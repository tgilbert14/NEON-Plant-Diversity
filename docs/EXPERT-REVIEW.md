# Plant Presence and Percent Cover — Expert Review

_NEON DP1.10058.001 · review updated for the v3 candidate science contract_

> **Review verdict:** the candidate now has a defensible analysis contract, but it is not yet a validated empirical release. Method rules, bundled-data facts, and ecological findings are different layers of evidence. This review endorses the first, records the second, and withholds the third until the build and deployment receipts pass.

The source-receipt correction establishes a separate limit: the exact legacy plant bytes can be identified, but their upstream date cannot. The current family is descriptive legacy context, not current-source evidence.

## Method fidelity

The app preserves the load-bearing parts of the NEON plant-diversity design:

- nested incidence at 1, 10, 100, and 400 m²;
- ocular cover only at 1 m²;
- species-level analysis separated from coarse taxonomic records;
- one selected survey event per plot for current-state analyses;
- Unknown nativity retained as an explicit category;
- cover described as an overlapping relative index, never a ground-share partition.

The new `snapshot_by_plot_year()` contract closes the previous multi-bout ambiguity. Selection is deterministic, emits support, and is tested for row-order invariance. `latest_snapshot()` builds on that contract, so app summaries, report values, and snapshot exports have one registered observation model.

## Estimator review

### Species-area

The nested species-area curve remains the app's most direct quantity. It is computed per plot and then summarized by scale. The candidate now counts only finite plot values in scale-specific `n`, and reports SD only when at least two plots support that scale. This is a product-contract strength; site-specific curve values still require candidate revalidation.

### Chao2

Incidence-based Chao2 is the appropriate estimator family for 1 m² presence units, but the former implementation mixed a classic formula, a bias-corrected label, and an approximate interval. The candidate now registers one formula:

`S_obs + ((m - 1) / m) * Q1 * (Q1 - 1) / (2 * (Q2 + 1))`

The result is a lower-bound estimate of total richness; its difference from observed richness is the estimated unseen component. `Q1`, `Q2`, `m`, and instability remain visible; no unsupported upper confidence limit is invented. It is not coverage-standardized, and its incidence-unit denominator remains limited by the absence of an explicit sampled-empty-quadrat table.

### Cover and Hill weights

Species and watchlist cover are aggregated across all known supported plots rather than only plots where the focal species occurs. Contradictory nativity records are routed to Unknown before nativity partitions are calculated. This is more defensible than present-only averaging.

One limitation remains: the bundles identify subplots through occurrence records, not through a complete survey-opportunity ledger. Known absences can contribute zero; unrecorded opportunity cannot. Hill numbers therefore remain cover-weighted descriptive profiles, not fully opportunity-standardized abundance estimates.

### Annual responses

Annual richness, total relative cover, introduced-cover share, and nativity trends now use one selected bout per plot-year and recurrent plot panels. The estimand is a mean plot-level response, with plot and sampling-unit support, rather than a site total that changes when effort changes.

This is the correct contract for descriptive time series. It does not by itself solve short records, observation error, shared trends, or causal identification.

## Taxonomy, nativity, and reference review

- Coarse IDs remain available in the all-record export but are excluded from species estimands.
- A taxon recorded as both Native and Introduced is classified Unknown/review, not resolved by mode and not counted in both categories.
- USDA lower-48 nativity comparisons do not run at Alaska, Hawaiʻi, or Puerto Rico sites.
- State-occurrence matches no longer demote observed-not-reference species. Every such record remains review until per-match source, query, confidence, dataset, and license provenance are available.
- The NRCS list is explicitly scoped to one site reference coordinate and selected soil/ecological unit. It is not a site-wide expected flora.

The scientific framing follows from those constraints: reference overlap is completeness context; reference absence is not a NEON error; and observed-not-reference is a review list rather than proof of misidentification or range expansion.

## Environment review

The former seasonal Driver/Cascade interpretation has been removed from this app. The remaining environment screen is deliberately narrow:

- annual precipitation, temperature, flowering, and green-up only;
- exactly 12 non-missing monthly values per annual driver;
- recurrent plot-panel responses with one bout per plot-year;
- Spearman scans with circular-shift nulls;
- exploratory language regardless of effect size.

Fruiting intensity and incomplete seasonal aggregates are excluded. The app does not own a suite-level phenology result, does not fit a per-site causal edge, and does not promote its short annual associations to Driver.

## Export and parity review

The export contract is now materially stronger:

- full occurrences and the analysis snapshot are separate files;
- plot, ground, environment, expected/reference, and release provenance are separately scoped;
- the strict data dictionary is generated from the emitted frames and fails on unknown or duplicate columns;
- definitions, units, NA semantics, and estimands accompany every exported field;
- the PDF uses the same selected snapshot for richness, species-area, and Chao2.

These are implemented safeguards, not yet a release receipt. The candidate still needs an R execution of the hard-assertion fixtures, exact manifest validation, export inspection, and deployed semantic health evidence.

## Plant source-provenance review

The exact 46-site `DP1.10058.001` family was introduced by repository commit `4ffcb24c3c1bf0dcab1f6c42fd3b9b5fe4de4e1e` on 2026-06-19. The canonical frozen-family SHA-256 in [Plant Source Receipt](PLANT-SOURCE-RECEIPT.md) is a valid exact-byte identity guard. The superseded MD5-based inventory hashes are useful only for audit reconciliation. Neither checksum family, the commit date, filesystem mtimes, nor manifest/runtime hashes is evidence of the original NEON fetch date or release.

The original official NEON release, fetch/query cutoff, query receipt, raw-source digest, and actual bundle build date were not preserved. The scientifically honest legacy values are therefore `builtAt=NA`, `neonRelease=NA`, and `sourceCutoff=NA`, with `repositoryImportedAt` and `sourceBundleCommit` reported separately. Exact-byte validation allows ecological values to remain descriptive for this frozen family; it does not make them current-source results.

## Current evidence and unresolved validation

Repository inventory currently shows 46 site bundles, 46 environment bundles, and 34 site reference artifacts. That supports coverage accounting only. It does not validate the ecological values previously quoted in this review.

The following remain unresolved until the candidate is frozen and tested:

1. empirical recomputation of site metrics under the new bout, recurrent-panel, cover, nativity, and Chao2 contracts;
2. an explicit sampled-opportunity artifact for empty 1 m² quadrats;
3. a complete current-source plant receipt from a future reviewed refresh; the legacy family has an exact-byte receipt, but its missing upstream vintage/release fields cannot be reconstructed;
4. deterministic derived-artifact and manifest equality;
5. cold/offline application boot and export generation;
6. public Connect deployment identity, semantic readiness, console health, and desktop/mobile review.

Earlier claims such as named site rankings, exact invasion percentages, Chao2 values, or significant/non-significant site correlations are historical calculations, not current candidate findings. They must not be copied into UI, reports, or Driver context without recomputation and a source-byte receipt.

## Product honesty scorecard

| Dimension | Candidate assessment | Remaining condition |
|---|---|---|
| Observation model | Registered and testable | Execute fixtures in R/CI |
| Nested-scale fidelity | Strong | Recompute candidate values |
| Chao2 | Correctly labelled lower-bound contract | Validate bundle opportunity/support |
| Cover interpretation | Honest relative-index framing | Add explicit sampled-empty opportunity data |
| Nativity/QC | Conflicts and regional limits gated | Preserve authority provenance |
| Expected/reference flora | Correctly limited to one local reference | Build plot/buffer-matched references before stronger claims |
| Annual metrics | Recurrent plot-panel estimands | Validate support across all sites |
| Environment | Descriptive and non-causal | No Driver promotion from this screen |
| Export/provenance | Exact legacy family identified; upstream receipt incomplete | Preserve `NA` source fields and inspect ZIP/PDF, source receipt, and exact manifest |
| Release status | Not yet promoted | Complete BUILD-TEST-HANDOFF receipts |

## Suite and Driver disposition

Plant Diversity is a composition context app, not a productivity or phenology authority. Its eventual suite contribution may include common-grain plot richness, introduced-cover composition, cross-scale occurrence, reference completeness, and their support. Those remain descriptive legacy context until candidate bytes and contracts are validated. Even after that validation, current-source promotion stays blocked until all 46 replacement bundles and `site_index.rds` carry one complete matching receipt.

The app must not contribute a productivity vote, management priority, per-site climate–richness edge, or phenology signal owned by the Phenology app. Driver disposition remains **context-only / hold current-source and inferential promotion**.

## Final recommendation

Do not publish a “science complete” verdict from code inspection alone. Run the full handoff, recompute empirical summaries from the reviewed commit, inspect the generated exports and PDF, and record the deployed identity. If those receipts pass, the candidate's method contract and descriptive results for the exact legacy bytes are defensible; the missing upstream release/cutoff/build receipt remains missing. If the gates fail, preserve the failure as part of the suite learning loop and keep the last known-good release in place.
