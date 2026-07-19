#!/usr/bin/env Rscript

# Build the complete DP1.10058.001 app bundle in an isolated output root.
# Release automation supplies an explicit build date and query-snapshot receipt,
# builds twice from the same raw staging, and compares every produced byte.

suppressWarnings(suppressMessages(library(dplyr)))
source("R/site_metadata.R")
source("R/source_receipt.R")
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
source_start <- required_env("PDE_SOURCE_START")
source_cutoff <- required_env("PDE_SOURCE_CUTOFF")
source_receipt_id <- required_env("PDE_SOURCE_RECEIPT_ID")
query_package <- required_env("PDE_QUERY_PACKAGE")
neon_utilities_version <- required_env("PDE_NEON_UTILITIES_VERSION")
source_digest <- required_env("PDE_SOURCE_DIGEST")
builder_commit <- required_env("PDE_BUILDER_COMMIT")
source_inventory <- file.path(raw_dir, "SOURCE-SHA256SUMS.txt")
neon_release_value <- trimws(Sys.getenv("NEON_RELEASE", ""))
neon_release <- if (nzchar(neon_release_value)) neon_release_value else NA_character_
demo_site <- "SRER"

parsed_build_date <- suppressWarnings(as.Date(build_date, format = "%Y-%m-%d"))
if (is.na(parsed_build_date) || !grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", build_date))
  stop("PDE_BUILD_DATE must be an ISO date (YYYY-MM-DD)", call. = FALSE)
if (is.na(suppressWarnings(as.Date(source_cutoff))) ||
    !grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", source_cutoff))
  stop("PDE_SOURCE_CUTOFF must be an ISO date (YYYY-MM-DD)", call. = FALSE)
if (format(as.Date(source_cutoff) + 1, "%d") != "01")
  stop("PDE_SOURCE_CUTOFF must be the end of a closed source month",
       call. = FALSE)
if (parsed_build_date < as.Date(source_cutoff))
  stop("PDE_BUILD_DATE cannot precede PDE_SOURCE_CUTOFF", call. = FALSE)
parsed_source_start <- suppressWarnings(
  as.Date(paste0(source_start, "-01"), format = "%Y-%m-%d")
)
if (!grepl("^[0-9]{4}-(0[1-9]|1[0-2])$", source_start) ||
    is.na(parsed_source_start) ||
    !identical(format(parsed_source_start, "%Y-%m"), source_start) ||
    parsed_source_start > as.Date(source_cutoff))
  stop("PDE_SOURCE_START must be a valid YYYY-MM no later than the cutoff", call. = FALSE)
if (!grepl("^[A-Za-z0-9._:-]+$", source_receipt_id))
  stop("PDE_SOURCE_RECEIPT_ID contains unsupported characters", call. = FALSE)
if (!identical(query_package, "basic"))
  stop("PDE_QUERY_PACKAGE must match the fetched NEON basic package", call. = FALSE)
if (!grepl("^[0-9]+([.][0-9]+){1,3}([.-][A-Za-z0-9]+)?$",
           neon_utilities_version))
  stop("PDE_NEON_UTILITIES_VERSION is invalid", call. = FALSE)
if (!grepl("^[0-9a-f]{64}$", source_digest))
  stop("PDE_SOURCE_DIGEST must be a lowercase SHA-256", call. = FALSE)
if (!grepl(source_digest, source_receipt_id, fixed = TRUE))
  stop("PDE_SOURCE_RECEIPT_ID must be bound to PDE_SOURCE_DIGEST", call. = FALSE)
if (!grepl("^[0-9a-f]{40}$", builder_commit))
  stop("PDE_BUILDER_COMMIT must be a full Git commit", call. = FALSE)
if (!is.na(neon_release) && !grepl("^[A-Za-z0-9._:-]+$", neon_release))
  stop("NEON_RELEASE contains unsupported characters", call. = FALSE)
if (!file.exists(source_inventory))
  stop("The canonical raw per-file SHA-256 inventory is missing", call. = FALSE)
inventory_lines <- readLines(source_inventory, warn = FALSE)
inventory_pattern <- "^[0-9a-f]{64}  [.]/([A-Z0-9]{4})_raw[.]rds$"
inventory_sites <- sub(inventory_pattern, "\\1", inventory_lines)
inventory_hashes <- sub("^([0-9a-f]{64}).*$", "\\1", inventory_lines)
if (length(inventory_lines) != 46L ||
    any(!grepl(inventory_pattern, inventory_lines)) ||
    !identical(inventory_sites, sort(as.character(neon_sites$site))) ||
    !identical(
      digest::digest(file = source_inventory, algo = "sha256", serialize = FALSE),
      source_digest
    ))
  stop("The canonical raw per-file SHA-256 inventory is invalid", call. = FALSE)

expected_sites <- sort(as.character(neon_sites$site))
raw_files <- sort(list.files(raw_dir, pattern = "_raw[.]rds$", full.names = TRUE))
raw_sites <- sort(sub("_raw[.]rds$", "", basename(raw_files)))
if (!identical(raw_sites, expected_sites))
  stop(sprintf("RAW SITE GATE FAILED: missing=[%s] extra=[%s]",
               paste(setdiff(expected_sites, raw_sites), collapse = ","),
               paste(setdiff(raw_sites, expected_sites), collapse = ",")),
       call. = FALSE)
actual_raw_hashes <- vapply(raw_files, function(path) {
  digest::digest(file = path, algo = "sha256", serialize = FALSE)
}, character(1))
if (!identical(raw_sites, inventory_sites) ||
    !identical(unname(actual_raw_hashes), inventory_hashes))
  stop("Raw plant inputs differ from their registered per-file SHA-256 inventory",
       call. = FALSE)

site_dir <- file.path(output_root, "data", "sites")
sample_dir <- file.path(output_root, "data-sample")
source_dir <- file.path(output_root, "data", "source")
dir.create(site_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(sample_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(source_dir, recursive = TRUE, showWarnings = FALSE)
old_site_files <- list.files(site_dir, pattern = "[.]rds$", full.names = TRUE)
if (length(old_site_files)) unlink(old_site_files)
old_source_files <- list.files(source_dir, full.names = TRUE)
if (length(old_source_files)) unlink(old_source_files, recursive = TRUE)
if (!file.copy(source_inventory,
               file.path(source_dir, "plant-raw-SHA256SUMS.txt"),
               overwrite = TRUE, copy.mode = FALSE, copy.date = FALSE))
  stop("Could not preserve the canonical raw per-file SHA-256 inventory",
       call. = FALSE)

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
  d1_required <- c("divDataType", "scientificName", "otherVariables", "endDate")
  d2_required <- c("scientificName", "endDate")
  if (length(setdiff(d1_required, names(d1))) ||
      length(setdiff(d2_required, names(d2))))
    stop(sprintf("%s raw dump lacks a required consumed-row field", site),
         call. = FALSE)
  d1_consumed <-
    (as.character(d1$divDataType) == "plantSpecies" & !is.na(d1$scientificName)) |
    (as.character(d1$divDataType) == "otherVariables" & !is.na(d1$otherVariables))
  d2_consumed <- !is.na(d2$scientificName)
  validate_plant_source_rows(
    d1, site, "div_1m2Data", parsed_source_start, as.Date(source_cutoff),
    d1_consumed
  )
  validate_plant_source_rows(
    d2, site, "div_10m2Data100m2Data", parsed_source_start,
    as.Date(source_cutoff), d2_consumed
  )
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
  site_lat <- suppressWarnings(stats::median(occurrence$lat, na.rm = TRUE))
  site_lng <- suppressWarnings(stats::median(occurrence$lng, na.rm = TRUE))
  if (length(site_lat) != 1L || length(site_lng) != 1L ||
      !is.finite(site_lat) || !is.finite(site_lng) ||
      abs(site_lat) > 90 || abs(site_lng) > 180)
    stop(sprintf("%s lacks a valid finite site coordinate", site), call. = FALSE)
  list(
    occ = occurrence,
    ground = ground,
    meta = list(
      site = site,
      lat = site_lat,
      lng = site_lng,
      years = sort(unique(occurrence$year)),
      receipt_version = "plant-source-receipt-v2",
      product = "DP1.10058.001",
      built_at = build_date,
      source_start = source_start,
      source_cutoff = source_cutoff,
      source_receipt_id = source_receipt_id,
      query_package = query_package,
      neon_utilities_version = neon_utilities_version,
      source_digest = source_digest,
      builder_commit = builder_commit,
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
receipt_attributes <- list(
  receipt_version = "plant-source-receipt-v2",
  product = "DP1.10058.001",
  built_at = build_date,
  source_start = source_start,
  source_cutoff = source_cutoff,
  source_receipt_id = source_receipt_id,
  query_package = query_package,
  neon_utilities_version = neon_utilities_version,
  source_digest = source_digest,
  builder_commit = builder_commit,
  neon_release = neon_release
)
for (field in names(receipt_attributes))
  attr(site_index, field) <- receipt_attributes[[field]]
saveRDS(site_index, file.path(output_root, "data", "site_index.rds"), compress = "xz")

demo_source <- file.path(site_dir, paste0(demo_site, ".rds"))
if (!file.copy(demo_source, file.path(sample_dir, "demo.rds"), overwrite = TRUE,
               copy.mode = FALSE, copy.date = FALSE))
  stop("Could not create the exact SRER demo copy", call. = FALSE)

produced <- sort(sub("[.]rds$", "", basename(list.files(site_dir, pattern = "[.]rds$"))))
if (!identical(produced, expected_sites) || nrow(site_index) != length(expected_sites))
  stop("BUNDLE SITE GATE FAILED after writing candidate", call. = FALSE)

cat(sprintf(
  "BUNDLE CANDIDATE PASSED: 46/46 sites, receipt=%s, cutoff=%s, built_at=%s.\n",
  source_receipt_id, source_cutoff, build_date
))
