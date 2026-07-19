# ===========================================================================
# NEON Plant Diversity Explorer — expected_qc.R
# Expected-vs-Observed plant QC (the "EcoPlot recipe"). For each NEON site we
# precompute its EXPECTED reference flora from the NRCS Ecological Site (built by
# scripts/build_expected_lists.R via Soil Data Access) and compare it against the
# species NEON actually observed. The framing is COMPLETENESS, not correctness:
# NEON samples ~400 m^2 per plot at peak greenness, so an expected species not
# detected is overwhelmingly non-detection (small area) or a real state-transition,
# NEVER an "error". Only two lanes are genuine data-quality signals (coarse IDs,
# nativity disagreements) and they are kept visually distinct from completeness.
#
# Pure functions only (no Shiny). All inputs are the in-memory `occ` table + the
# bundled expected list; the deployed app makes ZERO federal API calls. The USDA
# nativity/synonym authority is optional — every flag degrades gracefully when it
# is absent. See docs/_mlra_qc_plan.md and the NEONize "expected-vs-observed" module.
# ===========================================================================

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a

EXPECTED_DIR  <- "data/expected"
AUTHORITY_RDS <- "data/authority/plants_lookup.rds"

# ---- loaders --------------------------------------------------------------
# A site's EXPECTED reference flora, or NULL if unavailable (failed SDA fetch or
# genuinely no correlated ESD). NULL drives an honest empty state, never "0%".
load_expected <- function(site, dir = EXPECTED_DIR) {
  if (is.null(site) || !nzchar(site)) return(NULL)
  f <- file.path(dir, paste0(site, ".rds"))
  if (!file.exists(f)) return(NULL)
  e <- tryCatch(readRDS(f), error = function(err) NULL)
  if (is.null(e) || !identical(e$status, "ok") || is.null(e$reference_species)) return(NULL)
  e
}

# USDA PLANTS nativity + NEON synonym->accepted map (optional). Returns a list
# with $authority (tibble: accepted_symbol, sci_name, nativity_usda, growth_habit,
# duration) and $synonyms (named chr: taxonID -> acceptedTaxonID), or NULL.
load_plant_authority <- function(path = AUTHORITY_RDS) {
  if (!file.exists(path)) return(NULL)
  tryCatch(readRDS(path), error = function(err) NULL)
}

# Normalise a USDA-symbol vector to ACCEPTED symbols via the synonym map (so a
# NEON synonym doesn't miss the join and fake an "unmatched" QC signal). When no
# authority is loaded this is just upper-case/trim.
accept_symbol <- function(sym, authority = NULL) {
  s <- toupper(trimws(as.character(sym)))
  if (!is.null(authority) && !is.null(authority$synonyms) && length(authority$synonyms)) {
    m <- authority$synonyms[s]
    s <- ifelse(is.na(m), s, unname(m))
  }
  s
}

# The currently bundled expected lists are produced from one site coordinate,
# one intersecting soil map unit, and its dominant correlated ecological class.
# Keep that spatial limitation available to reports/exports so "expected" is
# never read as a site-wide truth claim.
expected_reference_scope <- function(expected = NULL) {
  if (is.null(expected)) return("No ecological-site reference is available.")
  if (!is.null(expected$reference_scope) && length(expected$reference_scope) &&
      !is.na(expected$reference_scope[1]) && nzchar(expected$reference_scope[1]))
    return(as.character(expected$reference_scope[1]))
  "Single NRCS ecological-site flora from the soil map unit at the site reference coordinate; descriptive, not a site-wide expected-flora census."
}

.nativity_conflict <- function(x) {
  z <- unique(as.character(x[!is.na(x) & x %in% c("Native", "Introduced")]))
  all(c("Native", "Introduced") %in% z)
}

.resolve_nativity <- function(x) {
  if (.nativity_conflict(x)) "Unknown" else mode_chr(x)
}

# ---- the observed species set (the comparison's left-hand side) -----------
# One row per ACCEPTED species symbol from the honest one-survey-per-plot snapshot
# (same recipe every other site metric uses — no pseudoreplication, agrees with
# the hero counts). Carries NEON nativity + mean 1 m^2 cover + plot ubiquity.
observed_species <- function(occ, authority = NULL) {
  d <- species_level_only(latest_snapshot(occ))
  if (is.null(d) || !nrow(d)) return(NULL)
  d <- d[!is.na(d$taxonID) & nzchar(d$taxonID), , drop = FALSE]
  if (!nrow(d)) return(NULL)
  d$sym <- accept_symbol(d$taxonID, authority)
  cov1 <- d[d$scale == 1 & is.finite(d$percentCover) & d$percentCover > 0, , drop = FALSE]
  cov_by <- if (nrow(cov1)) tapply(cov1$percentCover, cov1$sym, mean) else numeric(0)
  d %>% dplyr::group_by(.data$sym) %>%
    dplyr::summarise(
      scientificName = mode_chr(.data$scientificName),
      family         = mode_chr(.data$family),
      nativity_conflict = .nativity_conflict(.data$nativity),
      nativity       = .resolve_nativity(.data$nativity), # conflicts route to Unknown/review
      neon_status    = if (.nativity_conflict(.data$nativity))
        paste(sort(unique(as.character(.data$nativeStatusCode[!is.na(.data$nativeStatusCode)])),
                   method = "radix"), collapse = "|") else mode_chr(.data$nativeStatusCode),
      n_plots        = dplyr::n_distinct(.data$plotID),
      .groups = "drop") %>%
    dplyr::mutate(mean_cover = round(as.numeric(cov_by[.data$sym]), 2)) %>%
    dplyr::arrange(dplyr::desc(.data$n_plots), dplyr::desc(.data$mean_cover))
}

# the comparison reference list: real species only (drop SDA aggregate/genus codes
# like 2FA, 2SHRUB, PROSO), accepted-symbol normalised, one row per symbol.
reference_species_clean <- function(expected, authority = NULL) {
  ref <- expected$reference_species
  if (is.null(ref) || !nrow(ref)) return(ref)
  ref <- ref[!(ref$is_aggregate %in% TRUE), , drop = FALSE]
  if (!nrow(ref)) return(ref)
  ref$plantsym <- accept_symbol(ref$plantsym, authority)
  ref <- ref[!duplicated(ref$plantsym), , drop = FALSE]
  ref[order(-ifelse(is.finite(ref$rangeprod), ref$rangeprod, -1)), , drop = FALSE]
}

# ---- the three buckets (the hero framing: completeness, not correctness) ----
# A  Expected & Observed  -> confirmation (green)
# B  Expected but Absent  -> completeness gap, sorted by rangeprod (neutral)
# C  Observed but NOT in reference -> the genuine review lane (clay), split
#    Introduced (invasion signal) vs Native-not-in-reference (range/mapping/misID)
expected_vs_observed <- function(occ, expected, authority = NULL) {
  if (is.null(expected)) return(NULL)
  obs <- observed_species(occ, authority)
  ref <- reference_species_clean(expected, authority)
  if (is.null(obs) || !nrow(obs) || is.null(ref) || !nrow(ref)) return(NULL)

  obs_sym <- obs$sym
  in_obs  <- ref$plantsym %in% obs_sym

  # A — expected & observed (join observed cover/ubiquity onto the reference row)
  A <- ref[in_obs, , drop = FALSE]
  if (nrow(A)) {
    j <- match(A$plantsym, obs$sym)
    A$obs_cover  <- obs$mean_cover[j]
    A$obs_plots  <- obs$n_plots[j]
    A$obs_nativity <- obs$nativity[j]
    A <- A[order(-ifelse(is.finite(A$rangeprod), A$rangeprod, -1)), , drop = FALSE]
  }
  # B — expected but absent (completeness gap), dominants float up via rangeprod
  B <- ref[!in_obs, , drop = FALSE]

  # C — observed but not in the reference list
  C <- obs[!(obs$sym %in% ref$plantsym), , drop = FALSE]

  # Every observed-not-reference species remains in the review lane. A former
  # GBIF state-occurrence shortcut was removed because it lacked the per-match,
  # query, dataset, and license receipts needed to alter this classification.
  C$c_class <- rep("review", nrow(C))
  C_review <- C

  list(
    A = A, B = B, C = C_review, C_all = C,
    n_ref = nrow(ref), n_obs = nrow(obs),
    n_overlap = nrow(A),
    overlap_pct = round(100 * nrow(A) / nrow(ref), 1),
    dom_total = sum(ref$is_dominant %in% TRUE),
    dom_obs   = sum(ref$is_dominant %in% TRUE & in_obs),
    n_review_intro   = sum(C_review$nativity == "Introduced", na.rm = TRUE),
    n_review_native  = sum(C_review$nativity == "Native", na.rm = TRUE),
    n_review_unknown = nrow(C_review) - sum(C_review$nativity %in% c("Introduced", "Native")),  # residual -> always reconciles
    dom_basis = expected$dominance_basis %||% (if (sum(ref$is_dominant %in% TRUE) > 0) "rangeland_production" else "none"),
    dom_rule  = expected$dom_rule %||% NA_character_,
    ecoclassid = expected$ecoclassid, ecosite_name = expected$ecosite_name,
    mlra = expected$mlra, source = expected$source %||% "esd",
    reference_scope = expected_reference_scope(expected))
}

# the site code carried on the occ table (one survey, one site) — for the state lookup.
# The bundle's occ has no siteID column; the NEON plotID is "<SITE>_<plot>" (e.g.
# "SRER_001"), so the 4-char prefix is the site code. Fall back to siteID if present.
site_of_occ <- function(occ) {
  if (is.null(occ) || !nrow(occ)) return(NA_character_)
  if ("siteID" %in% names(occ)) {
    s <- mode_chr(occ$siteID); if (!is.na(s) && nzchar(s)) return(toupper(s))
  }
  if ("plotID" %in% names(occ)) {
    pid <- mode_chr(occ$plotID)
    if (!is.na(pid) && nzchar(pid)) return(toupper(sub("[_-].*$", "", pid)))
  }
  NA_character_
}

# the dominants-absent subset of bucket B (the completeness headline driver)
missing_dominants <- function(evo) {
  if (is.null(evo) || is.null(evo$B) || !nrow(evo$B)) return(evo$B)
  evo$B[evo$B$is_dominant %in% TRUE, , drop = FALSE]
}

# ---- TRUE QC lane (real data-quality signals) -----------------------------

# Flag 1 — taxonomic resolution. Share of the snapshot resolved only to genus /
# family / kingdom. A direct count (no inference, no false positives); it frames
# every other flag, so it is surfaced FIRST. Cover share uses the 1 m^2 quadrats.
flag_coarse_rank <- function(occ) {
  d <- latest_snapshot(occ)
  if (is.null(d) || !nrow(d)) return(NULL)
  fine <- c("species", "subspecies", "variety", "speciesGroup")
  # "fine" = species-level via the bundle's is_species flag, so this agrees with
  # species_level_only() (an NA rank with a clean binomial counts as species, not
  # coarse) — the two conventions must not disagree.
  fine_row <- function(x) if ("is_species" %in% names(x)) x$is_species %in% TRUE else
    (!is.na(x$taxonRank) & x$taxonRank %in% fine)
  is_coarse <- !fine_row(d)
  rank <- ifelse(is.na(d$taxonRank), "unknown", as.character(d$taxonRank))
  n <- nrow(d)
  cov <- d[d$scale == 1 & is.finite(d$percentCover) & d$percentCover > 0, , drop = FALSE]
  cov_coarse <- if (nrow(cov)) {
    cr <- !fine_row(cov)
    100 * sum(cov$percentCover[cr]) / sum(cov$percentCover)
  } else NA_real_
  by_rank <- as.data.frame(table(rank[is_coarse]), stringsAsFactors = FALSE)
  names(by_rank) <- c("rank", "n_records")
  by_rank <- by_rank[order(-by_rank$n_records), , drop = FALSE]
  rows <- d[is_coarse, c("plotID","subplotID","scale","year","taxonID","scientificName","taxonRank","family"), drop = FALSE]
  rows <- rows[order(rows$taxonRank, rows$scientificName), , drop = FALSE]
  list(pct_records = round(100 * sum(is_coarse) / n, 1),
       pct_cover   = if (is.finite(cov_coarse)) round(cov_coarse, 1) else NA_real_,
       n_coarse = sum(is_coarse), n_total = n,
       by_rank = by_rank, rows = rows)
}

# Flag 2 — nativity mismatch (NEON vs USDA L48). Cheapest high-value flag, but
# needs the authority; returns NULL (handled as "needs authority") when absent.
# Only N-vs-I disagreements count; NEON NI/UNK and USDA unknown are NON-conflicting
# (nativity is regional — a true scale mismatch, not a contradiction).
flag_nativity_mismatch <- function(occ, authority = NULL) {
  if (is.null(authority) || is.null(authority$authority) || !nrow(authority$authority)) return(NULL)
  obs <- observed_species(occ, authority)
  empty <- data.frame(
    sym = character(), scientificName = character(), family = character(),
    nativity = character(), usda_nativity = character(), n_plots = integer(),
    mean_cover = numeric(), stringsAsFactors = FALSE)
  if (is.null(obs) || !nrow(obs)) return(list(rows = empty, n = 0L))
  state <- tryCatch(site_state(site_of_occ(occ)), error = function(e) NA_character_)
  if (!is.na(state) && state %in% c("AK", "HI", "PR")) {
    return(list(rows = obs[0, , drop = FALSE], n = 0L, eligible = FALSE,
                reason = "USDA nativity authority is L48-only", state = state))
  }
  auth <- authority$authority
  j <- match(obs$sym, auth$accepted_symbol)
  obs$usda_nativity <- auth$nativity_usda[j]
  norm <- function(x) dplyr::case_when(x %in% c("Native") ~ "Native",
                                       x %in% c("Introduced") ~ "Introduced",
                                       TRUE ~ NA_character_)
  neon_n <- norm(obs$nativity); usda_n <- norm(obs$usda_nativity)
  conflict <- !is.na(neon_n) & !is.na(usda_n) & neon_n != usda_n
  rows <- obs[conflict, c("sym","scientificName","family","nativity","usda_nativity","n_plots","mean_cover"), drop = FALSE]
  rows <- rows[order(-rows$n_plots), , drop = FALSE]
  list(rows = rows, n = nrow(rows), eligible = TRUE, state = state)
}

# Flag 4 — cover summing implausibly. Multi-layer canopy legitimately exceeds
# 100% (a tallgrass 1 m^2 can hit ~200%), so flag only EXTREME outliers — a sanity
# backstop for entry error — per (plot, subplot, year, bout) at the 1 m^2 scale.
# Typed group-aggregate (no paste/strsplit, so an NA/absent bout can't crash it).
flag_cover_sum <- function(occ, ceiling_pct = 250) {
  empty <- data.frame(plotID = character(), subplotID = character(), year = integer(),
                      bout = character(), total_cover = numeric(), stringsAsFactors = FALSE)
  d <- occ[occ$scale == 1 & is.finite(occ$percentCover) & occ$percentCover > 0, , drop = FALSE]
  if (is.null(d) || !nrow(d)) return(list(rows = empty, n = 0L, ceiling = ceiling_pct))
  d$.bout <- if ("bout" %in% names(d)) ifelse(is.na(d$bout), "—", as.character(d$bout)) else "—"
  agg <- d %>% dplyr::group_by(.data$plotID, .data$subplotID, .data$year, .data$.bout) %>%
    dplyr::summarise(total_cover = sum(.data$percentCover), .groups = "drop")
  bad <- agg[is.finite(agg$total_cover) & agg$total_cover > ceiling_pct, , drop = FALSE]
  if (!nrow(bad)) return(list(rows = empty, n = 0L, ceiling = ceiling_pct))
  out <- data.frame(plotID = bad$plotID, subplotID = bad$subplotID, year = as.integer(bad$year),
                    bout = bad$.bout, total_cover = round(bad$total_cover, 1), stringsAsFactors = FALSE)
  out <- out[order(-out$total_cover), , drop = FALSE]
  list(rows = out, n = nrow(out), ceiling = ceiling_pct)
}

# ---- match-rate honesty (publish on every name-join) ----------------------
# % of observed symbols that resolved to a USDA accepted symbol (needs authority)
# and % of the reference list carrying a usable species-level symbol.
qc_match_rate <- function(occ, expected, authority = NULL) {
  obs <- observed_species(occ, authority)
  ref_all <- if (!is.null(expected)) expected$reference_species else NULL
  ref_sp  <- reference_species_clean(expected, authority)
  obs_resolved <- if (!is.null(authority) && !is.null(obs)) {
    mean(obs$sym %in% authority$authority$accepted_symbol) * 100
  } else NA_real_
  list(
    obs_n = if (!is.null(obs)) nrow(obs) else 0L,
    obs_resolved_pct = if (is.finite(obs_resolved)) round(obs_resolved, 1) else NA_real_,
    ref_n_all = if (!is.null(ref_all)) nrow(ref_all) else 0L,
    ref_n_species = if (!is.null(ref_sp)) nrow(ref_sp) else 0L,
    ref_species_pct = if (!is.null(ref_all) && nrow(ref_all))
      round(100 * nrow(ref_sp) / nrow(ref_all), 1) else NA_real_)
}

# ---- the combined, downloadable completeness report -----------------------
# One tidy long table stacking all three buckets + the coarse-rank summary, so a
# user gets a single CSV that mirrors what the tab shows. Bucket + native columns
# let a researcher pivot it back apart in R.
qc_report_table <- function(evo, site = NA_character_) {
  if (is.null(evo)) return(data.frame())
  mk <- function(df, bucket, getsym, getname, getfam, getnat, getprod, getdom, getcov) {
    if (is.null(df) || !nrow(df)) return(NULL)
    data.frame(site = site, bucket = bucket,
               symbol = getsym(df), scientificName = getname(df), family = getfam(df),
               nativity = getnat(df), reference_production = getprod(df),
               is_dominant = getdom(df), observed_cover = getcov(df),
               stringsAsFactors = FALSE)
  }
  A <- mk(evo$A, "A · expected & observed",
          \(d) d$plantsym, \(d) d$sciname, \(d) NA_character_, \(d) d$obs_nativity,
          \(d) d$rangeprod, \(d) d$is_dominant, \(d) d$obs_cover)
  B <- mk(evo$B, "B · expected but not detected",
          \(d) d$plantsym, \(d) d$sciname, \(d) NA_character_, \(d) NA_character_,
          \(d) d$rangeprod, \(d) d$is_dominant, \(d) NA_real_)
  C <- mk(evo$C, "C · observed, not in reference (review)",
          \(d) d$sym, \(d) d$scientificName, \(d) d$family, \(d) d$nativity,
          \(d) NA_real_, \(d) NA, \(d) d$mean_cover)
  out <- do.call(rbind, Filter(Negate(is.null), list(A, B, C)))
  if (is.null(out)) data.frame() else out
}
