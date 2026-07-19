#!/usr/bin/env Rscript

# Deterministically rebuild the network search index from a complete site bundle
# root. PDE_OUTPUT_ROOT permits isolated candidate builds; the default is the repo.

suppressWarnings(suppressMessages(library(dplyr)))
source("R/site_metadata.R")
source("R/source_receipt.R")
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

site_index <- readRDS(site_index_path)
if (!is.data.frame(site_index) ||
    !identical(sort(as.character(site_index$site)), expected_sites))
  stop("data/site_index.rds is not the complete 46-site index", call. = FALSE)

taxa_for_site <- function(site, bundle) {
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

bundles <- stats::setNames(
  lapply(sites, function(site) readRDS(file.path(site_dir, paste0(site, ".rds")))),
  sites
)
bundle_metas <- lapply(bundles, `[[`, "meta")
source_status <- resolve_plant_source_set(
  site_dir, site_index, expected_sites, bundle_metas,
  require_bundle_metas = TRUE
)

requested_date <- trimws(Sys.getenv("PDE_BUILD_DATE", ""))
requested_release <- trimws(Sys.getenv("NEON_RELEASE", ""))
requested_start <- trimws(Sys.getenv("PDE_SOURCE_START", ""))
requested_cutoff <- trimws(Sys.getenv("PDE_SOURCE_CUTOFF", ""))
requested_receipt <- trimws(Sys.getenv("PDE_SOURCE_RECEIPT_ID", ""))
requested_package <- trimws(Sys.getenv("PDE_QUERY_PACKAGE", ""))
requested_neon_version <- trimws(Sys.getenv("PDE_NEON_UTILITIES_VERSION", ""))
requested_digest <- trimws(Sys.getenv("PDE_SOURCE_DIGEST", ""))
requested_commit <- trimws(Sys.getenv("PDE_BUILDER_COMMIT", ""))
if (nzchar(requested_date) &&
    (is.na(source_status$built_at) ||
     !identical(source_status$built_at, requested_date)))
  stop("Site bundle build receipts do not match PDE_BUILD_DATE", call. = FALSE)
if (nzchar(requested_release) &&
    (is.na(source_status$neon_release) ||
     !identical(source_status$neon_release, requested_release)))
  stop("Site bundle release receipts do not match NEON_RELEASE", call. = FALSE)
if (nzchar(requested_start) &&
    !identical(source_status$source_start, requested_start))
  stop("Site source receipts do not match PDE_SOURCE_START", call. = FALSE)
if (nzchar(requested_cutoff) &&
    !identical(source_status$source_cutoff, requested_cutoff))
  stop("Site source receipts do not match PDE_SOURCE_CUTOFF", call. = FALSE)
if (nzchar(requested_receipt) &&
    !identical(source_status$source_receipt_id, requested_receipt))
  stop("Site source receipts do not match PDE_SOURCE_RECEIPT_ID", call. = FALSE)
if (nzchar(requested_package) &&
    !identical(source_status$query_package, requested_package))
  stop("Site source receipts do not match PDE_QUERY_PACKAGE", call. = FALSE)
if (nzchar(requested_neon_version) &&
    !identical(source_status$neon_utilities_version, requested_neon_version))
  stop("Site source receipts do not match PDE_NEON_UTILITIES_VERSION", call. = FALSE)
if (nzchar(requested_digest) &&
    !identical(source_status$source_digest, requested_digest))
  stop("Site source receipts do not match PDE_SOURCE_DIGEST", call. = FALSE)
if (nzchar(requested_commit) &&
    !identical(source_status$bundle_commit, requested_commit))
  stop("Site source receipts do not match PDE_BUILDER_COMMIT", call. = FALSE)

site_index <- site_index[match(expected_sites, site_index$site), , drop = FALSE]
rownames(site_index) <- NULL

taxa <- dplyr::bind_rows(Map(taxa_for_site, sites, bundles))
taxa <- taxa[!is.na(taxa$scientificName) & nzchar(taxa$scientificName), , drop = FALSE]
taxa$year_min[!is.finite(taxa$year_min)] <- NA_integer_
taxa$year_max[!is.finite(taxa$year_max)] <- NA_integer_
taxa <- taxa[order(taxa$scientificName, taxa$site,
                   -dplyr::coalesce(taxa$mean_cover, -1), method = "radix"), , drop = FALSE]
rownames(taxa) <- NULL

index <- list(
  taxa = tibble::as_tibble(taxa),
  sites = tibble::as_tibble(site_index),
  built_at = source_status$built_at,
  repository_imported_at = source_status$repository_imported_at,
  neon_release = source_status$neon_release,
  source_start = source_status$source_start,
  source_cutoff = source_status$source_cutoff,
  source_receipt_id = source_status$source_receipt_id,
  source_digest = source_status$source_digest,
  source_receipt_basis = source_status$receipt_basis,
  source_provenance_class = source_status$provenance_class,
  source_bundle_commit = source_status$bundle_commit,
  query_package = source_status$query_package,
  neon_utilities_version = source_status$neon_utilities_version
)
saveRDS(index, search_path, compress = "xz")
cat(sprintf(
  "SEARCH INDEX PASSED: %d taxon-site rows, 46/46 sites, provenance=%s.\n",
  nrow(index$taxa), source_status$provenance_class
))
