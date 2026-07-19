# Build–Test Handoff

This is the release boundary for Plant Diversity. A local success, a green deployment log, and a healthy public app are three different receipts; release requires all three.

## Production release receipt — 2026-07-19

**Outcome: PASS for the exact legacy application release; CONTEXT / NO DRIVER BYTE CHANGE for Cascade.** The method, export, interface, deployment, and production-health gates closed. The plant source family remains `legacy-partial`, so this release does not invent an upstream build date, official NEON release, or query cutoff and does not authorize current-source or causal Driver promotion.

### Release lineage

- Science, data-contract, export, cover, provenance, refresh-safety, and CI rebuild: [PR #4](https://github.com/tgilbert14/NEON-Plant-Diversity/pull/4), head `7b2b2cdc971265ea0e0880063e131f8c1ff63c92`, merged as `dce2f3592619c71495f5a095b5f26164c736371b`; CI run `29677103854`.
- Live Plotly and Shiny lifecycle closure: [PR #6](https://github.com/tgilbert14/NEON-Plant-Diversity/pull/6), head `215cad7f1b0c646f5f57e8ea06a1498b83cfebab`, merged as `85447135ed42d6ce62c1e8122ed5bfdc04bd36e1`; CI run `29678025549`.
- Mobile loaded-site header, disconnect semantics, and deterministic ChromeDriver production health: [PR #7](https://github.com/tgilbert14/NEON-Plant-Diversity/pull/7), exact green head `9eed7d9e9c8f7699c6adbf893f90677d5b94fcce`, merged as `a374e0883ea67db1de2bd27b8797802fc54de0b4`; CI run `29692774450`.
- Full-width readiness at 320 px: [PR #8](https://github.com/tgilbert14/NEON-Plant-Diversity/pull/8), exact green head `2753916b09202e7ba76d2e0df69b6558b8f9b3c7`, merged as `8b5c1b1000678c11de7f5e8cc819c59ab54fbf33`; CI run `29694395248`.
- Framework-aware 44 x 44 px compact Help control: [PR #9](https://github.com/tgilbert14/NEON-Plant-Diversity/pull/9), exact green head `d51291bf570963c475595ab1cb9a9d41eba1bd59`, merged as final production commit `d6c48625f8268873bcd42d86285becaadbd57b4c`; CI run `29695040575`, job `88214223755`.
- Final master validation: [run `29695179837`](https://github.com/tgilbert14/NEON-Plant-Diversity/actions/runs/29695179837), job `88214587699`, green on exact merge `d6c48625f8268873bcd42d86285becaadbd57b4c`.
- Final Pages publication: [run `29695179559`](https://github.com/tgilbert14/NEON-Plant-Diversity/actions/runs/29695179559), deploy job `88214620774`, green on exact merge `d6c48625f8268873bcd42d86285becaadbd57b4c`.
- Semantic production health: [run `29695179854`](https://github.com/tgilbert14/NEON-Plant-Diversity/actions/runs/29695179854), exact post-republish attempt 2 job `88216101765`, green; exact runtime/cover receipts plus live Shiny/site readiness passed and outage issue `#5` remained closed.

### Exact release bytes

- Final PR-head artifact: `8444763625`; digest `sha256:d45ba722b254212cd0ff54551a584a11e7d1061a4102e399ab9d1d8c78c335a9`.
- Canonical master artifact: `8444800158`; digest `sha256:a23b2f6ce8df2172626d83d683473bc2da53861f0d2f36580bcfeab6869f386a`.
- Runtime receipt: `sha256:0765d8951843cf6fea09a295b260bfb53f1eb6708370748905a4a3941c85d2cb`; receipt-file SHA-256 `8c60432c053d45f033fe84d15d0a9a20db5c9f88040c35051af72cb816795768`.
- Cover receipt: `sha256:de6718b3b4e3557fdc395911cd98ce55be29db4d2a9b9038f1903814ed00413c`; receipt-file SHA-256 `c52ff4e6198aae3174af2174699caaea95c9f39cddd5d76c16063da34ed2061d`.
- `manifest.json` SHA-256: `12ffe3496ac54a6504a04656236604abc64f4638d1ae92bfe103565c0d15cd51`.
- Search-index SHA-256: `889764559d21f4de9b0f71f1f7e9140f63f73015352063cf3b4ff720acdefd1b`.
- Inventory: 46 plant bundles, 46 environment bundles, 34 site-reference artifacts, 150 manifest files, 91 R packages, R 4.5.2.
- Source identity: `legacy-partial`; exact-family guard `8f967bf7d0369879d0e9d3ac1ce19717d755ae681bc8eaa6d1341c3ade1f2a8a`; `repositoryImportedAt=2026-06-19`; `sourceBundleCommit=4ffcb24c3c1bf0dcab1f6c42fd3b9b5fe4de4e1e`; upstream build, official release, and cutoff remain `NA`.

### Deployment and public QA

- Connect content `019ee109-30ae-006e-cb3b-143afeac57e3`; public app <https://019ee109-30ae-006e-cb3b-143afeac57e3.share.connect.posit.cloud/>.
- Final publish request `00bdcf5f-babc-4a33-8307-144a221517f6`; Connect 2026.06.1 supplied all 91 packages under R 4.5.2 and began listening at `2026-07-19T09:40:19-07:00`.
- Connect Info identified exact deployed commit `d6c48625f8268873bcd42d86285becaadbd57b4c`.
- Public `?site=SRER` reached `data-app-ready=true`, `data-site-ready=true`, and `SRER ready`; the disconnect overlay was absent, the hero and Overview insight rendered, and there were zero Shiny output errors.
- Desktop plus 390, 375, 361, 360, and 320 px checks were overflow-free. `SRER ready` remained fully visible; the real Shiny Help control was 44 x 44 px at every compact width, retained the `How it works` accessible text in the DOM, and used a 16 px icon. The 360/320 layouts used the registered three-column grid. No disconnect overlay or Shiny output error was present.
- Ranked-species CSV, whole-site ZIP, completeness/QC ZIP, and the one-page Cairo PDF were downloaded and inspected on the scientific release. PRs #8 and #9 changed only mobile chrome, its regression checker, and exact release receipts/manifest; CI reconfirmed science, bundle, index, export, and offline-source contracts, and the search index remained byte-identical. Export frames, dictionary, README, provenance, source limitations, NRCS scope, and current-state/annual distinctions matched the registered contracts; the PDF rendered without clipping, overlap, or broken glyphs.
- The live cover and 1200×630 social card returned the exact cover receipt and passed canonical/social metadata checks. Their creative direction is now part of a separate suite-wide poster-system review, not an unrecorded release mutation.

### Failure closure, residual risk, and next action

- Closeout recorded `2026-07-19 09:57 MST` (`America/Phoenix`) for Plant Diversity Pass 3 release, governance, and Driver/suite handoff. Execution surfaces were GitHub Actions `ubuntu-22.04` with R 4.5.2 and the pinned Haswell/one-thread runtime, Posit Connect Cloud 2026.06.1 with R 4.5.2, and the signed-in public browser at desktop plus the five responsive widths.
- Local reproducible checks were `node --check www/app.js`, `node scripts/check_custom_message_handlers.mjs`, `node scripts/check_cover.mjs`, `node scripts/write_release_receipts.mjs --check`, `bash -n scripts/post_deploy_smoke.sh`, and `git diff --check`. The authoritative R parse, science fixtures, build portability, two-build search/manifest determinism, exact bundle/manifest equality, and offline source ran in the pinned CI jobs cited above.
- Production QA after PR #8 found a real framework seam that the earlier mock did not reproduce: Shiny's `actionButton()` keeps the Help label as a text node inside `.action-label`, so the sibling selector did not hide it and the control grew to roughly 94 px at 360/320. PR #9 preserved the DOM text, zeroed only its inherited visual font size, restored the icon size, and added a brace-walked static contract. No plant, environment, reference, search, cover, estimator, export, or Driver byte changed.
- PR #9's first validator run `29694888946` passed every science, portability, determinism, bundle, manifest-generation, and offline-source step, then failed only the intentional committed-byte equality gate. Artifact `8444715871` (digest `sha256:be763c5432e20950bbfa2e72f61ea53da27deb3cae93047f92708693d3cb9855`) proved the cover receipt and search index byte-identical and changed only the runtime receipt plus the manifest entries for that receipt and `www/styles.css`. Those exact validator files were promoted; the next exact-head run passed.
- Connect's public exact receipt was green, but its Info panel still showed the preceding merge during closeout. The authorized republish request above rebound Last deployed to `d6c48625f8268873bcd42d86285becaadbd57b4c`; public receipt and responsive checks were repeated afterward.
- Cleanup: the intentional failed exact-byte run left no repository mutation; its downloaded artifact was compared from the workspace staging directory and only the validator-produced runtime receipt and manifest were promoted. No failed deployment, open outage issue, partial data candidate, or unowned repository change remained.
- Residual scientific risk is explicit rather than a release failure: upstream source vintage/release/cutoff is unknown, sampled-empty 1 m² opportunities are not separately preserved, reference flora is spatially narrow, and short annual/environment screens remain descriptive context.
- Learning classes: `app-local` interface/export closure; `suite-platform` exact-byte, semantic-health, framework-markup, and breakpoint-seam prevention; `scientific-contract` nested-grain/opportunity/panel/nativity/reference limits; `Driver-impacting` disposition only. Driver decision is `CONTEXT / NO DRIVER BYTE CHANGE`.
- Next action: merge this documentation/governance closeout, update the Driver suite register and playbook without changing Driver artifacts, and hold the next companion's cover work until the owner approves the artistic poster direction.

## Candidate identity

Record before testing:

- commit SHA;
- R version and repository snapshot;
- plant source-receipt class and exact-family guard;
- for the legacy family: `builtAt=NA`, `neonRelease=NA`, `sourceCutoff=NA`, plus the separately labelled `repositoryImportedAt=2026-06-19` and `sourceBundleCommit=4ffcb24c3c1bf0dcab1f6c42fd3b9b5fe4de4e1e`;
- for a future refreshed family: actual bundle build date, query cutoff and immutable snapshot/query ID, official NEON release only if actually selected, raw/source digests, and builder commit;
- manifest SHA-256;
- counts for site, environment, expected-reference, search, and authority artifacts.

The legacy exact-family identity and canonical SHA-256 guard are registered in [Plant Source Receipt](PLANT-SOURCE-RECEIPT.md). Do not use the current date, repository commit/import date, filesystem mtimes, manifest hash, or runtime hash as an implicit source cutoff, release, or build date.

## Local and CI gates

1. Parse every tracked R file.
2. Source `global.R`, `ui.R`, and `server.R` with live fetch disabled.
3. Run `scripts/test_science_contracts.R` with hard assertions.
4. Run `scripts/verify_bundle.R`; require exactly 46 site and 46 environment bundles plus valid cross-index keys.
5. Run the strict export/codebook contract; no generic “see docs” fallback is allowed.
6. Run `scripts/check_custom_message_handlers.mjs`; every Shiny custom-message handler must accept exactly one payload argument.
7. Run `scripts/check_cover.mjs`; require canonical/social metadata, one H1, main/nav landmarks, local assets, and no fake health request.
8. Parse both app JavaScript files.
9. Build deterministic derived artifacts twice from the same staged inputs and compare bytes.
10. Generate the runtime and cover receipts, then regenerate `manifest.json`; require all four derived release files to be tracked and byte-equal to the candidate.
11. Verify the environment layer against [Environment Context Receipt](ENVIRONMENT-CONTEXT-RECEIPT.md): exact 46-site identity, month/date keys, finite/range rules, and unchanged bytes unless a separate reviewed environment rebuild is in scope.
12. Exercise an offline core boot. Remote basemap tiles are optional and may fail without breaking data/analysis.

The plant receipt gate fails closed. The exact legacy family must match its canonical content-addressed guard and must continue to expose unknown upstream fields as `NA`. Any family with embedded refreshed receipts must have a complete, identical receipt across all 46 bundles and `data/site_index.rds`; a partial, mixed, or mismatched receipt is a release failure.

## Data refresh gates

- Fetch into an isolated staging directory.
- Any failed/missing site exits non-zero.
- Never publish a subset while old bundles remain.
- Compare candidate and production inventories, row counts, schemas, vintage, and deletions.
- Build atomically into a candidate root.
- Preserve the actual build date separately from the query cutoff/snapshot ID; record a true official release only when it was explicitly selected.
- Preserve raw/source per-file and aggregate digests plus the builder commit.
- Require one complete matching receipt across all 46 new bundles and `data/site_index.rds` before the candidate can replace the legacy-partial receipt.
- Open a review PR; never push refreshed data directly to `master`.
- `skip_download` means revalidate the committed inputs and unchanged receipt. It must never mean “silently reuse unknown inputs” or stamp a new build date, cutoff, release, query ID, or source vintage.

## Human review

- Read the candidate cover and app at desktop plus 390/375/361/360/320 px. Require full status text, no root overflow, and 44 x 44 px compact controls on the real framework markup.
- Verify the national map sizes markers by plot support.
- Load at least SRER plus one Alaska/Puerto Rico or no-reference edge case.
- Traverse every navigation menu and keyboard-focus path.
- Confirm no raw richness is presented as a fair national ranking.
- Confirm Chao2, expected flora, cross-scale occurrence, and environment caveats are visible at the point of use.
- Download and inspect the whole-site ZIP, one plot CSV, one QC ZIP, and the PDF.
- Check the social card at 1200×630.

## Deployment receipt

Publish the exact reviewed commit. Then record:

- Connect content URL and deployment identifier;
- deployed commit and manifest hash;
- plant source-receipt class, source-bundle identity, and exact-family guard;
- public HTML 200 response;
- semantic `data-app-ready="true"` after Shiny connects;
- one site load with semantic site-ready status;
- absence of console errors;
- desktop and mobile screenshots;
- cover canonical/OG asset success;
- post-deploy smoke workflow result.

If Connect cannot restore an archived dependency, fix the package closure and retest a cold deployment. Never hand-edit package versions in the manifest to make provenance appear newer.

## Promotion and rollback

- Merge only after CI and review receipts are attached.
- For a release-byte promotion, Connect and Pages must point to the same promoted application commit. A later documentation-only closeout may merge without creating a new app release; record its repository/Pages commit separately while retaining the exact deployed application SHA and receipts.
- If public semantic health fails, stop promotion and restore the last known-good commit through a normal revert/redeploy workflow.
- Preserve the failed receipt and root cause for the suite learning loop.
- Keep current-source Driver promotion on hold while the plant family is `legacy-partial`, even if the application release and exact-byte deployment gates pass.
