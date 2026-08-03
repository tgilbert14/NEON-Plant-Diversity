#!/usr/bin/env Rscript

# Verify one serialized raw Plant Diversity fetch in a clean base-R process.
# This script deliberately does not load Arrow, neonUtilities, tibble, or dplyr.

file_args <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (!length(file_args)) stop("Run this verifier with Rscript", call. = FALSE)
script_path <- normalizePath(
  sub("^--file=", "", file_args[[1L]]), winslash = "/", mustWork = TRUE
)
repo_root <- dirname(dirname(script_path))
source(file.path(repo_root, "scripts", "plant_raw_portability.R"))
source(file.path(repo_root, "R", "source_receipt.R"))

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 4L) stop(
  paste(
    "Usage: verify_raw_portability.R",
    "RAW_RDS SITE SOURCE_START_DATE SOURCE_CUTOFF_DATE"
  ),
  call. = FALSE
)
raw_path <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
site <- args[[2L]]
source_start_date <- args[[3L]]
source_cutoff_date <- args[[4L]]

forbidden_namespaces <- c("arrow", "neonUtilities")
loaded_forbidden <- intersect(forbidden_namespaces, loadedNamespaces())
if (length(loaded_forbidden)) stop(sprintf(
  "Fresh-R verifier unexpectedly loaded: %s",
  paste(loaded_forbidden, collapse = ", ")
), call. = FALSE)

raw <- readRDS(raw_path)
loaded_forbidden <- intersect(forbidden_namespaces, loadedNamespaces())
if (length(loaded_forbidden)) stop(sprintf(
  "Reading the raw RDS required hidden namespace(s): %s",
  paste(loaded_forbidden, collapse = ", ")
), call. = FALSE)

required_tables <- c("div_1m2Data", "div_10m2Data100m2Data")
pde_require_raw_tables(raw, required_tables, sprintf("%s raw", site))
pde_validate_raw_result(raw, sprintf("%s raw", site))

d1 <- raw$div_1m2Data
d2 <- raw$div_10m2Data100m2Data
pde_require_columns(
  d1, "div_1m2Data",
  c("divDataType", "scientificName", "otherVariables", "endDate")
)
pde_require_columns(
  d2, "div_10m2Data100m2Data", c("scientificName", "endDate")
)

# Recreate the builder's science masks here rather than accepting a producer
# receipt. Missing names stay excluded; no missing opportunity becomes zero.
d1_consumed <-
  (as.character(d1$divDataType) == "plantSpecies" & !is.na(d1$scientificName)) |
  (as.character(d1$divDataType) == "otherVariables" & !is.na(d1$otherVariables))
d2_consumed <- !is.na(d2$scientificName)
pde_validate_consumed_mask(
  d1_consumed, d1, "div_1m2Data",
  c("divDataType", "scientificName", "otherVariables")
)
pde_validate_consumed_mask(
  d2_consumed, d2, "div_10m2Data100m2Data", "scientificName"
)
validate_plant_source_rows(
  d1, site, "div_1m2Data", source_start_date, source_cutoff_date, d1_consumed
)
validate_plant_source_rows(
  d2, site, "div_10m2Data100m2Data",
  source_start_date, source_cutoff_date, d2_consumed
)

cat(sprintf(
  "RAW PORTABILITY PASSED [%s]: %d 1m2 rows, %d 10/100m2 rows; no Arrow/neonUtilities namespace.\n",
  site, nrow(d1), nrow(d2)
))
