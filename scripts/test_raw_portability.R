#!/usr/bin/env Rscript

# Focused producer/consumer fixtures for the raw RDS transport boundary.
# The consumer is a fresh `Rscript --vanilla` process with no Arrow or
# neonUtilities namespace loaded.

file_args <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (!length(file_args)) stop("Run this test with Rscript", call. = FALSE)
test_file <- normalizePath(
  sub("^--file=", "", file_args[[1L]]), winslash = "/", mustWork = TRUE
)
repo_root <- dirname(dirname(test_file))
source(file.path(repo_root, "scripts", "plant_raw_portability.R"))

assert <- function(ok, message) if (!isTRUE(ok)) stop(message, call. = FALSE)

dates <- as.Date(c("2020-01-02", NA_character_))
times <- as.POSIXct(
  c("2020-01-02 03:04:05", NA_character_), tz = "UTC"
)
categories <- factor(c("native", NA_character_), levels = c("native", "introduced"))
ordered_categories <- ordered(c("low", "high"), levels = c("low", "high"))
arrowish <- structure(
  c("alpha", NA_character_),
  class = c("arrow::array_string_vector", "vctrs_vctr")
)
typed <- data.frame(
  logical_value = c(TRUE, NA),
  integer_value = c(1L, NA_integer_),
  numeric_value = c(1.25, NA_real_),
  character_value = c("one", NA_character_),
  stringsAsFactors = FALSE
)
typed$date_value <- dates
typed$time_value <- times
typed$factor_value <- categories
typed$ordered_value <- ordered_categories
typed$arrow_value <- arrowish

materialized <- pde_materialize_data_frame(typed, "typed fixture")
assert(identical(materialized$logical_value, typed$logical_value),
       "logical values changed during materialization")
assert(identical(materialized$integer_value, typed$integer_value),
       "integer values changed during materialization")
assert(identical(materialized$numeric_value, typed$numeric_value),
       "numeric values changed during materialization")
assert(identical(materialized$character_value, typed$character_value),
       "character values changed during materialization")
assert(identical(materialized$date_value, dates),
       "Date values or class changed during materialization")
assert(identical(materialized$time_value, times),
       "POSIXct values, class, or timezone changed during materialization")
assert(identical(materialized$factor_value, categories),
       "factor values, levels, or class changed during materialization")
assert(identical(materialized$ordered_value, ordered_categories),
       "ordered-factor values, levels, or class changed during materialization")
assert(identical(materialized$arrow_value, c("alpha", NA_character_)) &&
       is.null(attr(materialized$arrow_value, "class", exact = TRUE)),
       "Arrow-like character fixture was not reduced to a plain base vector")

d1 <- data.frame(
  siteID = rep("SRER", 3L),
  plotID = paste0("SRER_00", 1:3),
  endDate = c("2013-01-01", "2020-05-06T10:30:00Z", "2026-06-30"),
  divDataType = c("plantSpecies", "otherVariables", "plantSpecies"),
  scientificName = c("Fixture alpha", NA_character_, NA_character_),
  otherVariables = c(NA_character_, "bareGround", NA_character_),
  stringsAsFactors = FALSE
)
d2 <- data.frame(
  siteID = rep("SRER", 2L),
  plotID = c("SRER_001", "SRER_002"),
  endDate = c("2013-01-01", "2026-06-30T23:59:59Z"),
  scientificName = c("Fixture beta", NA_character_),
  stringsAsFactors = FALSE
)
d1$scientificName <- structure(
  d1$scientificName,
  class = c("arrow::array_string_vector", "vctrs_vctr")
)
raw <- list(
  div_1m2Data = d1,
  div_10m2Data100m2Data = d2,
  validation = typed
)
portable <- pde_materialize_raw_result(raw, "fixture raw")
expected_d1_mask <- c(TRUE, TRUE, FALSE)
expected_d2_mask <- c(TRUE, FALSE)
actual_d1_mask <-
  (as.character(portable$div_1m2Data$divDataType) == "plantSpecies" &
     !is.na(portable$div_1m2Data$scientificName)) |
  (as.character(portable$div_1m2Data$divDataType) == "otherVariables" &
     !is.na(portable$div_1m2Data$otherVariables))
actual_d2_mask <- !is.na(portable$div_10m2Data100m2Data$scientificName)
assert(identical(actual_d1_mask, expected_d1_mask) &&
       identical(actual_d2_mask, expected_d2_mask),
       "materialization changed the registered consumed-row masks")

temporary_root <- tempfile("plant-raw-portability-")
dir.create(temporary_root)
on.exit(unlink(temporary_root, recursive = TRUE), add = TRUE)
portable_path <- file.path(temporary_root, "SRER_raw.rds")
saveRDS(portable, portable_path, compress = "xz")
child_output <- pde_verify_raw_file_in_fresh_r(
  portable_path, "SRER", "2013-01-01", "2026-06-30",
  file.path(repo_root, "scripts", "verify_raw_portability.R")
)
assert(any(grepl("RAW PORTABILITY PASSED", child_output, fixed = TRUE)),
       "fresh child-R consumer did not validate the portable fixture")

bad_d1 <- unclass(portable$div_1m2Data)
bad_d1$scientificName <- character(0)
attr(bad_d1, "row.names") <- .set_row_names(3L)
class(bad_d1) <- "data.frame"
malformed <- portable
malformed$div_1m2Data <- bad_d1
malformed_path <- file.path(temporary_root, "SRER_malformed_raw.rds")
saveRDS(malformed, malformed_path, compress = "xz")

malformed_error <- tryCatch({
  pde_verify_raw_file_in_fresh_r(
    malformed_path, "SRER", "2013-01-01", "2026-06-30",
    file.path(repo_root, "scripts", "verify_raw_portability.R"), echo = FALSE
  )
  ""
}, error = function(error) conditionMessage(error))
assert(
  grepl("scientificName has length=0; expected rows=3", malformed_error, fixed = TRUE),
  "fresh child-R consumer did not reject the malformed zero-length field precisely"
)

mask_error <- tryCatch({
  pde_validate_consumed_mask(
    logical(0), portable$div_1m2Data, "div_1m2Data",
    c("divDataType", "scientificName", "otherVariables")
  )
  ""
}, error = function(error) conditionMessage(error))
assert(
  grepl("expected a one-dimensional logical vector of length 3", mask_error,
        fixed = TRUE) && grepl("got typeof=logical", mask_error, fixed = TRUE) &&
    grepl("divDataType{typeof=character", mask_error, fixed = TRUE) &&
    grepl("scientificName{typeof=character", mask_error, fixed = TRUE) &&
    grepl("otherVariables{typeof=character", mask_error, fixed = TRUE),
  "consumed-mask diagnostics did not report expected and actual shape"
)

fetch_text <- paste(readLines(
  file.path(repo_root, "scripts", "fetch_plant_all.R"), warn = FALSE
), collapse = "\n")
bundle_text <- paste(readLines(
  file.path(repo_root, "scripts", "bundle_plant_data.R"), warn = FALSE
), collapse = "\n")
workflow_text <- paste(readLines(
  file.path(repo_root, ".github", "workflows", "refresh-data.yml"),
  warn = FALSE
), collapse = "\n")

fetch_tokens <- c(
  'source("scripts/plant_raw_portability.R")',
  "pde_materialize_raw_result(",
  "pde_verify_raw_file_in_fresh_r(",
  "saveRDS(result, temporary, compress = \"xz\")"
)
assert(all(vapply(fetch_tokens, grepl, logical(1), x = fetch_text, fixed = TRUE)),
       "fetch script is missing a portable raw-RDS boundary")
fetch_positions <- vapply(
  c("pde_materialize_raw_result(",
    "saveRDS(result, temporary, compress = \"xz\")",
    "pde_verify_raw_file_in_fresh_r(",
    "file.rename(temporary, destination)"),
  function(token) regexpr(token, fetch_text, fixed = TRUE)[[1L]],
  integer(1)
)
assert(all(fetch_positions > 0L) && identical(order(fetch_positions), 1:4),
       "fetch script does not materialize, save, child-verify, then publish in order")
assert(grepl("pde_validate_raw_result(raw", bundle_text, fixed = TRUE) &&
       grepl("pde_validate_consumed_mask(", bundle_text, fixed = TRUE),
       "bundle script lacks portable-frame or detailed mask validation")

raw_artifact_start <- regexpr(
  'name: plant-diversity-raw-${{ github.sha }}', workflow_text, fixed = TRUE
)[[1L]]
build_job_start <- regexpr("\n  build_candidate:", workflow_text, fixed = TRUE)[[1L]]
assert(raw_artifact_start > 0L && build_job_start > raw_artifact_start,
       "refresh workflow lacks a bounded raw-artifact upload block")
raw_artifact_block <- substr(workflow_text, raw_artifact_start, build_job_start - 1L)
assert(grepl("retention-days: 7", raw_artifact_block, fixed = TRUE),
       "raw refresh evidence must remain available for seven days")

publisher_tokens <- c(
  'remote_master=$(git rev-parse origin/master)',
  'if [ "$remote_master" != "$GITHUB_SHA" ]',
  'if [ "$(git rev-parse HEAD^)" != "$GITHUB_SHA" ]',
  'if [ "$pushed_commit" != "$published_commit" ]',
  "--json url,baseRefName,headRefName,headRefOid,isDraft",
  "Open a reviewer-authenticated draft PR",
  "Approve exact-head draft-review checks"
)
assert(all(vapply(
  publisher_tokens, grepl, logical(1), x = workflow_text, fixed = TRUE
)), "refresh publisher is missing an exact-head/draft-review identity gate")
assert(!grepl("gh pr create", workflow_text, fixed = TRUE) &&
       !grepl("gh pr ready", workflow_text, fixed = TRUE),
       "refresh publisher must not create or change PR review state with GITHUB_TOKEN")

cat("Raw RDS portability and fresh-process fixtures passed.\n")
