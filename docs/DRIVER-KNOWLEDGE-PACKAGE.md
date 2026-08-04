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
- Validated data candidate: `374fb704c548ca830f05c46d5fab1331e0027302`
- Source-data merge: `a060ee64909431f7c694d32be9729f03cb7b04e0`
- Current refreshed production/runtime authority:
  `8fc0824493a52a1a7ca2054852a5d84b264a9c8c`
- Current documentation/default authority:
  `72924657ab93a05d28297616ed337bf55d4c8fbc`
- Current source family: one matching 46-site `plant-source-receipt-v2`, built
  `2026-08-03`, queried from `2013-01` through closed cutoff `2026-07-31`, raw-
  inventory digest
  `48167b04cc689fbcaaa3e83bdac7cc7ed1c8ac34f791e5e76d3f229862d61ac6`,
  and builder `1734840a4f09e7acee356431ea1e57e9a637fb31`. No official release was
  selected (`neonRelease=NA`), and retained observations end in 2024.

## Unit, opportunity, and support

- Current-state unit: one deterministic eligible `(year, bout)` snapshot per plot.
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
| `plant_mean_richness_400m2` | mean species per 400 m² plot | one registered snapshot per plot | composition context only |
| `plant_introduced_cover_relative` | mean introduced relative ocular cover | supported plots and known 1 m² records | disturbance/composition context |
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
