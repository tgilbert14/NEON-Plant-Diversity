# NEON Plant Diversity Explorer — Data Takeaways & Critical Review

_Suite audit — June 2026. NEON DP1.10058.001 (Plant presence & percent cover)._

## What the data actually shows

All numbers below are recomputed from the shipped bundles (`data/sites/<SITE>.rds`, `data/site_index.rds`, `data/authority/plants_lookup.rds`, `data/env/<SITE>.rds`, `data/expected/`) using the app's own helpers (`latest_snapshot()`, `species_level_only()`, `site_invasion()`).

- **Coverage: 46 NEON terrestrial sites, ~1,574 plot-snapshots, 6–12 survey years/site (median 9.5).** Suite-wide there are **5,777 distinct species-level taxa** (the `scientificName` union over `species_level_only`). Snapshot richness per site spans **20 (STER, a tiny 11-plot reclaimed-field site) to 356 (CLBJ, Texas oak savanna)**, median ~160 species/site.

- **Richness is steeply scale-dependent — the nested species-area curve is the app's most defensible quantity.** At SRER a single 1 m² quadrat holds a mean of **5.5 species** (sd 2.7), rising to **15.2 at 10 m², 26.7 at 100 m², and 42.6 across the 400 m² plot** (n=33 plots, from `species_area_site`). The shape is biome-diagnostic: CLBJ climbs 13.3→52.9, but JORN (Chihuahuan desert) goes only **2.1→5.5** — a near-flat curve that says "this place is genuinely species-poor at every grain," not undersampled.

- **Introduced-cover share (`pct_introduced`) is bimodal, and the worst-invaded sites are the species-poorest.** Median across sites is only **3.5%**, but a hard tail of sites is dominated by exotics: **STER 99.8%, KONA 95.1%, SJER 81.6%, LAJA 78.7%, BLAN 72.0%** — all low-richness (rich = 20, 63, 92, 116, 144). SRER (the demo) sits at **22.2%**, driven almost entirely by *Eragrostis lehmanniana* (Lehmann lovegrass): mean 1 m² cover 4.4% in **21 of 33 plots** (`invasive_watchlist`), exactly the textbook Sonoran-grassland invasion the README advertises.

- **The native/introduced label is honestly qualified — unknown-status share is published, not hidden.** Suite-median **1.35%** of species are Unknown-status, but it reaches **9.5% at KONA**; SRER, GUAN, BARR, several others sit at 0%. The hero KPI also reports an **unknown-cover share** so the invasion % is read with its own caveat. This is the right move: nativity is `nativeStatusCode` collapsed to 3 buckets with `NI`/`UNK`/`NA` → Unknown.

- **Coarse-rank (non-species) IDs carry a real, site-varying fraction of every site's records — median 11% of records, up to 32.7% at YELL** (and 28.4% DSNY, 26.0% TEAK). These genus/family/"plant" records are correctly excluded from species counts via `is_species`, and the Expected-vs-Observed tab surfaces the rate as a "read the comparison as a floor" advisory. SRER is 17.3% coarse.

- **The USDA PLANTS name-join is essentially exact: 5,773 of 5,777 observed species symbols (99.9%) resolve to a USDA accepted symbol** (`data/authority/plants_lookup.rds`: 5,876 accepted symbols, 91 synonyms collapsed, 0 failed fetches). Because NEON `taxonID` *is* the USDA PLANTS symbol, the QC join is a symbol equality, not fuzzy matching — a genuinely strong design choice. USDA nativity is typed for 5,544/5,876 symbols (4,860 Native / 684 Introduced / 332 untyped).

- **Expected-vs-Observed completeness is live for 34 of 46 sites and behaves as completeness, not error.** Median detection is **56.8% of the NRCS reference flora**, ranging **0% (STER) → 100% (ORNL, but only 9 ref spp)**. JORN detects **24% (12/50)** and SRER's reference comparison is bundled. Provenance honestly records why the other 12 sites are absent: **8 `no_esd`, 4 `no_plants`** (not silent zeros). One nativity disagreement at SRER (*Eriochloa acuminata*, NEON=Native / USDA=Introduced) — the kind of range-edge flag the QC lane is built to surface, labeled "review," never "error."

- **The within-site annual richness-vs-climate test is statistically empty — and the app's own permutation null proves it.** Per-site "strongest driver" |r| values look dramatic (KONZ green-up +0.88, SJER precip +0.94, CPER green-up −0.73, MOAB temp −0.78) but on n=6–10 survey years the permutation p-values run **0.07–0.95**, and across all 46 sites **only 1 site (2%) clears p<0.05** for its best-of-12-drivers×3-lags search — right at the false-positive rate you'd expect under the null. SRER's headline green-up r=−0.67 (lag 1, n=7) has **p=0.758**. The signs are incoherent across sites (no directional law). This is the small-n false-negative floor made concrete.

## How it's built

**Source → bundle.** `scripts/bundle_plant_data.R` reads raw `loadByProduct` dumps (`div_1m2Data` + `div_10m2Data100m2Data`), parses quadrat scale from the `subplotID` encoding (`_1_`→1, `_10_`→10, `_100`→100 m²), collapses `nativeStatusCode` to a 3-bucket `nativity`, flags `is_species` (drops `sp.`/`A/B`/genus), and writes `list(occ, ground, meta)` per site plus a rebuilt `data/site_index.rds`. The 1 m² scale is the only one carrying `percentCover`; 10/100 m² are presence-only.

**Bundle → app.** Every site-level metric runs on `latest_snapshot()` — the latest `(year, bout)` per plot, *not* the year-pooled table — so 7 repeat visits of a quadrat aren't double-counted into richness, the cover denominator, or Chao2 incidence units. The cover share itself is de-pseudoreplicated in `plot_species_cover()`: per-species cover is summed then divided by **all** sampled subplots (structural zeros), giving cover a relative-index meaning the app repeatedly flags as "not a share of ground."

**Metric definitions the app renders.** Nested species-area curve (`species_area_site`), Hill q0/q1/q2 on summed 1 m² cover (`hill_site`), incidence-based **Chao2** with a rough CI and a `Q2<3` instability flag (`chao2`; SRER S_obs=124 → Chao2 145.2, 95% CI 126–164.5), an "invasion-pressure" foothold index (introduced spp detectable at 1 m² vs across 400 m²), and the Expected-vs-Observed QC tab (`scripts/build_expected_lists.R` resolves each site's coords → NRCS mukey → dominant component `ecoclassid` → `coeplants` reference list; `scripts/build_plant_authority.R` pulls USDA PLANTS profiles for nativity; both build-time only, never in the deployed manifest). The Environment tab loads per-site monthly env (`data/env/<SITE>.rds`: `precip_mm, temp_c, greenup_pct, flowering_pct, fruiting_pct`) and runs a Spearman × 3-lag search with a 499-rep permutation null.

## Critical findings by lens

### NEONize (suite cohesion / parity / honest-stats machinery)
- **`pct_introduced` definition is single-sourced** through `site_invasion()`, shared by hero, `site_index`, picker, and map — they can never disagree. Severity: **none (model behavior to replicate suite-wide).**
- **Codebook drift in the all-data ZIP.** `plant_codebook()` documents `occ_long.csv` with 12 columns including `bout` and `taxonID`, but the export keeps `intersect(c(...), names(occ))` and `plots.csv` codebook lists 8 columns while the exported `plot_summary` carries more (`n_unknown, dominant, dominant_cover, native_cover, lat, lng`). Issue → fix: regenerate the codebook from the actual exported frames so every shipped column is documented. Severity: **Low.**
- **`fruiting_pct` is sparse and unlabeled as an intensity max.** Only **15 of 121 monthly env rows** at SRER carry `fruiting_pct`; it is a binned-ordinal-intensity max sold as a seed crop. If exposed as an Environment driver, label it a status yes-share on an exact phenophase, or drop it. Severity: **Medium.**

### Ecological (Jornada plant-cover methods)
- **Richness is composition, not productivity — and the data shows the trap.** Cross-site Spearman(richness, `pct_introduced`) is only +0.12, but the five most-invaded sites are all in the bottom third of richness; in drylands a richness uptick can mean exotic forb addition, not more standing biomass. Fix: state explicitly that richness ≠ productivity, and (per the cascade memo) prefer veg-structure basal area as the slow-state floor. Severity: **Medium.**
- **The nested species-area curve is represented correctly** (mean-of-per-plot-curves with ±1 sd and per-area n surfaced) and is the most journal-defensible quantity here — the 1→400 m² scaling is NEON's actual design, not an interpolation. Severity: **none (strength).**
- **Cover is correctly framed as an ocular relative index** (overlapping layers, not %ground) in every banner and the codebook — a reviewer-proof caveat. Keep it. Severity: **none (strength).**

### Data science (Quinn — analysis-ready export)
- **The export is genuinely FAIR-adjacent:** tidy long `occ_long.csv` (one row per taxon×scale), `plots.csv`, `ground_cover.csv`, an Expected-vs-Observed CSV, a `data_dictionary.csv`, and a README documenting the snapshot vs full-record distinction and the cover caveat. Strong. Severity: **none (strength).**
- **Typing/units are mostly documented but the codebook is hand-maintained and out of sync** (see NEONize finding). Also `scale` is renamed to `scale_m2` on export but the in-app `occ` uses `scale` — fine, but the dictionary should note the rename. Fix: derive the dictionary programmatically. Severity: **Low.**
- **No machine-readable provenance/version stamp in the per-site CSV export** (the README has a generated-date string only). Add `fetchedAt` / NEON release tag columns so a downstream user can cite the exact vintage. Severity: **Low.**

### Statistics (small-n honesty)
- **The Environment tab's per-site verdicts are an n=6–10 false-negative/forking-paths regime.** Recomputed permutation p for the strongest driver is 0.07–0.95 at the eight worked sites; suite-wide only 1/46 sites clears p<0.05 (≈ the null rate). The app *does* the right machinery (permutation null over the driver×lag search, "exploratory" labels, an explicit "NOT independent evidence" caption) — the fix is to **lead with the across-site pooled result and gate or grey the per-site OLS fit line on the permutation p** so a strong-looking line never contradicts a non-significant banner. Severity: **High (framing, not math).**
- **Chao2 is the correct incidence estimator for nested-quadrat data** and the `Q2<3` lower-bound flag is honest. Keep it; cite Chao 1987 in the footnote (already referenced). Severity: **none (strength).**
- **The snapshot-not-pooled discipline is exactly right** and prevents the most common plant-diversity inflation error. Severity: **none (strength).**

## Honest-stats & caveats — what this app must NOT be read to claim

- **No site's annual plant signal "tracks" its climate here.** With 6–10 survey years and a 12-driver × 3-lag search, the per-site Environment correlations (however large the r) are not distinguishable from chance — permutation p clears 0.05 at only 1 of 46 sites. The tab is exploratory context, full stop; the in-app captions already say so and should not be softened.
- **`pct_introduced` is a relative cover index, not a fraction of ground.** Cover is ocular and layers overlap. A site at "22% introduced cover" has not lost 22% of its ground to exotics.
- **"Expected but not detected" is completeness, never error.** NEON samples ~400 m²/plot against an NRCS reference community for a whole ecological site; the 24% detection at JORN or 0% at STER reflects sampled-patch area and legitimate state-transitions (shrub-encroached desert grassland), not missing data.
- **Richness is not productivity.** In drylands richness can rise with exotic-forb addition; do not read high richness as ecosystem health or high biomass.
- **Per-plot richness verdicts depend on grain.** A "species-poor" plot at 1 m² (SRER mean 5.5) is not species-poor at 400 m² (42.6) — always state the scale.

## Place in the cascade

This app is the **plant (producer) rung** of the climate → plants → consumers cascade, and the audit sharpens where it can and cannot contribute:

- **What it feeds the cascade honestly:** the *seasonal monthly env machinery already exists in the bundle* (`precip_mm`, `temp_c`, `greenup_pct` per month; SRER cool-season Oct–Mar mean 19.7 mm/mo vs monsoon Jul–Sep 54.3 mm/mo). That is the raw material for the "one move" — a winter/monsoon precip split that flips desert precip→richness — and for the suite's one robust pooled link, **temperature → green-up onset**. The green-up phenophase here (`greenup_pct`, 103/121 SRER months populated) is the same metric that link rides on.
- **What it must NOT contribute:** any per-site annual richness↔climate correlation as a cascade edge. Those are the false-negative regime (p mostly >0.2). The cascade integrator must **pool across sites**, not stack per-site verdicts.
- **Composition vs productivity correction:** this app's richness is the wrong producer-state variable for a bottom-up cascade in drylands (it can invert). Its defensible producer signals for the cascade are (1) the **green-up onset** phenology it already carries, and (2) **introduced-cover/composition shifts** as a disturbance covariate — with veg-structure basal area (a sibling app) as the slow standing-stock floor. Lead the cascade with temp→green-up; use this app's richness and invasion layers as descriptive corroboration, not as a fitted edge.
