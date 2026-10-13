# harness

The shared pipeline. It names no taxon and no method: taxon modules
supply specs, `methods/` supplies what the specs name, and the harness
runs them. A change here affects every experiment, past and future;
review it as such and check it with [`1_code/tests/`](../tests/).

Load everything with:

```r
source("1_code/harness/harness.R")
load_framework()  # harness/, methods/, modules/

# An experiment also loads its own methods from hooks/
load_framework(hooks = "1_code/experiments/<id>/hooks")
```

Experiments never edit this folder. Everything an experiment
changes is an `experiment_config()` argument, a spec change made in
its `run.R`, or a function in its `hooks/` (see the
[experiments README](../experiments/README.md)).

`new_experiment.R` is the exception: it is base R and runs without
`load_framework()`.

## Files

| File | Holds |
| --- | --- |
| `harness.R` | `load_framework()`: sources the harness, methods and modules, then an experiment's hooks (`load_hooks()`); workers load the same hooks |
| `experiment.R` | `experiment_config()` (checks everything, lists every problem at once), `run_experiment()`, `script_step()`, `runs_for_species()` |
| `new_experiment.R` | `new_experiment()`: scaffold an experiment's three folders |
| `data_source.R` | The pinned published dataset versions; `test_dataset_dir()`, `v2_results_dir()`, `verify_published()` |
| `data_load.R` | `lookup/dataset_manifest.csv`, loaders, `covariate_files` joins, model frames; `covariate_columns_needed()` |
| `cache.R` | Session cache for dataset reads |
| `covariate_sets.R` | Named covariate sets, derived columns, term renaming |
| `model_sets.R` | v2 candidate formulas, spliced verbatim; `extend_models()` and `models_from_covariates()` to add or build, `drop_candidates()` and `strip_terms()` to reduce |
| `spec.R` | `validate_spec()`, `apply_stage_models()`, `replace_stage_method()`; `modify_stage()`, `modify_region()`, `modify_resample()` for an experiment's spec changes; `check_spec_covariates()` |
| `registry.R` | `register_engine()` and the other `register_*()` (metrics take a `direction`); `list_methods()`. A hook may not reuse a registered name |
| `engines.R` | Engine interface and `check_engine()` |
| `selection.R` | Plumbing for selection rules: `fit_candidates()`, `combined_predictor()`, `selection_result()` |
| `resample.R` | Per-species seeds, `with_seed()`, spatial blocks; `v2_block_breaks()` |
| `species.R` | Species lists; `read_species_file()` and `check_species_names()` for an experiment's `species.csv` |
| `predict_grid.R` | Projects a final model onto a habitat grid |
| `eval_metrics.R` | Scores a prediction with every registered metric |
| `run_model.R` | `run_specs()`: prepare each spec, fit species in parallel, merge shards; `region_request()` and `province_request()`, shared with the configuration check |
| `result.R` | The result store: writes and reads its files |
| `summarise.R` | `collect_results()`: stores to summary tables |
| `compare.R` | `compare_experiments()`: one experiment against another; `default_compare_metrics()` |
| `run_record.R` | `run_record()`: writes `run_record.md`, with provenance |

## What `run_experiment()` does

1. **Configure.** `experiment_config()` checks every decision before
   anything is fitted, and stops once with every problem listed:
   species names (with close matches), runs, draws, regions,
   metrics, each spec, and every covariate the formulas name.
2. **Fit.** Every spec is validated and each region's data and grid
   are loaded once. Each species is one job; with `workers` above 1,
   jobs run in parallel R sessions. Each species draws under its own
   seed, so results do not depend on the worker count. A failed
   species or draw is logged and the run continues.
3. **Store.** Shards are merged into one store per run and region in
   `2_pipeline/<id>/`, plus `run_log.csv` and `session_info.txt`.
4. **Summarize.** `collect_results()` writes `3_output/<id>/tables/`.
5. **Compare.** Every experiment except the baseline writes
   `tables/comparison_metrics.csv` against exp_000.
6. **Steps.** The experiment's own `steps`, in order.
7. **Record.** `run_record.md`.

`run_experiment(config, fit = FALSE)` re-summarizes existing stores.
Nothing outside `2_pipeline/<id>/` and `3_output/<id>/` is written.

## `experiment_config()` arguments

| Argument | Default | Sets |
| --- | --- | --- |
| `id` | | Folder name under `2_pipeline/` and `3_output/` |
| `taxa` | see note | Runs, from `names(standard_specs())`. Left out with a species list: only the runs that fit a listed species (a `Moose_Summer` row runs `mammal_summer`). Left out with no species list: every run |
| `species` | every species | The experiment's `species.csv` (`taxon,species,note`), or a vector named by taxon. Names are checked against the dataset's species queue |
| `n_bootstraps` | `100` | Draws per species; v2 used 100. 5 checks a run works |
| `seed` | `20260909` | Base seed; `NULL` leaves draws unseeded, as v2 did |
| `stage_models` | v2's | Replacement candidate sets, keyed `stage` or `taxon.stage` |
| `covariate_files` | none | CSVs of extra covariates keyed on `survey_unit_id` |
| `specs` | `standard_specs()` | Changed specs, such as a different engine or rule |
| `plant_bootstrap` | `"spatial_block"` | `"v2_ids"` replays v2's stored plant draws |
| `workers` | `1` | Species fitted at once |
| `unit_predictions` | `"none"` | `"oob"` or `"all"` writes per-unit predictions |
| `baseline` | `"exp_000_parity_v2"` | Experiment to compare with; `NULL` skips |
| `v2_bootstraps` | `100` | Draws a run needs to be gated |
| `regions` | all | Regions to fit, e.g. `"north"` |
| `metrics` | all registered | Metrics scored per draw |
| `compare_metrics` | `default_compare_metrics()` | Prefixed metrics (e.g. `"oob_auc"`) compared with the baseline |
| `project_root`, `data_dir`, `pipeline_dir`, `out_dir` | derived | Path overrides |

## Outputs

A *draw* is one bootstrap iteration; draw 1 is the full data. Every
summary reduces draws to `median`, `p10` and `p90` (what comparisons
read), plus `mean`, `sd`, `n` and `boot1` (the draw-1 value).

### Result stores: `2_pipeline/<id>/<run>/<region>/`

| File | Holds |
| --- | --- |
| `coefficients.csv` | Every stage's coefficients per species, draw and term |
| `metrics.csv` | Metrics per species and draw |
| `grid_predictions.csv` | The final model's prediction for each habitat type |
| `unit_predictions.csv` | Only with `unit_predictions = "oob"` or `"all"`; several GB for birds |
| `meta.json` | Stages, engines, rules, covariates, resampling, seed, overrides, hook files |

`2_pipeline/<id>/run_log.csv` records every species, region and draw:
`ok`, or why not. `2_pipeline/<id>/session_info.txt` holds the full
`sessionInfo()` of the run.

`3_output/<id>/run_record.md` is the committed record. Its
Provenance section gives the full git commit, how many files under
`1_code/` differ from it, R version, platform, modelling package
versions, and each hook file with its md5. Its Configuration
section gives every setting, the species file, the hooks, and each
change from v2.

### Summary tables: `3_output/<id>/tables/`

| File | One row per | Notes |
| --- | --- | --- |
| `coverage.csv` | run × region | Species, draws and stages written; `species = 0` means nothing ran (see `run_log.csv`) |
| `metric_summary.csv` | taxon × region × species × metric | Prefixes: `insample_`, `oob_` (held-out; NA for draw 1), `v2val_` and `oob_v2val_` (v2's seven plant validation AUCs) |
| `grid_summary.csv` | taxon × region × species × `grid_unit` | Response scale; pure stand at the stage's constants (`Climate` 0) |
| `coefficient_summary.csv` | run × region × stage × species × term | Gitignored. Term meaning varies by taxon and stage |
| `comparison_metrics.csv` | species × metric | Against exp_000; both sides' summaries, the difference, and whether this run did better. Gitignored |

Metrics: `auc`, `deviance_explained`, `rmse`, `spearman`,
`calibration_slope`, `prevalence`, `n`. They score each run's final
model, so for plants `insample_auc` equals `v2val_Full`. "Better" is
higher AUC, deviance explained and Spearman, lower RMSE, and a
calibration slope closer to 1.

## Data access

Runs read the published dataset versions pinned in `data_source.R`
(`sdm_published$versions`), on `//ABMI-DATA2/science/sdmMethodsDev/0_data/`.
Set `SDM_TEST_DATASET` or `SDM_V2_RESULTS` to read another copy. Each
call checks file presence and size; `verify_published()` checks md5.
