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

resolve_repo_root <- function() {
  override <- trimws(Sys.getenv("PDE_REPO_ROOT", ""))
  script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  starts <- character()
  if (nzchar(override)) starts <- c(starts, override)
  if (length(script_arg)) {
    script_file <- sub("^--file=", "", script_arg[[1L]])
    starts <- c(starts, dirname(normalizePath(script_file, winslash = "/", mustWork = TRUE)))
  }
  starts <- c(starts, getwd())
  for (start in unique(starts)) {
    current <- normalizePath(start, winslash = "/", mustWork = TRUE)
    repeat {
      if (file.exists(file.path(current, "data", "sites")) &&
          file.exists(file.path(current, "scripts", "build_plant_authority.R"))) {
        return(current)
      }
      parent <- dirname(current)
      if (identical(parent, current)) break
      current <- parent
    }
  }
  stop(
    "Could not locate the NEON-Plant-Diversity repository. Set PDE_REPO_ROOT explicitly.",
    call. = FALSE
  )
}

REPO_ROOT <- resolve_repo_root()
SITE_DIR <- file.path(REPO_ROOT, "data", "sites")
EXPECTED_DIR <- file.path(REPO_ROOT, "data", "expected")
AUTHORITY_DIR <- file.path(REPO_ROOT, "data", "authority")
dir.create(AUTHORITY_DIR, showWarnings = FALSE, recursive = TRUE)
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || (length(a) == 1 && is.na(a))) b else a

# every bundled site by default (the authority is shared suite-wide); optional CLI subset
.bundled <- sort(sub("\\.rds$", "", list.files(SITE_DIR, pattern = "\\.rds$")))
SITES <- if (length(commandArgs(TRUE))) commandArgs(TRUE) else .bundled

# union of observed species-level symbols + non-aggregate reference symbols
syms <- character(0)
for (s in SITES) {
  b <- tryCatch(readRDS(file.path(SITE_DIR, paste0(s, ".rds"))), error = function(e) NULL)
  if (!is.null(b)) {
    occ <- b$occ; sp <- occ[occ$is_species %in% TRUE & !is.na(occ$taxonID), ]
    syms <- c(syms, toupper(trimws(sp$taxonID)))
  }
  e <- tryCatch(readRDS(file.path(EXPECTED_DIR, paste0(s, ".rds"))), error = function(e) NULL)
  if (!is.null(e) && !is.null(e$reference_species)) {
    rs <- e$reference_species; syms <- c(syms, toupper(trimws(rs$plantsym[!(rs$is_aggregate %in% TRUE)])))
  }
}
syms <- sort(unique(syms[nzchar(syms)]))
cat("unique symbols to resolve:", length(syms), "\n")

CACHE <- file.path(AUTHORITY_DIR, "_profile_cache.rds")
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

# assemble the shipped artifact ---------------------------------------------
df <- do.call(rbind, cache[intersect(syms, names(cache))])
df <- df[!is.na(df$accepted_symbol) & nzchar(df$accepted_symbol), , drop = FALSE]
authority <- df[!duplicated(df$accepted_symbol),
  c("accepted_symbol","sci_name","nativity_usda","growth_habit","duration")]
rownames(authority) <- NULL
syn <- df[df$queried != df$accepted_symbol, , drop = FALSE]
synonyms <- stats::setNames(syn$accepted_symbol, syn$queried)
out <- list(authority = authority, synonyms = synonyms,
  n_symbols = length(syms), n_resolved = nrow(authority), n_synonyms = length(synonyms),
  n_failed = length(failed), built_for = SITES, fetchedAt = format(Sys.time(), "%Y-%m-%d"))
saveRDS(out, file.path(AUTHORITY_DIR, "plants_lookup.rds"), compress = "xz")
cat(sprintf("\nplants_lookup.rds: %d accepted symbols, %d synonyms, %d nativity-typed | failed %d\n",
  nrow(authority), length(synonyms), sum(!is.na(authority$nativity_usda)), length(failed)))
cat("nativity breakdown:\n"); print(table(authority$nativity_usda, useNA = "ifany"))
