# Plant Diversity Science Contract

Status: registered for the v3 rebuild candidate. This document is normative; UI copy, exports, PDF output, tests, and Driver handoff must agree with it.

## Observation model

- Product: NEON Plant presence and percent cover (`DP1.10058.001`).
- Spatial grain: nested 1, 10, 100, and 400 m² incidence; ocular cover only at 1 m².
- Current-state unit: one latest registered `(year, bout)` snapshot per plot.
- Annual unit: one deterministic bout per plot-year, then a plot-level response.
- Cross-year estimand: mean plot-level response over the recurrent plot panel represented in every included year.
- Cover interpretation: relative ocular index with potentially overlapping vegetation layers; never a fraction of bare ground.
- Known opportunity limitation: occurrence bundles do not preserve an explicit table of sampled-but-empty quadrats. No function may claim a complete structural-zero correction until that table exists.

## Plant source-receipt contract

The current plant data are an exact, frozen legacy family, not a current-source claim. The 46-site `DP1.10058.001` family was introduced in repository commit `4ffcb24c3c1bf0dcab1f6c42fd3b9b5fe4de4e1e` on 2026-06-19 and is guarded by the canonical frozen-family SHA-256 recorded in [Plant Source Receipt](PLANT-SOURCE-RECEIPT.md). The original NEON release, fetch/query cutoff, query receipt, raw-source digest, and actual bundle build date were not preserved.

For this legacy family, `builtAt`, `neonRelease`, and `sourceCutoff` are `NA`. `repositoryImportedAt=2026-06-19` and `sourceBundleCommit=4ffcb24c3c1bf0dcab1f6c42fd3b9b5fe4de4e1e` identify repository receipt only. No filesystem mtime, commit date, manifest checksum, runtime checksum, or derived-artifact checksum may be substituted for an upstream source date, release, cutoff, query ID, or raw-source digest.

These exact bytes may support descriptive ecological values under the estimand and support rules below. They may not be labelled current, assigned an invented official release, or promoted as current-source Driver evidence. A future query-snapshot refresh requires one complete matching receipt across every one of the 46 plant bundles and `data/site_index.rds`, including a separate actual build date, query cutoff and immutable snapshot/query ID, true selected official release when applicable, raw/source digests, and builder commit. Revalidation without download preserves the existing receipt; it never stamps new provenance.

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
- reference and provenance receipts, including the plant source-receipt class and exact-family guard.

Any mismatch blocks release.

## Driver disposition

Current status: **context-only / hold current-source and inferential promotion**.

Eligible after byte and contract validation as descriptive legacy context: common-grain plot richness, introduced-cover composition, cross-scale occurrence, reference completeness, support, and uncertainty. Current-source promotion remains blocked until a complete reviewed plant refresh receipt exists. Excluded: productivity vote, per-site climate–richness edges, management priority, and phenology signals owned by the Phenology app.
