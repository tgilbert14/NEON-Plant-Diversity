<!-- neonize-playbook-stub: v1 -->
# NEONize playbook: pointer for Plant Diversity Explorer

The NEON suite playbook has one home, read by Claude Code and Codex alike:
https://github.com/tgilbert14/NEON-Driver-Cascade/blob/master/docs/neonize-playbook.md
(side-by-side clone: `../NEON-Driver-Cascade/docs/neonize-playbook.md`). Read it before
suite work. Fold every suite rule, pattern or gotcha into that file, never into this one.
Anything here beyond this pointer and the app facts below is a stale fork: report it.

## This app

- Repo `NEON-Plant-Diversity` · watched branch `master` · product `DP1.10058.001`
- Rung specialist: `flora`
- Refresh: `refresh-data.yml` (first-week cadence) publishes validated bytes only to the fixed review branch `automation/plant-diversity-data-refresh`, never `master`; a person's merge to `master` is the deploy.
- Local authority files: `docs/SCIENCE-CONTRACT.md` (grains, estimators, claim limits), `docs/PLANT-SOURCE-RECEIPT.md` (source receipt and candidate identity), `docs/BUILD-TEST-HANDOFF.md` (commands, evidence, session log), `DEPLOY.md` (release and Connect runbook), `docs/EXPERT-REVIEW.md` (product-expert review), `docs/DRIVER-KNOWLEDGE-PACKAGE.md` (Driver disposition). The site-picker contract that `R/map_picker.R` points to is canonical §2g.

## App-specific rules

- None beyond the local authority files above.

## Owner-settled house rules (both tools)

- Default demo, startup and picker pre-selection site: **SRER** (then JORN, SJER, MOAB, ONAQ) unless this app documents a reason.
- Copy voice on covers, share cards and in-app copy: plain words a non-expert follows; say what NEON is; no em dashes; no sales pitch (price, access, ease); no hype adjectives; no sincerity labels ("honest", "real data"); never state what the reader can already see.
- No visible "illustration" badge on poster art; the art's status lives in alt text and the image provenance record.

Cold boot: also grep the fleet's `.claude/agents/LESSONS.md` in TG-Data-Apps (Codex: the
`dev-teams` mirror) for your role name: `grep -E '^- \[[0-9-]*\] [a-z0-9+-]*<role>[ +]'`.
