# ===========================================================================
# build_expected_lists.R — precompute each NEON site's EXPECTED plant community
# from the NRCS Ecological Site (the EcoPlot recipe), via the raw Soil Data Access
# (SDA) REST API — no soilDB dependency. Writes data/expected/<SITE>.rds +
# data/expected/provenance.rds. Build-only (httr/jsonlite never enter global.R /
# the rsconnect manifest). All sources US-gov public domain (USDA-NRCS).
#   point(lng lat) -> mukey -> dominant component's ecoclassid -> coeplants ref list
# Re-runnable: refetches only sites missing/failed. See docs/_mlra_qc_plan.md.
# ===========================================================================
suppressPackageStartupMessages({ library(httr); library(jsonlite) })

# Resolve the repository independently of the caller's working directory. An
# explicit override supports unusual launchers; normal Rscript use resolves from
# this file, with an upward search from getwd() as an interactive fallback.
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
      if (file.exists(file.path(current, "R", "site_metadata.R")) &&
          file.exists(file.path(current, "scripts", "build_expected_lists.R"))) {
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
EXPECTED_DIR <- file.path(REPO_ROOT, "data", "expected")
SITE_DIR <- file.path(REPO_ROOT, "data", "sites")
source(file.path(REPO_ROOT, "R", "site_metadata.R"))   # neon_sites (site, lat, lng)
dir.create(EXPECTED_DIR, showWarnings = FALSE, recursive = TRUE)

sda <- function(q) {
  r <- tryCatch(httr::POST("https://sdmdataaccess.sc.egov.usda.gov/Tabular/post.rest",
    body = list(query = q, format = "JSON+COLUMNNAME"), encode = "json", httr::timeout(60)),
    error = function(e) NULL)
  if (is.null(r) || httr::status_code(r) != 200) return(NULL)
  tab <- tryCatch(jsonlite::fromJSON(httr::content(r, "text", encoding = "UTF-8"))$Table, error = function(e) NULL)
  if (is.null(tab) || nrow(tab) < 2) return(NULL)
  df <- as.data.frame(tab[-1, , drop = FALSE], stringsAsFactors = FALSE); names(df) <- tab[1, ]; df
}

expected_for_site <- function(lng, lat) {
  mk <- sda(sprintf("SELECT mukey FROM SDA_Get_Mukey_from_intersection_with_WktWgs84('point(%f %f)')", lng, lat))
  if (is.null(mk)) return(list(status = "sda_failed"))
  mukey <- mk$mukey[1]
  ec <- sda(sprintf("SELECT TOP 1 ce.ecoclassid, ce.ecoclassname, c.comppct_r
    FROM component c LEFT JOIN coecoclass ce ON ce.cokey=c.cokey
    WHERE c.mukey='%s' AND ce.ecoclassid IS NOT NULL ORDER BY c.comppct_r DESC", mukey))
  if (is.null(ec) || !nrow(ec)) return(list(status = "no_esd", mukey = mukey))
  eco <- ec$ecoclassid[1]
  pl <- sda(sprintf("SELECT cp.plantsym, cp.plantsciname, cp.plantcomname, cp.rangeprod
    FROM coecoclass ce INNER JOIN coeplants cp ON cp.cokey=ce.cokey
    WHERE ce.ecoclassid='%s' AND cp.plantsym IS NOT NULL", eco))
  if (is.null(pl) || !nrow(pl)) return(list(status = "no_plants", ecoclassid = eco, ecosite_name = ec$ecoclassname[1]))
  pl$rangeprod <- suppressWarnings(as.numeric(pl$rangeprod))
  # dedupe to one row per symbol (keep the max-production row), tag aggregate/genus codes
  pl <- pl[order(-ifelse(is.finite(pl$rangeprod), pl$rangeprod, -1)), ]
  pl <- pl[!duplicated(pl$plantsym), ]
  agg <- grepl("^[0-9]", pl$plantsym) | is.na(pl$plantsciname) | !grepl("[A-Za-z]+ [a-z]", pl$plantsciname %||% "")
  # DOMINANCE — the core species that make up the top HALF of the reference
  # community's production (a cumulative-share rule, list-length-invariant: adding
  # trace associates never changes the set, unlike a raw percentile). This is the
  # "dominant core", the few heavy-hitters that define the site. rangeprod is NRCS
  # air-dry production (lb/ac) at normal precip (NRPH basis). FOREST ESDs carry no
  # per-species production in coeplants (canopy dominants are trees, scored by site
  # index / canopy, not lb/ac) — so we honestly record dominance_basis="none"
  # rather than mislabel an understory associate as dominant. (Per-species forest
  # canopy dominants are a documented fast-follow.)
  fin <- !agg & is.finite(pl$rangeprod) & pl$rangeprod > 0
  is_dom <- rep(FALSE, nrow(pl)); dom_basis <- "none"; dom_cut <- NA_real_
  dom_rule <- "the core species comprising the top 50% of reference-community production (NRCS air-dry lb/ac, normal precip)"
  if (any(fin)) {
    dom_basis <- "rangeland_production"
    tot <- sum(pl$rangeprod[fin])
    cum <- cumsum(ifelse(fin, pl$rangeprod, 0)) / tot     # pl is production-desc -> finite rows contiguous at top
    crossed <- which(fin & cum >= 0.5)[1]; if (is.na(crossed)) crossed <- which(fin)[1]
    is_dom <- fin & seq_len(nrow(pl)) <= crossed
    dom_cut <- pl$rangeprod[crossed]
  }
  ref <- data.frame(plantsym = toupper(trimws(pl$plantsym)), sciname = pl$plantsciname,
    comname = pl$plantcomname, rangeprod = pl$rangeprod,
    is_aggregate = agg, is_dominant = is_dom, stringsAsFactors = FALSE)
  # MLRA / geoUnit = the 4-char block after the R/F/any single-letter prefix
  # ("R041XC318AZ" -> "041X", "F144BY501ME" -> "144B"); leave non-standard codes
  # (e.g. alpine "G2401x") as-is, the UI just won't deep-link those.
  mlra <- sub("^[A-Z]?([0-9]{3}[A-Z]).*", "\\1", eco)
  list(status = "ok", ecoclassid = eco, ecosite_name = ec$ecoclassname[1],
       mlra = mlra, source = "esd",
       dominance_basis = dom_basis, dom_rule = dom_rule, dom_cut = dom_cut,
       reference_species = ref)
}
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || (length(a)==1 && is.na(a))) b else a

# Default: fan out to every bundled site (data/sites/*.rds). SRER first (house default).
# Optional CLI subset: Rscript scripts/build_expected_lists.R SRER JORN ...
.bundled <- sort(sub("\\.rds$", "", list.files(SITE_DIR, pattern = "\\.rds$")))
.bundled <- c("SRER", setdiff(.bundled, "SRER"))
SITES <- if (length(commandArgs(TRUE))) commandArgs(TRUE) else .bundled
prov <- list()
for (s in SITES) {
  row <- neon_sites[neon_sites$site == s, ]; if (!nrow(row)) { cat(s, "no coords\n"); next }
  f <- file.path(EXPECTED_DIR, paste0(s, ".rds"))
  res <- tryCatch(expected_for_site(row$lng[1], row$lat[1]), error = function(e) list(status = paste("err:", conditionMessage(e))))
  if (identical(res$status, "ok")) {
    saveRDS(res, f)
    cat(sprintf("%-5s OK  %s  %-34s  %d ref spp (%d dominants, %d aggregate)\n", s, res$ecoclassid,
      substr(res$ecosite_name,1,34), nrow(res$reference_species), sum(res$reference_species$is_dominant),
      sum(res$reference_species$is_aggregate)))
  } else cat(sprintf("%-5s %s\n", s, res$status))
  prov[[s]] <- data.frame(site = s, status = res$status,
    ecoclassid = res$ecoclassid %||% NA, n_expected = if (!is.null(res$reference_species)) nrow(res$reference_species) else 0L)
}
saveRDS(do.call(rbind, prov), file.path(EXPECTED_DIR, "provenance.rds"))
cat("\nprovenance written; sites done:", length(prov), "\n")
