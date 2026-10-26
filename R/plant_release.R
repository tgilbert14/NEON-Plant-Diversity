# ===========================================================================
# NEON Plant Diversity Explorer: plant_release.R
# The pinned NEON data release for DP1.10058.001, its DOI and CC BY 4.0
# citation, the fail-closed release check on consumed raw rows, and the NEON
# product change log (issue log) reader used for per-site notices.
#
# Base R plus jsonlite only.  Sourced by global.R (app), the fetch producer, the
# bundler, verify_bundle.R and the science tests.  Nothing here touches the
# network: the change log is read from the committed data/source copy.
# ===========================================================================

# The workflow's release gate greps this exact line; keep it on one line.
PLANT_NEON_RELEASE <- "RELEASE-2026"

PLANT_NEON_PRODUCT <- "DP1.10058.001"

# DOIs from the NEON products API (checked 2026-10-22); prefix https://doi.org/10.48443/.
PLANT_NEON_RELEASES <- data.frame(
  release = c("RELEASE-2021", "RELEASE-2022", "RELEASE-2023", "RELEASE-2024",
              "RELEASE-2025", "RELEASE-2026"),
  doi = paste0("https://doi.org/10.48443/",
               c("abge-r811", "pr5e-1q60", "9579-a253", "c50b-qx77", "zp67-s364", "9g4s-hq52")),
  published = c(2021L, 2022L, 2023L, 2024L, 2025L, 2026L),
  stringsAsFactors = FALSE)

.plant_release_scalar <- function(release) {
  if (is.null(release) || !length(release)) return(NA_character_)
  r <- as.character(release[[1]])
  if (is.na(r) || !nzchar(trimws(r))) NA_character_ else trimws(r)
}

# "https://doi.org/10.48443/9g4s-hq52" for a known release, else NA.
plant_release_doi <- function(release = PLANT_NEON_RELEASE) {
  r <- .plant_release_scalar(release)
  if (is.na(r)) return(NA_character_)
  i <- match(r, PLANT_NEON_RELEASES$release)
  if (is.na(i)) NA_character_ else PLANT_NEON_RELEASES$doi[i]
}

# One-line CC BY 4.0 citation.  An NA release drops the release and DOI parts
# (no release label is invented for a query that did not select one).
plant_release_citation <- function(release = PLANT_NEON_RELEASE) {
  r <- .plant_release_scalar(release)
  head <- "NEON (National Ecological Observatory Network). Plant presence and percent cover (DP1.10058.001)"
  tail <- "Dataset accessed from https://data.neonscience.org. CC BY 4.0."
  if (is.na(r)) return(paste0(head, ". ", tail))
  doi <- plant_release_doi(r)
  if (is.na(doi)) paste0(head, ", ", r, ". ", tail)
  else paste0(head, ", ", r, ". ", doi, ". ", tail)
}

# Fail-closed release check on raw rows.  character(0) when every consumed row's
# `release` column equals `release`; otherwise one problem string.  `consumed`
# is an optional logical or integer row selector (the rows the bundler keeps).
plant_release_row_problems <- function(frame, release, label, consumed = NULL) {
  label <- as.character(label %||% "table")[1]
  r <- .plant_release_scalar(release)
  if (is.na(r)) return(sprintf("%s: no expected release given", label))
  if (is.null(frame)) return(sprintf("%s: table is missing", label))
  frame <- as.data.frame(frame, stringsAsFactors = FALSE)
  if (!is.null(consumed)) {
    if (is.logical(consumed)) {
      if (length(consumed) != nrow(frame))
        return(sprintf("%s: consumed selector has %d values for %d rows", label,
                       length(consumed), nrow(frame)))
      consumed <- which(consumed %in% TRUE)
    }
    frame <- frame[as.integer(consumed), , drop = FALSE]
  }
  if (!nrow(frame)) return(character(0))
  if (!("release" %in% names(frame)))
    return(sprintf("%s: no `release` column on %d consumed rows (expected %s)",
                   label, nrow(frame), r))
  got <- as.character(frame$release)
  bad <- is.na(got) | got != r
  if (!any(bad)) return(character(0))
  seen <- sort(unique(ifelse(is.na(got[bad]), "<NA>", got[bad])), method = "radix")
  sprintf("%s: %d of %d consumed rows are not %s (found: %s)", label, sum(bad),
          length(got), r, paste(utils::head(seen, 6), collapse = ", "))
}

.CHANGE_LOG_COLS <- c("id", "issueDate", "resolvedDate", "dateRangeStart", "dateRangeEnd",
                      "locationAffected", "issue", "resolution")

# Read the committed NEON product change log.  data.frame with .CHANGE_LOG_COLS
# (id integer, the rest character) sorted by id, or NULL when the file is absent,
# unparsable or has no changeLogs.  Never errors.
load_neon_change_log <- function(path = "data/source/neon-change-log.json") {
  tryCatch({
    if (is.null(path) || !length(path) || !file.exists(path)) return(NULL)
    if (!requireNamespace("jsonlite", quietly = TRUE)) return(NULL)
    j <- jsonlite::fromJSON(path, simplifyVector = FALSE)
    logs <- j$changeLogs
    if (is.null(logs) || !length(logs)) return(NULL)
    field <- function(x, nm) {
      v <- x[[nm]]
      if (is.null(v) || !length(v)) NA_character_ else as.character(v[[1]])
    }
    rows <- lapply(logs, function(x) {
      out <- lapply(.CHANGE_LOG_COLS, function(nm) field(x, nm))
      names(out) <- .CHANGE_LOG_COLS
      as.data.frame(out, stringsAsFactors = FALSE)
    })
    out <- do.call(rbind, rows)
    out$id <- suppressWarnings(as.integer(out$id))
    out <- out[order(out$id, method = "radix"), .CHANGE_LOG_COLS, drop = FALSE]
    rownames(out) <- NULL
    attr(out, "product") <- if (is.null(j$product)) NA_character_ else as.character(j$product)
    out
  }, error = function(e) NULL)
}

.first_sentence <- function(x, max_chars = 220L) {
  x <- gsub("[[:space:]]+", " ", trimws(as.character(x)))
  x[is.na(x)] <- ""
  vapply(x, function(s) {
    m <- regexpr("[.!?](\\s|$)", s)
    s1 <- if (m > 0) substr(s, 1L, m) else s
    if (nchar(s1) > max_chars) paste0(substr(s1, 1L, max_chars - 3L), "...") else s1
  }, character(1), USE.NAMES = FALSE)
}

# Change-log rows that apply to `site` (named as a word in locationAffected, or
# locationAffected starting with "All") and start after `after` (a Date, usually
# the end of the bundled records).  Zero-row frame when none.
plant_site_notices <- function(log, site, after) {
  empty <- data.frame(id = integer(), date = character(), text = character(),
                      location = character(), stringsAsFactors = FALSE)
  if (is.null(log) || !is.data.frame(log) || !nrow(log)) return(empty)
  site <- toupper(trimws(as.character(site %||% "")[1]))
  after <- tryCatch(as.Date(after), error = function(e) as.Date(NA))
  if (!length(after) || is.na(after[1])) return(empty)
  loc <- ifelse(is.na(log$locationAffected), "", as.character(log$locationAffected))
  starts <- suppressWarnings(as.Date(substr(as.character(log$dateRangeStart), 1L, 10L)))
  names_site <- nzchar(site) & grepl("^[A-Z0-9]{4}$", site) &
    grepl(paste0("\\b", site, "\\b"), loc, perl = TRUE)
  all_sites <- grepl("^\\s*All", loc, ignore.case = TRUE)
  keep <- (names_site | all_sites) & !is.na(starts) & starts > after[1]
  if (!any(keep)) return(empty)
  x <- log[keep, , drop = FALSE]
  out <- data.frame(id = as.integer(x$id),
                    date = substr(as.character(x$issueDate), 1L, 10L),
                    text = .first_sentence(x$issue),
                    location = as.character(x$locationAffected),
                    stringsAsFactors = FALSE)
  out <- out[order(out$id, method = "radix"), , drop = FALSE]
  rownames(out) <- NULL
  out
}

# Latest observation year across bundle metas (a list of meta lists, or one
# meta).  NA_integer_ when no meta carries years.
plant_data_through <- function(metas) {
  if (is.null(metas)) return(NA_integer_)
  if (!is.null(metas$years) || !is.null(metas$site)) metas <- list(metas)
  yrs <- unlist(lapply(metas, function(m)
    suppressWarnings(as.integer(if (is.list(m)) m$years else NULL))), use.names = FALSE)
  yrs <- yrs[!is.na(yrs)]
  if (!length(yrs)) NA_integer_ else as.integer(max(yrs))
}

if (!exists("%||%", mode = "function"))
  `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
