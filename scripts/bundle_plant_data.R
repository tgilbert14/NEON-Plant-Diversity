# ===========================================================================
# Bundle NEON Plant presence & % cover (DP1.10058.001) into lean per-site .rds.
# Reads the raw loadByProduct dumps from ../plant-data-fetch/<SITE>_raw.rds
# (built by the mammal app's scripts/fetch_plant_demo.R with R-4.1.1) and writes
# data/sites/<SITE>.rds + a data-sample demo + data/site_index.rds.
# Run with any R (just readRDS/saveRDS). See docs/data-bundling-pattern.md.
#
# Each site bundle is list(occ=, ground=, meta=):
#   occ    — one row per taxon occurrence at a scale: plotID, subplotID, scale
#            (1/10/100 m^2), year, bout, taxonID, scientificName, taxonRank,
#            family, nativeStatusCode, nativity, percentCover (NA when scale>1 =
#            presence-only), is_species, plotType, nlcdClass, lat, lng.
#   ground — abiotic ground cover at 1 m^2 (soil/litter/rock/...): plotID,
#            subplotID, year, bout, otherVariables, percentCover.
# ===========================================================================
suppressWarnings(suppressMessages({ library(dplyr) }))
source("R/plant_helpers.R")   # share the EXACT site_invasion/latest_snapshot recipe with the app
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || (length(a) == 1 && is.na(a))) b else a

RAW <- "../plant-data-fetch"
DEMO  <- "SRER"   # the invasion-story demo (Lehmann lovegrass / buffelgrass)
# Process EVERY raw dump present in ../plant-data-fetch (so the all-site build is
# just "fetch more raw, re-run this"). Optional CLI subset: Rscript scripts/
# bundle_plant_data.R SRER JORN ...  — re-bundling is cheap (seconds/site).
.args <- commandArgs(trailingOnly = TRUE)
all_raw <- sub("_raw\\.rds$", "", list.files(RAW, pattern = "_raw\\.rds$"))
SITES <- if (length(.args)) intersect(.args, all_raw) else all_raw
if (!length(SITES)) stop("No <SITE>_raw.rds dumps found in ", RAW, " — run scripts/fetch_plant_all.R first.")

# scale (m^2) from the NEON subplotID encoding: 31_1_1 = 1, 31_10_1 = 10, 31_100 = 100
parse_scale <- function(x) {
  x <- as.character(x)
  dplyr::case_when(grepl("_100$", x) ~ 100L, grepl("_10_", x) ~ 10L,
                   grepl("_1_", x) ~ 1L, TRUE ~ NA_integer_)
}
# native-status -> a clean 3-bucket nativity (publish the Unknown rate; don't fake it)
nativity_of <- function(code) {
  dplyr::case_when(code == "N" ~ "Native", code == "I" ~ "Introduced",
                   TRUE ~ "Unknown")   # NI (ambiguous), UNK, NA all -> Unknown
}
is_species_rank <- function(rank, sci) {
  rank_ok <- is.na(rank) | rank %in% c("species", "subspecies", "variety", "speciesGroup")
  amb <- grepl("\\bsp\\.?$", ifelse(is.na(sci), "", sci)) | grepl("/", ifelse(is.na(sci), "", sci), fixed = TRUE)
  rank_ok & !amb
}

build_site <- function(site) {
  f <- file.path(RAW, paste0(site, "_raw.rds"))
  if (!file.exists(f)) { cat("  MISSING", f, "\n"); return(NULL) }
  r <- readRDS(f)
  d1 <- tibble::as_tibble(r$div_1m2Data)
  d2 <- tibble::as_tibble(r$div_10m2Data100m2Data)
  yr <- function(x) as.integer(substr(as.character(x), 1, 4))

  # 1 m^2 species (cover) ---------------------------------------------------
  cov_sp <- d1 %>% dplyr::filter(.data$divDataType %in% "plantSpecies", !is.na(.data$scientificName)) %>%
    dplyr::transmute(plotID, subplotID, scale = 1L, year = yr(endDate), bout = boutNumber,
                     taxonID, scientificName, taxonRank, family, nativeStatusCode,
                     nativity = nativity_of(nativeStatusCode),
                     percentCover = suppressWarnings(as.numeric(percentCover)),
                     plotType, nlcdClass,
                     decimalLatitude, decimalLongitude)
  # 10 / 100 m^2 presence ---------------------------------------------------
  pres <- d2 %>% dplyr::filter(!is.na(.data$scientificName)) %>%
    dplyr::transmute(plotID, subplotID, scale = parse_scale(subplotID), year = yr(endDate), bout = boutNumber,
                     taxonID, scientificName, taxonRank, family, nativeStatusCode,
                     nativity = nativity_of(nativeStatusCode),
                     percentCover = NA_real_, plotType, nlcdClass,
                     decimalLatitude, decimalLongitude)
  occ <- dplyr::bind_rows(cov_sp, pres) %>%
    dplyr::filter(!is.na(.data$scale), !is.na(.data$year)) %>%
    dplyr::mutate(is_species = is_species_rank(.data$taxonRank, .data$scientificName)) %>%
    dplyr::rename(lat = decimalLatitude, lng = decimalLongitude)

  # abiotic ground cover at 1 m^2 ------------------------------------------
  ground <- d1 %>% dplyr::filter(.data$divDataType %in% "otherVariables", !is.na(.data$otherVariables)) %>%
    dplyr::transmute(plotID, subplotID, year = yr(endDate), bout = boutNumber,
                     otherVariables, percentCover = suppressWarnings(as.numeric(percentCover))) %>%
    dplyr::filter(!is.na(.data$year))

  meta <- list(site = site,
               lat = stats::median(occ$lat, na.rm = TRUE),
               lng = stats::median(occ$lng, na.rm = TRUE),
               years = sort(unique(occ$year)))
  list(occ = occ, ground = ground, meta = meta)
}

dir.create("data/sites", showWarnings = FALSE, recursive = TRUE)
dir.create("data-sample", showWarnings = FALSE)
idx_rows <- list()
for (s in SITES) {
  cat("=== bundling", s, "===\n")
  b <- build_site(s); if (is.null(b)) next
  saveRDS(b, file.path("data/sites", paste0(s, ".rds")), compress = "xz")
  if (identical(s, DEMO)) saveRDS(b, file.path("data-sample", "demo.rds"), compress = "xz")
  occ <- b$occ
  snap <- latest_snapshot(occ)            # the same one-survey-per-plot snapshot the app uses
  sp <- species_level_only(snap)
  topfam <- names(sort(table(sp$family[!is.na(sp$family)]), decreasing = TRUE))[1]
  idx_rows[[s]] <- data.frame(
    site = s,
    richness = length(unique(sp$scientificName)),
    n_plots = length(unique(snap$plotID)),
    pct_introduced = site_invasion(snap),  # IDENTICAL recipe to the app hero -> never disagree
    dominant_family = if (is.null(topfam)) NA_character_ else topfam,
    lat = b$meta$lat, lng = b$meta$lng,
    stringsAsFactors = FALSE)
  cat(sprintf("  %s: %d species (snapshot), %d plots, %.1f%% introduced cover, top family %s | occ rows %d, ground %d | size %s\n",
      s, idx_rows[[s]]$richness, idx_rows[[s]]$n_plots, idx_rows[[s]]$pct_introduced %||% NA,
      idx_rows[[s]]$dominant_family, nrow(occ), nrow(b$ground),
      format(file.size(file.path("data/sites", paste0(s, ".rds"))), big.mark = ",")))
}
idx <- dplyr::bind_rows(idx_rows)
saveRDS(idx, "data/site_index.rds", compress = "xz")
cat("\nsite_index:\n"); print(idx)
cat("DONE\n")
