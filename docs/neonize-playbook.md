# NEON Explorer Suite product playbook

This is the current companion-app learning loop. It supersedes earlier advice to copy a flagship verbatim, load essential fonts/libraries from CDNs, demote records through undocumented range matches, pre-warm deployments, or publish refreshes directly to production.

“NEONize” means turning one NEON data product into an independent, useful explorer with product-native science, clear limits, strong interaction design, exact release receipts, and an explicit relationship to Driver Cascade.

## 1. Give every app one job

Before designing screens, register:

- source data product and license;
- observation unit and sampling opportunity;
- current-state, annual, and comparison estimands;
- one sentence describing what the app can decide or reveal;
- one sentence describing what it cannot support;
- suite role and Driver disposition: `promote`, `context`, `hold`, or `reject`.

Do not let a convenient available field become a metric before its denominator, grain, panel, missingness, and authority are known. Composition, timing, standing stock, abundance, chemistry, and productivity are distinct signals with distinct app owners.

## 2. Research before feature design

For each product, audit independently:

1. NEON tables, joins, units, release notes, duplication warnings, and sampling design;
2. defensible domain questions and known interpretation traps;
3. estimators, support gates, pseudoreplication risks, opportunity/zero semantics, and uncertainty;
4. current repository data, code, UI, manifest, deployment, and public behavior;
5. companion overlap and candidate Driver fields.

Use official product and authority sources. Record source/version/query/license receipts for every build-time enrichment. A fuzzy or undocumented match can create a review lead; it cannot silently change an observation.

## 3. Design the user journey

Every companion should provide:

- an artistic public-cover poster with one dominant product-native object, a 3–7 word hook, one 6–12 word plain-language promise, and one CTA;
- an explicit suite role, honest “can tell / cannot tell” contract, and Driver-centred relationships below the poster fold;
- a national or entity picker with a non-map fallback;
- an answer-first Overview;
- navigation grouped by user intent, not a row of equal-weight tabs;
- one product-native interactive funnel: position → inspect → profile/QC → export;
- accessible keyboard/table alternatives for pointer-driven charts;
- point-of-use support, grain, estimator, and limitation copy;
- a full export with strict dictionary and provenance;
- desktop and mobile interaction design, visible focus, 44 px targets, and reduced-motion behavior.

Generated cover art may be used when it is clearly illustrative, grounded in the field method, art-directed for separate desktop/mobile crops, and documented in image provenance. Never present synthetic art as field evidence. Metrics, methods, provenance, receipts, and secondary routes belong below the poster face. The 1200×630 social card is a separately composed release surface, not a cropped placeholder.

## 4. Build independent, offline-core apps

Companions remain independently deployable. Reuse proven patterns deliberately, but do not copy product-specific analyses or branding without review.

Core requirements:

- committed, read-only data bundles and a small default/demo path;
- defensive bundle reads with visible failure states;
- vendored essential browser libraries and system/local fonts;
- no server-start font download, CDN dependency, live data fetch, or fake readiness probe;
- optional basemap tiles explicitly separated from core data/analysis;
- one-argument Shiny custom-message handlers;
- semantic readiness markers promoted only after Shiny connects and the requested entity loads;
- deterministic derived artifacts from explicit query cutoffs/snapshot IDs, separately recorded actual build dates, builder commits, and versions.

Compact controls must be verified against framework-generated markup, not a hand-written approximation. Shiny `actionButton()` places its visible label in a text node inside `.action-label`, so a sibling selector cannot remove it. Preserve the DOM text for the accessible name, zero only its inherited visual font size, restore the icon size, and require a true 44 x 44 px target. Test both sides of every responsive seam; Plant's production matrix is 390/375/361/360/320 px, with the status/help/theme grid beginning at 360.

A missing production bundle is a release error. Do not mask it with a live API fallback that changes provenance, latency, schema, and reproducibility.

## 5. Register science as executable contracts

Each app ships a normative `SCIENCE-CONTRACT.md` and hard fixtures for:

- row-order and bout/event selection invariance;
- opportunity/structural-zero semantics;
- panel and effort handling;
- exact estimator edge cases;
- classification conflicts and geographic authority gates;
- app/PDF/export parity;
- strict codebook definitions, units, NA semantics, and estimands;
- Driver eligibility and exclusions.

Claims live beside the relevant number or chart so a screenshot keeps its caveat. “Not detected” is not “absent”; “review” is not “error”; correlation is not cause; raw richness is not an equal-effort ranking.

## 6. Treat refresh and release as trust boundaries

Fetch, build, validate, promote, deploy, and public health are separate receipts.

A refresh must:

1. use an explicit query cutoff and immutable query/snapshot ID, recording an official source release only when it was actually selected;
2. fetch into empty isolated staging;
3. fail on any missing expected entity;
4. build complete candidates atomically with one matching receipt across every expected bundle and index, including raw/source digests and builder commit;
5. compare two builds byte-for-byte;
6. regenerate and verify the exact manifest closure;
7. open a review PR—never commit directly to the watched production branch.

Repository receipt and upstream vintage are separate facts. If a legacy bundle family lacks its original build date, release, cutoff, query receipt, or raw-source digest, keep those fields unknown and identify only the exact repository bytes. Do not infer source vintage from commit dates, file mtimes, manifests, or runtime hashes. A revalidation/skip-download path preserves the existing receipt without stamping a new date or release.

A release must pass R parse/runtime, science fixtures, bundle/schema/index checks, offline boot, export inspection, cover checks, desktop/mobile browser QA, console health, semantic Shiny/entity readiness, and exact promoted-commit identity. An HTTP 200, shell marker, or no-CORS response is not application readiness.

## 7. Run the suite learning loop

After every promoted app:

1. write `SUITE-LEARNING-HANDOFF.md` with product, science, UX, data, and release lessons;
2. write `DRIVER-KNOWLEDGE-PACKAGE.md` with candidate fields, grains, support, uncertainty, exclusions, and disposition;
3. update the central Driver learning registry with the promoted commit and source hashes;
4. carry the prevention rules into the next app’s tests and cover/navigation patterns;
5. keep unresolved findings as visible holds rather than polished claims.

Driver Cascade is the suite ambassador and integrator. Companion apps own their product-specific evidence; Driver links back to the owning app, contract, support, release, and source bytes before accepting any field.

## Definition of done

An app is finished only when the reviewed code and data are merged, exact release bytes are promoted, Connect and Pages are healthy, desktop/mobile public QA passes, exports and receipts are inspected, suite learning is recorded centrally, and the last known-good rollback remains identifiable.
