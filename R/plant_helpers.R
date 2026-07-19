# ===========================================================================
# NEON Plant Diversity Explorer — plant_helpers.R
# Community-grain analyses on NEON Plant presence & % cover (DP1.10058.001).
# Diversity math (Hill, species-level filter, palette) ported from the
# NEON Small Mammal Tracker (DDL) — abundance swapped from captures to % cover;
# richness estimation swapped to incidence-based Chao2. Everything mark-recapture
# (individuals, dossier, home range) is deliberately ABSENT — plants have no
# individuals; the unit is a taxon's cover/presence in a subplot.
# ===========================================================================

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a

# Keep only confirmed SPECIES-level IDs (drop "X sp." / "A/B" / genus-only) so an
# unidentified taxon isn't counted as its own species. Ported verbatim in spirit
# from the mammal app's species_level_only(). The bundle already carries an
# `is_species` flag computed the same way; this is the runtime guard.
species_level_only <- function(d) {
  if (is.null(d) || !nrow(d)) return(d)
  if ("is_species" %in% names(d)) return(d[d$is_species %in% TRUE, , drop = FALSE])
  rank <- if ("taxonRank" %in% names(d)) d$taxonRank else rep(NA_character_, nrow(d))
  ok <- is.na(rank) | rank %in% c("species", "subspecies", "variety", "speciesGroup")
  nm <- ifelse(is.na(d$scientificName), "", as.character(d$scientificName))
  amb <- grepl("\\bsp\\.?$", nm) | grepl("/", nm, fixed = TRUE)
  d[ok & !amb, , drop = FALSE]
}

# Resolve contradictory Native/Introduced labels within a site's taxon
# records to Unknown.  This prevents one taxon contributing to both sides of a
# nativity partition while preserving the conflict count as an audit attribute.
resolve_nativity_records <- function(d) {
  if (is.null(d) || !nrow(d) || !("nativity" %in% names(d))) return(d)
  d$nativity <- as.character(d$nativity)
  tax <- if ("taxonID" %in% names(d)) as.character(d$taxonID) else as.character(d$scientificName)
  tax[is.na(tax) | !nzchar(tax)] <- as.character(d$scientificName[is.na(tax) | !nzchar(tax)])
  site <- if ("plotID" %in% names(d)) sub("[_-].*$", "", as.character(d$plotID)) else ""
  key <- paste(site, tax, sep = "\r")
  conflicts <- names(which(vapply(split(as.character(d$nativity), key), function(x) {
    z <- unique(x[!is.na(x) & x %in% c("Native", "Introduced")])
    all(c("Native", "Introduced") %in% z)
  }, logical(1))))
  if (length(conflicts)) d$nativity[key %in% conflicts] <- "Unknown"
  attr(d, "nativity_conflict_keys") <- conflicts
  d
}

# Okabe-Ito colourblind-safe qualitative palette — the categorical key colours
# (NLCD class, plot type, dominant family in the Diversity Lab, and the species
# palette below). Distinguishable under deuteranopia/protanopia, unlike Set2/Dark2.
OKABE_ITO <- c("#0072B2", "#E69F00", "#009E73", "#CC79A7",
               "#56B4E9", "#D55E00", "#F0E442", "#117733", "#882255", "#999999")

# Stable species -> color (same species, same color everywhere). Ported; now keyed
# off the CVD-safe Okabe-Ito ramp instead of Set2.
make_species_pal <- function(d) {
  sp <- sort(unique(d$scientificName[!is.na(d$scientificName)]))
  if (length(sp) == 0) return(character(0))
  cols <- grDevices::colorRampPalette(OKABE_ITO)(length(sp))
  stats::setNames(cols, sp)
}

# nativity -> a fixed display color (the first-class plant lens). THE single source
# of truth: global.R's DDL and the CSS --native/--introduced/--unknown tokens are
# derived from / mirror these, so the chart, the piv-bar, the map, and the legend
# can never drift. Herbarium values — native stays a true green, introduced a clay
# rust nudged for luminance separation from the green (CVD-aware; always pair with
# a second non-colour channel on any chart where the distinction carries a claim).
NATIVITY_COLS <- c(Native = "#2E7D32", Introduced = "#B85C38", Unknown = "#9AA39A")

# corner code from a NEON subplotID ("31_1_1" -> "31", "40_100" -> "40")
subplot_corner <- function(x) sub("_.*$", "", as.character(x))

# ---------------------------------------------------------------------------
# snapshot_by_plot_year(): keep one deterministic bout for each plot-year.
#
# Bout is part of the sampling event.  Pooling spring and monsoon bouts makes a
# plot look richer and more heavily sampled than it was at either visit.  When
# bouts are numeric we select the greatest numeric value; otherwise we select
# the last value in locale-independent byte order.  An all-missing bout is one
# valid (unspecified) event and is retained.  The attached support table is an
# audit trail, not an input to the estimators.
# ---------------------------------------------------------------------------
snapshot_by_plot_year <- function(occ, years = NULL) {
  if (is.null(occ) || !nrow(occ)) return(occ)
  needed <- c("plotID", "year")
  if (!all(needed %in% names(occ)))
    stop("snapshot_by_plot_year() requires plotID and year", call. = FALSE)

  d <- occ
  if (!is.null(years)) d <- d[d$year %in% years, , drop = FALSE]
  if (!nrow(d)) return(d)

  # A text key deliberately retains NA years as their own auditable group.
  yr_key <- ifelse(is.na(d$year), "<NA>", as.character(d$year))
  gp <- paste(as.character(d$plotID), yr_key, sep = "\r")
  groups <- split(seq_len(nrow(d)), gp, drop = TRUE)
  keep <- rep(FALSE, nrow(d))
  support <- vector("list", length(groups))

  for (i in seq_along(groups)) {
    ix <- groups[[i]]
    b <- if ("bout" %in% names(d)) as.character(d$bout[ix]) else rep(NA_character_, length(ix))
    usable <- !is.na(b) & nzchar(trimws(b))
    selected <- NA_character_
    if (any(usable)) {
      vals <- unique(trimws(b[usable]))
      nums <- suppressWarnings(as.numeric(vals))
      select_rows <- if (all(is.finite(nums))) {
        mx <- max(nums)
        tied <- sort(vals[nums == mx], method = "radix")
        selected <- tied[length(tied)]
        b_num <- suppressWarnings(as.numeric(trimws(b)))
        usable & is.finite(b_num) & b_num == mx
      } else {
        selected <- sort(vals, method = "radix")[length(vals)]
        usable & trimws(b) == selected
      }
      keep[ix[select_rows]] <- TRUE
    } else {
      keep[ix] <- TRUE
    }
    support[[i]] <- data.frame(
      plotID = as.character(d$plotID[ix[1]]), year = d$year[ix[1]],
      selected_bout = selected,
      n_bouts_observed = length(unique(trimws(b[usable]))),
      n_records_selected = sum(keep[ix]), stringsAsFactors = FALSE)
  }

  out <- d[keep, , drop = FALSE]
  attr(out, "snapshot_support") <- do.call(rbind, support)
  out
}

# ---------------------------------------------------------------------------
# latest_snapshot(): keep, for EACH plot, only its most-recent survey year.
# Every site-level snapshot metric (richness, species-area, Chao2, Hill, cover,
# invasion) runs on this — NOT on the year-pooled table. Pooling 7 visits of the
# same quadrat treats them as independent spatial samples (inflating richness and
# conflating spatial with temporal turnover); one-visit-per-plot is the honest
# instantaneous-spatial picture. The time-series (native_trend) still uses the
# full multi-year table — that's where temporal change belongs.
# ---------------------------------------------------------------------------
# NOTE: NEON runs multiple BOUTS within a year at some sites (spring + monsoon at
# SRER/JORN). Collapsing to the latest YEAR alone still pools both bouts of that
# year, so a quadrat's two visits get double-counted into richness, the cover
# denominator, and the Chao2 incidence units. We therefore keep the latest
# (year, bout) per plot — one survey per plot, the honest instantaneous picture.
latest_snapshot <- function(occ) {
  if (is.null(occ) || !nrow(occ)) return(occ)
  py <- snapshot_by_plot_year(occ)
  groups <- split(seq_len(nrow(py)), as.character(py$plotID), drop = TRUE)
  keep <- rep(FALSE, nrow(py))
  for (ix in groups) {
    yy <- suppressWarnings(as.numeric(as.character(py$year[ix])))
    if (any(is.finite(yy))) keep[ix[is.finite(yy) & yy == max(yy, na.rm = TRUE)]] <- TRUE
    else keep[ix] <- TRUE
  }
  snap <- py[keep, , drop = FALSE]
  sup <- attr(py, "snapshot_support")
  if (!is.null(sup) && nrow(sup)) {
    keys <- paste(as.character(snap$plotID), ifelse(is.na(snap$year), "<NA>", snap$year), sep = "\r")
    skeys <- paste(as.character(sup$plotID), ifelse(is.na(sup$year), "<NA>", sup$year), sep = "\r")
    attr(snap, "snapshot_support") <- sup[skeys %in% unique(keys), , drop = FALSE]
  }
  snap
}

# site-level introduced-cover share — the ONE definition used by the hero, the
# picker/site_index, and the map, so they can never disagree. Built on the same
# structural-zero plot_species_cover() recipe the rest of the app uses.
site_invasion <- function(occ) {
  psc <- plot_species_cover(occ); if (is.null(psc)) return(NA_real_)
  tot <- sum(psc$mean_cover, na.rm = TRUE)
  intro <- sum(psc$mean_cover[psc$nativity == "Introduced"], na.rm = TRUE)
  if (tot > 0) round(100 * intro / tot, 1) else NA_real_
}

# site-level UNKNOWN cover share — the cover-unit companion to unknown_rate()
# (which is a species-count figure). Surfaced next to the % introduced hero so the
# honesty number is measured on the same unit (cover) as the metric it qualifies.
unknown_cover_share <- function(occ) {
  psc <- plot_species_cover(occ); if (is.null(psc)) return(NA_real_)
  tot <- sum(psc$mean_cover, na.rm = TRUE)
  unk <- sum(psc$mean_cover[psc$nativity == "Unknown"], na.rm = TRUE)
  if (tot > 0) round(100 * unk / tot, 1) else NA_real_
}

# ---------------------------------------------------------------------------
# Per-species mean % cover within a plot, de-pseudoreplicated across distinct
# 1 m^2 subplots represented by at least one eligible occurrence record. Species
# absence within those represented subplots contributes zero. Truly sampled but
# vegetation-empty quadrats cannot enter until a separate survey-opportunity
# table is bundled, so n_sub is published with the result rather than hidden.
# ---------------------------------------------------------------------------
plot_species_cover <- function(occ, year = NULL) {
  d1 <- resolve_nativity_records(species_level_only(occ))
  d1 <- d1[d1$scale == 1, , drop = FALSE]
  if (!is.null(year)) d1 <- d1[d1$year %in% year, , drop = FALSE]
  if (!nrow(d1)) return(NULL)
  # subplots sampled per plot = the structural-zero denominator (a species absent
  # from a subplot contributes 0 cover there, so cover SHARE must divide by all
  # sampled subplots, not only the ones where the species was present)
  nsub <- d1 %>% dplyr::group_by(.data$plotID) %>%
    dplyr::summarise(n_sub = dplyr::n_distinct(.data$subplotID), .groups = "drop")
  cov <- d1[is.finite(d1$percentCover) & d1$percentCover > 0, , drop = FALSE]
  if (!nrow(cov)) return(NULL)
  agg <- cov %>% dplyr::group_by(.data$plotID, .data$scientificName, .data$family, .data$nativity) %>%
    dplyr::summarise(sum_cover = sum(.data$percentCover), n_present = dplyr::n(), .groups = "drop") %>%
    dplyr::left_join(nsub, by = "plotID")
  agg$mean_cover <- round(agg$sum_cover / agg$n_sub, 2)   # mean cover over ALL sampled subplots
  agg
}

# ---------------------------------------------------------------------------
# One row per PLOT — the unit the Diversity Lab scatters and the Plot Profile
# drills into. Richness is the 400 m^2 whole-plot species union; cover metrics
# come from the 1 m^2 quadrats (the only scale with cover).
# ---------------------------------------------------------------------------
plot_summary <- function(occ, year = NULL) {
  d <- resolve_nativity_records(species_level_only(occ))
  if (!is.null(year)) d <- d[d$year %in% year, , drop = FALSE]
  if (!nrow(d)) return(NULL)
  # richness (any scale = the 400 m^2 plot list) + native/introduced richness
  rich <- d %>% dplyr::group_by(.data$plotID) %>%
    dplyr::summarise(
      richness     = dplyr::n_distinct(.data$scientificName),
      n_native     = dplyr::n_distinct(.data$scientificName[.data$nativity == "Native"]),
      n_introduced = dplyr::n_distinct(.data$scientificName[.data$nativity == "Introduced"]),
      n_unknown    = dplyr::n_distinct(.data$scientificName[.data$nativity == "Unknown"]),
      plotType = mode_chr(.data$plotType), nlcdClass = mode_chr(.data$nlcdClass),
      lat = stats::median(.data$lat, na.rm = TRUE), lng = stats::median(.data$lng, na.rm = TRUE),
      .groups = "drop")
  # cover: per-plot species mean cover -> totals + introduced share + dominant
  psc <- plot_species_cover(d, year = NULL)
  covagg <- if (is.null(psc)) NULL else psc %>% dplyr::group_by(.data$plotID) %>%
    dplyr::summarise(
      total_cover  = round(sum(.data$mean_cover), 1),
      intro_cover  = round(sum(.data$mean_cover[.data$nativity == "Introduced"]), 1),
      native_cover = round(sum(.data$mean_cover[.data$nativity == "Native"]), 1),
      dominant     = .data$scientificName[which.max(.data$mean_cover)],
      dominant_cover = round(max(.data$mean_cover), 1),
      .groups = "drop")
  out <- if (is.null(covagg)) rich else dplyr::left_join(rich, covagg, by = "plotID")
  for (nm in c("total_cover", "intro_cover", "native_cover", "dominant_cover"))
    if (!(nm %in% names(out))) out[[nm]] <- NA_real_
  if (!("dominant" %in% names(out))) out$dominant <- NA_character_
  out$pct_introduced <- ifelse(is.finite(out$total_cover) & out$total_cover > 0,
                               round(100 * out$intro_cover / out$total_cover, 1), NA_real_)
  out %>% dplyr::arrange(dplyr::desc(.data$richness))
}

# ---------------------------------------------------------------------------
# Annual plant estimands.  First calculate every response at the plot-year
# level after deterministic bout selection; then retain the same recurrent
# plots in every year for the requested response.  This prevents changing plot
# effort from masquerading as a temporal or environmental signal.
# ---------------------------------------------------------------------------
annual_plant_metrics <- function(occ) {
  d <- resolve_nativity_records(species_level_only(snapshot_by_plot_year(occ)))
  if (is.null(d) || !nrow(d)) return(NULL)
  yrs <- sort(unique(d$year[!is.na(d$year)]))
  if (!length(yrs)) return(NULL)

  one_year <- function(y) {
    dy <- d[d$year == y, , drop = FALSE]
    rich <- dy %>% dplyr::group_by(.data$plotID) %>%
      dplyr::summarise(
        richness = dplyr::n_distinct(.data$scientificName),
        n_native = dplyr::n_distinct(.data$scientificName[.data$nativity == "Native"]),
        n_introduced = dplyr::n_distinct(.data$scientificName[.data$nativity == "Introduced"]),
        .groups = "drop")

    psc <- plot_species_cover(dy)
    cov <- if (is.null(psc)) NULL else psc %>%
      dplyr::group_by(.data$plotID) %>%
      dplyr::summarise(
        total_cover = sum(.data$mean_cover, na.rm = TRUE),
        intro_cover = sum(.data$mean_cover[.data$nativity == "Introduced"], na.rm = TRUE),
        .groups = "drop")
    out <- if (is.null(cov)) rich else dplyr::left_join(rich, cov, by = "plotID")
    if (!("total_cover" %in% names(out))) out$total_cover <- NA_real_
    if (!("intro_cover" %in% names(out))) out$intro_cover <- NA_real_
    out$pct_introduced <- ifelse(is.finite(out$total_cover) & out$total_cover > 0,
                                  100 * out$intro_cover / out$total_cover, NA_real_)

    scale_num <- suppressWarnings(as.numeric(as.character(dy$scale)))
    scale1 <- dy[is.finite(scale_num) & scale_num == 1, , drop = FALSE]
    nunit <- if (nrow(scale1)) scale1 %>% dplyr::group_by(.data$plotID) %>%
      dplyr::summarise(n_sampling_units = dplyr::n_distinct(.data$subplotID), .groups = "drop") else NULL
    if (!is.null(nunit)) out <- dplyr::left_join(out, nunit, by = "plotID")
    if (!("n_sampling_units" %in% names(out))) out$n_sampling_units <- 0L
    out$n_sampling_units[is.na(out$n_sampling_units)] <- 0L

    bout_value <- function(x) {
      z <- unique(as.character(x[!is.na(x)]))
      if (length(z)) sort(z, method = "radix")[length(z)] else NA_character_
    }
    bouts <- if ("bout" %in% names(dy)) dy %>% dplyr::group_by(.data$plotID) %>%
      dplyr::summarise(selected_bout = bout_value(.data$bout), .groups = "drop") else
      data.frame(plotID = unique(dy$plotID), selected_bout = NA_character_, stringsAsFactors = FALSE)
    out <- dplyr::left_join(out, bouts, by = "plotID")
    out$year <- y
    out
  }

  out <- do.call(rbind, lapply(yrs, one_year))
  rownames(out) <- NULL
  attr(out, "estimand") <- "plot-year response after one deterministic bout per plot-year"
  out
}

balanced_plant_metric_series <- function(occ, metric = "richness") {
  pm <- annual_plant_metrics(occ)
  if (is.null(pm) || !nrow(pm) || !(metric %in% names(pm))) return(NULL)
  yrs <- sort(unique(pm$year[!is.na(pm$year)]))
  if (!length(yrs)) return(NULL)

  good <- is.finite(suppressWarnings(as.numeric(pm[[metric]])))
  support <- pm[good, c("plotID", "year"), drop = FALSE]
  panel <- names(which(vapply(split(support$year, support$plotID),
                              function(z) length(unique(z)) == length(yrs), logical(1))))
  if (!length(panel)) return(NULL)
  pp <- pm[pm$plotID %in% panel & good, , drop = FALSE]

  rows <- lapply(yrs, function(y) {
    x <- pp[pp$year == y, , drop = FALSE]
    bouts <- sort(unique(x$selected_bout[!is.na(x$selected_bout)]), method = "radix")
    data.frame(
      year = y, value = mean(as.numeric(x[[metric]])), n_plots = nrow(x),
      n_sampling_units = sum(x$n_sampling_units, na.rm = TRUE),
      selected_bouts = if (length(bouts)) paste(bouts, collapse = ";") else NA_character_,
      stringsAsFactors = FALSE)
  })
  out <- do.call(rbind, rows)
  attr(out, "panel_plotIDs") <- sort(panel, method = "radix")
  attr(out, "estimand") <- sprintf("mean plot-level %s over plots observed in every included year", metric)
  out
}

# ---------------------------------------------------------------------------
# Per-PLOT nested species-area curve at NEON's quadrat scales. 1 m^2 = mean
# richness of a single 1 m^2 subplot; 10/100 m^2 = mean richness of a corner's
# <=10 / <=100 m^2 rows; 400 m^2 = whole-plot union. Honest about the nesting.
# ---------------------------------------------------------------------------
species_area_plot <- function(occ, plotID, year = NULL) {
  d <- species_level_only(occ)
  d <- d[d$plotID == plotID, , drop = FALSE]
  if (!is.null(year)) d <- d[d$year %in% year, , drop = FALSE]
  if (!nrow(d)) return(NULL)
  d$corner <- subplot_corner(d$subplotID)
  r1 <- d[d$scale == 1, ] %>% dplyr::group_by(.data$subplotID) %>%
    dplyr::summarise(r = dplyr::n_distinct(.data$scientificName), .groups = "drop")
  r1m <- if (nrow(r1)) mean(r1$r) else NA_real_
  per_corner <- function(maxscale) {
    sub <- d[d$scale <= maxscale, ]
    if (!nrow(sub)) return(NA_real_)
    cc <- sub %>% dplyr::group_by(.data$corner) %>%
      dplyr::summarise(r = dplyr::n_distinct(.data$scientificName), .groups = "drop")
    mean(cc$r)
  }
  r400 <- dplyr::n_distinct(d$scientificName)
  data.frame(area_m2 = c(1, 10, 100, 400),
             richness = c(r1m, per_corner(10), per_corner(100), r400))
}

# site mean species-area curve (mean of per-plot curves, with the per-area sd)
species_area_site <- function(occ, year = NULL) {
  d <- species_level_only(occ)
  if (!is.null(year)) d <- d[d$year %in% year, , drop = FALSE]
  plots <- unique(d$plotID)
  if (!length(plots)) return(NULL)
  curves <- lapply(plots, function(p) {
    cv <- species_area_plot(d, p); if (!is.null(cv)) cv$plotID <- p; cv })
  cur <- do.call(rbind, curves[!vapply(curves, is.null, logical(1))])
  if (is.null(cur) || !nrow(cur)) return(NULL)
  # NB: compute sd BEFORE reassigning `richness` to its mean — within one
  # summarise() a later expr sees the earlier (already-collapsed) value, which
  # would make sd(scalar) = NA for every area.
  cur %>% dplyr::group_by(.data$area_m2) %>%
    dplyr::summarise(
      n = sum(is.finite(.data$richness)),
      sd = if (sum(is.finite(.data$richness)) >= 2)
        stats::sd(.data$richness[is.finite(.data$richness)]) else NA_real_,
      richness = if (sum(is.finite(.data$richness)))
        mean(.data$richness[is.finite(.data$richness)]) else NA_real_,
      .groups = "drop")
}

# ---------------------------------------------------------------------------
# Hill numbers (q0/q1/q2 = effective # of species) from an abundance vector —
# here the abundance is summed % cover per species (Hill accepts any non-negative
# weights). q0 = richness, q1 = exp(Shannon), q2 = inverse Simpson. Ported math.
# ---------------------------------------------------------------------------
hill_numbers <- function(abund) {
  p <- abund[is.finite(abund) & abund > 0]; if (!length(p)) return(NULL)
  p <- p / sum(p)
  q0 <- length(p)
  q1 <- exp(-sum(p * log(p)))
  q2 <- 1 / sum(p^2)
  c(q0 = q0, q1 = q1, q2 = q2)
}

# site Hill profile on per-species summed 1 m^2 cover (the honest abundance)
hill_site <- function(occ, year = NULL) {
  d <- species_level_only(occ)
  d <- d[d$scale == 1 & is.finite(d$percentCover) & d$percentCover > 0, , drop = FALSE]
  if (!is.null(year)) d <- d[d$year %in% year, , drop = FALSE]
  if (!nrow(d)) return(NULL)
  ab <- tapply(d$percentCover, d$scientificName, sum)
  hill_numbers(as.numeric(ab))
}

# ---------------------------------------------------------------------------
# Chao2 — bias-corrected richness estimate from INCIDENCE (presence across
# sampling units), the textbook choice for plant nested-quadrat data (NOT the
# count-based Chao1 the mammal app uses). Units = 1 m^2 subplots within the site.
# Returns S_obs and the exact bias-corrected lower-bound estimator.  An upper
# confidence bound is deliberately not fabricated from the incompatible classic
# Chao2 variance expression; callers receive explicit lower-bound semantics.
# Chao 1987; Chao & Chiu 2016.
# ---------------------------------------------------------------------------
chao2 <- function(occ, year = NULL) {
  d <- species_level_only(occ)
  d <- d[d$scale == 1, , drop = FALSE]                       # 1 m^2 subplots = incidence units
  if (!is.null(year)) d <- d[d$year %in% year, , drop = FALSE]
  if (!nrow(d)) return(NULL)
  bcol <- if ("bout" %in% names(d)) ifelse(is.na(d$bout), "", as.character(d$bout)) else ""
  unit <- paste(d$plotID, d$subplotID, d$year, bcol, sep = "|")   # bout-aware incidence unit
  m <- length(unique(unit))
  inc <- tapply(unit, d$scientificName, function(u) length(unique(u)))   # # units each species in
  inc <- as.numeric(inc)
  S <- length(inc); Q1 <- sum(inc == 1); Q2 <- sum(inc == 2)
  if (m < 2 || S == 0) return(NULL)
  corr <- (m - 1) / m
  # Bias-corrected Chao2: S + ((m-1)/m) * Q1(Q1-1) / (2(Q2+1)).
  # This form is defined at Q2 == 0 and avoids switching estimators by branch.
  chao <- S + corr * Q1 * (Q1 - 1) / (2 * (Q2 + 1))
  list(S_obs = S, chao2 = round(chao, 1),
       lo = S, hi = NA_real_,
       m = m, Q1 = Q1, Q2 = Q2, unstable = Q2 < 3,
       lower_bound = TRUE,
       estimator = "bias_corrected_chao2",
       interval = "observed-richness lower endpoint only; upper confidence bound not estimated")
}

# ---------------------------------------------------------------------------
# Native vs Invasive — the first-class plant lens.
# ---------------------------------------------------------------------------
# site-level: introduced cover share, introduced richness, unknown rate, by year
native_trend <- function(occ) {
  pct <- balanced_plant_metric_series(occ, "pct_introduced")
  if (is.null(pct)) return(NULL)
  panel <- attr(pct, "panel_plotIDs")
  metrics <- annual_plant_metrics(occ)
  metrics <- metrics[
    metrics$plotID %in% panel & metrics$year %in% pct$year &
      is.finite(metrics$pct_introduced), , drop = FALSE]
  out <- pct[, c("year", "value", "n_plots", "n_sampling_units", "selected_bouts"), drop = FALSE]
  names(out)[names(out) == "value"] <- "pct_introduced"
  panel_mean <- function(column, year) {
    values <- metrics[[column]][metrics$year == year]
    if (length(values) && all(is.finite(values))) mean(values) else NA_real_
  }
  out$n_introduced <- vapply(out$year, function(year) panel_mean("n_introduced", year), numeric(1))
  out$n_native <- vapply(out$year, function(year) panel_mean("n_native", year), numeric(1))
  out$n_introduced <- round(out$n_introduced, 1)
  out$n_native <- round(out$n_native, 1)
  out$pct_introduced <- round(out$pct_introduced, 1)
  out[order(out$year), c("year", "pct_introduced", "n_introduced", "n_native",
                         "n_plots", "n_sampling_units", "selected_bouts")]
}

# the invasive watchlist: introduced species ranked by mean 1 m^2 cover + ubiquity
invasive_watchlist <- function(occ, year = NULL) {
  psc <- plot_species_cover(occ, year = year)
  if (is.null(psc)) return(NULL)
  inv <- psc[psc$nativity == "Introduced", , drop = FALSE]
  if (!nrow(inv)) return(NULL)
  d <- species_level_only(occ)
  if (!is.null(year)) d <- d[d$year %in% year, , drop = FALSE]
  supported_plots <- unique(d$plotID[d$scale == 1 & !is.na(d$plotID)])
  n_supported <- length(supported_plots)
  if (!n_supported) return(NULL)
  inv %>% dplyr::group_by(.data$scientificName, .data$family) %>%
    dplyr::summarise(
      # Species absent from a supported plot contributes zero here; this is not
      # a mean over only the plots where the introduced species was present.
      mean_cover = round(sum(.data$mean_cover, na.rm = TRUE) / n_supported, 1),
      n_plots = dplyr::n_distinct(.data$plotID),
      n_supported_plots = n_supported, .groups = "drop") %>%
    dplyr::arrange(dplyr::desc(.data$mean_cover), dplyr::desc(.data$n_plots))
}

# the % of records whose nativity is Unknown — publish it (honesty, like a join rate)
unknown_rate <- function(occ) {
  sp <- resolve_nativity_records(species_level_only(occ))
  if (!nrow(sp)) return(NA_real_)
  round(100 * dplyr::n_distinct(sp$scientificName[sp$nativity == "Unknown"]) /
          dplyr::n_distinct(sp$scientificName), 1)
}

# ---------------------------------------------------------------------------
# Cross-scale occurrence summary. For each plot, report introduced and native
# richness detectable at 1 m^2 versus anywhere in the nested 400 m^2 plot list.
# This is a grain/detection comparison only: it does not measure pressure,
# establishment, spread, impact, or management priority.
# ---------------------------------------------------------------------------
cross_scale_plot_occurrence <- function(occ, year = NULL) {
  d <- resolve_nativity_records(species_level_only(occ))
  if (!is.null(year)) d <- d[d$year %in% year, , drop = FALSE]
  if (!nrow(d)) return(NULL)
  per_plot <- function(p) {
    pp <- d[d$plotID == p, ]
    intro <- pp[pp$nativity == "Introduced", ]
    nat   <- pp[pp$nativity == "Native", ]
    data.frame(plotID = p,
               intro_1m  = dplyr::n_distinct(intro$scientificName[intro$scale == 1]),
               intro_400 = dplyr::n_distinct(intro$scientificName),
               native_1m = dplyr::n_distinct(nat$scientificName[nat$scale == 1]),
               native_400 = dplyr::n_distinct(nat$scientificName))
  }
  out <- do.call(rbind, lapply(unique(d$plotID), per_plot))
  attr(out, "interpretation") <- "cross-scale occurrence only; no spread, impact, or management inference"
  out
}

# Backward-compatible app call; new code should use cross_scale_plot_occurrence().
invasion_pressure <- function(occ, year = NULL)
  cross_scale_plot_occurrence(occ, year = year)

# ---------------------------------------------------------------------------
# Per-introduced-species cross-scale occurrence. It counts plots where a taxon
# was recorded at 1 m^2 versus anywhere in the nested 400 m^2 plot list. A gap
# between the counts is a sampling-grain/detection result, not evidence of a
# foothold, spread, establishment, impact, or management priority. Plot lists
# are retained so every point is auditable.
# ---------------------------------------------------------------------------
species_cross_scale_occurrence <- function(occ, year = NULL) {
  d <- resolve_nativity_records(species_level_only(occ))
  if (!is.null(year)) d <- d[d$year %in% year, , drop = FALSE]
  intro <- d[d$nativity == "Introduced", , drop = FALSE]
  if (!nrow(intro)) return(NULL)
  wl <- invasive_watchlist(d)
  mean_cov <- if (!is.null(wl) && nrow(wl))
    stats::setNames(wl$mean_cover, wl$scientificName) else numeric(0)
  per_sp <- function(sp) {
    s  <- intro[intro$scientificName == sp, ]
    p1 <- sort(unique(s$plotID[s$scale == 1]))            # plots where seen at 1 m^2
    p4 <- sort(unique(s$plotID))                          # plots where seen anywhere in the 400 m^2 plot
    data.frame(scientificName = sp,
               family   = mode_chr(s$family),
               plots_1m = length(p1),
               plots_400 = length(p4),
               mean_cover_1m = round(as.numeric(mean_cov[sp] %||% NA_real_), 2),
               plotlist_1m  = paste(short_plot(p1), collapse = ", "),
               plotlist_400 = paste(short_plot(p4), collapse = ", "),
               stringsAsFactors = FALSE)
  }
  out <- do.call(rbind, lapply(sort(unique(intro$scientificName)), per_sp))
  out <- out[order(-out$plots_400, -out$plots_1m), , drop = FALSE]
  attr(out, "interpretation") <- "cross-scale occurrence only; no spread, impact, or management inference"
  out
}

# Backward-compatible app call; new code should use species_cross_scale_occurrence().
species_foothold <- function(occ, year = NULL)
  species_cross_scale_occurrence(occ, year = year)

# ---------------------------------------------------------------------------
# Ranked species by abundance (summed 1 m^2 cover) — the honest backing list
# for the Hill-number "effective common core" reveal. q1 is an evenness-weighted
# EFFECTIVE number (~N species), not a hand-picked set of exactly N names, so we
# return the FULL ranked list + a cumulative cover share and a cut at round(q1)
# so the modal can say "the top ~N is what 'effectively common' describes".
# ---------------------------------------------------------------------------
hill_ranked_species <- function(occ, year = NULL) {
  d <- resolve_nativity_records(species_level_only(occ))
  d <- d[d$scale == 1 & is.finite(d$percentCover) & d$percentCover > 0, , drop = FALSE]
  if (!is.null(year)) d <- d[d$year %in% year, , drop = FALSE]
  if (!nrow(d)) return(NULL)
  ab  <- tapply(d$percentCover, d$scientificName, sum)
  fam <- tapply(d$family, d$scientificName, mode_chr)
  nat <- tapply(d$nativity, d$scientificName, mode_chr)
  sp  <- names(ab)
  out <- data.frame(scientificName = sp,
                    family   = as.character(fam[sp]),
                    nativity = as.character(nat[sp]),
                    summed_cover = round(as.numeric(ab), 2),
                    stringsAsFactors = FALSE)
  out <- out[order(-out$summed_cover), , drop = FALSE]
  tot <- sum(out$summed_cover)
  out$cover_share_pct <- if (tot > 0) round(100 * out$summed_cover / tot, 1) else NA_real_
  out$cum_share_pct   <- if (tot > 0) round(100 * cumsum(out$summed_cover) / tot, 1) else NA_real_
  out$rank <- seq_len(nrow(out))
  rownames(out) <- NULL
  out
}

# ---------------------------------------------------------------------------
# One row per SPECIES — the secondary entity (species leaderboard + species card).
# ---------------------------------------------------------------------------
species_summary <- function(occ, year = NULL) {
  d <- resolve_nativity_records(species_level_only(occ))
  if (!is.null(year)) d <- d[d$year %in% year, , drop = FALSE]
  if (!nrow(d)) return(NULL)
  supported_plots <- unique(d$plotID[d$scale == 1 & !is.na(d$plotID)])
  psc <- plot_species_cover(d)
  cov_by_sp <- if (!is.null(psc) && nrow(psc) && length(supported_plots)) {
    sums <- tapply(psc$mean_cover, psc$scientificName, sum)
    sums / length(supported_plots)
  } else numeric(0)
  d %>% dplyr::group_by(.data$scientificName) %>%
    dplyr::summarise(family = mode_chr(.data$family), nativity = mode_chr(.data$nativity),
                     n_plots = dplyr::n_distinct(.data$plotID),
                     min_scale = suppressWarnings(min(.data$scale, na.rm = TRUE)),
                     .groups = "drop") %>%
    dplyr::mutate(mean_cover = round(as.numeric(cov_by_sp[.data$scientificName]), 2)) %>%
    dplyr::arrange(dplyr::desc(.data$n_plots), dplyr::desc(.data$mean_cover))
}

# cover composition by a grouping column (family or nativity) for the Overview
cover_by_group <- function(occ, by = c("family", "nativity"), year = NULL) {
  by <- match.arg(by)
  psc <- plot_species_cover(occ, year = year)
  if (is.null(psc)) return(NULL)
  psc %>% dplyr::group_by(.data[[by]]) %>%
    dplyr::summarise(cover = round(sum(.data$mean_cover), 1),
                     n_species = dplyr::n_distinct(.data$scientificName), .groups = "drop") %>%
    dplyr::arrange(dplyr::desc(.data$cover))
}

# abiotic ground cover (bare soil / litter / rock ...) mean per class
ground_summary <- function(ground, year = NULL) {
  if (is.null(ground) || !nrow(ground)) return(NULL)
  g <- if (!is.null(year)) ground[ground$year %in% year, ] else ground
  g <- g[is.finite(g$percentCover) & g$percentCover > 0, ]
  if (!nrow(g)) return(NULL)
  g %>% dplyr::group_by(.data$otherVariables) %>%
    dplyr::summarise(mean_cover = round(mean(.data$percentCover), 1), .groups = "drop") %>%
    dplyr::arrange(dplyr::desc(.data$mean_cover))
}

# modal non-NA character (ported from the mammal app)
mode_chr <- function(x) {
  x <- x[!is.na(x)]; if (!length(x)) return(NA_character_)
  names(sort(table(x), decreasing = TRUE))[1]
}

# short, human plot label ("KONZ_001" -> "001")
short_plot <- function(p) sub("^[A-Z]{4}_", "", as.character(p))

# ---------------------------------------------------------------------------
# Data dictionary for the all-data export — column meanings, types, units. Keeps
# the downloadable CSVs analysis-ready (FAIR / reproducible), the Quinn standard.
#
# Derived PROGRAMMATICALLY from the actual exported frames so every shipped
# column is documented and the codebook can never drift from the export. Pass
# `frames` = a named list (file name -> data.frame) of exactly what gets zipped;
# meanings come from a known-column lookup, types are read off the real columns.
# Called with no args it falls back to the canonical column set for safety.
# ---------------------------------------------------------------------------

# known-column meaning lookup (one source of truth for descriptions)
.PLANT_COL_MEANING <- c(
  site           = "NEON four-character site code",
  siteID         = "NEON four-character site code carried by the source table",
  plotID         = "NEON plot code",
  subplotID      = "nested subplot code",
  scale_m2       = "quadrat scale (1/10/100 m^2; 1 m^2 is the only cover scale)",
  scale          = "quadrat scale (1/10/100 m^2; exported as scale_m2)",
  year           = "survey year",
  bout           = "within-year bout (spring/monsoon at some sites)",
  taxonID        = "USDA PLANTS symbol (= NEON taxonID)",
  scientificName = "scientific name",
  taxonRank      = "taxonomic rank of the ID",
  family         = "plant family",
  nativeStatusCode = "raw NEON native-status code retained for classification audit",
  nativity       = "native / introduced / unknown (from NEON nativeStatusCode)",
  percentCover   = "ocular percent cover at 1 m^2 (bin midpoint/ocular, NA at presence-only scales)",
  groundCoverPct = "ocular percent cover of the named abiotic ground-cover class",
  is_species     = "TRUE if resolved to species level",
  richness       = "species richness (400 m^2 plot list)",
  n_native       = "native species count",
  n_introduced   = "introduced species count",
  n_unknown      = "unknown-status species count",
  total_cover    = "summed mean 1 m^2 cover (relative index)",
  intro_cover    = "summed mean 1 m^2 cover of introduced species (relative index)",
  native_cover   = "summed mean 1 m^2 cover of native species (relative index)",
  dominant       = "highest-cover species in the plot",
  dominant_cover = "mean 1 m^2 cover of the dominant species",
  pct_introduced = "introduced share of total cover (%)",
  plotType       = "NEON plot type",
  nlcdClass      = "NLCD land-cover class",
  lat            = "plot latitude (decimal degrees)",
  lng            = "plot longitude (decimal degrees)",
  otherVariables = "abiotic ground-cover class (soil/litter/rock/...)",
  ym             = "calendar month key in YYYY-MM form",
  date           = "calendar date representing the monthly environmental record",
  precip_mm      = "monthly precipitation total",
  temp_c         = "monthly mean air temperature",
  temp_min       = "monthly minimum air temperature",
  temp_max       = "monthly maximum air temperature",
  rh_pct         = "monthly relative humidity",
  vswc_pct       = "monthly volumetric soil-water content",
  flowering_pct  = "monthly share of monitored plants in the flowering phenophase",
  flowering_pct_n = "number of monthly flowering observations behind flowering_pct",
  greenup_pct    = "monthly share of monitored plants in the green-up phenophase",
  greenup_pct_n  = "number of monthly green-up observations behind greenup_pct",
  fruiting_pct   = "sparse monthly fruiting-status/intensity summary; descriptive only",
  fruiting_pct_n = "number of monthly fruiting observations behind fruiting_pct",
  source         = "source system or reference-list construction route",
  # provenance.csv
  artifact       = "artifact class described by this provenance row",
  builtAt        = "build provenance: date this bundle was built",
  exportedAt     = "date this CSV export was generated",
  neonRelease    = "build provenance: NEON release tag for the source product (NA if untagged)",
  dpid           = "NEON data product id (DP1.10058.001)",
  fetchedAt      = "build provenance: date this bundle was fetched/built",
  bundleFile     = "runtime artifact path used by the app",
  bundleMd5      = "MD5 checksum of the exact runtime artifact used by the app",
  snapshotContract = "registered rule used to select one current survey per plot",
  estimatorContract = "registered science-estimator contract version/description",
  sourceLicense  = "license or public-domain status for the source represented by the row",
  # expected_vs_observed.csv
  bucket               = "A = expected & observed, B = expected not detected, C = observed not in reference",
  symbol               = "USDA PLANTS symbol",
  reference_production = "NRCS reference-community expected production (air-dry lb/ac at normal precipitation; NA where not production-ranked)",
  is_dominant          = "TRUE if in the top 50% of reference production (app-defined dominance convention)",
  observed_cover       = "mean 1 m^2 observed cover (relative index; NA where not observed)",
  reference_role       = "dominant (top 50% of reference production) or associated",
  observed_cover_pct   = "mean 1 m^2 observed cover, percent (relative index)",
  n_plots              = "number of plots the species was observed in",
  common_name          = "USDA PLANTS common name",
  commonName           = "USDA PLANTS common name",
  mean_cover_pct       = "mean 1 m^2 cover, percent (relative index)",
  classification       = "review classification; observed-not-reference records remain review until provenance supports another class",
  note                 = "human-readable explanation emitted when a requested comparison is unavailable",
  # reference_provenance.csv
  referenceScope       = "spatial scope and limitation of the ecological-site reference list",
  referenceLatitude    = "latitude of the single coordinate used to select the reference soil map unit",
  referenceLongitude   = "longitude of the single coordinate used to select the reference soil map unit",
  ecoclassid           = "NRCS ecological-class identifier selected for the reference list",
  ecositeName          = "NRCS ecological-site name selected for the reference list",
  ecosite_name         = "NRCS ecological-site name selected for the reference list",
  mlra                  = "Major Land Resource Area identifier parsed from the ecological-class id",
  queryDate             = "date the external reference query was executed, when recorded",
  # environment matched-series export (env_matched.csv)
  plant_metric         = "the chosen annual plant signal (richness / % introduced cover / total cover)",
  metric_value         = "the plant signal value for that survey year",
  driver               = "co-located NEON climate/phenology driver (annual value)",
  driver_value         = "the driver's annual value for the matched year",
  driver_label         = "human-readable driver name",
  lag_years            = "lead in years: driver from year (Y - lag) matched to response year Y",
  # environment driver-rank export (env_driver_rank.csv)
  spearman_r           = "Spearman rank-correlation of the plant signal vs this driver at its best lag",
  best_lag_years       = "the lag (0-2 yr) that maximised |r| for this driver",
  matched_years        = "number of year-matched points behind the correlation",
  permutation_p        = "circular-shift p over the active registered search scope (full series × lag screen for Best; selected-series lag screen otherwise)",
  lag_search_p         = "per-driver circular-shift p corrected across that driver's registered 0–2 year lag screen",
  permutation_scope    = "human-readable search family corrected by the reported circular-shift p")

.plant_col_units <- function(cols) {
  out <- rep("not applicable", length(cols))
  names(out) <- cols
  out[cols %in% c("scale", "scale_m2")] <- "m^2"
  out[cols %in% c("percentCover", "groundCoverPct", "pct_introduced", "observed_cover", "observed_cover_pct",
                  "mean_cover_pct", "rh_pct", "vswc_pct", "flowering_pct", "greenup_pct",
                  "fruiting_pct")] <- "%"
  out[cols %in% c("total_cover", "intro_cover", "native_cover", "dominant_cover")] <-
    "relative cover index (summed percentage-point means)"
  out[cols %in% c("precip_mm")] <- "mm/month"
  out[cols %in% c("temp_c", "temp_min", "temp_max")] <- "degrees C"
  out[cols %in% c("lat", "lng", "referenceLatitude", "referenceLongitude")] <- "decimal degrees"
  out[cols %in% c("reference_production")] <- "air-dry lb/acre at normal precipitation"
  out[cols %in% c("richness", "n_native", "n_introduced", "n_unknown", "n_plots",
                  "matched_years", "flowering_pct_n", "greenup_pct_n", "fruiting_pct_n")] <- "count"
  out[cols %in% c("spearman_r")] <- "unitless correlation"
  out[cols %in% c("permutation_p", "lag_search_p")] <- "unitless probability"
  unname(out)
}

.plant_col_na <- function(cols) {
  out <- rep("NA means the source did not record or the app could not derive this field.", length(cols))
  out[cols %in% c("plotID", "subplotID", "year", "taxonID", "scientificName", "scale", "scale_m2")] <-
    "NA is invalid for analysis keys and should be retained only in the all-record audit export."
  out[cols %in% c("bout")] <- "NA means the within-year visit was not identified; it is retained only when the entire plot-year has no identified bout."
  out[cols %in% c("percentCover")] <- "NA is expected at presence-only 10/100 m^2 scales or when 1 m^2 cover was not recorded; it is not zero."
  out[cols %in% c("groundCoverPct")] <- "NA means abiotic ground cover was not recorded for that ground-cover class and sampling unit; it is not zero."
  out[cols %in% c("nativity")] <- "Unknown is the analysis category for unresolved/conflicting status; NA means no derived category was supplied."
  out[cols %in% c("neonRelease", "queryDate")] <- "NA means the release/query date was not captured, not that no release/query occurred."
  out[cols %in% c("reference_production")] <- "NA is expected where NRCS provides no production ranking, including many forest ecological sites."
  out[cols %in% c("total_cover", "intro_cover", "native_cover", "dominant", "dominant_cover", "pct_introduced") ] <-
    "NA means no eligible 1 m^2 cover estimate was available for the selected plot snapshot; it is not zero."
  out[cols %in% c("precip_mm", "temp_c", "temp_min", "temp_max", "rh_pct", "vswc_pct",
                  "flowering_pct", "greenup_pct", "fruiting_pct", "flowering_pct_n",
                  "greenup_pct_n", "fruiting_pct_n")] <-
    "NA means that monthly environmental value is unavailable; annual inference requires 12 non-missing monthly values."
  out[cols %in% c("observed_cover", "observed_cover_pct", "mean_cover_pct")] <-
    "NA means the species lacks an eligible observed 1 m^2 cover estimate; absence and missing cover are not interchangeable."
  out[cols %in% c("referenceLatitude", "referenceLongitude")] <-
    "NA means the historical reference artifact did not persist its query coordinate."
  unname(out)
}

.plant_col_estimand <- function(cols) {
  out <- rep("metadata or row-level source value; interpret in the context of the named export file.", length(cols))
  out[cols %in% c("plotID", "subplotID", "scale", "scale_m2", "year", "bout", "taxonID",
                  "scientificName", "taxonRank", "family", "nativeStatusCode", "nativity", "percentCover", "is_species")] <-
    "one bundled NEON taxon record; analysis_snapshot.csv restricts this to one selected bout in each plot's latest year."
  out[cols %in% c("richness", "n_native", "n_introduced", "n_unknown", "total_cover", "intro_cover",
                  "native_cover", "dominant", "dominant_cover", "pct_introduced", "plotType", "nlcdClass",
                  "lat", "lng")] <-
    "one plot at its latest deterministic year/bout snapshot; cover is a relative index over recorded 1 m^2 occurrence units."
  out[cols %in% c("otherVariables")] <- "one bundled abiotic ground-cover class record; the all-data file may span years/bouts."
  out[cols %in% c("groundCoverPct")] <- "ocular cover for one abiotic ground-cover class in one bundled ground-cover record; not plant composition."
  out[cols %in% c("ym", "date", "precip_mm", "temp_c", "temp_min", "temp_max", "rh_pct", "vswc_pct",
                  "flowering_pct", "greenup_pct", "fruiting_pct", "flowering_pct_n",
                  "greenup_pct_n", "fruiting_pct_n")] <-
    "one site-month environmental context record; only complete 12-month windows are eligible for annual exploratory association."
  out[cols %in% c("bucket", "symbol", "reference_production", "is_dominant", "observed_cover",
                  "reference_role", "observed_cover_pct", "common_name", "commonName", "mean_cover_pct",
                  "classification")] <-
    "species comparison against one NRCS ecological-site list selected at a single site reference coordinate; not a site-wide flora census."
  out[cols %in% c("referenceScope", "referenceLatitude", "referenceLongitude", "ecoclassid", "ecositeName",
                  "ecosite_name", "mlra", "queryDate")] <-
    "provenance for the single-coordinate NRCS ecological-site reference artifact."
  out[cols %in% c("artifact", "builtAt", "exportedAt", "neonRelease", "dpid", "fetchedAt", "bundleFile", "bundleMd5",
                  "snapshotContract", "estimatorContract", "sourceLicense")] <-
    "release/provenance metadata for the exported artifact, not an ecological estimand."
  out[cols %in% c("plant_metric", "metric_value", "driver", "driver_value", "driver_label", "lag_years",
                  "spearman_r", "best_lag_years", "matched_years", "permutation_p",
                  "lag_search_p", "permutation_scope")] <-
    "exploratory annual association over the recurrent plot panel and complete 12-month driver windows; no causal inference."
  unname(out)
}

# r class -> short codebook type
.plant_col_type <- function(x) {
  if (is.logical(x))   return("logical")
  if (is.integer(x))   return("int")
  if (is.numeric(x))   return("num")
  "chr"
}

plant_codebook <- function(frames = NULL) {
  # canonical fallback (used when no frames are supplied) — mirrors the export
  if (is.null(frames)) {
    frames <- list(
      "occurrences_all.csv" = stats::setNames(data.frame(matrix(nrow = 0, ncol = 13)),
        c("plotID","subplotID","scale_m2","year","bout","taxonID","scientificName",
          "taxonRank","family","nativeStatusCode","nativity","percentCover","is_species")),
      "plots_snapshot.csv" = stats::setNames(data.frame(matrix(nrow = 0, ncol = 15)),
        c("plotID","richness","n_native","n_introduced","n_unknown","plotType","nlcdClass",
          "lat","lng","total_cover","intro_cover","native_cover","dominant","dominant_cover","pct_introduced")),
      "ground_cover_all.csv" = stats::setNames(data.frame(matrix(nrow = 0, ncol = 6)),
        c("plotID","subplotID","year","bout","otherVariables","groundCoverPct")))
  }
  rows <- lapply(names(frames), function(fn) {
    df <- frames[[fn]]; if (is.null(df)) return(NULL)
    cols <- names(df)
    if (!length(cols)) return(NULL)
    if (anyDuplicated(cols))
      stop(sprintf("plant_codebook(): duplicate exported columns in %s: %s", fn,
                   paste(unique(cols[duplicated(cols)]), collapse = ", ")), call. = FALSE)
    unknown <- setdiff(cols, names(.PLANT_COL_MEANING))
    if (length(unknown))
      stop(sprintf("plant_codebook(): undocumented exported columns in %s: %s",
                   fn, paste(sort(unique(unknown)), collapse = ", ")), call. = FALSE)
    data.frame(
      file    = fn,
      column  = cols,
      meaning = unname(.PLANT_COL_MEANING[cols]),
      type    = vapply(df, .plant_col_type, character(1), USE.NAMES = FALSE),
      units = .plant_col_units(cols),
      na_semantics = .plant_col_na(cols),
      estimand = .plant_col_estimand(cols),
      stringsAsFactors = FALSE)
  })
  rows <- rows[!vapply(rows, is.null, logical(1))]
  do.call(rbind, rows)
}
