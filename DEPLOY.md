# Plant Diversity release and deployment runbook

Plant Diversity has two public surfaces:

- cover: <https://tgilbert14.github.io/NEON-Plant-Diversity/> from `docs/`;
- app: <https://019ee109-30ae-006e-cb3b-143afeac57e3.share.connect.posit.cloud/> on Posit Connect Cloud.

The application is bundle-only in production. Its core analysis must boot without NEON, Google Fonts, a JavaScript CDN, or any other runtime data request. Leaflet basemap tiles are optional visual context; their failure must not break tables, exports, or analysis.

This runbook does not assume that a push automatically republishes Connect content. A release is complete only after the exact promoted commit is visible in Connect and the public browser receipt passes.

## Release boundary

Before promotion, record:

- candidate commit SHA;
- R `4.5.2` and the dated package repository in `.github/workflows/ci.yml`;
- plant source-receipt class and exact-family guard;
- either the registered legacy receipt (`builtAt=NA`, `neonRelease=NA`, `sourceCutoff=NA`, with separate `repositoryImportedAt` and `sourceBundleCommit`) or a complete matching refreshed receipt with actual build date, query cutoff/snapshot ID, true selected official release when applicable, raw/source digests, and builder commit;
- site, environment, reference, authority, and index inventory;
- `manifest.json` SHA-256;
- CI run URL.

The current legacy identity is registered in [Plant Source Receipt](docs/PLANT-SOURCE-RECEIPT.md). Its exact 46-site family entered the repository in commit `4ffcb24c3c1bf0dcab1f6c42fd3b9b5fe4de4e1e` on 2026-06-19, but neither the commit nor its date is an upstream fetch/build/release fact. The normative gates are in [Build–Test Handoff](docs/BUILD-TEST-HANDOFF.md). Do not substitute a successful local page load for the R, byte, source, deployment, or public-browser receipts.

## Candidate validation

Open a review branch and PR. CI must:

1. parse all R sources and source the full application with `PDE_LIVE=0`;
2. run `scripts/test_science_contracts.R` and the build-portability contract;
3. validate exactly 46 plant and 46 environment bundles plus all cross-index/reference artifacts;
4. build `data/search_index.rds` twice and require identical bytes;
5. generate the public runtime/cover receipts and `manifest.json`, then require deterministic bytes;
6. require all four derived files to be tracked and identical to the committed candidate;
7. run JavaScript, cover, handler-arity, shell, environment-context, and offline-boot gates.

Plant source validation must either match the canonical frozen-family SHA-256 for the legacy 46-site bytes while preserving unknown source fields as `NA`, or validate one complete identical refreshed receipt across every plant bundle and `data/site_index.rds`. Partial or mixed receipt modes are ineligible for promotion.

This repository cannot safely hand-edit derived release bytes. If the first CI run regenerates a different candidate, download `plant-diversity-release-candidate-<SHA>`, inspect it, and replace all four exact files: `data/search_index.rds`, `www/runtime-receipt.txt`, `docs/cover-receipt.txt`, and `manifest.json`. Commit them together and rerun CI. The PR is not eligible to merge until every equality and tracked-membership gate is green.

## Manifest contract

Generate with the same R/package closure as CI:

```sh
Rscript --vanilla scripts/build_search_index.R
node scripts/write_release_receipts.mjs
Rscript --vanilla scripts/write_manifest.R
Rscript --vanilla scripts/verify_bundle.R
git ls-files --error-unmatch data/search_index.rds www/runtime-receipt.txt docs/cover-receipt.txt manifest.json
test -z "$(git status --porcelain -- data/search_index.rds www/runtime-receipt.txt docs/cover-receipt.txt manifest.json)"
```

`manifest.json` must contain every runtime file and its current checksum, including vendored browser assets and the runtime receipt. That proves deployment closure, not plant-source vintage; manifest/runtime hashes and filesystem mtimes must never populate `builtAt`, `neonRelease`, or `sourceCutoff`. Ordinary repository packages use the dated Posit Package Manager snapshot. The pinned geospatial closure preserves exact absolute source URLs: seven packages, including `wk 0.9.5`, use immutable 2026-07-15 Posit source paths, while archived `terra 1.8-50` uses its complete CRAN Archive URL. Never use a relative `CRAN/...` path or rewrite package identity/provenance to make a restore appear newer.

## Promotion

1. Merge only the green reviewed PR.
2. Verify the merge commit on `master` and record it.
3. In Connect Cloud, confirm this content points at `tgilbert14/NEON-Plant-Diversity`, the intended branch/revision, and the committed manifest.
4. If Connect does not automatically build the promoted revision, trigger the in-scope republish from the logged-in content page.
5. Inspect the dependency/build log. A host HTTP 200 or successful package install is not yet an app-health receipt.
6. Require the public `runtime-receipt.txt` and `cover-receipt.txt` to match the exact promoted candidate, then verify the app in a real browser at desktop and 390 px mobile widths. Require:
   - Shiny connection (`data-app-ready="true"`);
   - a deep-linked SRER load (`?site=SRER`) with `data-site-ready="true"`;
   - zero console errors;
   - working grouped navigation, map/list fallback, plots, accessible Lab table, and downloads.
7. Verify the Pages cover, canonical URL, local hero crops, 1200×630 social card, suite links, and mobile layout.
8. Attach screenshots, manifest hash, commit, plant source-receipt identity, deployment identifier, and workflow URLs to the release receipt.

The cover intentionally does not pre-warm or probe the app. A no-CORS request cannot establish health and creates unwanted traffic; readiness is checked after launch and in the post-deploy browser smoke.

## Data refresh

`.github/workflows/refresh-data.yml` creates a review candidate, never a direct production update:

1. resolve an explicit closed query cutoff and immutable query/snapshot ID; record an official NEON release only if the fetch actually selected it;
2. fetch exactly 46 sites on R `4.1.1` into empty, read-only staging, rejecting raw rows whose `siteID`/canonical `plotID` or `endDate` falls outside the requested site and source interval;
3. preserve `data/source/plant-raw-SHA256SUMS.txt` plus its aggregate source digest, then build twice on R `4.5.2` in separate roots with the actual build date and builder commit recorded separately from the source cutoff;
4. compare exact derived bytes, require one complete matching receipt across all 46 bundles and `data/site_index.rds`, and rebuild completeness plus the runtime receipt;
5. preserve the separately versioned environment overlays byte-for-byte while validating their site identity/schema/ranges; do not relabel them with the plant cutoff;
6. validate the complete inventory, science contracts, app boot, cover, handlers, and manifest;
7. publish the candidate to a restricted refresh branch and open/update a PR.

Fresh source-family PRs are opened as drafts. The PR CI gate remains red until human-reviewed changes cover the source receipt, science/current-status docs, Data Takeaways and Expert Review, Driver/suite handoffs, build handoff, empirical cover facts, social/OG artwork, image-provenance checksums, and cover receipt; deleting a required surface also fails. Once the branch contains a human review path, a later scheduled run must preserve it and post a newer-candidate notice instead of force-pushing. Artifact validation alone is not permission to retain claims from the previous source family.

`skip_download=true` means revalidate the committed inputs and their unchanged receipt; it is not permission to reuse an unknown or partial cache, and it must not stamp a workflow date, invented release/cutoff, file mtime, or derived hash into source provenance. Any failed or missing site exits non-zero. Old and new bundles must never be mixed.

`NEON_TOKEN` is required only by the scheduled fetch job and belongs in GitHub Actions secrets. It is never included in the app, manifest, logs, or exports.

## Pages publication

GitHub Pages should publish `master` / `docs`. The cover contains no runtime CDN or health probe. After a branding or claim change, rerun:

```sh
node scripts/check_cover.mjs
node scripts/write_release_receipts.mjs --check
```

Visually inspect both hero crops and `docs/og-image.png`; static metadata checks cannot judge art direction or text legibility.

## Failure and rollback

If dependency restore, cold start, semantic readiness, site load, export parity, or cover publication fails:

1. stop promotion;
2. preserve the failed logs/artifacts and root cause;
3. restore the last known-good revision through a normal revert and Connect republish;
4. confirm public recovery with the same browser receipt;
5. add the failure and prevention rule to `docs/SUITE-LEARNING-HANDOFF.md` and the central Driver learning log.

Never overwrite a known-good release with a partially validated refresh.
