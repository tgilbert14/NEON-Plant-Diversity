#----------------------------------------------------------------------
# make_og_image.R — draws docs/og-image.png (1200x630), the social card for
# the landing page. Self-contained base-R graphics in the Desert Data Labs
# "Herbarium" palette (deep leaf-green + ochre + clay on cream paper), with a
# faint nested-quadrat watermark (concentric 1->10->100->400 m^2 squares) for
# texture — the plant counterpart to the mammal app's paw-print card.
#   "C:\Program Files\R\R-4.3.1\bin\Rscript.exe" scripts/make_og_image.R
#----------------------------------------------------------------------
ROOT <- getwd()
out  <- file.path(ROOT, "docs", "og-image.png")
dir.create(dirname(out), showWarnings = FALSE, recursive = TRUE)

# Herbarium palette
leaf   <- "#1F5C3D"   # primary deep leaf-green
leaf2  <- "#2E7D52"   # primary2
clay   <- "#C56A3A"   # accent clay
ochre  <- "#C99A2E"   # highlight ochre / gold
cream  <- "#F5F1E6"   # cream paper
ink    <- "#232B22"   # near-black ink

png(out, width = 1200, height = 630, res = 144)
op <- par(mar = c(0, 0, 0, 0), bg = leaf); on.exit({ par(op); dev.off() })
plot.new(); plot.window(xlim = c(0, 1200), ylim = c(0, 630), xaxs = "i", yaxs = "i")

# background: deep leaf-green field with a soft glow from the upper-left
rect(0, 0, 1200, 630, col = leaf, border = NA)
for (i in seq(0, 1, length.out = 60)) {
  col <- grDevices::adjustcolor(leaf2, alpha.f = 0.016)
  symbols(150, 560, circles = 30 + i * 820, inches = FALSE, add = TRUE, bg = col, fg = NA)
}

# nested-quadrat motif: concentric 1->10->100->400 m^2 squares as a faint
# watermark — the app's species-area sampling design, drawn as squares whose
# SIDES scale as sqrt(area) (1, ~3.16, 10, 20 -> normalized to a base unit).
quadrat <- function(cx, cy, base, col, lwd = 2) {
  # side lengths proportional to sqrt(area): sqrt(1,10,100,400) = 1, 3.16, 10, 20
  sides <- c(1, 3.162, 10, 20)
  sides <- sides / max(sides)            # normalize so outer square = base
  for (s in sides) {
    half <- base * s / 2
    rect(cx - half, cy - half, cx + half, cy + half, border = col, lwd = lwd)
  }
}
set.seed(58)
for (k in 1:7) {
  quadrat(runif(1, 120, 1090), runif(1, 90, 540),
          base = runif(1, 60, 150),
          col  = grDevices::adjustcolor("white", alpha.f = runif(1, .035, .065)),
          lwd  = 2)
}

# a tiny leaf glyph used as the title accent (an almond leaf-blade + midrib)
leaf_glyph <- function(x, y, s, col) {
  tt  <- seq(0, 2 * pi, length.out = 80)
  # lens/almond shape via two arcs: width 0.42*s, length s, tilted slightly
  ang <- 22 * pi / 180; ca <- cos(ang); sa <- sin(ang)
  bx  <- (s / 2) * cos(tt)
  by  <- (s * 0.42 / 2) * sin(tt)
  # taper the lens into a leaf by pinching the ends (multiply by |cos|)
  px  <- bx
  py  <- by * (1 - 0.55 * (1 - cos(tt * 2)) / 2)
  xr  <- x + px * ca - py * sa
  yr  <- y + px * sa + py * ca
  polygon(xr, yr, col = col, border = NA)
  # midrib
  lines(c(x - (s / 2) * ca, x + (s / 2) * ca),
        c(y - (s / 2) * sa, y + (s / 2) * sa),
        col = grDevices::adjustcolor(leaf, .55), lwd = 2)
}

# badge
text(70, 556, "NEON · PLANT PRESENCE & % COVER · DP1.10058.001",
     col = grDevices::adjustcolor(ochre, .98), cex = .9, font = 2, adj = 0)

# title
text(68, 472, "NEON Plant Diversity", col = cream, cex = 3.5, font = 2, adj = 0)
text(68, 396, "Explorer",             col = cream, cex = 3.5, font = 2, adj = 0)
# a small ochre leaf accent, clear to the right of the "Explorer" wordmark
leaf_glyph(388, 402, 70, grDevices::adjustcolor(ochre, .95))

# subtitle
text(70, 322, "Explore plant communities across 46 NEON sites — cover composition,",
     col = grDevices::adjustcolor(cream, .93), cex = 1.12, adj = 0)
text(70, 292, "diversity, and where introduced plants are gaining ground, on real data.",
     col = grDevices::adjustcolor(cream, .93), cex = 1.12, adj = 0)

# stat chips
chips <- list(c("46", "field sites"), c("23", "states"),
              c("1→400 m²", "nested"), c("instant", "no API waits"))
x0 <- 70; gap <- 14; w <- 250; h <- 96; y1 <- 64
chipfill <- grDevices::adjustcolor(cream, .10)
for (i in seq_along(chips)) {
  xl <- x0 + (i - 1) * (w + gap)
  rect(xl, y1, xl + w, y1 + h, col = chipfill, border = NA)
  rect(xl, y1, xl + 6, y1 + h, col = ochre, border = NA)                 # ochre spine
  text(xl + 22, y1 + 62, chips[[i]][1], col = cream, cex = 1.8, font = 2, adj = 0)
  text(xl + 22, y1 + 28, chips[[i]][2], col = grDevices::adjustcolor(cream, .85), cex = .96, adj = 0)
}
cat("wrote", out, "\n")
