#!/usr/bin/env Rscript

# Content key (PD-08): does a refresh candidate carry different DATA than the
# committed tree, or only new stamps?  Base R plus jsonlite; no network.
#
#   Rscript --vanilla scripts/content_key.R <candidate_root> <committed_root>
#
# A root is a repository root (holding data/sites) or a data directory (holding
# sites/).  Compared, ignoring row order, attributes and bundle meta stamps:
#   * per-site occ and ground tables (columns sorted by name, rows sorted on
#     every column, row names dropped);
#   * data/site_index.rds values; data/search_index.rds taxa;
#   * data/expected/completeness_index.rds;
#   * data/source/neon-change-log.json changeLogs.
# Prints, and writes to $PDE_CONTENT_KEY_OUT when set:
#   content_changed=true|false
#   changed=<comma list>
#   new_change_log_ids=<comma list>
# Exit 0 after a completed comparison; non-zero only on error.

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2L)
  stop("usage: Rscript scripts/content_key.R <candidate_root> <committed_root>", call. = FALSE)

data_dir <- function(root) {
  root <- normalizePath(root, mustWork = TRUE)
  if (dir.exists(file.path(root, "data", "sites"))) return(file.path(root, "data"))
  if (dir.exists(file.path(root, "sites"))) return(root)
  stop(sprintf("%s holds neither data/sites nor sites/", root), call. = FALSE)
}
cand <- data_dir(args[[1L]])
comm <- data_dir(args[[2L]])

canon <- function(frame) {
  if (is.null(frame)) return(NULL)
  frame <- as.data.frame(frame, stringsAsFactors = FALSE)
  frame <- frame[, sort(names(frame), method = "radix"), drop = FALSE]
  for (nm in names(frame)) attributes(frame[[nm]]) <- NULL
  if (nrow(frame) && ncol(frame)) {
    o <- do.call(order, c(unname(as.list(frame)), list(na.last = TRUE, method = "radix")))
    frame <- frame[o, , drop = FALSE]
  }
  attributes(frame) <- list(names = names(frame), class = "data.frame",
                            row.names = .set_row_names(nrow(frame)))
  frame
}
read_or_null <- function(path) if (file.exists(path)) readRDS(path) else NULL
same <- function(a, b) identical(canon(a), canon(b))

changed <- character(0)
cand_sites <- sort(sub("[.]rds$", "", list.files(file.path(cand, "sites"), pattern = "^[A-Z0-9]{4}[.]rds$")))
comm_sites <- sort(sub("[.]rds$", "", list.files(file.path(comm, "sites"), pattern = "^[A-Z0-9]{4}[.]rds$")))
if (!identical(cand_sites, comm_sites)) changed <- c(changed, "site_set")
for (site in intersect(cand_sites, comm_sites)) {
  a <- readRDS(file.path(cand, "sites", paste0(site, ".rds")))
  b <- readRDS(file.path(comm, "sites", paste0(site, ".rds")))
  if (!same(a$occ, b$occ)) changed <- c(changed, sprintf("occ:%s", site))
  if (!same(a$ground, b$ground)) changed <- c(changed, sprintf("ground:%s", site))
}

if (!same(read_or_null(file.path(cand, "site_index.rds")),
          read_or_null(file.path(comm, "site_index.rds"))))
  changed <- c(changed, "site_index")
taxa_of <- function(path) { x <- read_or_null(path); if (is.null(x)) NULL else x$taxa }
if (!same(taxa_of(file.path(cand, "search_index.rds")), taxa_of(file.path(comm, "search_index.rds"))))
  changed <- c(changed, "search_index")
if (!same(read_or_null(file.path(cand, "expected", "completeness_index.rds")),
          read_or_null(file.path(comm, "expected", "completeness_index.rds"))))
  changed <- c(changed, "completeness_index")

change_logs <- function(dir) {
  path <- file.path(dir, "source", "neon-change-log.json")
  if (!file.exists(path)) return(NULL)
  j <- jsonlite::fromJSON(path, simplifyVector = FALSE)
  logs <- j$changeLogs %||% list()
  ids <- vapply(logs, function(x) as.character(x$id %||% NA), character(1))
  list(ids = ids, text = vapply(logs, function(x) jsonlite::toJSON(x, auto_unbox = TRUE, null = "null"),
                                character(1)))
}
`%||%` <- function(a, b) if (is.null(a) || !length(a)) b else a
cl_a <- change_logs(cand); cl_b <- change_logs(comm)
new_ids <- character(0)
if (!identical(sort(cl_a$text), sort(cl_b$text))) {
  changed <- c(changed, "change_log")
  new_ids <- sort(setdiff(cl_a$ids, cl_b$ids))
}

lines <- c(sprintf("content_changed=%s", if (length(changed)) "true" else "false"),
           sprintf("changed=%s", paste(changed, collapse = ",")),
           sprintf("new_change_log_ids=%s", paste(new_ids, collapse = ",")))
cat(lines, sep = "\n"); cat("\n")
out <- trimws(Sys.getenv("PDE_CONTENT_KEY_OUT", ""))
if (nzchar(out)) cat(lines, file = out, sep = "\n", append = TRUE)
