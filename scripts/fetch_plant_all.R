# ===========================================================================
# fetch_plant_all.R — pull raw NEON Plant presence & % cover (DP1.10058.001)
# for ALL terrestrial sites (or a CLI subset), RESUMABLE and CHUNKABLE so a
# 46-site sweep never has to run as one long blocking call.
#
# Needs neonUtilities (run with an R that has it; the README notes R-4.5.2 crashes
# on loadByProduct — use R-4.1.1/4.3.1 with neonUtilities installed). Writes the
# full loadByProduct list per site to ../plant-data-fetch/<SITE>_raw.rds; the
# bundler (scripts/bundle_plant_data.R) then trims each to a lean app bundle.
#
# RESUMABLE: skips any site whose _raw.rds already exists (delete one to re-pull).
# CHUNK IT so nothing hangs — run a handful of sites at a time, e.g.:
#   Rscript scripts/fetch_plant_all.R HARV BART BLAN SCBI SERC
#   Rscript scripts/fetch_plant_all.R DSNY JERC OSBS GUAN LAJA
# ...or pass no args to attempt every not-yet-fetched site in one (long) run.
# ===========================================================================

suppressPackageStartupMessages(library(neonUtilities))
source("R/site_metadata.R")   # canonical 46-site list (neon_sites$site)

# NEON API token raises the anonymous rate limit. Look in the usual places.
read_token <- function() {
  for (p in c(".neon_token", "../App-NEON-Small-Mammal-Tracker/.neon_token",
              "../.neon_token")) {
    t <- tryCatch(trimws(readLines(p, warn = FALSE))[1], error = function(e) "")
    if (!is.na(t) && nzchar(t) && nchar(t) > 20) { cat("Using NEON token from", p, "\n"); return(t) }
  }
  env <- Sys.getenv("NEON_TOKEN", "")
  if (nzchar(env)) { cat("Using NEON_TOKEN from the environment.\n"); return(env) }
  cat("No NEON token found — anonymous rate limits apply (slower).\n"); ""
}

outdir   <- "../plant-data-fetch"
dir.create(outdir, showWarnings = FALSE, recursive = TRUE)
tok      <- read_token()
start_d  <- "2013-01"
end_d    <- format(Sys.Date(), "%Y-%m")

.args <- commandArgs(trailingOnly = TRUE)
sites <- if (length(.args)) intersect(.args, neon_sites$site) else neon_sites$site
if (!length(sites)) stop("No valid sites requested. Valid: ", paste(neon_sites$site, collapse = ", "))

done <- 0L; skipped <- 0L; failed <- character(0)
for (s in sites) {
  f <- file.path(outdir, paste0(s, "_raw.rds"))
  if (file.exists(f) && file.size(f) > 5000) {            # resumable: already pulled
    cat("--- skip", s, "(already fetched)\n"); skipped <- skipped + 1L; next
  }
  cat("=== fetching", s, sprintf("(%s..%s) ===\n", start_d, end_d)); flush.console()
  res <- tryCatch(
    loadByProduct(dpID = "DP1.10058.001", site = s,
                  startdate = start_d, enddate = end_d,
                  package = "basic", check.size = "FALSE",
                  token = if (nzchar(tok)) tok else NA),
    error = function(e) { cat("  ERROR:", conditionMessage(e), "\n"); NULL })
  if (is.null(res) || is.null(res$div_1m2Data)) {
    cat("  no usable data for", s, "\n"); failed <- c(failed, s); flush.console(); next
  }
  saveRDS(res, f)
  n1  <- if (!is.null(res$div_1m2Data)) nrow(res$div_1m2Data) else 0
  n10 <- if (!is.null(res$div_10m2Data100m2Data)) nrow(res$div_10m2Data100m2Data) else 0
  cat(sprintf("  saved %s — div_1m2 rows: %d | div_10m2/100m2 rows: %d | %s\n",
              s, n1, n10, format(file.size(f), big.mark = ",")))
  done <- done + 1L; flush.console()
}
cat(sprintf("\nDONE — fetched %d, skipped %d (already had), failed %d%s.\n",
            done, skipped, length(failed),
            if (length(failed)) paste0(": ", paste(failed, collapse = ", ")) else ""))
cat("Next: Rscript scripts/bundle_plant_data.R   (bundles every raw dump present)\n")
