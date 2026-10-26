# ===========================================================================
# ui_helpers.R: small pure markup helpers for the Plant Diversity Explorer.
# No Shiny state, no reactive reads, no file or network access: every function
# takes plain values and returns a string or an htmltools tag, so
# scripts/test_ui_contracts.R can assert their output without a session.
# ===========================================================================

.ui_scalar <- function(x) {
  if (is.null(x) || !length(x)) return(NA)
  x[[1]]
}
.ui_blank <- function(x) {
  x <- .ui_scalar(x)
  is.na(x) || !nzchar(trimws(as.character(x)))
}

# Number formatted the way the hero count-up paints it (www/app.js animateCount):
# integers with a thousands separator, non-integers to one decimal.
ui_hero_value <- function(value) {
  v <- suppressWarnings(as.numeric(.ui_scalar(value)))
  if (!length(v) || is.na(v) || !is.finite(v)) return("n/a")
  if (abs(v - round(v)) < 1e-9) format(round(v), big.mark = ",", trim = TRUE, scientific = FALSE)
  else sprintf("%.1f", v)
}

# Accessible name for a clickable hero KPI tile. The tile is a role=button, so its
# aria-label replaces the visible text: carry the value, unit, label and sub-line.
# hero_aria_label(203, "", "species", "full-grain survey 2023")
#   -> "203 species, full-grain survey 2023. Open details"
hero_aria_label <- function(value, suffix = "", label = "", sub = NULL) {
  val <- ui_hero_value(value)
  suf <- if (identical(val, "n/a") || .ui_blank(suffix)) "" else as.character(.ui_scalar(suffix))
  lab <- if (.ui_blank(label)) "" else {
    l <- as.character(.ui_scalar(label))
    if (startsWith(l, "%")) {
      if (identical(val, "n/a")) paste0(" ", trimws(sub("^%", "", l))) else l   # "9.6% introduced cover" / "n/a introduced cover"
    } else paste0(" ", l)
  }
  s <- if (.ui_blank(sub)) "" else paste0(", ", as.character(.ui_scalar(sub)))
  paste0(val, suf, lab, s, ". Open details")
}

# Short source receipt for the hero band. The visible text carries the record
# span, release, query cutoff and the last six characters of the receipt ID; the
# full ID rides in the title attribute (and in the PDF and provenance export).
# short_receipt_html(2016, 2024, "RELEASE-2026", "2026-09-30", "PDE-...811cc7")
#   -> <span class="hero-receipt-text" title="PDE-...811cc7">records 2016 to 2024 ·
#      RELEASE-2026 · query through 2026-09-30 · receipt …811cc7</span>
short_receipt_html <- function(start_year, end_year, release, cutoff, receipt_id) {
  sy <- suppressWarnings(as.integer(.ui_scalar(start_year)))
  ey <- suppressWarnings(as.integer(.ui_scalar(end_year)))
  parts <- character(0)
  if (!is.na(sy) && !is.na(ey))
    parts <- c(parts, if (sy == ey) sprintf("records %d", sy) else sprintf("records %d to %d", sy, ey))
  if (!.ui_blank(release)) parts <- c(parts, as.character(.ui_scalar(release)))
  parts <- c(parts, sprintf("query through %s",
                            if (.ui_blank(cutoff)) "n/a" else as.character(.ui_scalar(cutoff))))
  id <- if (.ui_blank(receipt_id)) NA_character_ else as.character(.ui_scalar(receipt_id))
  parts <- c(parts, if (is.na(id)) "receipt n/a"
                    else sprintf("receipt …%s", substr(id, max(1L, nchar(id) - 5L), nchar(id))))
  htmltools::tags$span(class = "hero-receipt-text",
                       title = if (is.na(id)) NULL else id,
                       paste(parts, collapse = " · "))
}

# Landing-view data line: "NEON data through 2024 · RELEASE-2026 · DOI 10.48443/..."
# with the DOI as a link. A missing release drops the release and DOI parts.
data_through_line <- function(year, release = NA_character_, doi = NA_character_) {
  y <- suppressWarnings(as.integer(.ui_scalar(year)))
  first <- if (is.na(y)) "NEON data through n/a" else sprintf("NEON data through %d", y)
  rel_ok <- !.ui_blank(release)
  doi_ok <- rel_ok && !.ui_blank(doi)
  doi_s <- if (doi_ok) as.character(.ui_scalar(doi)) else NA_character_
  htmltools::tags$p(class = "data-through",
    first,
    if (rel_ok) paste0(" · ", as.character(.ui_scalar(release))),
    if (doi_ok) htmltools::tagList(" · ",
      htmltools::tags$a(href = doi_s, target = "_blank", rel = "noopener",
                        paste("DOI", sub("^https?://(dx\\.)?doi\\.org/", "", doi_s)))))
}

# Escaped pin-card HTML for one introduced species on the cross-scale chart. The
# species name rides in a single-quoted data-tag, so it must be attribute-escaped
# (Erodium cicutarium (L.) L'Hér. ex Aiton carries an apostrophe); pincards.js
# reads it back with getAttribute, which decodes the entity.
foothold_tip_html <- function(scientificName, family, plots_1m, plots_400,
                              mean_cover_1m = NA_real_) {
  nm  <- as.character(scientificName); nm[is.na(nm)] <- ""
  fam <- as.character(family); fam[is.na(fam)] <- "n/a"
  p1 <- suppressWarnings(as.integer(plots_1m)); p4 <- suppressWarnings(as.integer(plots_400))
  mc <- suppressWarnings(as.numeric(mean_cover_1m))
  if (length(mc) != length(nm)) mc <- rep_len(mc, length(nm))
  paste0(
    "<span class='smt-pin-emoji'>\U0001F33F</span> <b><i>", htmltools::htmlEscape(nm), "</i></b><br/>",
    "<span class='smt-pin-stats'>", htmltools::htmlEscape(fam), " · introduced",
      "<br/>", p1, " plot", ifelse(p1 == 1, "", "s"), " at 1 m² · ",
      p4, " plot", ifelse(p4 == 1, "", "s"), " in the 400 m² plot",
      ifelse(is.finite(mc), paste0("<br/>mean ", signif(mc, 3), "% cover at 1 m²"), ""),
      "</span>",
    "<br/><span class='smt-open-foothold' role='button' tabindex='0' data-tag='",
      htmltools::htmlEscape(nm, attribute = TRUE),
      "'>\U0001F50E Where is it? &rarr;</span>",
    "<br/><em class='smt-pin-hint'>Tap the dot to pin this card</em>")
}

# Scope chip: a persistent label naming what a view covers ("All 46 sites", "SRER").
scope_chip <- function(label) {
  if (.ui_blank(label)) return(NULL)
  htmltools::tags$span(class = "scope-chip",
    bsicons::bs_icon("geo-alt"),
    htmltools::tags$span(class = "scope-chip-label", as.character(.ui_scalar(label))))
}

# Watchlist display value: "<0.1" for present-but-tiny cover, else one decimal.
watchlist_cover_label <- function(x) {
  x <- suppressWarnings(as.numeric(x))
  ifelse(!is.finite(x), "n/a",
         ifelse(x > 0 & x < 0.1, "<0.1", sprintf("%.1f", x)))
}

# QC-flag level -> the suite's .qc-flag-<level> class.
qc_flag_class <- function(level) {
  lv <- tolower(as.character(.ui_scalar(level)))
  if (is.na(lv) || !lv %in% c("high", "warn", "info", "clean")) lv <- "info"
  paste0("qc-flag-", lv)
}

# A QC flag header rendered as a real button. A delegated handler in www/app.js
# sends Shiny.setInputValue('qcFlagOpen', <flag id>, {priority: 'event'}).
qc_flag_button <- function(flag_id, ...) {
  htmltools::tags$button(type = "button", class = "evo-flag-h qc-flag-btn",
                         `data-qc-flag` = as.character(.ui_scalar(flag_id)), ...)
}

# NEON change-log notices as a short list. `notices` is plant_site_notices()
# output: data.frame(id, date, text, location). NULL or zero rows -> NULL.
neon_notices_html <- function(notices, class = "neon-notices", heading = "NEON notices") {
  if (is.null(notices) || !is.data.frame(notices) || !nrow(notices)) return(NULL)
  items <- lapply(seq_len(nrow(notices)), function(i) {
    id <- as.character(notices$id[i]); dt <- as.character(notices$date[i])
    txt <- as.character(notices$text[i])
    htmltools::tags$li(
      htmltools::tags$span(class = "neon-notice-id",
        sprintf("NEON %s%s", if (is.na(id)) "notice" else paste("change log", id),
                if (is.na(dt) || !nzchar(dt)) "" else paste0(", ", dt))),
      ": ", if (is.na(txt)) "n/a" else txt)
  })
  htmltools::tags$div(class = class,
    htmltools::tags$span(class = "neon-notices-h", heading),
    htmltools::tags$ul(items))
}
