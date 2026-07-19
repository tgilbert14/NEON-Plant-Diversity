# ===========================================================================
# build_completeness_index.R — precompute each site's Expected-vs-Observed
# completeness (% of the NRCS reference flora NEON detected) into a tiny index
# the splash picker can colour by, WITHOUT reading 46 bundles at app boot.
# Writes data/expected/completeness_index.rds = data.frame(site, pct_detected,
# n_ref, n_overlap, dom_obs, dom_total). Re-runnable; run after the expected
# lists / authority are (re)built. Build-only.
# ===========================================================================
suppressWarnings(suppressMessages({ library(dplyr) }))

resolve_repo_root <- function() {
  override <- trimws(Sys.getenv("PDE_REPO_ROOT", ""))
  script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  starts <- character()
  if (nzchar(override)) starts <- c(starts, override)
  if (length(script_arg)) {
    script_file <- sub("^--file=", "", script_arg[[1L]])
    starts <- c(starts, dirname(normalizePath(script_file, winslash = "/", mustWork = TRUE)))
  }
  starts <- c(starts, getwd())
  for (start in unique(starts)) {
    current <- normalizePath(start, winslash = "/", mustWork = TRUE)
    repeat {
      if (file.exists(file.path(current, "R", "plant_helpers.R")) &&
          file.exists(file.path(current, "scripts", "build_completeness_index.R"))) {
        return(current)
      }
      parent <- dirname(current)
      if (identical(parent, current)) break
      current <- parent
    }
  }
  stop(
    "Could not locate the NEON-Plant-Diversity repository. Set PDE_REPO_ROOT explicitly.",
    call. = FALSE
  )
}

REPO_ROOT <- resolve_repo_root()
source(file.path(REPO_ROOT, "R", "plant_helpers.R"))
source(file.path(REPO_ROOT, "R", "expected_qc.R"))
env_path <- function(name, fallback) {
  value <- trimws(Sys.getenv(name, ""))
  if (nzchar(value)) normalizePath(value, winslash = "/", mustWork = TRUE) else fallback
}
BUILD_SITE_DIR <- env_path("PDE_SITE_DIR", file.path(REPO_ROOT, "data", "sites"))
BUILD_EXPECTED_DIR <- env_path("PDE_EXPECTED_DIR", file.path(REPO_ROOT, "data", "expected"))
BUILD_AUTHORITY_RDS <- env_path(
  "PDE_AUTHORITY_RDS", file.path(REPO_ROOT, "data", "authority", "plants_lookup.rds"))
BUILD_COMPLETENESS_OUT <- trimws(Sys.getenv("PDE_COMPLETENESS_OUT", ""))
if (!nzchar(BUILD_COMPLETENESS_OUT))
  BUILD_COMPLETENESS_OUT <- file.path(BUILD_EXPECTED_DIR, "completeness_index.rds")
BUILD_COMPLETENESS_OUT <- normalizePath(
  BUILD_COMPLETENESS_OUT, winslash = "/", mustWork = FALSE)
auth <- load_plant_authority(BUILD_AUTHORITY_RDS)

sites <- sort(sub("\\.rds$", "", list.files(BUILD_SITE_DIR, pattern = "\\.rds$")))
rows <- list()
for (s in sites) {
  e <- load_expected(s, BUILD_EXPECTED_DIR); if (is.null(e)) next # no reference list -> NA (omit)
  b <- tryCatch(readRDS(file.path(BUILD_SITE_DIR, paste0(s, ".rds"))), error = function(err) NULL)
  if (is.null(b) || is.null(b$occ)) next
  ev <- tryCatch(expected_vs_observed(b$occ, e, auth), error = function(err) NULL)
  if (is.null(ev)) next
  rows[[s]] <- data.frame(site = s, pct_detected = ev$overlap_pct,
    n_ref = ev$n_ref, n_overlap = ev$n_overlap,
    dom_obs = ev$dom_obs, dom_total = ev$dom_total, stringsAsFactors = FALSE)
  cat(sprintf("%-5s %.0f%% (%d/%d)\n", s, ev$overlap_pct, ev$n_overlap, ev$n_ref))
}
idx <- if (length(rows)) do.call(rbind, rows) else
  data.frame(site = character(), pct_detected = numeric())
dir.create(dirname(BUILD_COMPLETENESS_OUT), recursive = TRUE, showWarnings = FALSE)
saveRDS(idx, BUILD_COMPLETENESS_OUT, compress = "xz")
cat("\ncompleteness_index.rds:", nrow(idx), "sites with a reference list\n")
