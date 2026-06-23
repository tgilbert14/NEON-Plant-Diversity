# ===========================================================================
# NEON Plant Diversity Explorer — one-page site report PDF (base graphics).
# Streamed by output$reportPdf. No LaTeX / no Chrome — grDevices::cairo_pdf +
# base plotting only, Herbarium-themed. Every section is defensive (draws "—"
# rather than erroring) so it can never break the downloadHandler.
# ===========================================================================

build_diversity_report <- function(file, occ, ground = NULL, label = "site", expected = NULL) {
  P <- list(pine = "#1F5C3D", pine2 = "#2E7D52", terra = "#C56A3A", gold = "#C99A2E",
            green = "#2E7D32", ink = "#232B22", muted = "#6B7468", paper = "#ffffff",
            line = "#E2DCCB", intro = "#B85C38")
  ok <- function(expr) tryCatch(expr, error = function(e) NULL)
  snap <- ok(latest_snapshot(occ)) %||% occ

  grDevices::cairo_pdf(file, width = 8.5, height = 11, bg = P$paper)
  on.exit(grDevices::dev.off(), add = TRUE)
  old <- graphics::par(no.readonly = TRUE); on.exit(graphics::par(old), add = TRUE)
  graphics::par(family = "", mar = c(0, 0, 0, 0), oma = c(0, 0, 0, 0))
  graphics::plot.new(); graphics::plot.window(xlim = c(0, 100), ylim = c(0, 100))

  # ---- header band -------------------------------------------------------
  graphics::rect(0, 92, 100, 100, col = P$pine, border = NA)
  graphics::text(3, 96.4, "NEON Plant Diversity · Site Report", col = "#ffffff", cex = 1.5, font = 2, adj = 0)
  graphics::text(3, 93.6, label, col = P$gold, cex = 1.0, font = 2, adj = 0)
  graphics::text(97, 93.6, format(Sys.Date(), "%Y-%m-%d  ·  DP1.10058.001"), col = "#dfeee4", cex = 0.7, adj = 1)

  sp   <- ok(species_summary(snap))
  pl   <- ok(plot_summary(snap))
  cv   <- ok(chao2(occ))
  sa   <- ok(species_area_site(occ))
  intro <- ok(site_invasion(snap))

  # ---- hero strip --------------------------------------------------------
  yb <- 84
  chip <- function(x, v, l) { graphics::rect(x, yb, x + 22, yb + 6.5, col = "#eef4ea", border = P$line)
    graphics::text(x + 11, yb + 4.4, v, col = P$pine, cex = 1.25, font = 2)
    graphics::text(x + 11, yb + 1.4, l, col = P$muted, cex = 0.62) }
  n_sp <- if (!is.null(sp)) nrow(sp) else NA
  n_plots <- if (!is.null(pl)) nrow(pl) else NA
  chip(3,  if (is.finite(n_sp)) format(n_sp, big.mark = ",") else "—", "SPECIES (snapshot)")
  chip(27, if (!is.null(intro) && is.finite(intro)) paste0(intro, "%") else "—", "INTRODUCED COVER")
  chip(51, if (!is.null(cv) && is.finite(cv$chao2)) paste0(cv$chao2) else "—", "CHAO2 (est. total)")
  chip(75, if (is.finite(n_plots)) format(n_plots, big.mark = ",") else "—", "PLOTS SAMPLED")

  # ---- composition: top species by mean cover ----------------------------
  graphics::text(3, 80, "Most abundant plants · by mean cover", col = P$pine2, cex = 1.0, font = 2, adj = 0)
  if (!is.null(sp) && nrow(sp)) {
    topn <- sp[is.finite(sp$mean_cover) & sp$mean_cover > 0, ]
    topn <- utils::head(topn[order(-topn$mean_cover), ], 8)
    if (nrow(topn)) { topn <- topn[nrow(topn):1, ]
      x0 <- 38; x1 <- 92; ytop <- 78; ybot <- 56; n <- nrow(topn); mx <- max(topn$mean_cover, na.rm = TRUE)
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
    } else graphics::text(50, 67, "—", col = P$muted)
  } else graphics::text(50, 67, "—", col = P$muted)

  # ---- species-area curve (nested quadrats) ------------------------------
  graphics::text(3, 52, "Species–area curve (nested quadrats, 1 → 400 m²)", col = P$pine2, cex = 1.0, font = 2, adj = 0)
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
  } else graphics::text(50, 40, "—", col = P$muted)

  # ---- completeness (Expected vs Observed), if a reference list exists ----
  graphics::text(3, 28, "Expected vs observed (NRCS reference flora)", col = P$pine2, cex = 1.0, font = 2, adj = 0)
  evo <- if (!is.null(expected)) ok(expected_vs_observed(occ, expected, if (exists("PLANT_AUTHORITY")) PLANT_AUTHORITY else NULL)) else NULL
  if (!is.null(evo)) {
    graphics::text(3, 24.5, sprintf("Reference flora detected: %.0f%%  (%d of %d species)", evo$overlap_pct, evo$n_overlap, evo$n_ref), col = P$ink, cex = 0.72, adj = 0)
    dom <- if (evo$dom_total > 0) sprintf("%d of %d reference dominants observed", evo$dom_obs, evo$dom_total) else "dominants not production-ranked for this ecological site"
    graphics::text(3, 22.4, dom, col = P$ink, cex = 0.72, adj = 0)
    graphics::text(3, 20.3, sprintf("%d observed but not in the reference list (%d introduced · %d native), the review lane.", nrow(evo$C), evo$n_review_intro, evo$n_review_native), col = P$muted, cex = 0.62, adj = 0)
    if (isTRUE(evo$state_covered) && (evo$n_regional %||% 0) > 0)
      graphics::text(3, 19.0, sprintf("+ %d native(s) on the %s state flora but not this soil unit (regional associate, set aside).", evo$n_regional, evo$state %||% ""), col = P$muted, cex = 0.58, adj = 0)
    graphics::text(3, 17.6, sprintf("Reference community: %s (%s).", evo$ecosite_name %||% "—", evo$ecoclassid %||% "—"), col = P$muted, cex = 0.6, adj = 0)
  } else graphics::text(3, 23, "No NRCS reference list bundled for this site.", col = P$muted, cex = 0.7, adj = 0)

  # ---- honesty footer ----------------------------------------------------
  graphics::abline(h = 11, col = P$line)
  graphics::text(3, 9.4, "Numbers describe the most-recent survey of each plot (one survey per plot, species level). Cover is an ocular estimate and", col = P$muted, cex = 0.55, adj = 0)
  graphics::text(3, 7.8, "vegetation layers overlap, so site-summed cover is a relative index, not a share of ground. Chao2 is a bias-corrected minimum.", col = P$muted, cex = 0.55, adj = 0)
  graphics::text(3, 6.0, "Expected-but-absent reference species reflect completeness (NEON samples ~400 m²/plot), not error.", col = P$muted, cex = 0.55, adj = 0)
  graphics::text(3, 2.0, "Built by Desert Data Labs · unofficial · not affiliated with NEON, Battelle, or the NSF · desertdatalabs.com", col = P$muted, cex = 0.55, adj = 0)
  invisible(TRUE)
}
