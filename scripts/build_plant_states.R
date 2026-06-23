# ===========================================================================
# build_plant_states.R — augment data/authority/plants_lookup.rds with a per-symbol
# `states_l48` field (the L48 USPS state codes each species is recorded for) WITHOUT
# re-fetching every plant profile. Build-only (httr/jsonlite never enter global.R /
# the rsconnect manifest). Source: USDA PLANTS public-domain state plant lists.
#
#   USDA, NRCS. The PLANTS Database (https://plants.usda.gov). National Plant Data
#   Team, Greensboro, NC. Content is public domain.
#
# Endpoint: GET /api/plantsDownload/GetGSATByState?state=<StateName> returns a state's
# full recorded symbol list as JSON. The served set covers 18 states today; states it
# does NOT serve get NO states_l48 entries and the app DEGRADES GRACEFULLY there. We
# record the served states in `states_covered` so the app can tell "this state isn't
# covered (can't run the check)" apart from "covered, but not recorded for this state".
# Re-runnable. The same fetch logic is folded into build_plant_authority.R for a full
# rebuild; this script is the cheap, no-profile-refetch path.
# ===========================================================================
suppressWarnings(suppressMessages({ library(httr); library(jsonlite) }))
setwd("C:/Users/tsgil/OneDrive/Documents/VGS - R/NEON-Plant-Diversity")

AUTH <- "data/authority/plants_lookup.rds"
if (!file.exists(AUTH)) stop("plants_lookup.rds not found; run build_plant_authority.R first")
out <- readRDS(AUTH)
authority <- out$authority
synonyms  <- out$synonyms %||% character(0)
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a

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

fetch_state_symbols <- function(state_name) {
  u <- sprintf("https://plantsservices.sc.egov.usda.gov/api/plantsDownload/GetGSATByState?state=%s",
               utils::URLencode(state_name))
  for (k in 1:3) {
    r <- tryCatch(httr::GET(u, httr::timeout(90)), error = function(e) NULL)
    if (!is.null(r) && httr::status_code(r) == 200) {
      j <- tryCatch(jsonlite::fromJSON(httr::content(r, "text", encoding = "UTF-8")),
                    error = function(e) NULL)
      if (is.data.frame(j) && nrow(j) && "Symbol" %in% names(j)) return(toupper(trimws(j$Symbol)))
      return(NULL)
    }
    Sys.sleep(0.5 * k)
  }
  NULL
}

gsat_states <- tryCatch({
  r <- httr::GET("https://plantsservices.sc.egov.usda.gov/api/plantsDownload/GetGSATStateList", httr::timeout(40))
  if (httr::status_code(r) == 200) jsonlite::fromJSON(httr::content(r, "text", encoding = "UTF-8"))$State else character(0)
}, error = function(e) character(0))
state_names_to_try <- intersect(if (length(gsat_states)) gsat_states else names(STATE_ABBR), names(STATE_ABBR))

cat("state distribution: attempting", length(state_names_to_try), "states ...\n")
SYM_STATES <- new.env(parent = emptyenv()); covered_states <- character(0)
for (sn in state_names_to_try) {
  ab <- unname(STATE_ABBR[sn]); ss <- fetch_state_symbols(sn)
  if (is.null(ss) || !length(ss)) { cat(sprintf("  %-16s uncovered\n", sn)); next }
  covered_states <- c(covered_states, ab)
  ss_acc <- toupper(trimws(unname(ifelse(ss %in% names(synonyms), synonyms[ss], ss))))
  for (s in unique(ss_acc)) SYM_STATES[[s]] <- c(SYM_STATES[[s]], ab)
  cat(sprintf("  %-16s %5d symbols (%s)\n", sn, length(ss), ab)); Sys.sleep(0.2)
}
covered_states <- sort(unique(covered_states))
states_l48_for <- function(sym) { v <- SYM_STATES[[sym]]
  if (is.null(v) || !length(v)) NA_character_ else paste(sort(unique(v)), collapse = ";") }

authority$states_l48 <- vapply(authority$accepted_symbol, states_l48_for, character(1))
out$authority <- authority
out$states_covered <- covered_states
out$states_fetchedAt <- format(Sys.time(), "%Y-%m-%d")
saveRDS(out, AUTH, compress = "xz")
cat(sprintf("\nstates_l48 merged: %d states covered (%s); %d of %d symbols carry a state distribution\n",
  length(covered_states), paste(covered_states, collapse = ","),
  sum(!is.na(authority$states_l48)), nrow(authority)))
