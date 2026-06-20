I have everything I need. The key claims are verified: both apps have lat/lng in `site_index`, identical `load_site()`/`pickSite` wiring, Plant has 46 env files (the `insight_banner` machinery + `plant_env_perm` exist), Veg has no `data/env` and no QC flags exist in Plant (Veg has `tree_qc` in veg_helpers). The "Explore the NEON series" grep hit is in docs/README cross-promo only, not in the in-app About panel. Here is the consolidated plan.

---

# NEON Siblings → Flagship Parity: Per-App Upgrade Plan

**Verified against code (2026-06-19):** both `site_index.rds` already carry `lat`/`lng` (Plant 46 rows, Veg 42 rows) — the picker needs **zero new data and no `neon_sites` join**. Both apps already have identical `load_site()` + `observeEvent(input$pickSite, …)` wiring (Plant server.R:103-113, Veg :88-98), so a picker dot click reuses the existing load path. Plant has 46 env files + the `insight_banner`/`plant_env_perm`/`env_verdict` engine live but buried (server.R:199-379). Veg has **no `data/env`** and **no QC flags**; Plant has **no QC flags, no report PDF, no all-data export, no compare** (Veg has all four: server.R:480/519/675). The 6 reviewers are unanimous on the top two asks.

---

## SECTION 1 — PLANT DIVERSITY

### 1a. Ranked build list

| # | Item | Effort | Impact | Notes / file anchors |
|---|------|--------|--------|----------------------|
| **1** | **National pickerMap selector** (replaces `output$siteCards`) | **M** | **Defining** | Static `leafletOutput("pickerMap", height="560px")` in `div(id="splash")` (ui.R:76-90), NOT renderUI — Connect-rebind rule (flagship ui.R:135-143). Server: `renderLeaflet` + `outputOptions(…,"pickerMap",suspendWhenHidden=FALSE)`; dots size=`richness`, fill=`pct_introduced` on a sand→clay ramp. Bind popup click → existing `pickSite` (server.R:112). Keep `siteCards` as `<details>` list fallback. Lat/lng already in site_index. |
| **2** | **Precip→diversity tie-in, surfaced** (3 parts) | **M** | **High (ask #2)** | (a) Overview `overviewInsight` banner (server.R:199) leads with the precip verdict via `plant_env_perm(ms,e,only="precip")`, p-gated, silent if <5 overlapping yrs / not measured. (b) **National precip-richness gradient** scatter on the splash/Overview — one dot per site, MAP(x) vs richness(y) — the cross-site dryland-ANPP story that's robust where the 7-yr within-site series is not. (c) Hero KPI "mean annual precip (mm)" as a nav-door into the Environment tab. |
| **3** | **`precip_map` climate-normal column in site_index** | **S** | **High (unlocks #2)** | NEON gauge precip exists at only 19/46 sites — gating the national gradient on it kills the story. Pull a stable 30-yr normal (PRISM/Daymet/WorldClim) **once at build time** into `site_index$precip_map` so all 46 sites get a value. Dodges the 19/46 honesty trap; keep NEON gauge for the within-site permutation tab. |
| **4** | **Plot QC-flag system** (`plot_qc_flags()`) | **M** | **High** | No `_qc` function exists in Plant (verified). Write ranked "verify-not-wrong" flags: high=same species Native+Introduced across subplots; high=cover>150% at 1m²; warn=introduced-only-at-400m² edge contaminant; warn=watchlist invader at high cover; info=unknown-nativity share >40%. Render in plot card `#qcCardNode` (so PNG captures it) + green clean-path. Copy Veg `flags_ui` (server.R:394-399). |
| **5** | **Report PDF + all-data ZIP + codebook** | **M** | **Med-High** | Port Veg's `R/report_pdf.R` → `build_diversity_report()` (cover, species-area, Hill, native-vs-invasive, precip verdict, QC summary). Port Veg `allDataZip` (server.R:480) → occ_long.csv + plots.csv + env_annual.csv + data_dictionary.csv + README. Add a **tools-strip** to the Overview (Plant currently has none; Veg ui.R:92-95). |
| **6** | **Compare-two-sites modal** | **S-M** | **Med** | Plant has no compare (Veg server.R:675, flagship :740). Diversity is inherently comparative ("is SRER more invaded than JORN?"). Port Veg's `compareBtn` modal; side-by-side richness / %introduced / species-area. |
| **7** | **By-metric picker toggle** | **S** | **Med** | Mirror flagship by-site/by-species radio: "colour by richness \| %introduced \| precip", swapped via `leafletProxy` `clearMarkers` (no reflow, flagship server.R:698-707). |
| **8** | **`scripts/build_site_index.R`** | **S** | **Med (hygiene)** | Plant builds site_index inline in global.R:50-53; Veg + flagship have a script. With `precip_map` (+ optional species_ranges) incoming this gets unwieldy — make it one auditable precompute. |

### 1b. "Make it not underwhelming" depth additions (Plant)
- **`pm-pop-card` two-button popup** ("Explore this site" / "About this site" instant modal) so the national map is browsable before committing to a load (flagship server.R:454-501). The `.pm-pop-card` CSS is already present.
- **"This site vs the network" strip** — beeswarm/bar of all 46 sites' richness (or %introduced) with current site gold-highlighted (reuse the gold diamond at labScatter server.R:547). Answers "is this a lot?" — no site-local number can.
- **Ground-cover budget block** on Overview from the `ground` table (bare/litter/rock/foliar — partitions to ~100%, the AIM/NRCS numbers a district conservationist expects), as the headline stat *alongside* the existing relative species-cover bar.
- **Interactive invasion-foothold scatter** — make each plot dot in `pressurePlot` (server.R:317) tap-to-pin a QC card naming the introduced species detected at 1m², downloadable. Turns the app's most original analysis into a manager-actionable watchlist.
- **Honesty polish**: Chao2 unstable case → render as one-sided lower bound ("at least N species") + cite Chao 1987 in UI footnote; footnote Hill abundance unit = relative cover; gate `envScatter`'s OLS fit line on the permutation p (suppress/grey "exploratory" when verdict is "no clear link") so the line never contradicts the banner.
- **Orphan CSS**: `styles.css:519-521` has picker-tour CSS with no wired tour — either wire a landing how-to strip or delete.

---

## SECTION 2 — VEG STRUCTURE

### 2a. Ranked build list

| # | Item | Effort | Impact | Notes / file anchors |
|---|------|--------|--------|----------------------|
| **1** | **National pickerMap selector** (replaces `output$siteCards`) | **M** | **Defining** | Same static-`leafletOutput` pattern as Plant. Dots size=`n_trees`, fill=`structure_type` (forest teal / shrubland ochre, reuse `DDL$navy`/`$bark`). Popup: `tallest_m` + `biggest_dbh_cm`. Bind click → existing `pickSite` (server.R:96). Lat/lng already in site_index. Veg has **zero** national-map plumbing to reuse — but its cross-biome theme (global.R:66-71) was built for exactly this. |
| **2** | **Bundle per-site precip/temp env + climate axis** | **M-L** | **High** | Veg has **no `data/env`** at all (verified) — its only climate gap vs Plant. Port the family `refresh_env_data.R` → tiny per-site monthly precip/temp rds. Add (a) a "colour national map by mean annual precip" toggle, and (b) a **"Stand vs aridity" national scatter**: basal area / stems/ha / max height vs MAP across 42 sites (the tall-wet-forest → short-dry-shrubland continuum). |
| **3** | **Clickable QC flags → inspector** | **S-M** | **High** | `tree_qc_flags` exists (veg_helpers.R) but renders as static `<div>`s (server.R:398). Add `data-flag` id + `role=button` → `Shiny.setInputValue("qcFlagClick",…)` → `showModal` with the offending remeasurement rows + per-flag CSV + a `tree_qc_report()` full QC CSV on the card. (Then reuse this pattern for Plant's new `plot_qc`.) |
| **4** | **Annual mortality rate** (forestry standard) | **M** | **Med-High** | Mortality is honestly a snapshot ratio (ui.R:143). Veg HAS repeat measurements — add the compound annual rate `m = 1-(N1/N0)^(1/t)` (Sheil & May), gated on ≥2 censuses + known interval, CI'd, **next to** the snapshot with a one-line note distinguishing them. Keep snapshot for single-census sites. |
| **5** | **Growth allometry "Size Lab" chart** | **M** | **Med-High** | The depth chart Veg is missing: annual diameter increment vs current size, per species, fit line drawn **only** where n & \|r\| clear the bar — the structural twin of the mammal Size Lab. Answers "do big trees slow down?" with no fabricated data. |
| **6** | **Reverse-J stand-health overlay** | **S** | **Med** | Overlay the expected negative-exponential curve on `sizePlot` (server.R:194), labelled "expected reverse-J" (not a fit), so a missing-recruitment gap jumps out. Add a species-stacked variant showing which species own the canopy classes. Add a stand-shape badge (regenerating/aging/even-aged) to the picker popup + report PDF. |
| **7** | **Self-deploy → auto-push** | **S** | **Med (infra)** | `refresh-data.yml:88` uses `create-pull-request@v6` → a human must merge before Connect Cloud republishes. Replace with direct commit + `git push` to the watched branch (Plant already does this right). Confirm Connect watched branch = push target. |
| **8** | **By-record picker mode ("champions")** | **S** | **Med** | Toggle dot size = `tallest_m` / `biggest_dbh_cm` so the national map answers "where are the giant-tree sites?" before any load — extends the Champions tab to national scale. Make `fameTable` rows click → that tree's Plant Career (flagship Hall-of-Fame → Dossier pattern). |

### 2b. "Make it not underwhelming" depth additions (Veg)
- **`pm-pop-card` two-button popup** (Explore / About-instant-modal with `n_trees`/`n_species`/`tallest_m`/`biggest_dbh_cm`/`structure_type`).
- **"This site vs the network" strip** — 42-site basal area or tallest-tree with current site flagged (one reusable card, fed by already-loaded SITE_INDEX).
- **Tighten the stand fingerprint** — densityBanner + report lead with the 4-number FIA-style stand table: basal area (m²/ha ± SE), stems/ha, QMD (cm), dominant species' BA share — size-class as the supporting chart, "sampled plots not wall-to-wall" caveat in the footnote. Math is already sound (veg_helpers.R:165 pooled-RMS QMD); this is hierarchy only.
- **Growth histogram honesty** — confirm `growthPlot` x-axis spans the negative tail with a zero reference line and colors shrinkers distinctly (`DDL$bark`), so "these shrank, often real" is visible not clipped.
- **Compare modal** already exists (server.R:675) — let a tapped pair on the picker flow straight into the side-by-side size-class overlay.
- **Mobile**: cap species shown to top 10-12 on phones; reduce the `margin=list(l=200/150)` left margins responsively; confirm `config(responsive=TRUE)` on every plot; propose splash map height ~480-520px so the primary CTA stays in the thumb zone.

---

## SECTION 3 — SHARED / REUSABLE (build once, apply to both — and seed the other 3 siblings)

| Win | Effort | What | Why once |
|-----|--------|------|----------|
| **`R/map_picker.R` module** | **M (the big one)** | `mapPickerUI(id, height)` + `mapPickerServer(id, site_table, radius_metric, color_fn, popup_fn, on_pick)`. Encapsulates the Connect-rebind rule (static `leafletOutput` + `suspendWhenHidden=FALSE`), `picker_radius` (log1p 6–24px, flagship server.R:615 verbatim), `setView(-96,41,zoom=4)` + `minZoom=2` + `worldCopyJump` (so AK + PR reach), two-button `pm-pop-card`, and the `<details>` list fallback. Per-app config is just radius+color+popup. Source in both global.R files. | One audited place for the load-bearing rebind rule; reusable for Breeding Birds, Plant Phenology, Driver Cascade. This is the single highest-leverage build. |
| **QC-flag system + clickable inspector** | **S-M after Veg's** | Standardize one `*_qc_flags()` → ranked flags → `flags_ui` → clickable `showModal` + per-flag/full CSV. Rename CSS to playbook-standard hyphen form `.qc-flag-high/-warn/-info/-clean` in **both** apps (both predate the rule). | Plant gets it new, Veg gets the inspector upgrade, both get the same class convention. |
| **Report PDF + all-data ZIP + codebook** | **S to port** | Veg's `R/report_pdf.R` + `allDataZip` (cairo_pdf, no LaTeX) is the template — port to Plant; both expose a `*_codebook()` DT in-app (About/modal) + in the ZIP. | Closes Plant's biggest depth asymmetry; one export shape across the suite. |
| **"Explore the NEON series" in-app block** | **S** | Single shared registry (Small Mammal, Plant Diversity, Veg Structure, Breeding Birds, Plant Phenology, Ground Beetle, + Driver Cascade when live) — emoji + tagline + github.io URL — rendered in **every** About panel/footer. Currently only in docs/README cross-promo, NOT in the in-app About (verified). | One registry → adding a future app updates all siblings; required by playbook. |
| **localStorage "ask-once-remember-forever"** | **S** | On the picker, write picked site to localStorage on `shiny:connected` via **jQuery** `$(document).on` (not native addEventListener), try/catch-wrapped for private browsing; restore silently next visit. | Returning users skip re-picking from 42-46 sites; flagship's dashboard-mastery rule. |
| **Shared climate-normals chip** | **S** | Reusable `precip_map` + temp + green-up chip on both apps' site headers (Veg reads the same `data/env` layout once it lands). | Cheap cohesion; seeds the Driver Cascade climate layer. |

---

## DO FIRST (across both — ordered for execution)

1. **Build `R/map_picker.R` once** (Section 3, row 1) and wire it into **both** splashes, replacing `siteCards` (Plant build #1, Veg build #1). This is the defining-feature gap all 6 reviewers lead with; data + load wiring already exist, so it's near-mechanical. **Verify on the deployed Connect Cloud build with a cold cache** — a picker that binds locally but spins forever deployed is worse than the list it replaces (this is the documented bug the static-`leafletOutput` rule fixes).
2. **Plant: add `precip_map` column + surface the precip story** (Plant builds #3 then #2) — the explicit ask #2. Lead with the **national cross-site precip-richness gradient** (robust where the 7-yr site series is not), keep the within-site permutation tab as the honest drill-down, p-gate every claim.
3. **Veg: bundle precip env + "Stand vs aridity" axis** (Veg build #2) — closes Veg's only real climate gap and matches Plant's depth.
4. **Plant: port the depth stack from Veg** (Plant builds #4-#6: QC flags, report PDF + all-data ZIP, compare modal) — erases the sibling asymmetry; mostly porting existing Veg code.
5. **Both: QC clickable inspector + the shared "Explore the NEON series" block + localStorage** (Section 3) — finish cohesion and the QC-as-credibility signature.

**Relevant file paths:**
- Plant: `C:\Users\tsgil\OneDrive\Documents\VGS - R\NEON-Plant-Diversity\{ui.R (splash 76-90), server.R (load_site 103-113, env/insight 199-379), global.R (site_index 50-53), R\env_helpers.R, R\plant_helpers.R}`
- Veg: `C:\Users\tsgil\OneDrive\Documents\VGS - R\NEON-Veg-Structure\{ui.R (splash 64-96), server.R (load_site 88-98, allDataZip 480, reportPdf 519, compareBtn 675), R\veg_helpers.R (tree_qc), R\report_pdf.R, .github\workflows\refresh-data.yml:88}`
- Flagship reference: `C:\Users\tsgil\OneDrive\Documents\VGS - R\App-NEON-Small-Mammal-Tracker\{ui.R:135-212, server.R:610-707}`
- New shared module to create: `NEON-Plant-Diversity\R\map_picker.R` (and source the same file into Veg, or lift to a shared location)