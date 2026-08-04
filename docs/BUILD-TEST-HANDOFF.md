# Build–Test Handoff

This is the release boundary for Plant Diversity. A local success, a green deployment log, and a healthy public app are three different receipts; release requires all three.

## 2026-08-04 14:51:24 EDT - [Codex] current-production governance closeout

- Scope was documentation-only suite synthesis from clean branch
  `agent/suite-synthesis-plant-governance` at exact current default/docs commit
  `72924657ab93a05d28297616ed337bf55d4c8fbc`. The watched branch remains
  `master`; Pages remains
  <https://tgilbert14.github.io/NEON-Plant-Diversity/> and Connect remains
  <https://019ee109-30ae-006e-cb3b-143afeac57e3.share.connect.posit.cloud/>
  (content ID `019ee109-30ae-006e-cb3b-143afeac57e3`). No runtime, data,
  estimator, manifest, workflow, Pages, Connect, or Driver artifact was changed.
- The refreshed query-snapshot family is promoted production, not a pending
  candidate. Validated candidate
  `374fb704c548ca830f05c46d5fab1331e0027302` entered `master` through source-data
  merge `a060ee64909431f7c694d32be9729f03cb7b04e0`. PR #14 exact-head run
  `30826586359` authorized the compact-width runtime promotion merged as
  `8fc0824493a52a1a7ca2054852a5d84b264a9c8c`; current documentation/default
  authority is `72924657ab93a05d28297616ed337bf55d4c8fbc`. Current-default
  validation `30828066796`, Pages `30828064229`, and production health
  `30828072298` passed. Current `manifest.json` SHA-256 is
  `d7e24b0df9d25657a8999b855ed7ad92f37e3c5b45556464cc5fa10a8baaa938`;
  `data/site_index.rds` SHA-256 is
  `1addb5ae4e5adcc3bce64016ea0a7ecce0b987b184949187742f404cc46a424a`.
- The measured suite audit ran from the Driver worktree with
  `Rscript --vanilla scripts/audit_suite_compatibility.R
  /Users/vgs/Documents/Codex/2026-07-22/we-have-been-working-through-updating/work/repos
  plant_diversity`. The 46-site current family is visible, but annual eligible
  support and a Driver site-year join remain `UNMEASURED`: the source does not
  preserve an explicit sampled-empty opportunity ledger. The current Driver pin
  `73c92c6c67f7c982eaae76950f718ce932ff7a52` also differs at the consumed
  `data/sites` tree from promoted runtime `8fc0824`.
- Decision axes are now explicit: the current app scientific/release contract is
  `VERIFIED`; the ecological Driver disposition remains
  `CONTEXT / HOLD DRIVER INGESTION / NO DRIVER BYTE CHANGE`. A complete source
  receipt proves the app family, not an annual opportunity denominator, eligible
  join, independent adapter, or Driver vote.
- Static documentation checks passed: `git diff --check`; a changed-path audit
  limited this closeout to `docs/BUILD-TEST-HANDOFF.md` and
  `docs/DRIVER-KNOWLEDGE-PACKAGE.md`; and exact-identity/disposition assertions
  found the candidate, source-data/runtime/docs authorities, four workflow
  receipts, `UNMEASURED` support/join, pin mismatch, contract-trust axis, and
  no-byte authorization. Full R/app/browser and deployment gates are `N/A`
  because no release byte changed. The first audit invocation used unsupported
  product alias `plant`, exited before reading product data, and changed nothing;
  the documented `plant_diversity` invocation passed. No cleanup was required.

Next action: keep Plant Diversity non-voting context until an explicit sampled-
opportunity ledger, measured eligible join, independent adapter, and old/new parity
can authorize a Driver change.

## 2026-08-03 refreshed-family compact-width production closeout

- PR #13 merged the reviewed complete query-snapshot family as
  `a060ee64909431f7c694d32be9729f03cb7b04e0`. Exact PR-head CI
  `30824231684`, post-merge CI `30824565159`, Pages `30824563599`, and semantic
  production health `30824565205` passed. Public SRER loaded with 161 species,
  33 plots, 10.0% introduced relative cover, and Chao2 194.5. Its live 11-file
  whole-site ZIP passed integrity and value/receipt parity; the 44,575-byte
  one-page Cairo PDF rendered cleanly at 144 dpi with the same surfaced values
  and NRCS reference facts.
- That source release exposed one real compact-width defect: at forced 390×844,
  its new content-addressed query receipt retained a 473 px min-content width
  inside a 375 px document and produced a horizontal scrollbar. PR #14 gives
  `.hero-receipt` an explicit zero flex minimum, 100% maximum, border-box sizing,
  and anywhere/break-word wrapping, and makes those protections an executable
  mobile-cascade contract. This is an app-local presentation repair; plant,
  environment, reference, estimator, export, cover, and Driver data bytes are
  unchanged.
- The source repair `18568efeb2f4f9faf3d0d6586d18b382c2d5e2d1` passed every
  substantive pinned gate in exact-head run `30826012189` and failed only the
  intentional committed-release-byte equality boundary. Its validator artifact
  `8860955279` (digest
  `sha256:33f70f63e2650981721977ae0ed7bff1f81b4315bf33715b71adf69ca24ed209`)
  supplied the exact replacement runtime receipt and manifest; search and cover
  bytes were already identical. Promotion head
  `9a8c4a383f1c277685a8edf9a994296a1ee70aa4` then passed literal-head CI
  `30826586359` and merged through PR #14 as
  `8fc0824493a52a1a7ca2054852a5d84b264a9c8c`.
- The merged authority passed main CI `30827023726`; its exact release artifact
  is `8861393536`, 135,994 bytes, digest
  `sha256:f4d9c431b78b727c9dc21a91a4554eececb54c7fb3b3b2df0288a58f3c323f40`.
  Semantic production verification `30827025550` and Pages deployment
  `30827021757` passed on that same merge. Connect serves runtime receipt
  `sha256:22418f8bf10fd96795b007a81b1b9174020c9e0eac97aec8d52e80b80a7309ce`;
  Pages serves unchanged cover receipt
  `sha256:27ede8c791fa23cac59cf7023f7d7fe4c79910f63dec0831f09ccf1c802e5792`.
- Real production browser QA repeated SRER at 390, 375, 361, 360, and 320 CSS
  pixels. Every width reached `SRER ready`, showed no visible Shiny error or
  disconnect, and had document/body scroll width equal to client width. The
  full receipt wrapped with `overflow-wrap: anywhere`; at 320 px its 255 px
  scroll width exactly matched its 255 px client width. The regression is
  closed without hiding or truncating provenance, and the temporary browser
  viewport override was reset after testing.
- Local JavaScript parse, handler/readiness/mobile-cascade, cover, generated
  receipt, shell syntax, and `git diff --check` gates passed. The package-complete
  R/science/bundle/offline-source authority is the pinned exact-head and merged
  CI above; no unsupported local substitute is claimed. Classification remains
  `app-local` plus a reusable `suite-platform` intrinsic-width guard. Driver
  disposition remains `CONTEXT / NO DRIVER BYTE CHANGE`.

Next action: vendor this exact source/production receipt into the central suite
register, then continue the independently gated companion-app release queue.

## 2026-08-03 complete-query refresh human-review candidate

- Recorded `2026-08-03 10:27 EDT` (`America/New_York`) from validated data
  candidate `374fb704c548ca830f05c46d5fab1331e0027302`, a direct child of
  `1734840a4f09e7acee356431ea1e57e9a637fb31`. The isolated implementation
  branch is `codex/plant-diversity-refresh-review-374fb704`; draft PR #13 must
  remain draft until the literal reviewed head passes CI and the deployment
  gates below. Public production remains the exact 2026-07-19 release recorded
  later in this file.
- Scheduled run `30818211291` produced validated artifact `8858560431`
  (artifact digest beginning `6929f301`). Every one of the 46 plant bundles
  and `data/site_index.rds` carries the same `plant-source-receipt-v2`: built
  `2026-08-03`, requested from `2013-01` through closed query cutoff
  `2026-07-31`, `basic` package, neonUtilities `4.0.1`, no selected official
  release (`neonRelease=NA`), builder commit
  `1734840a4f09e7acee356431ea1e57e9a637fb31`, and source digest
  `48167b04cc689fbcaaa3e83bdac7cc7ed1c8ac34f791e5e76d3f229862d61ac6`.
  The digest is the SHA-256 of the durable 46-line raw-file inventory. Query
  cutoff is not observation vintage: retained observations end in 2024.
- Two independent base-R review oracles, which do not source app helpers,
  reconciled all 46 receipt/index rows and candidate metrics. The candidate has
  1,375,149 occurrence rows, 451,979 ground rows, 1,217,691 species-level rows,
  157,458 coarse-identification rows, 1,574 plots, 9,326 current 1 m² incidence
  units, and 5,840 distinct species-level names across history. Compared with
  production, 63 names were added and none removed. Forty-three occurrence and
  ground row multisets are semantically unchanged after ignoring deterministic
  ordering/serialization; only JORN, KONZ, and SRER gain source rows.
- The three changed sites retain 33 current plots each. JORN moves from 35 to
  80 selected-snapshot species, 0.0% to 0.2% introduced relative cover, and
  Chao2 60.8 to 61.9; KONZ moves from 231 to 200 species, remains 0.2%, and
  moves Chao2 204.9 to 209.9; SRER moves from 203 to 161 species, 22.2% to
  10.0%, and Chao2 143.7 to 194.5. JORN and SRER now select 2024 for all 33
  plots. KONZ now selects 2024 for 11 plots while retaining the supported
  2020/2022/2023 panel for the rest. These are deterministic latest-snapshot
  changes, not row deletions, equal-effort national rankings, trends, health
  scores, or causal effects.
- The 46 environment bundles are byte-identical to production. The 34 reference
  artifacts are byte-identical; only their derived completeness index changes
  with the plant snapshot. Reference completeness stays 24% at JORN, moves 64%
  to 60% at KONZ, and 52% to 38% at SRER. The source still lacks an explicit
  sampled-empty 1 m² opportunity ledger, so provenance completeness does not
  close the Chao2/cover opportunity limitation.
- Validated runtime identities, unchanged by the human-only cover/review
  changes, are:
  manifest `c6350647ca245e9f8f6d656bfe21b685fae1cb8239471be497fd90427309e7ac`,
  search index `9d34390efdf8555f1b915828eedaeba0f6796d1585a259b01d0e71b403455d80`,
  site index `1addb5ae4e5adcc3bce64016ea0a7ecce0b987b184949187742f404cc46a424a`,
  completeness index
  `7da754ba77cd56185862f760b11e72f7e9197b1bb92efaccad6ca8edd6bee1f7`,
  runtime-receipt content
  `sha256:94e89e5c59166476c386f3e337e7cd4f08d59bef6953c4a3d09b07134ed8378e`,
  and runtime-receipt file
  `2484023fffdc4174f2038d7545b8e0a6926a725f8e9afbfbd1f4173c80d3543a`.
  The reviewed social SVG is
  `4d85e7e239a342d46aa841c04c55913522d4bf2f4667c4109fec7b82cad94233`;
  its visually inspected 1200×630 PNG is
  `4eb34b5e05e32d0a8d87534de612ab3b500ace097ceb07a71cbbcc79e7f12964`.
  Generated cover-receipt content is
  `sha256:27ede8c791fa23cac59cf7023f7d7fe4c79910f63dec0831f09ccf1c802e5792`
  (receipt-file SHA-256
  `aad0798de34ab1174aac633a97a998c5f128ddafeb1135302b27a7ec7f57101b`).
- The failing review workflow was validating GitHub's synthetic pull-request
  merge SHA while the human-review surface comparison and artifact labels
  purported to describe the PR head. CI now derives one immutable `SOURCE_SHA`
  from `github.event.pull_request.head.sha` (falling back to `github.sha` for
  non-PR events), checks out that exact revision, proves literal-head equality,
  and uses it for source-family diffs and artifact names. This is a workflow
  identity repair; it does not alter plant, environment, estimator, app, or
  Driver bytes.
- Local R 4.5.3 review passed both independent oracles,
  `scripts/test_build_script_portability.R`, `scripts/test_raw_portability.R`,
  and parse of all 28 app/R/script files. The raw inventory has exactly one
  unique digest for each canonical site and its own SHA-256 equals the embedded
  `sourceDigest`. JavaScript syntax, six-handler/semantic-readiness contracts,
  cover contract, generated-receipt check, shell syntax, Python compile, YAML
  parse, all 10 workflow run-block `bash -n` checks, all 15 changed human-review
  surfaces, `git diff --check`, native-size social-card inspection, and exact
  equality of manifest/search/runtime bytes to data candidate `374fb704` also
  passed. `actionlint` is unavailable locally. The first Ruby run-block helper
  used `filter_map`, which is unavailable in local Ruby 2.6.10, and the first
  zsh surface helper accidentally shadowed zsh's special `path` array; both
  diagnostics failed before evaluating repository content and their corrected
  versions passed.
- The full science test and bundle verifier stop at missing local `dplyr`; the
  offline app source stops at missing local `shiny`. This machine has only
  `htmltools`, `digest`, and `jsonlite` from the runtime closure, so no green
  result is claimed for those package-dependent gates and no ad hoc package
  installation was used. They must run in the pinned R 4.5.2 CI closure.
  Likewise, headless Chrome on this host enforces a 485 CSS-pixel minimum even
  when cropping a 390/320 screenshot, so those captures are not responsive
  evidence. Remaining authority gates are literal-head CI, app/export/PDF
  parity, real desktop plus 390/375/361/360/320 responsive/accessibility review,
  merge, exact Connect/Pages identity, and post-deploy semantic health.
- Failure/cleanup: the original publish-or-update-review-branch stage did not
  establish a publishable reviewed head. No subset, failed deployment, or
  partial family is being promoted by this local review; no GitHub mutation is
  authorized from this worktree. Local `gh auth status` reports the saved
  `tgilbert14` CLI token invalid, which does not affect the local audit but also
  prevents a remote recheck from this worktree. Learning classes are
  `app-local` for surfaced
  snapshot facts, `suite-platform` for literal-head CI identity, and
  `scientific-contract` for receipt/opportunity boundaries. Driver disposition
  remains `CONTEXT / NO DRIVER BYTE CHANGE`.

## 2026-08-03 scheduled-refresh raw-RDS portability repair candidate

- Recorded `2026-08-03 08:46 EDT` (`America/New_York`) from source branch
  `origin/master` at exact commit
  `dfb44231e67fff49f229a835eb9fcdc2bfcefe0d`; implementation branch is
  `agent/plant-diversity-refresh-portability`. Production remains the verified
  legacy runtime and Living Poster authorities recorded below. No generated
  plant/environment bundle, search index, receipt, cover, `manifest.json`,
  Connect deployment, Pages publication, or Driver byte changed in this source
  candidate.
- Scheduled run
  [30736596906](https://github.com/tgilbert14/NEON-Plant-Diversity/actions/runs/30736596906)
  fetched all 46 sites successfully, including 20,738 ABBY `div_1m2Data` rows,
  but the first clean build process stopped at ABBY with
  `div_1m2Data consumed-row mask is invalid`; the publisher was skipped. The
  sole raw artifact expired after one day and now returns HTTP 410, so the exact
  malformed column cannot be re-read. The strongest supported cause is the
  repository's already-documented Arrow ALTREP seam: the R 4.1.1 /
  neonUtilities 4.0.1 fetch process saved Arrow-backed strings directly, while
  the independent R 4.5.2 builder did not load Arrow. This diagnosis is
  high-confidence inference, not a byte-level observation from the expired
  artifact; there is no evidence that a new ecological row code caused the
  failure.
- The repair materializes every fetched data-frame column into a plain base-R
  vector while Arrow is still available, preserving base character, logical,
  integer, numeric, complex, raw, `Date`, `POSIXct`, factor, and ordered-factor
  values/classes. It rejects length/row disagreement, dimensions, unsupported
  storage or attributes, and residual Arrow/ALTREP-like classes before saving.
  Each saved site RDS is then opened by a fresh `Rscript --vanilla` child that
  loads neither Arrow nor neonUtilities, validates all data-frame columns,
  independently recreates both registered consumed-row masks, and re-runs the
  site/date source boundary before the file can be renamed into raw staging.
  The builder repeats the portable-frame gate and now reports expected/actual
  mask shape plus the three contributing field signatures. The mask itself is
  unchanged: only named `plantSpecies` and `otherVariables` records are consumed;
  no missing survey opportunity is converted to zero.
- Focused fixtures preserve exact values, `NA`s, storage types, `Date`/
  `POSIXct` timezone, factor levels/order, and the intended plant/other-variable
  mask. A producer-to-fresh-child regression passes a portable raw RDS, while a
  deliberately malformed three-row frame with a zero-length `scientificName`
  fails with the field and expected row count. Static assertions bind the fetch
  order (`materialize -> save -> child verify -> rename`) and the restricted
  publisher contract. Local R was 4.5.3 with `arrow`, `neonUtilities`, and
  `tibble` absent. Exact local results:
  `Rscript --vanilla scripts/test_raw_portability.R` — PASS;
  `Rscript --vanilla scripts/test_build_script_portability.R` — PASS; parse of
  all 26 app/R/script files — PASS; read-only materialization of the `occ` and
  `ground` frames in all 46 committed bundles preserved exact values, classes,
  and attributes — PASS; corrected Ruby safe-load of both changed
  workflow YAML files — PASS; extraction of the restricted publisher run block
  with PyYAML followed by `bash -n` — PASS; and `git diff --check` — PASS. The
  first Ruby diagnostic used the unavailable `YAML.safe_load_file` method and
  failed before reading either workflow; rerunning with
  `YAML.safe_load(File.read(...))` passed.
  The existing full science/bundle/manifest suite is not claimed locally because
  its pinned package closure is not installed.
- Raw evidence retention is raised from one to seven days. The restricted
  publisher still writes only
  `automation/plant-diversity-data-refresh`, never `master`; it now requires
  exact current-master input, a direct-child promotion commit, a remote branch
  resolving to that exact commit, and an unambiguous `master <- review branch`
  PR identity. It no longer calls `gh pr create` or changes PR readiness with the
  Actions token. When no PR exists it succeeds with a notice instructing a
  repository write user to open the intentionally draft PR; an existing PR is
  commented only after its exact head is observed. Human science/provenance
  changes on an active review branch remain protected from automation overwrite.
- Residual gate: the local fixture uses an Arrow-class analogue because Arrow is
  unavailable locally. The pinned R 4.1.1 fetch job must exercise the real
  neonUtilities/Arrow vectors, retain the raw family for seven days, and pass a
  full new 46-site fetch, two exact builds, manifest/verifier suite, and
  exact-head review workflow. Rerunning only the old failed jobs cannot succeed:
  their raw artifact is gone. A new full fetch will legitimately produce a new
  serialized raw digest even when ecological values are unchanged. Local
  `gh auth status` also reports that the saved `tgilbert14` token is invalid; no
  push, PR, dispatch, or other GitHub mutation had been attempted at audit time;
  publication still requires the exact receipts below.
  Learning is `app-local + suite-platform`, disposition `NONE`; the registered
  Plant Driver disposition remains `CONTEXT / NO DRIVER BYTE CHANGE`.

## 2026-07-22 Suite Living Poster V1 source candidate

- Working branch: `agent/plant-diversity-living-poster-v1`; production remains
  the verified release recorded below until the pinned validator, review, merge,
  and Connect/Pages promotion path completes.
- Pages and the in-app first-run surface now share the approved poster contract:
  **“How much can one square hold?”** / **“Explore plant communities from one
  square metre outward.”** / **“Pick a place.”** The face has one Driver route,
  one contextual CTA, dominant responsive editorial art, an explicit
  illustration/data boundary, and compact source and claim-boundary notes. The
  prior fact cards, method blocks, release receipt, and full suite directory were
  removed from the companion face.
- The documented nested-quadrat desktop/mobile art was reused without a new
  generative operation and mirrored byte-for-byte into `www/assets/`. The
  1200×630 social card was recomposed from its checked-in SVG around the same
  hook and promise; `docs/IMAGE-PROVENANCE.md` carries the new exact hashes.
- Local source verification passed `node --check scripts/check_cover.mjs`,
  `node scripts/check_cover.mjs`, `node --check www/app.js`, the six-handler
  contract, `git diff --check`, a clean 1280×720 browser render with one
  H1/Driver route and no root overflow or page-console errors, and an exact
  1200×630 social-card inspection. This shell has no R runtime, so the R parse,
  manifest/receipt, deterministic artifact, 390/320 browser, Connect, and Pages
  gates remain for the pinned validator. No scientific estimator, source family,
  bundle, or Driver byte changed.

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
- Keep Driver ingestion and inferential promotion on hold until explicit sampled
  opportunity, a measured eligible join, an independent adapter, and old/new
  parity pass. A complete source receipt alone is not authorization.
