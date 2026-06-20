# ===========================================================================
# build_completeness_index.R — precompute each site's Expected-vs-Observed
# completeness (% of the NRCS reference flora NEON detected) into a tiny index
# the splash picker can colour by, WITHOUT reading 46 bundles at app boot.
# Writes data/expected/completeness_index.rds = data.frame(site, pct_detected,
# n_ref, n_overlap, dom_obs, dom_total). Re-runnable; run after the expected
# lists / authority are (re)built. Build-only.
# ===========================================================================
setwd("C:/Users/tsgil/OneDrive/Documents/VGS - R/NEON-Plant-Diversity")
suppressWarnings(suppressMessages({ library(dplyr) }))
source("R/plant_helpers.R"); source("R/expected_qc.R")
auth <- load_plant_authority()

sites <- sort(sub("\\.rds$", "", list.files("data/sites", pattern = "\\.rds$")))
rows <- list()
for (s in sites) {
  e <- load_expected(s); if (is.null(e)) next            # no reference list -> NA (omit)
  b <- tryCatch(readRDS(file.path("data/sites", paste0(s, ".rds"))), error = function(err) NULL)
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
saveRDS(idx, "data/expected/completeness_index.rds", compress = "xz")
cat("\ncompleteness_index.rds:", nrow(idx), "sites with a reference list\n")
