#!/usr/bin/env Rscript

# Non-network release gate for all Plant Diversity runtime bytes: 46 plant
# bundles, 46 environmental overlays, derived indexes, static reference data,
# demo, explicit receipts, and the exact Posit Connect manifest.

suppressPackageStartupMessages(library(dplyr))

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0L) b else a
problems <- character(0)
note <- function(message) problems[[length(problems) + 1L]] <<- message
read_checked <- function(path) {
  if (!file.exists(path)) {
    note(sprintf("missing file: %s", path))
    return(NULL)
  }
  result <- tryCatch(readRDS(path), error = function(error) error)
  if (inherits(result, "error")) {
    note(sprintf("%s failed to load: %s", path, conditionMessage(result)))
    return(NULL)
  }
  result
}

source("R/site_metadata.R")
source("R/plant_helpers.R")
source("R/expected_qc.R")
EXPECTED_SITES <- sort(as.character(neon_sites$site))
EXPECTED_R_PLATFORM <- "4.5.2"
EXPECTED_REPOSITORY <-
  "https://packagemanager.posit.co/cran/__linux__/jammy/2026-07-15"
EXPECTED_REFERENCE_SITE_COUNT <- 34L
EXPECTED_BUILD_DATE <- trimws(Sys.getenv("PDE_EXPECT_BUILD_DATE", ""))
EXPECTED_RELEASE <- trimws(Sys.getenv("PDE_EXPECT_RELEASE", ""))

REQUIRED_RUNTIME_PACKAGES <- c(
  "shiny", "bslib", "bsicons", "dplyr", "tidyr", "stringr", "tibble",
  "plotly", "leaflet", "DT", "shinyjs", "shinycssloaders", "RColorBrewer",
  "htmltools"
)
FORBIDDEN_RUNTIME_PACKAGES <- c("neonUtilities", "arrow", "rsconnect")
EXPECTED_GEO_PINS <- c(
  terra = "1.8-50", sf = "1.1-1", s2 = "1.1.11", units = "1.0-1",
  wk = "0.9.5", classInt = "0.4-11", raster = "3.6-32", sp = "2.2-1"
)
EXPECTED_GEO_URLS <- c(
  terra = "https://cran.r-project.org/src/contrib/Archive/terra/terra_1.8-50.tar.gz",
  sf = "https://packagemanager.posit.co/cran/2026-07-15/src/contrib/sf_1.1-1.tar.gz",
  s2 = "https://packagemanager.posit.co/cran/2026-07-15/src/contrib/s2_1.1.11.tar.gz",
  units = "https://packagemanager.posit.co/cran/2026-07-15/src/contrib/units_1.0-1.tar.gz",
  wk = "https://packagemanager.posit.co/cran/2026-07-15/src/contrib/wk_0.9.5.tar.gz",
  classInt = "https://packagemanager.posit.co/cran/2026-07-15/src/contrib/classInt_0.4-11.tar.gz",
  raster = "https://packagemanager.posit.co/cran/2026-07-15/src/contrib/raster_3.6-32.tar.gz",
  sp = "https://packagemanager.posit.co/cran/2026-07-15/src/contrib/sp_2.2-1.tar.gz"
)

OCC_REQUIRED <- c(
  "plotID", "subplotID", "scale", "year", "bout", "taxonID",
  "scientificName", "taxonRank", "family", "nativeStatusCode", "nativity",
  "percentCover", "is_species", "plotType", "nlcdClass", "lat", "lng"
)
GROUND_REQUIRED <- c(
  "plotID", "subplotID", "year", "bout", "otherVariables", "percentCover"
)
SITE_INDEX_REQUIRED <- c(
  "site", "richness", "n_plots", "pct_introduced", "dominant_family", "lat", "lng"
)
SEARCH_TAXA_REQUIRED <- c(
  "scientificName", "site", "family", "nativity", "mean_cover",
  "n_plots", "year_min", "year_max"
)

# ---- plant site bundles -----------------------------------------------------
site_files <- list.files("data/sites", pattern = "[.]rds$", full.names = TRUE)
site_codes <- sort(sub("[.]rds$", "", basename(site_files)))
if (!identical(site_codes, EXPECTED_SITES))
  note(sprintf("plant site set mismatch: missing=[%s] extra=[%s]",
               paste(setdiff(EXPECTED_SITES, site_codes), collapse = ","),
               paste(setdiff(site_codes, EXPECTED_SITES), collapse = ",")))

bundles <- list()
bundle_dates <- character(0)
bundle_releases <- character(0)
for (path in site_files) {
  site <- sub("[.]rds$", "", basename(path))
  bundle <- read_checked(path)
  if (is.null(bundle)) next
  bundles[[site]] <- bundle
  if (!is.list(bundle) || !all(c("occ", "ground", "meta") %in% names(bundle))) {
    note(sprintf("%s is not an occ/ground/meta bundle", path))
    next
  }
  if (!is.data.frame(bundle$occ) || nrow(bundle$occ) == 0L) {
    note(sprintf("%s has an empty/non-data-frame occurrence table", path))
  } else {
    missing <- setdiff(OCC_REQUIRED, names(bundle$occ))
    if (length(missing)) note(sprintf("%s occurrence lacks: %s", path, paste(missing, collapse = ",")))
    if ("scale" %in% names(bundle$occ) &&
        any(!bundle$occ$scale %in% c(1L, 10L, 100L), na.rm = TRUE))
      note(sprintf("%s has a scale outside 1/10/100 m2", path))
    if (all(c("scale", "percentCover") %in% names(bundle$occ)) &&
        any(bundle$occ$scale != 1L & !is.na(bundle$occ$percentCover)))
      note(sprintf("%s carries cover at a presence-only scale", path))
    if ("percentCover" %in% names(bundle$occ) &&
        any(bundle$occ$percentCover < 0 | bundle$occ$percentCover > 100, na.rm = TRUE))
      note(sprintf("%s has plant cover outside 0..100", path))
    if ("nativity" %in% names(bundle$occ) &&
        any(!bundle$occ$nativity %in% c("Native", "Introduced", "Unknown")))
      note(sprintf("%s has an unsupported nativity bucket", path))
  }
  if (!is.data.frame(bundle$ground)) {
    note(sprintf("%s ground cover is not a data frame", path))
  } else {
    missing <- setdiff(GROUND_REQUIRED, names(bundle$ground))
    if (length(missing)) note(sprintf("%s ground lacks: %s", path, paste(missing, collapse = ",")))
    if ("percentCover" %in% names(bundle$ground) &&
        any(bundle$ground$percentCover < 0 | bundle$ground$percentCover > 100, na.rm = TRUE))
      note(sprintf("%s has ground cover outside 0..100", path))
  }
  meta <- bundle$meta
  if (!is.list(meta) ||
      !all(c("site", "lat", "lng", "years", "built_at", "neon_release") %in% names(meta)) ||
      !identical(as.character(meta$site), site)) {
    note(sprintf("%s metadata is incomplete or identifies another site", path))
  } else {
    built_at <- as.character(meta$built_at)
    release <- if (is.null(meta$neon_release) || is.na(meta$neon_release)) "" else
      as.character(meta$neon_release)
    parsed_built_at <- suppressWarnings(as.Date(built_at, format = "%Y-%m-%d"))
    if (length(built_at) != 1L || is.na(parsed_built_at))
      note(sprintf("%s has an invalid built_at receipt", path))
    if (nzchar(EXPECTED_BUILD_DATE) && !identical(built_at, EXPECTED_BUILD_DATE))
      note(sprintf("%s build receipt differs from PDE_EXPECT_BUILD_DATE", path))
    if (nzchar(EXPECTED_RELEASE) && !identical(release, EXPECTED_RELEASE))
      note(sprintf("%s release receipt differs from PDE_EXPECT_RELEASE", path))
    if (is.data.frame(bundle$occ) && "year" %in% names(bundle$occ) &&
        !identical(sort(unique(as.integer(bundle$occ$year))), sort(as.integer(meta$years))))
      note(sprintf("%s metadata years differ from its occurrence table", path))
    bundle_dates[[site]] <- built_at
    bundle_releases[[site]] <- release
  }
}
cat(sprintf("plant bundles: %d expected, %d readable\n",
            length(EXPECTED_SITES), length(bundles)))

if (length(bundle_dates) && length(unique(bundle_dates)) != 1L)
  note(sprintf("plant bundles have mixed build receipts: %s",
               paste(sort(unique(bundle_dates)), collapse = ",")))
nonempty_releases <- unique(bundle_releases[nzchar(bundle_releases)])
if (length(nonempty_releases) > 1L)
  note(sprintf("plant bundles have mixed release receipts: %s",
               paste(sort(nonempty_releases), collapse = ",")))

# ---- environmental overlays ------------------------------------------------
env_files <- list.files("data/env", pattern = "[.]rds$", full.names = TRUE)
env_codes <- sort(sub("[.]rds$", "", basename(env_files)))
if (!identical(env_codes, EXPECTED_SITES))
  note(sprintf("environment site set mismatch: missing=[%s] extra=[%s]",
               paste(setdiff(EXPECTED_SITES, env_codes), collapse = ","),
               paste(setdiff(env_codes, EXPECTED_SITES), collapse = ",")))
for (path in env_files) {
  site <- sub("[.]rds$", "", basename(path))
  env <- read_checked(path)
  if (is.null(env)) next
  required <- c(
    "siteID", "ym", "date", "precip_mm", "temp_c", "temp_min", "temp_max",
    "flowering_pct", "flowering_pct_n", "greenup_pct", "greenup_pct_n",
    "fruiting_pct", "fruiting_pct_n", "source")
  if (!is.data.frame(env) || nrow(env) == 0L)
    note(sprintf("%s is an empty/non-data-frame environment bundle", path))
  else {
    missing <- setdiff(required, names(env))
    if (length(missing)) note(sprintf("%s environment lacks: %s", path, paste(missing, collapse = ",")))
    if ("siteID" %in% names(env) &&
        any(is.na(env$siteID) | as.character(env$siteID) != site))
      note(sprintf("%s contains rows for another site", path))
    if ("source" %in% names(env) &&
        (!is.character(env$source) || any(is.na(env$source) | !nzchar(trimws(env$source)))))
      note(sprintf("%s has missing or noncharacter source provenance", path))
    if ("ym" %in% names(env)) {
      ym <- as.character(env$ym)
      if (anyDuplicated(ym)) note(sprintf("%s has duplicate monthly keys", path))
      if (any(is.na(ym) | !grepl("^[0-9]{4}-(0[1-9]|1[0-2])$", ym)))
        note(sprintf("%s has invalid YYYY-MM keys", path))
    }
    if (all(c("ym", "date") %in% names(env))) {
      dates <- suppressWarnings(as.Date(env$date))
      if (any(is.na(dates)) || any(format(dates, "%Y-%m") != as.character(env$ym)))
        note(sprintf("%s date values do not match the monthly keys", path))
    }
    numeric_columns <- intersect(
      c("precip_mm", "temp_c", "temp_min", "temp_max", "rh_pct", "vswc_pct",
        "flowering_pct", "flowering_pct_n", "greenup_pct", "greenup_pct_n",
        "fruiting_pct", "fruiting_pct_n"), names(env))
    for (column in numeric_columns) {
      value <- env[[column]]
      if (!is.numeric(value)) {
        note(sprintf("%s has nonnumeric %s storage", path, column))
      } else if (any(!is.na(value) & !is.finite(value))) {
        note(sprintf("%s has a non-finite %s value", path, column))
      }
    }
    if ("precip_mm" %in% names(env) && is.numeric(env$precip_mm) &&
        any(env$precip_mm < 0, na.rm = TRUE))
      note(sprintf("%s has negative monthly precipitation", path))
    bounded <- intersect(c("rh_pct", "vswc_pct", "flowering_pct", "greenup_pct", "fruiting_pct"), names(env))
    for (column in bounded) {
      value <- env[[column]]
      if (is.numeric(value) && any(value < 0 | value > 100, na.rm = TRUE))
        note(sprintf("%s has %s outside 0..100", path, column))
    }
    counts <- intersect(c("flowering_pct_n", "greenup_pct_n", "fruiting_pct_n"), names(env))
    for (column in counts) {
      if (is.numeric(env[[column]]) &&
          any(env[[column]] < 0 | env[[column]] != floor(env[[column]]), na.rm = TRUE))
        note(sprintf("%s has negative or non-integer %s support", path, column))
    }
    if (all(c("temp_min", "temp_max") %in% names(env)) &&
        is.numeric(env$temp_min) && is.numeric(env$temp_max) &&
        any(env$temp_min > env$temp_max, na.rm = TRUE))
      note(sprintf("%s has temp_min above temp_max", path))
  }
}
cat(sprintf("environment bundles: %d expected, %d found\n",
            length(EXPECTED_SITES), length(env_files)))

# ---- site and search indexes ------------------------------------------------
site_index <- read_checked("data/site_index.rds")
if (!is.null(site_index)) {
  if (!is.data.frame(site_index) || nrow(site_index) != length(EXPECTED_SITES)) {
    note("site_index must be a 46-row data frame")
  } else {
    missing <- setdiff(SITE_INDEX_REQUIRED, names(site_index))
    if (length(missing)) note(sprintf("site_index lacks: %s", paste(missing, collapse = ",")))
    if (!identical(sort(as.character(site_index$site)), EXPECTED_SITES))
      note("site_index site set differs from site_metadata")
    if (anyDuplicated(as.character(site_index$site))) note("site_index contains duplicate sites")
    index_date <- as.character(attr(site_index, "built_at") %||% "")
    index_release <- as.character(attr(site_index, "neon_release") %||% "")
    if (nzchar(EXPECTED_BUILD_DATE) && !identical(index_date, EXPECTED_BUILD_DATE))
      note("site_index build receipt differs from PDE_EXPECT_BUILD_DATE")
    if (nzchar(EXPECTED_RELEASE) && !identical(index_release, EXPECTED_RELEASE))
      note("site_index release receipt differs from PDE_EXPECT_RELEASE")
    if (nzchar(index_date) && length(bundle_dates) && !identical(index_date, max(bundle_dates)))
      note("site_index build receipt differs from the site bundles")
    if (nzchar(index_release) && length(nonempty_releases) &&
        !identical(index_release, nonempty_releases[[1L]]))
      note("site_index release receipt differs from the site bundles")
    if (all(c("site", "lat", "lng") %in% names(site_index))) {
      metadata <- neon_sites[match(site_index$site, neon_sites$site), ]
      if (any(abs(site_index$lat - metadata$lat) > 1.5, na.rm = TRUE) ||
          any(abs(site_index$lng - metadata$lng) > 1.5, na.rm = TRUE))
        note("site_index coordinates are implausibly far from canonical site coordinates")
    }
    if (length(bundles) == length(EXPECTED_SITES) &&
        !length(setdiff(SITE_INDEX_REQUIRED, names(site_index)))) {
      for (site in EXPECTED_SITES) {
        row <- site_index[site_index$site == site, , drop = FALSE]
        snapshot <- latest_snapshot(bundles[[site]]$occ)
        species <- species_level_only(snapshot)
        expected_richness <- length(unique(species$scientificName))
        expected_plots <- length(unique(snapshot$plotID))
        expected_invasion <- site_invasion(snapshot)
        same_invasion <- isTRUE(all.equal(as.numeric(row$pct_introduced),
                                          as.numeric(expected_invasion),
                                          tolerance = 1e-10, check.attributes = FALSE))
        if (nrow(row) != 1L || row$richness != expected_richness ||
            row$n_plots != expected_plots || !same_invasion ||
            !isTRUE(all.equal(as.numeric(row$lat), as.numeric(bundles[[site]]$meta$lat),
                              tolerance = 1e-10)) ||
            !isTRUE(all.equal(as.numeric(row$lng), as.numeric(bundles[[site]]$meta$lng),
                              tolerance = 1e-10)))
          note(sprintf("site_index metrics differ from the %s site bundle", site))
      }
    }
  }
}

search <- read_checked("data/search_index.rds")
if (!is.null(search)) {
  if (!is.list(search) ||
      !all(c("taxa", "sites", "built_at", "neon_release") %in% names(search))) {
    note("search_index must contain taxa/sites/built_at/neon_release")
  } else if (!is.data.frame(search$taxa) || !nrow(search$taxa) ||
             !is.data.frame(search$sites) || !nrow(search$sites)) {
    note("search_index taxa and sites must be non-empty data frames")
  } else {
    missing <- setdiff(SEARCH_TAXA_REQUIRED, names(search$taxa))
    if (length(missing)) note(sprintf("search taxa lacks: %s", paste(missing, collapse = ",")))
    if (all(c("site", "scientificName") %in% names(search$taxa))) {
      keys <- paste(search$taxa$site, search$taxa$scientificName, sep = "\r")
      if (anyDuplicated(keys)) note("search taxa contains duplicate site/species rows")
      if (any(!as.character(search$taxa$site) %in% EXPECTED_SITES))
        note("search taxa contains an unknown site")
      if (length(bundles) == length(EXPECTED_SITES)) {
        expected_keys <- sort(unique(unlist(lapply(names(bundles), function(site) {
          species <- species_level_only(latest_snapshot(bundles[[site]]$occ))
          paste(site, species$scientificName, sep = "\r")
        }))))
        if (!identical(sort(keys), expected_keys))
          note("search taxon keys differ from the complete site bundles")
      }
    }
    if (!is.null(site_index) && is.data.frame(site_index) &&
        !isTRUE(all.equal(as.data.frame(search$sites), as.data.frame(site_index),
                          check.attributes = FALSE)))
      note("search sites differ from site_index")
    if (length(bundle_dates) &&
        !identical(as.character(search$built_at), max(bundle_dates)))
      note("search built_at does not match the bundle receipt")
    expected_release <- if (length(nonempty_releases)) nonempty_releases[[1L]] else ""
    search_release <- if (is.null(search$neon_release) || is.na(search$neon_release)) "" else
      as.character(search$neon_release)
    if (!identical(search_release, expected_release))
      note("search release receipt differs from the site bundles")
  }
}

demo <- read_checked("data-sample/demo.rds")
if (!is.null(demo) && !is.null(bundles$SRER) && !identical(demo, bundles$SRER))
  note("demo.rds is not an exact object copy of the SRER site bundle")

# ---- expected flora and authority ------------------------------------------
expected_files <- list.files("data/expected", pattern = "^[A-Z]{4}[.]rds$", full.names = TRUE)
expected_codes <- sort(sub("[.]rds$", "", basename(expected_files)))
if (length(expected_codes) != EXPECTED_REFERENCE_SITE_COUNT ||
    any(!expected_codes %in% EXPECTED_SITES))
  note(sprintf("expected-flora set must contain exactly %d known sites; got %d",
               EXPECTED_REFERENCE_SITE_COUNT, length(expected_codes)))
for (path in expected_files) {
  expected <- read_checked(path)
  if (is.null(expected)) next
  if (!is.list(expected) || !identical(expected$status, "ok") ||
      is.null(expected$reference_species) || !is.data.frame(expected$reference_species) ||
      !nrow(expected$reference_species)) {
    note(sprintf("%s is not a usable expected-flora bundle", path))
  } else {
    required <- c("plantsym", "sciname", "comname", "rangeprod", "is_aggregate", "is_dominant")
    missing <- setdiff(required, names(expected$reference_species))
    if (length(missing)) note(sprintf("%s expected flora lacks: %s", path, paste(missing, collapse = ",")))
    if ("plantsym" %in% names(expected$reference_species) &&
        anyDuplicated(as.character(expected$reference_species$plantsym)))
      note(sprintf("%s has duplicate expected plant symbols", path))
  }
}

completeness <- read_checked("data/expected/completeness_index.rds")
if (!is.null(completeness) &&
    (!is.data.frame(completeness) ||
     !all(c("site", "pct_detected", "n_ref", "n_overlap", "dom_obs", "dom_total") %in% names(completeness)) ||
     !identical(sort(as.character(completeness$site)), expected_codes)))
  note("completeness_index does not match the bundled expected-flora site set")

provenance <- read_checked("data/expected/provenance.rds")
if (!is.null(provenance) &&
    (!is.data.frame(provenance) ||
     !all(c("site", "status", "ecoclassid", "n_expected") %in% names(provenance)) ||
     !identical(sort(as.character(provenance$site)), EXPECTED_SITES)))
  note("expected-flora provenance must describe all 46 sites")

authority <- read_checked("data/authority/plants_lookup.rds")
if (!is.null(authority)) {
  required <- c("authority", "synonyms", "n_symbols", "n_resolved",
                "n_synonyms", "n_failed", "built_for", "fetchedAt")
  if (!is.list(authority) || length(setdiff(required, names(authority)))) {
    note("plant authority container is incomplete")
  } else {
    columns <- c("accepted_symbol", "sci_name", "nativity_usda", "growth_habit",
                 "duration")
    if (!is.data.frame(authority$authority) || !nrow(authority$authority) ||
        length(setdiff(columns, names(authority$authority))))
      note("plant authority table is empty or lacks required columns")
    if (!identical(sort(as.character(authority$built_for)), EXPECTED_SITES))
      note("plant authority built_for receipt does not cover all 46 sites")
    if (length(authority$synonyms) && is.null(names(authority$synonyms)))
      note("plant authority synonym map is unnamed")
  }
}

if (!is.null(completeness) && is.data.frame(completeness) &&
    !is.null(authority) && is.list(authority) &&
    length(bundles) == length(EXPECTED_SITES)) {
  rebuilt_rows <- lapply(expected_codes, function(site) {
    expected <- load_expected(site, "data/expected")
    comparison <- if (is.null(expected)) NULL else
      expected_vs_observed(bundles[[site]]$occ, expected, authority)
    if (is.null(comparison)) return(NULL)
    data.frame(
      site = site, pct_detected = comparison$overlap_pct,
      n_ref = comparison$n_ref, n_overlap = comparison$n_overlap,
      dom_obs = comparison$dom_obs, dom_total = comparison$dom_total,
      stringsAsFactors = FALSE)
  })
  rebuilt_rows <- rebuilt_rows[!vapply(rebuilt_rows, is.null, logical(1))]
  rebuilt <- if (length(rebuilt_rows)) do.call(rbind, rebuilt_rows) else data.frame()
  required <- c("site", "pct_detected", "n_ref", "n_overlap", "dom_obs", "dom_total")
  if (!all(required %in% names(completeness)) ||
      !all(required %in% names(rebuilt))) {
    note("completeness_index cannot be reconciled to current bundles")
  } else {
    actual <- completeness[order(completeness$site), required, drop = FALSE]
    expected <- rebuilt[order(rebuilt$site), required, drop = FALSE]
    rownames(actual) <- rownames(expected) <- NULL
    if (!isTRUE(all.equal(actual, expected, tolerance = 1e-10,
                          check.attributes = FALSE)))
      note("completeness_index metrics differ from the current plant/reference bundles")
  }
}

# ---- exact manifest ---------------------------------------------------------
if (!file.exists("manifest.json")) {
  note("manifest.json is missing")
} else {
  manifest <- tryCatch(jsonlite::fromJSON("manifest.json", simplifyVector = FALSE),
                       error = function(error) error)
  if (inherits(manifest, "error")) {
    note(sprintf("manifest JSON parse failed: %s", conditionMessage(manifest)))
  } else {
    runtime_files <- c(
      "global.R", "ui.R", "server.R",
      list.files("R", pattern = "[.]R$", full.names = TRUE),
      list.files("www", recursive = TRUE, full.names = TRUE),
      Sys.glob("data/*.rds"),
      list.files("data/sites", pattern = "[.]rds$", full.names = TRUE),
      list.files("data/env", pattern = "[.]rds$", full.names = TRUE),
      list.files("data/expected", pattern = "[.]rds$", full.names = TRUE),
      "data/authority/plants_lookup.rds",
      list.files("data-sample", pattern = "[.]rds$", full.names = TRUE)
    )
    runtime_files <- sort(unique(runtime_files[file.exists(runtime_files)]))
    declared <- sort(names(manifest$files %||% list()))
    if (!identical(declared, runtime_files))
      note(sprintf("manifest file set differs: missing=[%s] extra=[%s]",
                   paste(setdiff(runtime_files, declared), collapse = ","),
                   paste(setdiff(declared, runtime_files), collapse = ",")))
    present <- intersect(declared, runtime_files)
    bad_checksums <- vapply(present, function(path) {
      expected <- tolower(as.character(manifest$files[[path]]$checksum %||% ""))
      actual <- tolower(unname(tools::md5sum(path)))
      !identical(expected, actual)
    }, logical(1))
    if (any(bad_checksums))
      note(sprintf("manifest checksum mismatch: %s",
                   paste(present[bad_checksums], collapse = ",")))
    if (!identical(as.character(manifest$platform %||% ""), EXPECTED_R_PLATFORM))
      note(sprintf("manifest platform is %s, expected %s",
                   manifest$platform %||% "<missing>", EXPECTED_R_PLATFORM))

    packages <- manifest$packages %||% list()
    keys <- names(packages)
    missing <- setdiff(REQUIRED_RUNTIME_PACKAGES, keys)
    forbidden <- intersect(FORBIDDEN_RUNTIME_PACKAGES, keys)
    if (length(missing)) note(sprintf("manifest lacks runtime packages: %s", paste(missing, collapse = ",")))
    if (length(forbidden)) note(sprintf("manifest contains forbidden packages: %s", paste(forbidden, collapse = ",")))
    for (package in keys) {
      info <- packages[[package]]
      if (!identical(as.character(info$description$Package %||% ""), package) ||
          !nzchar(as.character(info$description$Version %||% "")))
        note(sprintf("manifest package identity is incomplete: %s", package))
      if (!package %in% names(EXPECTED_GEO_PINS) &&
          (!identical(as.character(info$Source %||% ""), "CRAN") ||
           !identical(as.character(info$Repository %||% ""), EXPECTED_REPOSITORY)))
        note(sprintf("ordinary package provenance is not pinned: %s", package))
    }
    for (package in names(EXPECTED_GEO_PINS)) {
      info <- packages[[package]]
      if (is.null(info)) {
        note(sprintf("manifest lacks geospatial package: %s", package))
        next
      }
      expected_ref <- paste0("url::", unname(EXPECTED_GEO_URLS[[package]]))
      if (!identical(as.character(info$description$Version %||% ""),
                     unname(EXPECTED_GEO_PINS[[package]])) ||
          !identical(as.character(info$Source %||% ""), "CRAN") ||
          !identical(as.character(info$Repository %||% ""),
                     if (package == "terra") "https://cran.r-project.org" else
                       "https://packagemanager.posit.co/cran/2026-07-15") ||
          !identical(as.character(info$description$RemoteType %||% ""), "url") ||
          !identical(as.character(info$description$RemotePkgRef %||% ""), expected_ref) ||
          nzchar(as.character(info$description$Built %||% "")))
        note(sprintf("geospatial package provenance is invalid: %s", package))
    }
  }
}

if (length(problems)) {
  for (problem in problems)
    cat(sprintf("::error title=Plant Diversity release verification::%s\n", problem))
  stop(sprintf("Plant Diversity release verification FAILED with %d problem(s).",
               length(problems)), call. = FALSE)
}

cat("Plant Diversity release verification PASSED: 46 plant + 46 environment bundles, references, indexes, demo, and exact manifest.\n")
