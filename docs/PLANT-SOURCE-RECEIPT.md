# Plant source receipt

Status: **legacy-partial source receipt; current-source promotion hold**.

This receipt applies to the exact 46-site `DP1.10058.001` plant-bundle family first introduced to this repository by commit `4ffcb24c3c1bf0dcab1f6c42fd3b9b5fe4de4e1e` on 2026-06-19. That date is the repository receipt date. It is not the upstream fetch date, bundle build date, query cutoff, snapshot date, or NEON release.

## What is known

- Product: NEON Plant presence and percent cover (`DP1.10058.001`).
- Inventory: exactly 46 `data/sites/<SITE>.rds` bundles and the corresponding 46-row `data/site_index.rds` introduced together in the source-bundle commit.
- `sourceBundleCommit`: `4ffcb24c3c1bf0dcab1f6c42fd3b9b5fe4de4e1e`.
- `repositoryImportedAt`: `2026-06-19`.
- Legacy `sourceDigest` / canonical frozen-family SHA-256 guard for the 46 per-site bundles: `8f967bf7d0369879d0e9d3ac1ce19717d755ae681bc8eaa6d1341c3ade1f2a8a`, computed with files ordered by basename over inventory lines in the form `<sha256> <basename>\n`. In this legacy receipt, `sourceDigest` means the exact bundled family, not a preserved raw upstream response.
- Superseded audit cross-checks over the basename-ordered historical `<basename> <MD5>\n` inventory: MD5 `ae043340a5efd16539a2a56c11d3f257` and SHA-256 `da900f839ca7ea1b5fd4c78c87d08f7345fd0bc0c673f52ba22e88a8844020b9`. They reconcile the earlier inventory but are not the current guard.

The hashes prove which 46 per-site repository bytes are being described. They do not cover `data/site_index.rds`, which is checked separately for exact site identity and cross-index consistency, and they do not reveal when NEON produced or served the source bytes.

## What was not preserved

The original fetch did not preserve a complete upstream receipt. Therefore the legacy family must report:

| Field | Legacy value | Meaning |
|---|---:|---|
| `builtAt` | `NA` | The actual bundle build date is unknown. |
| `neonRelease` | `NA` | No official NEON release was recorded as explicitly selected. |
| `sourceCutoff` | `NA` | The fetch/query cutoff is unknown. |
| query or snapshot identifier | `NA` | The upstream query receipt was not preserved. |
| original raw/staged source digest | `NA` | No digest of the original staged upstream response was preserved. |

`repositoryImportedAt` and `sourceBundleCommit` are separate receipt fields precisely so a repository fact cannot be mistaken for an upstream-vintage fact. Filesystem modification times are checkout/deployment properties, not source evidence. The deployment manifest, runtime receipt, and their hashes verify repository and deployment closure; they are not upstream dates, releases, cutoffs, query receipts, or raw-source digests.

## Permitted interpretation

Exact-byte verification preserves the usefulness of the bundled ecological values as descriptive results for this frozen family, subject to the registered observation, opportunity, estimator, and support limitations. It does not establish that the family is current, identify a NEON release, or authorize promotion as current-source Driver evidence.

Driver may link to Plant Diversity as a companion and descriptive context source. Current-source or inferential promotion remains blocked until a reviewed refresh replaces this legacy receipt with a complete one.

## Contract for a future refresh

A future candidate may be labelled with a complete query-snapshot receipt only when one matching receipt is present across all 46 plant bundles and `data/site_index.rds`. The receipt must preserve:

1. the actual bundle build date, recorded separately from every source date;
2. the query cutoff and an immutable query/snapshot identifier;
3. a true official NEON release only when the fetch explicitly selected and recorded that release—otherwise `neonRelease` remains `NA`;
4. the durable `data/source/plant-raw-SHA256SUMS.txt` per-file inventory and its content-bound aggregate `sourceDigest`;
5. the builder commit and receipt schema/version;
6. the exact product, expected site inventory, license, and failure record;
7. raw-row boundary checks proving every consumed record belongs to the requested site and has a parseable `endDate` inside the registered query interval.

Partial, mixed, or disagreeing receipts fail closed. A missing site, a receipt present on only some bundles, or disagreement with `site_index.rds` blocks the candidate. `skip_download=true` means revalidate the committed inputs and their existing receipt without changing any receipt field. It must never stamp the workflow date, repository date, file mtime, manifest hash, or runtime hash into a source-vintage field.

A changed source family also triggers a separate human-claim gate. The draft refresh PR cannot pass CI until the canonical receipt, science/current-status documentation, Data Takeaways, Expert Review, Driver and suite handoffs, build handoff, empirical cover facts, social/OG artwork, image-provenance checksums, and cover receipt all carry reviewed changes; a missing or deleted required surface fails too. Exact artifact validation cannot authorize stale claims from the previous family.
