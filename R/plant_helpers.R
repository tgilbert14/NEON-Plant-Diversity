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
  ly <- occ %>% dplyr::group_by(.data$plotID) %>%
    dplyr::summarise(.snapyr = max(.data$year, na.rm = TRUE), .groups = "drop")
  snap <- occ %>% dplyr::inner_join(ly, by = "plotID") %>%
    dplyr::filter(.data$year == .data$.snapyr) %>% dplyr::select(-".snapyr")
  if ("bout" %in% names(snap) && any(!is.na(snap$bout))) {
    lb <- snap %>% dplyr::group_by(.data$plotID) %>%
      dplyr::summarise(.snapbout = suppressWarnings(max(.data$bout, na.rm = TRUE)), .groups = "drop")
    snap <- snap %>% dplyr::inner_join(lb, by = "plotID") %>%
      dplyr::filter(is.na(.data$bout) | !is.finite(.data$.snapbout) | .data$bout == .data$.snapbout) %>%
      dplyr::select(-".snapbout")
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
# Per-species mean % cover within a plot, de-pseudoreplicated: mean across the
# 1 m^2 subplots where the species was scored (NOT all subplots) — matches the
# mammal app's "mean per unit before per-group" discipline. Returns one row per
# (plotID, scientificName) with mean_cover + the subplot count it's based on.
# ---------------------------------------------------------------------------
plot_species_cover <- function(occ, year = NULL) {
  d1 <- species_level_only(occ)
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
  d <- species_level_only(occ)
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
  out$pct_introduced <- ifelse(is.finite(out$total_cover) & out$total_cover > 0,
                               round(100 * out$intro_cover / out$total_cover, 1), NA_real_)
  out %>% dplyr::arrange(dplyr::desc(.data$richness))
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
    dplyr::summarise(sd = stats::sd(.data$richness, na.rm = TRUE),
                     richness = mean(.data$richness, na.rm = TRUE),
                     n = dplyr::n(), .groups = "drop")
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
# Returns S_obs, Chao2, and a (rough) 95% CI; flags instability when Q2 is tiny.
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
  chao <- if (Q2 > 0) S + corr * Q1^2 / (2 * Q2) else S + corr * Q1 * (Q1 - 1) / 2
  # variance (Chao 1987 approx) for a rough CI
  if (Q2 > 0) {
    r <- Q1 / Q2
    v <- Q2 * (corr * 0.5 * r^2 + corr^2 * r^3 + corr^2 * 0.25 * r^4)
  } else v <- NA_real_
  se <- if (is.finite(v) && v > 0) sqrt(v) else NA_real_
  list(S_obs = S, chao2 = round(chao, 1),
       lo = if (is.na(se)) NA else round(max(S, chao - 1.96 * se), 1),
       hi = if (is.na(se)) NA else round(chao + 1.96 * se, 1),
       m = m, Q1 = Q1, Q2 = Q2, unstable = Q2 < 3)
}

# ---------------------------------------------------------------------------
# Native vs Invasive — the first-class plant lens.
# ---------------------------------------------------------------------------
# site-level: introduced cover share, introduced richness, unknown rate, by year
native_trend <- function(occ) {
  sp_all <- species_level_only(occ)
  psc_year <- function(y) {
    sp <- sp_all[sp_all$year == y, ]
    if (!nrow(sp)) return(NULL)                       # truly no records that year -> drop
    p <- plot_species_cover(occ, year = y)            # records but no cover -> NA gap, keep the year
    pct <- if (is.null(p)) NA_real_ else {
      tot <- sum(p$mean_cover); intro <- sum(p$mean_cover[p$nativity == "Introduced"])
      if (tot > 0) round(100 * intro / tot, 1) else NA_real_ }
    data.frame(year = y, pct_introduced = pct,
               n_introduced = dplyr::n_distinct(sp$scientificName[sp$nativity == "Introduced"]),
               n_native = dplyr::n_distinct(sp$scientificName[sp$nativity == "Native"]))
  }
  do.call(rbind, lapply(sort(unique(occ$year)), psc_year))
}

# the invasive watchlist: introduced species ranked by mean 1 m^2 cover + ubiquity
invasive_watchlist <- function(occ, year = NULL) {
  psc <- plot_species_cover(occ, year = year)
  if (is.null(psc)) return(NULL)
  inv <- psc[psc$nativity == "Introduced", , drop = FALSE]
  if (!nrow(inv)) return(NULL)
  inv %>% dplyr::group_by(.data$scientificName, .data$family) %>%
    dplyr::summarise(mean_cover = round(mean(.data$mean_cover), 1),
                     n_plots = dplyr::n_distinct(.data$plotID), .groups = "drop") %>%
    dplyr::arrange(dplyr::desc(.data$mean_cover), dplyr::desc(.data$n_plots))
}

# the % of records whose nativity is Unknown — publish it (honesty, like a join rate)
unknown_rate <- function(occ) {
  sp <- species_level_only(occ)
  if (!nrow(sp)) return(NA_real_)
  round(100 * dplyr::n_distinct(sp$scientificName[sp$nativity == "Unknown"]) /
          dplyr::n_distinct(sp$scientificName), 1)
}

# ---------------------------------------------------------------------------
# "Invasion Pressure" — the novel scale-mismatch index (Sarah). For each plot,
# how many INTRODUCED species are already detectable at the smallest (1 m^2)
# scale vs only at larger scales: a foothold-detection signal. Returns per-plot
# introduced richness at 1 m^2 and at 400 m^2 + the native counterpart.
# ---------------------------------------------------------------------------
invasion_pressure <- function(occ, year = NULL) {
  d <- species_level_only(occ)
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
  do.call(rbind, lapply(unique(d$plotID), per_plot))
}

# ---------------------------------------------------------------------------
# One row per SPECIES — the secondary entity (species leaderboard + species card).
# ---------------------------------------------------------------------------
species_summary <- function(occ, year = NULL) {
  d <- species_level_only(occ)
  if (!is.null(year)) d <- d[d$year %in% year, , drop = FALSE]
  if (!nrow(d)) return(NULL)
  cov1 <- d[d$scale == 1 & is.finite(d$percentCover) & d$percentCover > 0, ]
  cov_by_sp <- if (nrow(cov1)) tapply(cov1$percentCover, cov1$scientificName, mean) else numeric(0)
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
# ---------------------------------------------------------------------------
plant_codebook <- function() {
  data.frame(file = c(
    rep("occ_long.csv", 12), rep("plots.csv", 8), rep("ground_cover.csv", 5)),
    column = c(
      "plotID","subplotID","scale_m2","year","bout","taxonID","scientificName",
      "taxonRank","family","nativity","percentCover","is_species",
      "plotID","richness","n_native","n_introduced","total_cover","pct_introduced","plotType","nlcdClass",
      "plotID","subplotID","year","otherVariables","percentCover"),
    meaning = c(
      "NEON plot code","nested subplot code","quadrat scale (1/10/100 m^2; 1 m^2 is the only cover scale)",
      "survey year","within-year bout (spring/monsoon at some sites)","USDA PLANTS symbol (= NEON taxonID)",
      "scientific name","taxonomic rank of the ID","plant family","native / introduced / unknown (from NEON nativeStatusCode)",
      "ocular percent cover at 1 m^2 (NA at presence-only scales)","TRUE if resolved to species level",
      "NEON plot code","species richness (400 m^2 plot list)","native species count","introduced species count",
      "summed mean 1 m^2 cover (relative index)","introduced share of total cover (%)","NEON plot type","NLCD land-cover class",
      "NEON plot code","nested subplot code","survey year","abiotic ground-cover class (soil/litter/rock/...)","ocular percent cover"),
    type = c(
      "chr","chr","int","int","int","chr","chr","chr","chr","chr","num","logical",
      "chr","int","int","int","num","num","chr","chr",
      "chr","chr","int","chr","num"),
    stringsAsFactors = FALSE)
}
