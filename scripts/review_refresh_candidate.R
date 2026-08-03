#!/usr/bin/env Rscript

# Independent semantic review oracle for a complete Plant Diversity refresh.
#
# This deliberately does not source the application helpers. It reconstructs the
# registered latest-plot snapshot, species support, structural-zero cover
# denominator, and incidence-based Chao2 inputs directly from the bundled rows.
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

select_plot_year_bout <- function(occ) {
  if (!nrow(occ)) return(occ)
  year_key <- paste(as_text(occ$plotID), as_text(occ$year), sep = "\r")
  keep <- rep(FALSE, nrow(occ))
  for (rows in split(seq_len(nrow(occ)), year_key, drop = TRUE)) {
    bouts <- trimws(as.character(occ$bout[rows]))
    usable <- !is.na(bouts) & nzchar(bouts)
    if (!any(usable)) {
      keep[rows] <- TRUE
      next
    }
    values <- unique(bouts[usable])
    numeric_values <- suppressWarnings(as.numeric(values))
    selected <- if (all(is.finite(numeric_values))) {
      values[numeric_values == max(numeric_values)][1L]
    } else {
      sort(values, method = "radix")[length(values)]
    }
    if (all(is.finite(numeric_values))) {
      row_values <- suppressWarnings(as.numeric(bouts))
      keep[rows[usable & is.finite(row_values) &
                  row_values == as.numeric(selected)]] <- TRUE
    } else {
      keep[rows[usable & bouts == selected]] <- TRUE
    }
  }
  plot_year <- occ[keep, , drop = FALSE]
  keep_latest <- rep(FALSE, nrow(plot_year))
  for (rows in split(seq_len(nrow(plot_year)), as_text(plot_year$plotID),
                     drop = TRUE)) {
    years <- suppressWarnings(as.numeric(as.character(plot_year$year[rows])))
    if (any(is.finite(years))) {
      keep_latest[rows[is.finite(years) & years == max(years, na.rm = TRUE)]] <- TRUE
    } else {
      keep_latest[rows] <- TRUE
    }
  }
  plot_year[keep_latest, , drop = FALSE]
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

site_metrics <- function(path) {
  bundle <- readRDS(path)
  if (!is.list(bundle) || !identical(names(bundle), c("occ", "ground", "meta")) ||
      !is.data.frame(bundle$occ) || !is.data.frame(bundle$ground)) {
    stop(sprintf("invalid bundle structure: %s", path), call. = FALSE)
  }
  occ <- bundle$occ
  snapshot <- select_plot_year_bout(occ)
  species <- snapshot[snapshot$is_species %in% TRUE, , drop = FALSE]
  species <- resolve_nativity(species)

  plot_ids <- sort(unique(as.character(snapshot$plotID)), method = "radix")
  plot_richness <- vapply(plot_ids, function(plot_id) {
    length(unique(as.character(species$scientificName[species$plotID == plot_id])))
  }, integer(1))

  one <- species[suppressWarnings(as.numeric(species$scale)) == 1, , drop = FALSE]
  n_subplots <- if (nrow(one)) vapply(plot_ids, function(plot_id) {
    length(unique(as.character(one$subplotID[one$plotID == plot_id])))
  }, integer(1)) else stats::setNames(integer(length(plot_ids)), plot_ids)
  names(n_subplots) <- plot_ids

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
    cover_table$mean_cover <- cover_table$cover_sum /
      n_subplots[match(cover_table$plotID, names(n_subplots))]
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
    n_plots_snapshot = length(plot_ids),
    snapshot_species = length(unique(as.character(species$scientificName))),
    mean_plot_richness_400m2 = mean(plot_richness),
    pct_introduced_cover = if (is.finite(total_cover) && total_cover > 0)
      round(100 * introduced_cover / total_cover, 1) else NA_real_,
    pct_unknown_cover = if (is.finite(total_cover) && total_cover > 0)
      round(100 * unknown_cover / total_cover, 1) else NA_real_,
    incidence_units_1m2 = units, chao2_observed = observed,
    chao2_lower_bound = round(chao2, 1), chao2_uniques = uniques,
    chao2_doubletons = doubletons,
    nativity_conflicts = attr(species, "nativity_conflicts"),
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
candidate_index <- candidate_index[order(candidate_index$site), , drop = FALSE]
if (!identical(as.character(candidate$site), as.character(candidate_index$site)) ||
    !identical(as.integer(candidate$snapshot_species),
               as.integer(candidate_index$richness)) ||
    !identical(as.integer(candidate$n_plots_snapshot),
               as.integer(candidate_index$n_plots)) ||
    !isTRUE(all.equal(as.numeric(candidate$pct_introduced_cover),
                      as.numeric(candidate_index$pct_introduced),
                      check.attributes = FALSE, tolerance = 1e-10))) {
  stop("independent candidate metrics do not reconcile to data/site_index.rds",
       call. = FALSE)
}

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
numeric_columns <- setdiff(names(candidate), "site")
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
  production_intro_pct = production$pct_introduced_cover,
  candidate_intro_pct = candidate$pct_introduced_cover,
  production_chao2 = production$chao2_lower_bound,
  candidate_chao2 = candidate$chao2_lower_bound,
  stringsAsFactors = FALSE
)
print(review, row.names = FALSE)

cat("\nREVIEW ASSERTIONS PASSED: 46-site identity; uniform bundle schema; " ,
    "one matching complete query-snapshot receipt across every bundle and index; " ,
    "independent snapshot richness/plot/introduced-cover parity with site_index.\n",
    sep = "")
