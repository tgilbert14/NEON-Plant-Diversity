# ===========================================================================
# test_ui_contracts.R: fixtures for the pure UI helpers (R/ui_helpers.R), the
# bundle-path allowlist and the page shell. Run from the repo root:
#   Rscript --vanilla scripts/test_ui_contracts.R
# Sources global.R (bundle-only, PDE_LIVE=0) and ui.R; never sources server.R.
# ===========================================================================
Sys.setenv(PDE_LIVE = "0")
suppressPackageStartupMessages(source("global.R", local = FALSE))
source("ui.R", local = FALSE)

fail <- function(...) stop(sprintf(...), call. = FALSE)
check <- function(ok, ...) if (!isTRUE(ok)) fail(...)

# 1. foothold tip: an apostrophe name round-trips through the single-quoted data-tag
erodium <- "Erodium cicutarium (L.) L'Hér. ex Aiton"
tip <- foothold_tip_html(erodium, "Geraniaceae", 0L, 4L, NA_real_)
m <- regmatches(tip, regexec("data-tag='([^']*)'", tip))[[1]]
check(length(m) == 2L, "foothold tip: no single-quoted data-tag found")
decode <- function(x) {
  x <- gsub("&#39;", "'", x, fixed = TRUE); x <- gsub("&quot;", "\"", x, fixed = TRUE)
  x <- gsub("&lt;", "<", x, fixed = TRUE);  x <- gsub("&gt;", ">", x, fixed = TRUE)
  gsub("&amp;", "&", x, fixed = TRUE)
}
check(identical(decode(m[2]), erodium), "foothold tip: data-tag decodes to '%s', not the full name", decode(m[2]))
check(!grepl("<script", foothold_tip_html("<script>x</script>", "F", 1L, 1L), fixed = TRUE),
      "foothold tip: visible name is not HTML-escaped")

# 2. hero aria-label carries the value, unit and sub-line
lab <- hero_aria_label(203, "", "species", "full-grain survey 2023")
check(identical(lab, "203 species, full-grain survey 2023. Open details"), "hero_aria_label: got '%s'", lab)
lab2 <- hero_aria_label(9.6, "", "% introduced cover", NULL)
check(grepl("9.6", lab2, fixed = TRUE), "hero_aria_label: value missing from '%s'", lab2)
check(grepl("^n/a", hero_aria_label(NA, "", "plots")), "hero_aria_label: NA value is not n/a")

# 3. short receipt keeps the full ID in title and shows only the tail
rid <- "PDE-DP1.10058.001-query-through-2026-09-30-sha256-d7e9e0de7d8e624cb4e4f9d6d64b4a41ae58f09ead497ce1307983b797811cc7"
rh <- as.character(short_receipt_html(2016, 2024, "RELEASE-2026", "2026-09-30", rid))
check(grepl(sprintf("title=\"%s\"", rid), rh, fixed = TRUE), "short_receipt_html: full ID not in title")
check(grepl("records 2016 to 2024 · RELEASE-2026 · query through 2026-09-30 · receipt …811cc7", rh, fixed = TRUE),
      "short_receipt_html: visible text is '%s'", rh)
rh_na <- as.character(short_receipt_html(2016, 2024, NA, "2026-09-30", rid))
check(!grepl("RELEASE", rh_na, fixed = TRUE), "short_receipt_html: NA release still printed")

# 4. data-through line links the DOI and drops release parts when NA
dl <- as.character(data_through_line(2024, "RELEASE-2026", "https://doi.org/10.48443/9g4s-hq52"))
check(grepl("NEON data through 2024", dl, fixed = TRUE) && grepl("href=\"https://doi.org/10.48443/9g4s-hq52\"", dl, fixed = TRUE),
      "data_through_line: got '%s'", dl)
check(!grepl("href", as.character(data_through_line(2024, NA, NA)), fixed = TRUE), "data_through_line: NA release kept a link")

# 5. bundle path allowlist
check(is.null(load_site_bundle("../../data-sample/demo")), "load_site_bundle accepted a path outside data/sites")
check(is.null(load_site_bundle(c("SRER", "JORN"))), "load_site_bundle accepted a vector")
check(is.null(load_site_bundle(NA_character_)), "load_site_bundle accepted NA")
check(!is.null(load_site_bundle("SRER")), "load_site_bundle rejected SRER")

# 6. page shell: <title>, lang, and no stray window_title/fillable attributes
page <- as.character(htmltools::renderTags(ui)$html)
# the document Shiny actually serves (renderPage applies the page's lang attribute)
full <- paste(as.character(shiny:::renderPage(ui)), collapse = "\n")
check(grepl("<title>NEON Plant Diversity Explorer</title>", full, fixed = TRUE), "page: no <title>NEON Plant Diversity Explorer</title>")
check(grepl("lang=\"en\"", full, fixed = TRUE), "page: no lang=\"en\"")
check(!grepl("window_title", full, fixed = TRUE), "page: stray window_title attribute")
check(!grepl("fillable=\"FALSE\"", full, fixed = TRUE), "page: stray fillable attribute")

# 7. info popover triggers carry an accessible name
check(grepl("aria-label=\"About: ", page, fixed = TRUE), "info_pop: trigger has no aria-label")

cat("ui-contract fixtures: PASS\n")
