#!/usr/bin/env Rscript

# Fetch a complete, explicit-vintage raw candidate for DP1.10058.001.
# This is a fetch-runtime script only: release automation runs it under R 4.1.1
# into a new staging directory and never gives that job repository write access.

suppressPackageStartupMessages(library(neonUtilities))
source("R/site_metadata.R")

read_required_env <- function(name) {
  value <- trimws(Sys.getenv(name, ""))
  if (!nzchar(value))
    stop(sprintf("%s is required for a reproducible fetch", name), call. = FALSE)
  value
}

outdir <- Sys.getenv("PDE_RAW_OUT_DIR", "../plant-data-fetch")
start_d <- Sys.getenv("PDE_FETCH_START", "2013-01")
end_d <- read_required_env("PDE_FETCH_END")
token <- read_required_env("NEON_TOKEN")

if (!grepl("^[0-9]{4}-[0-9]{2}$", start_d) ||
    !grepl("^[0-9]{4}-[0-9]{2}$", end_d))
  stop("PDE_FETCH_START and PDE_FETCH_END must use YYYY-MM", call. = FALSE)
if (start_d > end_d)
  stop("PDE_FETCH_START must not be later than PDE_FETCH_END", call. = FALSE)

args <- commandArgs(trailingOnly = TRUE)
requested <- if (length(args)) unique(args) else as.character(neon_sites$site)
unknown <- setdiff(requested, neon_sites$site)
if (length(unknown))
  stop(sprintf("Unknown site code(s): %s", paste(unknown, collapse = ", ")),
       call. = FALSE)
requested <- sort(requested)

dir.create(outdir, showWarnings = FALSE, recursive = TRUE)
existing <- list.files(outdir, pattern = "_raw[.]rds$", full.names = FALSE)
if (length(existing))
  stop(sprintf("Raw staging must be empty; found: %s", paste(existing, collapse = ", ")),
       call. = FALSE)

failed <- character(0)
for (site in requested) {
  destination <- file.path(outdir, paste0(site, "_raw.rds"))
  cat(sprintf("=== fetching %s (%s..%s) ===\n", site, start_d, end_d))
  flush.console()
  result <- tryCatch(
    neonUtilities::loadByProduct(
      dpID = "DP1.10058.001", site = site,
      startdate = start_d, enddate = end_d,
      package = "basic", check.size = "FALSE", token = token
    ),
    error = function(error) {
      message(sprintf("FETCH FAILED [%s]: %s", site, conditionMessage(error)))
      NULL
    }
  )

  if (is.null(result) || is.null(result$div_1m2Data) ||
      !is.data.frame(result$div_1m2Data) || nrow(result$div_1m2Data) == 0L ||
      is.null(result$div_10m2Data100m2Data) ||
      !is.data.frame(result$div_10m2Data100m2Data) ||
      nrow(result$div_10m2Data100m2Data) == 0L) {
    failed <- c(failed, site)
    next
  }

  temporary <- tempfile(pattern = paste0(site, "-"), tmpdir = outdir,
                        fileext = ".rds.tmp")
  saveRDS(result, temporary, compress = "xz")
  if (!file.rename(temporary, destination)) {
    unlink(temporary)
    failed <- c(failed, site)
    next
  }
  cat(sprintf("saved %s: %d 1m2 rows, %d 10/100m2 rows\n",
              basename(destination), nrow(result$div_1m2Data),
              nrow(result$div_10m2Data100m2Data)))
  rm(result)
  invisible(gc())
}

files <- list.files(outdir, pattern = "_raw[.]rds$", full.names = TRUE)
actual <- sort(sub("_raw[.]rds$", "", basename(files)))
small <- files[is.na(file.info(files)$size) | file.info(files)$size <= 5000]

if (length(failed) || !identical(actual, requested) || length(small)) {
  stop(sprintf(
    paste0("RAW CANDIDATE REJECTED: failed=[%s] missing=[%s] extra=[%s] ",
           "undersized=[%s]"),
    paste(sort(unique(failed)), collapse = ","),
    paste(setdiff(requested, actual), collapse = ","),
    paste(setdiff(actual, requested), collapse = ","),
    paste(basename(small), collapse = ",")
  ), call. = FALSE)
}

cat(sprintf("RAW CANDIDATE PASSED: %d/%d sites through %s.\n",
            length(actual), length(requested), end_d))
