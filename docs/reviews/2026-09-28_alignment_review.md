# Alignment Review: `_setup`, `harness`, `modules`, `exp_000_parity_v2`

**Repository:** `sdmMethodsDev` (branch `development`, commit `5ae067a`)
**Date:** 2026-09-28
**Scope:** `1_code/_setup/`, `1_code/harness/`, `1_code/modules/`,
`1_code/experiments/exp_000_parity_v2/`, checked against `README.md`
and the v2 reference code in `0_data/v2_scripts/`.
**Method:** Static reading of the code and comparison with the v2
source, the committed outputs in `3_output/exp_000_parity_v2/`, and
`2_pipeline/exp_000_parity_v2/run_log.csv`. Nothing was re-run.

---

## 1. Verdict

**The code is partly aligned.** Harmonizing the v2 data is well
advanced and carefully validated. The reproducible structure exists
and is well engineered. **Parity with v2 has not been shown, and in
its current form the pipeline cannot show it.** There are three
reasons:

1. **Several v2 behaviours are implemented differently.** The biggest
   is that the climate stage is fitted separately on the north and
   south subsets, while v2 fits it once, province-wide. This shifts
   every downstream habitat coefficient, for every taxon.
2. **The gate compares the wrong things.**
   - Only the final stage's coefficients are stored, so climate-stage
     parity is never measured, even though the report is headed
     "Climate-stage parity".
   - The gate reads v2 references from network drives and a wrong
     local path. It ignores the harmonized reference that
     `_setup/05` builds.
3. **The committed outputs cannot be reproduced from the committed
   code.**
   - `report.md` and the parity tables have columns that no commit
     has ever produced.
   - The one committed artefact, `run_record.md`, describes a
     different run.

The README has also drifted. It describes an earlier design (v2
scripts rewritten into `modules/plants/01_…03_`). The code has since
become a spec-driven, taxon-agnostic harness. A new contributor who
follows the README would not find the files it names.

| Objective (from README) | Status |
| --- | --- |
| Static cross-taxa test dataset, harmonized from `model_ready_v2` | 🟢 Largely met |
| Taxon-agnostic harness + thin taxon modules | 🟢 Met (design differs from README) |
| Experiments configure-only; outputs confined to `pipeline_dir`/`out_dir` | 🟢 Met |
| Rewrite checked against v2 rather than trusted | 🟡 Partly met (formulas yes; stage structure no) |
| `exp_000` reproduces v2 outputs (parity gate) | 🔴 Not met, and not yet measurable |
| Results comparable over time from the repository alone | 🔴 Not met (outputs gitignored; record ≠ outputs) |
| README describes the current structure and run order | 🔴 Not met |

---

## 2. What is working well

These are real strengths and should be kept.

- **Harmonization and validation (`_setup/01`, `_setup/02`).**
  - Every value is traced back to the snapshot, with an independent
    re-statement of the rules, so a bug cannot cancel itself out.
  - Factor-level restoration, catalogue-based covariate checks, and
    the note that CSV round trips keep about 15 significant digits
    all reflect careful work.
  - The vegetation prediction matrix now carries `Peatland`,
    `Mineral`, `Upland` and `CCR1234`, so the README's main "known
    gap" is closed.
- **Reference recovery (`_setup/03`–`05`).**
  - The bryophyte reference was regenerated with the frozen v2
    functions.
  - The bird coefficients were re-packaged.
  - `05` flattens three storage formats into one long reference,
    `0_data/v2_results/v2_results.csv`. This is the right design.
- **Harness engineering.**
  - Engines, selection rules, resampling schemes and metrics each
    have one interface.
  - Covariates are read off the formulas, so no term can be fitted
    without its column.
  - Stage-model overrides are recorded in `meta.json`.
  - Failures are recorded per draw rather than aborting the run
    (with one exception, M6).
- **Plant formula fidelity.** The 58-model plant climate set rebuilds
  v2's `model.update.id` logic correctly: 14 base models, 14 bioclim
  variants, and 10 × 3 spatial variants. The IVW grid rule and
  `coef_adjust_plant_veg()` match v2 line for line.
- **Honest documentation of gaps.** Specs and headers state what
  they do not reproduce. The problem is that these statements now
  disagree with each other (see §5).

---

## 3. Critical findings (P0): these invalidate the parity read

### C1. The climate stage is fitted per region, not province-wide

| | |
| --- | --- |
| **Where** | [run_model.R:395](../../1_code/harness/run_model.R#L395) applies `region_filter` in `build_model_data()` before any stage runs. Plant regions are `nr != "Grassland"` and `nr %in% c("Grassland","Parkland")` ([plant_group.R](../../1_code/modules/_shared/plant_group.R)); bird regions are `useNorth` / `useSouth`. |
| **v2** | Plants: `climate_models()` fits on every site in the bootstrap sample. Only `vegetation_models()` and `soil_models()` then filter by `NR` (`hierarchical-model_functions.R` L39–42 vs L161, L723). Birds: `06.ModelClimate.R` fits climate on all surveys in the draw; `07.ModelLandcover.R` filters by region afterwards. |
| **Effect** | Each region gets its own climate model, fitted on a subset. The `Climate` term carried into the habitat stage is therefore a different covariate from v2's, and every habitat coefficient shifts. `_setup/05` says "A run's north and south climate results are both scored against [the province-wide v2 values]", which is a structural mismatch. |
| **Remedy** | Add a stage-level scope (e.g. `scope = "province"`). Fit the climate stage once per species × draw on the unfiltered draw, then apply the region filter only for the habitat stage. |

### C2. The bootstrap is drawn within the region, not province-wide

| | |
| --- | --- |
| **Where** | `resample_for_species()` is given `model_data$covariates`, which is already region-filtered ([run_model.R:421](../../1_code/harness/run_model.R#L421)). |
| **v2** | `01b_bootstrapping.R` / `bootstrap_data()` resample within lat/long blocks across **all** sites, once per species. The ≥ 20-detection redraw rule is evaluated on the whole sample. |
| **Effect** | The block composition, the redraw rule and the sample size all differ from v2. Distributional parity is not expected even if everything else were fixed. |
| **Remedy** | Draw once per species over the province-wide frame, and derive the regional subsets from that draw. Fix this together with C1. |

### C3. Climate-stage coefficients are never written, so the "climate parity" table is habitat parity

| | |
| --- | --- |
| **Where** | `run_one_draw()` writes only `result$selected$coefficients`, the **last** stage ([run_model.R:613](../../1_code/harness/run_model.R#L613)). The committed `report.md` table is headed "Climate-stage parity" but its `stage` column reads `habitat` on every row. |
| **Effect** | The README status "Climate and soil models run" is never actually compared. The bryophyte "now gatable" claim in the experiment README is false: against a climate-only reference, the join matches on `Intercept` alone, which is a different quantity in the two stages. |
| **Remedy** | Write coefficients for every stage with a `stage` column, and compare per stage. The climate stage is the one that could be gated **now**. |

### C4. The bird specification departs from v2 in four places

| Item | v2 (`0_data/v2_scripts/birds/`) | Harness | Evidence |
| --- | --- | --- | --- |
| Climate candidates | **25**: null + 8 + 8 × (`Easting + Northing + Easting:Northing`) + 8 × (`+ I(Easting^2) + I(Northing^2)`) | **9** (`climate_bird_mammal_v2`) | `06.ModelClimate.R` L111–125 vs [model_sets.R:54](../../1_code/harness/model_sets.R#L54) |
| Landcover weights | `weights = vegw` (north) / `soilw` (south) | `weight_column = NULL` | `07.ModelLandcover.R` L84–101 vs [birds/spec.R:51](../../1_code/modules/birds/spec.R#L51) |
| Climate carried as | `exp(link)`, the response scale | `carry_scale = "link"` | `06.ModelClimate.R` L83, L134 vs [birds/spec.R:84](../../1_code/modules/birds/spec.R#L84) |
| Staged selection | Always advances to the group's smallest-K model within 2 BIC (K > 1) | Advances only if it beats the current model's BIC | `07.ModelLandcover.R` L122–131 vs `select_staged_bic()` in [selection.R](../../1_code/harness/selection.R) |

The spec header's statement that the climate set is "the same set the
mammal pipeline arrived at independently" is incorrect. These four
differences are the likeliest cause of the committed bird parity
result: 0–2.6 % of terms in band, with a median standardized
difference of 40–56. That result is systematic, not noise.

**Also needed:** a term translation. `Birds2024.RData` holds
coefficients on the standardized cross-taxa template
(`WhiteSpruceR`, `Loamy`, …). The harness stores raw `glm` names
(`vegcCrop`, `soilcLoamy`). A port of the `08.PackageCoefficients.R`
translation is needed before bird habitat terms can be compared.

### C5. The gate does not read the harmonized reference

- [02_compare_to_v2.R:60–75](../../1_code/experiments/exp_000_parity_v2/02_compare_to_v2.R#L60-L75)
  reads plant and mammal references from `//ABMI-DATA2/…` and
  `G:/Shared drives/…`. It ignores `0_data/v2_results/v2_results.csv`,
  which `_setup/05` builds for exactly this purpose. It is 124,098
  rows, with every source reachable according to
  `v2_results_coverage.csv`.
- The "local" search path is `pipeline_dir/v2_reference`, which is
  `2_pipeline/exp_000_parity_v2/v2_reference/`. `_setup/03` and `04`
  write to `2_pipeline/v2_reference/`, so the regenerated references
  are never found.
- The bird reference is hard-coded to `NULL`, although
  `Birds2024.RData` exists.
- The mammal reference is read from the **climate** coefficient
  files, while the mammal run's final stage is **habitat**.
- This breaks the README rule that an experiment needs only the test
  dataset: "Building the dataset needs the snapshot; running an
  experiment does not."

**Remedy:** `02_compare_to_v2.R` should read only
`0_data/v2_results/v2_results.csv` and join on `taxon`, `region`,
`stage`, `species` and `term`.

### C6. The committed outputs are not reproducible from the committed code

- `3_output/…/tables/parity_summary.csv` and `report.md` contain the
  columns `stage`, `run_terms`, `match_rate_pct` and
  `expansion_terms`. `git log --all -S match_rate_pct` returns
  nothing, so no commit has ever produced them. The working tree is
  clean, so this is not uncommitted code sitting in the repository.
  The timestamps show what happened: the last commit was at 10:44,
  the parity tables were written at 13:10 by a temporary edit of
  `02_compare_to_v2.R`, and that file was restored to its committed
  content at 13:15.
- The remaining tables (`coefficient_summary.csv`,
  `metric_summary.csv`, `coverage.csv`) were written at 13:21 by a
  later run, so the folder mixes outputs from two runs.
- Those tables also report **bird** parity, which the committed
  `02_compare_to_v2.R` cannot produce, because it sets the bird
  reference to `NULL`.
- `run_record.md`, the only committed artefact, describes a
  **different run**: commit `e5a381a`, 2026-09-13, 2 draws, 1 species
  per taxon. The tables and report come from a 2026-09-28 run with 5
  draws and 2 species per taxon.
- The README says `3_output/` is committed. `.gitignore` commits only
  `run_record.md`.

**Remedy:**

- Regenerate the tables from committed code: in `run.R`, set
  `run_models <- FALSE` and re-run so collect, compare and report
  rebuild from the existing stores. If the temporary comparison
  version was intended work, recover it and commit it.
- Decide which `3_output/` artefacts are committed (at minimum
  `parity_summary.csv` and `report.md`) and align `.gitignore` and
  the README.

---

## 4. Major findings (P1): correctness and provenance

| ID | Finding | Evidence | Remedy |
| --- | --- | --- | --- |
| **M1** | **The recorded seed is wrong.** Plants and mammals pass `seed = NULL` (unseeded). `meta.json` records `spec$resample$seed %||% harness_seed()`, which is `20260909`, a seed that was never used. The README's `boot_seed` in `run.R` does not exist. | [plant_group.R:170](../../1_code/modules/_shared/plant_group.R#L170), [mammals/spec.R:311](../../1_code/modules/mammals/spec.R#L311), [run_model.R:460](../../1_code/harness/run_model.R#L460) | Seed by default. Expose `boot_seed` in `run.R`. Record the seed actually used (or `"unseeded"`). |
| **M2** | **`set.seed()` inside the resamplers** resets the global RNG on every species × region call. When seeded, every species gets the same draw rows (correlated across species; v2 draws independently), and the caller's RNG state changes as a side effect. | [resample.R:225, 301](../../1_code/harness/resample.R#L225) | Derive a per-species seed (e.g. a hash of base seed + taxon + species + region). Restore the RNG state on exit. |
| **M3** | **Predictions and metrics come from the best single candidate, not the averaged model.** `aic_average` and `ivw_grid` return the lowest-IC fit as `fit`, and unit predictions and AUC are computed from it. Metrics are also **in-sample**: they are computed on every unit, including those in the draw. v2's validation stage (`03x_model-validation`) has no equivalent. | [selection.R:387, 611](../../1_code/harness/selection.R#L387), [run_model.R:617](../../1_code/harness/run_model.R#L617) | Predict from the averaged coefficients (`predict_from_coefficients`). Add out-of-bag evaluation, and port v2's validation to create a baseline. |
| **M4** | **Mammals are not comparable to their reference.** (a) The run is summer-only, but `Coef.pa.all` averages seasons (per `_setup/05`'s own note). (b) South `habitat_models = NULL`, so every south draw errors (10/10 `error` rows in `run_log.csv`). (c) `climate_source = "precomputed"`, documented as the v2 default, is not implemented: `mammal_climate_predictions.csv` is never read. (d) v2 fits the habitat stage once, so only iteration 1 is like-for-like. (e) Age splines and cutblock convergence are missing. | [mammals/spec.R:256](../../1_code/modules/mammals/spec.R#L256), `run_log.csv` | Run both seasons and average before comparing. Skip south explicitly until its sets exist. Implement or remove `precomputed`. Gate mammals on `boot == 1`. |
| **M5** | **Plant cutblock convergence is under-flagged.** v2 converges cutblock classes **2**, 3 and 4 onto natural stands (`hierarchical-model_functions.R` L622–628). The gate's `age_spline_term` regex `^CC.*[34]$` misses class 2, so those terms count as "reachable" when they cannot match. | [02_compare_to_v2.R](../../1_code/experiments/exp_000_parity_v2/02_compare_to_v2.R) | Build the flag list from v2's code, not a regex. |
| **M6** | **One rare species can abort the whole experiment.** `resample_spatial_block()` calls `stop()` after 100 failed redraws. It runs outside the per-draw `tryCatch`, so the whole experiment aborts. v2 instead redraws only when the full data already met the threshold. | [resample.R](../../1_code/harness/resample.R), [run_model.R:421](../../1_code/harness/run_model.R#L421) | Mirror v2: check the full-data detection count first, and log and skip on failure. |
| **M7** | **The AICc parameter count differs from MuMIn.** It uses `length(coef)`, which counts aliased (`NA`) coefficients. MuMIn uses the `logLik` degrees of freedom (the rank). Weights diverge whenever a candidate has aliased terms. | [engines.R:329](../../1_code/harness/engines.R#L329) | Use `attr(logLik(fit), "df")`. |
| **M8** | **Any warning causes a refit.** `fit_glm_family()` fits the model again in its `warning =` handler. For `bayesglm` on rare species, warnings are common, so fitting cost roughly doubles. | [engines.R:218](../../1_code/harness/engines.R#L218) | Use `withCallingHandlers()` to capture the warning and fit once. |

---

## 5. Documentation and structure drift (P1–P2)

| ID | README says | Code does |
| --- | --- | --- |
| **D1** | `modules/plants/{load_model_data.R, 01_bootstrap_ids.R, 02_…, 03_…}`, `functions/`; `run_step()` sources each stage | `modules/<taxon>/spec.R` + `_shared/plant_group.R`; the old files are in `_deprecated/`; `run_step()` is loaded but never called |
| **D2** | `harness/{data_load, data_split, covar_attach, eval_metrics}.R` | 13 files (`selection`, `engines`, `resample`, `model_sets`, `run_record`, …); `data_split` and `covar_attach` are deprecated |
| **D3** | `test_dataset/covariates/<taxon>_{climate,veg,soil}.csv`, per taxon | One wide `covariates.csv` keyed on `survey_unit_id` + `taxon` |
| **D4** | `_setup/` holds `01`, `02`, `_scratch.R` | `01`–`05`; `03`–`05` are undocumented; `_scratch.R` sits at `1_code/` root |
| **D5** | `utils/species_lists.R` | `utils/focal_species.R` |
| **D6** | "Vegetation models cannot be fitted yet" | The prediction matrix is complete; the habitat stage runs |
| **D7** | "Contributing a taxon module: model it on `lichens/`, with `load_model_data.R`, numbered stages, `functions/`" | `lichens/` is a 44-line spec |
| **D8** | `3_output/` is committed | Only `run_record.md` is committed |
| **D9** | Not mentioned | `0_data/v2_results/`, `docs/framework_design.md`, `docs/taxon_quirks.md`, `1_code/_deprecated/` |

**Internal contradictions.** Status is currently stated in six
places: the README, the experiment README, the `run.R` header, the
`03_build_report.R` hard-coded text, spec `notes`, and
`docs/taxon_quirks.md`. They disagree:

- **Mammal climate:** "4 of 9 models, `CMD` missing" in
  `03_build_report.R` L83 and the mammal spec L340, but "full 9-model
  set" in the experiment README and the mammal spec L181.
- **Bryophytes:** "no usable reference" in `03_build_report.R` L138
  and `02_compare_to_v2.R`, but "regenerated, now gatable" in the
  experiment README.
- **Birds:** "no reference reachable" in the experiment README L102
  and the spec, but `Birds2024.RData` is packaged and listed as
  reachable in `v2_results_coverage.csv`.
- **Bird landcover:** "not yet reproducible" in the spec header, but
  "that was wrong" in the spec notes.
- **Habitat coverage:** "Coverage is the climate stage; no taxon's
  habitat stage is reproduced" in `run.R` L24, while the experiment
  README table shows habitat ✅ or ⚠️.
- **Mammal notes:** the string is garbled by concatenation ("…it
  needs AICc Habitat: both halves…", mammal spec L325).

**Dead code:**

- `climate_mammal_available` in `model_sets.R` is no longer used.
- `step_runner.R` is sourced but unused.

---

## 6. Remediation plan

The plan is ordered so each phase makes the next one measurable. Each
step has an acceptance check.

### Phase 0: Re-establish a trustworthy baseline (documentation and provenance)

| # | Action | Done when |
| --- | --- | --- |
| 0.1 | Regenerate the `3_output` tables from committed code (`run_models <- FALSE`), replacing the ones left by the temporary edit (C6). | Re-running `run.R` from a clean checkout reproduces the committed `parity_summary.csv`. |
| 0.2 | Set one `boot_seed` in `run.R`, derive a per-species seed from it, and record the seed actually used in `meta.json` and `run_record()` (M1, M2). | Two runs with the same `boot_seed` give identical stores. `meta.json` never reports an unused seed. |
| 0.3 | Decide which `3_output/` artefacts are committed; align `.gitignore` and the README (C6, D8). | The README and `.gitignore` agree. |
| 0.4 | Rewrite the README's *Pipeline flow*, *Directory structure*, *`1_code/`*, *Known gaps* and *Contributing a taxon module* sections for the spec-driven design, and document `_setup/03–05`, `0_data/v2_results/` and `docs/` (D1–D9). | Every path named in the README exists. |
| 0.5 | Give status one source of truth. Generate the report's coverage prose from the specs (`habitat_v2_ready`, `notes`) and `v2_results_coverage.csv`, instead of hard-coding it in `03_build_report.R`. Fix the garbled mammal notes. | No contradictions remain between the README, the experiment README, specs and the report. |

### Phase 1: Make the gate measure the right thing

| # | Action | Done when | Status (2026-09-29) |
| --- | --- | --- | --- |
| 1.1 | Write coefficients **per stage**, with a `stage` column (C3). | `coefficient_summary.csv` has climate and habitat rows. | Done |
| 1.2 | Point `02_compare_to_v2.R` at `0_data/v2_results/v2_results.csv` only; drop the network paths (C5). | The gate runs with the network drives unmounted. | Done |
| 1.3 | Join on `taxon × region × stage × species × term`. Score plant **climate** against the `region = "all"` rows. | The climate-stage parity table exists for all four plant taxa. | Done; plant habitat terms also relabelled as v2's `04a` does |
| 1.4 | Mammals: run both seasons, average them, and compare against `.all`. Gate on `boot == 1` (M4). | Mammal rows are like-for-like. | Done, with season filtering fixed in `list_species()`; mammal habitat joins only terms named alike (new item) |
| 1.5 | Birds: port the `08.PackageCoefficients.R` term translation (C4). | Bird habitat terms join on the standardized template. | Done; exact against `Birds2024.RData`. Needs `_setup/06`. Found and fixed a `method` reference-level bug |
| 1.6 | Build the non-reachable-term list from v2's code, including `CC*2` (M5). | `reachable_terms` excludes every spline- or convergence-overwritten term. | Done, for plants, mammals and bird placeholders |

### Phase 2: Match v2 behaviour where the harness departs from it

| # | Action | Done when | Status (2026-09-29) |
| --- | --- | --- | --- |
| 2.1 | Fit the climate stage on the full province draw; apply the region filter only for habitat (C1). | The plant climate coefficients for north and south runs are identical per draw. | Done; north and south climate identical per draw (difference 0) |
| 2.2 | Draw the bootstrap once per species over the province, with v2's redraw rule (C2, M6). | Draw sizes match `bootstrap_data()`; a rare species logs and skips instead of aborting. | Done; draws are the full province size, and a species whose draws cannot be made is logged `resample_failed` |
| 2.3 | **Strongly recommended:** harmonize v2's own stored plant bootstrap ids (`<taxon>-bootstrap-ids.Rdata`: 100 draws for lichen, mite and vascular plant, regenerated for bryophyte) into `lookup/`, and extend `resample_precomputed()` to per-species ids. This turns parity from **distributional** into **numerical, draw by draw**, as birds already allow. | Per-draw climate coefficients match v2 to numerical tolerance (e.g. relative difference < 1e-6), or each deviation is explained. | Done (`_setup/07`, `bootstrap = "v2_ids"`). Exact to 4e-11 per draw against the regenerated bryophyte reference; the published lichen models were not fitted on the stored draws, so only draw 1 matches there |
| 2.4 | Birds: use the 25-model climate set, `vegw`/`soilw` weights, climate carried on the response scale, and v2's advance rule (C4). | The bird climate stage matches `Birds2024.RData` per draw with precomputed ids. | Done; matches v2's own code to 4e-13 (climate and landcover). Also fixed: landcover lacked `Climate`. The published `Birds2024` differs because it came from a different data vintage |
| 2.5 | Take the AICc degrees of freedom from `logLik` (M7). Fit once per candidate (M8). | Akaike weights match `MuMIn::model.avg` on a test case. | Done; matches `MuMIn::model.avg` (≤ 6e-17), including aliased terms |
| 2.6 | Seed per species, with RNG state restored (M1, M2). | Two runs of the same configuration give identical stores. | Done (earlier); two runs give identical stores |
| 2.7 | Mammal south: implement the sets or skip the region explicitly. Implement or remove `climate_source = "precomputed"` (M4). | `run_log.csv` has no structural `error` rows. | Done: south sets implemented; `precomputed` stops with a clear message. No `error` rows |

### Phase 3: Add the missing v2 machinery

| # | Action | Done when | Status (2026-09-29) |
| --- | --- | --- | --- |
| 3.1 | Plant age splines: 9 GAM fits, AIC selection across the 4 groupings, prediction at ages 0.5 and 1–8. `select_ivw_grid()` must also return the site-level IVW prediction (`data$prediction` in v2). | The 45 aged-stand terms enter the reachable set. | Done; north habitat matches v2 to 2e-12 on the full-data draw (lichen, mite). Also fixed: the south dropped its pAspen candidates |
| 3.2 | Plant cutblock convergence for classes 2, 3 and 4, then `coef.adjust`. **Order matters:** v2 applies convergence *before* the adjustment. | The `CC*` terms are reachable. | Done; converged before the pooling, as v2 |
| 3.3 | Mammal age splines, cutblock convergence and total abundance, as a separate implementation (per `taxon_quirks.md`). | The mammal habitat terms are reachable. | Done: `modules/mammals/hurdle.R`, both halves together on v2's full habitat set; presence, abundance and total match to 2e-14 (moose, coyote; north and south). Also fixed: the dataset carried the wrong south pAspen |
| 3.4 | Port v2's validation stage (`03x_model-validation`) and compute held-out metrics. | `metric_summary.csv` holds out-of-bag or validation metrics, not in-sample ones. | Done: v2's 7 AUCs in-bag and out-of-bag, plus out-of-bag harness metrics. South exact; north within 2e-4 of v2's published values |

### Phase 4: Close the gate

| # | Action | Done when | Status (2026-09-29) |
| --- | --- | --- | --- |
| 4.1 | **Calibrate before you set a target.** Compare the regenerated bryophyte reference against `COEFS.RData` (two v2 runs of the same code) to measure v2's own run-to-run agreement. That sets the ceiling for any distributional target. | A documented v2-vs-v2 in-band rate exists. | Done: `v2_self_agreement.R`. v2 against itself: 100% in band, median standardized difference 0.019, median Spearman 0.998 |
| 4.2 | Agree a numeric target per taxon and per stage. A strawman: with precomputed ids, **numerical** agreement on climate; for stages that stay stochastic, an in-band rate ≥ the v2-vs-v2 rate minus a stated tolerance, **and** grid-prediction correlation ≥ 0.95. | The targets are recorded in the experiment README. | Proposed, awaiting agreement: `utils/parity_targets.R`, recorded in the experiment README; verdicts computed per row. Spearman of medians replaces the grid correlation, which v2's reference cannot support |
| 4.3 | Run 100 draws for the full species queues and commit the report and record. | The gate reads pass or fail per taxon. | Partly: the full queues are days of compute; the parity_check set was run at 100 draws for an indicative verdict. Not committed |

---

## 7. Code review summary (AGENTS.md §7)

| Section | Standard | Meets | Needs Improvement | Not Met | Comments |
| --- | --- | --- | --- | --- | --- |
| Code formatting | tidyverse style, ≤ 70-char lines, `snake_case`, no dead code | ✅ | | | Consistent and well styled. The long habitat formula strings exceed 70 characters, but they are verbatim v2 splices, which is justified. There is minor dead code (`climate_mammal_available`, unused `run_step`). |
| Project structure | Conventions in the guide and README | | ✅ | | Layout follows the template. The README tree is out of date (D1–D9), and `_scratch.R` is misplaced. |
| Functional correctness | Valid results, validation, reproducibility | | | ✅ | C1–C6 and M1–M7. The pipeline runs, but it does not yet reproduce v2, and its provenance records are inaccurate. |
| Efficiency | No redundant work | | ✅ | | Column-selective reads and load-once-per-region are good. Refit on warning (M8); no parallelism for a 100-draw run. |
| Intelligibility | Headers, docs, logical flow | | ✅ | | Excellent headers and *why* comments. Status is spread across six sources that contradict each other (§5). |

---

## 8. Assumptions, confidence and limits

**Assumptions**

- The README's stated objectives (harmonized frozen dataset →
  taxon-agnostic pipeline → `exp_000` parity with the v2 outputs)
  are the yardstick. The spec-driven redesign is taken as
  intentional, not as a mistake.
- "Parity" means reproducing v2's published coefficients for the
  same method, not better methods.

**Not verified**

- No code was run, including `_setup/02_validate_test_dataset.R`,
  which needs network access to the snapshot.
- The harmonized data values were not checked against the snapshot.
- The mammal v2 scripts were read only for bootstrap usage. Mammal
  findings rely partly on statements in `_setup/05` and the specs.

**Confidence**

- **High** for C1, C3, C4, C5, C6, M1, M4(b–c) and D1–D9: each is
  directly visible in the code, the v2 source, or git.
- **Moderate** for how much C1, C2 and C4 contribute to the observed
  parity gaps. The committed run used only 5 draws and 2 species, so
  its in-band rates cannot separate noise from bias. The bird
  standardized differences of 40–56 are too large to be noise.
- **Moderate** for M7 (AICc degrees of freedom): whether it matters
  depends on how often candidates have aliased terms.

**Pitfall to watch**

The current in-band test asks whether the v2 **median** falls inside
this run's 10th–90th percentile band. With few draws the band is wide
and the test barely discriminates; `run.R` already warns about this.
With many draws, v2's own run-to-run variation can push the median
outside the band even for a perfect reimplementation. Step 2.3
(precomputed ids) removes this ambiguity for every stage that can use
it, and is the single most valuable change for making the gate
decisive.
