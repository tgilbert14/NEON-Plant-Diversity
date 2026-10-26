# Project status

Last updated 2026-10-26.

## Current state

- The app is live on Posit Connect Cloud, published from `master`:
  <https://019ee109-30ae-006e-cb3b-143afeac57e3.share.connect.posit.cloud/>.
  The cover is on GitHub Pages: <https://tgilbert14.github.io/NEON-Plant-Diversity/>.
- Data: NEON Plant presence and percent cover (DP1.10058.001), RELEASE-2026
  (DOI 10.48443/9g4s-hq52, CC BY 4.0), 46 terrestrial sites, records through
  2024. The pinned release is named once, in `R/plant_release.R`. NEON suspended
  this product's field sampling for 2026 (change log 110012), and field
  operations at DELA ended on 2025-12-31 (change log 110614); the app shows both
  as NEON notices.
- Snapshot contract `plant-snapshot-v2`: richness and species-area come from the
  latest full-grain site event (1, 10 and 100 m² in one year and bout); cover,
  Hill numbers, Chao2 and the watchlist come from the latest complete 1 m² bout.
  A plot's 1 m² sampling units include quadrats that held only ground cover.
- Refresh: `.github/workflows/refresh-data.yml` runs every Saturday and proceeds
  in the first week of the month. It fetches the pinned release, builds twice,
  validates, and pushes `automation/plant-diversity-data-refresh` only when the
  content changed; a change to receipts or checksums alone publishes nothing. One
  tracking issue says a candidate is waiting and closes when it lands. A person
  opens and merges the PR; that merge is the deploy. The same workflow opens one
  issue when NEON publishes a release newer than the pin, and warns on NEON
  change-log entries that are not in the committed copy.
- Post-deploy: `.github/workflows/post-deploy.yml` runs on every push to `master`
  and weekly. It requires the live runtime and cover receipts to equal the
  committed ones, the page title and `lang="en"`, and a semantic Shiny readiness
  pass on SRER.

## Open items (owner)

- Set the Connect content variable `CARTO_BASEMAP_KEY` and republish, then
  confirm the map loads tiles from `basemaps.cartocdn.com` (DEPLOY.md).
- Add a ruleset on `master`: pull request required, the `release_contracts`
  check required, no force-push or deletion (DEPLOY.md).
- Decide whether PUUM (Pu'u Maka'ala, Hawai'i) joins the bundle (see below).
- Decide whether the NEON Site Explorer joins the in-app suite registry.
- RELEASE-2027: when NEON publishes it, the release watch opens an issue. Moving
  to it is a reviewed change to `R/plant_release.R` plus a full refresh through
  the review branch.

## This round (2026-10)

- Closed the 2026-10-18 suite audit findings for this app (status file:
  `neon-audit-2026-10-18/reports/status/plant-diversity.md`, outside the repo).
- PR #20: the two-event snapshot contract (audit items 3 and 11). PR #23: the
  first refresh built under it. PR #22: the post-deploy smoke marker.
- PR #26 (this round's PR): release pin and DOI, NEON change-log notices, cover
  denominator over sampled quadrats, ground cover on the cover event, exact
  duplicate rows removed at build time, clickable QC flags with CSV, in-app data
  dictionary, page title and language, map-picker fixes, accessibility and copy
  fixes, an independent oracle in `scripts/verify_bundle.R`, and a refresh that
  publishes only when content changes. It carries the validated RELEASE-2026
  candidate from refresh run 40364543238. No observation changed: 5,678 exact
  duplicate occurrence rows and 921 ground rows were dropped, six site-index
  introduced-cover values moved by 0.1 to 0.5 points, and SRER stays at 203
  species, 33 plots and 9.6% introduced cover.

## Deliberately deferred

- PUUM. NEON publishes DP1.10058.001 at Pu'u Maka'ala (47 sites), but this app
  bundles 46. Adding PUUM needs its own USDA nativity authority entries, NRCS
  reference lookup and environment overlay before the 46-site checks can move to
  47. Owner decision.
- Provisional data. The app shows released data only; NEON's provisional 2025
  bouts arrive with RELEASE-2027.
- An explicit sampled-opportunity table. Quadrats with neither a plant record nor
  a ground-cover record stay unknown, not zero.
- Two cover values for one taxon in one quadrat visit. Exact duplicate rows are
  removed at build time; rows that share a key with different cover stay, are
  summed as before, and are listed by the duplicate-record QC flag.
- bslib `nav_menu()` inside `navset_card_tab()` produces ARIA tablist warnings
  (aria-required-parent, aria-required-children, aria-allowed-attr). The markup is
  bslib's; the grouped navigation stays until bslib fixes it or the IA changes.
- Connect Cloud sends no CSP, HSTS or frame-ancestors header. That is a platform
  setting; it can be set at a proxy if a custom domain ever fronts the app.
- Switching releases automatically. The workflow only reports a newer release.
- A keepalive job for the 60-day schedule rule. GitHub turns off a public repo's
  schedule after 60 days without activity; a merged commit re-arms it. Ground
  Beetle trials the keepalive job first.
- Chao2's sampling-unit count. It counts quadrats with a species-level record,
  not every sampled quadrat (18 sites differ; TEAK 86 of 120, JORN 155 of 198).
  The (m-1)/m factor moves by at most 0.33%, which is at most 0.16 species of
  Chao2. Aligning it is a registered estimator change for a later pass.
