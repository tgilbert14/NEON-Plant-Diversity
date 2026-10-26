# NEON Plant Diversity Explorer

See how plant communities change from **1 to 400 m²**, inspect native and introduced cover, and see what the shipped records can and cannot support across 46 bundled NEON terrestrial sites.

[Open the public cover](https://tgilbert14.github.io/NEON-Plant-Diversity/) · [Launch the app](https://019ee109-30ae-006e-cb3b-143afeac57e3.share.connect.posit.cloud/) · [Open the NEON Cross-Product Response Atlas](https://tgilbert14.github.io/NEON-Driver-Cascade/)

Validated data candidate from refresh run `40364543238` (builder `486304d`, carried in PR #26) pins NEON **RELEASE-2026** (DOI [10.48443/9g4s-hq52](https://doi.org/10.48443/9g4s-hq52)) for the 46-site family: built 2026-10-26 from a `basic` query spanning 2013-01 through the closed cutoff 2026-09-30. Observations still end in 2024. The rows equal production's except 5,678 exact duplicate occurrence rows and 921 ground rows that the bundler now drops; six `site_index` introduced-cover values move by 0.1 to 0.5 points under the new sampled-quadrat denominator, and no richness or plot count moves. Production is master `d2b9f56` (app bytes from the PR #23 merge `d39b8d4`, with the 2026-10-21 receipt) until this candidate passes exact-head CI, merge, Connect, Pages, export, responsive, and semantic-health verification. See [Build-Test Handoff](docs/BUILD-TEST-HANDOFF.md).

This is an independent, unofficial R/Shiny explorer for NEON **Plant presence and percent cover** (`DP1.10058.001`). It is the **composition and invasion context** app in the NEON Explorer Suite. It does not treat richness as productivity, turn per-site short records into causal climate edges, or make management prescriptions.

## What the app describes

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
- a NEON Cross-Product Response Atlas edge from a handful of within-site annual points.

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

Since 2019 NEON surveys the 10 and 100 m² subplots every other year (changeLog 16204/16207), so a plot's latest year is often a 1 m²-only year. `site_snapshot()` therefore selects two labelled site events: a **grain event** (the latest year with 1, 10 and 100 m² rows; one bout; full-grain plots only) for every richness, species-area and plot-list figure, and a **cover event** (the latest complete 1 m² bout) for every cover-weighted figure (relative cover, Hill, Chao2, watchlist). Both labels appear in the hero band, the PDF and the exports. The old per-plot latest-year rule is gone; `latest_snapshot()` is a deprecated alias of the grain event.

### Annual estimates

`snapshot_by_plot_year()` selects one deterministic bout per plot-year. Annual metrics are first calculated at plot level, then summarized over the recurrent plot panel represented in every included year. Every result carries plot, sampling-unit, and selected-bout support.

### Cover

Cover is recorded at 1 m². The app averages a species across known supported plots, allowing zero contribution where the species is absent from a supported plot. The current occurrence bundle cannot distinguish a truly sampled-but-empty quadrat from an unrepresented survey opportunity, so it does not claim a complete structural-zero correction. A future refresh contract must preserve an explicit opportunity table.

### Chao2

The app uses the incidence-based, finite-sample bias-corrected Chao2 lower-bound estimator of total richness. It is appropriate for repeated incidence units and is flagged when uniques/doubletons make it unstable. Chao2 minus observed richness is the estimated unseen component; neither quantity is an equal-coverage or equal-effort cross-site standardizer.

### Expected vs Observed

The current reference bundle resolves one site reference coordinate to one NRCS soil map unit and dominant ecological class. It is a **single-point reference context**, not a complete flora for every plot. Expected-but-not-detected is completeness, never error. Every observed-but-unlisted taxon remains reviewable; undocumented fuzzy/state-occurrence matching cannot silently demote it.

### Short-record context

Only complete annual context windows enter the association scan. The plant response uses the registered recurrent plot panel, and the null uses circular shifts that preserve the ordered response pattern. No fitted line is drawn, and no result becomes an edge in the NEON Cross-Product Response Atlas.

See [Science Contract](docs/SCIENCE-CONTRACT.md), [Data Takeaways](docs/DATA-TAKEAWAYS.md), and [Expert Review](docs/EXPERT-REVIEW.md).

## Data and exports

Committed per-site bundles live at `data/sites/<SITE>.rds` as `list(occ, ground, meta)`. Every candidate bundle and `data/site_index.rds` carries the same `plant-source-receipt-v2`: build date `2026-10-26`, source interval `2013-01` through `2026-09-30`, NEON release `RELEASE-2026`, immutable receipt ID `PDE-DP1.10058.001-query-through-2026-09-30-sha256-3e484580d6c3198cb9eff6c1e300a9da31fa18d82c91b31daae450408f19e6bc`, raw-inventory digest `3e484580d6c3198cb9eff6c1e300a9da31fa18d82c91b31daae450408f19e6bc`, builder commit `486304df47c87068386d306b597a0655351b19fc`, `basic` query package, and `neonUtilities 4.0.2`. `data/site_index.rds` and `data/search_index.rds` also declare `snapshot_contract = plant-snapshot-v2`, and `data/source/neon-change-log.json` holds NEON's change log for the product. The cutoff identifies the closed query boundary; retained records span 2013 to 2024, and provisional 2025 bouts at NEON are excluded. Earlier receipts are kept as rollback history in the receipt file. See the canonical [Plant Source Receipt](docs/PLANT-SOURCE-RECEIPT.md).

The app also ships 46 versioned-static environmental context bundles, a network search index, 34 currently available NRCS reference bundles, and an optional USDA authority file. The environment layer's partial provenance and independent refresh boundary are registered in [`docs/ENVIRONMENT-CONTEXT-RECEIPT.md`](docs/ENVIRONMENT-CONTEXT-RECEIPT.md).

The whole-site ZIP preserves:

- `occurrences_all.csv`: every bundled taxon record, including coarse IDs;
- `analysis_snapshot.csv`: the records of the full-grain site event behind richness and species-area;
- `cover_snapshot.csv`: the records of the 1 m² cover event behind cover, Hill numbers, Chao2 and the watchlist;
- `plots_snapshot.csv`: plot-level richness, nativity, cover, coordinates, and support;
- `ground_cover_all.csv`: bundled ground-cover history;
- `environment_context.csv`: co-located context when available;
- `expected_vs_observed.csv`, `reference_provenance.csv` and `qc_flags.csv` when a reference is available;
- `provenance.csv`: bundle checksum, source-receipt fields (including explicit unknowns), NEON release and DOI, product, license, and estimator contract;
- `plant_raw_source_SHA256SUMS.txt` after a receipt-complete refresh: the durable per-file raw-source inventory bound by `sourceDigest`;
- `data_dictionary.csv`: strict meanings, types, units, NA semantics, and estimands for every exported column. The same dictionary opens in the app's About panel and downloads on its own.

NEON data are licensed CC BY 4.0. Cite them as: NEON (National Ecological Observatory Network). Plant presence and percent cover (DP1.10058.001), RELEASE-2026. https://doi.org/10.48443/9g4s-hq52. Dataset accessed from https://data.neonscience.org. NRCS reference sources are U.S. federal public-domain data. Source details and limitations travel with the export.

NEON publishes this product at 47 terrestrial sites. Pu'u Maka'ala (PUUM, Hawai'i) is not yet bundled here: its USDA nativity authority entries, NRCS reference lookup and environment overlay need their own build before the 46-site checks can move to 47. NEON suspended field sampling for this product in 2026 (change log 110012), and field operations at Dead Lake (DELA) ended on 2025-12-31 (change log 110614); the app shows both as NEON notices.

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

1. fetch the pinned NEON release (`R/plant_release.R`) up to an explicit query cutoff and immutable query/snapshot ID into isolated staging, rejecting any row from another release, and save NEON's change log for the product;
2. fail if any of the 46 expected sites is missing or failed, or if a consumed raw row has a foreign site identity or an unparseable/out-of-window `endDate`;
3. build all plant, completeness, demo, and search artifacts atomically; preserve the actual build date separately from the query cutoff, the durable per-file raw SHA-256 inventory and aggregate source digest, plus the builder commit; carry the separately versioned environment context forward byte-for-byte and revalidate its site/schema/runtime receipt;
4. prove schema, cross-index, scientific-fixture, manifest, offline-boot, and two-build determinism gates;
5. publish a review branch only when the content changed (receipt or checksum churn alone publishes nothing), and open or update one tracking issue; a person opens the PR;
6. publish only the reviewed commit and verify the public semantic readiness marker.

A person opens the review PR as a draft. CI compares the plant source family with the PR base and stays red until a human has reviewed and changed every provenance/current-status document, the Data Takeaways and Expert Review verdicts, Driver and suite handoffs, empirical cover facts, social/OG artwork, image-provenance checksums, cover receipt, and build handoff. Missing or deleted review surfaces also fail. Once any human review path exists on that branch, later scheduled runs preserve it and only post a newer-candidate notice. This prevents a technically valid query-snapshot refresh from silently leaving public legacy-family claims behind or overwriting review work.

The refresh workflow must never mix new partial raw data with old site bundles or push directly to `master`. `skip_download=true` revalidates the committed receipt and bytes; it does not stamp a new build date, release, cutoff, or source vintage.

## Suite role

Plant Diversity's disposition is **CONTEXT / HOLD DRIVER INGESTION / NO DRIVER BYTE CHANGE** for the 2026-10-26 RELEASE-2026 candidate:

- eligible after promotion as descriptive query-snapshot context: common-grain plot richness, introduced-cover composition, cross-scale occurrence, reference completeness, support, and uncertainty. This candidate closes the missing plant source-receipt gate, but Driver ingestion remains held until an explicit sampled-opportunity ledger, a measured eligible Driver join, an independent adapter, and old/new parity are reviewed;
- excluded: productivity votes, management priority, per-site climate–richness fits, and duplicated phenology signals owned by the Phenology app.

The reusable lessons from this rebuild are recorded in [Suite Learning Handoff](docs/SUITE-LEARNING-HANDOFF.md) and the proposed Driver fields in [Driver Knowledge Package](docs/DRIVER-KNOWLEDGE-PACKAGE.md).

Built by Desert Data Labs. Independent and unofficial; not endorsed by NEON, Battelle, NSF, USDA, or NRCS.
