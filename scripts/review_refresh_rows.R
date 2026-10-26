#!/usr/bin/env Rscript

# Row-multiset and schema comparison companion to review_refresh_candidate.R.
# Kept in a separate process so the full 46-site scientific metric audit and
# sort-heavy row comparison do not compete for the validator's memory ceiling.

args <- commandArgs(trailingOnly = TRUE)
if (!length(args) || length(args) > 2L) {
  stop("usage: Rscript scripts/review_refresh_rows.R <production-root> [candidate-root]",
       call. = FALSE)
}
old_root <- normalizePath(args[[1L]], mustWork = TRUE)
new_root <- normalizePath(if (length(args) == 2L) args[[2L]] else ".",
                          mustWork = TRUE)
sites <- sub("[.]rds$", "", sort(list.files(file.path(new_root, "data", "sites"),
                                           pattern = "^[A-Z0-9]{4}[.]rds$")))
if (length(sites) != 46L) stop("candidate does not contain 46 site bundles",
                               call. = FALSE)

signature <- function(frame) paste(
  names(frame), vapply(frame, function(value) paste(class(value), collapse = "/"),
                       character(1)), sep = ":", collapse = "|"
)

equal_at_order <- function(old, new, fields) {
  old_order <- do.call(order, c(unname(old[fields]),
                                list(na.last = TRUE, method = "radix")))
  new_order <- do.call(order, c(unname(new[fields]),
                                list(na.last = TRUE, method = "radix")))
  all(vapply(names(old), function(field) {
    isTRUE(all.equal(old[[field]][old_order], new[[field]][new_order],
                     check.attributes = FALSE, tolerance = 0))
  }, logical(1)))
}

semantic_equal <- function(old, new, stable_fields) {
  if (!identical(names(old), names(new)) || nrow(old) != nrow(new)) return(FALSE)
  if (isTRUE(equal_at_order(old, new, stable_fields))) return(TRUE)
  # Some source rows share the builder key but differ in cover. Resolve those
  # exact ties by ordering on every retained column before declaring a change.
  isTRUE(equal_at_order(old, new, names(old)))
}

# PD-18: the bundler now drops exact duplicate rows.  A site whose candidate
# equals the committed rows with exact duplicates removed changed only by that
# contract step; it is reported as dedup-only, never as new data.
dedup_equal <- function(old, new, stable_fields) {
  old <- as.data.frame(old)
  semantic_equal(old[!duplicated(old), , drop = FALSE], as.data.frame(new), stable_fields)
}

review <- data.frame(site = sites, occ_equal = FALSE, ground_equal = FALSE,
                     occ_dedup_only = FALSE, ground_dedup_only = FALSE,
                     schema_equal = FALSE, candidate_schema = NA_character_,
                     stringsAsFactors = FALSE)
for (i in seq_along(sites)) {
  site <- sites[[i]]
  old <- readRDS(file.path(old_root, "data", "sites", paste0(site, ".rds")))
  new <- readRDS(file.path(new_root, "data", "sites", paste0(site, ".rds")))
  review$occ_equal[[i]] <- semantic_equal(
    old$occ, new$occ,
    c("plotID", "subplotID", "scale", "year", "bout", "scientificName", "taxonID")
  )
  review$ground_equal[[i]] <- semantic_equal(
    old$ground, new$ground,
    c("plotID", "subplotID", "year", "bout", "otherVariables")
  )
  if (!review$occ_equal[[i]])
    review$occ_dedup_only[[i]] <- dedup_equal(old$occ, new$occ,
      c("plotID", "subplotID", "scale", "year", "bout", "scientificName", "taxonID"))
  if (!review$ground_equal[[i]])
    review$ground_dedup_only[[i]] <- dedup_equal(old$ground, new$ground,
      c("plotID", "subplotID", "year", "bout", "otherVariables"))
  review$schema_equal[[i]] <- identical(
    paste(signature(old$occ), signature(old$ground), sep = " || "),
    paste(signature(new$occ), signature(new$ground), sep = " || ")
  )
  review$candidate_schema[[i]] <- paste(
    signature(new$occ), signature(new$ground), sep = " || "
  )
  rm(old, new)
  invisible(gc())
}

cat("PLANT DIVERSITY REFRESH ROW REVIEW\n")
cat(sprintf("occurrence row multisets unchanged: %d/46\n", sum(review$occ_equal)))
cat(sprintf("ground row multisets unchanged: %d/46\n", sum(review$ground_equal)))
cat(sprintf("exact retained-column schemas unchanged: %d/46\n",
            sum(review$schema_equal)))
cat(sprintf("changed occurrence sites: %s\n",
            paste(review$site[!review$occ_equal], collapse = ",")))
cat(sprintf("changed ground sites: %s\n",
            paste(review$site[!review$ground_equal], collapse = ",")))
cat(sprintf("occurrence changed only by exact-duplicate removal: %s\n",
            paste(review$site[review$occ_dedup_only], collapse = ",")))
cat(sprintf("ground changed only by exact-duplicate removal: %s\n",
            paste(review$site[review$ground_dedup_only], collapse = ",")))
cat(sprintf("schema-class change sites: %s\n",
            paste(review$site[!review$schema_equal], collapse = ",")))
# The reviewer states which sites are EXPECTED to carry refreshed rows through
# PDE_EXPECTED_CHANGED_SITES (comma-separated; empty = no site may change rows).
# The 2026-08-03 review expected JORN,KONZ,SRER; the 2026-10-21 review expected
# none (stamp-and-contract refresh). Any other family fails closed.
expected_changed <- sort(unique(Filter(nzchar, trimws(strsplit(
  Sys.getenv("PDE_EXPECTED_CHANGED_SITES", ""), ",", fixed = TRUE)[[1L]]))),
  method = "radix")
data_changed_occ <- review$site[!review$occ_equal & !review$occ_dedup_only]
data_changed_ground <- review$site[!review$ground_equal & !review$ground_dedup_only]
if (!identical(sort(data_changed_occ, method = "radix"), expected_changed) ||
    !identical(sort(data_changed_ground, method = "radix"), expected_changed) ||
    length(unique(review$candidate_schema)) != 1L) {
  stop(sprintf("row review found an unexpected changed-site family or candidate schema (expected changed sites: %s)",
               if (length(expected_changed)) paste(expected_changed, collapse = ",") else "none"),
       call. = FALSE)
}
cat(sprintf("REVIEW ASSERTIONS PASSED: %d site row families are semantically unchanged; refreshed row families: %s; every candidate bundle shares one retained schema.\n",
            sum(review$occ_equal),
            if (length(expected_changed)) paste(expected_changed, collapse = ", ") else "none"))
