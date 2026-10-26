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

# Nested-cell key shared by a 1 m^2 quadrat and the 10 m^2 subplot it sits in:
# "31_1_1" -> "31_1", "31_10_1" -> "31_1" (same corner and quadrant suffix).
# A 100 m^2 subplot ("31_100") or any non-conforming code has no cell (NA).
# Both 10 m^2 subplots of a corner keep distinct cells, so they are never merged
# into one 10/20 m^2 mix (the subplot_corner() grain bug this replaces).
subplot_cell <- function(x) {
  x <- as.character(x)
  out <- rep(NA_character_, length(x))
  ok <- !is.na(x) & grepl("^[^_]+_(1|10)_[^_]+$", x)
  out[ok] <- sub("^([^_]+)_(1|10)_([^_]+)$", "\\1_\\3", x[ok])
  out
}

.scale_num <- function(s) suppressWarnings(as.numeric(as.character(s)))

# Canonical bout keys for the rows of ONE site-year, with the same tie rule as
# snapshot_by_plot_year(): when every identified bout is numeric the order is
# numeric (and "1"/"1.0" share a key); otherwise locale-independent radix order.
# A row with a missing/blank bout is a candidate only when the whole year has no
# identified bout (one unspecified event); otherwise it belongs to no event.
.year_bout_keys <- function(b) {
  b <- trimws(as.character(b))
  usable <- !is.na(b) & nzchar(b)
  if (!any(usable))
    return(list(key = rep(NA_character_, length(b)), member = rep(TRUE, length(b)),
                order = NA_character_))
  vals <- unique(b[usable])
  nums <- suppressWarnings(as.numeric(vals))
  if (all(is.finite(nums))) {
    bn <- suppressWarnings(as.numeric(b))
    key <- ifelse(usable, as.character(bn), NA_character_)
    ord <- as.character(sort(unique(nums)))
  } else {
    key <- ifelse(usable, b, NA_character_)
    ord <- sort(vals, method = "radix")
  }
  list(key = key, member = usable, order = ord)
}

# Row-level (year, bout-key, event-member) for a whole occurrence table.
.event_keys <- function(occ) {
  n <- nrow(occ)
  yr <- suppressWarnings(as.numeric(as.character(occ$year)))
  b <- if ("bout" %in% names(occ)) occ$bout else rep(NA_character_, n)
  key <- rep(NA_character_, n); member <- rep(FALSE, n); rank <- rep(NA_integer_, n)
  ok <- is.finite(yr) & !is.na(occ$plotID)
  for (y in unique(yr[ok])) {
    iy <- which(ok & yr == y)
    k <- .year_bout_keys(b[iy])
    key[iy] <- k$key; member[iy] <- k$member
    rank[iy] <- if (all(is.na(k$order))) 1L else match(k$key, k$order)
  }
  list(year = yr, key = key, member = member, rank = rank)
}

# ---------------------------------------------------------------------------
# site_events(): one row per site event (year, bout) with the plots surveyed in
# it.  n_plots_1m counts plots carrying scale-1 rows; n_plots_full counts plots
# carrying rows at all of 1, 10 and 100 m^2 in that same (year, bout).  Row
# support only: sampled-but-empty quadrats are not invented.  bout is the
# canonical character key (NA = one unspecified bout); bout_rank orders bouts
# within the year for the "later bout wins a tie" rule.
# ---------------------------------------------------------------------------
site_events <- function(occ) {
  empty <- data.frame(year = numeric(), bout = character(), bout_rank = integer(),
                      n_plots = integer(), n_plots_1m = integer(),
                      n_plots_full = integer(), stringsAsFactors = FALSE)
  empty$plots_1m <- list(); empty$plots_full <- list()
  if (is.null(occ) || !nrow(occ)) return(empty)
  if (!all(c("plotID", "year", "scale") %in% names(occ)))
    stop("site_events() requires plotID, year and scale", call. = FALSE)
  ek <- .event_keys(occ)
  sc <- .scale_num(occ$scale)
  pid <- as.character(occ$plotID)
  use <- which(ek$member)
  if (!length(use)) return(empty)
  ekey <- paste(ek$year[use], ifelse(is.na(ek$key[use]), "<NA>", ek$key[use]), sep = "\r")
  groups <- split(use, ekey, drop = TRUE)
  rows <- lapply(groups, function(ix) {
    p <- pid[ix]; s <- sc[ix]
    has <- function(v) unique(p[is.finite(s) & s == v])
    p1 <- has(1); p10 <- has(10); p100 <- has(100)
    full <- sort(intersect(intersect(p1, p10), p100), method = "radix")
    out <- data.frame(year = ek$year[ix[1]], bout = ek$key[ix[1]],
                      bout_rank = ek$rank[ix[1]], n_plots = length(unique(p)),
                      n_plots_1m = length(p1), n_plots_full = length(full),
                      stringsAsFactors = FALSE)
    out$plots_1m <- list(sort(p1, method = "radix"))
    out$plots_full <- list(full)
    out
  })
  out <- do.call(rbind, rows)
  out <- out[order(out$year, out$bout_rank, method = "radix"), , drop = FALSE]
  rownames(out) <- NULL
  out
}

# pick the bout with the most qualifying plots; ties -> the later bout
.pick_bout <- function(e, count_col) {
  e[order(-e[[count_col]], -e$bout_rank, method = "radix"), , drop = FALSE][1L, , drop = FALSE]
}

# Grain event F: the latest year in which >= 1 plot carries 1, 10 and 100 m^2
# rows; within it the bout with most full-grain plots (tie -> later bout); only
# the plots carrying all three scales in that bout.  NULL when no such year.
select_grain_event <- function(occ, events = NULL) {
  ev <- events %||% site_events(occ)
  ev <- ev[ev$n_plots_full > 0, , drop = FALSE]
  if (!nrow(ev)) return(NULL)
  y <- max(ev$year)
  e <- .pick_bout(ev[ev$year == y, , drop = FALSE], "n_plots_full")
  list(kind = "grain", year = e$year, bout = e$bout,
       plotIDs = e$plots_full[[1]], n_plots = length(e$plots_full[[1]]),
       n_plots_surveyed = e$n_plots, scales = "1/10/100")
}

# Cover event Q: walk years downward from the newest; in each year take the bout
# with most scale-1 plots (tie -> later bout); accept the first whose plot count
# reaches max(min_plots, ceiling(min_share * n_plots(F))).  NULL when none does.
# `grain` may be an event list, a grain_snapshot() frame, or NULL (computed).
select_cover_event <- function(occ, grain = NULL, min_share = 0.5, min_plots = 3L,
                               events = NULL) {
  ev <- events %||% site_events(occ)
  if (is.data.frame(grain)) grain <- attr(grain, "event", exact = TRUE)
  if (is.null(grain)) grain <- select_grain_event(occ, events = ev)
  n_f <- if (is.null(grain)) 0L else as.integer(grain$n_plots)
  need <- max(as.integer(min_plots), as.integer(ceiling(min_share * n_f)))
  ev <- ev[ev$n_plots_1m > 0, , drop = FALSE]
  for (y in sort(unique(ev$year), decreasing = TRUE)) {
    e <- .pick_bout(ev[ev$year == y, , drop = FALSE], "n_plots_1m")
    if (e$n_plots_1m >= need)
      return(list(kind = "cover", year = e$year, bout = e$bout,
                  plotIDs = e$plots_1m[[1]], n_plots = e$n_plots_1m,
                  n_plots_surveyed = e$n_plots, scales = "1",
                  min_plots_required = need))
  }
  NULL
}

# "2023 · bout 2 · 33 plots · 1/10/100 m²" (grain) / "... · 1 m² cover" (cover)
event_label <- function(ev, kind = c("grain", "cover")) {
  kind <- match.arg(kind)
  if (is.null(ev))
    return(if (kind == "grain") "no full-grain (1/10/100 m²) survey event" else
      "no cover survey event")
  bout <- if (is.na(ev$bout)) "bout unspecified" else paste("bout", ev$bout)
  tail <- if (kind == "grain") "1/10/100 m²" else "1 m² cover"
  sprintf("%s · %s · %d plot%s · %s", format(ev$year, scientific = FALSE), bout,
          as.integer(ev$n_plots), if (as.integer(ev$n_plots) == 1L) "" else "s", tail)
}

# Rows of one site event, optionally restricted to scales.  Bout-safe: an NA
# event bout matches only the rows of a year with no identified bout at all.
# Input row order is preserved and never affects which rows are selected.
snapshot_event <- function(occ, ev, scales = NULL) {
  if (is.null(occ)) return(occ)
  if (is.null(ev) || !nrow(occ)) return(occ[0, , drop = FALSE])
  ek <- .event_keys(occ)
  same_bout <- if (is.na(ev$bout)) is.na(ek$key) else (!is.na(ek$key) & ek$key == ev$bout)
  keep <- ek$member & is.finite(ek$year) & ek$year == ev$year & same_bout &
    as.character(occ$plotID) %in% ev$plotIDs
  if (!is.null(scales)) keep <- keep & .scale_num(occ$scale) %in% as.numeric(scales)
  occ[keep, , drop = FALSE]
}

# Per-plot support for one event: every plot observed at the site is listed,
# with whether it entered the event and why not.  An audit trail only.
.event_support <- function(occ, ev, kind, events) {
  pid <- as.character(occ$plotID)
  plots <- sort(unique(pid[!is.na(pid)]), method = "radix")
  yr <- suppressWarnings(as.numeric(as.character(occ$year)))
  latest <- vapply(plots, function(p) {
    y <- yr[pid == p & is.finite(yr)]; if (length(y)) max(y) else NA_real_
  }, numeric(1))
  if (is.null(ev)) {
    status <- rep(if (kind == "grain") "no full-grain year at site" else
      "no cover event meets the plot floor", length(plots))
    return(data.frame(plotID = plots, kind = kind, event_year = NA_real_,
                      event_bout = NA_character_, in_snapshot = FALSE,
                      status = status, plot_latest_year = unname(latest),
                      stringsAsFactors = FALSE))
  }
  er <- events[events$year == ev$year &
                 (if (is.na(ev$bout)) is.na(events$bout) else
                   (!is.na(events$bout) & events$bout == ev$bout)), , drop = FALSE]
  surveyed <- if (nrow(er)) {
    ex <- snapshot_event(occ, list(year = ev$year, bout = ev$bout, plotIDs = plots))
    unique(as.character(ex$plotID))
  } else character()
  inside <- plots %in% ev$plotIDs
  status <- ifelse(inside, "in event",
    ifelse(plots %in% surveyed,
           if (kind == "grain") "surveyed in event without all of 1/10/100 m²" else
             "surveyed in event without 1 m² rows",
           "not surveyed in event"))
  data.frame(plotID = plots, kind = kind, event_year = ev$year,
             event_bout = ev$bout, in_snapshot = inside, status = status,
             plot_latest_year = unname(latest), stringsAsFactors = FALSE)
}

# ---------------------------------------------------------------------------
# grain_snapshot() = F.  Every richness / incidence / species-area figure uses
# F: one site event (year, bout) whose plots all carry 1, 10 and 100 m^2 rows.
# NEON surveys 10/100 m^2 only every other year since 2019, so a per-plot
# "latest year" lands on 1 m^2-only years and mislabels 1 m^2 lists as 400 m^2
# plot lists; F never does.  Plots outside the event are not in the snapshot;
# attr "snapshot_support" lists them with the reason.  No full-grain year ->
# a zero-row frame (never an error, never a silent fallback).
# ---------------------------------------------------------------------------
grain_snapshot <- function(occ, events = NULL) {
  if (is.null(occ)) return(occ)
  ev_tab <- events %||% site_events(occ)
  ev <- select_grain_event(occ, events = ev_tab)
  out <- snapshot_event(occ, ev)
  attr(out, "event") <- ev
  attr(out, "snapshot_label") <- event_label(ev, "grain")
  attr(out, "snapshot_support") <- if (nrow(occ)) .event_support(occ, ev, "grain", ev_tab) else NULL
  out
}

# ---------------------------------------------------------------------------
# sampled_units(): the 1 m^2 sampling units of one cover event (PD-14, lead
# decision 3).  A plot's units are the union of the event's 1 m^2 subplotIDs
# over EVERY occurrence row (any taxon rank, so a quadrat holding only a coarse
# ID still counts) and the event's ground-cover rows (a quadrat with no plant
# record but a ground-cover record was sampled; it contributes zero plant
# cover).  Returns data.frame(plotID, subplotID), one row per unit, sorted.
# Nothing is invented: a quadrat with neither record type stays unknown.
# ---------------------------------------------------------------------------
sampled_units <- function(occ_event, ground_event = NULL) {
  pick <- function(d, scale_one) {
    if (is.null(d) || !nrow(d) || !all(c("plotID", "subplotID") %in% names(d)))
      return(data.frame(plotID = character(), subplotID = character(), stringsAsFactors = FALSE))
    keep <- !is.na(d$plotID) & !is.na(d$subplotID)
    if (scale_one && "scale" %in% names(d)) keep <- keep & .scale_num(d$scale) %in% 1
    data.frame(plotID = as.character(d$plotID[keep]),
               subplotID = as.character(d$subplotID[keep]), stringsAsFactors = FALSE)
  }
  u <- rbind(pick(occ_event, TRUE), pick(ground_event, FALSE))
  u <- u[!duplicated(u), , drop = FALSE]
  u <- u[order(u$plotID, u$subplotID, method = "radix"), , drop = FALSE]
  rownames(u) <- NULL
  u
}

# cover_snapshot() = Q.  Every cover-weighted figure (cover, Hill, Chao2,
# watchlist, % introduced) uses Q: scale-1 rows of the newest site event with
# enough 1 m^2 plots (see select_cover_event()).  attr "event" as for F, and
# attr "sampled_units" = sampled_units(Q rows, the event's ground rows): the
# structural-zero cover denominator every cover helper reads.  `ground` is the
# bundle's ground-cover table (optional; without it units come from occurrence
# rows of any rank only).
cover_snapshot <- function(occ, grain = NULL, events = NULL, min_share = 0.5, min_plots = 3L,
                           ground = NULL) {
  if (is.null(occ)) return(occ)
  ev_tab <- events %||% site_events(occ)
  ev <- select_cover_event(occ, grain = grain, min_share = min_share,
                           min_plots = min_plots, events = ev_tab)
  out <- snapshot_event(occ, ev, scales = 1)
  ground_event <- if (!is.null(ev) && !is.null(ground) && nrow(ground) &&
                      all(c("plotID", "subplotID", "year") %in% names(ground)))
    snapshot_event(ground, ev) else NULL
  attr(out, "event") <- ev
  attr(out, "snapshot_label") <- event_label(ev, "cover")
  attr(out, "snapshot_support") <- if (nrow(occ)) .event_support(occ, ev, "cover", ev_tab) else NULL
  attr(out, "sampled_units") <- sampled_units(out, ground_event)
  out
}

# Both labelled events of a site in one call.
# min_share / min_plots pass through to select_cover_event() (defaults = contract);
# `ground` (the bundle's ground table) completes the cover event's sampled units.
site_snapshot <- function(occ, ground = NULL, min_share = 0.5, min_plots = 3L) {
  ev_tab <- if (is.null(occ)) NULL else site_events(occ)
  grain <- grain_snapshot(occ, events = ev_tab)
  cover <- cover_snapshot(occ, grain = attr(grain, "event", exact = TRUE), events = ev_tab,
                          min_share = min_share, min_plots = min_plots, ground = ground)
  row <- function(kind, ev) data.frame(
    kind = kind,
    year = if (is.null(ev)) NA_real_ else ev$year,
    bout = if (is.null(ev)) NA_character_ else ev$bout,
    n_plots = if (is.null(ev)) 0L else as.integer(ev$n_plots),
    label = event_label(ev, kind), stringsAsFactors = FALSE)
  list(grain = grain, cover = cover,
       events = rbind(row("grain", attr(grain, "event", exact = TRUE)), row("cover", attr(cover, "event", exact = TRUE))))
}

# DEPRECATED alias of grain_snapshot(), kept so a stray caller receives F (one
# full-grain site event) and can never again receive 1 m^2-only years labelled
# as a plot list.  New code: grain_snapshot() / cover_snapshot() / site_snapshot().
latest_snapshot <- function(occ) grain_snapshot(occ)


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
# legacy_plot_latest_snapshot(): the RETIRED v1 rule, kept verbatim only so
# scripts/verify_bundle.R can reconcile a site_index built before contract
# plant-snapshot-v2.  It keeps, for EACH plot, its latest (year, bout).  It is
# wrong as an estimator: since 2019 NEON surveys 10/100 m^2 every other year, so
# at 40 of 46 sites it mixed 1 m^2-only plot years into a "400 m^2 plot list".
# Do not call it from the app or from any estimator.
# ---------------------------------------------------------------------------
legacy_plot_latest_snapshot <- function(occ) {
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
site_invasion <- function(occ, units = attr(occ, "sampled_units", exact = TRUE)) {
  psc <- plot_species_cover(occ, units = units); if (is.null(psc)) return(NA_real_)
  tot <- sum(psc$mean_cover, na.rm = TRUE)
  intro <- sum(psc$mean_cover[psc$nativity == "Introduced"], na.rm = TRUE)
  if (tot > 0) round(100 * intro / tot, 1) else NA_real_
}

# site-level UNKNOWN cover share — the cover-unit companion to unknown_rate()
# (which is a species-count figure). Surfaced next to the % introduced hero so the
# honesty number is measured on the same unit (cover) as the metric it qualifies.
unknown_cover_share <- function(occ, units = attr(occ, "sampled_units", exact = TRUE)) {
  psc <- plot_species_cover(occ, units = units); if (is.null(psc)) return(NA_real_)
  tot <- sum(psc$mean_cover, na.rm = TRUE)
  unk <- sum(psc$mean_cover[psc$nativity == "Unknown"], na.rm = TRUE)
  if (tot > 0) round(100 * unk / tot, 1) else NA_real_
}

# ---------------------------------------------------------------------------
# The structural-zero denominator for a cover table: per plot, its distinct
# 1 m^2 sampling units.  Units = `units` (normally attr(Q, "sampled_units"):
# occurrence rows of any rank plus the event's ground-cover rows) united with
# every scale-1 row of `occ` of any rank, so a quadrat holding only a coarse ID
# or only ground cover still counts.  Supported plots = the plots in the table.
# Returns data.frame(plotID, n_sub).
# ---------------------------------------------------------------------------
cover_units_by_plot <- function(occ, units = NULL, year = NULL) {
  d <- occ
  if (!is.null(d) && !is.null(year)) d <- d[d$year %in% year, , drop = FALSE]
  s1 <- sampled_units(d, NULL)
  u <- if (!is.null(units) && is.data.frame(units) && nrow(units)) {
    uu <- data.frame(plotID = as.character(units$plotID),
                     subplotID = as.character(units$subplotID), stringsAsFactors = FALSE)
    rbind(uu, s1)
  } else s1
  u <- u[!is.na(u$plotID) & !is.na(u$subplotID) & !duplicated(u), , drop = FALSE]
  if (!nrow(u)) return(data.frame(plotID = character(), n_sub = integer(), stringsAsFactors = FALSE))
  n <- tapply(u$subplotID, u$plotID, length)
  out <- data.frame(plotID = names(n), n_sub = as.integer(n), stringsAsFactors = FALSE)
  out[order(out$plotID, method = "radix"), , drop = FALSE]
}

# ---------------------------------------------------------------------------
# Per-species mean % cover within a plot: the species' summed 1 m^2 cover over
# the plot's sampled 1 m^2 units (cover_units_by_plot()), so absence from a
# sampled quadrat contributes zero.  `units` defaults to attr(occ,
# "sampled_units") (attached by cover_snapshot()); pass it explicitly when
# `occ` is a subset that lost the attribute.  No rounding here: values are
# rounded only where they are printed.  Rows that share a sampling key with
# different cover are summed (aggregation is a sum; they are flagged by
# flag_duplicate_records()).  attrs: n_supported_plots, units_per_plot.
# ---------------------------------------------------------------------------
plot_species_cover <- function(occ, year = NULL, units = attr(occ, "sampled_units", exact = TRUE)) {
  if (is.null(occ) || !nrow(occ)) return(NULL)
  units <- units
  nsub <- cover_units_by_plot(occ, units = units, year = year)
  d1 <- resolve_nativity_records(species_level_only(occ))
  d1 <- d1[.scale_num(d1$scale) %in% 1, , drop = FALSE]
  if (!is.null(year)) d1 <- d1[d1$year %in% year, , drop = FALSE]
  if (!nrow(d1) || !nrow(nsub)) return(NULL)
  cov <- d1[is.finite(d1$percentCover) & d1$percentCover > 0, , drop = FALSE]
  if (!nrow(cov)) return(NULL)
  agg <- cov %>% dplyr::group_by(.data$plotID, .data$scientificName, .data$family, .data$nativity) %>%
    dplyr::summarise(sum_cover = sum(.data$percentCover), n_present = dplyr::n(), .groups = "drop") %>%
    dplyr::left_join(nsub, by = "plotID")
  agg$mean_cover <- agg$sum_cover / agg$n_sub   # mean cover over ALL sampled 1 m^2 units, unrounded
  attr(agg, "n_supported_plots") <- nrow(nsub)
  attr(agg, "units_per_plot") <- nsub
  agg
}

# Labels of the events behind a mixed presence/cover table.  A frame without an
# "event" attribute (a raw fixture) gets NA; with no cover table the cover label
# describes the grain event's own 1 m^2 rows (option A of contract v2).
.event_labels <- function(grain, cover) {
  gev <- attr(grain, "event", exact = TRUE)
  g <- if (is.null(gev)) NA_character_ else event_label(gev, "grain")
  cv <- if (is.null(cover)) { if (is.null(gev)) NA_character_ else event_label(gev, "cover") } else {
    cev <- attr(cover, "event", exact = TRUE); if (is.null(cev)) NA_character_ else event_label(cev, "cover") }
  list(grain = g, cover = cv)
}

# ---------------------------------------------------------------------------
# One row per PLOT — the unit the Diversity Lab scatters and the Plot Profile
# drills into.  Presence columns (richness = 400 m^2 whole-plot union, native /
# introduced / unknown richness, plotType, nlcdClass, lat, lng) come from the
# grain snapshot F; cover columns (total/intro/native cover, dominant,
# pct_introduced) come from the cover snapshot Q's 1 m^2 rows (`cover`), or from
# F's own 1 m^2 rows when no cover table is given.  Rows are F's plots; a plot in
# F without Q cover keeps NA cover (never zero).  attrs grain_event / cover_event
# carry the two event labels.
# ---------------------------------------------------------------------------
plot_summary <- function(grain, cover = NULL, year = NULL) {
  labels <- .event_labels(grain, cover)
  d <- resolve_nativity_records(species_level_only(grain))
  if (is.null(d)) return(NULL)
  if (!is.null(year)) d <- d[d$year %in% year, , drop = FALSE]
  if (!nrow(d)) return(NULL)
  rich <- d %>% dplyr::group_by(.data$plotID) %>%
    dplyr::summarise(
      richness     = dplyr::n_distinct(.data$scientificName),
      n_native     = dplyr::n_distinct(.data$scientificName[.data$nativity == "Native"]),
      n_introduced = dplyr::n_distinct(.data$scientificName[.data$nativity == "Introduced"]),
      n_unknown    = dplyr::n_distinct(.data$scientificName[.data$nativity == "Unknown"]),
      plotType = mode_chr(.data$plotType), nlcdClass = mode_chr(.data$nlcdClass),
      lat = stats::median(.data$lat, na.rm = TRUE), lng = stats::median(.data$lng, na.rm = TRUE),
      .groups = "drop")
  cv <- if (is.null(cover)) grain else cover
  cv_units <- attr(cv, "sampled_units", exact = TRUE)
  if (!is.null(year) && !is.null(cv) && nrow(cv)) cv <- cv[cv$year %in% year, , drop = FALSE]
  psc <- if (is.null(cv) || !nrow(cv)) NULL else plot_species_cover(cv, units = cv_units)
  # sums are unrounded; the 1-dp rounding is display precision applied last, and
  # pct_introduced is computed from the unrounded sums (no double rounding)
  covagg <- if (is.null(psc)) NULL else psc %>% dplyr::group_by(.data$plotID) %>%
    dplyr::summarise(
      total_cover  = sum(.data$mean_cover),
      intro_cover  = sum(.data$mean_cover[.data$nativity == "Introduced"]),
      native_cover = sum(.data$mean_cover[.data$nativity == "Native"]),
      dominant     = .data$scientificName[which.max(.data$mean_cover)],
      dominant_cover = max(.data$mean_cover),
      .groups = "drop")
  out <- if (is.null(covagg)) rich else dplyr::left_join(rich, covagg, by = "plotID")
  for (nm in c("total_cover", "intro_cover", "native_cover", "dominant_cover"))
    if (!(nm %in% names(out))) out[[nm]] <- NA_real_
  if (!("dominant" %in% names(out))) out$dominant <- NA_character_
  out$pct_introduced <- ifelse(is.finite(out$total_cover) & out$total_cover > 0,
                               round(100 * out$intro_cover / out$total_cover, 1), NA_real_)
  for (nm in c("total_cover", "intro_cover", "native_cover", "dominant_cover"))
    out[[nm]] <- round(out[[nm]], 1)
  out <- out %>% dplyr::arrange(dplyr::desc(.data$richness))
  attr(out, "grain_event") <- labels$grain
  attr(out, "cover_event") <- labels$cover
  out
}

# ---------------------------------------------------------------------------
# Annual plant estimands.  First calculate every response at the plot-year
# level after deterministic bout selection; then retain the same recurrent
# plots in every year for the requested response.  This prevents changing plot
# effort from masquerading as a temporal or environmental signal.
# ---------------------------------------------------------------------------
# Sampled 1 m^2 units of each plot-year's selected bout: scale-1 rows of any
# rank in `py` (a snapshot_by_plot_year() result) plus the ground-cover rows of
# the same plot, year and selected bout.  data.frame(plotID, year, subplotID).
.plot_year_units <- function(py, ground = NULL) {
  occ_u <- py[.scale_num(py$scale) %in% 1 & !is.na(py$plotID) & !is.na(py$subplotID),
              c("plotID", "year", "subplotID"), drop = FALSE]
  occ_u <- data.frame(plotID = as.character(occ_u$plotID), year = occ_u$year,
                      subplotID = as.character(occ_u$subplotID), stringsAsFactors = FALSE)
  sup <- attr(py, "snapshot_support")
  g_u <- NULL
  if (!is.null(ground) && nrow(ground) && !is.null(sup) && nrow(sup) &&
      all(c("plotID", "subplotID", "year") %in% names(ground))) {
    g <- ground[!is.na(ground$plotID) & !is.na(ground$subplotID), , drop = FALSE]
    key <- paste(as.character(g$plotID), g$year, sep = "\r")
    skey <- paste(as.character(sup$plotID), sup$year, sep = "\r")
    sel <- sup$selected_bout[match(key, skey)]
    gb <- if ("bout" %in% names(g)) trimws(as.character(g$bout)) else rep(NA_character_, nrow(g))
    same <- ifelse(is.na(sel), TRUE,
                   !is.na(gb) & (gb == sel |
                     (is.finite(suppressWarnings(as.numeric(gb))) &
                        suppressWarnings(as.numeric(gb)) == suppressWarnings(as.numeric(sel)))))
    keep <- key %in% skey & same %in% TRUE
    g <- g[keep, , drop = FALSE]
    if (nrow(g)) g_u <- data.frame(plotID = as.character(g$plotID), year = g$year,
                                   subplotID = as.character(g$subplotID), stringsAsFactors = FALSE)
  }
  u <- rbind(occ_u, g_u)
  u[!duplicated(u), , drop = FALSE]
}

annual_plant_metrics <- function(occ, ground = NULL) {
  py <- snapshot_by_plot_year(occ)
  if (is.null(py) || !nrow(py)) return(NULL)
  units_all <- .plot_year_units(py, ground)
  d <- resolve_nativity_records(species_level_only(py))
  if (is.null(d) || !nrow(d)) return(NULL)
  yrs <- sort(unique(d$year[!is.na(d$year)]))
  if (!length(yrs)) return(NULL)

  one_year <- function(y) {
    dy <- d[d$year == y, , drop = FALSE]
    # Mean 1 m^2 subplot richness per plot: the only grain NEON surveys every
    # year.  A 400 m^2 plot list would follow the biennial 10/100 m^2 schedule
    # (a sawtooth, not a signal).  Every recorded 1 m^2 quadrat of the plot is a
    # unit (zero for a nativity class it lacks); none is invented or dropped to
    # a hard-coded subplot set.
    s1 <- dy[is.finite(.scale_num(dy$scale)) & .scale_num(dy$scale) == 1, , drop = FALSE]
    if (!nrow(s1)) return(NULL)
    per_sub <- s1 %>% dplyr::group_by(.data$plotID, .data$subplotID) %>%
      dplyr::summarise(
        r = dplyr::n_distinct(.data$scientificName),
        rn = dplyr::n_distinct(.data$scientificName[.data$nativity == "Native"]),
        ri = dplyr::n_distinct(.data$scientificName[.data$nativity == "Introduced"]),
        .groups = "drop")
    rich <- per_sub %>% dplyr::group_by(.data$plotID) %>%
      dplyr::summarise(richness = mean(.data$r), n_native = mean(.data$rn),
                       n_introduced = mean(.data$ri), .groups = "drop")

    uy <- units_all[units_all$year %in% y, c("plotID", "subplotID"), drop = FALSE]
    psc <- plot_species_cover(dy, units = uy)
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

    # sampled 1 m^2 units of the selected bout (any rank + ground cover): the
    # cover denominator and the support label of every annual response
    nunit <- if (nrow(uy)) {
      tt <- tapply(uy$subplotID, uy$plotID, length)
      data.frame(plotID = names(tt), n_sampling_units = as.integer(tt), stringsAsFactors = FALSE)
    } else NULL
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
  if (is.null(out) || !nrow(out)) return(NULL)
  rownames(out) <- NULL
  attr(out, "estimand") <- paste(
    "plot-year response after one deterministic bout per plot-year;",
    "richness, n_native and n_introduced are mean 1 m^2 subplot richness per plot",
    "(the annually surveyed grain), cover is the 1 m^2 relative cover index over the",
    "selected bout's sampled 1 m^2 units (occurrence rows of any rank plus ground cover)")
  out
}

# Registered NEON DP1.10058.001 design changes that break a time series.  Trend
# charts mark them and never draw one line across 2019.
PLANT_DESIGN_BREAKS <- data.frame(
  year = c(2018, 2019, 2026),
  label = c("half-plot design (changeLog 16203)",
            "6 subplots; 10/100 m² biennial (16207)",
            "plant diversity sampling suspended (110012)"),
  source = c("NEON DP1.10058.001 issue log 16203",
             "NEON DP1.10058.001 issue log 16204/16207",
             "NEON DP1.10058.001 issue log 110012"),
  stringsAsFactors = FALSE)

# plotly layout pieces for the design breaks inside [min(years), max(years) + 1]:
# dashed vertical lines between survey years plus small top labels.  Returns
# list(shapes = list(...), annotations = list(...)); both empty when none apply.
design_break_shapes <- function(years, dark = FALSE) {
  yrs <- suppressWarnings(as.numeric(years)); yrs <- yrs[is.finite(yrs)]
  empty <- list(shapes = list(), annotations = list())
  if (!length(yrs)) return(empty)
  b <- PLANT_DESIGN_BREAKS[PLANT_DESIGN_BREAKS$year >= min(yrs) &
                             PLANT_DESIGN_BREAKS$year <= max(yrs) + 1, , drop = FALSE]
  if (!nrow(b)) return(empty)
  col <- if (dark) "rgba(214,226,214,0.6)" else "rgba(70,80,70,0.55)"
  txt <- if (dark) "#cfd8cf" else "#4a554a"
  x <- b$year - 0.5
  list(
    shapes = lapply(x, function(v) list(
      type = "line", xref = "x", yref = "paper", x0 = v, x1 = v, y0 = 0, y1 = 1,
      line = list(color = col, width = 1, dash = "dash"), layer = "below")),
    annotations = lapply(seq_along(x), function(i) list(
      x = x[i], y = 1, xref = "x", yref = "paper", text = b$label[i],
      showarrow = FALSE, xanchor = "left", yanchor = "bottom", textangle = 0,
      font = list(size = 9, color = txt))))
}

# Segment key for drawing a trend as separate pre-/post-2019 traces.
design_segment <- function(years, at = 2019) {
  y <- suppressWarnings(as.numeric(years))
  ifelse(is.finite(y) & y >= at, paste0(at, " onward"), paste0("before ", at))
}

balanced_plant_metric_series <- function(occ, metric = "richness", ground = NULL) {
  pm <- annual_plant_metrics(occ, ground = ground)
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
# Per-PLOT nested species-area curve at NEON's registered grains.  Input is the
# grain snapshot F (one site event, every plot carrying 1, 10 and 100 m^2 rows).
#   1 m^2   = mean richness over the plot's 1 m^2 quadrats;
#   10 m^2  = mean over the plot's 10 m^2 subplots of the UNION of that
#             subplot's rows and its nested 1 m^2 quadrat (same subplot_cell());
#             the two 10 m^2 subplots of a corner stay separate units.  A 1 m^2
#             quadrat whose parent 10 m^2 subplot carries no rows still marks a
#             surveyed 10 m^2 unit (NEON's 10 m^2 list need not repeat nested
#             species), so its union is its own quadrat list;
#   100 m^2 = mean over corners of the union of that corner's 100, 10 and 1 m^2
#             rows;
#   400 m^2 = whole-plot union.
# Union is the rule at every grain because NEON's coarser tables record only part
# of the species already listed at the nested finer grain.  A plot lacking rows at
# a scale contributes NA there (and 400 m^2 needs all three scales), so a 1 m^2
# list is never relabelled as a larger grain.
# ---------------------------------------------------------------------------
species_area_plot <- function(occ, plotID, year = NULL) {
  d <- species_level_only(occ)
  d <- d[d$plotID == plotID, , drop = FALSE]
  if (!is.null(year)) d <- d[d$year %in% year, , drop = FALSE]
  if (!nrow(d)) return(NULL)
  sc <- .scale_num(d$scale)
  sp <- as.character(d$scientificName)
  sub <- as.character(d$subplotID)
  cell <- subplot_cell(sub)
  corner <- subplot_corner(sub)
  has <- function(v) any(is.finite(sc) & sc == v)
  r1 <- if (has(1)) {
    i1 <- which(sc == 1)
    mean(vapply(split(sp[i1], sub[i1]), function(x) length(unique(x)), numeric(1)))
  } else NA_real_
  r10 <- if (has(10)) {
    cells <- unique(cell[sc %in% c(1, 10) & !is.na(cell)])
    if (length(cells)) mean(vapply(cells, function(k)
      length(unique(sp[sc %in% c(1, 10) & !is.na(cell) & cell == k])), numeric(1))) else NA_real_
  } else NA_real_
  r100 <- if (has(100)) {
    cc <- unique(corner[sc %in% c(1, 10, 100)])
    mean(vapply(cc, function(k) length(unique(sp[sc %in% c(1, 10, 100) & corner == k])),
                numeric(1)))
  } else NA_real_
  r400 <- if (has(1) && has(10) && has(100)) length(unique(sp)) else NA_real_
  data.frame(area_m2 = c(1, 10, 100, 400), richness = c(r1, r10, r100, r400))
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
native_trend <- function(occ, ground = NULL) {
  pct <- balanced_plant_metric_series(occ, "pct_introduced", ground = ground)
  if (is.null(pct)) return(NULL)
  panel <- attr(pct, "panel_plotIDs")
  metrics <- annual_plant_metrics(occ, ground = ground)
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
# mean_cover is UNROUNDED (a present invader is never exported as 0); round or
# signif() only where printed.  n_supported_plots = plots with sampled units.
invasive_watchlist <- function(occ, year = NULL, units = attr(occ, "sampled_units", exact = TRUE)) {
  psc <- plot_species_cover(occ, year = year, units = units)
  if (is.null(psc)) return(NULL)
  inv <- psc[psc$nativity == "Introduced", , drop = FALSE]
  if (!nrow(inv)) return(NULL)
  n_supported <- attr(psc, "n_supported_plots", exact = TRUE) %||% 0L
  if (!n_supported) return(NULL)
  inv %>% dplyr::group_by(.data$scientificName, .data$family) %>%
    dplyr::summarise(
      # Species absent from a supported plot contributes zero here; this is not
      # a mean over only the plots where the introduced species was present.
      mean_cover = sum(.data$mean_cover, na.rm = TRUE) / n_supported,
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
# Per-introduced-species cross-scale occurrence (input: grain snapshot F). It counts plots where a taxon
# was recorded at 1 m^2 versus anywhere in the nested 400 m^2 plot list. A gap
# between the counts is a sampling-grain/detection result, not evidence of a
# foothold, spread, establishment, impact, or management priority. Plot lists
# are retained so every point is auditable.
# ---------------------------------------------------------------------------
species_cross_scale_occurrence <- function(occ, year = NULL, cover = NULL) {
  d <- resolve_nativity_records(species_level_only(occ))
  if (!is.null(year)) d <- d[d$year %in% year, , drop = FALSE]
  intro <- d[d$nativity == "Introduced", , drop = FALSE]
  if (!nrow(intro)) return(NULL)
  # occ is the grain snapshot F (needs 1 and 400 m^2); mean 1 m^2 cover comes
  # from the cover snapshot Q when supplied, else from F's own 1 m^2 rows.
  wl <- if (is.null(cover)) invasive_watchlist(d, year = year, units = NULL) else
    invasive_watchlist(cover, year = year)
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
               mean_cover_1m = signif(as.numeric(mean_cov[sp] %||% NA_real_), 3),
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
species_foothold <- function(occ, year = NULL, cover = NULL)
  species_cross_scale_occurrence(occ, year = year, cover = cover)

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
# family, nativity, n_plots (plots where recorded at any grain) and min_scale come
# from the grain snapshot F; mean_cover is the structural-zero site mean over the
# cover table (Q, or F's own 1 m^2 rows when `cover` is NULL): the sum of the
# species' per-plot mean 1 m^2 cover divided by every supported plot (a plot with
# scale-1 rows), so absence counts as zero.  plots_with_cover = supported plots
# where the species had positive cover.  Species recorded only in the cover event
# are not added (the rows are F's species).
# ---------------------------------------------------------------------------
species_summary <- function(grain, cover = NULL, year = NULL) {
  labels <- .event_labels(grain, cover)
  d <- resolve_nativity_records(species_level_only(grain))
  if (is.null(d)) return(NULL)
  if (!is.null(year)) d <- d[d$year %in% year, , drop = FALSE]
  if (!nrow(d)) return(NULL)
  # the cover table keeps every rank: coarse-only quadrats are sampled units
  cv <- if (is.null(cover)) grain else cover
  cv_units <- attr(cv, "sampled_units", exact = TRUE)
  if (!is.null(year) && !is.null(cv) && nrow(cv)) cv <- cv[cv$year %in% year, , drop = FALSE]
  nsub <- if (is.null(cv) || !nrow(cv)) NULL else cover_units_by_plot(cv, units = cv_units)
  supported_plots <- if (is.null(nsub)) character() else nsub$plotID
  psc <- if (length(supported_plots)) plot_species_cover(cv, units = cv_units) else NULL
  cov_by_sp <- if (!is.null(psc) && nrow(psc)) {
    tapply(psc$mean_cover, psc$scientificName, sum) / length(supported_plots)
  } else numeric(0)
  n_cov_by_sp <- if (!is.null(psc) && nrow(psc))
    tapply(psc$plotID, psc$scientificName, function(x) length(unique(x))) else integer(0)
  out <- d %>% dplyr::group_by(.data$scientificName) %>%
    dplyr::summarise(family = mode_chr(.data$family), nativity = mode_chr(.data$nativity),
                     n_plots = dplyr::n_distinct(.data$plotID),
                     min_scale = suppressWarnings(min(.data$scale, na.rm = TRUE)),
                     .groups = "drop") %>%
    dplyr::mutate(
      mean_cover = as.numeric(cov_by_sp[.data$scientificName]),
      plots_with_cover = dplyr::coalesce(as.integer(n_cov_by_sp[.data$scientificName]), 0L)) %>%
    dplyr::arrange(dplyr::desc(.data$n_plots), dplyr::desc(.data$mean_cover))
  if (!length(supported_plots)) out$plots_with_cover <- NA_integer_
  attr(out, "grain_event") <- labels$grain
  attr(out, "cover_event") <- labels$cover
  attr(out, "n_supported_plots") <- length(supported_plots)
  out
}

# ---------------------------------------------------------------------------
# The site headline numbers from one site_snapshot() result, each on its own
# event: species, plots, introduced species and species-area on the grain
# event F (nativity conflicts resolved within F); % introduced cover, Chao2
# and its S_obs on the cover event Q.  One definition for the hero, the PDF,
# the compare view and scripts/verify_bundle.R (which checks it against the
# independent oracle in scripts/plant_oracle.R).
# ---------------------------------------------------------------------------
snapshot_headlines <- function(ss) {
  g <- ss$grain; q <- ss$cover
  g_ok <- !is.null(g) && nrow(g) > 0
  q_ok <- !is.null(q) && nrow(q) > 0
  sp <- if (g_ok) resolve_nativity_records(species_level_only(g)) else NULL
  sa <- if (g_ok) species_area_site(g) else NULL
  ch <- if (q_ok) chao2(q) else NULL
  sa_at <- function(a) if (is.null(sa)) NA_real_ else {
    v <- sa$richness[sa$area_m2 == a]; if (length(v)) v else NA_real_ }
  list(
    species = if (g_ok) length(unique(sp$scientificName)) else NA_integer_,
    n_plots = if (g_ok) length(unique(g$plotID)) else NA_integer_,
    n_introduced_species = if (g_ok) length(unique(sp$scientificName[sp$nativity == "Introduced"])) else NA_integer_,
    pct_introduced = if (q_ok) site_invasion(q) else NA_real_,
    species_area = c(`1` = sa_at(1), `10` = sa_at(10), `100` = sa_at(100), `400` = sa_at(400)),
    chao2 = if (is.null(ch)) NA_real_ else ch$chao2,
    S_obs = if (is.null(ch)) NA_integer_ else ch$S_obs)
}

# ---------------------------------------------------------------------------
# One search-index row per species at a site (scripts/build_search_index.R and
# the science-contract tests share this).  Presence (family, nativity, n_plots)
# from the grain snapshot F; mean_cover and plots_with_cover from
# species_summary(F, Q); year_min / year_max span every bundled year.
# ---------------------------------------------------------------------------
search_taxa_for_site <- function(site, bundle) {
  if (is.null(bundle$occ) || !nrow(bundle$occ))
    stop(sprintf("%s has no occurrence table", site), call. = FALSE)
  ss <- site_snapshot(bundle$occ, ground = bundle$ground)
  sp <- species_summary(ss$grain, ss$cover)
  if (is.null(sp) || !nrow(sp))
    stop(sprintf("%s has no species-level grain snapshot", site), call. = FALSE)
  years <- species_level_only(bundle$occ) |>
    dplyr::group_by(.data$scientificName) |>
    dplyr::summarise(
      year_min = suppressWarnings(min(.data$year, na.rm = TRUE)),
      year_max = suppressWarnings(max(.data$year, na.rm = TRUE)),
      .groups = "drop"
    )
  output <- as.data.frame(sp, stringsAsFactors = FALSE)
  output$site <- site
  output <- dplyr::left_join(output, years, by = "scientificName")
  output[, c("scientificName", "site", "family", "nativity", "mean_cover",
             "n_plots", "plots_with_cover", "year_min", "year_max")]
}

# cover composition by a grouping column (family or nativity) for the Overview
cover_by_group <- function(occ, by = c("family", "nativity"), year = NULL,
                           units = attr(occ, "sampled_units", exact = TRUE)) {
  by <- match.arg(by)
  psc <- plot_species_cover(occ, year = year, units = units)
  if (is.null(psc)) return(NULL)
  psc %>% dplyr::group_by(.data[[by]]) %>%
    dplyr::summarise(cover = round(sum(.data$mean_cover), 1),
                     n_species = dplyr::n_distinct(.data$scientificName), .groups = "drop") %>%
    dplyr::arrange(dplyr::desc(.data$cover))
}

# ---------------------------------------------------------------------------
# Abiotic ground cover per class (PD-15).  With `cover` = the cover snapshot Q,
# the ground rows are restricted to Q's event (year, bout, plots) and each
# class's mean_cover is its summed cover over the event's sampled 1 m^2 units
# (attr(Q, "sampled_units"); a unit without the class contributes zero).
# n_units = that denominator; pct_quadrats_recorded = share of units where the
# class was recorded with positive cover.  Repeated rows of one class in one
# quadrat are averaged first (one value per quadrat-class).  layer = "canopy"
# for overstory (an overlapping layer, draw it apart), else "ground".
# Without `cover` (legacy call) every bundled row is used and the denominator
# is every plot x subplot x year x bout visit in the table.
# ---------------------------------------------------------------------------
GROUND_CANOPY_CLASSES <- c("overstory")

ground_summary <- function(ground, cover = NULL) {
  if (is.null(ground) || !nrow(ground)) return(NULL)
  year <- NULL
  if (!is.null(cover) && !is.data.frame(cover)) { year <- cover; cover <- NULL }
  g <- ground[!is.na(ground$otherVariables), , drop = FALSE]
  bout_txt <- function(x) if ("bout" %in% names(x)) ifelse(is.na(x$bout), "", as.character(x$bout)) else ""
  if (!is.null(cover)) {
    ev <- attr(cover, "event", exact = TRUE)
    if (is.null(ev)) return(NULL)
    g <- snapshot_event(g, ev)
    units <- attr(cover, "sampled_units", exact = TRUE) %||% sampled_units(cover, g)
    unit_key <- paste(units$plotID, units$subplotID, sep = "\r")
    gkey <- paste(g$plotID, g$subplotID, sep = "\r")
    # units always contain the event's ground quadrats when built by
    # cover_snapshot(ground = ); add them here when Q was built without ground
    unit_key <- unique(c(unit_key, gkey))
  } else {
    if (!is.null(year)) g <- g[g$year %in% year, , drop = FALSE]
    gkey <- paste(g$plotID, g$subplotID, g$year, bout_txt(g), sep = "\r")
    unit_key <- unique(gkey)
  }
  n_units <- length(unit_key)
  if (!nrow(g) || !n_units) return(NULL)
  val <- suppressWarnings(as.numeric(g$percentCover))
  ok <- is.finite(val)
  if (!any(ok)) return(NULL)
  per <- stats::aggregate(list(v = val[ok]),
                          by = list(cls = as.character(g$otherVariables[ok]), unit = gkey[ok]),
                          FUN = mean)
  cls <- sort(unique(per$cls), method = "radix")
  out <- data.frame(
    otherVariables = cls,
    mean_cover = vapply(cls, function(k) sum(per$v[per$cls == k]) / n_units, numeric(1)),
    n_units = as.integer(n_units),
    pct_quadrats_recorded = vapply(cls, function(k)
      100 * length(unique(per$unit[per$cls == k & per$v > 0])) / n_units, numeric(1)),
    layer = ifelse(cls %in% GROUND_CANOPY_CLASSES, "canopy", "ground"),
    stringsAsFactors = FALSE)
  out <- out[out$mean_cover > 0, , drop = FALSE]
  if (!nrow(out)) return(NULL)
  out <- out[order(out$layer == "canopy", -out$mean_cover, method = "radix"), , drop = FALSE]
  rownames(out) <- NULL
  attr(out, "cover_event") <- if (!is.null(cover)) attr(cover, "snapshot_label", exact = TRUE) else NA_character_
  out
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
  richness       = "species richness: the 400 m^2 whole-plot list of the grain event in plot/snapshot exports; mean 1 m^2 subplot richness per plot in annual series",
  n_native       = "native species count (400 m^2 plot list in snapshots; mean per 1 m^2 subplot in annual series)",
  n_introduced   = "introduced species count (400 m^2 plot list in snapshots; mean per 1 m^2 subplot in annual series)",
  mean_richness_1m2 = "mean 1 m^2 subplot species richness per plot (the annually surveyed grain)",
  plots_with_cover = "number of cover-event plots where the species had positive 1 m^2 cover",
  n_supported_plots = "plots in the cover event with sampled 1 m^2 units (the denominator of the site mean cover)",
  mean_cover     = "mean 1 m^2 cover over the cover event's sampled 1 m^2 units (structural zero; relative index): per species over supported plots in species tables, per class in ground-cover tables",
  n_units        = "number of sampled 1 m^2 units (plot x quadrat) in the cover event behind a ground-cover mean",
  pct_quadrats_recorded = "share of the cover event's sampled 1 m^2 units where the ground-cover class was recorded with positive cover",
  layer          = "ground (partitioning surface classes) or canopy (overstory, an overlapping layer)",
  n_sampling_units = "sampled 1 m^2 units (occurrence rows of any rank plus ground-cover rows) behind an annual value",
  selected_bouts = "bouts selected (one per plot-year) behind an annual value",
  flag           = "QC flag id (nativity_mismatch, cover_sum_gt_250, duplicate_record)",
  level          = "QC flag tier (warn / info); verify, not wrong",
  usda_nativity  = "USDA PLANTS lower-48 nativity of the accepted symbol",
  quadrat_cover_sum_pct = "summed plant percent cover of one 1 m^2 quadrat visit",
  n_records      = "number of bundled records sharing one sampling key (plot, quadrat, scale, year, bout, taxon)",
  covers         = "percent cover values of the records sharing one sampling key, separated by semicolons",
  grain_event    = "label of the grain site event (year, bout, plots; 1/10/100 m^2) behind presence and richness figures",
  cover_event    = "label of the cover site event (year, bout, plots; 1 m^2) behind cover-weighted figures",
  status         = "applicability or availability status of the row (e.g. cropland: no native reference applies)",
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
  builtAt        = "date the app bundle was actually built (unknown for the exact legacy family)",
  exportedAt     = "date this CSV export was generated",
  neonRelease    = "NEON data release pinned by the query (RELEASE-2026 for this family)",
  neonReleaseDoi = "DOI of the pinned NEON data release (https://doi.org/10.48443/...)",
  neonReleaseCitation = "CC BY 4.0 citation of the pinned NEON data release",
  dataThrough    = "latest observation year in the bundled records (not the query cutoff)",
  repositoryImportedAt = "date the exact legacy family was imported into this repository; not an upstream build or fetch date",
  sourceStart    = "first calendar month requested by a receipt-complete source query",
  sourceCutoff   = "closed end date requested by a receipt-complete source query",
  sourceReceiptId = "app-defined immutable identifier for the source query snapshot",
  sourceDigest   = "SHA-256 identity for the source family represented by this row",
  sourceReceiptBasis = "human-readable boundary explaining what the source receipt does and does not establish",
  sourceProvenanceClass = "receipt class: exact legacy partial, reviewed query snapshot, or partial context overlay",
  sourceBundleCommit = "full Git commit that imported the legacy family or built the reviewed query snapshot",
  queryPackage   = "NEON query package selected for a receipt-complete refresh",
  neonUtilitiesVersion = "neonUtilities version used for a receipt-complete source query",
  dpid           = "NEON data product id (DP1.10058.001)",
  fetchedAt      = "build provenance: date this bundle was fetched/built",
  bundleFile     = "runtime artifact path used by the app",
  bundleMd5      = "MD5 checksum of the exact runtime artifact used by the app",
  snapshotContract = "registered rule selecting the site's grain event (F, 1/10/100 m^2) and cover event (Q, 1 m^2)",
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
  plant_metric         = "the chosen annual plant signal (mean 1 m^2 richness / % introduced cover / total cover)",
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
                  "fruiting_pct", "mean_cover", "pct_quadrats_recorded",
                  "quadrat_cover_sum_pct")] <- "%"
  out[cols %in% c("total_cover", "intro_cover", "native_cover", "dominant_cover")] <-
    "relative cover index (summed percentage-point means)"
  out[cols %in% c("precip_mm")] <- "mm/month"
  out[cols %in% c("temp_c", "temp_min", "temp_max")] <- "degrees C"
  out[cols %in% c("lat", "lng", "referenceLatitude", "referenceLongitude")] <- "decimal degrees"
  out[cols %in% c("reference_production")] <- "air-dry lb/acre at normal precipitation"
  out[cols %in% c("mean_richness_1m2")] <- "species per m^2 quadrat"
  out[cols %in% c("richness", "n_native", "n_introduced", "n_unknown", "n_plots",
                  "plots_with_cover", "matched_years", "flowering_pct_n", "greenup_pct_n", "fruiting_pct_n",
                  "n_supported_plots", "n_units", "n_sampling_units", "n_records")] <- "count"
  out[cols %in% c("dataThrough")] <- "year"
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
  out[cols %in% c("builtAt", "neonRelease", "sourceStart", "sourceCutoff",
                  "sourceReceiptId", "queryPackage", "neonUtilitiesVersion")] <-
    "NA means this upstream/build receipt field was not preserved or does not apply; it must not be inferred from filesystem or deployment time."
  out[cols %in% c("repositoryImportedAt")] <-
    "NA means the artifact is not the registered legacy repository import."
  out[cols %in% c("sourceDigest", "sourceReceiptBasis", "sourceProvenanceClass",
                  "sourceBundleCommit")] <-
    "NA means the represented artifact has only partial provenance; see sourceReceiptBasis and the release documentation."
  out[cols %in% c("queryDate")] <-
    "NA means the reference query date was not captured, not that no query occurred."
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
  out[cols %in% c("neonReleaseDoi", "neonReleaseCitation")] <-
    "NA means no NEON release was pinned by the query; no DOI is invented."
  out[cols %in% c("mean_cover")] <-
    "NA means the species had no eligible cover-event 1 m^2 cover; a present species is never exported as 0."
  out[cols %in% c("usda_nativity", "quadrat_cover_sum_pct", "n_records", "covers")] <-
    "NA means the field does not apply to this QC flag row."
  unname(out)
}

.plant_col_estimand <- function(cols) {
  out <- rep("metadata or row-level source value; interpret in the context of the named export file.", length(cols))
  out[cols %in% c("plotID", "subplotID", "scale", "scale_m2", "year", "bout", "taxonID",
                  "scientificName", "taxonRank", "family", "nativeStatusCode", "nativity", "percentCover", "is_species")] <-
    "one bundled NEON taxon record; analysis_snapshot.csv restricts this to the site's labelled grain event (one year and bout, plots carrying 1/10/100 m^2)."
  out[cols %in% c("richness", "n_native", "n_introduced", "n_unknown", "total_cover", "intro_cover",
                  "native_cover", "dominant", "dominant_cover", "pct_introduced", "plotType", "nlcdClass",
                  "lat", "lng")] <-
    "one plot in the site's grain event (presence, richness) with cover from the labelled cover event; cover is a relative index over the cover event's sampled 1 m^2 units (occurrence rows of any rank plus ground-cover rows; absence counts as zero)."
  out[cols %in% c("mean_cover", "n_supported_plots")] <-
    "site mean over the cover event's supported plots: per-plot mean over sampled 1 m^2 units, absent plots count as zero; unrounded."
  out[cols %in% c("n_units", "pct_quadrats_recorded", "layer")] <-
    "abiotic ground cover over the cover event's sampled 1 m^2 units (structural zero); overstory is a canopy layer, not a ground class."
  out[cols %in% c("n_sampling_units", "selected_bouts")] <-
    "support of an annual value: one deterministic bout per plot-year over the recurrent plot panel."
  out[cols %in% c("flag", "level", "usda_nativity", "quadrat_cover_sum_pct", "n_records", "covers")] <-
    "one QC flag row: a record to verify, not a record known to be wrong."
  out[cols %in% c("mean_richness_1m2")] <-
    "mean over a plot's recorded 1 m^2 quadrats in one deterministic bout per plot-year."
  out[cols %in% c("grain_event", "cover_event", "status")] <-
    "label describing which site event or applicability rule produced the row; not an ecological estimand."
  out[cols %in% c("plots_with_cover")] <-
    "count of plots in the cover event; plots outside the event are not counted."
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
  out[cols %in% c("artifact", "builtAt", "exportedAt", "neonRelease", "neonReleaseDoi",
                  "neonReleaseCitation", "dataThrough",
                  "repositoryImportedAt", "sourceStart", "sourceCutoff",
                  "sourceReceiptId", "sourceDigest", "sourceReceiptBasis",
                  "sourceProvenanceClass", "sourceBundleCommit", "queryPackage",
                  "neonUtilitiesVersion", "dpid", "fetchedAt", "bundleFile",
                  "bundleMd5", "snapshotContract", "estimatorContract",
                  "sourceLicense")] <-
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
