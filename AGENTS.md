# Repository operating instructions

These instructions apply to the entire repository. User and platform instructions
take precedence.

## Mandatory entry point

Before inspecting, changing, testing, rebuilding, publishing, or reporting on this
repository, read `docs/BUILD-TEST-HANDOFF.md`, `docs/SCIENCE-CONTRACT.md`,
`docs/PLANT-SOURCE-RECEIPT.md`, and `docs/DRIVER-KNOWLEDGE-PACKAGE.md` completely.
For suite work, also read the Driver repository's complete
`docs/NEON-SUITE-LEARNING-LOOP.md`, `docs/NEON-SUITE-REVAMP-PLAN.md`, and
`docs/neonize-playbook.md`.

Start and end every session with `git status --short --branch`. Preserve changes
you did not create. Record the source branch and commit, watched publication
branch, public Pages URL, Connect content and URL, exact receipt values, and test
state before changing release bytes.

## Scientific contract

- The product is NEON Plant Presence and Percent Cover `DP1.10058.001`. It
  describes recorded composition, nested-scale occurrence, and relative ocular
  cover; it does not estimate productivity, biomass, demographic performance,
  ecosystem health, management success, or causal environmental effects.
- Preserve the registered 1, 10, 100, and 400 m² nested grains. Never pool raw
  sums across unequal areas or detach a value from its grain and support.
- Current-state summaries use one deterministic eligible bout per plot. Annual
  comparisons use recurrent plot panels and one deterministic bout per
  plot-year. Do not mix visits, protocols, or record-only plots to inflate
  support.
- Chao2 is the registered incidence-based, finite-sample bias-corrected lower
  bound over supported 1 m² opportunities. It is not a generic effort correction,
  a symmetric interval, or permission to invent sampled-empty quadrats.
- Percent cover is a relative composition index over supported records. Native,
  Introduced, and Unknown are exclusive; contradictory or unsupported authority
  records remain Unknown rather than being forced into a preferred class.
- Reference-flora completeness is spatially scoped. A site-level NRCS comparison
  is not a plot expectation, survey completeness score, or absence claim.
- Environment associations and short annual screens are descriptive context only.
  Maintain explicit `CAN`, `CANNOT`, and `HELD` claims and prefer an unavailable
  state to an unsupported estimate.

## Build, release, and data rules

1. Runtime must boot entirely from committed bundles. Do not add a startup
   network dependency or treat an opaque HTTP response as app health.
2. The frozen family is `legacy-partial`. Its content hash proves exact bytes, not
   upstream vintage. Never infer `builtAt`, `neonRelease`, or `sourceCutoff` from
   import dates, mtimes, manifests, runtime receipts, or repository history.
3. A refresh must stage a complete candidate, prove the expected 46 plant and 46
   environment bundles plus every derived index/reference, and publish through a
   review branch. Never delete a valid committed bundle before its complete
   replacement passes.
4. Never edit `manifest.json`, search indexes, or public receipt files by hand.
   Generate them in the pinned validator, verify deterministic equality and
   package provenance, and promote only the exact validator artifact.
5. Pin the R version, runner image, package snapshot/source closure, BLAS core and
   thread count, workflow actions, and release identities. Do not weaken a gate to
   make an environment pass.
6. Every Shiny custom-message handler accepts exactly one payload argument. Keep
   semantic readiness revocable on disconnect and test deferred Plotly wiring.
7. A release-byte promotion requires green tests on the exact PR head and merge,
   exact manifest and public receipt equality, a matching Connect-deployed commit,
   app-specific semantic readiness, and desktop plus 390/375/361/360/320 public
   verification. HTTP 200 alone is not health. A later documentation-only closeout
   records the deployed application SHA and the documentation merge separately and
   is not a new app release unless a manifest, runtime, cover, or bundled-data input
   changes.
8. Cover and social art must be local, responsive, accessible, provenance-aware,
   and separately composed at 1200×630. Creative changes do not bypass the exact
   cover receipt or suite-level art-direction review.

## Durable closeout and suite learning

Immediately before editing a durable record, re-read its latest entry. Update
`docs/BUILD-TEST-HANDOFF.md` with timestamp/time zone, scope, exact commands and
environment, expected and actual outcomes, hashes and release identities, failed
attempts and cleanup, residual risks, and the next concrete action. Update
`docs/DRIVER-KNOWLEDGE-PACKAGE.md`, `docs/DATA-TAKEAWAYS.md`, and
`docs/EXPERT-REVIEW.md` when scientific support or release status changes.

Every completed pass must update the Driver repository's evidence register,
implication backlog, revamp plan, and reusable playbook. Classify results as
app-local, suite-platform, scientific-contract, and/or Driver-impacting, and record
an explicit `ADOPT`, `HOLD`, `CONTEXT`, `COMPLEMENT`, `REJECT`, or `NONE`
disposition. Do not modify Driver artifact bytes until the evidence and decision
authorize it.
