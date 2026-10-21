#!/usr/bin/env Rscript

# Read-only, no network.  For every site (or the site codes given as arguments)
# print one row comparing the RETIRED v1 snapshot (per-plot latest year/bout,
# species-area with the old corner rule) against plant-snapshot-v2 (grain event
# F for richness / species-area, cover event Q for Chao2 / S_obs / % introduced),
# then the per-bout 1 m^2 plot counts of each site's Q year.
#   Rscript --vanilla scripts/report_snapshot_events.R [SITE ...]

suppressWarnings(suppressMessages(library(dplyr)))
source("R/plant_helpers.R")

args <- toupper(commandArgs(trailingOnly = TRUE))
all_sites <- sort(sub("[.]rds$", "", list.files("data/sites", pattern = "[.]rds$")))
sites <- if (length(args)) intersect(args, all_sites) else all_sites
if (length(args) && length(setdiff(args, all_sites)))
  stop(sprintf("unknown site(s): %s", paste(setdiff(args, all_sites), collapse = ",")), call. = FALSE)

# The species-area rule the app displayed before contract v2: 10/100 m^2 = mean
# over corners of the union of rows at scale <= 10 / <= 100 (so a corner's two
# 10 m^2 subplots merged, and 1 m^2-only plots fed every grain).
old_species_area_site <- function(occ) {
  d <- species_level_only(occ)
  if (is.null(d) || !nrow(d)) return(rep(NA_real_, 4))
  d$corner <- subplot_corner(d$subplotID)
  curves <- lapply(split(d, d$plotID), function(p) {
    r1 <- p[p$scale == 1, ]
    r1m <- if (nrow(r1)) mean(tapply(r1$scientificName, r1$subplotID, function(x) length(unique(x)))) else NA_real_
    pc <- function(mx) { s <- p[p$scale <= mx, ]; if (!nrow(s)) NA_real_ else
      mean(tapply(s$scientificName, s$corner, function(x) length(unique(x)))) }
    c(r1m, pc(10), pc(100), length(unique(p$scientificName)))
  })
  m <- do.call(rbind, curves)
  apply(m, 2, function(x) if (any(is.finite(x))) mean(x[is.finite(x)]) else NA_real_)
}
new_sa <- function(grain) {
  sa <- species_area_site(grain)
  if (is.null(sa)) return(rep(NA_real_, 4))
  sa$richness[match(c(1, 10, 100, 400), sa$area_m2)]
}
fmt <- function(x, d = 1) ifelse(is.finite(x), formatC(x, format = "f", digits = d), "NA")
sa_txt <- function(v) paste(fmt(v), collapse = "/")
chao_parts <- function(d) { ch <- chao2(d); if (is.null(ch)) c(NA, NA) else c(ch$chao2, ch$S_obs) }
n_species <- function(d) length(unique(species_level_only(d)$scientificName))

rows <- list(); bouts <- list()
for (site in sites) {
  occ <- readRDS(file.path("data", "sites", paste0(site, ".rds")))$occ
  old <- legacy_plot_latest_snapshot(occ)
  old_years <- sort(unique(old$year))
  old_c <- chao_parts(old)
  ss <- site_snapshot(occ)
  g <- ss$grain; q <- ss$cover
  new_c <- chao_parts(q)
  rows[[site]] <- data.frame(
    site = site,
    old_years = if (length(old_years) > 3) sprintf("%d-%d", min(old_years), max(old_years))
                else paste(old_years, collapse = ","),
    old_plots = length(unique(old$plotID)),
    old_species = n_species(old),
    old_SA_1_10_100_400 = sa_txt(old_species_area_site(old)),
    old_chao2 = fmt(old_c[1]), old_Sobs = fmt(old_c[2], 0),
    old_pct_intro = fmt(site_invasion(old)),
    F_event = ss$events$label[ss$events$kind == "grain"],
    F_plots = length(unique(g$plotID)),
    F_species = n_species(g),
    F_SA_1_10_100_400 = sa_txt(new_sa(g)),
    Q_event = ss$events$label[ss$events$kind == "cover"],
    Q_chao2 = fmt(new_c[1]), Q_Sobs = fmt(new_c[2], 0),
    Q_pct_intro = fmt(site_invasion(q)),
    F_excluded_plots = sum(!attr(g, "snapshot_support")$in_snapshot),
    stringsAsFactors = FALSE)
  qev <- attr(q, "event", exact = TRUE)
  if (!is.null(qev)) {
    ev <- site_events(occ); ev <- ev[ev$year == qev$year, , drop = FALSE]
    bouts[[site]] <- sprintf("%s Q %s: %s", site, format(qev$year),
      paste(sprintf("bout %s = %d plots with 1 m2", ifelse(is.na(ev$bout), "NA", ev$bout),
                    ev$n_plots_1m), collapse = "; "))
  }
}
out <- do.call(rbind, rows); rownames(out) <- NULL
old_opt <- options(width = 10000); on.exit(options(old_opt), add = TRUE)
cat("Plant Diversity snapshot events: retired v1 (per-plot latest year) vs plant-snapshot-v2 (F grain / Q cover)\n")
cat("old_* = per-plot latest year/bout, old corner species-area; F_* = grain event; Q_* = cover event (Chao2, S_obs, % introduced on Q)\n\n")
print(out, row.names = FALSE, right = FALSE)
cat("\nPer-bout 1 m2 plot counts in each site's cover-event year:\n")
cat(paste(unlist(bouts), collapse = "\n"), "\n")
