# Plant Diversity Explorer -> Driver knowledge package

Source app: NEON Plant Diversity Explorer (`DP1.10058.001`)

## Decision axes

- **Application contract trust: `VERIFIED`.** The current promoted query-snapshot
  family passed its nested-grain, deterministic-snapshot, recurrent-panel,
  source-receipt, manifest, export, responsive, Pages, and production-health
  contracts.
- **Ecological Driver disposition: `CONTEXT / HOLD DRIVER INGESTION / NO DRIVER
  BYTE CHANGE`.** App contract trust is not an ecological adoption receipt. No
  Plant Diversity value is authorized to enter a Driver evidence tally or change a
  Driver artifact from this package.

## Product and release identity

- Repository: `tgilbert14/NEON-Plant-Diversity`
- Product: NEON Plant Presence and Percent Cover `DP1.10058.001`
- Validated data candidate under review: the RELEASE-2026 candidate from refresh run `40364543238` (builder
  `486304df47c87068386d306b597a0655351b19fc`), carried in PR #26
- Previous data candidates: `a9fc28fdaebd318744dadde341c0cca55a91a899` (2026-10-21, deployed by the PR #23 merge
  `d39b8d4`) and `374fb704c548ca830f05c46d5fab1331e0027302` (2026-08)
- Current production: master `d2b9f56` (app bytes from `d39b8d4`, the 2026-10-21 receipt; post-deploy smoke
  `39620095811` passed)
- Candidate source family: one matching 46-site `plant-source-receipt-v2`, built `2026-10-26`, queried from `2013-01`
  through closed cutoff `2026-09-30`, NEON release `RELEASE-2026` (DOI 10.48443/9g4s-hq52), `neonUtilities 4.0.2`,
  receipt ID `PDE-DP1.10058.001-query-through-2026-09-30-sha256-3e484580d6c3198cb9eff6c1e300a9da31fa18d82c91b31daae450408f19e6bc`, raw-inventory digest `3e484580d6c3198cb9eff6c1e300a9da31fa18d82c91b31daae450408f19e6bc`, and a site index declaring `snapshot_contract =
  plant-snapshot-v2`. No observation changed: rows differ from production only by 5,678 exact duplicate occurrence rows
  and 921 ground rows that the bundler now drops, and six index introduced-cover values move by 0.1 to 0.5 points under
  the sampled-quadrat denominator. Retained observations end in 2024.
- Production source family (master `d2b9f56`): the 2026-10-21 receipt, built `2026-10-21`, cutoff `2026-09-30`,
  raw-inventory digest `d7e9e0de7d8e624cb4e4f9d6d64b4a41ae58f09ead497ce1307983b797811cc7`, builder
  `280539c8713c16b6b13d47d5916e0f50a10edd24`, no release selected (`neonRelease=NA`).

## Unit, opportunity, and support

- Current-state unit (`plant-snapshot-v2`, 2026-10-18): two labelled site events.
  The grain event is the site's latest `(year, bout)` with 1, 10 and 100 m² rows,
  full-grain plots only, and carries every richness and species-area figure; the
  cover event is the latest complete 1 m² bout and carries every cover-weighted
  figure. The former per-plot latest-year snapshot was retired because NEON has
  surveyed the 10 and 100 m² subplots every other year since 2019 (changeLog
  16204/16207), which left 1 m² richness under a 400 m² label at 40 of 46 sites.
- Annual unit: one deterministic bout per plot-year over a recurrent plot panel.
- Registered spatial grains: 1, 10, 100, and 400 m² incidence; ocular cover only
  at 1 m².
- Percent cover is a relative composition index over supported records; it is not
  bare-ground share, biomass, productivity, or health.
- The source family does **not** preserve an explicit sampled-empty 1 m²
  opportunity ledger. Missing survey opportunity therefore stays missing and may
  not be manufactured as zero.
- Chao2 is the registered incidence-based finite-sample lower bound over supported
  1 m² opportunities. It is not a general effort correction or permission to
  invent sampled-empty units.

## Trusted app-local context

| Field | Meaning | Grain/support | Driver use |
|---|---|---|---|
| `plant_mean_richness_400m2` | mean species per 400 m² plot | grain event: full-grain plots of one labelled site `(year, bout)` | composition context only |
| `plant_introduced_cover_relative` | mean introduced relative ocular cover | cover event: supported plots and known 1 m² records of one labelled site bout | disturbance/composition context |
| `plant_native_cover_relative` | mean native relative ocular cover | same | composition context |
| `plant_unknown_nativity_share` | unknown/conflicted share | species and cover support | confidence/context |
| `plant_cross_scale_gap` | 400 m² minus 1 m² plot detections by introduced species | exact plot lists at both grains | review context only |
| `plant_reference_completeness` | overlap with one bundled NRCS reference list | reference coordinate and list size | documentation/QC context |
| `plant_support_*` | plots, incidence units, bout, years, source identity | explicit fields | mandatory eligibility metadata |

## Measured Driver compatibility

The 2026-08-04 immutable-object audit confirmed the 46-site promoted family but
classified annual eligible support and the site-year join as `UNMEASURED`. Without
the sampled-empty opportunity ledger, a calendar intersection would not establish
the registered annual denominator. The current Driver Plant pin is
`73c92c6c67f7c982eaae76950f718ce932ff7a52`; its consumed `data/sites` tree
differs from the promoted `8fc0824` family. A blind repin is therefore forbidden.
The 2026-10-26 candidate does not change that. Its rows equal the promoted family's except for the
exact duplicates the bundler now drops, but its receipts, raw digests and six site-index values differ, and the Driver
pin still names neither. Measured with the Atlas's own annual plant summary, a repin would change no richness,
plot count or sampling-unit count in any of 439 site-years. Hill q1 and q2 change in 96 site-years (at most about 2
effective species, TALL 2018), and introduced cover share in 72 (at most 0.86 points, SCBI 2015). Even after promotion, any repin must go through the measured join and old/new parity below.

This yields four separate facts:

- app contract trust is `VERIFIED`;
- source provenance is complete for the promoted query snapshot;
- annual Driver eligibility and join support remain `UNMEASURED`; and
- ecological vote eligibility remains `CONTEXT / HOLD`.

## Explicit exclusions

- richness as productivity, biomass, standing stock, or ecosystem health;
- raw site richness as an equal-effort national ranking;
- per-site climate or phenology association as a Cascade edge;
- cross-scale occurrence as temporal spread or management priority;
- expected-list mismatch as error or survey incompleteness; and
- Plant Diversity green-up as a duplicate of the Phenology app's owned timing
  signal.

## Driver eligibility gate

Driver may reconsider a Plant field only after one reviewed package provides:

1. the exact promoted source and estimator identities;
2. a sampled-opportunity ledger that distinguishes supported zero from missing;
3. one-bout-per-plot-year and recurrent/common-grain support receipts;
4. a measured eligible Driver site-year join rather than a roster intersection;
5. an independent adapter that does not execute the sibling app;
6. missing/unknown/conflict, uncertainty, and descriptive-only semantics; and
7. old/new data, search, export, and claim parity.

Until then, Driver may link to Plant Diversity as a trusted companion and show its
methods or composition context, but it may not add Plant values to evidence tallies.

## Reusable engineering and design learning

- A complete query receipt closes source provenance; it does not create a missing
  sampling-opportunity table or authorize ingestion.
- Candidate, data merge, runtime, documentation/default, and deployed identities
  are separate receipts and must not be collapsed into one moving commit.
- Every Driver result should link to the owning app, estimator contract, support,
  source-receipt fields, and exact source identity.
- Keep composition, phenology, and slow standing structure distinct: Plant
  Diversity owns composition, Plant Phenology owns timing, and Vegetation Structure
  owns channel-qualified standing-structure context.
- The producer-state correction remains descriptive: richness is grain-dependent
  composition and may rise through exotic addition; it is not a productivity rung.

Learning classes: `app-local`, `suite-platform`, `scientific-contract`, and
`Driver-impacting` (context/held; no byte change).

## Publication receipt

2026-10-26 RELEASE-2026 candidate (not yet promoted):

- Refresh run `40364543238`, builder `486304df47c87068386d306b597a0655351b19fc`; promoted onto PR #26 as data commit
  `c5ec0becef5e64f73cdb893b15ec5e1c7ee41d62`. Earlier dispatches `40348600215` and `40359047336` stopped on first-run defects fixed in `587378f` and `486304d`.
- Candidate `data/site_index.rds` SHA-256 (committed bytes): `a47a9b3b0ed6fff6889c2637c356a543b09d7572cdcd195b372c318c2252b374`.
- Exact-head CI run, merge commit, promoted manifest SHA-256, Pages, Connect, and production-health runs: to be
  recorded at promotion.

2026-10-21 candidate, deployed: candidate `a9fc28fdaebd318744dadde341c0cca55a91a899` (run `39546911504`), PR #23
merge `d39b8d4`, exact-head validator `39551161098`, post-deploy smoke `39615036337`; site-index SHA-256
`44600682c60ecc56d74d54da3bfac9d388dbd6d10dfe67ec34ecfebd8644dd4c`.

2026-08 promotion record (its site-index SHA-256 still matches master `280539c`;
the manifest has changed since and is not re-recorded here):

- Validated data candidate: `374fb704c548ca830f05c46d5fab1331e0027302`.
- Source-data merge: `a060ee64909431f7c694d32be9729f03cb7b04e0`.
- PR #14 exact-head validation: `30826586359`; refreshed production/runtime merge:
  `8fc0824493a52a1a7ca2054852a5d84b264a9c8c`.
- Current documentation/default commit:
  `72924657ab93a05d28297616ed337bf55d4c8fbc`.
- Current-default validation: `30828066796`; Pages: `30828064229`; production
  health: `30828072298`.
- Current manifest SHA-256:
  `d7e24b0df9d25657a8999b855ed7ad92f37e3c5b45556464cc5fa10a8baaa938`;
  current site-index SHA-256:
  `1addb5ae4e5adcc3bce64016ea0a7ecce0b987b184949187742f404cc46a424a`.

## Driver decision and next dependency

Current decision: `CONTEXT / HOLD DRIVER INGESTION / NO DRIVER BYTE CHANGE`. The
current app contract and refreshed production family are trusted. The first
dependency that can change the ecological decision is an explicit sampled-
opportunity ledger, followed by a measured eligible join, independent adapter, and
old/new parity. Until all four clear, preserve Plant Diversity as non-voting
composition context and make no Driver byte change.
