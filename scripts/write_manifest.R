# ===========================================================================
# write_manifest.R — (re)generate manifest.json for a lean, bundle-only
# Posit Connect Cloud deploy (git-backed).
#
# Bundles ONLY what the running app needs: global/ui/server + R/ + www/ + the
# precomputed indexes (data/*.rds) + the per-site bundles (data/sites/*.rds) +
# the demo sample. It does NOT bundle scripts/, docs/, rsconnect/, or the README.
#
# neonUtilities is intentionally EXCLUDED — it's referenced dynamically in
# global.R (.NEON_PKG) so the dependency scanner never pins it, keeping the
# deploy lean (no wasm build; live-pull-on-cold-worker is a hang risk). The
# deployed app is bundle-only; the optional live-fetch still works in local dev.
#
# Run with an R that has the app's runtime packages (R 4.3.1 here has them all):
#   "C:\Program Files\R\R-4.3.1\bin\Rscript.exe" scripts/write_manifest.R
# Re-run whenever runtime dependencies change, then commit manifest.json.
# ===========================================================================
suppressMessages(library(rsconnect))

appFiles <- c(
  "global.R", "ui.R", "server.R",
  list.files("R", pattern = "\\.R$", full.names = TRUE),
  list.files("www", recursive = TRUE, full.names = TRUE),
  Sys.glob("data/*.rds"),                                       # precomputed indexes (incl. search_index.rds)
  "data/search_index.rds",                                      # the "Search the network" index (explicit; also caught by the glob)
  list.files("data/sites", pattern = "\\.rds$", full.names = TRUE),
  list.files("data/env",   pattern = "\\.rds$", full.names = TRUE),   # env overlays
  # RUNTIME-CRITICAL reference data the app loads on the Expected-vs-Observed
  # lens (the EcoPlot QC). The top-level data/*.rds glob does NOT reach these
  # subfolders, so list them explicitly or a CI regen silently drops them and
  # the QC buckets go dark in production.
  list.files("data/expected", pattern = "\\.rds$", full.names = TRUE),   # per-site NRCS reference lists + completeness index + provenance
  "data/authority/plants_lookup.rds",                                    # USDA PLANTS nativity + NEON synonym authority
  list.files("data-sample", pattern = "\\.rds$", full.names = TRUE)
)
# NOTE: data/authority/_profile_cache.rds is a BUILD-TIME artifact only (used by
# scripts/build_plant_authority.R); the running app never reads it, so it stays
# out of the bundle deliberately.
appFiles <- unique(appFiles[file.exists(appFiles)])

cat(sprintf("Writing manifest for %d files (%d site bundles)...\n",
            length(appFiles), length(list.files("data/sites", pattern = "\\.rds$"))))
rsconnect::writeManifest(appDir = ".", appFiles = appFiles)

# quick self-check
m <- readLines("manifest.json", warn = FALSE)
pkgs <- gsub('.*"([^"]+)": \\{', "\\1",
             grep('^\\s*"[A-Za-z0-9.]+": \\{\\s*$', m, value = TRUE))
cat(sprintf("manifest.json written: %d packages.\n", sum(grepl('"Source"', m))))

# ---- pin terra to the last release before the GDAL-3.8 multidim code (1.8-54) ----
# terra >= 1.8-54 ships gdal_multidimensional.cpp using a GDAL 3.8 call unguarded in
# releases, so it FAILS to compile against Connect Cloud's GDAL 3.4.1. Connect compiles
# from source regardless of repo. 1.8-50 is the last release before 1.8-54: it compiles
# on 3.4.1 and still satisfies raster's terra (>= 1.8-5). terra/raster are install-only
# (leaflet -> raster -> terra; app never calls terra) -> zero runtime impact. Also pin
# the repo to the RSPM jammy binary mirror for suite consistency.
local({
  mm <- jsonlite::fromJSON("manifest.json", simplifyVector = FALSE)
  if (!is.null(mm$packages$terra)) {
    mm$packages$terra$description$Version <- "1.8-50"
    if (!is.null(mm$packages$terra$description$RemoteSha)) mm$packages$terra$description$RemoteSha <- "1.8-50"
    jsonlite::write_json(mm, "manifest.json", auto_unbox = TRUE, pretty = TRUE, null = "null")
  }
  mtxt <- readLines("manifest.json", warn = FALSE)
  mtxt <- gsub("https://cloud.r-project.org", "https://packagemanager.posit.co/cran/__linux__/jammy/latest", mtxt, fixed = TRUE)
  mtxt <- gsub("https://packagemanager.posit.co/cran/latest", "https://packagemanager.posit.co/cran/__linux__/jammy/latest", mtxt, fixed = TRUE)
  writeLines(mtxt, "manifest.json")
  cat("Pinned terra to 1.8-50 + RSPM jammy repo.\n")
})

# HARD GATE: a leaked NEON-pull dependency must NEVER commit silently. The deploy
# is bundle-only + lean; neonUtilities is referenced by a computed name so the
# scanner can't pin it, but a stray library() or a future edit could re-leak it
# (or arrow, which only the live fetch needs). Parse the written manifest's
# package KEYS and stop() non-zero if any appear.
#
# neonUtilities + arrow are ALWAYS banned (their presence means the heavy live-
# pull stack leaked into a deploy that is meant to run on bundles only).
#
# data.table is conditionally banned: plotly *Imports* it, so a plotly app
# legitimately carries it (the suite's Mosquito-Pulse reference manifest does
# too). It is only a leak signal when NO runtime package explains it — i.e. when
# plotly is absent — which would mean it came in via the NEON fetch chain.
mj   <- tryCatch(jsonlite::fromJSON("manifest.json", simplifyVector = FALSE),
                 error = function(e) NULL)
keys <- if (!is.null(mj) && !is.null(mj$packages)) names(mj$packages) else character(0)

banned <- intersect(c("neonUtilities", "arrow"), keys)
if ("data.table" %in% keys && !("plotly" %in% keys))
  banned <- c(banned, "data.table")   # unexplained by plotly -> a real pull leak

if (length(banned))
  stop(sprintf("LEAKED manifest: NEON-pull package(s) present as keys: %s. Refusing to commit a non-lean manifest.",
               paste(banned, collapse = ", ")), call. = FALSE)
cat("OK: no leaked NEON-pull deps in the manifest (neonUtilities/arrow absent; data.table only via plotly). Lean bundle-only build.\n")
