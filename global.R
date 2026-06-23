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
source("R/env_helpers.R",   local = FALSE)   # environment overlays + climate correlation
source("R/map_picker.R",    local = FALSE)   # reusable national site-picker map
source("R/expected_qc.R",   local = FALSE)   # expected-vs-observed plant QC (the EcoPlot recipe)
source("R/report_pdf.R",    local = FALSE)   # one-page site report PDF (base graphics)

# USDA PLANTS nativity + NEON synonym authority (built by scripts/build_plant_authority.R).
# Optional: the nativity-mismatch flag degrades to "needs authority" when absent, but
# the three buckets + coarse-rank + cover-sum flags all work without it. Loaded once.
PLANT_AUTHORITY <- load_plant_authority()

NEON_DPID <- "DP1.10058.001"   # Plant presence and percent cover

# Live NEON fetch is OFF in the deployed demo (bundle-only, lean Connect Cloud
# build). The package is referenced by a computed name so the rsconnect scanner
# never pins it. (Same anti-pin trick as the mammal app.)
.NEON_PKG <- paste0("neon", "Utilities")
LIVE_FETCH <- (Sys.getenv("PDE_LIVE", "0") != "0") && requireNamespace(.NEON_PKG, quietly = TRUE)

# ---- bundled per-site data ------------------------------------------------
SITE_DIR  <- "data/sites"
DEMO_PATH <- "data-sample/demo.rds"
DEMO_META <- list(site = "SRER", label = "SRER · Santa Rita Experimental Range · demo")

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

# "Search the network" index — one small precomputed file loaded ONCE at boot
# (built by scripts/build_search_index.R). list(taxa=, sites=). Searches filter
# it in memory, so the network-wide search is instant with no live fetch. NULL-safe.
SEARCH_INDEX <- tryCatch(readRDS("data/search_index.rds"), error = function(e) NULL)
SEARCH_TAXA  <- if (!is.null(SEARCH_INDEX)) SEARCH_INDEX$taxa else NULL
# the autocomplete choice list: every distinct species in the index (sorted)
SEARCH_TAXON_CHOICES <- if (!is.null(SEARCH_TAXA))
  sort(unique(SEARCH_TAXA$scientificName)) else character(0)
# introduced-only species (for the "jump to a known invader" quick filter)
SEARCH_INVADER_CHOICES <- if (!is.null(SEARCH_TAXA))
  sort(unique(SEARCH_TAXA$scientificName[SEARCH_TAXA$nativity == "Introduced"])) else character(0)

# bundled sites only (the demo deploy ships these); join site metadata for the picker
BUNDLED <- if (!is.null(SITE_INDEX)) SITE_INDEX$site else character(0)
site_table <- if (length(BUNDLED)) {
  m <- neon_sites[match(BUNDLED, neon_sites$site), ]
  cbind(m, SITE_INDEX[match(m$site, SITE_INDEX$site), c("richness","n_plots","pct_introduced","dominant_family")])
} else neon_sites[0, ]

# completeness scalar (% of the NRCS reference flora detected) for the splash
# picker's "colour by" toggle — precomputed by scripts/build_completeness_index.R
# so boot never reads 46 bundles. NA for sites with no bundled reference list.
COMPLETENESS <- tryCatch(readRDS("data/expected/completeness_index.rds"), error = function(e) NULL)
if (nrow(site_table) && !is.null(COMPLETENESS) && nrow(COMPLETENESS))
  site_table$pct_detected <- COMPLETENESS$pct_detected[match(site_table$site, COMPLETENESS$site)]
if (!"pct_detected" %in% names(site_table)) site_table$pct_detected <- NA_real_

# sidebar picker: only bundled sites
plant_state_choices <- function() {
  st <- sort(unique(site_table$state))
  if (!length(st)) return(NULL)
  setNames(st, sprintf("%s (%d)", state_names[st] %||% st, as.integer(table(site_table$state)[st])))
}
plant_sites_in_state <- function(stt) {
  rows <- site_table[site_table$state == stt, ]; rows <- rows[order(rows$name), ]
  if (!nrow(rows)) return(character(0))
  setNames(rows$site, sprintf("%s · %s", rows$site, rows$name))
}

# ---- theme (Herbarium — the plant-forward Desert Data Labs identity) ---------
# Deliberately distinct from the navy/cardinal/gold Small Mammal Tracker: a deep
# leaf-green primary, a clay/terracotta accent, an ochre highlight, on cream paper.
# The token KEYS are kept (navy/cardinal/gold) so server.R needs no churn — only
# the VALUES change, so the whole cascade re-skins from here. Nativity colours come
# from the single source NATIVITY_COLS (sourced above via plant_helpers.R) so the
# chart palette, the CSS --native/--introduced tokens, and DDL can never drift.
# corr_pos / corr_neg are a CVD-safe (blue/vermillion) correlation-sign axis kept
# OFF the nativity green/clay poles, ready for the Environment tab.
DDL <- list(
  navy = "#0e1d40", navy2 = "#1b2e5c", cardinal = "#fb8a7e", gold = "#ffd24a",
  gold2 = "#e0b43a", sky = "#43b8e8", green = "#5fd16a", green2 = "#3f9a52",
  ink = "#eaf2ff", muted = "#9fb0cf", bg = "#070d1f", paper = "#0e1d40",
  line = "rgba(255,255,255,0.12)",
  corr_pos = "#0072B2", corr_neg = "#D55E00",
  native = unname(NATIVITY_COLS["Native"]),
  introduced = unname(NATIVITY_COLS["Introduced"]),
  unknown = unname(NATIVITY_COLS["Unknown"]))

# The app mascot — a flat (no-gradient, no-id so it's safely reusable) cute
# seedling-sprout in the desert-green accent. Used as the loading spinner, the
# splash guide, and the celebration hop. Parts are classed so the CSS can wiggle
# leaves (mascot-ear-l/r) / blink eyes (mascot-eyes).
MASCOT_CRITTER <- htmltools::HTML(paste0(
  '<svg class="mascot" viewBox="0 0 120 120" aria-hidden="true">',
  '<path d="M60,60 L60,30" stroke="#4aa050" stroke-width="4" stroke-linecap="round"/>',
  '<g class="mascot-ear-l"><path d="M60,36 C40,24 24,30 22,46 C40,52 56,46 60,36 Z" fill="#5fd16a"/></g>',
  '<g class="mascot-ear-r"><path d="M60,36 C80,24 96,30 98,46 C80,52 64,46 60,36 Z" fill="#5fd16a"/></g>',
  '<ellipse cx="60" cy="76" rx="28" ry="26" fill="#d8cf9e"/>',
  '<g class="mascot-eyes"><circle cx="51" cy="72" r="6" fill="#3a2a12"/><circle cx="69" cy="72" r="6" fill="#3a2a12"/>',
  '<circle cx="49" cy="69.5" r="2.2" fill="#ffffff"/><circle cx="67" cy="69.5" r="2.2" fill="#ffffff"/></g>',
  '</svg>'))

# Light desert-DAY hexes for bslib (the app PAGE defaults to light; only the
# prominent info-boxes go dark via CSS). Keep these readable on the light paper.
app_theme <- bs_theme(
  version = 5, bg = "#ffffff", fg = "#16243a",
  primary = "#2f9a4f", secondary = "#e0685a",
  success = "#3f9a52", info = "#2f8fc4", warning = "#d6a31c", danger = "#e0685a",
  base_font = font_google("Rubik"),
  heading_font = font_google("Fraunces"),   # soft-serif botanical headings — de-couples from the all-Rubik mammal app
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

# auto-pick readable text: dark ink on a bright fill, white on a dark fill
.lum <- function(hex) {
  hex <- gsub("#", "", hex); if (nchar(hex) != 6) return(0)
  rgb <- c(strtoi(substr(hex,1,2),16L), strtoi(substr(hex,3,4),16L), strtoi(substr(hex,5,6),16L))
  (0.299*rgb[1] + 0.587*rgb[2] + 0.114*rgb[3]) / 255
}
glow_badge <- function(label, color = DDL$navy, glow = color) {
  txt <- if (.lum(color) > 0.6) "#16243a" else "#fff"
  span(class = "glow-badge",
       style = sprintf("color:%s; background:%s; border-color:%s;", txt, color, color), label)
}

card_head <- function(icon, title, ...)
  bslib::card_header(class = "with-info", bsicons::bs_icon(icon),
                     tags$span(class = "ch-title", " ", title), ...)

fmt_int <- function(x) format(round(as.numeric(x)), big.mark = ",", trim = TRUE)
fmt_range <- function(a, b) if (is.null(a) || is.null(b) || is.na(a) || is.na(b)) "" else
  sprintf("%s–%s", a, b)

# ---- the NEON-series sibling registry (in-app cross-promo) ------------------
# Mirrors the constellation in docs/index.html so the About panel can link the
# WHOLE suite. Landing covers (github.io) front each live app; kept here as a
# plain list so the block can't drift from the chrome.
.SIBLINGS <- list(
  list(name = "Driver Cascade",   prod = "cross-product synthesis", url = "https://tgilbert14.github.io/NEON-Driver-Cascade/"),
  list(name = "Small Mammals",    prod = "DP1.10072.001",           url = "https://tgilbert14.github.io/NEON-Small-Mammal-Tracker-App/"),
  list(name = "Breeding Birds",   prod = "DP1.10003.001",           url = "https://tgilbert14.github.io/NEON-Breeding-Birds/"),
  list(name = "Ground Beetles",   prod = "DP1.10022.001",           url = "https://tgilbert14.github.io/NEON-Ground-Beetle-Tracker/"),
  list(name = "Plant Phenology",  prod = "DP1.10055.001",           url = "https://tgilbert14.github.io/NEON-Plant-Phenology-Explorer/"),
  list(name = "Veg Structure",    prod = "DP1.10098.001",           url = "https://tgilbert14.github.io/NEON-Vegetation-Structure-Explorer/"),
  list(name = "Water Chemistry",  prod = "DP1.20093.001",           url = "https://tgilbert14.github.io/NEON-WaterChemistry-Analyte-Viewer-App/"),
  list(name = "Mosquito Pulse",   prod = "DP1.10043.001",           url = "https://tgilbert14.github.io/NEON-Mosquito-Pulse/"))
