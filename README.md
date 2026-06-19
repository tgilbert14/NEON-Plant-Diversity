# NEON Plant Diversity Explorer

An (unofficial) R/Shiny explorer for NEON's **Plant presence & percent cover** product
(**DP1.10058.001**) — a *NEONize* sibling of the [NEON Small Mammal Tracker][smt], built to
the same Desert Data Labs quality bar but with analyses native to plant-community data.

> Plants have no marked individuals, so this app's unit is the **plot** (and the **species**),
> not an animal's capture career. There is no dossier / Hall of Fame / home range here — instead:
> cover, nested species-area curves, native vs. invasive, and a per-plot drill-down.

## What it shows

| Tab | Content |
|---|---|
| **Overview** | Cover composition (native vs. introduced), an auto-written "story", ground-cover (soil/litter/rock). |
| **Diversity** | Nested **species-area curve** (1 → 10 → 100 → 400 m²), the **Hill** diversity profile (q0/q1/q2), and a **Chao2** incidence-based richness estimate. |
| **Native vs Invasive** | Introduced-cover share over time, an invasive **watchlist**, and the **Invasion-Pressure** index (introduced species already detectable at the 1 m² scale). |
| **Diversity Lab** | The flagship: every plot as a dot (richness × % introduced cover), **tap-to-pin** plot cards, named quadrants, export-with-pins. |
| **Plot Profile** | The drill-down: a downloadable plot card (PNG + CSV) — richness, native/introduced split, species-area sparkline, top plants by cover. |
| **Map** | Plot markers sized by richness, coloured by richness or % introduced. |
| **About** | Methods + caveats. |

## Run it

R 4.5.x (the app is bundle-only — no network needed):

```r
shiny::runApp(".", port = 8190)
```

The Santa Rita (**SRER**) demo — a Sonoran desert grassland with a textbook *Eragrostis
lehmanniana* (Lehmann lovegrass) invasion — loads instantly. KONZ (Konza tallgrass) and JORN
(Jornada) are also bundled.

## Data

Per-site bundles live in `data/sites/<SITE>.rds` as `list(occ, ground, meta)`:

- **`occ`** — one row per taxon occurrence at a scale (1 / 10 / 100 m²): `plotID, subplotID,
  scale, year, taxonID, scientificName, taxonRank, family, nativeStatusCode, nativity,
  percentCover` (cover only at 1 m²), `is_species, plotType, nlcdClass, lat, lng`.
- **`ground`** — abiotic 1 m² ground cover (soil, litter, rock, biocrust, …).

### Rebuild the bundles

NEON pulls need **R-4.1.1** (neonUtilities; R-4.5.2 crashes on `loadByProduct`) and a token in
`.neon_token`:

1. Fetch raw: `Rscript-4.1.1 ../App-NEON-Small-Mammal-Tracker/scripts/fetch_plant_demo.R`
   (writes `../plant-data-fetch/<SITE>_raw.rds`).
2. Bundle: `Rscript scripts/bundle_plant_data.R` (trims → `data/sites/*.rds` + `data/site_index.rds` + the demo).

## Lineage

Chrome, the data-bundling spine, the diversity helpers, the report machinery, and the
`pincards.js` tap-to-pin system are ported from the Small Mammal Tracker per
[`docs/neonize-playbook.md`](docs/neonize-playbook.md). The plant-native analysis layer
(`R/plant_helpers.R`) is new. Built by Desert Data Labs · desertdatalabs@gmail.com

*Not affiliated with NEON, Battelle, or the NSF. An educational data-exploration tool.*

[smt]: ../App-NEON-Small-Mammal-Tracker
