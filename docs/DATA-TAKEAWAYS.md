# NEON Plant Diversity Explorer — Data Takeaways and Validation Status

_Human source-family review for NEON DP1.10058.001 · candidate 2026-08-03._

> **Status:** validated data candidate `374fb704c548ca830f05c46d5fab1331e0027302` carries a complete 46-site query-snapshot receipt and has passed independent local semantic review. It is not yet production: public commit `d6c48625f8268873bcd42d86285becaadbd57b4c` remains authoritative until the reviewed head passes CI, merge, Connect, Pages, export, responsive, and semantic-health gates in [BUILD-TEST-HANDOFF.md](BUILD-TEST-HANDOFF.md).

## What is verified in the repository

The current artifact inventory contains:

- 46 site bundles in `data/sites/`;
- 46 monthly environment bundles in `data/env/`;
- 34 site-specific NRCS reference artifacts in `data/expected/`, with unavailable sites represented separately rather than as zero overlap;
- a site index, search index, and plant authority artifact;
- hard-assertion science fixtures in `scripts/test_science_contracts.R` and bundle/release checks in `scripts/verify_bundle.R`.

These are inventory facts, not ecological findings. The candidate's 46 plant bundles and `data/site_index.rds` carry one matching [Plant Source Receipt](PLANT-SOURCE-RECEIPT.md): built 2026-08-03 from a `basic` query spanning 2013-01 through closed cutoff 2026-07-31, raw-inventory digest `48167b04cc689fbcaaa3e83bdac7cc7ed1c8ac34f791e5e76d3f229862d61ac6`, and builder commit `1734840a4f09e7acee356431ea1e57e9a637fb31`. No official release was selected, so `neonRelease=NA`; retained observations end in 2024.

## Candidate change review

The independent base-R review reconstructed all 46 latest-plot snapshots, cover denominators, and Chao2 inputs without sourcing the application helpers, then reconciled snapshot richness, plot support, and introduced-cover percentages to `data/site_index.rds`. The candidate contains 1,375,149 occurrence rows and 451,979 ground-context rows across 1,574 plots. Of the occurrence rows, 1,217,691 are species-level and 157,458 are coarse-identification records retained for audit/export. Across the full historical family there are 5,840 distinct species-level scientific names: 63 more than production and none removed.

Forty-three site occurrence and ground row multisets are semantically unchanged after ignoring deterministic row order and serialization. Only JORN, KONZ, and SRER gained source rows. Their historical ranges expand from 2017–2023 to 2014–2024, 2017–2023 to 2015–2024, and 2017–2023 to 2016–2024, respectively. The other 43 site ranges and row multisets are unchanged.

Current-state values legitimately move when a plot receives a newer selected survey. JORN moves from 35 to 80 snapshot species and 0.0% to 0.2% introduced relative cover; KONZ moves from 231 to 200 species while remaining 0.2%; SRER moves from 203 to 161 species and 22.2% to 10.0%. Plot support remains 33 at each site. NRCS single-point reference overlap stays 24% at JORN, moves 64% to 60% at KONZ, and 52% to 38% at SRER. These are snapshot/receipt facts, not population, productivity, ecosystem-health, or national-rank claims.

## Production QA example: SRER

The candidate oracle reports 161 plant species across 33 selected current-state plots at Santa Rita Experimental Range, with 10.0% introduced relative cover in the known supported 1 m² cover records and a bias-corrected Chao2 lower bound of 194.5. All 33 SRER plots now select 2024 rather than 2023. The nested species-area view retains the registered 1, 10, 100, and 400 m² grains. These values require app/export/PDF parity on the reviewed head before promotion and are not an effort-standardized national rank, productivity signal, management grade, or temporal trend.

## Registered product contract

### Current-state analyses

- `snapshot_by_plot_year()` deterministically selects one bout for each plot-year and is required to be invariant to input row order.
- `latest_snapshot()` then retains each plot's latest selected year. Current-state richness, species-area, Chao2, cover, PDF summaries, and snapshot exports must use that same selection.
- Richness always travels with its grain. The nested 1, 10, 100, and 400 m² curve is a direct description of the NEON sampling design, not an interpolation.
- Cover is an ocular relative index from 1 m² records. Vegetation layers may overlap, so cover is never described as a fraction of ground.

### Annual analyses

- Annual plant responses first select one deterministic bout per plot-year.
- Each response is calculated at plot level and summarized over the recurrent plot panel represented in every included year.
- Annual outputs carry plot, sampling-unit, and selected-bout support. Changing plot effort is not allowed to masquerade as a temporal trend.
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
- Results remain descriptive short-record co-movement. No fitted line, causal wording, or per-site Driver/Cascade edge is authorized.

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

The candidate review recomputed surfaced values under the refreshed bundles and complete query receipt. The source-provenance gap is closed for this family: `builtAt=2026-08-03`, `sourceStart=2013-01`, `sourceCutoff=2026-07-31`, and the immutable source receipt/raw digest are present across every bundle and index. `neonRelease=NA` remains correct because no official release was selected. Query cutoff is not observation vintage; no retained record is later than 2024.

These values may be reported only as descriptive results for the exact promoted bytes with estimand and support attached. File mtimes and manifest/runtime hashes still cannot replace source fields, and complete provenance does not repair missing sampled-empty quadrat opportunity.

## Export and reproducibility contract

The whole-site ZIP distinguishes source records from analysis frames:

- `occurrences_all.csv` retains every bundled taxon record, including coarse IDs;
- `analysis_snapshot.csv` contains the exact current-state records selected by the snapshot contract;
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

The data candidate passed run `30818211291` producer/validator gates and independent local 46-site row/metric review. Exact-head CI, real app/export/PDF parity, desktop/390/375/361/360/320 review, merge, Connect/Pages identity, and semantic post-deploy health remain required before this section can be closed as production evidence. The last known-good public production release remains `d6c48625f8268873bcd42d86285becaadbd57b4c`.

Driver/Cascade disposition is **CONTEXT / NO DRIVER BYTE CHANGE**. Common-grain plot richness, introduced-cover composition, cross-scale occurrence, reference completeness, support, and uncertainty may be handed off after promotion as descriptive query-snapshot context. The candidate satisfies the source-receipt gate, but ingestion and inference still require explicit sampled opportunity, a measured eligible Driver join, an independent adapter, and old/new parity. Productivity votes, per-site climate–richness edges, management inference, and phenology signals owned by the Phenology app remain excluded.
