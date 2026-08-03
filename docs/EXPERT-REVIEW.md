# Plant Presence and Percent Cover — Expert Review

_NEON DP1.10058.001 · human source-family review for candidate 2026-08-03_

> **Review verdict:** validated candidate `374fb704c548ca830f05c46d5fab1331e0027302` has a defensible unchanged estimator contract, one complete 46-site query receipt, and independently reconciled bundle/index semantics. It is eligible to proceed to literal-head CI and production review, not yet to be called deployed. Causal, productivity, health, management, equal-effort ranking, and Driver-vote claims remain out of scope.

The refresh closes the legacy family's missing upstream query receipt without changing the observation model. It records an actual build date and closed query boundary while preserving `neonRelease=NA` because no official release was selected. Complete provenance strengthens exact-source interpretation; it does not manufacture survey opportunity or inference.

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

The nested species-area curve remains the app's most direct quantity. It is computed per plot and then summarized by scale. The registered implementation counts only finite plot values in scale-specific `n`, and reports SD only when at least two plots support that scale. This is a product-contract strength; site-specific values remain descriptive for the exact reviewed source family.

### Chao2

Incidence-based Chao2 is the appropriate estimator family for 1 m² presence units, but the former implementation mixed a classic formula, a bias-corrected label, and an approximate interval. The promoted release registers one formula:

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

These safeguards retain the 2026-07-19 production receipt. For the new source family, hard-assertion R fixtures, deterministic artifacts, exact manifest validation, offline sourcing, export/PDF inspection, and deployed semantic health must all rerun on the literal reviewed head before promotion.

## Plant source-provenance review

Every candidate site bundle and `data/site_index.rds` carries `plant-source-receipt-v2`: `builtAt=2026-08-03`, `sourceStart=2013-01`, `sourceCutoff=2026-07-31`, receipt ID `PDE-DP1.10058.001-query-through-2026-07-31-sha256-48167b04cc689fbcaaa3e83bdac7cc7ed1c8ac34f791e5e76d3f229862d61ac6`, raw-inventory digest `48167b04cc689fbcaaa3e83bdac7cc7ed1c8ac34f791e5e76d3f229862d61ac6`, builder commit `1734840a4f09e7acee356431ea1e57e9a637fb31`, `basic`, and `neonUtilities 4.0.1`. The durable raw inventory has exactly 46 scoped entries. No official release was selected, so `neonRelease=NA` is the supported value.

The query cutoff is a request boundary, not an observation date: retained records span 2013–2024. The prior legacy guard remains rollback history but no longer describes the candidate. Repository dates, mtimes, manifest/runtime hashes, and derived checksums remain ineligible substitutes for source fields.

An independent base-R oracle found 1,375,149 occurrence rows, 451,979 ground rows, 1,574 plots, and 5,840 distinct species-level names across all historical records. Forty-three site row families are semantically unchanged; only JORN, KONZ, and SRER gained rows. Sixty-three species-level names were added nationally and none removed. Candidate snapshot/index parity passed across all 46 sites. JORN, KONZ, and SRER changed current-state values because newer surveys became the deterministic latest plot snapshots, not because historical rows were deleted.

## Production evidence and remaining scientific limits

The candidate inventory contains 46 site bundles, 46 byte-unchanged environment bundles, and 34 byte-unchanged site reference artifacts; only the derived completeness index changed with plant snapshots. Producer/validator run `30818211291` and artifact `8858560431` establish the data candidate. Public/export QA still must confirm parity for the final reviewed head. Complete source provenance supports exact query-snapshot interpretation; it does not create broader inferential authority.

The following remain scientific limits rather than unfinished release gates:

1. an explicit sampled-opportunity artifact for empty 1 m² quadrats;
2. a measured eligible site-year Driver join and independent adapter; the source-receipt gate is satisfied by this candidate, but no Driver ingestion parity has been run;
3. a coverage-standardized cross-site estimator before any national richness ranking;
4. plot- or buffer-matched reference flora before stronger expected/observed conclusions.

Named site rankings, Chao2 values, invasion percentages, or association screens may be shown only when generated from the promoted code with their estimand, support, and query-snapshot receipt. They must not be detached from those qualifications or copied into Driver as causal, productivity, health, management, or vote-eligible evidence.

## Product honesty scorecard

| Dimension | Production assessment | Remaining condition |
|---|---|---|
| Observation model | Registered and validated | Preserve fixtures and export parity |
| Nested-scale fidelity | Strong and release-tested | Preserve exact grain/support labels |
| Chao2 | Correctly labelled lower-bound contract | Add explicit sampled-opportunity data |
| Cover interpretation | Honest relative-index framing | Add explicit sampled-empty opportunity data |
| Nativity/QC | Conflicts and regional limits gated | Preserve authority provenance |
| Expected/reference flora | Correctly limited to one local reference | Build plot/buffer-matched references before stronger claims |
| Annual metrics | Recurrent plot-panel estimands validated | Preserve panel and bout support |
| Environment | Descriptive and non-causal | No Driver promotion from this screen |
| Export/provenance | Complete 46-site query receipt and raw inventory independently reconciled | Keep `neonRelease=NA`; preserve cutoff ≠ observation-year distinction |
| Release status | Data candidate validated; public production still on 2026-07-19 release | Require literal-head CI, export/PDF parity, merge, deploy, mobile, and post-deploy receipts |

## Suite and Driver disposition

Plant Diversity is a composition context app, not a productivity or phenology authority. Its validated suite contribution may include common-grain plot richness, introduced-cover composition, cross-scale occurrence, reference completeness, and their support. After promotion these are descriptive query-snapshot context. The complete-receipt gate is closed; explicit sampled opportunity, a measured Driver join, an independent adapter, and old/new parity remain held.

The app must not contribute a productivity vote, management priority, per-site climate–richness edge, or phenology signal owned by the Phenology app. Driver disposition is **CONTEXT / NO DRIVER BYTE CHANGE** for this pass.

## Final recommendation

The candidate's source and semantic review passes. It should proceed to literal-head CI and, only after a green exact reviewed commit, to merge and deployment verification. The last-known-good public release remains authoritative until app/export/PDF parity, responsive QA, Connect/Pages identity, and semantic health close. `neonRelease=NA`, missing sampled-empty opportunity, and descriptive-only Driver status remain explicit; every later refresh must repeat the full handoff.
