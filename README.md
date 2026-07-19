# NEON Plant Diversity Explorer

See how plant communities change from **1 to 400 m²**, inspect native and introduced cover, and audit what the currently shipped bytes can—and cannot—support across 46 bundled NEON terrestrial sites.

[Open the public cover](https://tgilbert14.github.io/NEON-Plant-Diversity/) · [Launch the app](https://019ee109-30ae-006e-cb3b-143afeac57e3.share.connect.posit.cloud/) · [Open Driver Cascade](https://tgilbert14.github.io/NEON-Driver-Cascade/)

This is an independent, unofficial R/Shiny explorer for NEON **Plant presence and percent cover** (`DP1.10058.001`). It is the **composition and invasion context** app in the NEON Explorer Suite. It does not treat richness as productivity, turn per-site short records into causal climate edges, or make management prescriptions.

## Start with the honest question

The app is strongest at describing:

- plant richness at the stated nested grain: 1, 10, 100, or 400 m²;
- plot-level community composition and Hill diversity;
- relative ocular cover from sampled 1 m² quadrats;
- native, introduced, unknown, and contradictory nativity status;
- introduced-species occurrence at fine versus broad survey grain;
- reference-list completeness and review candidates;
- the exact plot, bout, survey-unit, source, and bundle support behind a result.

It does **not** establish:

- productivity, biomass, ecosystem health, impact, or cause from richness;
- percent of bare ground from overlapping ocular cover layers;
- temporal spread from a cross-scale occurrence gap;
- equal-effort national rankings from raw site richness;
- a site-wide expected flora from one NRCS reference coordinate;
- a Driver Cascade edge from a handful of within-site annual points.

## Product structure

The loaded app uses five top-level destinations instead of ten competing tabs:

| Destination | What is inside |
|---|---|
| **Overview** | Current plot snapshots, mean relative cover per supported plot, ground context, downloads, and a bundle receipt. |
| **Explore** | Diversity and Native vs Invasive, including nested species-area, Hill numbers, bias-corrected Chao2, recurrent-panel cover history, watchlist, and cross-scale occurrence. |
| **Network & QC** | Expected vs Observed, short-record climate/phenology context, and network-wide taxon/site search. |
| **Plots** | Diversity Lab, an accessible sortable plot table, plot profiles, and the site map. |
| **About** | Estimands, limitations, sources, licenses, suite role, and companion apps. |

The national picker sizes dots by **sampled plot support**, not raw richness. Within a loaded site, plot maps may size or colour by plot richness because every point shares the same 400 m² grain.

## Registered science contracts

### Current-state snapshot

`latest_snapshot()` keeps one latest `(year, bout)` snapshot per plot. It prevents two seasonal bouts or unequal visit histories from being pooled into one current-state richness number.

### Annual estimates

`snapshot_by_plot_year()` selects one deterministic bout per plot-year. Annual metrics are first calculated at plot level, then summarized over the recurrent plot panel represented in every included year. Every result carries plot, sampling-unit, and selected-bout support.

### Cover

Cover is recorded at 1 m². The app averages a species across known supported plots, allowing zero contribution where the species is absent from a supported plot. The current occurrence bundle cannot distinguish a truly sampled-but-empty quadrat from an unrepresented survey opportunity, so it does not claim a complete structural-zero correction. A future refresh contract must preserve an explicit opportunity table.

### Chao2

The app uses the incidence-based, finite-sample bias-corrected Chao2 lower-bound estimator of total richness. It is appropriate for repeated incidence units and is flagged when uniques/doubletons make it unstable. Chao2 minus observed richness is the estimated unseen component; neither quantity is an equal-coverage or equal-effort cross-site standardizer.

### Expected vs Observed

The current reference bundle resolves one site reference coordinate to one NRCS soil map unit and dominant ecological class. It is a **single-point reference context**, not a complete flora for every plot. Expected-but-not-detected is completeness, never error. Every observed-but-unlisted taxon remains reviewable; undocumented fuzzy/state-occurrence matching cannot silently demote it.

### Short-record context

Only complete annual context windows enter the association scan. The plant response uses the registered recurrent plot panel, and the null uses circular shifts that preserve the ordered response pattern. No fitted line is drawn, and no result becomes a Driver Cascade edge.

See [Science Contract](docs/SCIENCE-CONTRACT.md), [Data Takeaways](docs/DATA-TAKEAWAYS.md), and [Expert Review](docs/EXPERT-REVIEW.md).

## Data and exports

Committed per-site bundles live at `data/sites/<SITE>.rds` as `list(occ, ground, meta)`. The exact legacy 46-site family was introduced to this repository in commit `4ffcb24c3c1bf0dcab1f6c42fd3b9b5fe4de4e1e` on 2026-06-19. Its original NEON release, fetch/query cutoff, query receipt, and actual build date were not preserved. Accordingly, its `builtAt`, `neonRelease`, and `sourceCutoff` values remain `NA`; `repositoryImportedAt` and `sourceBundleCommit` record the repository receipt without pretending it is upstream vintage. The frozen-family guard identifies the exact bytes, which remain useful for descriptive ecology, but neither it nor filesystem, manifest, or runtime hashes establishes source recency. See the canonical [Plant Source Receipt](docs/PLANT-SOURCE-RECEIPT.md).

The app also ships 46 versioned-static environmental context bundles, a network search index, 34 currently available NRCS reference bundles, and an optional USDA authority file. The environment layer's partial provenance and independent refresh boundary are registered in [`docs/ENVIRONMENT-CONTEXT-RECEIPT.md`](docs/ENVIRONMENT-CONTEXT-RECEIPT.md).

The whole-site ZIP preserves:

- `occurrences_all.csv` — every bundled taxon record, including coarse IDs;
- `analysis_snapshot.csv` — the exact current-state plot snapshots;
- `plots_snapshot.csv` — plot-level richness, nativity, cover, coordinates, and support;
- `ground_cover_all.csv` — bundled ground-cover history;
- `environment_context.csv` — co-located context when available;
- `expected_vs_observed.csv` and `reference_provenance.csv` when a reference is available;
- `provenance.csv` — bundle checksum, source-receipt fields (including explicit unknowns), product, license, and estimator contract;
- `plant_raw_source_SHA256SUMS.txt` after a receipt-complete refresh — the durable per-file raw-source inventory bound by `sourceDigest`;
- `data_dictionary.csv` — strict meanings, types, units, NA semantics, and estimands for every exported column.

NEON data are licensed CC BY 4.0. NRCS reference sources are U.S. federal public-domain data. Source details and limitations travel with the export.

## Run locally

Use R 4.5.2 with the packages pinned by `manifest.json`:

```r
shiny::runApp(".", port = 8190)
```

Core data, analysis, notifications, and PNG export use committed local assets. Leaflet basemap tiles remain an optional external enhancement; without tile access, the data tables and analyses still work.

## Validate before release

```sh
Rscript scripts/test_science_contracts.R
Rscript scripts/verify_bundle.R
node scripts/check_custom_message_handlers.mjs
node scripts/check_cover.mjs
node --check www/app.js
node --check www/pincards.js
```

CI also parses every R file, verifies the manifest file/checksum closure, sources the app with network disabled, tests two-build determinism for derived artifacts, and runs a semantic deployment smoke check.

Read [Build–Test Handoff](docs/BUILD-TEST-HANDOFF.md) and [Deploy](DEPLOY.md) before changing data or release wiring.

## Refresh policy

A refresh is a candidate, not an automatic publication. Any refresh that fetches replacement plant bytes must replace the legacy-partial receipt with one complete matching receipt across all 46 plant bundles and `data/site_index.rds`:

1. fetch an explicit query cutoff and immutable query/snapshot ID into isolated staging; record an official NEON release only if that release was actually selected;
2. fail if any of the 46 expected sites is missing or failed, or if a consumed raw row has a foreign site identity or an unparseable/out-of-window `endDate`;
3. build all plant, completeness, demo, and search artifacts atomically; preserve the actual build date separately from the query cutoff, the durable per-file raw SHA-256 inventory and aggregate source digest, plus the builder commit; carry the separately versioned environment context forward byte-for-byte and revalidate its site/schema/runtime receipt;
4. prove schema, cross-index, scientific-fixture, manifest, offline-boot, and two-build determinism gates;
5. open a review branch/PR with the data and deletion diff;
6. publish only the reviewed commit and verify the public semantic readiness marker.

The automation opens a draft PR. CI compares the plant source family with the PR base and stays red until a human has reviewed and changed every provenance/current-status document, the Data Takeaways and Expert Review verdicts, Driver and suite handoffs, empirical cover facts, social/OG artwork, image-provenance checksums, cover receipt, and build handoff. Missing or deleted review surfaces also fail. Once any human review path exists on that branch, later scheduled runs preserve it and only post a newer-candidate notice. This prevents a technically valid query-snapshot refresh from silently leaving public legacy-family claims behind or overwriting review work.

The refresh workflow must never mix new partial raw data with old site bundles or push directly to `master`. `skip_download=true` revalidates the committed receipt and bytes; it does not stamp a new build date, release, cutoff, or source vintage.

## Suite role

Plant Diversity supplies **context only** to Driver Cascade today:

- eligible after exact-byte and contract validation as descriptive legacy context: common-grain plot richness, introduced-cover composition, cross-scale occurrence, reference completeness, support, and uncertainty; current-source Driver promotion remains blocked until a complete reviewed refresh receipt exists;
- excluded: productivity votes, management priority, per-site climate–richness fits, and duplicated phenology signals owned by the Phenology app.

The reusable lessons from this rebuild are recorded in [Suite Learning Handoff](docs/SUITE-LEARNING-HANDOFF.md) and the proposed Driver fields in [Driver Knowledge Package](docs/DRIVER-KNOWLEDGE-PACKAGE.md).

Built by Desert Data Labs. Independent and unofficial; not endorsed by NEON, Battelle, NSF, USDA, or NRCS.
