# ===========================================================================
# build_plant_states.R — augment data/authority/plants_lookup.rds with a per-symbol
# `states_l48` field (the US state codes each species is recorded for) for the FULL
# country. USDA PLANTS' own state-checklist API (GetGSATByState) only serves 18
# states and its full-distribution search times out server-side, so we source the
# distribution from GBIF occurrence facets instead, which cover every state.
#
# Two steps (build-only; nothing here enters global.R / the rsconnect manifest):
#   1. scripts/fetch_gbif_states.py harvests raw (symbol, gbif_key, states) into a
#      TSV (run after build_plant_authority.R emits the species list).
#   2. THIS script cleans the raw GBIF state names to USPS codes and merges them.
#
# Permissive by design (owner steer: flag obvious errors only, not range-edge
# natives): a species is "plausible" in any state GBIF records it in (>=2 records,
# the python threshold). `states_covered` is the full set of US states/territories,
# so the app runs the state-plausibility demotion everywhere (no 18-state gap).
#
#   Source: GBIF.org occurrence facets (CC-BY). USDA PLANTS nativity is still the
#   authority for native-vs-introduced; GBIF only supplies WHERE it occurs.
# ===========================================================================
suppressWarnings(suppressMessages({ library(dplyr) }))
ROOT <- "C:/Users/tsgil/OneDrive/Documents/VGS - R/NEON-Plant-Diversity"
AUTH <- file.path(ROOT, "data/authority/plants_lookup.rds")
RAW  <- if (length(commandArgs(TRUE))) commandArgs(TRUE)[1] else "C:/temp/gbif/states_raw.tsv"

# full US state / territory name -> USPS, matched case-insensitively. Combined GBIF
# strings ("New Mexico / Texas") are split on "/"; junk ("unknown") drops out.
NAME2AB <- c(
  "ALABAMA"="AL","ALASKA"="AK","ARIZONA"="AZ","ARKANSAS"="AR","CALIFORNIA"="CA",
  "COLORADO"="CO","CONNECTICUT"="CT","DELAWARE"="DE","FLORIDA"="FL","GEORGIA"="GA",
  "HAWAII"="HI","IDAHO"="ID","ILLINOIS"="IL","INDIANA"="IN","IOWA"="IA","KANSAS"="KS",
  "KENTUCKY"="KY","LOUISIANA"="LA","MAINE"="ME","MARYLAND"="MD","MASSACHUSETTS"="MA",
  "MICHIGAN"="MI","MINNESOTA"="MN","MISSISSIPPI"="MS","MISSOURI"="MO","MONTANA"="MT",
  "NEBRASKA"="NE","NEVADA"="NV","NEW HAMPSHIRE"="NH","NEW JERSEY"="NJ","NEW MEXICO"="NM",
  "NEW YORK"="NY","NORTH CAROLINA"="NC","NORTH DAKOTA"="ND","OHIO"="OH","OKLAHOMA"="OK",
  "OREGON"="OR","PENNSYLVANIA"="PA","RHODE ISLAND"="RI","SOUTH CAROLINA"="SC",
  "SOUTH DAKOTA"="SD","TENNESSEE"="TN","TEXAS"="TX","UTAH"="UT","VERMONT"="VT",
  "VIRGINIA"="VA","WASHINGTON"="WA","WEST VIRGINIA"="WV","WISCONSIN"="WI","WYOMING"="WY",
  "DISTRICT OF COLUMBIA"="DC","PUERTO RICO"="PR","VIRGIN ISLANDS"="VI",
  "U.S. VIRGIN ISLANDS"="VI","AMERICAN SAMOA"="AS","GUAM"="GU")

clean_states <- function(s) {
  if (is.na(s) || !nzchar(s) || s == "NOMATCH") return(NA_character_)
  parts <- unlist(strsplit(s, "[|/]"))                 # split combined + multi
  parts <- toupper(trimws(gsub("\\s+", " ", parts)))
  ab <- unname(NAME2AB[parts])
  ab <- ab[!is.na(ab)]
  if (!length(ab)) return(NA_character_)
  paste(sort(unique(ab)), collapse = ";")
}

raw <- read.table(RAW, sep = "\t", header = FALSE, quote = "", comment.char = "",
                   stringsAsFactors = FALSE, fill = TRUE,
                   col.names = c("sym", "key", "states"))
raw$states_l48 <- vapply(raw$states, clean_states, character(1))

out <- readRDS(AUTH)
authority <- out$authority
authority$states_l48 <- raw$states_l48[match(authority$accepted_symbol, raw$sym)]
out$authority <- authority
# Every US state is now covered by GBIF, so the app's state-plausibility check runs
# at all sites (no 18-state gap). Record the covered set as the full union seen.
out$states_covered  <- sort(unique(unlist(strsplit(na.omit(authority$states_l48), ";"))))
out$states_source   <- "GBIF occurrence facets (CC-BY), >=2 records/state"
out$states_fetchedAt <- format(Sys.time(), "%Y-%m-%d")
saveRDS(out, AUTH, compress = "xz")

cat(sprintf("states_l48 merged from GBIF: %d of %d symbols carry a distribution; %d states/territories covered (%s)\n",
  sum(!is.na(authority$states_l48)), nrow(authority),
  length(out$states_covered), paste(out$states_covered, collapse = ",")))
