# Plant Diversity Science Contract

Status: registered estimator contract; source-family review updated for validated query-snapshot candidate `374fb704c548ca830f05c46d5fab1331e0027302`. Public production remains on the 2026-07-19 legacy release until exact-head CI, merge, deployment, and public verification complete. This document is normative; UI copy, exports, PDF output, tests, and Driver handoff must agree with it.

## Observation model

- Product: NEON Plant presence and percent cover (`DP1.10058.001`).
- Spatial grain: nested 1, 10, 100, and 400 m² incidence; ocular cover only at 1 m².
- Current-state unit: one latest registered `(year, bout)` snapshot per plot.
- Annual unit: one deterministic bout per plot-year, then a plot-level response.
- Cross-year estimand: mean plot-level response over the recurrent plot panel represented in every included year.
- Cover interpretation: relative ocular index with potentially overlapping vegetation layers; never a fraction of bare ground.
- Known opportunity limitation: occurrence bundles do not preserve an explicit table of sampled-but-empty quadrats. No function may claim a complete structural-zero correction until that table exists.

## Plant source-receipt contract

The candidate plant data are a receipt-complete 46-site `DP1.10058.001` query snapshot, not the former frozen legacy family. Every site bundle and `data/site_index.rds` carries `plant-source-receipt-v2` with build date `2026-08-03`, source interval `2013-01` through closed cutoff `2026-07-31`, immutable receipt ID `PDE-DP1.10058.001-query-through-2026-07-31-sha256-48167b04cc689fbcaaa3e83bdac7cc7ed1c8ac34f791e5e76d3f229862d61ac6`, raw-inventory digest `48167b04cc689fbcaaa3e83bdac7cc7ed1c8ac34f791e5e76d3f229862d61ac6`, builder commit `1734840a4f09e7acee356431ea1e57e9a637fb31`, `basic` query package, and `neonUtilities 4.0.1`. See [Plant Source Receipt](PLANT-SOURCE-RECEIPT.md).

No official NEON release was explicitly selected, so `neonRelease=NA`. That honest `NA` does not invalidate the complete query receipt. The closed 2026-07-31 cutoff states what the query requested; retained observations span 2013–2024 and must not be presented as 2026 observations. Repository dates, file mtimes, manifest/runtime hashes, and derived checksums remain ineligible substitutes for source fields.

After exact promotion, these bytes may support descriptive ecological values under the estimand and support rules below. A complete query receipt closes the former source-provenance hold, but does not invent sampled-empty 1 m² opportunities, standardize national effort, establish causal currentness, or authorize a Driver vote. Every later refresh must again carry one complete matching receipt across all 46 bundles and `data/site_index.rds`; revalidation without download preserves the existing receipt and never stamps new provenance.

## Registered estimands

| Estimand | Unit | Support | Permitted interpretation |
|---|---|---|---|
| Nested species-area | mean species / plot at 1, 10, 100, 400 m² | finite plot count per scale | grain-specific community richness |
| Plot richness | species / 400 m² plot | plot snapshot | composition, not productivity or health |
| Native/introduced cover | mean relative ocular cover / supported plot | supported plot and known 1 m² records | within-site composition context |
| Introduced-cover annual series | mean plot share over recurrent panel | plot, 1 m² unit, selected bout | descriptive registered endpoints |
| Hill q0/q1/q2 | effective species from 1 m² cover weights | current snapshot | richness/evenness/dominance profile |
| Bias-corrected Chao2 | incidence lower bound | 1 m² incidence units, uniques, doubletons | total-richness floor; difference from observed is the estimated unseen component |
| Cross-scale introduced occurrence | plot detections at 1 vs 400 m² | plot lists at both grains | detectability/patchiness review lead |
| Expected/reference completeness | overlap with single-point NRCS list | reference ID, coordinate, list size | reference-list completeness context |
| Annual environment association | Spearman scan over complete years | recurrent plots, complete months, matched years | descriptive short-record co-movement only |

## Estimator rules

### Snapshot selection

`snapshot_by_plot_year()` must be invariant to input row order. Bout selection is deterministic and exported. `latest_snapshot()` must select the latest registered plot snapshot without pooling bouts.

### Cover denominators

The 1 m² sampling-unit denominator is determined before filtering to a focal species. Species absent from a known supported plot contribute zero at the plot aggregation step. Missing survey opportunity remains missing, not zero.

### Chao2

The finite-sample bias-corrected incidence estimator is:

`S_obs + ((m - 1) / m) * Q1 * (Q1 - 1) / (2 * (Q2 + 1))`

where `m` is the number of incidence units, `Q1` uniques, and `Q2` doubletons. It is a lower-bound estimator. Unstable cases are flagged; no unsupported symmetric confidence interval is promoted as definitive. It is never labelled effort-corrected or coverage-standardized.

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
- Response years use one bout per plot-year and a recurrent plot panel.
- Circular-shift nulls preserve ordered response structure.
- No fitted line, causal wording, or Driver edge is allowed from this per-site screen.

## Parity requirements

For a selected site and snapshot, the following must match exactly:

- app headline values;
- report PDF values;
- `analysis_snapshot.csv` and `plots_snapshot.csv`;
- science fixture outputs;
- reference and provenance receipts, including the matching query-snapshot fields and durable raw-source inventory digest.

Any mismatch blocks release.

## Driver disposition

Current status: **CONTEXT / NO DRIVER BYTE CHANGE.** The candidate closes the plant source-receipt gate, but current Driver ingestion and inferential promotion remain held on explicit sampled opportunity, a measured eligible join, an independent adapter, and old/new parity.

Eligible after exact promotion as descriptive query-snapshot context: common-grain plot richness, introduced-cover composition, cross-scale occurrence, reference completeness, support, and uncertainty. Excluded: productivity vote, per-site climate–richness edges, management priority, and phenology signals owned by the Phenology app.
