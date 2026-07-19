#!/usr/bin/env Rscript

# Executable science-contract fixtures. Metric tests use synthetic records;
# release-receipt tests inspect only committed local bytes. Nothing uses network.
suppressPackageStartupMessages(library(dplyr))
source("R/plant_helpers.R")
source("R/site_metadata.R")
source("R/source_receipt.R")
source("R/expected_qc.R")
source("R/env_helpers.R")
source("R/report_pdf.R")

assert <- function(ok, msg) if (!isTRUE(ok)) stop(msg, call. = FALSE)
near <- function(x, y, tol = 1e-10) isTRUE(all.equal(x, y, tolerance = tol, check.attributes = FALSE))

# 0. Source provenance is a fail-closed family state machine. The frozen legacy
# bytes are exact, but their upstream build/release/cutoff remain unknown.
receipt_sites <- sort(as.character(neon_sites$site))
receipt_index <- readRDS("data/site_index.rds")
receipt_metas <- stats::setNames(lapply(receipt_sites, function(site) {
  readRDS(file.path("data", "sites", paste0(site, ".rds")))$meta
}), receipt_sites)
current_receipt <- resolve_plant_source_set(
  "data/sites", receipt_index, receipt_sites, receipt_metas,
  require_bundle_metas = TRUE
)
assert(current_receipt$provenance_class %in% c("legacy-partial", "query-snapshot"),
       "current plant family did not resolve to a registered receipt class")
if (identical(current_receipt$provenance_class, "legacy-partial")) {
  assert(identical(current_receipt$repository_imported_at, "2026-06-19") &&
         identical(current_receipt$bundle_commit,
                   "4ffcb24c3c1bf0dcab1f6c42fd3b9b5fe4de4e1e") &&
         identical(current_receipt$source_digest,
                   "8f967bf7d0369879d0e9d3ac1ce19717d755ae681bc8eaa6d1341c3ade1f2a8a") &&
         identical(current_receipt$receipt_basis,
                   "legacy repository import commit date; not an upstream fetch cutoff") &&
         is.na(current_receipt$built_at) && is.na(current_receipt$neon_release) &&
         is.na(current_receipt$source_cutoff),
         "legacy source receipt overstates upstream provenance")
  bad_receipt <- PLANT_SOURCE_RECEIPT
  bad_receipt$site_inventory_sha256 <- paste(rep("0", 64L), collapse = "")
  bad_receipt_failed <- tryCatch({
    verify_legacy_plant_source_receipt("data/sites", receipt_sites, bad_receipt)
    FALSE
  }, error = function(error) TRUE)
  assert(bad_receipt_failed,
         "an unregistered 46-site family passed the legacy receipt gate")
} else {
  assert(.receipt_iso_date(current_receipt$built_at) &&
         .receipt_iso_date(current_receipt$source_cutoff) &&
         .receipt_hex(current_receipt$source_digest, 64L) &&
         grepl(current_receipt$source_digest, current_receipt$source_receipt_id,
               fixed = TRUE),
         "current query-snapshot receipt is incomplete")
}

# Receipt-state fixtures start from stripped metadata so they remain valid after
# the repository itself advances from the legacy family to a reviewed refresh.
fixture_index <- receipt_index
for (field in PLANT_REFRESH_RECEIPT_FIELDS) attr(fixture_index, field) <- NULL
fixture_metas <- lapply(receipt_metas, function(meta) {
  meta[PLANT_REFRESH_RECEIPT_FIELDS] <- NULL
  meta
})
partial_metas <- fixture_metas
partial_metas[[1L]]$built_at <- "2026-07-18"
partial_failed <- tryCatch({
  resolve_plant_source_set("data/sites", fixture_index, receipt_sites,
                           partial_metas, require_bundle_metas = TRUE)
  FALSE
}, error = function(error) grepl("partial or mixed", conditionMessage(error)))
assert(partial_failed, "a partial future source receipt fell back to legacy mode")
future_values <- list(
  receipt_version = "plant-source-receipt-v2",
  product = "DP1.10058.001",
  built_at = "2026-07-18",
  source_start = "2013-01",
  source_cutoff = "2026-06-30",
  source_receipt_id = paste0("plant-query-fixture-sha256-",
                             paste(rep("a", 64L), collapse = "")),
  query_package = "basic",
  neon_utilities_version = "2.4.2",
  source_digest = paste(rep("a", 64L), collapse = ""),
  builder_commit = paste(rep("b", 40L), collapse = ""),
  neon_release = NA_character_
)
future_index <- fixture_index
for (field in names(future_values)) attr(future_index, field) <- future_values[[field]]
future_metas <- fixture_metas
for (site in names(future_metas))
  for (field in names(future_values))
    future_metas[[site]][[field]] <- future_values[[field]]
future_receipt <- resolve_plant_source_set(
  "data/sites", future_index, receipt_sites, future_metas,
  require_bundle_metas = TRUE
)
assert(identical(future_receipt$provenance_class, "query-snapshot") &&
       identical(future_receipt$source_cutoff, "2026-06-30") &&
       is.na(future_receipt$neon_release),
       "a complete query-snapshot receipt did not resolve as refreshed data")
future_search <- list(
  built_at = future_receipt$built_at,
  repository_imported_at = future_receipt$repository_imported_at,
  neon_release = future_receipt$neon_release,
  source_start = future_receipt$source_start,
  source_cutoff = future_receipt$source_cutoff,
  source_receipt_id = future_receipt$source_receipt_id,
  source_digest = future_receipt$source_digest,
  source_receipt_basis = future_receipt$receipt_basis,
  source_provenance_class = future_receipt$provenance_class,
  source_bundle_commit = future_receipt$bundle_commit,
  query_package = future_receipt$query_package,
  neon_utilities_version = future_receipt$neon_utilities_version
)
verify_plant_search_receipt(future_search, future_receipt)
future_search$source_cutoff <- "2026-06-29"
stale_search_failed <- tryCatch({
  verify_plant_search_receipt(future_search, future_receipt)
  FALSE
}, error = function(error) grepl("differs", conditionMessage(error)))
assert(stale_search_failed, "a stale search-index source receipt passed")
midmonth_values <- future_values
midmonth_values$source_cutoff <- "2026-06-29"
midmonth_failed <- tryCatch({
  .validate_plant_refresh_receipt(midmonth_values)
  FALSE
}, error = function(error) TRUE)
assert(midmonth_failed, "a mid-month cutoff passed the monthly query receipt")
future_metas[[1L]]$source_digest <- paste(rep("c", 64L), collapse = "")
future_metas[[1L]]$source_receipt_id <- paste0(
  "plant-query-fixture-sha256-", future_metas[[1L]]$source_digest
)
mixed_failed <- tryCatch({
  resolve_plant_source_set("data/sites", future_index, receipt_sites,
                           future_metas, require_bundle_metas = TRUE)
  FALSE
}, error = function(error) grepl("differs", conditionMessage(error)))
assert(mixed_failed, "mixed refreshed source digests passed the family gate")

# Raw fetch/build boundaries reject plausible-looking cross-site and malformed
# records before they can become runtime keys or source-vintage evidence.
raw_rows <- data.frame(
  siteID = c("SRER", "SRER"),
  plotID = c("SRER_001", "SRER_002"),
  endDate = c("2013-01-01", "2026-06-30T23:59:59.125Z"),
  stringsAsFactors = FALSE
)
validate_plant_source_rows(
  raw_rows, "SRER", "fixture", "2013-01-01", "2026-06-30"
)
row_gate_fails <- function(frame, consumed = NULL) {
  tryCatch({
    validate_plant_source_rows(
      frame, "SRER", "fixture", "2013-01-01", "2026-06-30", consumed
    )
    FALSE
  }, error = function(error) TRUE)
}
foreign_site <- raw_rows
foreign_site$siteID[1L] <- "ABBY"
assert(row_gate_fails(foreign_site),
       "a foreign siteID passed the raw-row boundary")
foreign_plot <- raw_rows
foreign_plot$plotID[1L] <- "ABBY_001"
assert(row_gate_fails(foreign_plot),
       "a foreign retained plotID passed behind a matching siteID")
malformed_date <- raw_rows
malformed_date$endDate[1L] <- "2013-01-01garbage"
assert(row_gate_fails(malformed_date),
       "an endDate with trailing junk passed the raw-row boundary")
invalid_clock <- raw_rows
invalid_clock$endDate[1L] <- "2013-01-01T25:00:00Z"
assert(row_gate_fails(invalid_clock),
       "an endDate with an invalid clock passed the raw-row boundary")
out_of_window <- raw_rows
out_of_window$endDate[1L] <- "2012-12-31"
assert(row_gate_fails(out_of_window),
       "an out-of-window endDate passed the raw-row boundary")
masked_rows <- rbind(raw_rows[1L, ], foreign_plot[1L, ])
validate_plant_source_rows(
  masked_rows, "SRER", "fixture", "2013-01-01", "2026-06-30",
  c(TRUE, FALSE)
)
assert(row_gate_fails(masked_rows, c(TRUE, TRUE)),
       "the consumed-row mask failed to gate a foreign retained plotID")

occ_row <- function(plotID, subplotID, year, bout, taxonID, scientificName,
                    nativity = "Native", status = "N", cover = 10,
                    scale = 1, row_id = NA_character_) {
  data.frame(
    plotID = plotID, subplotID = subplotID, scale = scale, year = year, bout = bout,
    taxonID = taxonID, scientificName = scientificName, taxonRank = "species",
    family = "Fixtureaceae", nativity = nativity, nativeStatusCode = status,
    percentCover = cover, is_species = TRUE, plotType = "distributed",
    nlcdClass = "fixture", lat = 0, lng = 0, row_id = row_id,
    stringsAsFactors = FALSE)
}

# 1. One deterministic bout per plot-year, then one latest year per plot.
snap_fx <- rbind(
  occ_row("SRER_001", "31_1", 2020, 1, "OLD", "Old species", row_id = "old"),
  occ_row("SRER_001", "31_1", 2020, 2, "NEW", "New species", row_id = "new"),
  occ_row("SRER_001", "31_1", 2021, 1, "NOW", "Now species", row_id = "now"),
  occ_row("SRER_002", "31_1", 2020, NA, "B", "Beta species", row_id = "beta"))
py <- snapshot_by_plot_year(snap_fx)
assert(setequal(py$row_id, c("new", "now", "beta")), "snapshot_by_plot_year pooled or selected the wrong bout")
sup <- attr(py, "snapshot_support")
assert(nrow(sup) == 3L && sup$n_bouts_observed[sup$plotID == "SRER_001" & sup$year == 2020] == 2L,
       "snapshot support did not retain observed-bout counts")
latest <- latest_snapshot(snap_fx)
assert(setequal(latest$row_id, c("now", "beta")), "latest_snapshot did not select one latest plot survey")
set.seed(42)
py_perm <- snapshot_by_plot_year(snap_fx[sample(seq_len(nrow(snap_fx))), ])
assert(identical(sort(py$row_id), sort(py_perm$row_id)), "bout selection depends on input row order")

# 2. Annual responses use the recurrent plot panel and never borrow an older bout.
annual_fx <- rbind(
  occ_row("SRER_001", "31_1", 2020, 1, "OLD", "Old species", cover = 90),
  occ_row("SRER_001", "31_1", 2020, 2, "A", "Alpha species", cover = 10),
  occ_row("SRER_001", "31_1", 2021, 1, "A", "Alpha species", cover = 20),
  occ_row("SRER_002", "31_1", 2020, 1, "B", "Beta species", cover = 30),
  occ_row("SRER_002", "31_1", 2021, 1, "B", "Beta species", cover = 40),
  occ_row("SRER_003", "31_1", 2020, 1, "C", "Gamma species", cover = 99),
  occ_row("SRER_003", "31_2", 2020, 1, "D", "Delta species", cover = 99))
rich_ts <- balanced_plant_metric_series(annual_fx, "richness")
assert(identical(attr(rich_ts, "panel_plotIDs"), c("SRER_001", "SRER_002")),
       "changing plot effort leaked into the recurrent panel")
assert(all(rich_ts$n_plots == 2L) && near(rich_ts$value, c(1, 1)),
       "annual richness is not a mean plot-level balanced estimand")
cov_ts <- balanced_plant_metric_series(annual_fx, "total_cover")
assert(near(cov_ts$value, c(20, 30)), "annual cover pooled an older bout or a non-recurrent plot")
trend_fx <- rbind(
  annual_fx,
  occ_row("SRER_004", "31_10", 2020, 1, "E", "Epsilon species", "Introduced", "I", scale = 10, cover = NA),
  occ_row("SRER_004", "31_10", 2021, 1, "E", "Epsilon species", "Introduced", "I", scale = 10, cover = NA))
trend <- native_trend(trend_fx)
pct_support <- balanced_plant_metric_series(trend_fx, "pct_introduced")
rich_support <- balanced_plant_metric_series(trend_fx, "n_introduced")
assert(identical(trend$n_plots, pct_support$n_plots) &&
       identical(trend$n_sampling_units, pct_support$n_sampling_units) &&
       all(rich_support$n_plots > trend$n_plots) && all(trend$n_introduced == 0),
       "introduced-cover trend labels support from the richness panel")
set.seed(99)
rich_perm <- balanced_plant_metric_series(annual_fx[sample(seq_len(nrow(annual_fx))), ], "richness")
assert(near(rich_ts$value, rich_perm$value) && identical(rich_ts$n_plots, rich_perm$n_plots),
       "annual estimand depends on record order")
watch_fx <- rbind(
  occ_row("SRER_001", "31_1", 2020, 1, "INV", "Introduced species", "Introduced", "I", 20),
  occ_row("SRER_002", "31_1", 2020, 1, "NAT", "Native species", "Native", "N", 40))
watch <- invasive_watchlist(watch_fx)
assert(nrow(watch) == 1L && watch$n_supported_plots == 2L && near(watch$mean_cover, 10),
       "watchlist mean cover is still conditioned on presence-only plots")
watch_sp <- species_summary(watch_fx)
assert(near(watch_sp$mean_cover[watch_sp$scientificName == "Introduced species"], 10),
       "species summary does not share the supported-plot cover contract")
cross <- species_cross_scale_occurrence(watch_fx)
assert(grepl("no spread", attr(cross, "interpretation"), fixed = TRUE),
       "cross-scale occurrence retained a spread/management interpretation")

# 3. Exact bias-corrected Chao2, including Q2 == 0 lower-bound semantics.
chao_fx <- rbind(
  occ_row("P", "u1", 2020, 1, "A", "Alpha species"),
  occ_row("P", "u2", 2020, 1, "B", "Beta species"),
  occ_row("P", "u1", 2020, 1, "C", "Gamma species"),
  occ_row("P", "u2", 2020, 1, "C", "Gamma species"),
  occ_row("P", "u1", 2020, 1, "D", "Delta species"),
  occ_row("P", "u2", 2020, 1, "D", "Delta species"),
  occ_row("P", "u3", 2020, 1, "D", "Delta species"),
  occ_row("P", "u4", 2020, 1, "D", "Delta species"))
ch <- chao2(chao_fx)
assert(ch$S_obs == 4L && ch$m == 4L && ch$Q1 == 2L && ch$Q2 == 1L,
       "Chao2 incidence sufficient statistics are wrong")
assert(near(ch$chao2, 4.4) && isTRUE(ch$lower_bound) && is.na(ch$hi) && ch$lo == 4,
       "bias-corrected Chao2/lower-bound contract is wrong for Q2 > 0")
chao_zero <- chao_fx[!(chao_fx$taxonID == "C"), ]
ch0 <- chao2(chao_zero)
assert(ch0$Q2 == 0L && near(ch0$chao2, 3.8), "bias-corrected Chao2 is wrong for Q2 == 0")

# 4. Species-area support counts only finite plot estimates.
sa_fx <- rbind(
  occ_row("P1", "31_1", 2020, 1, "A", "Alpha species", scale = 1),
  occ_row("P1", "31_10", 2020, 1, "B", "Beta species", scale = 10),
  occ_row("P1", "31_100", 2020, 1, "C", "Gamma species", scale = 100),
  occ_row("P2", "31_10", 2020, 1, "B", "Beta species", scale = 10),
  occ_row("P2", "31_100", 2020, 1, "C", "Gamma species", scale = 100))
sa <- species_area_site(sa_fx)
a1 <- sa[sa$area_m2 == 1, ]
assert(a1$n == 1L && is.na(a1$sd) && is.finite(a1$richness),
       "species-area n/SD includes a plot with a missing scale")

# 5. Contradictory NEON nativity routes to Unknown/review; L48 authority is gated.
nat_fx <- rbind(
  occ_row("SRER_001", "31_1", 2020, 1, "X", "Conflict species", "Native", "N"),
  occ_row("SRER_001", "31_2", 2020, 1, "X", "Conflict species", "Introduced", "I"))
auth <- list(authority = data.frame(accepted_symbol = "X", nativity_usda = "Introduced",
                                    stringsAsFactors = FALSE), synonyms = character())
obs <- observed_species(nat_fx, auth)
assert(nrow(obs) == 1L && isTRUE(obs$nativity_conflict) && obs$nativity == "Unknown",
       "within-NEON nativity conflict was silently resolved by mode")
nat_plot <- plot_summary(nat_fx)
assert(nat_plot$n_native == 0L && nat_plot$n_introduced == 0L && nat_plot$n_unknown == 1L,
       "a contradictory taxon contributed to both native and introduced plot metrics")
mm <- flag_nativity_mismatch(nat_fx, auth)
assert(mm$n == 0L, "an unresolved within-NEON conflict became a USDA mismatch")
ak_fx <- occ_row("BARR_001", "31_1", 2020, 1, "X", "Arctic species", "Native", "N")
ak <- flag_nativity_mismatch(ak_fx, auth)
assert(identical(ak$eligible, FALSE) && ak$n == 0L && ak$state == "AK",
       "L48 nativity authority was applied outside the lower 48")
assert(grepl("Single NRCS ecological-site flora", expected_reference_scope(list(status = "ok")), fixed = TRUE),
       "expected-reference scope does not disclose the single-coordinate soil unit")
expected_fx <- list(status = "ok", reference_species = data.frame(
  plantsym = "REF", sciname = "Reference species", comname = "reference",
  rangeprod = 1, is_aggregate = FALSE, is_dominant = TRUE, stringsAsFactors = FALSE),
  ecoclassid = "R000TEST", ecosite_name = "Fixture site", mlra = "000X", source = "esd")
ev <- expected_vs_observed(nat_fx, expected_fx, auth)
assert(nrow(ev$C) == 1L && identical(ev$C$c_class, "review") &&
       !any(c("C_regional", "state_covered", "state_review_reason", "n_regional") %in% names(ev)),
       "observed-not-reference records did not remain in the provenance-safe review lane")
expected_all <- expected_fx
expected_all$reference_species$plantsym <- "X"
ev_all <- expected_vs_observed(nat_fx, expected_all, auth)
assert(nrow(ev_all$C) == 0L && identical(ev_all$C$c_class, character()),
       "a complete observed/reference overlap crashed or fabricated a review row")

# 6. Annual environment values require all 12 months; seasonal drivers are absent.
env_year <- function(y, n, signal) data.frame(
  year = y, ym = sprintf("%04d-%02d", y, seq_len(n)),
  precip_mm = rep(signal, n), stringsAsFactors = FALSE)
env_partial <- rbind(env_year(2020, 12, 1), env_year(2021, 11, 100))
ea <- env_annual(env_partial, "precip")
assert(nrow(ea) == 1L && ea$year == 2020 && ea$value == 12,
       "an incomplete annual climate window entered inference")
ms <- data.frame(year = 2012:2019, value = c(1, 2, 4, 3, 6, 5, 8, 7))
env_full <- do.call(rbind, Map(env_year, ms$year, MoreArgs = list(n = 12), signal = ms$value))
assert(is.null(plant_env_scan(ms, env_full, "precip_winter", lags = 0)),
       "removed seasonal driver entered inferential ranking")
pm1 <- plant_env_perm(ms, env_full, lags = 0, B = 99, seed = 5, only = "precip")
set.seed(8)
pm2 <- plant_env_perm(ms[sample(seq_len(nrow(ms))), ], env_full, lags = 0, B = 99, seed = 5, only = "precip")
assert(near(pm1$p, pm2$p) && near(pm1$top$r, pm2$top$r),
       "serially aware environment null depends on input row order")
verdict <- env_verdict(0.9, 0.01, 10)
assert(isTRUE(verdict$flag) && verdict$word == "exploratory association",
       "environment verdict overstates observational evidence")

# 7. The PDF must use the same snapshot for Chao2 and species-area as its hero.
pdf_body <- paste(deparse(body(build_diversity_report)), collapse = "\n")
assert(grepl("chao2(snap)", pdf_body, fixed = TRUE) &&
       grepl("species_area_site(snap)", pdf_body, fixed = TRUE),
       "PDF estimators do not share the app snapshot contract")

# 8. Every emitted column has a strict unit/NA/estimand contract; no fallback.
cb <- plant_codebook(list("fixture.csv" = data.frame(
  plotID = "P1", percentCover = 10, snapshotContract = "latest plot year/bout",
  stringsAsFactors = FALSE)))
assert(all(c("meaning", "units", "na_semantics", "estimand") %in% names(cb)) &&
       all(nzchar(cb$meaning)) && all(nzchar(cb$na_semantics)) && all(nzchar(cb$estimand)),
       "codebook omitted field-level science metadata")
ground_cb <- plant_codebook(list("ground_cover_all.csv" = data.frame(
  plotID = "P1", subplotID = "31_1", year = 2020L, bout = 1L,
  otherVariables = "litter", groundCoverPct = 25, stringsAsFactors = FALSE)))
ground_row <- ground_cb[ground_cb$column == "groundCoverPct", , drop = FALSE]
assert(nrow(ground_row) == 1L && grepl("abiotic", ground_row$meaning) &&
       grepl("abiotic", ground_row$estimand),
       "ground-cover percent inherited the plant-occurrence dictionary contract")
empty_frame <- function(cols) as.data.frame(stats::setNames(replicate(length(cols), logical(0), simplify = FALSE), cols))
env_cols <- c("siteID", "ym", "date", "precip_mm", "temp_c", "temp_min", "temp_max",
              "flowering_pct", "flowering_pct_n", "greenup_pct", "greenup_pct_n",
              "fruiting_pct", "fruiting_pct_n", "source", "year")
prov_cols <- c(
  "artifact", "site", "builtAt", "neonRelease", "repositoryImportedAt",
  "sourceStart", "sourceCutoff", "sourceReceiptId", "sourceDigest",
  "sourceReceiptBasis", "sourceProvenanceClass", "sourceBundleCommit",
  "queryPackage", "neonUtilitiesVersion", "dpid", "exportedAt",
  "bundleFile", "bundleMd5", "snapshotContract", "estimatorContract",
  "sourceLicense"
)
ref_cols <- c("site", "referenceScope", "referenceLatitude", "referenceLongitude", "source",
              "ecoclassid", "ecositeName", "mlra", "queryDate", "sourceLicense")
rank_cols <- c("plant_metric", "driver", "driver_label", "spearman_r", "best_lag_years",
               "matched_years", "lag_search_p", "permutation_scope")
schema_cb <- plant_codebook(list(
  "environment_context.csv" = empty_frame(env_cols),
  "provenance.csv" = empty_frame(prov_cols),
  "reference_provenance.csv" = empty_frame(ref_cols),
  "context_association_scan.csv" = empty_frame(rank_cols)))
assert(nrow(schema_cb) == length(env_cols) + length(prov_cols) + length(ref_cols) + length(rank_cols),
       "strict codebook does not cover an emitted export schema")
unknown_failed <- tryCatch({
  plant_codebook(list("bad.csv" = data.frame(undocumented_field = 1)))
  FALSE
}, error = function(e) grepl("undocumented exported columns", conditionMessage(e), fixed = TRUE))
assert(unknown_failed, "codebook accepted an undocumented exported column")
assert(is.null(plant_codebook(list("empty.csv" = data.frame()))),
       "zero-column empty export crashed the codebook")

cat("science-contract fixtures: PASS\n")
