# Plant source receipt

Status: **receipt-complete query-snapshot candidate of 2026-10-21; reviewed locally, not yet promoted**.

This receipt applies to validated data candidate `a9fc28fdaebd318744dadde341c0cca55a91a899` for NEON Plant Presence and Percent Cover (`DP1.10058.001`). It supersedes the 2026-08-03 candidate receipt. Public production is master `280539c8713c16b6b13d47d5916e0f50a10edd24`, which serves the `plant-snapshot-v2` code over the 2026-08-03 receipt and a `site_index.rds` built before plant-snapshot-v2. This candidate is not production until the reviewed head passes exact-head CI, merge, Connect, Pages, export, responsive (desktop and 390/375/361/360/320), and semantic-health gates.

## Candidate identity

Every one of the 46 `data/sites/<SITE>.rds` bundles and `data/site_index.rds` carries the same embedded receipt (read from the committed bytes at `a9fc28f`):

| Field | Candidate value | Meaning |
|---|---|---|
| `receipt_version` | `plant-source-receipt-v2` | complete embedded query-snapshot schema |
| `product` | `DP1.10058.001` | Plant Presence and Percent Cover |
| `built_at` | `2026-10-21` | actual bundle build date |
| `source_start` | `2013-01` | first month requested |
| `source_cutoff` | `2026-09-30` | closed query boundary; not the newest observation date |
| `source_receipt_id` | `PDE-DP1.10058.001-query-through-2026-09-30-sha256-d7e9e0de7d8e624cb4e4f9d6d64b4a41ae58f09ead497ce1307983b797811cc7` | immutable app-defined query-snapshot identity |
| `query_package` | `basic` | NEON query package |
| `neon_utilities_version` | `4.0.2` | fetch package version (was `4.0.1`) |
| `source_digest` | `d7e9e0de7d8e624cb4e4f9d6d64b4a41ae58f09ead497ce1307983b797811cc7` | SHA-256 of the durable 46-line raw-file inventory |
| `builder_commit` | `280539c8713c16b6b13d47d5916e0f50a10edd24` | exact code revision used to build the candidate |
| `neon_release` | `NA` | no official NEON release was explicitly selected |

`data/site_index.rds` also declares the attribute `snapshot_contract = plant-snapshot-v2`, and so does `data/search_index.rds`, whose taxon table (7,546 taxon-site rows) gained a `plots_with_cover` column.

The durable raw-source inventory is `data/source/plant-raw-SHA256SUMS.txt`: exactly 46 basename-scoped raw RDS SHA-256 entries, one per expected site. Its file SHA-256 equals `sourceDigest`. All 46 per-file digests are new, because the upstream responses arrived in a different byte order; that is why the receipt ID changed while no observation changed (see below).

Refresh run `39546911504` (`workflow_dispatch`, `skip_download=false`) fetched the complete family, built it at builder commit `280539c8713c16b6b13d47d5916e0f50a10edd24` (master after PR #20, plant-snapshot-v2, and PR #22), passed two exact plant builds, the 46 environment byte/schema checks, the runtime receipt, the manifest, and the offline source gate, and pushed the review branch. The candidate commit is a direct child of master `280539c`. An earlier dispatch, run `39542458760`, built an identical candidate, but its publisher refused to push because master moved mid-run (the PR #22 merge). That refusal is the stale-base guard working as designed, not a data failure. The validated artifact identity for run `39546911504` is recorded by the lead in [Build-Test Handoff](BUILD-TEST-HANDOFF.md).

The query boundary extends through 2026-09-30, while the retained observation records span 2013 to 2024. Those are different facts. NEON has released nothing newer than 2024 for this product; provisional 2025 bouts exist at NEON and are excluded. The receipt does not invent 2025 or 2026 observations, and `neonRelease=NA` is not a missing-data error: the `basic` query did not select an official release.

## Complete-family and semantic review

No occurrence or ground row was added or removed at any of the 46 sites. The row oracle `scripts/review_refresh_rows.R` (now parameterized by `PDE_EXPECTED_CHANGED_SITES`, empty for this candidate) found the occurrence row multisets unchanged at 46 of 46 sites, the ground row multisets unchanged at 46 of 46, and one retained column schema across all 46 bundles. The family therefore still holds 1,375,149 occurrence rows and 451,979 ground-context rows across 1,574 plots, the same totals as the 2026-08-03 review. Six bundles (CPER, DEJU, OAES, OSBS, SCBI, STEI) differ from master only in row order, from tie-order churn in `percentCover`; the other 40 are byte-identical in their rows. All 46 bundle metas changed only in the receipt stamp fields above.

The candidate oracle `scripts/review_refresh_candidate.R` previously rebuilt the retired per-plot latest-year snapshot and so could not reconcile to a plant-snapshot-v2 `site_index`; it was rewritten to the plant-snapshot-v2 contract for this review. The rewritten candidate oracle (`scripts/review_refresh_candidate.R`, base R, no app helpers sourced) passed against this head: 46-site identity, one bundle schema, one matching receipt across every bundle and `data/site_index.rds`, and independent plant-snapshot-v2 parity (grain-event richness and plots, cover-event introduced cover) with the index. Network totals are unchanged from master under the same rule: 1,375,149 occurrence rows, 451,979 ground rows, 1,217,691 species-level rows, 1,574 plots, 1,047 grain-event plots, 6,603 1 m² incidence units, 5,840 species-level names (0 added, 0 removed); every per-site delta is zero. Its informational block lists the 43 sites where master's pre-v2 index differs from the v2 reconstruction.

The index values moved anyway, and the reason is the contract, not the data. 43 of the 46 `site_index` rows change in richness, plots, or introduced cover, because the index is now built under `plant-snapshot-v2` (the grain event for richness and plots, the 1 m² cover event for introduced cover). PR #20 said this refresh would deliver that correction. Before and after, as species / plots / introduced relative cover:

| Site | Master index (pre-v2) | Candidate index (v2) |
|---|---|---|
| SRER | 161 / 33 / 10.0% | 203 / 33 / 9.6% |
| CPER | 102 / 70 / 0.4% | 92 / 33 / 0.4% |
| JORN | 80 / 33 / 0.2% | 66 / 33 / 0.2% |
| STER | 20 / 11 / 99.8% | 30 / 10 / 99.9% |

SRER's grain event is 2023 bout 2 with 33 plots (species-area 5.5 / 12.3 / 26.7 / 42.6 at 1 / 10 / 100 / 400 m²); its cover event is 2024 bout 1 with 33 plots (Chao2 191.9 from 157 species seen at 1 m²). The source bundle still does not preserve an explicit sampled-empty 1 m² opportunity ledger, so the receipt does not remove that estimator limitation.

## Superseded 2026-08-03 receipt

The 2026-08-03 candidate (`374fb704c548ca830f05c46d5fab1331e0027302`, now on master) carried build date `2026-08-03`, cutoff `2026-07-31`, receipt ID `PDE-DP1.10058.001-query-through-2026-07-31-sha256-48167b04cc689fbcaaa3e83bdac7cc7ed1c8ac34f791e5e76d3f229862d61ac6`, raw-inventory digest `48167b04cc689fbcaaa3e83bdac7cc7ed1c8ac34f791e5e76d3f229862d61ac6`, builder commit `1734840a4f09e7acee356431ea1e57e9a637fb31`, and `neonUtilities 4.0.1`, from scheduled run `30818211291` and artifact `8858560431`. Those values stay here as rollback history; they no longer describe the candidate.

The legacy family before it was introduced by repository commit `4ffcb24c3c1bf0dcab1f6c42fd3b9b5fe4de4e1e` on 2026-06-19 under frozen-family guard `8f967bf7d0369879d0e9d3ac1ce19717d755ae681bc8eaa6d1341c3ade1f2a8a`; its upstream build date, release, cutoff, query ID, and raw-source digest were unknown. Repository dates, mtimes, manifest hashes, and runtime hashes still may not substitute for upstream source fields.

## Permitted interpretation

After exact promotion, this source family may support descriptive ecological values under the registered observation, opportunity, estimator, and support rules. A newer query cutoff with no new rows is not new evidence: it says the request ran later, not that the ecology changed. It does not make raw richness an equal-effort national rank, turn ocular cover into ground share, create sampled-empty opportunities, establish causality, or authorize a Driver vote.

Driver disposition remains **CONTEXT / HOLD DRIVER INGESTION / NO DRIVER BYTE CHANGE**. The receipt gate is satisfied, but an explicit opportunity ledger, measured eligible Driver join, independent adapter, and old/new parity remain required before any ingestion decision.

## Contract for later refreshes

A later candidate is eligible only when one matching receipt is present across all 46 replacement bundles and `data/site_index.rds`. It must preserve:

1. the actual build date, separate from every source date;
2. query start/cutoff and an immutable query/snapshot identifier;
3. a true official release only when the fetch explicitly selected it, otherwise `neonRelease` remains `NA`;
4. the durable per-file raw SHA-256 inventory and its content-bound aggregate `sourceDigest`;
5. builder commit, receipt schema/version, product, expected inventory, license, and failure record;
6. raw-row gates proving every consumed row belongs to the requested site and has a parseable `endDate` inside the registered interval;
7. atomic two-build and exact-head validator evidence before publication; and
8. when the candidate was built after a snapshot or estimator contract change, an explicit statement that index movement is contract-driven, with the before and after index values for named sites and the row-multiset evidence that separates contract movement from data movement.

Partial, mixed, or disagreeing receipts fail closed. `skip_download=true` revalidates the committed inputs and existing receipt without changing any receipt field. It never stamps workflow time, repository time, file mtime, manifest hash, or runtime hash into source provenance.

A changed source family also triggers the human-claim gate. The review PR cannot pass until the canonical receipt, science/current-status documentation, Data Takeaways, Expert Review, Driver and suite handoffs, build handoff, empirical cover facts, social/OG artwork, image-provenance checksums, and cover receipt all carry reviewed changes. Exact artifact validation alone cannot authorize stale claims from the replaced family.
