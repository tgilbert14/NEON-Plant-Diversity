# Driver Cascade Knowledge Package

Source app: NEON Plant Diversity Explorer (`DP1.10058.001`)

Disposition: **CONTEXT / NO DRIVER BYTE CHANGE.** The recurrent-panel contract and candidate source receipt are validated, but no Driver ingestion or inferential promotion is authorized until a sampled-opportunity ledger, measured eligible join, independent adapter, and old/new parity are reviewed in promoted artifacts.

Validated candidate `374fb704c548ca830f05c46d5fab1331e0027302` replaces the legacy set in candidate bytes with one matching 46-site `plant-source-receipt-v2`: built `2026-08-03`, query `2013-01` through `2026-07-31`, raw-inventory digest `48167b04cc689fbcaaa3e83bdac7cc7ed1c8ac34f791e5e76d3f229862d61ac6`, and builder commit `1734840a4f09e7acee356431ea1e57e9a637fb31`. No official release was selected, so `neonRelease=NA`; retained observations end in 2024. See [Plant Source Receipt](PLANT-SOURCE-RECEIPT.md).

Producer/validator run `30818211291` and artifact `8858560431` establish the candidate data family; an independent oracle reconciles all 46 snapshot/index rows and limits semantic row changes to JORN, KONZ, and SRER. Public production still serves legacy commit `d6c48625f8268873bcd42d86285becaadbd57b4c` until exact-head CI, merge, Connect, Pages, export, responsive, and semantic-health evidence closes in [BUILD-TEST-HANDOFF.md](BUILD-TEST-HANDOFF.md). Candidate validation closes source provenance, not Driver ingestion.

## What this app contributes

| Field | Proposed meaning | Grain/support | Driver use |
|---|---|---|---|
| `plant_mean_richness_400m2` | mean species per 400 m² plot | one registered snapshot per plot | composition context |
| `plant_introduced_cover_relative` | mean introduced relative ocular cover | supported plot and known 1 m² units | disturbance/composition context |
| `plant_native_cover_relative` | mean native relative ocular cover | same | composition context |
| `plant_unknown_nativity_share` | unknown/conflicted share | species and cover support | confidence penalty |
| `plant_cross_scale_gap` | 400 m² minus 1 m² plot detections by introduced species | exact plot lists at both grains | review context only |
| `plant_reference_completeness` | overlap with the bundled single-point NRCS reference list | reference coordinate, list size | documentation/QC context |
| `plant_support_*` | plots, incidence units, bout, years, source hash | explicit | mandatory eligibility fields |

## Explicit exclusions

- richness as productivity, biomass, or ecosystem health;
- raw site richness as an equal-effort national ranking;
- per-site climate/phenology association as a Cascade edge;
- cross-scale occurrence as temporal spread or management priority;
- expected-list mismatch as error;
- Plant Diversity green-up as a duplicate of the Phenology app's owned phenology signal.

## Eligibility gate

Driver may ingest a proposed Plant field only when the source package includes:

1. estimator contract version;
2. exact source artifact and inventory hashes;
3. one complete matching source receipt across all 46 plant bundles and `site_index.rds`, including the actual build date, query cutoff and immutable snapshot/query ID, true official release only when actually selected, raw/source digest, and builder commit;
4. one-bout-per-plot-year selection receipt;
5. recurrent-panel or common-grain support;
6. opportunity/denominator semantics;
7. missing/unknown/conflict semantics;
8. uncertainty or explicit “descriptive only” class;
9. exact app/export/fixture parity.

Candidate `374fb704c548ca830f05c46d5fab1331e0027302` satisfies item 3 with one matching receipt and durable 46-file raw inventory. It also preserves the registered estimator, snapshot, support, missingness, and descriptive-only contracts. It does not satisfy an explicit sampled-empty opportunity ledger, measured Driver join, independent adapter, or ingestion parity. Driver should therefore continue to show Plant Diversity as a companion and descriptive method/context source without adding its values to evidence tallies.

## Design feedback for Driver

- Centre Driver Cascade as integrator; companions orbit it by evidence role.
- Every Driver result should link back to the owning app, estimator contract, support, source-receipt class/fields, and exact source hash; an unknown release stays unknown.
- Use `promote`, `context`, `hold`, and `reject` dispositions instead of silently treating every available metric as an edge.
- Separate producer composition, producer phenology, and producer standing stock. Plant Diversity owns composition; Plant Phenology owns timing; Vegetation Structure should own standing-stock/productivity context.
- Carry “can tell / cannot tell” and release-receipt patterns into the Driver cover and result panels.

## Driver insight

The useful suite-level learning is not a new climate→richness edge. It is the **producer-state correction**: plant richness is a grain-dependent composition measure and can rise through exotic addition, while basal area/vegetation structure is the more defensible slow standing-stock context. Driver should encode that distinction before accepting plant evidence.
