# Plant source receipt

Status: **RELEASE-2026 candidate of 2026-10-26; validated, carried in PR #26, not yet promoted**.

This receipt applies to the validated data candidate for NEON Plant Presence and Percent Cover (`DP1.10058.001`) built by refresh run `40364543238` at builder commit `486304df47c87068386d306b597a0655351b19fc` and promoted byte for byte onto the PR #26 branch (data commit `c5ec0becef5e64f73cdb893b15ec5e1c7ee41d62`). It supersedes the 2026-10-21 receipt. Public production is master `d2b9f56`, whose app bytes come from the PR #23 merge `d39b8d4` and carry the 2026-10-21 receipt. This candidate is not production until the reviewed head passes exact-head CI, merge, Connect, Pages, export, responsive (desktop and 390/375/361/360/320), and semantic-health gates.

## Candidate identity

Every one of the 46 `data/sites/<SITE>.rds` bundles and `data/site_index.rds` carries the same embedded receipt (read from the committed bytes):

| Field | Candidate value | Meaning |
|---|---|---|
| `receipt_version` | `plant-source-receipt-v2` | complete embedded query-snapshot schema |
| `product` | `DP1.10058.001` | Plant Presence and Percent Cover |
| `built_at` | `2026-10-26` | actual bundle build date |
| `source_start` | `2013-01` | first month requested |
| `source_cutoff` | `2026-09-30` | closed query boundary; not the newest observation date |
| `source_receipt_id` | `PDE-DP1.10058.001-query-through-2026-09-30-sha256-3e484580d6c3198cb9eff6c1e300a9da31fa18d82c91b31daae450408f19e6bc` | immutable app-defined query-snapshot identity |
| `query_package` | `basic` | NEON query package |
| `neon_utilities_version` | `4.0.2` | fetch package version |
| `source_digest` | `3e484580d6c3198cb9eff6c1e300a9da31fa18d82c91b31daae450408f19e6bc` | SHA-256 of the durable 46-line raw-file inventory |
| `builder_commit` | `486304df47c87068386d306b597a0655351b19fc` | exact code revision used to build the candidate |
| `neon_release` | `RELEASE-2026` | the official NEON release the fetch selected (DOI https://doi.org/10.48443/9g4s-hq52) |

`data/site_index.rds` and `data/search_index.rds` declare `snapshot_contract = plant-snapshot-v2`. The release is named once, in `R/plant_release.R`; the fetch requests it with `include.provisional = FALSE`, and the build rejects any consumed row whose `release` column differs. NEON's change log for the product is saved beside the raw files and committed as `data/source/neon-change-log.json` (19 entries).

The durable raw-source inventory is `data/source/plant-raw-SHA256SUMS.txt`: exactly 46 basename-scoped raw RDS SHA-256 entries, one per expected site. Its file SHA-256 equals `sourceDigest`.

Refresh run `40364543238` (`workflow_dispatch` from `fix/finish-audit-2026-10`, `skip_download=false`) fetched the complete family and built it twice with identical bytes. It passed the 46 environment byte and schema checks, the independent oracle, the runtime receipt, the manifest and the offline source gate, recorded the content key (content changed), and uploaded artifact `plant-diversity-refresh-486304df47c87068386d306b597a0655351b19fc`. Its publisher stopped at "Only master publishes", as a dispatch from a code branch must, and the artifact was promoted onto the branch unchanged.

The first dispatch, run `40348600215` at `8e06ab7`, fetched cleanly but never produced a candidate. Its runners twice hung in R setup and were cancelled. Its third attempt then stopped at the content-key guard, which rejected the colon in `occ:<SITE>`. A local replay of the remaining validator steps on that run's raw files found one more first-run defect: the inventory check refused `data/source` once the change log sat there. Commit `587378f` fixes both and adds a regression test. The next dispatch, run `40359047336`, rejected ABBY and BARR because the citation check looked for the lower-case DOI suffix, which NEON's BibTeX carries only in the entry key (the doi field reads `10.48443/9G4S-HQ52`); DOI names are case-insensitive, and `486304d` compares without case.

The query boundary and the observation records are different facts: retained records span 2013 to 2024. RELEASE-2026 holds nothing newer for this product; provisional 2025 bouts at NEON are excluded. NEON suspended this product's field sampling for 2026 (change log 110012), and field operations at DELA ended on 2025-12-31 (change log 110614); the app shows both as notices.

## Complete-family and semantic review

The row oracle `scripts/review_refresh_rows.R` (`PDE_EXPECTED_CHANGED_SITES` empty) passed: no site carries a new or changed observation. Every site whose rows differ from master differs only by exact-duplicate removal, the bundling step this PR adds (PD-18): 5,678 occurrence rows at 44 sites (from 2 at RMNP to 714 at CLBJ) and 921 ground rows at 35 sites. All 46 bundles keep one retained schema, and no exact duplicate remains. The family now holds 1,369,471 occurrence rows and 451,058 ground rows across 1,574 plots. Pinning RELEASE-2026 changed no row: it names the release the earlier unpinned query was already returning.

The candidate oracle `scripts/review_refresh_candidate.R` (base R, no app helpers sourced) passed: 46-site identity, one bundle schema, one matching receipt across every bundle and `data/site_index.rds`, and independent plant-snapshot-v2 parity with the index. Rebuilt under one rule from master's rows and from the candidate's, no headline moves at any site: snapshot species, plots, 400 m² richness, introduced and unknown cover, 1 m² incidence units and Chao2 are equal at 46 of 46. The duplicates removed did not move a headline. Network totals: 5,840 species-level names (0 added, 0 removed), 1,047 grain-event plots, 6,603 1 m² incidence units.

Six `site_index` rows move, each by 0.1 to 0.5 points of introduced relative cover; richness and plot counts do not move anywhere. The cause is the cover-denominator contract in this PR, not new data: a plot's 1 m² sampling units now include quadrats that held only ground cover (PD-14), and plot means are no longer rounded to 2 dp before the site sums. As species / plots / introduced relative cover:

| Site | Master index | Candidate index |
|---|---|---|
| GUAN | 174 / 23 / 3.1% | 174 / 23 / 3.2% |
| LAJA | 130 / 26 / 73.6% | 130 / 26 / 73.1% |
| MOAB | 81 / 30 / 14.0% | 81 / 30 / 14.1% |
| SOAP | 141 / 14 / 32.9% | 141 / 14 / 33.1% |
| WOOD | 99 / 8 / 14.3% | 99 / 8 / 14.4% |
| YELL | 192 / 15 / 0.7% | 192 / 15 / 0.8% |

SRER is unchanged at 203 / 33 / 9.6%: grain event 2023 bout 2 (species-area 5.5 / 12.3 / 26.7 / 42.6), cover event 2024 bout 1 over 198 sampled 1 m² quadrats (Chao2 191.9 from 157 species seen at 1 m²). Species-level mean cover moves more than the site shares, because every sampled quadrat now enters the denominator. At JORN the cover event counts 198 quadrats where 155 were counted before; the summed species mean cover falls from 5.68 to 4.15 and Prosopis glandulosa from 4.16 to 2.80. The search index (7,546 taxon-site rows) carries the same denominator. The completeness index is byte-identical to master. The source bundle still does not preserve an explicit sampled-empty 1 m² opportunity ledger, so the receipt does not remove that estimator limitation.

## Superseded receipts

The 2026-10-21 receipt (candidate `a9fc28fdaebd318744dadde341c0cca55a91a899`, production since the PR #23 merge `d39b8d4`) carried build date `2026-10-21`, cutoff `2026-09-30`, receipt ID `PDE-DP1.10058.001-query-through-2026-09-30-sha256-d7e9e0de7d8e624cb4e4f9d6d64b4a41ae58f09ead497ce1307983b797811cc7`, raw-inventory digest `d7e9e0de7d8e624cb4e4f9d6d64b4a41ae58f09ead497ce1307983b797811cc7`, builder commit `280539c8713c16b6b13d47d5916e0f50a10edd24`, `neonUtilities 4.0.2` and `neonRelease=NA` (no release was selected), from refresh run `39546911504`.

The 2026-08-03 candidate (`374fb704c548ca830f05c46d5fab1331e0027302`) carried build date `2026-08-03`, cutoff `2026-07-31`, raw-inventory digest `48167b04cc689fbcaaa3e83bdac7cc7ed1c8ac34f791e5e76d3f229862d61ac6`, builder commit `1734840a4f09e7acee356431ea1e57e9a637fb31` and `neonUtilities 4.0.1`, from scheduled run `30818211291`. Both stay here as rollback history; they no longer describe the candidate.

The legacy family before them was introduced by repository commit `4ffcb24c3c1bf0dcab1f6c42fd3b9b5fe4de4e1e` on 2026-06-19 under frozen-family guard `8f967bf7d0369879d0e9d3ac1ce19717d755ae681bc8eaa6d1341c3ade1f2a8a`; its upstream build date, release, cutoff, query ID and raw-source digest were unknown. Repository dates, mtimes, manifest hashes and runtime hashes still may not substitute for upstream source fields.

## Permitted interpretation

After exact promotion, this source family may support descriptive ecological values under the registered observation, opportunity, estimator and support rules. Naming the release makes the source citable; it does not make raw richness an equal-effort national rank, turn ocular cover into ground share, create sampled-empty opportunities, establish causality or authorize a Driver vote.

Driver disposition remains **CONTEXT / HOLD DRIVER INGESTION / NO DRIVER BYTE CHANGE**. An explicit opportunity ledger, a measured eligible Driver join, an independent adapter and old/new parity remain required before any ingestion decision.

## Contract for later refreshes

A later candidate is eligible only when one matching receipt is present across all 46 replacement bundles and `data/site_index.rds`. It must preserve:

1. the actual build date, separate from every source date;
2. query start/cutoff and an immutable query/snapshot identifier;
3. the pinned official NEON release from `R/plant_release.R`, with every consumed row carrying it; moving to a newer release is a reviewed change to that file (the weekly release watch opens one issue when NEON publishes one);
4. the durable per-file raw SHA-256 inventory and its content-bound aggregate `sourceDigest`;
5. builder commit, receipt schema/version, product, expected inventory, license, and failure record;
6. raw-row gates proving every consumed row belongs to the requested site and release and has a parseable `endDate` inside the registered interval;
7. NEON's change log for the product, with entries not in the committed copy reported;
8. atomic two-build, independent-oracle and exact-head validator evidence before publication; and
9. when the candidate was built after a snapshot, estimator or bundling contract change, an explicit statement that index movement is contract-driven, with the before and after index values for named sites and the row-multiset evidence that separates contract movement from data movement.

Partial, mixed, or disagreeing receipts fail closed. `skip_download=true` revalidates the committed inputs and existing receipt without changing any receipt field. It never stamps workflow time, repository time, file mtime, manifest hash, or runtime hash into source provenance. A candidate whose content equals the committed content (receipt or checksum churn only) publishes nothing.

A changed source family also triggers the human-claim gate. The review PR cannot pass until the canonical receipt, science/current-status documentation, Data Takeaways, Expert Review, Driver and suite handoffs, build handoff, empirical cover facts, social/OG artwork, image-provenance checksums, and cover receipt all carry reviewed changes. Exact artifact validation alone cannot authorize stale claims from the replaced family.
