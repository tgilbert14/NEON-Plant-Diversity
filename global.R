# ===========================================================================
# NEON Plant Diversity Explorer — global.R
# A sibling of the NEON Small Mammal Tracker (Desert Data Labs), NEONized for
# the Plant presence & percent cover product (DP1.10058.001). Chrome, theme, and
# bundling spine ported from the mammal flagship; the analysis layer is plant-
# native (cover, nested species-area, native vs invasive). See docs/neonize-playbook.md.
# ===========================================================================

suppressPackageStartupMessages({
  library(shiny); library(bslib); library(bsicons)
  library(dplyr); library(tidyr); library(stringr); library(tibble)
  library(plotly); library(leaflet); library(DT)
  library(shinyjs); library(shinycssloaders); library(RColorBrewer); library(htmltools)
})

# ---- helpers + metadata ---------------------------------------------------
source("R/site_metadata.R", local = FALSE)
source("R/plant_helpers.R", local = FALSE)

NEON_DPID <- "DP1.10058.001"   # Plant presence and percent cover

# Live NEON fetch is OFF in the deployed demo (bundle-only, lean Connect Cloud
# build). The package is referenced by a computed name so the rsconnect scanner
# never pins it. (Same anti-pin trick as the mammal app.)
.NEON_PKG <- paste0("neon", "Utilities")
LIVE_FETCH <- (Sys.getenv("PDE_LIVE", "0") != "0") && requireNamespace(.NEON_PKG, quietly = TRUE)

# ---- bundled per-site data ------------------------------------------------
SITE_DIR  <- "data/sites"
DEMO_PATH <- "data-sample/demo.rds"
DEMO_META <- list(site = "SRER", label = "SRER · Santa Rita Experimental Range — demo")

# Defensive bundle read: a list(occ, ground, meta) or NULL — never crash boot.
read_bundle <- function(f) {
  if (!file.exists(f)) return(NULL)
  out <- tryCatch(readRDS(f), error = function(e) {
    warning(sprintf("read_bundle('%s') failed: %s", f, conditionMessage(e))); NULL })
  if (is.null(out) || is.null(out$occ) || !nrow(out$occ)) NULL else out
}
load_site_bundle <- function(site) read_bundle(file.path(SITE_DIR, paste0(site, ".rds")))
load_demo <- function() { b <- load_site_bundle(DEMO_META$site); if (!is.null(b)) b else read_bundle(DEMO_PATH) }

# national site index (the picker) — one row per bundled site
SITE_INDEX <- read_bundle("data/site_index.rds")
if (is.null(SITE_INDEX)) SITE_INDEX <- tryCatch(readRDS("data/site_index.rds"), error = function(e) NULL)

# bundled sites only (the demo deploy ships these); join site metadata for the picker
BUNDLED <- if (!is.null(SITE_INDEX)) SITE_INDEX$site else character(0)
site_table <- if (length(BUNDLED)) {
  m <- neon_sites[match(BUNDLED, neon_sites$site), ]
  cbind(m, SITE_INDEX[match(m$site, SITE_INDEX$site), c("richness","n_plots","pct_introduced","dominant_family")])
} else neon_sites[0, ]

# sidebar picker: only bundled sites
plant_state_choices <- function() {
  st <- sort(unique(site_table$state))
  if (!length(st)) return(NULL)
  setNames(st, sprintf("%s (%d)", state_names[st] %||% st, as.integer(table(site_table$state)[st])))
}
plant_sites_in_state <- function(stt) {
  rows <- site_table[site_table$state == stt, ]; rows <- rows[order(rows$name), ]
  if (!nrow(rows)) return(character(0))
  setNames(rows$site, sprintf("%s — %s", rows$site, rows$name))
}

# ---- theme (Desert Data Labs / Girth-Index house style; greened for plants) --
# Same triad as the mammal app; the accent leans evergreen for a plant app, but
# the navy/cardinal/gold core is kept so the DDL family reads as one.
DDL <- list(
  navy = "#0C234B", navy2 = "#16386e", cardinal = "#AB0520", gold = "#FFD200",
  gold2 = "#c9a300", sky = "#2f7fb5", green = "#1a7f37", green2 = "#12612a",
  ink = "#1c2733", muted = "#6b7a89", bg = "#eef2f8", paper = "#ffffff", line = "#dbe2ec",
  native = "#1a7f37", introduced = "#c1502e", unknown = "#9aa6b2")

app_theme <- bs_theme(
  version = 5, bg = "#ffffff", fg = DDL$ink,
  primary = DDL$navy, secondary = DDL$cardinal,
  success = DDL$green, info = DDL$sky, warning = DDL$gold, danger = DDL$cardinal,
  base_font = font_google("Rubik"), heading_font = font_google("Rubik"),
  "border-radius" = "10px")

# ---- static-asset cache-busting (mtime query) -----------------------------
asset_url <- function(path) {
  f <- file.path("www", path)
  v <- if (file.exists(f)) as.integer(as.numeric(file.mtime(f))) else 0L
  sprintf("%s?v=%s", path, v)
}

# ---- small UI utilities (ported) ------------------------------------------
spin <- function(x, img = "leaf.gif")
  shinycssloaders::withSpinner(x, color = DDL$green, color.background = "#ffffff", type = 6)

info_pop <- function(title, ..., placement = "auto")
  bslib::popover(tags$span(class = "info-dot", bsicons::bs_icon("info-circle")),
                 ..., title = title, placement = placement)

insight_banner <- function(icon, ..., tone = "navy")
  div(class = paste("chart-insight", paste0("ci-", tone)),
      bsicons::bs_icon(icon), div(class = "ci-text", ...))

glow_badge <- function(label, color = "#0C234B", glow = color)
  span(class = "glow-badge",
       style = sprintf("color:#fff; background:%s; border-color:%s;", color, color), label)

card_head <- function(icon, title, ...)
  bslib::card_header(class = "with-info", bsicons::bs_icon(icon),
                     tags$span(class = "ch-title", " ", title), ...)

fmt_int <- function(x) format(round(as.numeric(x)), big.mark = ",", trim = TRUE)
fmt_range <- function(a, b) if (is.null(a) || is.null(b) || is.na(a) || is.na(b)) "" else
  sprintf("%s–%s", a, b)
