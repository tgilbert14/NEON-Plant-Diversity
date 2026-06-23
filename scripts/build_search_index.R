# ===========================================================================
# build_search_index.R — the "Search the network" precomputed index.
#
# READS the committed per-site bundles (data/sites/*.rds) — NOT a live fetch —
# and the precomputed data/site_index.rds, and writes ONE small file
# data/search_index.rds that the app loads once at boot (like site_index) and
# filters in memory. No live calls, instant search.
#
# search_index.rds is list(taxa=, sites=):
#   taxa  — one row per (scientificName, site) the taxon occurs at:
#             scientificName, site, family, nativity, mean_cover (the app's
#             honest per-site % cover unit, NA where presence-only),
#             n_plots, year_min, year_max. Drives FIND-A-TAXON.
#   sites — reuse of site_index (site, richness, n_plots, pct_introduced,
#             dominant_family, lat, lng). Drives the THRESHOLD query.
#
# The cover unit is the SAME recipe the app uses everywhere: plot_species_cover()
# = mean over a plot's sampled 1 m^2 subplots, then mean across plots. Computed on
# the honest latest_snapshot() (one survey per plot), species-level IDs only — so
# the index can never disagree with what a site's Overview shows.
#
# Run:  "C:\Program Files\R\R-4.5.2\bin\Rscript.exe" scripts/build_search_index.R
# (plain readRDS/saveRDS + dplyr; any modern R works.)
# ===========================================================================
suppressWarnings(suppressMessages({ library(dplyr) }))
source("R/plant_helpers.R")   # the EXACT cover / snapshot recipe the app uses

SITE_DIR <- "data/sites"
sites <- sub("\\.rds$", "", list.files(SITE_DIR, pattern = "\\.rds$"))
if (!length(sites)) stop("No site bundles in ", SITE_DIR, " — run scripts/bundle_plant_data.R first.")

# per-site taxon rows: species-level, on the honest one-survey-per-plot snapshot.
# mean_cover = mean across plots of the plot's mean 1 m^2 cover for the taxon
# (the same plot_species_cover() the Overview / leaderboard use). Presence-only
# taxa (never scored at 1 m^2) carry NA cover but still appear (they ARE present).
taxa_for_site <- function(site) {
  b <- tryCatch(readRDS(file.path(SITE_DIR, paste0(site, ".rds"))), error = function(e) NULL)
  if (is.null(b) || is.null(b$occ) || !nrow(b$occ)) return(NULL)
  snap <- latest_snapshot(b$occ)
  sp   <- species_level_only(snap)
  if (is.null(sp) || !nrow(sp)) return(NULL)

  # the per-(plot,species) cover, then mean across plots -> the site cover unit
  psc <- plot_species_cover(sp)
  cover_by_sp <- if (is.null(psc)) NULL else psc %>%
    dplyr::group_by(.data$scientificName) %>%
    dplyr::summarise(mean_cover = round(mean(.data$mean_cover), 2), .groups = "drop")

  # one row per species: family / nativity (modal), plots present, year span.
  # year span from the FULL bundle (not just the snapshot) so "first/last seen"
  # reflects every survey the taxon appears in.
  yr_by_sp <- species_level_only(b$occ) %>%
    dplyr::group_by(.data$scientificName) %>%
    dplyr::summarise(year_min = suppressWarnings(min(.data$year, na.rm = TRUE)),
                     year_max = suppressWarnings(max(.data$year, na.rm = TRUE)),
                     .groups = "drop")

  out <- sp %>%
    dplyr::group_by(.data$scientificName) %>%
    dplyr::summarise(family   = mode_chr(.data$family),
                     nativity = mode_chr(.data$nativity),
                     n_plots  = dplyr::n_distinct(.data$plotID),
                     .groups  = "drop") %>%
    dplyr::mutate(site = site)
  if (!is.null(cover_by_sp)) out <- dplyr::left_join(out, cover_by_sp, by = "scientificName")
  if (!"mean_cover" %in% names(out)) out$mean_cover <- NA_real_
  out <- dplyr::left_join(out, yr_by_sp, by = "scientificName")
  out[, c("scientificName", "site", "family", "nativity", "mean_cover",
          "n_plots", "year_min", "year_max")]
}

cat("Building taxon-occurrence index from", length(sites), "site bundles...\n")
taxa <- dplyr::bind_rows(lapply(sites, function(s) { cat("  ", s, "\n"); taxa_for_site(s) }))
taxa <- taxa[!is.na(taxa$scientificName) & nzchar(taxa$scientificName), , drop = FALSE]
taxa$year_min[!is.finite(taxa$year_min)] <- NA_integer_
taxa$year_max[!is.finite(taxa$year_max)] <- NA_integer_
taxa <- taxa[order(taxa$scientificName, -dplyr::coalesce(taxa$mean_cover, -1)), ]

# the site-level table for the threshold query: reuse the canonical site_index so
# the % introduced numbers are IDENTICAL to the hero / picker (never re-derive).
sites_tbl <- tryCatch(readRDS("data/site_index.rds"), error = function(e) NULL)
if (is.null(sites_tbl)) stop("data/site_index.rds missing — run scripts/bundle_plant_data.R first.")

idx <- list(taxa = tibble::as_tibble(taxa),
            sites = tibble::as_tibble(sites_tbl),
            built_at = format(Sys.Date(), "%Y-%m-%d"))
saveRDS(idx, "data/search_index.rds", compress = "xz")

cat(sprintf("\nsearch_index.rds written: %s\n  %d taxon-site rows | %d distinct taxa | %d sites | size %s\n",
            "data/search_index.rds", nrow(idx$taxa),
            dplyr::n_distinct(idx$taxa$scientificName), nrow(idx$sites),
            format(file.size("data/search_index.rds"), big.mark = ",")))
cat("DONE\n")
