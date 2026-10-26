# NEON Plant Diversity Explorer — Data Takeaways and Validation Status

_Human source-family review for NEON DP1.10058.001 · RELEASE-2026 candidate 2026-10-26 (supersedes the 2026-10-21 candidate)._

> **Status:** the validated RELEASE-2026 candidate from refresh run `40364543238` (builder `486304d`, carried in PR #26) carries one complete 46-site receipt and has passed the independent row review and the candidate-metric oracle. It is not yet production: master `d2b9f56` (app bytes from the PR #23 merge `d39b8d4`, with the 2026-10-21 receipt; post-deploy smoke `39620095811` passed) remains authoritative until the reviewed head passes CI, merge, Connect, Pages, export, responsive, and semantic-health gates in [BUILD-TEST-HANDOFF.md](BUILD-TEST-HANDOFF.md).

## What is verified in the repository

The current artifact inventory contains:

- 46 site bundles in `data/sites/`;
- 46 monthly environment bundles in `data/env/`;
- 34 site-specific NRCS reference artifacts in `data/expected/`, with unavailable sites represented separately rather than as zero overlap;
- a site index, search index, and plant authority artifact;
- hard-assertion science fixtures in `scripts/test_science_contracts.R` and bundle/release checks in `scripts/verify_bundle.R`.

These are inventory facts, not ecological findings. The candidate's 46 plant bundles and `data/site_index.rds` carry one matching [Plant Source Receipt](PLANT-SOURCE-RECEIPT.md): NEON RELEASE-2026 (DOI 10.48443/9g4s-hq52), built 2026-10-26 from a `basic` query spanning 2013-01 through closed cutoff 2026-09-30 with `neonUtilities 4.0.2`, raw-inventory digest `3e484580d6c3198cb9eff6c1e300a9da31fa18d82c91b31daae450408f19e6bc`, and builder commit `486304df47c87068386d306b597a0655351b19fc`. `data/site_index.rds` and `data/search_index.rds` declare `snapshot_contract = plant-snapshot-v2`; `data/source/neon-change-log.json` holds NEON's change log for the product. Retained observations end in 2024, and provisional 2025 bouts at NEON are excluded.

## Candidate change review

This candidate changed no observation. The row oracle `scripts/review_refresh_rows.R` (with `PDE_EXPECTED_CHANGED_SITES` empty) found that every site whose rows differ from master differs only by exact-duplicate removal, the bundling step added for PD-18: 5,678 occurrence rows at 44 sites (from 2 at RMNP to 714 at CLBJ) and 921 ground rows at 35 sites. All 46 bundles keep one retained schema and no exact duplicate remains: 1,369,471 occurrence rows and 451,058 ground rows across 1,574 plots. Pinning RELEASE-2026 changed no row; the earlier unpinned query was already returning that release. The candidate oracle `scripts/review_refresh_candidate.R` (base R, no app helpers sourced) passed: 46-site identity, one bundle schema, one matching receipt, and independent plant-snapshot-v2 parity with the index. Rebuilt under one rule from master's rows and the candidate's, no headline moves at any of the 46 sites; the duplicates did not move a headline.

Six `site_index` rows move, by 0.1 to 0.5 points of introduced relative cover, and no richness or plot count moves. The cause is this PR's cover-denominator contract (a plot's sampled 1 m² quadrats now include quadrats that held only ground cover, and plot means are not rounded before the site sums), not new data. As introduced relative cover: GUAN 3.1% to 3.2%, LAJA 73.6% to 73.1%, MOAB 14.0% to 14.1%, SOAP 32.9% to 33.1%, WOOD 14.3% to 14.4%, YELL 0.7% to 0.8%. Species-level cover moves more: at JORN the cover event now counts 198 sampled quadrats where 155 were counted, the summed species mean cover falls from 5.68 to 4.15, and Prosopis glandulosa from 4.16 to 2.80; SRER (13.26 to 13.11) and MOAB (8.58 to 8.42) move less. The search index carries the same denominator, and the completeness index is byte-identical to master. Environment overlays and the 34 reference artifacts are byte-identical to master. These are contract and receipt facts, not population, productivity, ecosystem-health, or national-rank claims.

The 2026-10-21 candidate (no row change, 43 of 46 index rows moved to plant-snapshot-v2, SRER 161 to 203 species) and the 2026-08-03 candidate (JORN, KONZ and SRER gaining rows under the retired per-plot latest-year snapshot) are kept only as history; the correction below explains why the latest-year values were wrong.

## Production QA example: SRER

**Correction, 2026-10-18 (audit item 3, P0).** The 2026-08 review above selected each plot's latest year, and at SRER that year (2024) carries 1 m² rows only: NEON has surveyed the 10 and 100 m² subplots every other year since 2019 (changeLog 16204/16207). The former "161 species across 33 plots" and the species-area 6.5 / 8.2 / 8.2 / 17.9 were 1 m² lists under a 400 m² label; the claim that the view "retains the registered grains" was false. Forty of 46 sites were affected (988 of 1,574 current-snapshot plots had no 10/100 m² rows).

Under `plant-snapshot-v2` SRER reports two labelled events. Grain event 2023 · bout 2 · 33 plots: 203 species-level names and a species-area of 5.5 / 12.3 / 26.7 / 42.6 (the 10 m² point is the per-10 m² subplot union; the former corner union gave 15.2 by merging two 10 m² subplots). Cover event 2024 · bout 1 · 33 plots: 9.6% introduced relative cover, Chao2 191.9 from 157 species seen at 1 m². Two contrasting sites: CPER keeps its 33 plots surveyed in 2024 and drops 37 plots last surveyed in 2013/2014 (92 species at 400 m², Chao2 73.1 from 58 at 1 m², 0.4% introduced), where the old snapshot pooled 70 plots across 2013–2024 for 102 species; JORN (2024 · bout 1 · 33 plots for both events) shows 66 species at 400 m² and Chao2 46.5 beside its 1 m² count of 39, where the old compare modal printed Chao2 61.9 under a species row of 80. STER and KONA (every plot `cultivatedCrops`) no longer receive a "reference flora detected" percentage; their completeness status is "cropland: no native reference applies". The full 46-site before/after table is in the PR for this change. None of these values is an effort-standardized national rank, productivity signal, management grade, or temporal trend.

## Registered product contract

### Current-state analyses

- `snapshot_by_plot_year()` deterministically selects one bout for each plot-year and is required to be invariant to input row order.
- `site_snapshot()` selects two labelled site events: the grain event (latest year with 1, 10 and 100 m² rows; one bout; full-grain plots only) carries richness, species-area, plot lists and the Expected-vs-Observed presence set; the cover event (latest complete 1 m² bout) carries relative cover, Hill, Chao2 and the watchlist. App, PDF and exports print both labels. `latest_snapshot()` is a deprecated alias of the grain event.
- Richness always travels with its grain and its event. The nested 1, 10, 100, and 400 m² curve is a direct description of the NEON sampling design, not an interpolation; the 10 m² point is the mean over 10 m² subplots of their own rows plus the nested 1 m² quadrat.
- Chao2 is printed beside its own 1 m² S_obs and is never compared with the plot-wide species count.
- Cover is an ocular relative index from 1 m² records. Vegetation layers may overlap, so cover is never described as a fraction of ground.

### Annual analyses

- Annual plant responses first select one deterministic bout per plot-year.
- Each response is calculated at plot level and summarized over the recurrent plot panel represented in every included year.
- Annual outputs carry plot, sampling-unit, and selected-bout support. Changing plot effort is not allowed to masquerade as a temporal trend. The annual richness response is mean 1 m² subplot richness, because the biennial 10/100 m² schedule made the 400 m² series a sawtooth (SRER odd years 42.3, even years 16.7); the 2018, 2019 and 2026 design breaks are drawn on every annual chart.
- Richness is a composition measure. It is not productivity, biomass, ecosystem health, or a Driver vote.

### Estimators and QC

- Chao2 uses the registered finite-sample bias-corrected incidence formula and is reported as a lower bound. The promoted app no longer publishes the earlier classic-form estimate or an unsupported symmetric confidence interval.
- Species-area support counts only finite plot estimates at each scale; SD is unavailable when fewer than two plots support a scale.
- Contradictory Native/Introduced NEON records resolve to Unknown and remain in review rather than contributing to both categories.
- USDA nativity mismatch checks are gated outside the lower 48.
- Every observed species absent from the NRCS list remains in review. State-occurrence data cannot demote a record until exact match, query, dataset, and license provenance is bundled.
- Cross-scale introduced occurrence describes detections at different grains. It is not evidence of establishment, spread, impact, or management priority.

### Environment context

- Only annual precipitation, temperature, flowering, and green-up are registered as app-level environment context.
- An annual value requires 12 non-missing monthly values. Fruiting intensity, incomplete seasonal windows, and the former winter/monsoon per-site Driver read are excluded.
- Association screens use recurrent plot responses, complete annual windows, Spearman correlation, and circular-shift nulls that preserve response order.
- Results remain descriptive short-record co-movement. At least 6 matched years and circular-shift p < 0.10 are required before any pattern wording. No fitted line, causal wording, or per-site Driver/Cascade edge is authorized.

## Known limitations

### Sampling opportunity

The occurrence bundles do not contain an explicit table of sampled-but-vegetation-empty quadrats. Cover functions can include species zeros across known supported subplots and plots, but cannot claim complete structural-zero correction. A missing survey opportunity remains unknown, not zero. Chao2's incidence-unit count has the same opportunity limitation.

### Cross-site comparison

Raw site richness reflects site-specific plot support. Mean plot richness at the common 400 m² grain is descriptive, but no coverage-standardized cross-site estimator is registered. Chao2 is a within-sample lower bound and cannot substitute for rarefaction or coverage standardization.

### Expected/reference flora

Each current expected list comes from one site reference coordinate, one intersecting soil map unit, and its selected ecological class. It is a local comparison list, not a census of every plot or the whole site. “Reference but not detected” is completeness context, never an error finding.

### Authority provenance

The plant authority supports accepted-symbol and lower-48 nativity review, but state-occurrence provenance is not sufficient to alter review classifications. No fuzzy or undocumented geographic match is promoted as authoritative.

### Empirical validation

The candidate review compared the refreshed bundles and the complete receipt with master. The source-provenance gap stays closed: `builtAt=2026-10-26`, `sourceStart=2013-01`, `sourceCutoff=2026-09-30`, `neonRelease=RELEASE-2026`, `neonUtilitiesVersion=4.0.2`, and the immutable source receipt/raw digest `3e484580d6c3198cb9eff6c1e300a9da31fa18d82c91b31daae450408f19e6bc` are present across every bundle and index. App, export, and PDF parity for SRER under plant-snapshot-v2 (203 species and species-area 5.5 / 12.3 / 26.7 / 42.6 in grain event 2023 bout 2; 9.6% introduced and Chao2 191.9 from 157 at 1 m² over 198 sampled quadrats in cover event 2024 bout 1) must be confirmed on the reviewed head before promotion. Query cutoff is not observation vintage; no retained record is later than 2024.

These values may be reported only as descriptive results for the exact promoted bytes with estimand and support attached. File mtimes and manifest/runtime hashes still cannot replace source fields, and complete provenance does not repair missing sampled-empty quadrat opportunity.

## Export and reproducibility contract

The whole-site ZIP distinguishes source records from analysis frames:

- `occurrences_all.csv` retains every bundled taxon record, including coarse IDs;
- `analysis_snapshot.csv` contains the grain-event records and `cover_snapshot.csv` the cover-event records, each with its event label;
- `plots_snapshot.csv` contains plot-level snapshot estimates;
- `ground_cover_all.csv` and `environment_context.csv` remain clearly scoped as bundled context;
- expected/reference and release provenance are exported separately;
- the data dictionary is derived from emitted frames and fails on undocumented or duplicate columns. It includes definitions, types, units, NA semantics, and estimands.

The PDF must use the same snapshot as the app and exports. Bundle checksum, estimator contract, source license, and reference scope are part of the release receipt.

## What the app may and may not claim

The promoted app may describe:

- grain-specific plant composition;
- relative ocular cover and nativity composition with support;
- cross-scale occurrence as a detection/grain pattern;
- Chao2 as an incidence lower bound;
- overlap with one local NRCS ecological-site reference;
- exploratory annual environment co-movement when all support gates pass.

It may not claim:

- productivity, biomass, health, causal response, or management priority from richness or cover;
- complete sampled-zero correction;
- a site-wide expected flora;
- effort-standardized national richness rankings;
- a per-site climate-to-plant Driver edge;
- a suite-level empirical result inherited from another app.

## Release and Driver disposition

The data candidate passed refresh run `40364543238` producer/validator gates (builder `486304d`; two earlier dispatches stopped on first-run defects fixed in `587378f` and `486304d`), the independent 46-site row review and the candidate-metric oracle. Exact-head CI, real app/export/PDF parity, desktop/390/375/361/360/320 review, merge, Connect/Pages identity, and semantic post-deploy health remain required before this section can be closed as production evidence. The last known-good public production release remains master `d2b9f56` (app bytes from `d39b8d4`).

Driver/Cascade disposition is **CONTEXT / HOLD DRIVER INGESTION / NO DRIVER BYTE CHANGE**. Common-grain plot richness, introduced-cover composition, cross-scale occurrence, reference completeness, support, and uncertainty may be handed off after promotion as descriptive query-snapshot context. The candidate satisfies the source-receipt gate, but ingestion and inference still require explicit sampled opportunity, a measured eligible Driver join, an independent adapter, and old/new parity. Productivity votes, per-site climate–richness edges, management inference, and phenology signals owned by the Phenology app remain excluded.
