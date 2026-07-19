> **Historical implementation plan — superseded for release decisions.** This file records earlier design intent and may contain stale source, authority, estimator, UI, or validation claims. Use [SCIENCE-CONTRACT.md](SCIENCE-CONTRACT.md) for the normative analysis rules and [BUILD-TEST-HANDOFF.md](BUILD-TEST-HANDOFF.md) for the current release gates. Do not treat unchecked items or historical findings below as implemented or validated.

The two load-bearing facts check out: `latest_snapshot()` and `species_level_only()` exist as described, `NATIVITY_COLS`/`OKABE_ITO` are present, and `neon_sites` carries lat/lng for all 46 sites with SRER at 31.9107, -110.8355 (AZ, D14). Now I have what I need to write the design.

---

# Expected-vs-Observed Plant QC — Buildable Design

NEON Plant Diversity Explorer (DP1.10058.001) · R/Shiny · bundle-only · Posit Connect Cloud · default site **SRER**

The three research passes converge on one design. They disagree on the *expected-list source* (Jornada/Atlas: NRCS Ecological Site reference community via SDA `coeplants`; Sarah: USDA PLANTS state checklist). The resolution below uses **both, layered**: SDA ecological-site list as the fine-grained "expected" (the EcoPlot recipe), USDA PLANTS state distribution + nativity as the **range/nativity authority** for the genuine QC flags. Everything precomputes to `.rds`; the deployed app makes zero federal API calls.

---

## 1. THE DATA SPINE

### (a) Each NEON site → MLRA + ecological site

| Need | Source | Method | License |
|---|---|---|---|
| lat/lng → MLRA | NRCS MLRA 2022 v5.2 GeoJSON (already bundled in EcoPlot at `VGS-Mock/src/app/vendor/mlra-us.json`) | Build-time `sf::st_join` (route b) **or** port EcoPlot's ray-cast (`53-mlra-offline.js`, route a). Route b is one `st_intersects` call — prefer it; `sf` is build-only. | USDA-NRCS public domain |
| lat/lng → mukey → component → `ecoclassid` | NRCS Soil Data Access (SDA) `https://sdmdataaccess.sc.egov.usda.gov/Tabular/post.rest` | `soilDB::SDA_spatialQuery(point, what="mukey")` → `soilDB::get_SDA_coecoclass(mukey=...)`. WKT order is `point(LNG LAT)`. Buffer ~1.3 km and UNION eco-sites so one dominant component doesn't undercount (EcoPlot `epFetchNearbySoils` pattern). | public domain |

### (b) Expected species list (per site)

| Tier | Source | Method | When used |
|---|---|---|---|
| **PRIMARY** | SDA `coeplants` (Component Existing Plants) for each `ecoclassid` | `SELECT DISTINCT plantsym, plantsciname, plantcomname, rangeprod ...` over the unioned eco-sites (EcoPlot recipe, live-tested 160+ spp for Tucson) | the comparison list; `plantsym` = the join key |
| **FALLBACK** | MLRA union via `soilDB::get_EDIT_ecoclass_by_geoUnit(geoUnit=mlra, catalog="esd")` then union reference communities | when a point lands on a map unit with no correlated ESD | tag `source = "mlra_union"` |
| **HEADER ONLY** | EDIT `edit.sc.egov.usda.gov/services/descriptions/esd/{geoUnit}/{ecoclassid}.json` → `generalInformation.dominantSpecies` | a 4–6 species "Reference community: creosote / triangle bursage / …" headline | site card header, NOT the list |

> **Load-bearing URL note:** EDIT moved to `edit.sc.egov.usda.gov` (NRCS-hosted, April 2026). Do not hardcode the old `edit.jornada.nmsu.edu`; let `soilDB::make_EDIT_service_URL()` build it. Re-verify the live JSON shape for a *real resolved SRER ecoclassid* before quoting any field name in a UI label — the research probe ecoclassid 404'd (it was a guess).

### (c) Nativity / growth-habit / range authority

| Field | Source | Method | License |
|---|---|---|---|
| nativity (regional, L48) + growth habit + duration | USDA PLANTS per-profile API `plantsservices.sc.egov.usda.gov/api/PlantProfile?symbol=SYM` (verified live 2026-06-19) | build-time `httr2` per accepted symbol; throttle ~0.3 s, `req_retry(3)`, `req_timeout` | **public domain** ("not copyrighted and is free for any use") |
| synonym → accepted symbol | NEON taxonomy API `data.neonscience.org/api/v0/taxonomy?taxonTypeCode=PLANT` | pull once (~93.7k rows), map `taxonID → acceptedTaxonID` | NEON CC0/CC-BY |
| state present/absent distribution | USDA PLANTS distribution endpoint | **UNRESOLVED** — `MapCoordinates` returns only territory bounding boxes, not per-state present/absent. `HasDistributionData=true` confirms it exists behind a separate endpoint. **VERIFY exact URL/shape before building the out-of-range flag.** | public domain |

**Do NOT bundle:** BONAP maps (copyrighted), GBIF wrapper of PLANTS (CC-BY, attribution burden), Zenodo DwCA mirror (License Not Specified), POWO/WCVP (unconfirmed). Pull USDA **directly** to inherit clean PD.

### Build-time precompute → what `.rds` to ship

Run under R-4.1.1 in `scripts/` (keep `sf`/`httr2`/`jsonlite`/`soilDB` build-only — never in `global.R`'s `library()` or the rsconnect manifest; mirror the `.NEON_PKG` anti-pin trick). All artifacts committed so deploys reproduce without re-hitting SDA.

| Artifact | Shape | Notes |
|---|---|---|
| `data/site_mlra.rds` | 46 rows: `site, mlra, mlraSym, mlraName` | sub-KB |
| `data/expected/<SITE>.rds` | `list(ecoclassid, ecosite_name, mlra, source[esd\|mlra_union], reference_species = tibble(plantsym, sciname, comname, rangeprod, is_dominant))` | the comparison list |
| `data/authority/plants_lookup.rds` | `tibble(accepted_symbol, sci_name, family, growth_habit, duration, usda_nativity_L48, states[])` over the union of all observed symbols | shared across sites; small (low single-digit MB) |
| `data/expected/provenance.rds` | per-site: `ecoclassid, n_expected, n_with_usable_symbol, fetchedAt, status[ok\|failed\|no_esd]` | distinguish "SDA failed" from "genuinely no reference species" — the difference between an honest empty state and a fake "0% detected" |

**Robustness:** wrap each site in `tryCatch` + `httr::timeout(~30s)` + retry-with-backoff (SDA times out even on good connections). A failed site = "expected list unavailable" (null), not empty. Re-runs refetch only missing/failed sites.

One build gap to close: the current bundle's `occ` does **not** carry `acceptedTaxonID` (verified FALSE). Add it in `bundle_plant_data.R` from the NEON taxonomy table so synonyms collapse before the join.

---

## 2. THE QC + FEATURE SET

Two categories, kept visually distinct so users never read ecology as error. Each flag is a **clickable row → downloadable CSV** (the suite's QC-flag pattern). Severity colors reuse `NATIVITY_COLS`/`OKABE_ITO`: **review = clay/rust `#B85C38`**, **completeness = neutral `#9AA39A`**, **confirmed = green `#2E7D32`**. **Nothing in the completeness category is ever red.**

### TRUE QC (real data-quality signals — the "verify" lane)

**Flag 1 — Taxonomic rank too coarse / morphospecies burden** · severity **MEDIUM, surfaced FIRST**
*Rule:* share of records and of cover resolved only to genus/family/kingdom (`2PLANT` = unknown plant). Computed from `taxonRank` already in `occ`. SRER: genus 5,851 / kingdom 1,209 / family 723 of ~45k rows — this is the dominant real story.
*Why first:* if users don't see the coarse-ID rate, they misread coarse IDs as range/nativity errors. This frames every other flag.
*False-positive note:* none — it's a direct count, not an inference. Lean on NEON's own `identificationQualifier`/`morphospeciesID`; don't invent a parallel uncertainty model.

**Flag 2 — Nativity mismatch (NEON vs USDA L48)** · severity **HIGH** · *cheapest high-value flag*
*Rule:* NEON `nativeStatusCode` (N/I/NI/UNK) disagrees with USDA `usda_nativity_L48` for that species. Both categorical, keyed by symbol → zero geography work.
*False-positive note:* nativity is **regional** — join on STATE, not globally; a species native in NM may be introduced in HI. Treat NEON `NI` and `UNK` as **non-conflicting**. NEON is location-specific, USDA L48 is regional — a true scale mismatch, not a contradiction. Document this inline.

**Flag 3 — Observed outside documented range** · severity **HIGH** · *gated on (c) verifying the distribution endpoint*
*Rule:* a species-level NEON record whose taxon is absent from USDA's state distribution for the site's state. Strong misID / data-entry candidate.
*False-positive note:* fire **only** for `taxonRank` species/subspecies/variety (never genus/family); exclude introduced/adventive taxa (ranges expand); label **"review," never "error"** — county/state gaps in PLANTS are real. **Ship MVP without this** if the endpoint isn't confirmed.

**Flag 4 — Cover summing implausibly** · severity **LOW-MEDIUM**
*Rule:* per `(plotID, subplotID, scale, year, bout)` summed `percentCover` exceeding a sane ceiling. Multi-layer canopy legitimately exceeds 100%, so flag **extreme** outliers only (e.g. >300% in 1 m²) as entry error.
*False-positive note:* set the threshold high; this is a sanity backstop, not a primary signal.

### ECOLOGICAL EXPECTATION (completeness — never an error)

**Flag 5 — Expected dominant absent** · severity **LOW = COMPLETENESS**
*Rule:* an ESD reference-community dominant (high `rangeprod`/`is_dominant`) not observed at the site. Sort bucket B by `rangeprod` so the "big reference species you'd most expect to hit" float to the top.
*Honesty guard (the single most important sentence on the feature):* NEON samples ~400 m²/plot × ~30–35 plots; an ESD lists the whole ecological site's potential vegetation under *reference* conditions. Absence is overwhelmingly **non-detection (small area)** or a **legitimate state-transition** (SRER is a classic mesquite/shrub-encroachment STM site). **Frame as completeness or as an ecological pattern — never red, never "missing/error."** The reverse over-claim (treating the ESD as truth the data must match) is scientifically wrong.

### The three buckets (the hero framing — completeness, not correctness)

- **A · Expected & Observed** → confirmation. Hero metric: **"X of Y reference species detected (Z%)."** Green.
- **B · Expected but Absent** → completeness gap, sorted by `rangeprod`. Neutral. Caption: *"not detected in NEON's ~400 m² sample."*
- **C · Observed but NOT Expected** → the genuine review lane. Split: **Introduced** (invasion signal → ties to the existing invasion lens) vs **Native-not-in-reference** (range edge / mapping mismatch / misID). Clay/rust.

### Headline value-box row

(a) overlap % · (b) dominants observed (k of n) · (c) review-worthy count (Flags 2+3 combined) · (d) **% of records resolved to species** (the morphospecies-honesty number). Plus published **match rate**: % of NEON species symbols that resolved to a USDA accepted symbol, and % of the reference list with a usable species-level `plantsym` — name-join metrics always ship their match rate.

---

## 3. TAXONOMY MATCHING

**The hard problem is already solved — this is a symbol join, not fuzzy matching.** NEON's plant taxonomy *is* USDA PLANTS (`dwc:nameAccordingToID = plants.usda.gov`), so `occ$taxonID` values (MAPI, CHPO12, ERLE) *are* USDA PLANTS Symbols — the same `plantsym` SDA returns and the same key USDA's API takes.

Reconciliation pipeline (exact, not fuzzy):
1. **Collapse synonyms first.** Map `taxonID → acceptedTaxonID` via the NEON taxonomy table (verified: ABAB2 → ABPR3). Build the authority lookup at the **accepted** symbol — otherwise a NEON synonym misses the USDA join and you over-report "unmatched" (a fake QC signal).
2. **Restrict to species level.** Run the comparison only on `species_level_only(latest_snapshot(occ))` — same one-survey-per-plot, bout-aware snapshot every other site metric uses (no pseudoreplication, no disagreement with the hero count). Do **not** use the year-pooled `occ`.
3. **Join** upper-cased/trimmed `acceptedTaxonID` to `reference_species$plantsym` and to `plants_lookup$accepted_symbol`.
4. **Exclude unmatched coarse taxa from range/nativity flags entirely** — don't flag what you couldn't resolve. SDA `coeplants` also carries aggregate codes (`2FA`, `2SD`, genus-level, null `plantsciname`); drop these so they don't inflate buckets B/C.
5. **Publish the match rate** on the methods note.

`taxize`/TNRS and the old `plantsdb.xyz` API are dead ends (verified defunct) — not needed.

---

## 4. UX

**Location:** a new top-level `nav_panel` — name it **"Expected vs Observed"** (or "Completeness", `bs_icon("clipboard-check")`) placed between **"Native vs Invasive"** and **"Environment"**, modeled on the existing card / `insight_banner` / `info_pop` chrome (Herbarium theme). It is a site-scoped page, not a plant card — the comparison is a site-level set operation.

**Layout (top → bottom):**
1. **Headline value-box row** — the four numbers from §2, with the small-plot caveat baked into the subtitle so it auto-vanishes from screenshots (reuse the `ctx_note`/amber-callout pattern).
2. **Reference ecological site header** — one line: `ecoclassid` + name + MLRA + a `source` badge (`esd` | `mlra_union`), with the EDIT URL as the citation link and access date. Optional EDIT dominant-species headline.
3. **Three collapsible sections** (capped DT tables, 10–12 rows + "Other (n)" per the report-design ethic), each row click-through to a downloadable CSV, each with a `plants.sc.egov.usda.gov/home/plantProfile?symbol=<plantsym>` link-out (PLANTS has no live API — link-out only):
   - "Matches the reference flora" (green)
   - "Observed but not in reference — review" (clay; Introduced vs Native-not-in-reference)
   - "Expected but not detected — completeness — NEON sampled ~400 m²" (neutral)
4. **One advisory callout max:** *"X% of records are coarser than species — interpret nativity/range flags after resolving these."*

**Plain-English framing for non-tech users** (state it literally on the page):
> *"Expected = the plants NRCS says this kind of soil and climate can support (its ecological site), cross-checked against USDA's record of what grows in [state]. NEON samples a small plot area at peak greenness, so a species expected but not found usually means it wasn't in the sampled patch — not that anything is wrong. The 'review' list is where it's worth a second look: a species USDA doesn't record in this state, or a native/introduced label that disagrees with USDA."*

**Default everything to SRER** (lookup at 31.9107, -110.8355; MLRA 41/041X; D14). The worked example: high morphospecies/coarse-rank share (the honest headline), strong native dominance, and a shrub-vs-grass-dominant completeness narrative framed as STM departure, not error. SRER also exercises the bout-aware snapshot (spring + monsoon), so it's the right regression case.

**Map angle (fast-follow):** color the 46 picker markers (`R/map_picker.R`) by MLRA or by `pct_detected` — a derived completeness scalar promoted to a spatial layer (national "which ecoregion, how complete" read). Spot-check AK and PR sites' MLRA hits at build (PR may fall outside CONUS MLRA coverage → handle "no MLRA" as a labeled empty state, not a crash).

---

## 5. MVP vs FAST-FOLLOW

**MVP (smallest valuable build — impact/effort 5/2, ship it):**
- `data/authority/plants_lookup.rds` (growth habit + nativity confirmed-clean; **defer state-range**) + `acceptedTaxonID` added to `occ`.
- `data/expected/<SITE>.rds` for SRER + 3–5 representative sites (SRER, JORN, KONZ, CPER, HARV) to prove the pattern before fanning out to 46.
- `R/expected_qc.R` pure functions on existing recipes:
  - `observed_species(occ)` = `species_level_only(latest_snapshot(occ))`
  - `expected_vs_observed(occ, expected)` → 3 buckets + overlap %
  - `flag_nativity_mismatch()`, `flag_coarse_rank()`, `flag_cover_sum()`, `missing_dominants()`
- The tab with headline row + 3 bucket tables, SRER default.
- **Flags shipped:** 1 (coarse rank), 2 (nativity mismatch), 4 (cover sum), 5 (completeness). **Flag 3 (out-of-range) held** until the distribution endpoint is verified.

**Fast-follow (in order):**
1. Verify USDA distribution endpoint → ship **Flag 3 (observed-out-of-range)**.
2. Fan out `expected/` to all 46 sites + `provenance.rds` UI states.
3. `site_mlra.rds` → map-marker coloring by MLRA / completeness.
4. EDIT dominant-species header enrichment (build-time pull only).
5. Optional GBIF/BIEN range tie-breaker (low priority — wrong shape, attribution burden).

**Fold into NEONize as a reusable "Expected-vs-Observed QC" pattern:**
The general recipe transfers to any NEON organismal app whose taxonID is a registry symbol with an external "expected for this place" authority. Abstract it as: (1) **build-time location→reference-list join** frozen to `.rds`; (2) **three-bucket framing** (confirmed / completeness-gap / review) with completeness-never-red as a hard rule; (3) **match-rate publishing** on every join; (4) **provenance row** distinguishing fetch-failure from genuine-empty. Document in `docs/neonize-playbook.md` as the "expected-vs-observed QC" module, with SRER as the canonical worked example. Note that this same env-corr-style honesty (claim only what the unit supports) is the through-line tying it to the existing playbook.

---

## 6. OPEN QUESTIONS / LICENSING RISKS TO CONFIRM BEFORE SHIPPING

1. **USDA state-distribution endpoint (load-bearing, blocks Flag 3).** `PlantProfile.MapCoordinates` returns only territory bounding boxes (AK/HI/PR/VI/L48), not per-state present/absent. `HasDistributionData=true` confirms a separate endpoint exists — pin its exact URL/shape before building out-of-range. Until then MVP ships on habit + nativity only.
2. **Real SRER ecoclassid + live EDIT JSON shape.** The research probe ecoclassid 404'd. Resolve the actual `ecoclassid` via SDA at the SRER point, then pull `plant-community-tables` / `descriptions` live to confirm field names before quoting any in a UI label.
3. **SDA reliability at build.** Timeouts are expected. Without retry/backoff + per-site provenance you'll silently ship sites with empty lists that look like "0% detected." The provenance artifact must distinguish failed from empty.
4. **PR / far-AK MLRA coverage.** PR may fall outside CONUS MLRA polygons; spot-check BARR/TOOL/GUAN/LAJA at build. "No MLRA" must be a labeled empty state.

**Licensing — confirmed clean to bundle (US-government public domain):** USDA PLANTS (pulled directly), NRCS SDA/`coeplants`, NRCS MLRA 2022 v5.2, EDIT ESD content. NEON data CC0/CC-BY.
**Confirmed NOT to bundle:** BONAP (copyrighted maps), GBIF republication of PLANTS (CC-BY wrapper — attribution burden; pull USDA direct to keep clean PD), Zenodo DwCA mirror ("License Not Specified"), POWO/WCVP (unconfirmed, over-scoped). If GBIF/BIEN is ever added as a range tie-breaker, per-dataset DOI citations are required.
**Citations to surface in-app:** USDA — *"USDA, NRCS. The PLANTS Database (https://plants.usda.gov). National Plant Data Team, Greensboro, NC."*; NEON DP1.10058.001; EDIT/ESD by `ecoclassid` + access date; "USDA-NRCS" provenance label on MLRA/SDA-derived numbers.

---

**Files to create/touch:** `scripts/build_mlra_lookup.R`, `scripts/build_expected_lists.R`, `scripts/build_expected_flora.R` (USDA authority), `R/expected_qc.R` (new), `R/plant_helpers.R` (reuse only), `scripts/bundle_plant_data.R` (add `acceptedTaxonID`), `ui.R`/`server.R` (new tab), `R/map_picker.R` (fast-follow). Artifacts: `data/site_mlra.rds`, `data/expected/<SITE>.rds`, `data/expected/provenance.rds`, `data/authority/plants_lookup.rds`.
