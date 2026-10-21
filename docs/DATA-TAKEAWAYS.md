# NEON Plant Diversity Explorer — Data Takeaways and Validation Status

_Human source-family review for NEON DP1.10058.001 · candidate 2026-10-21 (supersedes the 2026-08-03 candidate)._

> **Status:** validated data candidate `a9fc28fdaebd318744dadde341c0cca55a91a899` carries a complete 46-site query-snapshot receipt queried through 2026-09-30 and has passed the independent row review; its candidate-metric oracle rerun is pending. It is not yet production: master `280539c8713c16b6b13d47d5916e0f50a10edd24` (plant-snapshot-v2 code over the 2026-08-03 receipt and a pre-v2 site index, post-deploy smoke `39544227599` passed) remains authoritative until the reviewed head passes CI, merge, Connect, Pages, export, responsive, and semantic-health gates in [BUILD-TEST-HANDOFF.md](BUILD-TEST-HANDOFF.md).

## What is verified in the repository

The current artifact inventory contains:

- 46 site bundles in `data/sites/`;
- 46 monthly environment bundles in `data/env/`;
- 34 site-specific NRCS reference artifacts in `data/expected/`, with unavailable sites represented separately rather than as zero overlap;
- a site index, search index, and plant authority artifact;
- hard-assertion science fixtures in `scripts/test_science_contracts.R` and bundle/release checks in `scripts/verify_bundle.R`.

These are inventory facts, not ecological findings. The candidate's 46 plant bundles and `data/site_index.rds` carry one matching [Plant Source Receipt](PLANT-SOURCE-RECEIPT.md): built 2026-10-21 from a `basic` query spanning 2013-01 through closed cutoff 2026-09-30 with `neonUtilities 4.0.2`, raw-inventory digest `d7e9e0de7d8e624cb4e4f9d6d64b4a41ae58f09ead497ce1307983b797811cc7`, and builder commit `280539c8713c16b6b13d47d5916e0f50a10edd24`. `data/site_index.rds` and `data/search_index.rds` declare `snapshot_contract = plant-snapshot-v2`. No official release was selected, so `neonRelease=NA`; retained observations end in 2024, and provisional 2025 bouts at NEON are excluded.

## Candidate change review

This refresh changed no observations. The row oracle `scripts/review_refresh_rows.R` (with `PDE_EXPECTED_CHANGED_SITES` empty) found the occurrence row multisets unchanged at 46 of 46 sites, the ground row multisets unchanged at 46 of 46, and one retained column schema across all 46 bundles. The family still holds 1,375,149 occurrence rows and 451,979 ground-context rows across 1,574 plots, the same totals as the 2026-08-03 review, and retained observations still span 2013 to 2024. Six bundles (CPER, DEJU, OAES, OSBS, SCBI, STEI) differ from master only in row order, from `percentCover` tie-order churn; 40 are byte-identical in their rows. Every bundle meta changed only in its receipt stamps (build date, cutoff, receipt ID, raw digest, builder commit, `neonUtilities` version). The 46 raw-file digests are all new because the upstream responses arrived in a different byte order, which is why the receipt ID moved while the rows did not. The rewritten candidate oracle (`scripts/review_refresh_candidate.R`, base R, no app helpers sourced) passed against this head: 46-site identity, one bundle schema, one matching receipt across every bundle and `data/site_index.rds`, and independent plant-snapshot-v2 parity (grain-event richness and plots, cover-event introduced cover) with the index. Network totals are unchanged from master under the same rule: 1,375,149 occurrence rows, 451,979 ground rows, 1,217,691 species-level rows, 1,574 plots, 1,047 grain-event plots, 6,603 1 m² incidence units, 5,840 species-level names (0 added, 0 removed); every per-site delta is zero. Its informational block lists the 43 sites where master's pre-v2 index differs from the v2 reconstruction.

The site index moved anyway, and the cause is the contract, not the data: 43 of 46 `site_index` rows change in richness, plots, or introduced cover because this is the first full refresh built under `plant-snapshot-v2` (the grain event for richness and plots, the 1 m² cover event for introduced cover), the correction PR #20 said this refresh would deliver. As species / plots / introduced relative cover, SRER moves from 161 / 33 / 10.0% to 203 / 33 / 9.6%; CPER from 102 / 70 / 0.4% to 92 / 33 / 0.4%; JORN from 80 / 33 / 0.2% to 66 / 33 / 0.2%; STER from 20 / 11 / 99.8% to 30 / 10 / 99.9%. The completeness index is carried unchanged from master, where PR #20 had already rebuilt it under plant-snapshot-v2 (SRER 52%, 26 of 50 reference species; STER and KONA have no percentage, status "cropland: no native reference applies"). Environment overlays and the 34 reference artifacts are byte-identical to master. These are snapshot-contract and receipt facts, not population, productivity, ecosystem-health, or national-rank claims.

The 2026-08-03 review numbers (JORN, KONZ, and SRER gaining rows; 63 species-level names added; JORN 35 to 80, KONZ 231 to 200, SRER 203 to 161 under the retired per-plot latest-year snapshot) describe the previous candidate and are kept only as history; the correction below explains why the latest-year values were wrong.

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

The candidate review compared the refreshed bundles and complete query receipt with master. The source-provenance gap stays closed: `builtAt=2026-10-21`, `sourceStart=2013-01`, `sourceCutoff=2026-09-30`, `neonUtilitiesVersion=4.0.2`, and the immutable source receipt/raw digest `d7e9e0de7d8e624cb4e4f9d6d64b4a41ae58f09ead497ce1307983b797811cc7` are present across every bundle and index. The later cutoff added no rows, so it is a newer request, not newer ecology. App, export, and PDF parity for SRER under plant-snapshot-v2 (203 species and species-area 5.5 / 12.3 / 26.7 / 42.6 in grain event 2023 bout 2; 9.6% introduced and Chao2 191.9 from 157 at 1 m² in cover event 2024 bout 1) must be confirmed on the reviewed head before promotion. `neonRelease=NA` remains correct because no official release was selected. Query cutoff is not observation vintage; no retained record is later than 2024.

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

The data candidate passed refresh run `39546911504` producer/validator gates (builder `280539c8713c16b6b13d47d5916e0f50a10edd24`; the earlier run `39542458760` built the same candidate but its publisher correctly refused a stale base) and the independent 46-site row review; the candidate-metric oracle rerun under plant-snapshot-v2 is pending. Exact-head CI, real app/export/PDF parity, desktop/390/375/361/360/320 review, merge, Connect/Pages identity, and semantic post-deploy health remain required before this section can be closed as production evidence. The last known-good public production release remains master `280539c8713c16b6b13d47d5916e0f50a10edd24`.

Driver/Cascade disposition is **CONTEXT / HOLD DRIVER INGESTION / NO DRIVER BYTE CHANGE**. Common-grain plot richness, introduced-cover composition, cross-scale occurrence, reference completeness, support, and uncertainty may be handed off after promotion as descriptive query-snapshot context. The candidate satisfies the source-receipt gate, but ingestion and inference still require explicit sampled opportunity, a measured eligible Driver join, an independent adapter, and old/new parity. Productivity votes, per-site climate–richness edges, management inference, and phenology signals owned by the Phenology app remain excluded.
