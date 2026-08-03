# Plant source receipt

Status: **receipt-complete query-snapshot candidate; reviewed locally, not yet promoted**.

This receipt applies to validated data candidate `374fb704c548ca830f05c46d5fab1331e0027302` for NEON Plant Presence and Percent Cover (`DP1.10058.001`). Public production remains on the prior legacy family until the reviewed head passes exact-head CI, merge, Connect, Pages, export, responsive, and semantic-health gates.

## Candidate identity

Every one of the 46 `data/sites/<SITE>.rds` bundles and `data/site_index.rds` carries the same embedded receipt:

| Field | Candidate value | Meaning |
|---|---|---|
| `receipt_version` | `plant-source-receipt-v2` | complete embedded query-snapshot schema |
| `product` | `DP1.10058.001` | Plant Presence and Percent Cover |
| `built_at` | `2026-08-03` | actual bundle build date |
| `source_start` | `2013-01` | first month requested |
| `source_cutoff` | `2026-07-31` | closed query boundary; not the newest observation date |
| `source_receipt_id` | `PDE-DP1.10058.001-query-through-2026-07-31-sha256-48167b04cc689fbcaaa3e83bdac7cc7ed1c8ac34f791e5e76d3f229862d61ac6` | immutable app-defined query-snapshot identity |
| `query_package` | `basic` | NEON query package |
| `neon_utilities_version` | `4.0.1` | fetch package version |
| `source_digest` | `48167b04cc689fbcaaa3e83bdac7cc7ed1c8ac34f791e5e76d3f229862d61ac6` | SHA-256 of the durable 46-line raw-file inventory |
| `builder_commit` | `1734840a4f09e7acee356431ea1e57e9a637fb31` | exact code revision used to build the candidate |
| `neon_release` | `NA` | no official NEON release was explicitly selected |

The durable raw-source inventory is `data/source/plant-raw-SHA256SUMS.txt`: exactly 46 basename-scoped raw RDS SHA-256 entries, one per expected site. Its file SHA-256 equals `sourceDigest`. Scheduled run `30818211291` fetched the complete family; validated artifact `8858560431` has an artifact digest beginning `6929f301`. The candidate commit is a direct child of master `1734840a4f09e7acee356431ea1e57e9a637fb31`.

The query boundary extends through 2026-07-31, while the retained observation records span 2013–2024. Those are different facts. The receipt does not invent 2025 or 2026 observations, and `neonRelease=NA` is not a missing-data error: the `basic` query did not select an official release.

## Complete-family and semantic review

The candidate contains exactly 46 plant bundles with one uniform retained schema, 1,375,149 occurrence rows, and 451,979 ground-context rows. An independent base-R oracle reconciled candidate snapshot richness, current plot support, and introduced-cover percentages to all 46 `site_index.rds` rows. It also proved that 43 site occurrence/ground row multisets are semantically unchanged after ignoring deterministic row order and serialization; only JORN, KONZ, and SRER gained source rows. Across all historical records, 63 species-level scientific names were added and none were removed.

Current-state estimates changed at those sites because `latest_snapshot()` correctly moved some plots to newer surveys. That is a snapshot change, not a deletion claim. JORN moves from 35 to 80 selected-snapshot species, KONZ from 231 to 200, and SRER from 203 to 161; all three retain the same plot counts as before. The source bundle does not preserve an explicit sampled-empty 1 m² opportunity ledger, so the added receipt does not remove that estimator limitation.

## Superseded legacy receipt

The prior 46-site family was introduced by repository commit `4ffcb24c3c1bf0dcab1f6c42fd3b9b5fe4de4e1e` on 2026-06-19. Its canonical frozen-family guard was `8f967bf7d0369879d0e9d3ac1ce19717d755ae681bc8eaa6d1341c3ade1f2a8a`; its upstream build date, release, cutoff, query ID, and raw-source digest were unknown. That receipt remains historical rollback evidence, not the candidate's provenance. Repository dates, mtimes, manifest hashes, and runtime hashes still may not substitute for upstream source fields.

## Permitted interpretation

After exact promotion, this source family may support descriptive ecological values under the registered observation, opportunity, estimator, and support rules. The complete query receipt closes the prior source-provenance gap. It does not make raw richness an equal-effort national rank, turn ocular cover into ground share, create sampled-empty opportunities, establish causality, or authorize a Driver vote.

Driver disposition remains **CONTEXT / NO DRIVER BYTE CHANGE**. The receipt gate is now satisfied for this candidate, but an explicit opportunity ledger, measured eligible Driver join, independent adapter, and old/new parity remain required before any ingestion decision.

## Contract for later refreshes

A later candidate is eligible only when one matching receipt is present across all 46 replacement bundles and `data/site_index.rds`. It must preserve:

1. the actual build date, separate from every source date;
2. query start/cutoff and an immutable query/snapshot identifier;
3. a true official release only when the fetch explicitly selected it—otherwise `neonRelease` remains `NA`;
4. the durable per-file raw SHA-256 inventory and its content-bound aggregate `sourceDigest`;
5. builder commit, receipt schema/version, product, expected inventory, license, and failure record;
6. raw-row gates proving every consumed row belongs to the requested site and has a parseable `endDate` inside the registered interval; and
7. atomic two-build and exact-head validator evidence before publication.

Partial, mixed, or disagreeing receipts fail closed. `skip_download=true` revalidates the committed inputs and existing receipt without changing any receipt field. It never stamps workflow time, repository time, file mtime, manifest hash, or runtime hash into source provenance.

A changed source family also triggers the human-claim gate. The review PR cannot pass until the canonical receipt, science/current-status documentation, Data Takeaways, Expert Review, Driver and suite handoffs, build handoff, empirical cover facts, social/OG artwork, image-provenance checksums, and cover receipt all carry reviewed changes. Exact artifact validation alone cannot authorize stale claims from the replaced family.
