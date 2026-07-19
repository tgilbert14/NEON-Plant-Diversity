# Build–Test Handoff

This is the release boundary for Plant Diversity. A local success, a green deployment log, and a healthy public app are three different receipts; release requires all three.

## Candidate identity

Record before testing:

- commit SHA;
- R version and repository snapshot;
- explicit NEON release/cutoff;
- bundle build date supplied by the release job;
- manifest SHA-256;
- counts for site, environment, expected-reference, search, and authority artifacts.

Do not use the current date as an implicit source cutoff.

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

## Data refresh gates

- Fetch into an isolated staging directory.
- Any failed/missing site exits non-zero.
- Never publish a subset while old bundles remain.
- Compare candidate and production inventories, row counts, schemas, vintage, and deletions.
- Build atomically into a candidate root.
- Open a review PR; never push refreshed data directly to `master`.
- `skip_download` must never mean “silently reuse unknown inputs.”

## Human review

- Read the candidate cover and app at desktop and 390px mobile widths.
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
- Connect and Pages must point to the same promoted commit.
- If public semantic health fails, stop promotion and restore the last known-good commit through a normal revert/redeploy workflow.
- Preserve the failed receipt and root cause for the suite learning loop.
