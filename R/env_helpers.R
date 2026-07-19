# ===========================================================================
# env_helpers.R — Environment overlays + climate/phenology correlation.
#
# Adapts the NEON Small Mammal Tracker's MONTHLY env engine to the plant app's
# ANNUAL surveys. Plants are surveyed ~once a year at peak greenness, so the
# honest question is "does a SITE-YEAR's plant metric (richness, % introduced
# cover, total cover) track that year's CLIMATE/PHENOLOGY?" — an annual plant
# metric vs an annual-aggregated env window, NOT a month-to-month correlation.
#
# Because the series are SHORT (a handful of survey years) and we scan several
# drivers x a small year-lag window, a naive max|r| over that search would
# manufacture a large "significant"-looking r from noise. So the engine ships
# three honesty guards baked in (Quinn, 2026-06):
#   1. matched-n on screen, gated at MIN_ENV_YEARS overlapping years;
#   2. a CIRCULAR-SHIFT NULL that re-runs the FULL driver x lag scan while
#      preserving the response series' serial pattern;
#   3. r reported as Spearman (robust on short series) + a "best of N" + a
#      short-series / shared-trend caveat carried to the UI.
# Env data: data/env/<SITE>.rds (monthly per-site; precip, temp, phenology).
# ===========================================================================

ENV_DIR <- "data/env"
MIN_ENV_YEARS <- 5L          # overlap floor below which we show no correlation
FIRM_ENV_YEARS <- 7L         # below this -> flagged "exploratory"
ENV_LAGS <- 0:2              # driver leads response by 0, 1, or 2 YEARS (prior-year climate)

# The driver registry the UI + plots read. `agg` is how a year's monthly values
# collapse to one annual number; `lead` flags drivers expected to lead vegetation;
# `dig` = decimals in hover. Colours are driver IDENTITY hues (kept OFF the
# nativity green/clay and OFF the correlation-sign blue/vermillion).
ENV_LAYERS <- list(
  precip  = list(col = "precip_mm",     label = "Precipitation (annual)", unit = "mm/yr", agg = "sum",
                 color = "#2F7D9E", lead = TRUE,  dig = 0,
                 desc = "Total annual precipitation (sum of the monthly weighing-gauge product)."),
  temp    = list(col = "temp_c",        label = "Air temperature",   unit = "°C",    agg = "mean",
                 color = "#C56A3A", lead = FALSE, dig = 1,
                 desc = "Mean annual air temperature."),
  flower  = list(col = "flowering_pct", label = "Plants flowering",  unit = "% peak", agg = "max",
                 color = "#C2426E", lead = TRUE,  dig = 0,
                 desc = "Peak monthly share of monitored plants in flower that year."),
  greenup = list(col = "greenup_pct",   label = "Green-up",          unit = "% peak", agg = "max",
                 color = "#2E7D32", lead = TRUE,  dig = 0,
                 desc = "Peak monthly share leafing out (early-season green-up).")
  # NOTE: `fruiting_pct` is deliberately NOT registered as a driver. It is a max
  # of binned ORDINAL phenophase-intensity (not a measured seed crop) and is
  # sparse (e.g. 15/121 SRER monthly rows), so a max-over-search r off it would
  # be a misleading headline. Gated out of the driver x lag scan per expert review.
)

# the plant-side response metrics the user can correlate against the drivers
PLANT_METRICS <- list(
  pct_introduced = list(label = "% introduced cover", unit = "%",   dig = 1,
                        desc = "Mean plot-level introduced-cover share over the recurrent plot panel that year."),
  richness       = list(label = "Mean plot richness", unit = "spp/plot", dig = 1,
                        desc = "Mean plot-level richness over plots represented in every included year."),
  total_cover    = list(label = "Total relative cover", unit = "",  dig = 0,
                        desc = "Mean plot-level summed relative cover over the recurrent plot panel that year.")
)

# ---- load + shape --------------------------------------------------------
load_env <- function(site) {
  if (is.null(site) || !nzchar(site)) return(NULL)
  f <- file.path(ENV_DIR, paste0(site, ".rds"))
  if (!file.exists(f)) return(NULL)
  e <- tryCatch(readRDS(f), error = function(err) NULL)
  if (is.null(e) || !nrow(e)) return(NULL)
  e$date <- as.Date(e$date)
  e$year <- suppressWarnings(as.integer(substr(as.character(e$ym), 1, 4)))
  e
}

# overlay picker choices — only drivers that actually have data for this site
env_layer_choices <- function(env) {
  base <- c("None" = "none")
  if (is.null(env) || !nrow(env)) return(base)
  have <- vapply(names(ENV_LAYERS), function(k) {
    m <- ENV_LAYERS[[k]]
    col <- m$col
    col %in% names(env) && any(is.finite(suppressWarnings(as.numeric(env[[col]]))))
  }, logical(1))
  if (!any(have)) return(base)
  labs <- vapply(ENV_LAYERS[have], function(m) sprintf("%s (%s)", m$label, m$unit), character(1))
  c(base, stats::setNames(names(ENV_LAYERS)[have], labs))
}

# collapse a driver's monthly series to one value per calendar year
env_annual <- function(env, layer) {
  meta <- ENV_LAYERS[[layer]]
  if (is.null(meta) || is.null(env)) return(NULL)
  if (!(meta$col %in% names(env))) return(NULL)
  v <- suppressWarnings(as.numeric(env[[meta$col]]))
  d <- data.frame(year = env$year, v = v)
  d <- d[is.finite(d$v) & !is.na(d$year), , drop = FALSE]
  if (!nrow(d)) return(NULL)
  fn <- switch(meta$agg, sum = sum, mean = mean, max = max, mean)
  # Every annual statistic requires a complete 12-month value window.  A year
  # with missing precipitation must not be relabelled as unusually dry, and a
  # partial phenology/temperature year is not comparable with a full year.
  month_key <- if ("ym" %in% names(env)) as.character(env$ym) else
    if ("date" %in% names(env)) format(as.Date(env$date), "%Y-%m") else rep(NA_character_, nrow(env))
  d$month_key <- month_key[is.finite(v) & !is.na(env$year)]
  nmo <- stats::aggregate(month_key ~ year, data = d, FUN = function(x) length(unique(x[!is.na(x)])))
  agg <- stats::aggregate(v ~ year, data = d, FUN = fn)
  names(agg) <- c("year", "value"); names(nmo) <- c("year", "nmonths")
  agg <- merge(agg, nmo, by = "year")
  agg <- agg[agg$nmonths == 12L, , drop = FALSE]
  agg[order(agg$year), c("year", "value")]
}

# annual plant-metric series: one value per survey year for the chosen metric
plant_metric_series <- function(occ, metric = "richness") {
  out <- balanced_plant_metric_series(occ, metric)
  if (is.null(out) || nrow(out) < 2) return(NULL)
  out$value <- round(out$value, if (metric == "richness") 2 else 1)
  out
}

# ---- the correlation scan + permutation null -----------------------------
# Spearman correlation of an annual plant metric vs one driver, scanning the
# year-lag window; returns the strongest |r| with its lag and matched-n.
plant_env_scan <- function(ms, env, layer, lags = ENV_LAGS) {
  if (is.null(ms) || nrow(ms) < MIN_ENV_YEARS) return(NULL)
  meta0 <- ENV_LAYERS[[layer]]
  # Unregistered or explicitly descriptive-only layers cannot enter ranking.
  if (is.null(meta0) || identical(meta0$inference, FALSE)) return(NULL)
  # A registered driver may pin its own lag set; otherwise use the short common
  # lag registry and correct the full search with the null below.
  if (!is.null(meta0) && !is.null(meta0$lags)) lags <- as.integer(meta0$lags)
  ea <- env_annual(env, layer); if (is.null(ea) || !nrow(ea)) return(NULL)
  best <- list(lag = NA_integer_, r = NA_real_, n = 0L)
  for (L in lags) {
    e2 <- ea; e2$year <- e2$year + L                 # driver from year (Y-L) -> response year Y
    j <- merge(ms, e2, by = "year")                  # value.x = plant metric, value.y = driver
    if (nrow(j) >= MIN_ENV_YEARS &&
        stats::sd(j$value.x) > 0 && stats::sd(j$value.y) > 0) {
      r <- suppressWarnings(stats::cor(j$value.x, j$value.y, method = "spearman"))
      if (!is.na(r) && (is.na(best$r) || abs(r) > abs(best$r)))
        best <- list(lag = L, r = as.numeric(r), n = nrow(j))
    }
  }
  if (is.na(best$r)) return(NULL)
  meta <- ENV_LAYERS[[layer]]
  best$layer <- layer; best$label <- meta$label; best$unit <- meta$unit; best
}

# observed max|r| over ALL available drivers x lags (the thing the banner reports)
plant_env_all <- function(ms, env, lags = ENV_LAGS) {
  if (is.null(ms) || is.null(env)) return(NULL)
  rows <- lapply(names(ENV_LAYERS), function(k) {
    mk <- ENV_LAYERS[[k]]
    if (!(mk$col %in% names(env))) return(NULL)
    sc <- plant_env_scan(ms, env, k, lags); if (is.null(sc)) return(NULL)
    data.frame(layer = k, label = sc$label, color = ENV_LAYERS[[k]]$color,
               lag = sc$lag, r = sc$r, n = sc$n, stringsAsFactors = FALSE)
  })
  rows <- rows[!vapply(rows, is.null, logical(1))]
  if (!length(rows)) return(NULL)
  res <- do.call(rbind, rows)
  res[order(-abs(res$r)), ]
}

# Circular-shift null over the FULL driver x lag search.  Rotating the ordered
# plant series preserves its serial pattern while breaking calendar alignment;
# unrestricted row shuffling does not.  p = how often a shifted series beats the
# observed best.  With short annual records this is intentionally conservative
# and may have only n-1 distinct null alignments.
# `only` restricts the search to a single driver (when the user has picked one),
# so the reported p is corrected for that driver's lag search, not the whole panel.
plant_env_perm <- function(ms, env, lags = ENV_LAGS, B = 999, seed = 1L, only = NULL) {
  ms <- ms[order(ms$year), , drop = FALSE]
  all <- plant_env_all(ms, env, lags); if (is.null(all)) return(NULL)
  if (!is.null(only)) { all <- all[all$layer %in% only, , drop = FALSE]; if (!nrow(all)) return(NULL) }
  obs <- max(abs(all$r))
  layers <- unique(all$layer)
  best_abs <- function(series) {
    rr <- vapply(layers, function(k) {
      s <- plant_env_scan(series, env, k, lags); if (is.null(s)) NA_real_ else abs(s$r)
    }, numeric(1))
    if (all(is.na(rr))) NA_real_ else max(rr, na.rm = TRUE)
  }
  shifts <- seq_len(nrow(ms) - 1L)
  if (length(shifts) > B) { set.seed(seed); shifts <- sort(sample(shifts, B)) }
  null <- numeric(length(shifts)); shuf <- ms
  for (b in seq_along(shifts)) {
    k <- shifts[b]
    shuf$value <- c(tail(ms$value, k), head(ms$value, -k))
    null[b] <- best_abs(shuf)
  }
  null <- null[is.finite(null)]
  p <- (1 + sum(null >= obs)) / (length(null) + 1)
  list(obs = round(obs, 2), p = round(p, 3), B = length(null),
       top = all[1, , drop = FALSE], all = all, n = all$n[1])
}

# matched (year, plant-metric, driver) points for the response scatter
plant_env_points <- function(ms, env, layer, lag = 0L) {
  ea <- env_annual(env, layer); if (is.null(ms) || is.null(ea)) return(NULL)
  e2 <- ea; e2$year <- e2$year + as.integer(lag)
  j <- merge(ms, e2, by = "year")
  if (nrow(j) < 3) return(NULL)
  names(j)[names(j) == "value.x"] <- "metric"; names(j)[names(j) == "value.y"] <- "driver"
  j[order(j$year), c("year", "metric", "driver")]
}

# ---- CVD-safe colour for a (driver, sign) pair (ported + plant poles) -----
# identity = driver hue family; sign = which pole; magnitude only fades loudness.
# Only ever used where sign is ALSO encoded geometrically (slope / side of 0).
EC_CORR_POLES <- list(
  precip  = list(pos = c("#1f6fb2", "#5aa9e6"), neg = c("#b07a35", "#d8a85a")),
  temp    = list(pos = c("#C56A3A", "#e08a52"), neg = c("#2f7fb5", "#6cc4ec")),
  flower  = list(pos = c("#C2426E", "#e06a95"), neg = c("#7a8a99", "#9aa7b5")),
  greenup = list(pos = c("#2b8a3e", "#69db7c"), neg = c("#9c6644", "#c08457"))
  # fruit poles dropped with the fruiting_pct driver (see ENV_LAYERS note above)
)
blend_hex <- function(a, b, w) {
  ca <- grDevices::col2rgb(a); cb <- grDevices::col2rgb(b)
  m  <- round(ca * (1 - w) + cb * w)
  grDevices::rgb(m[1], m[2], m[3], maxColorValue = 255)
}
ec_corr_color <- function(layer, r, dark = FALSE) {
  if (length(r) != 1 || is.na(r)) return("#8a97a8")
  s <- abs(r); if (s < 0.2) return("#8a97a8")
  pole <- EC_CORR_POLES[[layer]]
  base <- if (is.null(pole)) (ENV_LAYERS[[layer]]$color %||% "#8a97a8")
          else (if (r >= 0) pole$pos else pole$neg)[[if (dark) 2L else 1L]]
  surf <- if (dark) "#18271E" else "#ffffff"
  w <- if (s >= 0.6) 0 else if (s >= 0.35) 0.15 else 0.40
  blend_hex(base, surf, w)
}

# Verdict word + tone for the environment banner. Circular-shift p gates every
# non-null pattern, and even the strongest supported result remains explicitly
# exploratory because this is a short observational site series.
env_verdict <- function(r, p, n) {
  if (is.na(r) || is.na(p)) return(list(word = "no clear link", tone = "weak", flag = TRUE))
  s <- abs(r); firm <- n >= FIRM_ENV_YEARS
  # Correlations remain exploratory context: no causal/confirmatory language is
  # emitted from these short observational site series.
  if (s >= 0.6 && p < 0.10 && firm)      list(word = "exploratory association", tone = "mod", flag = TRUE)
  else if (s >= 0.45 && p < 0.25)        list(word = "possible pattern",        tone = "mod", flag = TRUE)
  else                                   list(word = "no clear pattern",         tone = "weak", flag = TRUE)
}
