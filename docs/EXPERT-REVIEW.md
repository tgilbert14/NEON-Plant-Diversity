# Plant Presence and Percent Cover — Expert Review

_NEON DP1.10058.001 · human source-family review for candidate 2026-10-21_

> **Review verdict:** validated candidate `a9fc28fdaebd318744dadde341c0cca55a91a899` carries the registered plant-snapshot-v2 estimator contract, one complete 46-site query receipt through 2026-09-30, and no row change at any site; its index values move only because the index is now built under plant-snapshot-v2. The candidate-metric oracle rerun is pending. It is eligible to proceed to literal-head CI and production review, not yet to be called deployed. Causal, productivity, health, management, equal-effort ranking, and Driver-vote claims remain out of scope.

The refresh re-stamps the query receipt without changing any observation, and it is the first full refresh to build the site index under the plant-snapshot-v2 contract. It records an actual build date and closed query boundary while preserving `neonRelease=NA` because no official release was selected. Complete provenance strengthens exact-source interpretation; it does not manufacture survey opportunity or inference.

## Method fidelity

The app preserves the load-bearing parts of the NEON plant-diversity design:

- nested incidence at 1, 10, 100, and 400 m²;
- ocular cover only at 1 m²;
- species-level analysis separated from coarse taxonomic records;
- two labelled site events for current-state analyses (`plant-snapshot-v2`): a full-grain event for richness and species-area, a 1 m² cover event for cover-weighted figures;
- Unknown nativity retained as an explicit category;
- cover described as an overlapping relative index, never a ground-share partition.

The `snapshot_by_plot_year()` contract closes the multi-bout ambiguity for annual series. The 2026-10-18 audit found that the former per-plot `latest_snapshot()` selected 1 m²-only years at 40 of 46 sites because NEON surveys the 10 and 100 m² subplots biennially since 2019, so the current-state model was rewritten as two labelled site events (`site_snapshot()`): richness and species-area come from the latest full-grain `(year, bout)` with full-grain plots only; cover, Hill, Chao2 and the watchlist come from the latest complete 1 m² bout. Plots outside an event are reported as unsupported rather than carried forward from older years (CPER no longer keeps 36 plots last surveyed in 2013). The trade-off against a single event for everything is recorded in the science contract and the PR.

## Estimator review

### Species-area

The nested species-area curve remains the app's most direct quantity. It is computed per plot on the grain event and then summarized by scale. The 10 m² point is the mean over 10 m² subplots of each subplot's own rows plus its nested 1 m² quadrat; the former corner union merged both 10 m² subplots of a corner into a 10/20 m² mix (about +23% at SRER). The registered implementation counts only finite plot values in scale-specific `n`, and reports SD only when at least two plots support that scale.

### Chao2

Incidence-based Chao2 is the appropriate estimator family for 1 m² presence units, but the former implementation mixed a classic formula, a bias-corrected label, and an approximate interval. The promoted release registers one formula:

`S_obs + ((m - 1) / m) * Q1 * (Q1 - 1) / (2 * (Q2 + 1))`

The result is a lower-bound estimate of the 1 m² quadrat species pool; its difference from the 1 m² `S_obs` printed beside it is the estimated unseen component. It must never be read against the plot-wide species count, which includes 10 and 100 m² detections and exceeded Chao2 at 23 of 46 sites in the compare modal and PDF before this fix. `Q1`, `Q2`, `m`, and instability remain visible; no unsupported upper confidence limit is invented. It is not coverage-standardized, and its incidence-unit denominator remains limited by the absence of an explicit sampled-empty-quadrat table.

### Cover and Hill weights

Species and watchlist cover are aggregated across all known supported plots rather than only plots where the focal species occurs. Contradictory nativity records are routed to Unknown before nativity partitions are calculated. This is more defensible than present-only averaging.

One limitation remains: the bundles identify subplots through occurrence records, not through a complete survey-opportunity ledger. Known absences can contribute zero; unrecorded opportunity cannot. Hill numbers therefore remain cover-weighted descriptive profiles, not fully opportunity-standardized abundance estimates.

### Annual responses

Annual richness, total relative cover, introduced-cover share, and nativity trends use one selected bout per plot-year and recurrent plot panels. The annual richness response is mean 1 m² subplot richness per plot: the whole-plot list alternates with the biennial 10/100 m² schedule (SRER odd years 42.3, even years 16.7), so the former 400 m² annual series was a sampling-design sawtooth. The 2018, 2019 and 2026 design breaks (changeLog 16203, 16207, 110012) are drawn on every annual chart and no line crosses 2019. The environment screen requires at least 6 matched years and p < 0.10 before any pattern wording.

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
- the PDF uses the same two labelled events as the app for richness, species-area, cover and Chao2.

These safeguards retain the 2026-07-19 production receipt. For the new source family, hard-assertion R fixtures, deterministic artifacts, exact manifest validation, offline sourcing, export/PDF inspection, and deployed semantic health must all rerun on the literal reviewed head before promotion.

## Plant source-provenance review

Every candidate site bundle and `data/site_index.rds` carries `plant-source-receipt-v2`: `builtAt=2026-10-21`, `sourceStart=2013-01`, `sourceCutoff=2026-09-30`, receipt ID `PDE-DP1.10058.001-query-through-2026-09-30-sha256-d7e9e0de7d8e624cb4e4f9d6d64b4a41ae58f09ead497ce1307983b797811cc7`, raw-inventory digest `d7e9e0de7d8e624cb4e4f9d6d64b4a41ae58f09ead497ce1307983b797811cc7`, builder commit `280539c8713c16b6b13d47d5916e0f50a10edd24`, `basic`, and `neonUtilities 4.0.2`. The durable raw inventory has exactly 46 scoped entries, all with new per-file digests because upstream byte order changed. No official release was selected, so `neonRelease=NA` is the supported value. `site_index.rds` and `search_index.rds` declare `snapshot_contract = plant-snapshot-v2`.

The query cutoff is a request boundary, not an observation date: retained records span 2013 to 2024, and NEON's provisional 2025 bouts are excluded. The 2026-08-03 receipt (cutoff 2026-07-31, digest `48167b04cc689fbcaaa3e83bdac7cc7ed1c8ac34f791e5e76d3f229862d61ac6`) and the older legacy guard remain rollback history. Repository dates, mtimes, manifest/runtime hashes, and derived checksums remain ineligible substitutes for source fields.

The row oracle found occurrence and ground row multisets unchanged at 46 of 46 sites and one retained schema across all bundles: 1,375,149 occurrence rows and 451,979 ground rows across 1,574 plots, the 2026-08-03 totals. Six bundles (CPER, DEJU, OAES, OSBS, SCBI, STEI) differ only in row order. 43 of 46 index rows still change, because the grain event (richness, plots) and the 1 m² cover event (introduced cover) replace the retired per-plot latest-year rule: SRER 161 to 203 species at 33 plots, CPER 102 to 92 species with plots 70 to 33, JORN 80 to 66, STER 20 to 30. That movement is contract-driven and should be reviewed as a method correction, not as new data. The old candidate oracle rebuilt the retired snapshot and could not reconcile to a v2 index, so it was rewritten to plant-snapshot-v2 for this review. The rewritten candidate oracle (`scripts/review_refresh_candidate.R`, base R, no app helpers sourced) passed against this head: 46-site identity, one bundle schema, one matching receipt across every bundle and `data/site_index.rds`, and independent plant-snapshot-v2 parity (grain-event richness and plots, cover-event introduced cover) with the index. Network totals are unchanged from master under the same rule: 1,375,149 occurrence rows, 451,979 ground rows, 1,217,691 species-level rows, 1,574 plots, 1,047 grain-event plots, 6,603 1 m² incidence units, 5,840 species-level names (0 added, 0 removed); every per-site delta is zero. Its informational block lists the 43 sites where master's pre-v2 index differs from the v2 reconstruction.

## Production evidence and remaining scientific limits

The candidate inventory contains 46 site bundles, 46 environment bundles byte-identical to master (same Git tree), and 34 site reference artifacts plus the completeness index carried unchanged from master, where PR #20 rebuilt the completeness index under plant-snapshot-v2. Refresh run `39546911504` establishes the data candidate; run `39542458760` built the same bytes and its publisher refused because master moved mid-run. Master `280539c8713c16b6b13d47d5916e0f50a10edd24` is live on Connect with the plant-snapshot-v2 code and a pre-v2 site index (post-deploy smoke `39544227599` passed). Public/export QA still must confirm parity for the final reviewed head.

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
| Nested-scale fidelity | Repaired 2026-10-18: grain event and per-subplot 10 m² point | Preserve exact grain/support labels; regenerate `site_index` by refresh |
| Chao2 | Correctly labelled lower-bound contract | Add explicit sampled-opportunity data |
| Cover interpretation | Honest relative-index framing | Add explicit sampled-empty opportunity data |
| Nativity/QC | Conflicts and regional limits gated | Preserve authority provenance |
| Expected/reference flora | Correctly limited to one local reference | Build plot/buffer-matched references before stronger claims |
| Annual metrics | Recurrent plot-panel estimands validated | Preserve panel and bout support |
| Environment | Descriptive and non-causal | No Driver promotion from this screen |
| Export/provenance | Complete 46-site query receipt and raw inventory independently reconciled | Keep `neonRelease=NA`; preserve cutoff ≠ observation-year distinction |
| Release status | 2026-10-21 data candidate validated (no row change, v2 index); production is master `280539c` with a pre-v2 index | Require literal-head CI, export/PDF parity, merge, deploy, mobile, and post-deploy receipts |

## Suite and Driver disposition

Plant Diversity is a composition context app, not a productivity or phenology authority. Its validated suite contribution may include common-grain plot richness, introduced-cover composition, cross-scale occurrence, reference completeness, and their support. After promotion these are descriptive query-snapshot context. The complete-receipt gate is closed; explicit sampled opportunity, a measured Driver join, an independent adapter, and old/new parity remain held.

The app must not contribute a productivity vote, management priority, per-site climate–richness edge, or phenology signal owned by the Phenology app. Driver disposition is **CONTEXT / HOLD DRIVER INGESTION / NO DRIVER BYTE CHANGE** for this pass.

## Final recommendation

The candidate's source and row review passes, and its candidate-metric oracle rerun is pending. It should proceed to literal-head CI and, only after a green exact reviewed commit, to merge and deployment verification. The last-known-good public release remains authoritative until app/export/PDF parity, responsive QA, Connect/Pages identity, and semantic health close. `neonRelease=NA`, missing sampled-empty opportunity, and descriptive-only Driver status remain explicit; every later refresh must repeat the full handoff.
