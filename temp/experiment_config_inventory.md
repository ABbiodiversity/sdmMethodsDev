# Experiment configuration inventory

Phase 1 of the experiment-configuration work. Read-only scan of
`1_code/harness/`, `1_code/methods/`, `1_code/modules/` (including
`_shared/`), and `1_code/experiments/`, as of commit `afdfe3b`
(branch `development`). `1_code/_setup/` was read only to classify it
as fixed.

**Agreed direction (this session):** keep R configuration
(`experiment_config()` in each `run.R`); no YAML. Each experiment
holds its own species list and its own spec changes. `_shared/`
holds only reference material.

## Summary

Most experiment-variable settings can already be set from an
experiment's own folder: through `experiment_config()` arguments,
`stage_models`, `covariate_files`, a changed `specs` list, or
`steps`. Ten items still need an edit to a shared file. They are
listed as **leaks** in section 4 and marked `LEAK` in the table.

Status key for the "Settable now?" column:

- **cfg**: an `experiment_config()` or `run_experiment()` argument.
- **sm**: the `stage_models` argument.
- **cf**: the `covariate_files` argument.
- **spec**: a changed spec passed as `specs`. Today this means
  `replace_stage_method()`, or a hand edit of the spec list in
  `run.R`. A hand edit works but is not recorded as a change (see
  leak L3).
- **step**: a `steps` script in the experiment folder.
- **LEAK**: can be changed only by editing a shared file.

Line references are `file:line` from the repository root.

## 1. Inventory

### 1.1 Data selection

| Component | Current location | Current value or behaviour | Type | Settable now? | Proposed mechanism | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| Runs (taxa) included | `1_code/harness/experiment.R:69` | `NULL` = every run in `standard_specs()` | list | cfg (`taxa`) | config list | Run names are fixed in `modules/_shared/standard_specs.R:33-45`. |
| Focal species | `1_code/harness/experiment.R:70`, `:162` | Name of a shared set, an inline named vector, or `NULL` for all | list | cfg, but the named sets are shared | Per-experiment `species.csv` (`taxon,species`) | **LEAK L2.** The named sets live in `1_code/experiments/_shared/focal_species.R:32-124`. |
| Named species sets | `1_code/experiments/_shared/focal_species.R:59-122` | `full`, `parity_check`, `plants_only`, `one_each` | list | LEAK | Move each experiment's set into its own `species.csv` | exp_000, exp_001, exp_002, and `_template` all name `parity_check`. |
| Valid species names (reference) | `1_code/harness/species.R:33-66` reads `lookup/species_queue.csv` in the published dataset | One queue for every taxon, region, tier, and season | reference | Read-only | Keep as the shared reference list | Already exists in the data. `resolve_species()` (`species.R:157`) checks names, but only inside `prepare_spec()` (`run_model.R:188`), after configuration. |
| Regions run | `1_code/harness/run_model.R:68`, `:191` | `run_specs(regions = NULL)` = every region in the spec | list | **LEAK** | config list (`regions`) | **L5.** `run_specs()` takes `regions`, but `experiment_config()` and `run_experiment()` (`experiment.R:281-291`) never pass it. |
| Region definition (filters) | `modules/_shared/plant_group.R:98`, `:104`; `modules/birds/spec.R:49`, `:59`; `modules/mammals/spec.R:200-204`, `:221-225` | v2 filters, e.g. `~ nr != "Grassland"`, `~ summer_days > 10 & WetlandMargin != 1` | value (formula) | spec (hand edit) | Spec-change helper (L3) | v2 parity depends on these; changing them is an experiment. |
| Mammal tier | `modules/mammals/spec.R:144` | `"modelled"` | value | spec (`mammal_spec(tier = )`) | Already a module argument | Leave as is. |
| Mammal season | `modules/_shared/standard_specs.R:39-40` | Both seasons, as separate runs | value | cfg (`taxa`) | Already settable | |
| Response definition | `plant_group.R:91` (`"detection"`); `birds/spec.R:39` (`"identity"`); `mammals/spec.R:174` (`mammal_pa_response`) | v2 transforms | value or function | spec (hand edit) | Spec-change helper (L3); a custom function goes in `hooks/` | |
| Mammal abundance winsorizing | `modules/mammals/spec.R:113` | Cap at the 99th percentile | value inside a function | LEAK (in the module) | Keep fixed; to vary it, write a replacement `abundance_response` in `hooks/` | A v2 port. See section 3. |
| Minimum detections to fit a stage | `plant_group.R:167`; harness check at `run_model.R:824-830` | `20L` for the plant habitat stage | value | spec (hand edit) | Spec-change helper | The v2 "20-detection skip". |
| Minimum detections to redraw a bootstrap | `plant_group.R:183`; `mammals/spec.R:272`; used at `methods/resampling/spatial_block.R:131-152` | `20L` | value | spec (hand edit) | Spec-change helper | |
| Data source and version | `1_code/harness/data_source.R:33-38` | Published `test_dataset` and `v2_results`, both `2026-10-05` | value | cfg (`data_dir`); environment variables `SDM_TEST_DATASET` and `SDM_V2_RESULTS` | Keep | Should stay pinned for the team. An experiment can point `data_dir` elsewhere, but its results then don't compare with the baseline. |
| Temporal subsetting (survey years) | none | Not implemented; no year filter exists in the harness | n/a | Possible only through a region `filter` | Spec-change helper on `regions$<r>$filter` | No year-based selection exists today; flagged, not designed. |
| Spatial or temporal thinning | none | Not implemented | n/a | n/a | Out of scope unless asked | Would be a new resampler or a filter, added through `hooks/`. |

### 1.2 Covariates

| Component | Current location | Current value or behaviour | Type | Settable now? | Proposed mechanism | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| Candidate formulas per stage | `1_code/harness/model_sets.R:31-295` (v2 sets); applied by `spec.R:391-421` | v2 sets, spliced verbatim | list | sm (`stage_models`, keyed `stage` or `taxon.stage`) | Already settable | Inline formulas or `extend_models()` work. A new *named* set needs a shared edit to `model_sets.R`; inline avoids that. |
| Added covariate terms | `model_sets.R:318` (`extend_models()`), `:349` (`models_from_covariates()`) | Helpers | function | sm | Already settable | exp_002 is the worked example. |
| Covariates not in the dataset | `harness/data_load.R:388-505` | Extra CSVs keyed on `survey_unit_id` | list | cf | Already settable | Checked at config time (`experiment.R:148-158`). |
| Named covariate groups | `harness/covariate_sets.R:39-72` | `climate_v2`, `topography`, `remote_sensing`, and others | list | Shared registry | Use inline vectors in the experiment | Minor. A new named group needs a shared edit; inline vectors avoid it. |
| Derived covariates | `harness/covariate_sets.R:92` (`derived_covariates()`) | Fixed derivations | function | **LEAK** | Supply derived columns through `covariate_files` | **L9, minor.** A new derivation needs a harness edit. The workaround is a CSV written by an experiment script. |
| Transformations and interactions | Inside formula text | e.g. `I()`, `poly()`, `a:b` | value | sm | Already settable | |
| Buffer radii and scales | none | Fixed by `_setup/` harmonization | n/a | cf (an experiment extracts its own) | Already settable | Fixed in the published dataset by design (memory: `_setup` fixed). |
| Landcover and footprint groupings | `plant_group.R:153-156` (post-process), `:690-693` (`coef_adjust_plant_veg` overlap); `birds/standardize.R` | v2 ports | function | No | Keep fixed | Section 3. |
| Plant Protocol term | `plant_group.R:64-82`, `:137-149` | Fitted for bryophytes and lichens, as v2 | value | spec (`bryophyte_spec(use_protocol = )`) | Already a module argument | Recorded in `notes` and `protocol_is_v2`. |
| Offsets | Bird QPAD offset in formula (`run_model.R:723-726`); `birds/spec.R:88` `carry_offset = FALSE` | v2 | value | spec (hand edit) | Keep fixed | Section 3 (memory: bird climate carry has no offset). |
| Region-level held constants | `plant_group.R:109` (`paspen = 0`); `mammals/spec.R:234`, `:262` (`seas_days = 100`, `Climate = 0`) | v2 | value | spec (hand edit) | Spec-change helper | They change what the grid predictions mean; record it if changed. |

### 1.3 Model structure

| Component | Current location | Current value or behaviour | Type | Settable now? | Proposed mechanism | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| Engine per stage | `plant_group.R:117`, `:130` (`bayesglm`); `birds/spec.R:74`, `:94` (`glm`); `mammals/spec.R:157`, `:242` (`glm`) | v2 | value (registry name) | spec (`replace_stage_method(engine = )`) | Already settable | exp_001 is the worked example. |
| Built-in engines | `1_code/methods/engines/` | `glm`, `bayesglm`, `xgboost` | registry | Shared | Experiment-local `hooks/` | **LEAK L1.** A new engine has to go in `methods/`. |
| Engine settings (`control`) | `plant_group.R:120`, `:133` (`maxit = 250`); `methods/engines/bayesglm.R:50-51` (default 250); `methods/engines/xgboost.R:78-81` | v2 and untuned xgboost defaults | list | spec (`replace_stage_method(control = )`) | Already settable for a replaced stage; spec-change helper otherwise | xgboost's own `seed = 20260909L` (`xgboost.R:81`) is separate from the experiment seed. See section 5. |
| Selection rule per stage | `plant_group.R:118` (`aic_average`), `:131` (`ivw_grid`); `birds/spec.R:75`, `:95` (`staged_bic`); `mammals/spec.R:244-245` (`hurdle`, `aic_best`) | v2 | value (registry name) | spec (`replace_stage_method(selection = )`) | Already settable | |
| Built-in selection rules | `1_code/methods/selection/` | `aic_average`, `aic_best`, `hurdle`, `ivw_grid`, `single`, `staged_bic` | registry | Shared | `hooks/` | **LEAK L1.** |
| Information criterion | `plant_group.R:119`, `:132`; `birds/spec.R:76`, `:96`; default `run_model.R:757` | `AICc`, or `BIC` for the bird landcover stage | value | spec (hand edit) | Spec-change helper | Validated against `AIC`, `AICc`, and `BIC` (`spec.R:207-210`). |
| Rule settings | `methods/selection/staged_bic.R:37` (`threshold = 2`, `always_advance`); `ivw_grid.R:50` (`head_terms`); `hurdle.R:64-69` | v2 | value | spec (hand edit; stage fields named like rule arguments) | Spec-change helper | `validate_spec()` already accepts rule arguments as stage fields (`spec.R:160-162`). |
| Hierarchy (climate stage carried into habitat) | `carry_as`, `carry_from`, `carry_scale`, `carry_offset` in each spec; `run_model.R:884-907` | v2: province climate carried as `Climate` | value | spec (hand edit) | Spec-change helper | Structural. Changing it is a real experiment; record it. |
| Stage scope (province or region) | `plant_group.R:122`; `birds/spec.R:78`; logic at `run_model.R:364-412` | v2 | value | spec (hand edit) | Spec-change helper | |
| Weighting | `birds/spec.R:56`, `:65`, `:79`; `mammals/spec.R:188`; `run_model.R:834-839` | v2 | value | spec (hand edit) | Spec-change helper | |
| Error family | `plant_group.R:92`; `birds/spec.R:40`; `mammals/spec.R:187`, `:256` | v2 | value | spec (hand edit) | Spec-change helper | |
| Post-processing (v2 ports) | `plant_group.R:153-156`; `mammals/spec.R:266` | v2 | function list | Removed by `replace_stage_method()` | Keep fixed | Section 3. |
| Mammal climate source | `mammals/spec.R:142` | `"precomputed"` (v2) | value | spec (`mammal_spec(climate_source = )`) | Already a module argument | |
| Plant bootstrap source | `harness/experiment.R:76` | `"spatial_block"`; `"v2_ids"` replays v2's draws | value | cfg (`plant_bootstrap`) | Already settable | |

### 1.4 Evaluation

| Component | Current location | Current value or behaviour | Type | Settable now? | Proposed mechanism | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| Resampling scheme | `plant_group.R:174-186`; `birds/spec.R:106-113`; `mammals/spec.R:270-274`; dispatch at `harness/resample.R:186-209` | `spatial_block` (plants, mammals); `precomputed` (birds) | value (registry name) | spec (hand edit) | Spec-change helper | `spatial_cv` is registered (`methods/resampling/spatial_cv.R`). |
| Built-in resamplers | `1_code/methods/resampling/` | `precomputed`, `spatial_block`, `spatial_cv` | registry | Shared | `hooks/` | **LEAK L1.** |
| Number of draws or folds | `harness/experiment.R:71`; `spatial_cv.R:92` (folds = `length(iterations)`) | 100 | value | cfg (`n_bootstraps`) | Already settable | For `spatial_cv`, `n_bootstraps` is the fold count. |
| Spatial block cut points | `harness/resample.R:143-144` | Longitude `-121, -116, -112, -109`; latitude `48, 51, 54, 57, 61` (v2 plant grid) | value | **LEAK** | Resample setting (`long_breaks`, `lat_breaks`) passed through the resampler | **L6.** Neither `resampler_spatial_block()` (`spatial_block.R:124-128`) nor `resampler_spatial_cv()` (`spatial_cv.R:87-90`) passes breaks, so the block size for CV can't be changed. |
| Redraw attempts | `spatial_block.R:127` | `max_attempts = 100L` | value | spec (hand edit of `resample`) | Spec-change helper | |
| Seed | `harness/experiment.R:72`; `resample.R:35-37`, `:59-76` | `20260909L`, per-species derived | value | cfg (`seed`) | Already settable | |
| Metrics computed | `harness/eval_metrics.R:34-42`; `run_model.R:71` | Every registered metric | list | **LEAK** | config list (`metrics`) | **L5.** `run_specs(metrics = )` exists but isn't passed from `experiment_config()`. |
| Built-in metrics | `1_code/methods/metrics/` | `auc`, `calibration_slope`, `deviance_explained`, `n`, `prevalence`, `rmse`, `spearman` | registry | Shared | `hooks/` | **LEAK L1.** |
| Metric direction ("better") | `harness/compare.R:38-46` | Hard-coded by name; anything unknown is "higher" | function | **LEAK** | Declare direction when registering a metric | **L7.** A hook metric where lower is better would be reported backwards. |
| Comparison metrics | `harness/compare.R:97-100`; console headline at `harness/experiment.R:488-490` | Five `oob_` metrics; headline shows three | list | **LEAK** | config list (`compare_metrics`) | **L7.** |
| Comparison baseline | `harness/experiment.R:79` | `"exp_000_parity_v2"` | value | cfg (`baseline`) | Already settable | |
| Summary statistics | `harness/summarise.R:178-179` | median and 10-90% band | value | No | Keep fixed | Every comparison and gate reads these; changing them breaks comparability. |
| v2 validation AUCs (plants) | `plant_group.R:233`; `run_model.R:1065-1075` | `plant_v2_validation` | function | Dropped by `replace_stage_method()` | Keep fixed | Section 3. |
| Parity thresholds | `experiments/exp_000_parity_v2/utils/parity_targets.R:80-88` | 1e-6, 90%, 0.25, 0.75 to 1.33 | value | Already experiment-local | n/a | Good existing pattern. |
| Coefficient translation (birds) | `harness/experiment.R:271`; template `run.R:78-81` | `translate = list(bird = bird_habitat_translation)` | function | cfg (`run_experiment(translate = )`) | Already settable | exp_001 omits it, which is correct for xgboost (no coefficients). |

### 1.5 Prediction

| Component | Current location | Current value or behaviour | Type | Settable now? | Proposed mechanism | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| Prediction grid | `plant_group.R:99`, `:105`; `birds/spec.R:52`, `:62`; `mammals/spec.R:205`, `:226`; loader `harness/predict_grid.R:35-64` | One habitat-type grid per region, read only from `<data_dir>/lookup/` | value | spec, but only grids already in the dataset | **LEAK** if an experiment needs its own grid | **L8.** The loader can't read a grid from the experiment folder or `2_pipeline/<id>/inputs/`. Spatial prediction is deferred (memory), so this is flagged, not designed. |
| Grid rows and columns dropped | `mammals/spec.R:208-209`, `:227` | v2 | value | spec (hand edit) | Spec-change helper | |
| Grid constants (current or reference scenario) | `plant_group.R:109`, `:137-144`; `mammals/spec.R:262` | `Climate = 0`, `paspen = 0`, `Protocol = "New"`, `seas_days = 100` | value | spec (hand edit) | Spec-change helper | The closest thing to a "scenario" today. |
| Resolution, extent, spatial maps | none | Not implemented (habitat-type grids only) | n/a | n/a | Out of scope | Deferred (memory: spatial prediction deferred). |
| Per-unit predictions written | `harness/experiment.R:78` | `"none"` | value | cfg (`unit_predictions`) | Already settable | |

### 1.6 Run control

| Component | Current location | Current value or behaviour | Type | Settable now? | Proposed mechanism | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| Workers | `harness/experiment.R:77` | `1L` (experiments set 12) | value | cfg (`workers`) | Already settable | |
| Worker start-up | `harness/run_model.R:505-516` (`load_worker()`) | Each worker sources the framework only | code path | n/a | Also source the experiment's `hooks/` | **L1 blocker.** Without this, a hook method registered in the main session is unknown to the workers. |
| Fit or re-summarize | `harness/experiment.R:269` | `fit = TRUE` | value | cfg (`run_experiment(fit = )`) | Already settable | |
| Extra stages (steps) | `harness/experiment.R:270`, `:522-539` | `script_step()` runs scripts from the experiment folder | function | step | Already settable | |
| Output paths | `harness/experiment.R:82-84`, `:203-205` | `2_pipeline/<id>/`, `3_output/<id>/` | value | cfg | Already settable | |
| Run record | `harness/run_record.R:171-290`; `experiment.R:354-410` | Settings, coverage, metrics; provenance holds short commit, R version, time | function | Fixed | Add session info, full commit and dirty flag, and hook files | **L4.** |
| Scaffolding | `harness/new_experiment.R:135`, `:278` | Copies every file in `_template/` and fills placeholders | function | n/a | Template gains `species.csv` and `hooks/` | Copies recursively, so new template files are picked up without a code change. Check the placeholder fill on a CSV. |
| Which stages run | Spec `stages` list | All stages | list | spec (hand edit) | Spec-change helper | e.g. dropping the climate stage. |

## 2. Values that look variable but should stay fixed

| Item | Location | Why fixed |
| --- | --- | --- |
| Data cleaning and harmonization | `1_code/_setup/` | Defines the frozen v2 test dataset that every experiment and the baseline share. Experiments add data through `covariate_files` (memory: `_setup` fixed). |
| Published dataset versions | `harness/data_source.R:33-38` | Pinned so every experiment reads the same data. Change only as a maintainer release. |
| v2 candidate formulas | `harness/model_sets.R:31-295` | Verbatim v2 record. Experiments replace them through `stage_models` and don't edit them. |
| Bird climate `carry_offset = FALSE` and `carry_scale = "exp"` | `modules/birds/spec.R:86-88` | Matches how v2 carries `exp(link)` without the QPAD offset. Verified against v2 (memory: bird climate carry has no offset). |
| Plant post-processing (age splines, cutblock convergence, pAspen, footprint pooling, overlap constants, cutblock recovery weights) | `modules/_shared/plant_group.R:153-156`, `:379-1027` | Ports of v2 code, checked to 2e-12. They are part of the v2 model, not tuning knobs. |
| Mammal hurdle tables, lure ratio, 99% winsorizing, spline settings, held constants | `modules/mammals/hurdle.R`; `mammals/spec.R:113` | Ports of v2, matched to 2e-14. |
| Bird habitat translation | `modules/birds/standardize.R` | Port of v2's `08.PackageCoefficients.R`, checked exact. |
| Summary statistics (median, 10-90% band) | `harness/summarise.R:178-179` | Every comparison and gate reads them. |
| Metric definitions | `methods/metrics/*.R` | A changed definition breaks comparison with every past run. Add a new metric; don't redefine one. |
| Per-species seed derivation | `harness/resample.R:59-76` | Keeps draws stable when species are added or removed, and parallel equal to serial. |
| Iteration 1 = full data | `methods/resampling/spatial_block.R:79-81` | v2 behaviour; the comparison reads `boot1`. |
| Registry contracts (core arguments) | `harness/registry.R:152-279` | The interface hooks implement; changing them breaks every method. |

## 3. Hard-coded items in `modules/` and `_shared/`

Taxon leads own these files. The table lists what an experiment
could reasonably want to vary, and whether that is possible without
editing the module.

| Item | Location | Possible without a module edit? | How |
| --- | --- | --- | --- |
| Region filters | `plant_group.R:98`, `:104`; `birds/spec.R:49`, `:59`; `mammals/spec.R:200-225` | Yes | Change the spec in the experiment (spec-change helper) |
| Engine, rule, IC, `control` | All spec files | Yes | `replace_stage_method()` or spec-change helper |
| `min_detections` (stage and resample) | `plant_group.R:167`, `:183`; `mammals/spec.R:272` | Yes | Spec-change helper |
| Resampling scheme | All spec files | Yes | Spec-change helper on `resample` |
| Grid constants | `plant_group.R:109`, `:137-144`; `mammals/spec.R:234`, `:262` | Yes | Spec-change helper |
| Protocol term (plants) | `plant_group.R:45`, `:64-82` | Yes | Module argument `use_protocol` |
| Mammal climate source, tier | `mammals/spec.R:142-144` | Yes | Module arguments |
| Mammal winsorizing cap (0.99) | `mammals/spec.R:113`, inside `mammal_agp_response()` | Only by replacing the function | A replacement `abundance_response` in `hooks/`, set with the spec-change helper |
| Plant post-process constants | `plant_group.R:690-693`, `:1009` | Only by replacing the function | A replacement `post_process` in `hooks/`. Not expected; these are v2. |
| `standard_specs()` run list | `modules/_shared/standard_specs.R:33-45` | Yes | Pass a custom `specs` list |
| Named species sets | `experiments/_shared/focal_species.R:32-124` | No | **L2.** Moves to each experiment's `species.csv`. |

No module needs to change to accept configuration. Every module
setting above can already be overridden on the spec object the
module returns. What's missing is a tidy, recorded way to do it
(L3). **Expected module changes in Phase 4: none.**

## 4. Leaks, confirmed or corrected

The four leaks from the plan, plus six more found in the scan.

| # | Leak | Status | Shared file a user would edit today | Fix direction for Phase 2 |
| --- | --- | --- | --- | --- |
| L1 | New engine, rule, resampler, or metric | **Confirmed** | `1_code/methods/` | `hooks/*.R` in the experiment, registered with the existing `register_*()` functions. Also sourced in workers (`run_model.R:505-516`); today a method registered in the main session is missing from the workers. |
| L2 | Species selection | **Confirmed** | `experiments/_shared/focal_species.R` | Per-experiment `species.csv`. The shared reference list already exists as the dataset's `lookup/species_queue.csv`, read by `species_catalogue()`, so no new shared file is needed. Check names at config time rather than at `prepare_spec()`. |
| L3 | Spec changes other than a method swap | **Corrected: possible but unrecorded** | None strictly. Users can edit the spec list in `run.R`, but nothing documents it, it isn't recorded by `experiment_changes()`, and editing the module is the obvious path | `modify_stage()` / `modify_spec()` helpers that set fields, run `validate_spec()`, and append to `models_overridden`. |
| L4 | Provenance lacks session info and hooks | **Confirmed** | `harness/run_record.R:196-218` (harness, not a user edit) | Add session info, full commit, dirty flag, and hook files and checksums. |
| L5 | Regions and metrics subsets | **New** | `harness/experiment.R` | Pass `regions` and `metrics` through `experiment_config()` to `run_specs()`, which already accepts them. |
| L6 | Spatial block cut points | **New** | `harness/resample.R:143-144` | Let `spatial_block` and `spatial_cv` accept `long_breaks` and `lat_breaks` as `resample` settings, with the current values as defaults. This is a `methods/` change, not a module change. |
| L7 | Comparison metrics and metric direction | **New** | `harness/compare.R:38-46`, `:97-100`; `experiment.R:488-490` | Optional `direction` on `register_metric()`, defaulting to today's table; `compare_metrics` in config. |
| L8 | Experiment-supplied prediction grid | **New, deferred** | `harness/predict_grid.R:35-64` | Flag only. Spatial prediction is deferred. |
| L9 | New derived covariates | **New, minor** | `harness/covariate_sets.R:92` | Already possible through `covariate_files`; document it, no code. |
| L10 | Named model or covariate sets | **New, minor** | `harness/model_sets.R`, `harness/covariate_sets.R` | Already possible inline; document it, no code. |

## 5. Issues noticed (not fixed)

1. **xgboost seed is not the experiment seed.**
   `methods/engines/xgboost.R:81` defaults `seed = 20260909L`, so
   changing the experiment's `seed` doesn't change xgboost's
   subsampling or validation split.
2. **Species names are checked late.** Names are checked in
   `prepare_spec()` (`run_model.R:188`), after the config prints,
   rather than in `experiment_config()`. With 12 workers that is
   still before any fitting, but the error appears later than other
   config errors.
3. **`validate_spec()` runs late.** It runs only in `prepare_spec()`
   (`run_model.R:176`), not in `experiment_config()`. A bad spec
   passed through `specs` is caught at run start, not at config time.
4. **`spatial_cv` reports out-of-bag metrics under the `oob_`
   prefix**, the same as bootstrap out-of-bag rows. Comparing a
   spatial-CV experiment with the bootstrap baseline mixes two kinds
   of hold-out. This is a comparability caveat, not a bug.
5. **`run_record` shows `boot_seed` as `20260909.0000`**, because
   `fmt_value()` formats a double seed with four decimals. This is
   cosmetic.
6. **`1_code/_scratch.R` is tracked.** It is outside the experiment
   structure. Not checked further.

## 6. README and vignette sections that will need updating later

These are listed only; Phase 4 won't edit them.

- `1_code/experiments/README.md`: the `_shared/` row, and "Adding an
  experiment" steps 1-3 (species file, hooks, spec changes).
- `1_code/harness/README.md`: the `experiment_config()` argument
  table (new arguments), and the Files table if new helpers are
  added.
- `1_code/methods/README.md`: a note that experiment-local methods
  go in `hooks/`, and the metric `direction` field if added.
- `docs/getting_started.md`: around lines 237-250 (`species` and
  `focal_species_sets()`), plus the "test a change" walkthroughs.
- `docs/example_experiment.md` (line 235) and
  `docs/example_experiment_xgboost.md` (line 244):
  `species = "parity_check"`.
- `1_code/tests/README.md` line 22: the `parity_check` reference.
- exp_000, exp_001, exp_002 `README.md`: species rows in the design
  tables.
