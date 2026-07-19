# Suite Learning Handoff

App: Plant Diversity · pass 3 production closeout · 2026-07-19

This file is the reusable learning package for the next companion app and the final Driver Cascade synthesis.

## Product lessons

1. Lead with the decision or question, not the data product name. Plant's promise is scale-aware composition and introduced-cover review.
2. A companion app must state its suite role. Plant is context; Driver is integrator.
3. “Can tell / Cannot tell” belongs at the point of interpretation and below the cover fold; the poster face should stay brief enough to invite a non-scientist in.
4. Ten equal top-level tabs are not navigation. Group destinations by user intent and preserve direct deep links/values.
5. Every interactive chart needs a non-pointer alternative. The plot table is the canonical pattern.
6. Generated hero art works best when it is openly illustrative, tied to one product-native field object, and art-directed for separate desktop/mobile crops. Do not simulate documentary evidence.
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
3. Derived output must be byte-deterministic from explicit inputs and dates, with actual build date kept separate from query cutoff and source release.
4. The manifest is an exact file/package closure, not a place to rewrite package metadata.
5. Custom Shiny message handlers require exactly one payload parameter under current Shiny.
6. Vendor essential browser dependencies; optional basemap tiles must not be confused with core data dependencies.
7. “App ready” requires a semantic Shiny connection/site-load receipt. A `no-cors` fetch proves nothing.
8. Data/codebook/provenance must be generated from the exact exported frames and fail on undocumented columns.
9. Scheduled refreshes create review candidates, never direct-to-production commits.
10. Repository receipt and upstream vintage are different facts. Use fields such as `repositoryImportedAt` and `sourceBundleCommit`; keep unknown `builtAt`, `neonRelease`, and `sourceCutoff` values as `NA`.
11. Filesystem mtimes and manifest/runtime hashes prove neither source age nor upstream release. Content hashes identify exact bytes only.
12. A query-snapshot refresh requires one complete matching receipt across every expected bundle and its index, including query/snapshot identity, raw/source digest, and builder commit.
13. A skip-download run revalidates existing bytes and receipts without stamping a workflow date or invented source metadata.
14. A real Shiny `actionButton()` keeps its label as a text node inside `.action-label`; a sibling selector cannot hide that node. For compact icon-only presentation, retain the DOM text, zero the inherited visual font size, restore the icon's `em` basis, and prove a 44 x 44 px target at the actual 390/375/361/360/320 production widths.
15. Treat 360 px as a breakpoint seam, not a synonym for 320 px. The Plant release required a full-width status track plus fixed Help and theme columns at and below 360, while 361 remained the compact flex case.

## Pattern to carry to every next app

- Public cover: an artistic poster face with one dominant app-native object, a 3–7 word hook, one 6–12 word plain-language promise, and one CTA. Put role, verified facts, CAN/CANNOT, methods, provenance, release receipt, source/license/independence, and suite relationships below the fold; compose and validate the 1200 x 630 social image separately.
- In-app chrome: skip link, main/nav landmarks, persistent app/data status, 44px targets, visible focus, mobile intent-grouped navigation.
- Science package: `SCIENCE-CONTRACT.md`, hard fixtures, parity test, Driver disposition.
- Release package: bundle verifier, handler/cover static gates, exact manifest closure, offline core boot, deterministic build, semantic post-deploy smoke.
- Learning package: app-local handoff plus central Driver/Suite update after promotion.

## Driver changes to make after companion promotion

- Add Plant Diversity as **descriptive legacy composition & invasion context**, not a current-source or productivity vote; reconsider current-source promotion only after a complete reviewed refresh receipt.
- Add source-app/contract/support/release links to every accepted Driver field.
- Add the four-state disposition (`promote`, `context`, `hold`, `reject`).
- Rebuild the Driver cover as the master artistic poster, with companion field motifs converging into one cascade; keep the final composition pending the suite cover review.
- Preserve unresolved findings as visible holds rather than laundering them into a polished edge.
