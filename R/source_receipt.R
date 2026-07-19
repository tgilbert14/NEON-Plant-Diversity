# Source-receipt boundary for the plant occurrence bundles.
#
# The first complete 46-site bundle family predates embedded source receipts.
# Never infer its vintage from filesystem mtimes: Git and Connect rewrite them.
# Recognize only the exact content-addressed legacy family below and keep its
# original NEON release, query cutoff, and build date explicitly unknown.
# A reviewed refresh must instead carry one complete, matching receipt on every
# site bundle and on site_index.rds. Partial and mixed families fail closed.

PLANT_SOURCE_RECEIPT <- list(
  schema_version = "plant-legacy-source-receipt-v1",
  product = "DP1.10058.001",
  site_count = 46L,
  inventory_spec = "sorted '<per-file SHA-256> <basename>\\n' inventory",
  site_inventory_sha256 =
    "8f967bf7d0369879d0e9d3ac1ce19717d755ae681bc8eaa6d1341c3ade1f2a8a",
  bundle_commit = "4ffcb24c3c1bf0dcab1f6c42fd3b9b5fe4de4e1e",
  repository_imported_at = "2026-06-19",
  receipt_basis = "legacy repository import commit date; not an upstream fetch cutoff",
  neon_release = NA_character_,
  source_cutoff = NA_character_,
  built_at = NA_character_,
  provenance_class = "legacy-partial",
  limitation = paste(
    "The original NEON release, fetch cutoff, query receipt, and build date",
    "were not preserved. Ecological values are descriptive for these exact",
    "committed bytes."
  )
)

PLANT_REFRESH_RECEIPT_FIELDS <- c(
  "receipt_version", "product", "built_at", "source_start",
  "source_cutoff", "source_receipt_id", "query_package",
  "neon_utilities_version", "source_digest", "builder_commit",
  "neon_release"
)

.receipt_scalar <- function(value, allow_na = FALSE) {
  if (is.null(value) || length(value) != 1L)
    return(if (allow_na) NA_character_ else "")
  value <- as.character(value)
  if (is.na(value)) return(if (allow_na) NA_character_ else "")
  trimws(value)
}

.receipt_iso_date <- function(value) {
  value <- .receipt_scalar(value)
  nzchar(value) && grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", value) &&
    !is.na(suppressWarnings(as.Date(value, format = "%Y-%m-%d")))
}

.receipt_hex <- function(value, length) {
  grepl(sprintf("^[0-9a-f]{%d}$", as.integer(length)),
        .receipt_scalar(value))
}

# Validate the raw-row boundary shared by fetch and bundle stages. Both identity
# fields are enforced when supplied because plotID is retained in runtime data;
# a matching siteID must never hide a foreign plotID. Date-times may be bare ISO
# dates or complete ISO-like timestamps, but trailing junk and invalid clocks
# are rejected before the calendar date is parsed and range-checked.
plant_source_row_problems <- function(frame, site, table_name,
                                      source_start_date, source_cutoff_date,
                                      consumed = NULL) {
  if (!is.data.frame(frame))
    return(sprintf("%s is not a data frame", table_name))
  if (is.null(consumed)) consumed <- rep(TRUE, nrow(frame))
  if (!is.logical(consumed) || length(consumed) != nrow(frame))
    return(sprintf("%s consumed-row mask is invalid", table_name))
  consumed[is.na(consumed)] <- FALSE
  rows <- frame[consumed, , drop = FALSE]
  if (!nrow(rows)) return(character(0))

  start_date <- suppressWarnings(as.Date(
    as.character(source_start_date), format = "%Y-%m-%d"
  ))
  cutoff_date <- suppressWarnings(as.Date(
    as.character(source_cutoff_date), format = "%Y-%m-%d"
  ))
  if (length(start_date) != 1L || length(cutoff_date) != 1L ||
      is.na(start_date) || is.na(cutoff_date) || start_date > cutoff_date)
    return(sprintf("%s received an invalid source interval", table_name))

  problems <- character(0)
  if (!any(c("siteID", "plotID") %in% names(rows)))
    problems <- c(problems, sprintf("%s has neither siteID nor plotID", table_name))
  if ("siteID" %in% names(rows)) {
    site_values <- trimws(as.character(rows$siteID))
    safe_values <- ifelse(is.na(site_values), "", site_values)
    if (any(!nzchar(safe_values) | safe_values != site))
      problems <- c(problems, sprintf("%s contains a blank or foreign siteID", table_name))
  }
  if ("plotID" %in% names(rows)) {
    plot_values <- trimws(as.character(rows$plotID))
    safe_values <- ifelse(is.na(plot_values), "", plot_values)
    if (any(!nzchar(safe_values) |
            !startsWith(safe_values, paste0(site, "_"))))
      problems <- c(
        problems,
        sprintf("%s contains a blank or non-%s plotID", table_name, site)
      )
  }

  if (!"endDate" %in% names(rows)) {
    problems <- c(problems, sprintf("%s lacks endDate", table_name))
  } else {
    end_values <- trimws(as.character(rows$endDate))
    date_pattern <- paste0(
      "^[0-9]{4}-[0-9]{2}-[0-9]{2}",
      "([ T]([01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9]",
      "([.][0-9]+)?(Z|[+-]([01][0-9]|2[0-3]):?[0-5][0-9])?)?$"
    )
    date_shape <- !is.na(end_values) & grepl(date_pattern, end_values)
    date_part <- substr(end_values, 1L, 10L)
    parsed_dates <- rep(as.Date(NA), length(end_values))
    parsed_dates[date_shape] <- suppressWarnings(
      as.Date(date_part[date_shape], format = "%Y-%m-%d")
    )
    bad_dates <- is.na(parsed_dates) |
      parsed_dates < start_date | parsed_dates > cutoff_date
    if (any(bad_dates))
      problems <- c(
        problems,
        sprintf(
          "%s has %d unparsable or out-of-window endDate value(s)",
          table_name, sum(bad_dates)
        )
      )
  }

  problems
}

validate_plant_source_rows <- function(frame, site, table_name,
                                       source_start_date, source_cutoff_date,
                                       consumed = NULL) {
  problems <- plant_source_row_problems(
    frame, site, table_name, source_start_date, source_cutoff_date, consumed
  )
  if (length(problems)) stop(paste(problems, collapse = "; "), call. = FALSE)
  invisible(TRUE)
}

plant_site_inventory_sha256 <- function(site_dir, expected_sites) {
  if (!requireNamespace("digest", quietly = TRUE))
    stop("The digest package is required to verify the plant source receipt",
         call. = FALSE)
  paths <- sort(list.files(site_dir, pattern = "[.]rds$", full.names = TRUE))
  sites <- sub("[.]rds$", "", basename(paths))
  if (!identical(sites, sort(as.character(expected_sites))))
    stop("Plant source receipt site inventory does not match the expected 46-site set",
         call. = FALSE)
  checksums <- vapply(paths, function(path) {
    digest::digest(file = path, algo = "sha256", serialize = FALSE)
  }, character(1))
  if (length(checksums) != length(paths) || any(!nzchar(checksums)))
    stop("Plant source receipt could not checksum every site bundle", call. = FALSE)
  inventory <- paste0(paste(checksums, basename(paths)), collapse = "\n")
  digest::digest(charToRaw(paste0(inventory, "\n")),
                 algo = "sha256", serialize = FALSE)
}

verify_legacy_plant_source_receipt <- function(site_dir, expected_sites,
                                               receipt = PLANT_SOURCE_RECEIPT) {
  expected_sites <- sort(as.character(expected_sites))
  if (!identical(.receipt_scalar(receipt$schema_version),
                 "plant-legacy-source-receipt-v1") ||
      !identical(.receipt_scalar(receipt$product), "DP1.10058.001") ||
      !identical(as.integer(receipt$site_count), length(expected_sites)) ||
      !identical(.receipt_scalar(receipt$inventory_spec),
                 "sorted '<per-file SHA-256> <basename>\\n' inventory") ||
      !identical(.receipt_scalar(receipt$repository_imported_at), "2026-06-19") ||
      !identical(.receipt_scalar(receipt$provenance_class), "legacy-partial") ||
      !identical(.receipt_scalar(receipt$bundle_commit),
                 "4ffcb24c3c1bf0dcab1f6c42fd3b9b5fe4de4e1e") ||
      !identical(.receipt_scalar(receipt$site_inventory_sha256),
                 "8f967bf7d0369879d0e9d3ac1ce19717d755ae681bc8eaa6d1341c3ade1f2a8a") ||
      !identical(.receipt_scalar(receipt$receipt_basis),
                 "legacy repository import commit date; not an upstream fetch cutoff") ||
      !identical(.receipt_scalar(receipt$limitation), paste(
        "The original NEON release, fetch cutoff, query receipt, and build date",
        "were not preserved. Ecological values are descriptive for these exact",
        "committed bytes."
      )) ||
      !is.na(.receipt_scalar(receipt$built_at, allow_na = TRUE)) ||
      !is.na(.receipt_scalar(receipt$neon_release, allow_na = TRUE)) ||
      !is.na(.receipt_scalar(receipt$source_cutoff, allow_na = TRUE)))
    stop("Legacy plant source receipt is incomplete or overstates upstream provenance",
         call. = FALSE)
  actual <- plant_site_inventory_sha256(site_dir, expected_sites)
  if (!identical(actual, .receipt_scalar(receipt$site_inventory_sha256)))
    stop("Plant bundles do not match the registered legacy source receipt",
         call. = FALSE)
  invisible(TRUE)
}

.plant_embedded_receipt <- function(container, attributes = FALSE) {
  available <- if (attributes) names(attributes(container)) else names(container)
  present <- PLANT_REFRESH_RECEIPT_FIELDS %in% available
  values <- stats::setNames(vector("list", length(PLANT_REFRESH_RECEIPT_FIELDS)),
                            PLANT_REFRESH_RECEIPT_FIELDS)
  for (field in PLANT_REFRESH_RECEIPT_FIELDS) {
    value <- if (attributes) attr(container, field, exact = TRUE) else container[[field]]
    values[[field]] <- .receipt_scalar(value, allow_na = identical(field, "neon_release"))
  }
  list(present = stats::setNames(present, PLANT_REFRESH_RECEIPT_FIELDS),
       values = values)
}

.validate_plant_refresh_receipt <- function(values) {
  release <- values$neon_release
  if (!identical(values$receipt_version, "plant-source-receipt-v2") ||
      !identical(values$product, "DP1.10058.001") ||
      !.receipt_iso_date(values$built_at) ||
      !grepl("^[0-9]{4}-(0[1-9]|1[0-2])$", values$source_start) ||
      !.receipt_iso_date(values$source_cutoff) ||
      format(as.Date(values$source_cutoff) + 1, "%d") != "01" ||
      as.Date(values$built_at) < as.Date(values$source_cutoff) ||
      substr(values$source_cutoff, 1L, 7L) < values$source_start ||
      !grepl("^[A-Za-z0-9._:-]+$", values$source_receipt_id) ||
      !identical(values$query_package, "basic") ||
      !grepl("^[0-9]+([.][0-9]+){1,3}([.-][A-Za-z0-9]+)?$",
             values$neon_utilities_version) ||
      !.receipt_hex(values$source_digest, 64L) ||
      !grepl(values$source_digest, values$source_receipt_id, fixed = TRUE) ||
      !.receipt_hex(values$builder_commit, 40L) ||
      (!is.na(release) && !grepl("^[A-Za-z0-9._:-]+$", release)))
    stop("Plant bundles contain an invalid refreshed source receipt", call. = FALSE)
  invisible(TRUE)
}

resolve_plant_source_set <- function(site_dir, site_index, expected_sites,
                                     bundle_metas = NULL,
                                     receipt = PLANT_SOURCE_RECEIPT,
                                     require_bundle_metas = FALSE) {
  expected_sites <- sort(as.character(expected_sites))
  actual_sites <- sort(sub("[.]rds$", "", basename(list.files(
    site_dir, pattern = "[.]rds$", full.names = TRUE
  ))))
  if (!identical(actual_sites, expected_sites))
    stop("Plant source directory does not match the canonical site inventory",
         call. = FALSE)
  if (isTRUE(require_bundle_metas) && is.null(bundle_metas))
    stop("Plant source verification requires all bundle metadata", call. = FALSE)
  if (!is.null(bundle_metas) &&
      (!is.list(bundle_metas) ||
       !all(vapply(bundle_metas, is.list, logical(1))) ||
       !identical(sort(names(bundle_metas)), expected_sites)))
    stop("Plant source receipt did not receive one metadata record per site",
         call. = FALSE)

  index_receipt <- .plant_embedded_receipt(site_index, attributes = TRUE)
  meta_receipts <- if (is.null(bundle_metas)) list() else
    lapply(bundle_metas, .plant_embedded_receipt, attributes = FALSE)
  any_embedded <- any(index_receipt$present) ||
    any(vapply(meta_receipts, function(item) any(item$present), logical(1)))

  if (any_embedded) {
    if (!all(index_receipt$present) ||
        (length(meta_receipts) &&
         !all(vapply(meta_receipts, function(item) all(item$present), logical(1)))))
      stop("Plant bundles contain a partial or mixed embedded source receipt",
           call. = FALSE)
    values <- index_receipt$values
    .validate_plant_refresh_receipt(values)
    if (length(meta_receipts)) {
      for (site in names(meta_receipts)) {
        candidate <- meta_receipts[[site]]$values
        .validate_plant_refresh_receipt(candidate)
        for (field in PLANT_REFRESH_RECEIPT_FIELDS) {
          if (!identical(candidate[[field]], values[[field]]))
            stop(sprintf("Plant source receipt differs at %s (%s)", site, field),
                 call. = FALSE)
        }
      }
    }
    return(list(
      built_at = values$built_at,
      repository_imported_at = NA_character_,
      neon_release = values$neon_release,
      source_start = values$source_start,
      source_cutoff = values$source_cutoff,
      source_receipt_id = values$source_receipt_id,
      source_digest = values$source_digest,
      receipt_basis = "embedded reviewed query-snapshot receipt",
      provenance_class = "query-snapshot",
      bundle_commit = values$builder_commit,
      query_package = values$query_package,
      neon_utilities_version = values$neon_utilities_version
    ))
  }

  verify_legacy_plant_source_receipt(site_dir, expected_sites, receipt)
  list(
    built_at = NA_character_,
    repository_imported_at = .receipt_scalar(receipt$repository_imported_at),
    neon_release = NA_character_,
    source_start = NA_character_,
    source_cutoff = NA_character_,
    source_receipt_id = NA_character_,
    source_digest = .receipt_scalar(receipt$site_inventory_sha256),
    receipt_basis = .receipt_scalar(receipt$receipt_basis),
    provenance_class = .receipt_scalar(receipt$provenance_class),
    bundle_commit = .receipt_scalar(receipt$bundle_commit),
    query_package = NA_character_,
    neon_utilities_version = NA_character_,
    limitation = .receipt_scalar(receipt$limitation)
  )
}

verify_plant_search_receipt <- function(search_index, source_status) {
  fields <- c(
    built_at = "built_at",
    repository_imported_at = "repository_imported_at",
    neon_release = "neon_release",
    source_start = "source_start",
    source_cutoff = "source_cutoff",
    source_receipt_id = "source_receipt_id",
    source_digest = "source_digest",
    source_receipt_basis = "receipt_basis",
    source_provenance_class = "provenance_class",
    source_bundle_commit = "bundle_commit",
    query_package = "query_package",
    neon_utilities_version = "neon_utilities_version"
  )
  if (!is.list(search_index) || !all(names(fields) %in% names(search_index)))
    stop("Plant search index lacks the complete source-receipt schema",
         call. = FALSE)
  for (field in names(fields)) {
    if (!identical(search_index[[field]], source_status[[fields[[field]]]]))
      stop(sprintf("Plant search index source receipt differs at %s", field),
           call. = FALSE)
  }
  invisible(TRUE)
}

verify_plant_durable_source_inventory <- function(
    source_status, expected_sites,
    inventory_path = "data/source/plant-raw-SHA256SUMS.txt") {
  files <- sort(list.files(dirname(inventory_path), full.names = TRUE,
                           all.files = TRUE, no.. = TRUE))
  if (identical(source_status$provenance_class, "legacy-partial")) {
    if (length(files))
      stop("Legacy plant data must not carry a refreshed raw-source inventory",
           call. = FALSE)
    return(invisible(TRUE))
  }
  if (!identical(source_status$provenance_class, "query-snapshot"))
    stop("Plant source inventory received an unknown provenance class",
         call. = FALSE)
  if (!identical(files, inventory_path))
    stop("Receipt-complete plant data must carry exactly one raw-source inventory",
         call. = FALSE)
  lines <- readLines(inventory_path, warn = FALSE)
  pattern <- "^[0-9a-f]{64}  [.]/([A-Z0-9]{4})_raw[.]rds$"
  sites <- sub(pattern, "\\1", lines)
  digest <- digest::digest(file = inventory_path, algo = "sha256",
                           serialize = FALSE)
  if (length(lines) != length(expected_sites) ||
      any(!grepl(pattern, lines)) ||
      !identical(sites, sort(as.character(expected_sites))) ||
      !identical(digest, source_status$source_digest))
    stop("Durable raw per-file SHA-256 inventory differs from the source receipt",
         call. = FALSE)
  invisible(TRUE)
}
