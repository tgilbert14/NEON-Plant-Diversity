# Driver Cascade Knowledge Package

Source app: NEON Plant Diversity Explorer (`DP1.10058.001`)

Disposition: **descriptive legacy context only; no current-source or inferential Driver promotion until the registered opportunity, panel, and complete source-receipt contracts are present in promoted artifacts.**

The current plant family is the exact 46-site legacy set introduced in repository commit `4ffcb24c3c1bf0dcab1f6c42fd3b9b5fe4de4e1e` on 2026-06-19. Its canonical hash proves exact bytes, not upstream vintage. Because the original NEON release, query cutoff/receipt, raw-source digest, and actual build date were not preserved, `builtAt`, `neonRelease`, and `sourceCutoff` remain `NA`; `repositoryImportedAt` and `sourceBundleCommit` are repository-receipt fields. See [Plant Source Receipt](PLANT-SOURCE-RECEIPT.md).

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

The legacy exact-family receipt does not satisfy item 3, and missing fields may not be filled from repository dates, file mtimes, manifest hashes, or runtime hashes. Until a reviewed refresh satisfies every item, Driver should show Plant Diversity as a companion app and descriptive method/context source without adding its values to current-source evidence tallies.

## Design feedback for Driver

- Centre Driver Cascade as integrator; companions orbit it by evidence role.
- Every Driver result should link back to the owning app, estimator contract, support, source-receipt class/fields, and exact source hash; an unknown release stays unknown.
- Use `promote`, `context`, `hold`, and `reject` dispositions instead of silently treating every available metric as an edge.
- Separate producer composition, producer phenology, and producer standing stock. Plant Diversity owns composition; Plant Phenology owns timing; Vegetation Structure should own standing-stock/productivity context.
- Carry “can tell / cannot tell” and release-receipt patterns into the Driver cover and result panels.

## Candidate Driver insight

The useful suite-level learning is not a new climate→richness edge. It is the **producer-state correction**: plant richness is a grain-dependent composition measure and can rise through exotic addition, while basal area/vegetation structure is the more defensible slow standing-stock context. Driver should encode that distinction before accepting plant evidence.
