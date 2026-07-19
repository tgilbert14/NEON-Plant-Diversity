#!/usr/bin/env Rscript

# Build the complete DP1.10058.001 app bundle in an isolated output root.
# Release automation supplies an explicit build date and source-release receipt,
# builds twice from the same raw staging, and compares every produced byte.

suppressWarnings(suppressMessages(library(dplyr)))
source("R/site_metadata.R")
source("R/plant_helpers.R")

`%||%` <- function(a, b) {
  if (is.null(a) || length(a) == 0L || (length(a) == 1L && is.na(a))) b else a
}

required_env <- function(name) {
  value <- trimws(Sys.getenv(name, ""))
  if (!nzchar(value))
    stop(sprintf("%s is required for a deterministic bundle", name), call. = FALSE)
  value
}

raw_dir <- Sys.getenv("PDE_RAW_DIR", "../plant-data-fetch")
output_root <- Sys.getenv("PDE_OUTPUT_ROOT", ".")
build_date <- required_env("PDE_BUILD_DATE")
neon_release <- required_env("NEON_RELEASE")
demo_site <- "SRER"

parsed_build_date <- suppressWarnings(as.Date(build_date, format = "%Y-%m-%d"))
if (is.na(parsed_build_date) || !grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", build_date))
  stop("PDE_BUILD_DATE must be an ISO date (YYYY-MM-DD)", call. = FALSE)

expected_sites <- sort(as.character(neon_sites$site))
raw_files <- list.files(raw_dir, pattern = "_raw[.]rds$", full.names = TRUE)
raw_sites <- sort(sub("_raw[.]rds$", "", basename(raw_files)))
if (!identical(raw_sites, expected_sites))
  stop(sprintf("RAW SITE GATE FAILED: missing=[%s] extra=[%s]",
               paste(setdiff(expected_sites, raw_sites), collapse = ","),
               paste(setdiff(raw_sites, expected_sites), collapse = ",")),
       call. = FALSE)

site_dir <- file.path(output_root, "data", "sites")
sample_dir <- file.path(output_root, "data-sample")
dir.create(site_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(sample_dir, recursive = TRUE, showWarnings = FALSE)
old_site_files <- list.files(site_dir, pattern = "[.]rds$", full.names = TRUE)
if (length(old_site_files)) unlink(old_site_files)

parse_scale <- function(value) {
  value <- as.character(value)
  dplyr::case_when(
    grepl("_100$", value) ~ 100L,
    grepl("_10_", value) ~ 10L,
    grepl("_1_", value) ~ 1L,
    TRUE ~ NA_integer_
  )
}

nativity_of <- function(code) {
  dplyr::case_when(
    code == "N" ~ "Native",
    code == "I" ~ "Introduced",
    TRUE ~ "Unknown"
  )
}

is_species_rank <- function(rank, scientific_name) {
  rank_ok <- is.na(rank) | rank %in% c("species", "subspecies", "variety", "speciesGroup")
  ambiguous <- grepl("\\bsp\\.?$", ifelse(is.na(scientific_name), "", scientific_name)) |
    grepl("/", ifelse(is.na(scientific_name), "", scientific_name), fixed = TRUE)
  rank_ok & !ambiguous
}

stable_order <- function(frame, columns) {
  columns <- intersect(columns, names(frame))
  if (!length(columns) || !nrow(frame)) return(frame)
  keys <- lapply(frame[columns], function(value) {
    value <- as.character(value)
    value[is.na(value)] <- ""
    value
  })
  frame[do.call(order, c(keys, list(na.last = TRUE, method = "radix"))), , drop = FALSE]
}

build_site <- function(site) {
  raw <- readRDS(file.path(raw_dir, paste0(site, "_raw.rds")))
  if (is.null(raw$div_1m2Data) || is.null(raw$div_10m2Data100m2Data))
    stop(sprintf("%s raw dump lacks required product tables", site), call. = FALSE)
  d1 <- tibble::as_tibble(raw$div_1m2Data)
  d2 <- tibble::as_tibble(raw$div_10m2Data100m2Data)
  year_of <- function(value) as.integer(substr(as.character(value), 1L, 4L))

  cover <- d1 |>
    dplyr::filter(.data$divDataType %in% "plantSpecies", !is.na(.data$scientificName)) |>
    dplyr::transmute(
      plotID, subplotID, scale = 1L, year = year_of(endDate), bout = boutNumber,
      taxonID, scientificName, taxonRank, family, nativeStatusCode,
      nativity = nativity_of(nativeStatusCode),
      percentCover = suppressWarnings(as.numeric(percentCover)),
      plotType, nlcdClass, decimalLatitude, decimalLongitude
    )
  presence <- d2 |>
    dplyr::filter(!is.na(.data$scientificName)) |>
    dplyr::transmute(
      plotID, subplotID, scale = parse_scale(subplotID), year = year_of(endDate),
      bout = boutNumber, taxonID, scientificName, taxonRank, family,
      nativeStatusCode, nativity = nativity_of(nativeStatusCode),
      percentCover = NA_real_, plotType, nlcdClass,
      decimalLatitude, decimalLongitude
    )
  occurrence <- dplyr::bind_rows(cover, presence) |>
    dplyr::filter(!is.na(.data$scale), !is.na(.data$year)) |>
    dplyr::mutate(is_species = is_species_rank(.data$taxonRank, .data$scientificName)) |>
    dplyr::rename(lat = decimalLatitude, lng = decimalLongitude)
  occurrence <- stable_order(
    occurrence,
    c("plotID", "subplotID", "scale", "year", "bout", "scientificName", "taxonID")
  )

  ground <- d1 |>
    dplyr::filter(.data$divDataType %in% "otherVariables", !is.na(.data$otherVariables)) |>
    dplyr::transmute(
      plotID, subplotID, year = year_of(endDate), bout = boutNumber,
      otherVariables, percentCover = suppressWarnings(as.numeric(percentCover))
    ) |>
    dplyr::filter(!is.na(.data$year))
  ground <- stable_order(ground, c("plotID", "subplotID", "year", "bout", "otherVariables"))

  if (!nrow(occurrence))
    stop(sprintf("%s produced no usable plant occurrences", site), call. = FALSE)
  list(
    occ = occurrence,
    ground = ground,
    meta = list(
      site = site,
      lat = stats::median(occurrence$lat, na.rm = TRUE),
      lng = stats::median(occurrence$lng, na.rm = TRUE),
      years = sort(unique(occurrence$year)),
      built_at = build_date,
      neon_release = neon_release
    )
  )
}

index_rows <- vector("list", length(expected_sites))
names(index_rows) <- expected_sites
for (site in expected_sites) {
  cat(sprintf("=== bundling %s ===\n", site))
  bundle <- build_site(site)
  destination <- file.path(site_dir, paste0(site, ".rds"))
  temporary <- tempfile(pattern = paste0(site, "-"), tmpdir = site_dir,
                        fileext = ".rds.tmp")
  saveRDS(bundle, temporary, compress = "xz")
  if (!file.rename(temporary, destination))
    stop(sprintf("Could not atomically publish staged bundle %s", destination), call. = FALSE)

  snapshot <- latest_snapshot(bundle$occ)
  species <- species_level_only(snapshot)
  families <- sort(table(species$family[!is.na(species$family)]), decreasing = TRUE)
  top_family <- if (length(families)) names(families)[1L] else NA_character_
  index_rows[[site]] <- data.frame(
    site = site,
    richness = length(unique(species$scientificName)),
    n_plots = length(unique(snapshot$plotID)),
    pct_introduced = site_invasion(snapshot),
    dominant_family = top_family,
    lat = bundle$meta$lat,
    lng = bundle$meta$lng,
    stringsAsFactors = FALSE
  )
}

site_index <- dplyr::bind_rows(index_rows)
site_index <- site_index[match(expected_sites, site_index$site), , drop = FALSE]
attr(site_index, "built_at") <- build_date
attr(site_index, "neon_release") <- neon_release
saveRDS(site_index, file.path(output_root, "data", "site_index.rds"), compress = "xz")

demo_source <- file.path(site_dir, paste0(demo_site, ".rds"))
if (!file.copy(demo_source, file.path(sample_dir, "demo.rds"), overwrite = TRUE,
               copy.mode = FALSE, copy.date = FALSE))
  stop("Could not create the exact SRER demo copy", call. = FALSE)

produced <- sort(sub("[.]rds$", "", basename(list.files(site_dir, pattern = "[.]rds$"))))
if (!identical(produced, expected_sites) || nrow(site_index) != length(expected_sites))
  stop("BUNDLE SITE GATE FAILED after writing candidate", call. = FALSE)

cat(sprintf("BUNDLE CANDIDATE PASSED: 46/46 sites, release=%s, built_at=%s.\n",
            neon_release, build_date))
