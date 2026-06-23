# ===========================================================================
# build_plant_authority.R — precompute the USDA PLANTS nativity + synonym
# authority used by the Expected-vs-Observed QC tab. Pulls each observed/reference
# plant symbol's profile from the USDA PLANTS services API (public domain), keeps
# only the lower-48 nativity + growth habit/duration + the accepted-symbol map,
# and writes data/authority/plants_lookup.rds. Build-only: httr/jsonlite never
# enter global.R or the rsconnect manifest. Re-runnable (per-symbol cache).
#
#   USDA, NRCS. The PLANTS Database (https://plants.usda.gov). National Plant
#   Data Team, Greensboro, NC. Content is public domain.
#
#   data/authority/plants_lookup.rds = list(
#     authority = tibble(accepted_symbol, sci_name, nativity_usda, growth_habit, duration),
#     synonyms  = named chr  observed_symbol -> accepted_symbol  (only where they differ),
#     n_symbols, n_failed, fetchedAt)
# ===========================================================================
suppressWarnings(suppressMessages({ library(httr); library(jsonlite) }))
setwd("C:/Users/tsgil/OneDrive/Documents/VGS - R/NEON-Plant-Diversity")
dir.create("data/authority", showWarnings = FALSE, recursive = TRUE)
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || (length(a) == 1 && is.na(a))) b else a

# every bundled site by default (the authority is shared suite-wide); optional CLI subset
.bundled <- sort(sub("\\.rds$", "", list.files("data/sites", pattern = "\\.rds$")))
SITES <- if (length(commandArgs(TRUE))) commandArgs(TRUE) else .bundled

# union of observed species-level symbols + non-aggregate reference symbols
syms <- character(0)
for (s in SITES) {
  b <- tryCatch(readRDS(sprintf("data/sites/%s.rds", s)), error = function(e) NULL)
  if (!is.null(b)) {
    occ <- b$occ; sp <- occ[occ$is_species %in% TRUE & !is.na(occ$taxonID), ]
    syms <- c(syms, toupper(trimws(sp$taxonID)))
  }
  e <- tryCatch(readRDS(sprintf("data/expected/%s.rds", s)), error = function(e) NULL)
  if (!is.null(e) && !is.null(e$reference_species)) {
    rs <- e$reference_species; syms <- c(syms, toupper(trimws(rs$plantsym[!(rs$is_aggregate %in% TRUE)])))
  }
}
syms <- sort(unique(syms[nzchar(syms)]))
cat("unique symbols to resolve:", length(syms), "\n")

CACHE <- "data/authority/_profile_cache.rds"
cache <- if (file.exists(CACHE)) readRDS(CACHE) else list()

fetch_one <- function(sym) {
  url <- sprintf("https://plantsservices.sc.egov.usda.gov/api/PlantProfile?symbol=%s", utils::URLencode(sym))
  for (k in 1:3) {
    r <- tryCatch(httr::GET(url, httr::timeout(40)), error = function(e) NULL)
    if (!is.null(r) && httr::status_code(r) == 200) {
      j <- tryCatch(jsonlite::fromJSON(httr::content(r, "text", encoding = "UTF-8")), error = function(e) NULL)
      if (!is.null(j) && !is.null(j$Symbol)) return(j)
      return(NULL)                      # 200 but no profile = genuinely absent
    }
    Sys.sleep(0.5 * k)
  }
  NA                                    # fetch failed -> retry on next run
}
extract <- function(j, queried) {
  if (is.null(j)) return(data.frame(queried = queried, accepted_symbol = NA_character_,
    sci_name = NA_character_, nativity_usda = NA_character_, growth_habit = NA_character_,
    duration = NA_character_, stringsAsFactors = FALSE))
  ns <- j$NativeStatuses; nat <- NA_character_
  if (is.data.frame(ns) && nrow(ns)) {
    l48 <- ns[ns$Region %in% "L48", , drop = FALSE]
    st <- if (nrow(l48)) l48$Status[1] else NA_character_
    nat <- if (is.na(st)) NA_character_ else if (st == "N") "Native" else if (st == "I") "Introduced" else "Unknown"
  }
  gh <- paste(unlist(j$GrowthHabits), collapse = "; "); if (!nzchar(gh)) gh <- NA_character_
  du <- paste(unlist(j$Durations),   collapse = "; "); if (!nzchar(du)) du <- NA_character_
  data.frame(queried = queried,
    accepted_symbol = toupper(trimws(j$AcceptedSymbol %||% j$Symbol)),
    sci_name = (j$AcceptedScientificName %||% j$ScientificName) %||% NA_character_,
    nativity_usda = nat, growth_habit = gh, duration = du, stringsAsFactors = FALSE)
}

todo <- setdiff(syms, names(cache))
cat("already cached:", length(syms) - length(todo), "| to fetch:", length(todo), "\n")
n <- 0; failed <- character(0)
for (sym in todo) {
  j <- fetch_one(sym)
  if (length(j) == 1 && is.na(j)) { failed <- c(failed, sym); next }
  cache[[sym]] <- extract(j, sym); n <- n + 1
  if (n %% 25 == 0) { saveRDS(cache, CACHE); cat("  fetched", n, "of", length(todo), "...\n") }
  Sys.sleep(0.18)
}
saveRDS(cache, CACHE)
cat("fetched this run:", n, "| failed (will retry next run):", length(failed), "\n")

# ---- per-symbol STATE distribution (states_l48) ---------------------------
# Adds, per USDA accepted symbol, the L48 USPS state codes the species is recorded
# for, sourced BUILD-ONLY from the USDA PLANTS public-domain state plant lists. Used
# by the Expected-vs-Observed QC to relax the "not in this soil-unit reference list"
# flag to STATE-LEVEL plausibility (a native recorded for the site's state is a
# regional associate, not an error). PUBLIC DOMAIN: USDA, NRCS. The PLANTS Database.
#
# Endpoint: GET /api/plantsDownload/GetGSATByState?state=<StateName> returns the full
# per-state symbol list as JSON (Symbol, ScientificName, VernacularName). The GSAT set
# covers 18 states today; states it does NOT cover get NO states_l48 entries and the
# app DEGRADES GRACEFULLY there (falls back to the soil-unit-only behaviour, no crash).
# We record exactly which states were fetched in states_meta so the app can tell
# "this state isn't covered, so we can't run the plausibility check" apart from
# "covered, and the species genuinely isn't recorded for this state".
#
# To extend to all L48: drop additional StateName -> symbol-list sources into
# fetch_state_symbols() (e.g. the legacy NRCS per-state CSV) — the inversion below
# is source-agnostic. Re-runnable; a failed state is simply omitted from coverage.
STATE_ABBR <- c(Alabama="AL", Alaska="AK", Arizona="AZ", Arkansas="AR", California="CA",
  Colorado="CO", Connecticut="CT", Delaware="DE", Florida="FL", Georgia="GA", Idaho="ID",
  Illinois="IL", Indiana="IN", Iowa="IA", Kansas="KS", Kentucky="KY", Louisiana="LA",
  Maine="ME", Maryland="MD", Massachusetts="MA", Michigan="MI", Minnesota="MN",
  Mississippi="MS", Missouri="MO", Montana="MT", Nebraska="NE", Nevada="NV",
  "New Hampshire"="NH", "New Jersey"="NJ", "New Mexico"="NM", "New York"="NY",
  "North Carolina"="NC", "North Dakota"="ND", Ohio="OH", Oklahoma="OK", Oregon="OR",
  Pennsylvania="PA", "Rhode Island"="RI", "South Carolina"="SC", "South Dakota"="SD",
  Tennessee="TN", Texas="TX", Utah="UT", Vermont="VT", Virginia="VA", Washington="WA",
  "West Virginia"="WV", Wisconsin="WI", Wyoming="WY")

# one state's recorded symbols, or NULL on failure (so the state is just left uncovered)
fetch_state_symbols <- function(state_name) {
  u <- sprintf("https://plantsservices.sc.egov.usda.gov/api/plantsDownload/GetGSATByState?state=%s",
               utils::URLencode(state_name))
  for (k in 1:3) {
    r <- tryCatch(httr::GET(u, httr::timeout(90)), error = function(e) NULL)
    if (!is.null(r) && httr::status_code(r) == 200) {
      j <- tryCatch(jsonlite::fromJSON(httr::content(r, "text", encoding = "UTF-8")),
                    error = function(e) NULL)
      if (is.data.frame(j) && nrow(j) && "Symbol" %in% names(j))
        return(toupper(trimws(j$Symbol)))
      return(NULL)                       # 200 but not a symbol table = state not covered
    }
    Sys.sleep(0.5 * k)
  }
  NULL                                   # fetch failed -> uncovered (graceful)
}

# Per-symbol state distribution is populated SEPARATELY from GBIF occurrence facets
# (scripts/fetch_gbif_states.py -> scripts/build_plant_states.R), because USDA PLANTS'
# own state API serves only 18 states and its full-distribution search times out
# server-side. So this base rebuild leaves states_l48 empty; run build_plant_states.R
# after it to fill states_l48 / states_covered for the full country from GBIF.
# (fetch_state_symbols above is retained, unused, only as the legacy GSAT reference.)
state_names_to_try <- character(0)

cat("\nstate distribution: attempting", length(state_names_to_try), "states ...\n")
SYM_STATES <- new.env(parent = emptyenv())   # accepted_symbol -> chr() of state abbrs
covered_states <- character(0)
for (sn in state_names_to_try) {
  ab <- unname(STATE_ABBR[sn]); ss <- fetch_state_symbols(sn)
  if (is.null(ss) || !length(ss)) { cat(sprintf("  %-16s uncovered\n", sn)); next }
  covered_states <- c(covered_states, ab)
  ss_acc <- toupper(trimws(unname(ifelse(ss %in% names(synonyms), synonyms[ss], ss))))  # collapse synonyms
  for (s in unique(ss_acc)) SYM_STATES[[s]] <- c(SYM_STATES[[s]], ab)
  cat(sprintf("  %-16s %5d symbols (%s)\n", sn, length(ss), ab))
  Sys.sleep(0.2)
}
covered_states <- sort(unique(covered_states))
# fold per-symbol state vectors into the authority artifact (";"-joined L48 codes)
states_l48_for <- function(sym) {
  v <- SYM_STATES[[sym]]
  if (is.null(v) || !length(v)) NA_character_ else paste(sort(unique(v)), collapse = ";")
}
cat(sprintf("state distribution: %d states covered (%s); %d symbols carry >=1 state\n",
  length(covered_states), paste(covered_states, collapse = ","), length(ls(SYM_STATES))))

# assemble the shipped artifact ---------------------------------------------
df <- do.call(rbind, cache[intersect(syms, names(cache))])
df <- df[!is.na(df$accepted_symbol) & nzchar(df$accepted_symbol), , drop = FALSE]
authority <- df[!duplicated(df$accepted_symbol),
  c("accepted_symbol","sci_name","nativity_usda","growth_habit","duration")]
authority$states_l48 <- vapply(authority$accepted_symbol, states_l48_for, character(1))
rownames(authority) <- NULL
syn <- df[df$queried != df$accepted_symbol, , drop = FALSE]
synonyms <- stats::setNames(syn$accepted_symbol, syn$queried)
out <- list(authority = authority, synonyms = synonyms,
  states_covered = covered_states,   # L48 abbrs we have a recorded symbol list for (NULL/empty => no plausibility check anywhere)
  n_symbols = length(syms), n_resolved = nrow(authority), n_synonyms = length(synonyms),
  n_failed = length(failed), built_for = SITES, fetchedAt = format(Sys.time(), "%Y-%m-%d"))
saveRDS(out, "data/authority/plants_lookup.rds", compress = "xz")
cat(sprintf("\nplants_lookup.rds: %d accepted symbols, %d synonyms, %d nativity-typed | failed %d\n",
  nrow(authority), length(synonyms), sum(!is.na(authority$nativity_usda)), length(failed)))
cat(sprintf("states_l48: %d states covered (%s); %d symbols carry a state distribution\n",
  length(covered_states), paste(covered_states, collapse = ","), sum(!is.na(authority$states_l48))))
cat("nativity breakdown:\n"); print(table(authority$nativity_usda, useNA = "ifany"))
