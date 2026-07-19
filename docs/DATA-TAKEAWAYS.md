# NEON Plant Diversity Explorer — Data Takeaways and Validation Status

_Candidate review for NEON DP1.10058.001. Updated for the v3 science contract._

> **Status:** this document separates the implemented product contract from empirical results. The contract is registered in [SCIENCE-CONTRACT.md](SCIENCE-CONTRACT.md), but the candidate has not yet completed the receipts in [BUILD-TEST-HANDOFF.md](BUILD-TEST-HANDOFF.md). Exact ecological values quoted by earlier reviews are retired until they are recomputed from the promoted release bytes.

## What is verified in the repository

The current artifact inventory contains:

- 46 site bundles in `data/sites/`;
- 46 monthly environment bundles in `data/env/`;
- 34 site-specific NRCS reference artifacts in `data/expected/`, with unavailable sites represented separately rather than as zero overlap;
- a site index, search index, and plant authority artifact;
- hard-assertion science fixtures in `scripts/test_science_contracts.R` and bundle/release checks in `scripts/verify_bundle.R`.

These are inventory facts, not ecological findings. The exact 46-site plant family is now content-addressed under the legacy-partial [Plant Source Receipt](PLANT-SOURCE-RECEIPT.md): it entered the repository in commit `4ffcb24c3c1bf0dcab1f6c42fd3b9b5fe4de4e1e` on 2026-06-19. That repository receipt and the frozen-family hash prove which bytes are under review; they do not prove upstream vintage. File presence alone does not prove that the candidate code reproduces earlier values or that the deployed app serves the same bytes.

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

- Chao2 uses the registered finite-sample bias-corrected incidence formula and is reported as a lower bound. The candidate no longer publishes the earlier classic-form estimate or an unsupported symmetric confidence interval.
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

The previous review mixed historical bundle calculations with claims about the current application. Values such as site rankings, site-specific Chao2 estimates, invasion percentages, and climate correlations must be recomputed after the candidate manifest, bundles, and exact source-family receipt are frozen. Recomputed values may be reported as descriptive results for those exact bytes. They are not current-source findings because the original NEON release, query cutoff/receipt, raw-source digest, and actual build date were not preserved.

For the legacy family, `builtAt`, `neonRelease`, and `sourceCutoff` remain `NA`. `repositoryImportedAt=2026-06-19` and `sourceBundleCommit=4ffcb24c3c1bf0dcab1f6c42fd3b9b5fe4de4e1e` distinguish repository receipt from upstream source history. File mtimes and manifest/runtime hashes cannot fill the missing fields.

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

The candidate may describe:

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

Release remains a candidate until R parsing, science fixtures, bundle verification, deterministic rebuilds, strict manifest equality, offline boot, human desktop/mobile review, export inspection, and semantic post-deploy checks all pass for one recorded commit. Passing those gates can validate an application release over the exact legacy bytes; it cannot retroactively create an upstream source receipt or establish currentness.

Driver/Cascade disposition is **context-only / hold current-source and inferential promotion**. After exact-byte and contract validation, common-grain plot richness, introduced-cover composition, cross-scale occurrence, reference completeness, support, and uncertainty may be handed off as descriptive legacy context. Current-source promotion requires a future complete matching receipt across all 46 bundles and `site_index.rds`; productivity votes, per-site climate–richness edges, management inference, and phenology signals owned by the Phenology app remain excluded.
