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

review <- data.frame(site = sites, occ_equal = FALSE, ground_equal = FALSE,
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
cat(sprintf("schema-class change sites: %s\n",
            paste(review$site[!review$schema_equal], collapse = ",")))
if (!identical(review$site[!review$occ_equal], c("JORN", "KONZ", "SRER")) ||
    !identical(review$site[!review$ground_equal], c("JORN", "KONZ", "SRER")) ||
    length(unique(review$candidate_schema)) != 1L) {
  stop("row review found an unexpected changed-site family or candidate schema",
       call. = FALSE)
}
cat("REVIEW ASSERTIONS PASSED: 43 site row families are semantically unchanged; JORN, KONZ, and SRER are the only refreshed row families; every candidate bundle shares one retained schema.\n")
