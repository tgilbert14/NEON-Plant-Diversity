# Environment Context Receipt

Status: versioned static context; provenance is partial and this layer is not a Driver evidence source.

## Identity

- Inventory: 46 monthly `data/env/<SITE>.rds` overlays.
- Introduced to this repository: commit `b088d23ba49774d0bccd52cfd44774ca0a220091`, 2026-06-19.
- Recorded coverage in that source commit: monthly 2014–2026 climate and phenology context.
- Recorded fields: precipitation, air temperature, flowering, green-up, and sparse fruiting context.
- Upstream construction: copied from an already-built NEON suite overlay; the original per-product query IDs, download receipt, and transformation run were not preserved in this repository.

That missing upstream receipt is a real limitation. The app may use these bytes for clearly labelled short-record context, but they cannot support a promoted Cascade edge, causal statement, or independently reproducible data refresh.

## Release contract

- Plant-product refreshes do not silently relabel these overlays with the plant cutoff.
- The environment bytes are carried forward unchanged unless a separate reviewed environment rebuild replaces all 46 files.
- Every release verifies the exact 46-site filename/siteID mapping, monthly key/date consistency, finite/range constraints, and the public runtime receipt that hashes all environment files.
- A future environment rebuild must add source product IDs, query parameters, cutoff, transformation code/version, licenses, row counts, and per-file checksums before promotion.

## Driver disposition

Environment results from Plant Diversity remain exploratory, context-only, and excluded from Driver/Cascade promotion. Plant Phenology owns suite phenology timing; a future registered climate or ecosystem-flux app must own any inferential driver signal.
