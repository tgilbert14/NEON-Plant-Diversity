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
setwd("C:/Users/tsgil/OneDrive/Documents/VGS - R/NEON-Plant-Diversity")
source("R/site_metadata.R")   # neon_sites (site, lat, lng)
dir.create("data/expected", showWarnings = FALSE, recursive = TRUE)

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
  # dedupe to one row per symbol (max production), tag aggregates vs real species
  pl <- pl[order(-ifelse(is.finite(pl$rangeprod), pl$rangeprod, -1)), ]
  pl <- pl[!duplicated(pl$plantsym), ]
  agg <- grepl("^[0-9]", pl$plantsym) | is.na(pl$plantsciname) | !grepl("[A-Za-z]+ [a-z]", pl$plantsciname %||% "")
  cut <- suppressWarnings(stats::quantile(pl$rangeprod[!agg], 0.8, na.rm = TRUE))
  ref <- data.frame(plantsym = toupper(trimws(pl$plantsym)), sciname = pl$plantsciname,
    comname = pl$plantcomname, rangeprod = pl$rangeprod,
    is_aggregate = agg, is_dominant = !agg & is.finite(pl$rangeprod) & pl$rangeprod >= (if (is.finite(cut)) cut else Inf),
    stringsAsFactors = FALSE)
  list(status = "ok", ecoclassid = eco, ecosite_name = ec$ecoclassname[1],
       mlra = sub("^R?([0-9]{3}[A-Z]).*", "\\1", eco), source = "esd", reference_species = ref)
}
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || (length(a)==1 && is.na(a))) b else a

# MVP set first (SRER first, AZ + a desert/grassland/forest spread to prove the pattern)
SITES <- if (length(commandArgs(TRUE))) commandArgs(TRUE) else c("SRER","JORN","KONZ","CPER","HARV")
prov <- list()
for (s in SITES) {
  row <- neon_sites[neon_sites$site == s, ]; if (!nrow(row)) { cat(s, "no coords\n"); next }
  f <- sprintf("data/expected/%s.rds", s)
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
saveRDS(do.call(rbind, prov), "data/expected/provenance.rds")
cat("\nprovenance written; sites done:", length(prov), "\n")
