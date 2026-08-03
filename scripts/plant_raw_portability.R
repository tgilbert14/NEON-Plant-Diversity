# Portable raw-source boundary for the Plant Diversity refresh.
#
# neonUtilities 4.x can return Arrow-backed ALTREP vectors. Those vectors are
# valid while Arrow is loaded in the fetch process, but they are not a durable
# RDS contract for the separate build process. Materialize every fetched data
# frame into plain base vectors before serialization and fail closed on shapes
# or classes that cannot be represented without an implicit package dependency.

pde_detected_classes <- function(value) {
  explicit <- attr(value, "class", exact = TRUE)
  implicit <- tryCatch(class(value), error = function(error) character(0))
  unique(as.character(c(explicit, implicit)))
}

pde_vector_class <- function(value) {
  classes <- pde_detected_classes(value)
  if (!length(classes)) "<none>" else paste(classes, collapse = "/")
}

pde_vector_signature <- function(value) {
  dimensions <- dim(value)
  dimension_text <- if (is.null(dimensions)) "<none>" else
    paste(dimensions, collapse = "x")
  sprintf(
    "typeof=%s class=%s length=%d dimensions=%s",
    typeof(value), pde_vector_class(value), length(value), dimension_text
  )
}

pde_is_arrow_altrep_class <- function(value) {
  classes <- pde_detected_classes(value)
  if (!length(classes)) return(FALSE)
  any(grepl(
    "arrow|altrep|array_.*_vector",
    as.character(classes), ignore.case = TRUE, perl = TRUE
  ))
}

pde_standard_column_kind <- function(value) {
  classes <- attr(value, "class", exact = TRUE)
  if (identical(classes, "Date")) return("Date")
  if (identical(classes, c("POSIXct", "POSIXt"))) return("POSIXct")
  if (identical(classes, "factor")) return("factor")
  if (identical(classes, c("ordered", "factor"))) return("ordered")
  if (pde_is_arrow_altrep_class(value)) return("arrow-altrep")
  if (is.null(classes) || !length(classes)) return("base")
  "unsupported"
}

pde_column_shape_problems <- function(value, expected_rows, label,
                                      allow_arrow_altrep = FALSE) {
  problems <- character(0)
  expected_rows <- as.integer(expected_rows)
  if (length(expected_rows) != 1L || is.na(expected_rows) || expected_rows < 0L)
    return(sprintf("%s received an invalid expected row count", label))

  if (length(value) != expected_rows) {
    problems <- c(problems, sprintf(
      "%s has length=%d; expected rows=%d (%s)",
      label, length(value), expected_rows, pde_vector_signature(value)
    ))
  }
  if (!is.atomic(value) || !is.null(dim(value))) {
    problems <- c(problems, sprintf(
      "%s must be a one-dimensional atomic vector (%s)",
      label, pde_vector_signature(value)
    ))
  }
  if (!typeof(value) %in% c(
    "logical", "integer", "double", "complex", "character", "raw"
  )) {
    problems <- c(problems, sprintf(
      "%s has unsupported storage type (%s)",
      label, pde_vector_signature(value)
    ))
  }

  kind <- pde_standard_column_kind(value)
  if (kind %in% c("Date", "POSIXct") &&
      !typeof(value) %in% c("integer", "double")) {
    problems <- c(problems, sprintf(
      "%s has invalid %s storage (%s)",
      label, kind, pde_vector_signature(value)
    ))
  }
  if (kind %in% c("factor", "ordered") && !identical(typeof(value), "integer")) {
    problems <- c(problems, sprintf(
      "%s has invalid factor storage (%s)",
      label, pde_vector_signature(value)
    ))
  }
  if (identical(kind, "arrow-altrep") && !isTRUE(allow_arrow_altrep)) {
    problems <- c(problems, sprintf(
      "%s retains an Arrow/ALTREP-like class (%s)",
      label, pde_vector_signature(value)
    ))
  } else if (identical(kind, "unsupported")) {
    problems <- c(problems, sprintf(
      "%s has an unsupported explicit class (%s)",
      label, pde_vector_signature(value)
    ))
  }

  if (!identical(kind, "arrow-altrep")) {
    allowed_attributes <- switch(
      kind,
      base = "names",
      Date = c("class", "names"),
      POSIXct = c("class", "tzone", "names"),
      factor = c("levels", "class", "names"),
      ordered = c("levels", "class", "names"),
      character(0)
    )
    unexpected <- setdiff(names(attributes(value)), allowed_attributes)
    if (length(unexpected)) {
      problems <- c(problems, sprintf(
        "%s has unsupported attribute(s): %s",
        label, paste(unexpected, collapse = ", ")
      ))
    }
  }
  unique(problems)
}

pde_materialize_column <- function(value, expected_rows, label) {
  problems <- pde_column_shape_problems(
    value, expected_rows, label, allow_arrow_altrep = TRUE
  )
  if (length(problems)) stop(paste(problems, collapse = "; "), call. = FALSE)

  kind <- pde_standard_column_kind(value)
  output <- vector(typeof(value), length(value))
  if (length(value)) output[] <- value

  if (identical(kind, "Date")) {
    class(output) <- "Date"
  } else if (identical(kind, "POSIXct")) {
    class(output) <- c("POSIXct", "POSIXt")
    timezone <- attr(value, "tzone", exact = TRUE)
    if (!is.null(timezone)) attr(output, "tzone") <- timezone
  } else if (kind %in% c("factor", "ordered")) {
    attr(output, "levels") <- attr(value, "levels", exact = TRUE)
    class(output) <- if (identical(kind, "ordered"))
      c("ordered", "factor") else "factor"
  }
  value_names <- names(value)
  if (!is.null(value_names)) names(output) <- value_names

  problems <- pde_column_shape_problems(
    output, expected_rows, label, allow_arrow_altrep = FALSE
  )
  if (length(problems)) stop(paste(problems, collapse = "; "), call. = FALSE)
  output
}

pde_frame_problems <- function(frame, table_name) {
  if (!is.data.frame(frame))
    return(sprintf("%s is not a data frame", table_name))
  if (pde_is_arrow_altrep_class(frame))
    return(sprintf("%s retains an Arrow/ALTREP-like data-frame class", table_name))
  if (is.null(names(frame)) || anyNA(names(frame)) ||
      any(!nzchar(names(frame))) || anyDuplicated(names(frame)))
    return(sprintf("%s has blank or duplicate column names", table_name))
  problems <- character(0)
  for (column in names(frame)) {
    problems <- c(
      problems,
      pde_column_shape_problems(
        frame[[column]], nrow(frame), paste0(table_name, "$", column),
        allow_arrow_altrep = FALSE
      )
    )
  }
  unique(problems)
}

pde_validate_portable_frame <- function(frame, table_name) {
  problems <- pde_frame_problems(frame, table_name)
  if (length(problems)) stop(paste(problems, collapse = "; "), call. = FALSE)
  invisible(TRUE)
}

pde_materialize_data_frame <- function(frame, table_name) {
  if (!is.data.frame(frame))
    stop(sprintf("%s is not a data frame", table_name), call. = FALSE)
  if (pde_is_arrow_altrep_class(frame))
    stop(sprintf("%s has an unsupported Arrow/ALTREP-like data-frame class",
                 table_name), call. = FALSE)
  if (is.null(names(frame)) || anyNA(names(frame)) ||
      any(!nzchar(names(frame))) || anyDuplicated(names(frame)))
    stop(sprintf("%s has blank or duplicate column names", table_name), call. = FALSE)

  output <- frame
  for (column in names(frame)) {
    output[[column]] <- pde_materialize_column(
      frame[[column]], nrow(frame), paste0(table_name, "$", column)
    )
  }
  pde_validate_portable_frame(output, table_name)
  output
}

pde_materialize_raw_result <- function(result, context = "raw result") {
  if (!is.list(result) || is.null(names(result)) || anyNA(names(result)) ||
      any(!nzchar(names(result))) || anyDuplicated(names(result)))
    stop(sprintf("%s must be a uniquely named list", context), call. = FALSE)
  for (name in names(result)) {
    if (is.data.frame(result[[name]])) {
      result[[name]] <- pde_materialize_data_frame(
        result[[name]], paste0(context, "$", name)
      )
    }
  }
  pde_validate_raw_result(result, context)
  result
}

pde_validate_raw_result <- function(result, context = "raw result") {
  if (!is.list(result) || is.null(names(result)) || anyNA(names(result)) ||
      any(!nzchar(names(result))) || anyDuplicated(names(result)))
    stop(sprintf("%s must be a uniquely named list", context), call. = FALSE)
  for (name in names(result)) {
    if (is.data.frame(result[[name]]))
      pde_validate_portable_frame(result[[name]], paste0(context, "$", name))
  }
  invisible(TRUE)
}

pde_require_raw_tables <- function(result, required, context = "raw result",
                                   require_nonempty = TRUE) {
  if (!is.list(result))
    stop(sprintf("%s is not a list", context), call. = FALSE)
  missing <- setdiff(required, names(result))
  if (length(missing)) stop(sprintf(
    "%s lacks required table(s): %s",
    context, paste(missing, collapse = ", ")
  ), call. = FALSE)
  invalid <- required[!vapply(result[required], is.data.frame, logical(1))]
  if (length(invalid)) stop(sprintf(
    "%s required table(s) are not data frames: %s",
    context, paste(invalid, collapse = ", ")
  ), call. = FALSE)
  if (isTRUE(require_nonempty)) {
    empty <- required[vapply(result[required], nrow, integer(1)) == 0L]
    if (length(empty)) stop(sprintf(
      "%s required table(s) are empty: %s",
      context, paste(empty, collapse = ", ")
    ), call. = FALSE)
  }
  invisible(TRUE)
}

pde_require_columns <- function(frame, table_name, required) {
  missing <- setdiff(required, names(frame))
  if (length(missing)) stop(sprintf(
    "%s lacks required field(s): %s",
    table_name, paste(missing, collapse = ", ")
  ), call. = FALSE)
  invisible(TRUE)
}

pde_validate_consumed_mask <- function(consumed, frame, table_name,
                                       source_fields = character(0)) {
  expected <- if (is.data.frame(frame)) nrow(frame) else NA_integer_
  valid <- is.data.frame(frame) && is.logical(consumed) &&
    is.null(dim(consumed)) && length(consumed) == expected
  if (isTRUE(valid)) return(invisible(TRUE))

  fields <- intersect(source_fields, names(frame))
  field_text <- if (!length(fields)) "<none>" else paste(vapply(
    fields,
    function(field) sprintf("%s{%s}", field, pde_vector_signature(frame[[field]])),
    character(1)
  ), collapse = ", ")
  stop(sprintf(
    paste0(
      "%s consumed-row mask is invalid: expected a one-dimensional logical ",
      "vector of length %s; got %s; source fields: %s"
    ),
    table_name,
    if (length(expected) == 1L && !is.na(expected)) as.character(expected) else "<unknown>",
    pde_vector_signature(consumed), field_text
  ), call. = FALSE)
}

pde_verify_raw_file_in_fresh_r <- function(path, site, source_start_date,
                                           source_cutoff_date,
                                           verifier = file.path(
                                             "scripts", "verify_raw_portability.R"
                                           ), echo = TRUE) {
  verifier <- normalizePath(verifier, winslash = "/", mustWork = TRUE)
  path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  command <- file.path(R.home("bin"), "Rscript")
  arguments <- shQuote(c(
    "--vanilla", verifier, path, as.character(site),
    as.character(source_start_date), as.character(source_cutoff_date)
  ))
  output <- suppressWarnings(system2(
    command, args = arguments, stdout = TRUE, stderr = TRUE
  ))
  status <- attr(output, "status", exact = TRUE)
  if (is.null(status)) status <- 0L
  if (isTRUE(echo) && length(output)) cat(paste(output, collapse = "\n"), "\n")
  if (!identical(as.integer(status), 0L)) stop(sprintf(
    "Fresh-R raw portability validation failed for %s (status %d): %s",
    basename(path), as.integer(status), paste(output, collapse = " | ")
  ), call. = FALSE)
  invisible(output)
}
