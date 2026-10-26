# ===========================================================================
# NEON Plant Diversity Explorer, one-page site report PDF (base graphics).
# Streamed by output$reportPdf. No LaTeX / no Chrome, grDevices::cairo_pdf +
# base plotting only, Herbarium-themed. Every section is defensive (draws ", "
# rather than erroring) so it can never break the downloadHandler.
# ===========================================================================

build_diversity_report <- function(file, occ, ground = NULL, label = "site", expected = NULL,
                                   release = NULL, doi = NULL) {
  if (is.null(release) && exists("PLANT_SOURCE_STATUS")) release <- PLANT_SOURCE_STATUS$neon_release
  release <- if (is.null(release) || !length(release) || is.na(release[1]) || !nzchar(release[1])) NA_character_ else as.character(release[1])
  if (is.null(doi) && !is.na(release) && exists("plant_release_doi", mode = "function")) doi <- plant_release_doi(release)
  doi <- if (is.null(doi) || !length(doi) || is.na(doi[1]) || !nzchar(doi[1])) NA_character_ else as.character(doi[1])
  P <- list(pine = "#1F5C3D", pine2 = "#2E7D52", terra = "#C56A3A", gold = "#C99A2E",
            green = "#2E7D32", ink = "#232B22", muted = "#6B7468", paper = "#ffffff",
            line = "#E2DCCB", intro = "#B85C38")
  ok <- function(expr) tryCatch(expr, error = function(e) NULL)
  # plant-snapshot-v2: grain figures (species, plots, species-area) from the
  # latest full-grain site event F; cover figures (top species, introduced cover,
  # Chao2) from the latest complete 1 m² bout Q. Never fall back to raw occ.
  ss <- ok(site_snapshot(occ, ground = ground))
  grain_tbl <- ss$grain
  cover_tbl <- ss$cover
  has_rows <- function(d) !is.null(d) && is.data.frame(d) && nrow(d) > 0
  ev_lab <- function(kind, none) {
    e <- ss$events
    i <- if (is.data.frame(e) && nrow(e)) which(as.character(e$kind) == kind) else integer(0)
    if (length(i) && is.finite(suppressWarnings(as.numeric(e$year[i[1]]))) &&
        !is.na(e$label[i[1]]) && nzchar(e$label[i[1]])) as.character(e$label[i[1]]) else none
  }
  f_label <- ev_lab("grain", "no full-grain survey in the bundled record")
  q_label <- ev_lab("cover", "no 1 m² cover bout in the bundled record")

  grDevices::cairo_pdf(file, width = 8.5, height = 11, bg = P$paper)
  on.exit(grDevices::dev.off(), add = TRUE)
  old <- graphics::par(no.readonly = TRUE); on.exit(graphics::par(old), add = TRUE)
  graphics::par(family = "", mar = c(0, 0, 0, 0), oma = c(0, 0, 0, 0))
  graphics::plot.new(); graphics::plot.window(xlim = c(0, 100), ylim = c(0, 100))

  # ---- header band -------------------------------------------------------
  graphics::rect(0, 92, 100, 100, col = P$pine, border = NA)
  graphics::text(3, 90.6, paste0("Richness and species-area: ", f_label), col = P$ink, cex = 0.62, adj = 0)
  graphics::text(3, 89.0, paste0("Cover, Chao2 and top species: ", q_label), col = P$ink, cex = 0.62, adj = 0)
  graphics::text(3, 96.4, "NEON Plant Diversity · Site Report", col = "#ffffff", cex = 1.5, font = 2, adj = 0)
  graphics::text(3, 93.6, label, col = P$gold, cex = 1.0, font = 2, adj = 0)
  graphics::text(97, 93.6, format(Sys.Date(), "%Y-%m-%d  ·  DP1.10058.001"), col = "#dfeee4", cex = 0.7, adj = 1)

  sp   <- if (has_rows(grain_tbl)) ok(species_summary(grain_tbl, cover_tbl)) else NULL
  pl   <- if (has_rows(grain_tbl)) ok(plot_summary(grain_tbl, cover_tbl)) else NULL
  cv   <- if (has_rows(cover_tbl)) ok(chao2(cover_tbl)) else NULL
  sa   <- if (has_rows(grain_tbl)) ok(species_area_site(grain_tbl)) else NULL
  intro <- if (has_rows(cover_tbl)) ok(site_invasion(cover_tbl)) else NULL

  # ---- hero strip --------------------------------------------------------
  yb <- 81
  chip <- function(x, v, l) { graphics::rect(x, yb, x + 22, yb + 6.5, col = "#eef4ea", border = P$line)
    graphics::text(x + 11, yb + 4.4, v, col = P$pine, cex = 1.25, font = 2)
    graphics::text(x + 11, yb + 1.4, l, col = P$muted, cex = 0.62) }
  n_sp <- if (!is.null(sp)) nrow(sp) else NA
  # same population as the app hero and site_index: every plot in the grain event
  n_plots <- if (has_rows(grain_tbl)) dplyr::n_distinct(grain_tbl$plotID) else NA
  chip(3,  if (is.finite(n_sp)) format(n_sp, big.mark = ",") else "n/a", "SPECIES (FULL-GRAIN SURVEY)")
  chip(27, if (!is.null(intro) && is.finite(intro)) paste0(intro, "%") else "n/a", "INTRODUCED COVER")
  chip(51, if (!is.null(cv) && is.finite(cv$chao2)) paste0(cv$chao2) else "n/a",
       if (!is.null(cv)) sprintf("CHAO2 (1 m², %d SEEN)", cv$S_obs) else "CHAO2 (1 m²)")
  chip(75, if (is.finite(n_plots)) format(n_plots, big.mark = ",") else "n/a", "PLOTS SAMPLED")

  # ---- composition: top species by mean cover ----------------------------
  graphics::text(3, 78, "Most abundant plants · by mean 1 m² cover", col = P$pine2, cex = 1.0, font = 2, adj = 0)
  if (!is.null(sp) && nrow(sp)) {
    topn <- sp[is.finite(sp$mean_cover) & sp$mean_cover > 0, ]
    topn <- utils::head(topn[order(-topn$mean_cover), ], 8)
    if (nrow(topn)) { topn <- topn[nrow(topn):1, ]
      x0 <- 38; x1 <- 92; ytop <- 76; ybot <- 56; n <- nrow(topn); mx <- max(topn$mean_cover, na.rm = TRUE)
      yc <- seq(ybot, ytop, length.out = n); bh <- (ytop - ybot) / n * 0.62
      for (i in seq_len(n)) {
        w <- if (is.finite(mx) && mx > 0) (x1 - x0) * topn$mean_cover[i] / mx else 0
        col <- if (identical(topn$nativity[i], "Introduced")) P$intro else P$pine
        graphics::rect(x0, yc[i] - bh / 2, x0 + w, yc[i] + bh / 2, col = col, border = NA)
        nm <- topn$scientificName[i]; if (is.na(nm)) nm <- "unidentified"
        graphics::text(x0 - 1.5, yc[i], nm, col = P$ink, cex = 0.6, adj = 1, font = 3)
        graphics::text(x0 + w + 1, yc[i], sprintf("%.1f", topn$mean_cover[i]), col = P$muted, cex = 0.55, adj = 0)
      }
      graphics::text(92, 55, "green = native · clay = introduced", col = P$muted, cex = 0.5, adj = 1)
    } else graphics::text(50, 67, "n/a", col = P$muted)
  } else graphics::text(50, 67, "n/a", col = P$muted)

  # ---- species-area curve (nested quadrats) ------------------------------
  graphics::text(3, 52, "Species–area curve (nested quadrats, 1 → 400 m², full-grain survey)", col = P$pine2, cex = 1.0, font = 2, adj = 0)
  if (!is.null(sa) && nrow(sa)) {
    x0 <- 10; x1 <- 92; ybot <- 32; ytop <- 49
    ax <- log10(sa$area_m2); axr <- range(ax); mr <- max(sa$richness, na.rm = TRUE)
    px <- function(a) x0 + (x1 - x0) * (log10(a) - axr[1]) / max(1e-9, diff(axr))
    py <- function(r) ybot + (ytop - ybot) * r / max(1, mr)
    graphics::lines(px(sa$area_m2), py(sa$richness), col = P$pine, lwd = 2)
    graphics::points(px(sa$area_m2), py(sa$richness), pch = 19, col = P$pine, cex = 0.9)
    for (i in seq_len(nrow(sa))) {
      graphics::text(px(sa$area_m2[i]), ybot - 1.6, paste0(sa$area_m2[i], "m²"), col = P$muted, cex = 0.5)
      graphics::text(px(sa$area_m2[i]), py(sa$richness[i]) + 1.4, round(sa$richness[i]), col = P$ink, cex = 0.55)
    }
  } else graphics::text(50, 40, if (has_rows(grain_tbl)) "n/a" else "No full-grain survey in the bundled record", col = P$muted)

  # ---- completeness (Expected vs Observed), if a reference list exists ----
  graphics::text(3, 28, "Observed vs a local NRCS ecological-site reference", col = P$pine2, cex = 1.0, font = 2, adj = 0)
  evo <- if (!is.null(expected)) ok(expected_vs_observed(occ, expected, if (exists("PLANT_AUTHORITY")) PLANT_AUTHORITY else NULL)) else NULL
  if (!is.null(evo)) {
    if (isFALSE(evo$applicability$applies) || !is.finite(evo$overlap_pct))
      graphics::text(3, 24.5, sprintf("Reference flora detected: n/a  (%s)", evo$applicability$status %||% "no detected-share available"), col = P$ink, cex = 0.72, adj = 0)
    else
      graphics::text(3, 24.5, sprintf("Reference flora detected: %.0f%%  (%d of %d species)", evo$overlap_pct, evo$n_overlap, evo$n_ref), col = P$ink, cex = 0.72, adj = 0)
    dom <- if (isFALSE(evo$applicability$applies)) "reference dominants: not scored (no native reference applies)"
      else if (evo$dom_total > 0) sprintf("%d of %d reference dominants observed", evo$dom_obs, evo$dom_total)
      else "dominants not production-ranked for this ecological site"
    graphics::text(3, 22.4, dom, col = P$ink, cex = 0.72, adj = 0)
    graphics::text(3, 20.3, sprintf("%d observed but not in the reference list (%d introduced · %d native), the review lane.", nrow(evo$C), evo$n_review_intro, evo$n_review_native), col = P$muted, cex = 0.62, adj = 0)
    graphics::text(3, 17.6, sprintf("Reference community: %s (%s) · single site-coordinate soil unit.", evo$ecosite_name %||% "n/a", evo$ecoclassid %||% "n/a"), col = P$muted, cex = 0.56, adj = 0)
  } else graphics::text(3, 23, "No NRCS reference list bundled for this site.", col = P$muted, cex = 0.7, adj = 0)

  # ---- honesty footer ----------------------------------------------------
  graphics::abline(h = 11, col = P$line)
  graphics::text(3, 9.6, "Richness and species-area describe the latest full-grain survey (1, 10, 100 m² subplots); cover, Chao2 and the top-species bars describe", col = P$muted, cex = 0.55, adj = 0)
  graphics::text(3, 8.2, "the latest 1 m² bout; both are named above. Chao2 is a bias-corrected lower bound from 1 m² quadrat species only.", col = P$muted, cex = 0.55, adj = 0)
  graphics::text(3, 6.8, "Cover is an ocular estimate and vegetation layers overlap, so site-summed cover is a relative index, not a share of ground.", col = P$muted, cex = 0.55, adj = 0)
  graphics::text(3, 5.4, "Reference-but-absent species reflect completeness against one local soil unit, not site-wide truth or error.", col = P$muted, cex = 0.55, adj = 0)
  graphics::text(3, 3.6, if (is.na(release))
      "Data: NEON Plant presence and percent cover (DP1.10058.001), NEON release n/a (query snapshot) · CC BY 4.0"
    else sprintf("Data: NEON Plant presence and percent cover (DP1.10058.001), %s%s · CC BY 4.0",
                 release, if (is.na(doi)) "" else paste0(" · ", doi)),
    col = P$muted, cex = 0.55, adj = 0)
  graphics::text(3, 2.0, "Built by Desert Data Labs · unofficial · not affiliated with NEON, Battelle, or the NSF · desertdatalabs.com", col = P$muted, cex = 0.55, adj = 0)
  invisible(TRUE)
}
