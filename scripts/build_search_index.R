#!/usr/bin/env Rscript

# Deterministically rebuild the network search index from a complete site bundle
# root. PDE_OUTPUT_ROOT permits isolated candidate builds; the default is the repo.

suppressWarnings(suppressMessages(library(dplyr)))
source("R/site_metadata.R")
source("R/plant_helpers.R")

root <- Sys.getenv("PDE_OUTPUT_ROOT", ".")
site_dir <- file.path(root, "data", "sites")
search_path <- file.path(root, "data", "search_index.rds")
site_index_path <- file.path(root, "data", "site_index.rds")
expected_sites <- sort(as.character(neon_sites$site))
sites <- sort(sub("[.]rds$", "", list.files(site_dir, pattern = "[.]rds$")))
if (!identical(sites, expected_sites))
  stop(sprintf("SEARCH SITE GATE FAILED: missing=[%s] extra=[%s]",
               paste(setdiff(expected_sites, sites), collapse = ","),
               paste(setdiff(sites, expected_sites), collapse = ",")),
       call. = FALSE)

taxa_for_site <- function(site) {
  bundle <- readRDS(file.path(site_dir, paste0(site, ".rds")))
  if (is.null(bundle$occ) || !nrow(bundle$occ))
    stop(sprintf("%s has no occurrence table", site), call. = FALSE)
  snapshot <- latest_snapshot(bundle$occ)
  species <- species_level_only(snapshot)
  if (is.null(species) || !nrow(species))
    stop(sprintf("%s has no species-level snapshot", site), call. = FALSE)

  plot_cover <- plot_species_cover(species)
  cover_by_species <- if (is.null(plot_cover)) NULL else plot_cover |>
    dplyr::group_by(.data$scientificName) |>
    dplyr::summarise(mean_cover = round(mean(.data$mean_cover), 2), .groups = "drop")
  years <- species_level_only(bundle$occ) |>
    dplyr::group_by(.data$scientificName) |>
    dplyr::summarise(
      year_min = suppressWarnings(min(.data$year, na.rm = TRUE)),
      year_max = suppressWarnings(max(.data$year, na.rm = TRUE)),
      .groups = "drop"
    )
  output <- species |>
    dplyr::group_by(.data$scientificName) |>
    dplyr::summarise(
      family = mode_chr(.data$family), nativity = mode_chr(.data$nativity),
      n_plots = dplyr::n_distinct(.data$plotID), .groups = "drop"
    ) |>
    dplyr::mutate(site = site)
  if (!is.null(cover_by_species))
    output <- dplyr::left_join(output, cover_by_species, by = "scientificName")
  if (!"mean_cover" %in% names(output)) output$mean_cover <- NA_real_
  output <- dplyr::left_join(output, years, by = "scientificName")
  output[, c("scientificName", "site", "family", "nativity", "mean_cover",
             "n_plots", "year_min", "year_max")]
}

bundles <- lapply(sites, function(site) readRDS(file.path(site_dir, paste0(site, ".rds"))))
receipts <- vapply(bundles, function(bundle) as.character(bundle$meta$built_at), character(1))
release_ids <- vapply(bundles, function(bundle) {
  value <- bundle$meta$neon_release
  if (is.null(value) || !length(value) || is.na(value)) "" else as.character(value)
}, character(1))

requested_date <- trimws(Sys.getenv("PDE_BUILD_DATE", ""))
requested_release <- trimws(Sys.getenv("NEON_RELEASE", ""))
if (nzchar(requested_date) && any(receipts != requested_date))
  stop("Site bundle build receipts do not match PDE_BUILD_DATE", call. = FALSE)
if (nzchar(requested_release) && any(release_ids != requested_release))
  stop("Site bundle release receipts do not match NEON_RELEASE", call. = FALSE)
parsed_receipts <- suppressWarnings(as.Date(receipts, format = "%Y-%m-%d"))
if (any(is.na(parsed_receipts)))
  stop("Every site bundle must carry a valid built_at receipt", call. = FALSE)

built_at <- if (nzchar(requested_date)) requested_date else max(receipts)
nonempty_releases <- sort(unique(release_ids[nzchar(release_ids)]))
if (length(nonempty_releases) > 1L)
  stop("Site bundles contain mixed NEON release receipts", call. = FALSE)
neon_release <- if (nzchar(requested_release)) requested_release else
  if (length(nonempty_releases)) nonempty_releases[[1L]] else NA_character_

taxa <- dplyr::bind_rows(lapply(sites, taxa_for_site))
taxa <- taxa[!is.na(taxa$scientificName) & nzchar(taxa$scientificName), , drop = FALSE]
taxa$year_min[!is.finite(taxa$year_min)] <- NA_integer_
taxa$year_max[!is.finite(taxa$year_max)] <- NA_integer_
taxa <- taxa[order(taxa$scientificName, taxa$site,
                   -dplyr::coalesce(taxa$mean_cover, -1), method = "radix"), , drop = FALSE]
rownames(taxa) <- NULL

site_index <- readRDS(site_index_path)
if (!is.data.frame(site_index) ||
    !identical(sort(as.character(site_index$site)), expected_sites))
  stop("data/site_index.rds is not the complete 46-site index", call. = FALSE)
site_index <- site_index[match(expected_sites, site_index$site), , drop = FALSE]
rownames(site_index) <- NULL

index <- list(
  taxa = tibble::as_tibble(taxa),
  sites = tibble::as_tibble(site_index),
  built_at = built_at,
  neon_release = neon_release
)
saveRDS(index, search_path, compress = "xz")
cat(sprintf("SEARCH INDEX PASSED: %d taxon-site rows, 46/46 sites, built_at=%s.\n",
            nrow(index$taxa), built_at))
