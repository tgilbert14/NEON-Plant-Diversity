# Suite Learning Handoff

App: Plant Diversity · pass 3 · 2026-07-18

This file is the reusable learning package for the next companion app and the final Driver Cascade synthesis.

## Product lessons

1. Lead with the decision or question, not the data product name. Plant's promise is scale-aware composition and introduced-cover review.
2. A companion app must state its suite role. Plant is context; Driver is integrator.
3. “Can tell / Cannot tell” belongs on the cover and inside the app at the point of interpretation.
4. Ten equal top-level tabs are not navigation. Group destinations by user intent and preserve direct deep links/values.
5. Every interactive chart needs a non-pointer alternative. The plot table is the canonical pattern.
6. Generated hero art works best when it is openly illustrative, tied to the field method, and art-directed for separate desktop/mobile crops. Do not simulate documentary evidence.
7. A social image is a tested product surface, not a placeholder.

## Science lessons

1. Register the observation opportunity before calculating the metric. Occurrence rows cannot prove sampled zeros.
2. Choose one deterministic bout per plot-year before annual aggregation.
3. Standardize effort at the plot/panel/coverage level; Chao estimators are not generic effort corrections.
4. Keep grain in the metric name and UI.
5. Route contradictory classifications to Unknown/review; do not hide them with a mode.
6. A reference list inherits its spatial lookup scope. One centroid/soil unit cannot become site truth.
7. Short per-site annual records are context, not Driver edges—even after a search-corrected p-value.
8. Composition, phenology, and standing stock are different producer signals and should have different app owners.

## Data and release lessons

1. Refresh into isolated staging and require the full expected inventory before publishing.
2. A failure collector must exit non-zero.
3. Derived output must be byte-deterministic from explicit inputs and dates.
4. The manifest is an exact file/package closure, not a place to rewrite package metadata.
5. Custom Shiny message handlers require exactly one payload parameter under current Shiny.
6. Vendor essential browser dependencies; optional basemap tiles must not be confused with core data dependencies.
7. “App ready” requires a semantic Shiny connection/site-load receipt. A `no-cors` fetch proves nothing.
8. Data/codebook/provenance must be generated from the exact exported frames and fail on undocumented columns.
9. Scheduled refreshes create review candidates, never direct-to-production commits.

## Pattern to carry to every next app

- Public cover: outcome-led hero, role chip, verified facts with vintage, can/cannot, methods, release receipt, Driver-centred suite map, source/license/independence.
- In-app chrome: skip link, main/nav landmarks, persistent app/data status, 44px targets, visible focus, mobile intent-grouped navigation.
- Science package: `SCIENCE-CONTRACT.md`, hard fixtures, parity test, Driver disposition.
- Release package: bundle verifier, handler/cover static gates, exact manifest closure, offline core boot, deterministic build, semantic post-deploy smoke.
- Learning package: app-local handoff plus central Driver/Suite update after promotion.

## Driver changes to make after companion promotion

- Add Plant Diversity as **composition & invasion context**, not a productivity vote.
- Add source-app/contract/support/release links to every accepted Driver field.
- Add the four-state disposition (`promote`, `context`, `hold`, `reject`).
- Rebuild the Driver cover around the suite constellation with Driver clearly centred.
- Preserve unresolved findings as visible holds rather than laundering them into a polished edge.
