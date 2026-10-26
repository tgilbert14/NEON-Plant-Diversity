# ===========================================================================
# plant_oracle.R: an independent base-R reconstruction of the site headline
# numbers from docs/SCIENCE-CONTRACT.md (plant-snapshot-v2) and lead decision 3
# (cover denominator).  It never sources R/ and uses no package, so a defect in
# the app helpers cannot hide in both places.  Sourced by scripts/verify_bundle.R
# and scripts/review_refresh_candidate.R.
#
#   oracle_site_metrics(occ, ground) -> list(richness, n_plots, pct_introduced
#     (1 dp, as published), pct_introduced_raw, n_introduced_species,
#     species_area (named 1/10/100/400), chao2 (1 dp), chao2_raw, S_obs, ...)
#
# Contract text implemented here:
#   * bout identity per year: numeric bouts compare numerically; a row with no
#     bout joins an event only when nothing in that year carries a bout.
#   * grain event F: latest year with a plot carrying 1, 10 and 100 m^2 rows;
#     the bout with most such plots (tie: later bout); only those plots.
#   * cover event Q: newest year whose best 1 m^2 bout (most plots with 1 m^2
#     rows, tie: later) holds >= max(3, ceiling(0.5 * plots(F))) plots; 1 m^2
#     rows only.
#   * species = the bundle's is_species flag; nativity conflicts (Native and
#     Introduced for one taxon) resolve to Unknown within each event.
#   * sampled 1 m^2 units of a Q plot = union of Q's 1 m^2 subplotIDs over all
#     occurrence rows (any rank) and the event's ground-cover rows.
#   * plot-species mean cover = summed cover / the plot's units (unrounded);
#     % introduced = introduced share of the summed plot means.
#   * species-area on F: 1 m^2 = mean quadrat richness; 10 m^2 = mean over 10
#     m^2 cells of the union of the cell's 10 m^2 rows and its nested 1 m^2
#     quadrat; 100 m^2 = mean over corners of the corner union; 400 m^2 = plot
#     union; site = mean over plots with a finite value.
#   * Chao2 on Q species rows, unit = plot|subplot|year|bout:
#     S_obs + ((m - 1) / m) * Q1 * (Q1 - 1) / (2 * (Q2 + 1)).
# ===========================================================================

oracle_txt <- function(x) { x <- as.character(x); x[is.na(x)] <- "<NA>"; x }

oracle_bout_keys <- function(frame) {
  n <- nrow(frame)
  year <- suppressWarnings(as.numeric(as.character(frame$year)))
  key <- rep(NA_character_, n); rank <- rep(NA_real_, n)
  if (!n) return(list(year = year, key = key, rank = rank))
  bouts <- if ("bout" %in% names(frame)) trimws(as.character(frame$bout)) else rep(NA_character_, n)
  usable <- !is.na(bouts) & nzchar(bouts)
  has_year <- is.finite(year)
  for (rows in split(which(has_year), year[has_year], drop = TRUE)) {
    if (!any(usable[rows])) { key[rows] <- "<unspecified>"; rank[rows] <- 0; next }
    idx <- rows[usable[rows]]
    vals <- bouts[idx]
    num <- suppressWarnings(as.numeric(vals))
    if (all(is.finite(num))) {
      key[idx] <- format(num, scientific = FALSE, trim = TRUE, digits = 15)
      rank[idx] <- num
    } else {
      key[idx] <- vals
      rank[idx] <- match(vals, sort(unique(vals), method = "radix"))
    }
  }
  list(year = year, key = key, rank = rank)
}

oracle_best_bout <- function(keys, ranks, sets) {
  counts <- vapply(sets, length, integer(1))
  if (!length(counts) || max(counts) == 0L) return(NULL)
  cand <- which(counts == max(counts))
  pick <- cand[which.max(ranks[cand])]
  list(key = keys[[pick]], rank = ranks[[pick]], plots = sets[[pick]])
}

oracle_events <- function(occ) {
  keys <- oracle_bout_keys(occ)
  scale <- suppressWarnings(as.numeric(as.character(occ$scale)))
  plot <- as.character(occ$plotID)
  in_event <- is.finite(keys$year) & !is.na(keys$key) & !is.na(plot)
  years <- sort(unique(keys$year[in_event]), decreasing = TRUE)
  by_year <- function(y) {
    rows <- which(in_event & keys$year == y)
    bk <- unique(keys$key[rows])
    list(rows = rows, keys = bk,
         ranks = vapply(bk, function(k) keys$rank[rows][match(k, keys$key[rows])], numeric(1)))
  }
  grain <- NULL
  for (y in years) {
    yb <- by_year(y)
    sets <- lapply(yb$keys, function(k) {
      r <- yb$rows[keys$key[yb$rows] == k]
      bp <- split(scale[r], plot[r])
      sort(names(bp)[vapply(bp, function(s) all(c(1, 10, 100) %in% s), logical(1))], method = "radix")
    })
    ch <- oracle_best_bout(yb$keys, yb$ranks, sets)
    if (!is.null(ch)) { grain <- c(list(year = y), ch); break }
  }
  n_grain <- if (is.null(grain)) 0L else length(grain$plots)
  need <- max(3, ceiling(0.5 * n_grain))
  cover <- NULL
  for (y in years) {
    yb <- by_year(y)
    sets <- lapply(yb$keys, function(k) {
      r <- yb$rows[keys$key[yb$rows] == k & scale[yb$rows] %in% 1]
      sort(unique(plot[r]), method = "radix")
    })
    ch <- oracle_best_bout(yb$keys, yb$ranks, sets)
    if (!is.null(ch) && length(ch$plots) >= need) { cover <- c(list(year = y), ch); break }
  }
  list(
    grain = grain, cover = cover,
    grain_keep = if (is.null(grain)) rep(FALSE, nrow(occ)) else
      in_event & keys$year == grain$year & keys$key == grain$key & plot %in% grain$plots,
    cover_keep = if (is.null(cover)) rep(FALSE, nrow(occ)) else
      in_event & keys$year == cover$year & keys$key == cover$key &
        plot %in% cover$plots & scale %in% 1)
}

oracle_is_species <- function(frame) {
  if ("is_species" %in% names(frame)) return(frame$is_species %in% TRUE)
  rank <- if ("taxonRank" %in% names(frame)) frame$taxonRank else rep(NA_character_, nrow(frame))
  nm <- ifelse(is.na(frame$scientificName), "", as.character(frame$scientificName))
  (is.na(rank) | rank %in% c("species", "subspecies", "variety", "speciesGroup")) &
    !grepl("\\bsp\\.?$", nm) & !grepl("/", nm, fixed = TRUE)
}

oracle_resolve_nativity <- function(frame) {
  if (!nrow(frame)) return(frame)
  taxon <- if ("taxonID" %in% names(frame)) as.character(frame$taxonID) else rep(NA_character_, nrow(frame))
  miss <- is.na(taxon) | !nzchar(taxon)
  taxon[miss] <- as.character(frame$scientificName[miss])
  nat <- as.character(frame$nativity)
  conflict <- vapply(split(nat, taxon), function(v) all(c("Native", "Introduced") %in% v), logical(1))
  bad <- names(conflict)[conflict]
  nat[taxon %in% bad] <- "Unknown"
  frame$nativity <- nat
  attr(frame, "nativity_conflicts") <- length(bad)
  frame
}

oracle_species_area <- function(sp) {
  cell_of <- function(x) {
    out <- rep(NA_character_, length(x))
    ok <- !is.na(x) & grepl("^[^_]+_(1|10)_[^_]+$", x)
    out[ok] <- sub("^([^_]+)_(1|10)_([^_]+)$", "\\1_\\3", x[ok])
    out
  }
  plots <- unique(as.character(sp$plotID))
  per_plot <- lapply(plots, function(p) {
    d <- sp[as.character(sp$plotID) == p, , drop = FALSE]
    sc <- suppressWarnings(as.numeric(as.character(d$scale)))
    nm <- as.character(d$scientificName); sub <- as.character(d$subplotID)
    cell <- cell_of(sub); corner <- sub("_.*$", "", sub)
    has <- function(v) any(is.finite(sc) & sc == v)
    r1 <- if (has(1)) mean(vapply(split(nm[sc %in% 1], sub[sc %in% 1]),
                                  function(x) length(unique(x)), numeric(1))) else NA_real_
    r10 <- NA_real_
    if (has(10)) {
      k <- sc %in% c(1, 10) & !is.na(cell)
      if (any(k)) r10 <- mean(vapply(split(nm[k], cell[k]), function(x) length(unique(x)), numeric(1)))
    }
    r100 <- if (has(100)) {
      k <- sc %in% c(1, 10, 100)
      mean(vapply(split(nm[k], corner[k]), function(x) length(unique(x)), numeric(1)))
    } else NA_real_
    r400 <- if (has(1) && has(10) && has(100)) length(unique(nm)) else NA_real_
    c(r1, r10, r100, r400)
  })
  if (!length(per_plot)) return(stats::setNames(rep(NA_real_, 4), c("1", "10", "100", "400")))
  m <- do.call(rbind, per_plot)
  stats::setNames(apply(m, 2, function(x) if (any(is.finite(x))) mean(x[is.finite(x)]) else NA_real_),
                  c("1", "10", "100", "400"))
}

oracle_site_metrics <- function(occ, ground = NULL) {
  occ <- as.data.frame(occ, stringsAsFactors = FALSE)
  ev <- oracle_events(occ)

  # grain event F
  g <- occ[ev$grain_keep, , drop = FALSE]
  g_sp <- oracle_resolve_nativity(g[oracle_is_species(g), , drop = FALSE])
  richness <- length(unique(as.character(g_sp$scientificName)))
  n_plots <- if (is.null(ev$grain)) 0L else length(ev$grain$plots)
  n_intro <- length(unique(as.character(g_sp$scientificName[g_sp$nativity == "Introduced"])))
  sa <- oracle_species_area(g_sp)

  # cover event Q and its sampled units
  q <- occ[ev$cover_keep, , drop = FALSE]
  q_plots <- if (is.null(ev$cover)) character(0) else ev$cover$plots
  unit_key <- unique(paste(oracle_txt(q$plotID), oracle_txt(q$subplotID), sep = "\r"))
  if (!is.null(ground) && nrow(ground) && !is.null(ev$cover)) {
    ground <- as.data.frame(ground, stringsAsFactors = FALSE)
    gk <- oracle_bout_keys(ground)
    gkeep <- is.finite(gk$year) & gk$year == ev$cover$year & !is.na(gk$key) &
      gk$key == ev$cover$key & as.character(ground$plotID) %in% q_plots &
      !is.na(ground$subplotID)
    unit_key <- unique(c(unit_key, paste(oracle_txt(ground$plotID[gkeep]),
                                         oracle_txt(ground$subplotID[gkeep]), sep = "\r")))
  }
  unit_plot <- sub("\r.*$", "", unit_key)
  n_units <- table(unit_plot)

  one <- oracle_resolve_nativity(q[oracle_is_species(q), , drop = FALSE])
  pos <- one[is.finite(one$percentCover) & one$percentCover > 0, , drop = FALSE]
  pct_raw <- NA_real_; total <- 0
  if (nrow(pos)) {
    key <- paste(oracle_txt(pos$plotID), oracle_txt(pos$scientificName), oracle_txt(pos$nativity), sep = "\r")
    sums <- tapply(pos$percentCover, key, sum)
    parts <- strsplit(names(sums), "\r", fixed = TRUE)
    plot_of <- vapply(parts, `[[`, character(1), 1L)
    nat_of <- vapply(parts, `[[`, character(1), 3L)
    means <- as.numeric(sums) / as.numeric(n_units[plot_of])
    total <- sum(means)
    intro <- sum(means[nat_of == "Introduced"])
    if (total > 0) pct_raw <- 100 * intro / total
  }

  inc_unit <- paste(oracle_txt(one$plotID), oracle_txt(one$subplotID), oracle_txt(one$year),
                    ifelse(is.na(one$bout), "", as.character(one$bout)), sep = "|")
  counts <- if (nrow(one)) tapply(inc_unit, as.character(one$scientificName),
                                  function(u) length(unique(u))) else integer(0)
  S <- length(counts); Q1 <- sum(counts == 1L); Q2 <- sum(counts == 2L)
  m <- length(unique(inc_unit))
  chao <- if (m >= 2L && S > 0L) S + ((m - 1) / m) * Q1 * (Q1 - 1) / (2 * (Q2 + 1)) else NA_real_

  list(richness = richness, n_plots = n_plots,
       pct_introduced = if (is.finite(pct_raw)) round(pct_raw, 1) else NA_real_,
       pct_introduced_raw = pct_raw,
       n_introduced_species = n_intro,
       species_area = sa,
       chao2 = if (is.finite(chao)) round(chao, 1) else NA_real_, chao2_raw = chao,
       S_obs = if (is.finite(chao)) S else NA_integer_,
       n_units = sum(n_units), n_cover_plots = length(q_plots),
       units_per_plot = n_units, incidence_units = m, Q1 = Q1, Q2 = Q2,
       grain_year = if (is.null(ev$grain)) NA_real_ else ev$grain$year,
       grain_bout = if (is.null(ev$grain)) NA_character_ else ev$grain$key,
       cover_year = if (is.null(ev$cover)) NA_real_ else ev$cover$year,
       cover_bout = if (is.null(ev$cover)) NA_character_ else ev$cover$key,
       nativity_conflicts = attr(one, "nativity_conflicts") %||0% 0L)
}

`%||0%` <- function(a, b) if (is.null(a) || !length(a)) b else a
