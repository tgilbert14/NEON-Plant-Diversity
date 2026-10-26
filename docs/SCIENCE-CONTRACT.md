# Plant Diversity Science Contract

Status: registered estimator contract; source-family review updated for the RELEASE-2026 candidate of 2026-10-26 (refresh run `40364543238`, carried in PR #26). Public production is master `d2b9f56` (app bytes from the PR #23 merge `d39b8d4`, with the 2026-10-21 receipt) until this candidate passes exact-head CI, merge, deployment, and public verification. This document is normative; UI copy, exports, PDF output, tests, and Driver handoff must agree with it.

## Observation model

- Product: NEON Plant presence and percent cover (`DP1.10058.001`).
- Spatial grain: nested 1, 10, 100, and 400 m² incidence; ocular cover only at 1 m².
- Sampling design change: since 2019 NEON surveys the 10 and 100 m² subplots every other year (NEON changeLog 16204/16207); 1 m² quadrats are surveyed every year. A plot's latest year is therefore often a 1 m²-only year and is not a 400 m² plot list.
- Current-state unit (`plant-snapshot-v2`): two labelled site events, each one `(year, bout)` at one site with the plots surveyed in it.
  - Grain event: the site's latest year with rows at 1, 10 and 100 m²; the bout with the most full-grain plots (tie: later bout); only plots carrying all three scales. Every richness, species-area, incidence and plot-list figure uses it.
  - Cover event: the site's newest year whose best-covered bout holds at least max(3, half the grain event's plots) plots with 1 m² records; scale-1 rows only. Every cover-weighted figure (relative cover, Hill, Chao2, watchlist) uses it.
  - Mixed tables carry presence columns from the grain event and cover columns from the cover event, each labelled. No per-plot latest-year selection remains; a plot outside an event is reported as unsupported, never silently included.
  - Registered local choices: a 1 m² quadrat whose parent 10 m² subplot carries no rows still counts as one surveyed 10 m² unit whose list is its own quadrat (NEON's coarser lists need not repeat nested species; effect at most 0.12 species per site); a row with no bout belongs to an event only when nothing in that year carries a bout; nativity conflicts are resolved within each event; the grain event is the latest full-grain year even when an earlier year had more full-grain plots, and the plot count travels with every figure (ABBY 11, OAES 12, WOOD 8 full-grain plots in their latest full-grain year).
- Annual unit: one deterministic bout per plot-year, then a plot-level response. The annual richness response is mean 1 m² subplot richness, because the biennial 10/100 m² schedule would otherwise impose a sawtooth; the 2018 half-plot, 2019 subplot-cut and 2026 suspension design breaks (changeLog 16203, 16207, 110012) are drawn on every annual chart and no line is drawn across 2019.
- Cross-year estimand: mean plot-level response over the recurrent plot panel represented in every included year.
- Cover interpretation: relative ocular index with potentially overlapping vegetation layers; never a fraction of bare ground.
- 1 m² sampling units: a plot's units in the cover event are its quadrats that carry any occurrence row (any taxon rank, coarse IDs included) or any ground-cover row in that event. A quadrat that held only bare soil, litter or rock is a sampled unit with zero plant cover. (Before 2026-10-22 only quadrats with a species-level record counted, so JORN used 155 of its 198 sampled quadrats.)
- Known opportunity limitation: a quadrat with neither a plant record nor a ground-cover record stays unknown, not zero. No function may claim a complete structural-zero correction until an explicit sampled-opportunity table exists.
- Duplicate records: the bundle drops exact duplicate rows (every retained column) at build time; the bout is the survey event, so identical records dated apart within one bout count once. Rows that still share plot, subplot, grain, year, bout and taxon with different cover stay, are summed as before, and are listed by the duplicate-record QC flag ("verify, not wrong").

## Plant source-receipt contract

The candidate plant data are a receipt-complete 46-site `DP1.10058.001` snapshot of NEON RELEASE-2026. Every site bundle and `data/site_index.rds` carries `plant-source-receipt-v2` with build date `2026-10-26`, source interval `2013-01` through closed cutoff `2026-09-30`, NEON release `RELEASE-2026` (DOI https://doi.org/10.48443/9g4s-hq52), immutable receipt ID `PDE-DP1.10058.001-query-through-2026-09-30-sha256-3e484580d6c3198cb9eff6c1e300a9da31fa18d82c91b31daae450408f19e6bc`, raw-inventory digest `3e484580d6c3198cb9eff6c1e300a9da31fa18d82c91b31daae450408f19e6bc`, builder commit `486304df47c87068386d306b597a0655351b19fc`, `basic` query package, and `neonUtilities 4.0.2`. See [Plant Source Receipt](PLANT-SOURCE-RECEIPT.md).

`data/site_index.rds` declares `snapshot_contract = plant-snapshot-v2`, so `scripts/verify_bundle.R` reconciles it under the two-event rule and against the independent oracle in `scripts/plant_oracle.R`, which rebuilds every headline from this text in base R without sourcing the app helpers.

The fetch selects NEON RELEASE-2026 explicitly (named once in `R/plant_release.R`) with `include.provisional = FALSE`, so `neonRelease=RELEASE-2026`, and the build rejects any consumed row from another release. NEON's change log for the product is committed beside the raw inventory; the app shows the entries that start after the records end (110012, sampling suspended for 2026; 110614, DELA field operations ended 2025-12-31). The closed 2026-09-30 cutoff states what the query requested; retained observations span 2013 to 2024 (provisional 2025 bouts at NEON are excluded) and must not be presented as 2026 observations. Repository dates, file mtimes, manifest/runtime hashes, and derived checksums remain ineligible substitutes for source fields.

After exact promotion, these bytes may support descriptive ecological values under the estimand and support rules below. A complete query receipt closes the former source-provenance hold, but does not invent sampled-empty 1 m² opportunities, standardize national effort, establish causal currentness, or authorize a Driver vote. Every later refresh must again carry one complete matching receipt across all 46 bundles and `data/site_index.rds`; revalidation without download preserves the existing receipt and never stamps new provenance.

## Registered estimands

| Estimand | Unit | Support | Permitted interpretation |
|---|---|---|---|
| Nested species-area | mean species / plot at 1, 10, 100, 400 m² (grain event) | finite plot count per scale; 10 m² = mean over 10 m² subplots of their own rows plus the nested 1 m² quadrat; 100 m² = corner union; 400 m² = plot union | grain-specific community richness |
| Plot richness | species / 400 m² plot (grain event) | full-grain plot snapshot | composition, not productivity or health |
| Native/introduced cover | mean relative ocular cover / supported plot (cover event) | supported plot and known 1 m² records | within-site composition context |
| Annual richness series | mean 1 m² subplot richness per plot over recurrent panel | plot, 1 m² unit, selected bout; design breaks drawn | descriptive registered endpoints |
| Introduced-cover annual series | mean plot share over recurrent panel | plot, 1 m² unit, selected bout | descriptive registered endpoints |
| Hill q0/q1/q2 | effective species from 1 m² cover weights | cover event | richness/evenness/dominance profile |
| Ground cover | mean ocular cover of each abiotic or canopy class over the cover event's sampled 1 m² units (a class absent from a unit counts zero), with the share of units where it was recorded | cover event units | ground context; `overstory` is a canopy layer reported apart from soil, litter, rock, biocrust and standing dead, never as a share of ground |
| Bias-corrected Chao2 | incidence lower bound (cover event) | 1 m² incidence units, uniques, doubletons; always printed beside its own S_obs at 1 m² | total-richness floor for the 1 m² quadrat species; its gap from the 1 m² S_obs is the estimated unseen component; never compared with the plot-wide species count |
| Cross-scale introduced occurrence | plot detections at 1 vs 400 m² | plot lists at both grains | detectability/patchiness review lead |
| Expected/reference completeness | overlap with single-point NRCS list (presence from the grain event, cover from the cover event) | reference ID, coordinate, list size; unavailable (`NA`, status `cropland: no native reference applies`) where the sampled plots are cultivated crops | reference-list completeness context |
| Annual environment association | Spearman scan over complete years | recurrent plots, complete months, at least 6 matched years | descriptive short-record co-movement only; any pattern wording requires circular-shift p < 0.10 |

## Estimator rules

### Snapshot selection

`snapshot_by_plot_year()` must be invariant to input row order. Bout selection is deterministic and exported. `site_snapshot()` returns the grain event, the cover event and their labels; `grain_snapshot()` and `cover_snapshot()` are its halves. `latest_snapshot()` is a deprecated alias of `grain_snapshot()` so no caller can obtain a 1 m²-only year under a 400 m² label. The former per-plot latest-year rule survives only as `legacy_plot_latest_snapshot()`, used by the release validator to read a `data/site_index.rds` that still declares no `snapshot_contract` attribute (bundle-time; regenerated by the next refresh). Site events must be invariant to input row order; bout ties resolve to the later bout; an all-missing bout is one unspecified bout.

### Cover denominators

The 1 m² sampling-unit denominator is determined before filtering to a focal species. Species absent from a known supported plot contribute zero at the plot aggregation step. Missing survey opportunity remains missing, not zero. Every surface that prints a species' mean cover (species table, invasive watchlist, network search index, Expected-vs-Observed buckets and their CSVs) uses this one recipe (`species_summary()`); presence-conditional means are not permitted. The denominator is the plot's sampled 1 m² units defined above. Plot-species means are not rounded before nativity or site sums (the 2 dp per-plot rounding found by the oracle on 2026-10-21 was removed on 2026-10-22); values are rounded only where they are printed. A present species whose mean is below 0.1 prints as "<0.1", never 0, and the watchlist export carries the supported-plot denominator.

### Chao2

The finite-sample bias-corrected incidence estimator is:

`S_obs + ((m - 1) / m) * Q1 * (Q1 - 1) / (2 * (Q2 + 1))`

where `m` is the number of incidence units, `Q1` uniques, and `Q2` doubletons. It is a lower-bound estimator. Unstable cases are flagged; no unsupported symmetric confidence interval is promoted as definitive. It is never labelled effort-corrected or coverage-standardized.

### QC flags

Three data-quality flags are reported, each a review lead rather than an error verdict: a NEON-versus-USDA nativity disagreement (lower 48 only), a 1 m² quadrat visit whose cover sums above 250%, and a duplicate record (one taxon recorded twice in one quadrat visit with different cover). Every flag opens its full row list in the app and exports it, and `qc_flags.csv` carries all three in the completeness-report and all-data ZIPs.

### Independent oracle

`scripts/plant_oracle.R` recomputes each headline (species count, plots, introduced cover, introduced species, the species-area curve, Chao2 and its S_obs) in base R from the contract text, without the app's helpers. `scripts/verify_bundle.R` fails when the oracle, the app helpers and `data/site_index.rds` disagree for any site.

### Cross-site comparison

Raw site richness remains visible only with support. Mean richness per 400 m² plot is the common-grain descriptive row. A future coverage-standardized estimator requires an explicit registered implementation and fixtures; Chao2 cannot substitute for it.

### Nativity and reference authority

- Contradictory Native/Introduced NEON statuses resolve to Unknown/review.
- USDA lower-48 mismatch checks are disabled outside the lower 48.
- Fuzzy or undocumented state-occurrence matches may not demote a review record.
- The current NRCS list represents one reference coordinate/soil unit near the site centre, not every plot or the whole site flora.

### Environment context

- Annual precipitation, temperature, flowering, and green-up require 12 complete monthly values.
- Fruiting intensity and incomplete seasonal windows are excluded.
- Response years use one bout per plot-year and a recurrent plot panel; the richness response is mean 1 m² subplot richness.
- Circular-shift nulls preserve ordered response structure. At least 6 matched years are required to scan, and any wording other than "no clear pattern" requires p < 0.10.
- The default response shown is introduced-cover share; richness is offered under its 1 m² label.
- No fitted line, causal wording, or Driver edge is allowed from this per-site screen.

## Parity requirements

For a selected site and snapshot, the following must match exactly:

- app headline values, each carrying its event label;
- report PDF values, carrying the same two labels;
- `analysis_snapshot.csv` (grain event), `cover_snapshot.csv` (cover event) and `plots_snapshot.csv`;
- science fixture outputs;
- reference and provenance receipts, including the matching query-snapshot fields and durable raw-source inventory digest.

Any mismatch blocks release.

## Driver disposition

Current status: **CONTEXT / HOLD DRIVER INGESTION / NO DRIVER BYTE CHANGE.** The candidate closes the plant source-receipt gate, but current Driver ingestion and inferential promotion remain held on explicit sampled opportunity, a measured eligible join, an independent adapter, and old/new parity.

Eligible after exact promotion as descriptive query-snapshot context: common-grain plot richness, introduced-cover composition, cross-scale occurrence, reference completeness, support, and uncertainty. Excluded: productivity vote, per-site climate–richness edges, management priority, and phenology signals owned by the Phenology app.
