#!/usr/bin/env Rscript

# Independent semantic review oracle for a complete Plant Diversity refresh.
#
# This deliberately does not source the application helpers. It reconstructs the
# registered current-state contract `plant-snapshot-v2` (docs/SCIENCE-CONTRACT.md,
# "Observation model" and "Snapshot selection") directly from the bundled rows in
# base R: the grain event F (latest full-grain 1/10/100 m2 year, best bout, only
# full-grain plots) and the cover event Q (newest year whose best-covered bout holds
# at least max(3, half of F's plots) plots with 1 m2 rows; 1 m2 rows only). It then
# derives species support, the structural-zero cover denominator, and the
# incidence-based Chao2 inputs, and reconciles the candidate to data/site_index.rds.
# The first argument is the last-known-good repository root and the optional
# second argument is the candidate root (default: the current working directory).

args <- commandArgs(trailingOnly = TRUE)
if (!length(args) || length(args) > 2L) {
  stop("usage: Rscript scripts/review_refresh_candidate.R <production-root> [candidate-root]",
       call. = FALSE)
}

production_root <- normalizePath(args[[1L]], mustWork = TRUE)
candidate_root <- normalizePath(if (length(args) == 2L) args[[2L]] else ".",
                                mustWork = TRUE)

sites_for <- function(root) {
  paths <- sort(list.files(file.path(root, "data", "sites"),
                           pattern = "^[A-Z0-9]{4}[.]rds$", full.names = TRUE))
  stats::setNames(paths, sub("[.]rds$", "", basename(paths)))
}

production_paths <- sites_for(production_root)
candidate_paths <- sites_for(candidate_root)
if (length(production_paths) != 46L || length(candidate_paths) != 46L ||
    !identical(names(production_paths), names(candidate_paths))) {
  stop("both roots must contain the same canonical 46-site plant inventory",
       call. = FALSE)
}

as_text <- function(value) {
  value <- as.character(value)
  value[is.na(value)] <- "<NA>"
  value
}

# Bout identity for every row, within its year (plant-snapshot-v2).
# Returns list(year = numeric year or NA, key = canonical bout key or NA when the
# row belongs to no event, rank = within-year order of the key, higher = later).
row_bout_keys <- function(occ) {
  n <- nrow(occ)
  year <- suppressWarnings(as.numeric(as.character(occ$year)))
  key <- rep(NA_character_, n)
  rank <- rep(NA_real_, n)
  if (!n) return(list(year = year, key = key, rank = rank))
  bouts <- trimws(as.character(occ$bout))
  usable <- !is.na(bouts) & nzchar(bouts)
  has_year <- is.finite(year)
  for (rows in split(which(has_year), year[has_year], drop = TRUE)) {
    if (!any(usable[rows])) {
      # Nothing in this year carries a bout: one unspecified bout.
      key[rows] <- "<unspecified>"
      rank[rows] <- 0
      next
    }
    identified <- rows[usable[rows]]
    values <- bouts[identified]
    numeric_values <- suppressWarnings(as.numeric(values))
    if (all(is.finite(numeric_values))) {
      key[identified] <- format(numeric_values, scientific = FALSE, trim = TRUE,
                                digits = 15)
      rank[identified] <- numeric_values
    } else {
      ordered <- sort(unique(values), method = "radix")
      key[identified] <- values
      rank[identified] <- match(values, ordered)
    }
    # Blank-bout rows in a year where something carries a bout: no event.
  }
  list(year = year, key = key, rank = rank)
}

# Choose the bout with the most qualifying plots; tie goes to the later bout.
best_bout <- function(bout_keys, bout_ranks, plot_sets) {
  counts <- vapply(plot_sets, length, integer(1))
  if (!length(counts) || max(counts) == 0L) return(NULL)
  candidates <- which(counts == max(counts))
  pick <- candidates[which.max(bout_ranks[candidates])]
  list(key = bout_keys[[pick]], rank = bout_ranks[[pick]],
       plots = plot_sets[[pick]])
}

site_events <- function(occ) {
  keys <- row_bout_keys(occ)
  scale <- suppressWarnings(as.numeric(as.character(occ$scale)))
  plot <- as.character(occ$plotID)
  in_event <- is.finite(keys$year) & !is.na(keys$key) & !is.na(plot)
  event_years <- sort(unique(keys$year[in_event]), decreasing = TRUE)

  bouts_in_year <- function(y) {
    rows <- which(in_event & keys$year == y)
    bk <- unique(keys$key[rows])
    list(rows = rows, keys = bk,
         ranks = vapply(bk, function(k) keys$rank[rows][match(k, keys$key[rows])],
                        numeric(1)))
  }

  grain <- NULL
  for (y in event_years) {
    yb <- bouts_in_year(y)
    sets <- lapply(yb$keys, function(k) {
      r <- yb$rows[keys$key[yb$rows] == k]
      by_plot <- split(scale[r], plot[r])
      sort(names(by_plot)[vapply(by_plot, function(s) all(c(1, 10, 100) %in% s),
                                 logical(1))], method = "radix")
    })
    chosen <- best_bout(yb$keys, yb$ranks, sets)
    if (!is.null(chosen)) { grain <- c(list(year = y), chosen); break }
  }
  grain_keep <- if (is.null(grain)) rep(FALSE, nrow(occ)) else
    in_event & keys$year == grain$year & keys$key == grain$key & plot %in% grain$plots
  n_grain <- if (is.null(grain)) 0L else length(grain$plots)
  threshold <- max(3, ceiling(0.5 * n_grain))

  cover <- NULL
  for (y in event_years) {
    yb <- bouts_in_year(y)
    sets <- lapply(yb$keys, function(k) {
      r <- yb$rows[keys$key[yb$rows] == k & scale[yb$rows] %in% 1]
      sort(unique(plot[r]), method = "radix")
    })
    chosen <- best_bout(yb$keys, yb$ranks, sets)
    if (!is.null(chosen) && length(chosen$plots) >= threshold) {
      cover <- c(list(year = y), chosen); break
    }
  }
  cover_keep <- if (is.null(cover)) rep(FALSE, nrow(occ)) else
    in_event & keys$year == cover$year & keys$key == cover$key &
      plot %in% cover$plots & scale %in% 1
  list(grain = grain, grain_keep = grain_keep, cover = cover,
       cover_keep = cover_keep)
}

resolve_nativity <- function(frame) {
  if (!nrow(frame)) return(frame)
  taxon <- as.character(frame$taxonID)
  missing <- is.na(taxon) | !nzchar(taxon)
  taxon[missing] <- as.character(frame$scientificName[missing])
  keys <- paste(taxon, sep = "\r")
  conflicts <- names(which(vapply(split(as.character(frame$nativity), keys),
                                    function(values) {
    values <- unique(values[!is.na(values)])
    all(c("Native", "Introduced") %in% values)
  }, logical(1))))
  frame$nativity <- as.character(frame$nativity)
  frame$nativity[keys %in% conflicts] <- "Unknown"
  attr(frame, "nativity_conflicts") <- length(conflicts)
  frame
}

event_label <- function(event) {
  if (is.null(event)) return(NA_character_)
  paste0(format(event$year, scientific = FALSE, trim = TRUE), " b", event$key)
}

site_metrics <- function(path) {
  bundle <- readRDS(path)
  if (!is.list(bundle) || !identical(names(bundle), c("occ", "ground", "meta")) ||
      !is.data.frame(bundle$occ) || !is.data.frame(bundle$ground)) {
    stop(sprintf("invalid bundle structure: %s", path), call. = FALSE)
  }
  occ <- as.data.frame(bundle$occ, stringsAsFactors = FALSE)
  events <- site_events(occ)

  # Grain event F: richness, plot count and plot lists.
  grain_rows <- occ[events$grain_keep, , drop = FALSE]
  grain_species <- grain_rows[grain_rows$is_species %in% TRUE, , drop = FALSE]
  plot_ids <- if (is.null(events$grain)) character(0) else events$grain$plots
  plot_richness <- vapply(plot_ids, function(plot_id) {
    length(unique(as.character(
      grain_species$scientificName[grain_species$plotID == plot_id])))
  }, integer(1))

  # Cover event Q: scale-1 rows only; nativity conflicts resolved within Q.
  cover_rows <- occ[events$cover_keep, , drop = FALSE]
  cover_plots <- if (is.null(events$cover)) character(0) else events$cover$plots
  one <- resolve_nativity(cover_rows[cover_rows$is_species %in% TRUE, , drop = FALSE])
  # Structural-zero denominator: distinct 1 m2 subplots per plot represented by
  # at least one eligible (species-level) record in Q, fixed before any focal
  # species filter (SCIENCE-CONTRACT "Cover denominators").
  n_subplots <- vapply(cover_plots, function(plot_id) {
    length(unique(as.character(one$subplotID[one$plotID == plot_id])))
  }, integer(1))
  names(n_subplots) <- cover_plots

  positive <- one[is.finite(one$percentCover) & one$percentCover > 0, , drop = FALSE]
  cover_by_group <- numeric(0)
  if (nrow(positive)) {
    cover_keys <- paste(as_text(positive$plotID), as_text(positive$scientificName),
                        as_text(positive$family), as_text(positive$nativity), sep = "\r")
    cover_sums <- tapply(positive$percentCover, cover_keys, sum)
    key_parts <- strsplit(names(cover_sums), "\r", fixed = TRUE)
    cover_table <- data.frame(
      plotID = vapply(key_parts, `[[`, character(1), 1L),
      scientificName = vapply(key_parts, `[[`, character(1), 2L),
      family = vapply(key_parts, `[[`, character(1), 3L),
      nativity = vapply(key_parts, `[[`, character(1), 4L),
      cover_sum = as.numeric(cover_sums), stringsAsFactors = FALSE
    )
    # The registered index publishes each plot-species mean cover rounded to two
    # decimals before the nativity sums; reproduce that published precision (it
    # moves YELL's 2024 b1 share from 0.752 to below 0.75).
    cover_table$mean_cover <- round(cover_table$cover_sum /
      n_subplots[match(cover_table$plotID, names(n_subplots))], 2)
    cover_by_group <- tapply(cover_table$mean_cover, cover_table$nativity, sum)
  }
  total_cover <- sum(cover_by_group, na.rm = TRUE)
  introduced_cover <- unname(cover_by_group["Introduced"])
  unknown_cover <- unname(cover_by_group["Unknown"])
  if (!length(introduced_cover) || !is.finite(introduced_cover)) introduced_cover <- 0
  if (!length(unknown_cover) || !is.finite(unknown_cover)) unknown_cover <- 0

  incidence <- one
  unit <- paste(as_text(incidence$plotID), as_text(incidence$subplotID),
                as_text(incidence$year), as_text(incidence$bout), sep = "|")
  incidence_counts <- if (nrow(incidence)) tapply(
    unit, as.character(incidence$scientificName), function(value) length(unique(value))
  ) else integer(0)
  observed <- length(incidence_counts)
  uniques <- sum(incidence_counts == 1L)
  doubletons <- sum(incidence_counts == 2L)
  units <- length(unique(unit))
  chao2 <- if (units >= 2L && observed > 0L) {
    observed + ((units - 1) / units) * uniques * (uniques - 1) /
      (2 * (doubletons + 1))
  } else NA_real_


  years <- sort(unique(as.integer(occ$year[!is.na(occ$year)])))
  data.frame(
    site = as.character(bundle$meta$site),
    occ_rows = nrow(occ), ground_rows = nrow(bundle$ground),
    species_rows = sum(occ$is_species %in% TRUE),
    coarse_rows = sum(!(occ$is_species %in% TRUE)),
    first_year = if (length(years)) min(years) else NA_integer_,
    last_year = if (length(years)) max(years) else NA_integer_,
    n_years = length(years), n_plots_all = length(unique(occ$plotID)),
    grain_year = if (is.null(events$grain)) NA_real_ else events$grain$year,
    grain_bout = if (is.null(events$grain)) NA_character_ else events$grain$key,
    cover_year = if (is.null(events$cover)) NA_real_ else events$cover$year,
    cover_bout = if (is.null(events$cover)) NA_character_ else events$cover$key,
    grain_event = event_label(events$grain),
    cover_event = event_label(events$cover),
    n_plots_snapshot = length(plot_ids),
    n_plots_cover = length(cover_plots),
    snapshot_species = length(unique(as.character(grain_species$scientificName))),
    mean_plot_richness_400m2 = if (length(plot_richness)) mean(plot_richness) else NA_real_,
    pct_introduced_cover = if (is.finite(total_cover) && total_cover > 0)
      round(100 * introduced_cover / total_cover, 1) else NA_real_,
    pct_unknown_cover = if (is.finite(total_cover) && total_cover > 0)
      round(100 * unknown_cover / total_cover, 1) else NA_real_,
    incidence_units_1m2 = units, chao2_observed = observed,
    chao2_lower_bound = round(chao2, 1), chao2_uniques = uniques,
    chao2_doubletons = doubletons,
    nativity_conflicts = if (is.null(attr(one, "nativity_conflicts"))) 0L else
      attr(one, "nativity_conflicts"),
    stringsAsFactors = FALSE
  )
}

metrics_for <- function(paths) {
  rows <- lapply(paths, site_metrics)
  output <- do.call(rbind, rows)
  rownames(output) <- NULL
  output[order(output$site), , drop = FALSE]
}

production <- metrics_for(production_paths)
candidate <- metrics_for(candidate_paths)

candidate_index <- readRDS(file.path(candidate_root, "data", "site_index.rds"))
candidate_contract <- attr(candidate_index, "snapshot_contract", exact = TRUE)
if (!identical(candidate_contract, "plant-snapshot-v2")) {
  stop(sprintf(paste0("candidate data/site_index.rds must declare ",
                      "snapshot_contract = \"plant-snapshot-v2\" (found %s)"),
               if (is.null(candidate_contract)) "no attribute" else
                 paste(as_text(candidate_contract), collapse = ",")),
       call. = FALSE)
}
candidate_index <- candidate_index[order(candidate_index$site), , drop = FALSE]

index_mismatches <- function(metrics, index) {
  index <- index[match(metrics$site, index$site), , drop = FALSE]
  same_number <- function(a, b) {
    a <- as.numeric(a); b <- as.numeric(b)
    (is.na(a) & is.na(b)) | (!is.na(a) & !is.na(b) & abs(a - b) <= 1e-10)
  }
  ok <- !is.na(index$site) &
    same_number(metrics$snapshot_species, index$richness) &
    same_number(metrics$n_plots_snapshot, index$n_plots) &
    same_number(metrics$pct_introduced_cover, index$pct_introduced)
  data.frame(site = metrics$site,
             index_richness = index$richness, v2_richness = metrics$snapshot_species,
             index_n_plots = index$n_plots, v2_n_plots = metrics$n_plots_snapshot,
             index_pct_introduced = index$pct_introduced,
             v2_pct_introduced = metrics$pct_introduced_cover,
             stringsAsFactors = FALSE)[!ok, , drop = FALSE]
}

if (!identical(as.character(candidate$site), as.character(candidate_index$site)) ||
    !identical(as.integer(candidate$snapshot_species),
               as.integer(candidate_index$richness)) ||
    !identical(as.integer(candidate$n_plots_snapshot),
               as.integer(candidate_index$n_plots)) ||
    !isTRUE(all.equal(as.numeric(candidate$pct_introduced_cover),
                      as.numeric(candidate_index$pct_introduced),
                      check.attributes = FALSE, tolerance = 1e-10))) {
  bad <- index_mismatches(candidate, candidate_index)
  if (nrow(bad)) print(bad, row.names = FALSE)
  stop("independent candidate metrics do not reconcile to data/site_index.rds",
       call. = FALSE)
}

# The production tree's index may predate plant-snapshot-v2. Compare it to the v2
# reconstruction of the production bundles for information only; never fail.
production_index <- readRDS(file.path(production_root, "data", "site_index.rds"))
production_contract <- attr(production_index, "snapshot_contract", exact = TRUE)
production_index_note <- if (is.null(production_contract))
  "production index predates plant-snapshot-v2" else
    sprintf("production index declares %s", paste(as_text(production_contract),
                                                  collapse = ","))
production_index_diff <- index_mismatches(production, production_index)

receipt_fields <- c(
  "receipt_version", "product", "built_at", "source_start", "source_cutoff",
  "source_receipt_id", "query_package", "neon_utilities_version",
  "source_digest", "builder_commit", "neon_release"
)
index_receipt <- stats::setNames(lapply(receipt_fields, function(field) {
  attr(candidate_index, field, exact = TRUE)
}), receipt_fields)
for (site in names(candidate_paths)) {
  meta <- readRDS(candidate_paths[[site]])$meta
  for (field in receipt_fields) {
    if (!identical(meta[[field]], index_receipt[[field]])) {
      stop(sprintf("candidate receipt differs at %s (%s)", site, field),
           call. = FALSE)
    }
  }
}

schema_signature <- function(path) {
  bundle <- readRDS(path)
  paste(
    paste(names(bundle$occ), vapply(bundle$occ, function(value)
      paste(class(value), collapse = "/"), character(1)), sep = ":", collapse = "|"),
    paste(names(bundle$ground), vapply(bundle$ground, function(value)
      paste(class(value), collapse = "/"), character(1)), sep = ":", collapse = "|"),
    sep = " || "
  )
}
if (length(unique(vapply(candidate_paths, schema_signature, character(1)))) != 1L) {
  stop("candidate bundle schemas are not identical across all 46 sites",
       call. = FALSE)
}

delta <- candidate
numeric_columns <- names(candidate)[vapply(candidate, is.numeric, logical(1))]
for (column in numeric_columns) {
  delta[[column]] <- candidate[[column]] - production[[column]]
}

network_taxa <- function(paths) {
  sort(unique(unlist(lapply(paths, function(path) {
    occ <- readRDS(path)$occ
    as.character(occ$scientificName[occ$is_species %in% TRUE])
  }), use.names = FALSE)), method = "radix")
}
production_taxa <- network_taxa(production_paths)
candidate_taxa <- network_taxa(candidate_paths)

cat("PLANT DIVERSITY REFRESH SEMANTIC REVIEW\n")
cat(sprintf("production_root=%s\ncandidate_root=%s\n", production_root,
            candidate_root))
cat(sprintf("sites=%d receipt_version=%s built_at=%s source_start=%s source_cutoff=%s\n",
            nrow(candidate), index_receipt$receipt_version,
            index_receipt$built_at, index_receipt$source_start,
            index_receipt$source_cutoff))
cat(sprintf("source_receipt_id=%s\nsource_digest=%s\nbuilder_commit=%s\nneon_release=%s\n",
            index_receipt$source_receipt_id, index_receipt$source_digest,
            index_receipt$builder_commit,
            if (is.na(index_receipt$neon_release)) "NA" else index_receipt$neon_release))

cat("\nNETWORK TOTALS (production -> candidate; delta)\n")
for (column in c("occ_rows", "ground_rows", "species_rows", "coarse_rows",
                 "n_plots_all", "n_plots_snapshot", "incidence_units_1m2")) {
  old <- sum(production[[column]], na.rm = TRUE)
  new <- sum(candidate[[column]], na.rm = TRUE)
  cat(sprintf("%-24s %12.1f -> %12.1f (%+12.1f)\n", column, old, new,
              new - old))
}
cat(sprintf("%-24s %12d -> %12d (%+12d)\n", "network species",
            length(production_taxa), length(candidate_taxa),
            length(candidate_taxa) - length(production_taxa)))
cat(sprintf("species added=%d removed=%d retained=%d\n",
            length(setdiff(candidate_taxa, production_taxa)),
            length(setdiff(production_taxa, candidate_taxa)),
            length(intersect(production_taxa, candidate_taxa))))

cat("\nSITE CHANGE COUNTS\n")
for (column in c("occ_rows", "ground_rows", "snapshot_species",
                 "n_plots_snapshot", "mean_plot_richness_400m2",
                 "pct_introduced_cover", "pct_unknown_cover",
                 "incidence_units_1m2", "chao2_lower_bound")) {
  values <- delta[[column]]
  cat(sprintf("%-28s higher=%2d same=%2d lower=%2d NA=%2d range=[%s,%s]\n",
              column, sum(values > 0, na.rm = TRUE),
              sum(values == 0, na.rm = TRUE), sum(values < 0, na.rm = TRUE),
              sum(is.na(values)),
              format(min(values, na.rm = TRUE), digits = 8),
              format(max(values, na.rm = TRUE), digits = 8)))
}

rank_delta <- function(column, n = 6L) {
  ord <- order(delta[[column]], decreasing = TRUE, na.last = NA)
  keep <- unique(c(utils::head(ord, n), utils::tail(ord, n)))
  data.frame(site = delta$site[keep], production = production[[column]][keep],
             candidate = candidate[[column]][keep], delta = delta[[column]][keep],
             stringsAsFactors = FALSE)
}
cat("\nLARGEST SNAPSHOT-SPECIES DELTAS\n")
print(rank_delta("snapshot_species"), row.names = FALSE)
cat("\nLARGEST INTRODUCED-COVER DELTAS (percentage points)\n")
print(rank_delta("pct_introduced_cover"), row.names = FALSE)
cat(sprintf("\nPRODUCTION INDEX VS V2 RECONSTRUCTION (informational; %s; %d of %d sites differ)\n",
            production_index_note, nrow(production_index_diff), nrow(production)))
for (row in seq_len(nrow(production_index_diff))) {
  d <- production_index_diff[row, ]
  cat(sprintf("%s %s: richness %s -> %s; n_plots %s -> %s; pct_introduced %s -> %s\n",
              d$site, production_index_note,
              as_text(d$index_richness), as_text(d$v2_richness),
              as_text(d$index_n_plots), as_text(d$v2_n_plots),
              as_text(d$index_pct_introduced), as_text(d$v2_pct_introduced)))
}
cat("\nALL-SITE REVIEW TABLE\n")
review <- data.frame(
  site = candidate$site,
  production_years = paste0(production$first_year, "-", production$last_year),
  candidate_years = paste0(candidate$first_year, "-", candidate$last_year),
  production_occ = production$occ_rows,
  candidate_occ = candidate$occ_rows,
  production_snapshot_species = production$snapshot_species,
  candidate_snapshot_species = candidate$snapshot_species,
  production_plots = production$n_plots_snapshot,
  candidate_plots = candidate$n_plots_snapshot,
  candidate_grain_event = candidate$grain_event,
  candidate_cover_event = candidate$cover_event,
  candidate_cover_plots = candidate$n_plots_cover,
  production_intro_pct = production$pct_introduced_cover,
  candidate_intro_pct = candidate$pct_introduced_cover,
  production_chao2 = production$chao2_lower_bound,
  candidate_chao2 = candidate$chao2_lower_bound,
  stringsAsFactors = FALSE
)
print(review, row.names = FALSE)

cat("\nREVIEW ASSERTIONS PASSED: 46-site identity; uniform bundle schema; " ,
    "one matching complete query-snapshot receipt across every bundle and index; " ,
    "independent plant-snapshot-v2 grain-event richness/plot and cover-event ",
    "introduced-cover parity with site_index.\n",
    sep = "")
