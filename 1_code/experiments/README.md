# experiments

One folder per methods question, keyed `exp_NNN_short_description`.
The same id names the experiment's folders in `2_pipeline/` and
`3_output/`.

**An experiment edits files in its own folder only.**
`1_code/harness/`, `methods/` and `modules/` are the shared back-end;
everything an experiment changes is set in its folder (see
[What an experiment can change](#what-an-experiment-can-change)).

| Folder | Holds | Status |
| --- | --- | --- |
| `_template/` | The `run.R`, `README.md`, `species.csv` and `hooks/` that `new_experiment()` copies | |
| [`exp_000_parity_v2/`](exp_000_parity_v2/README.md) | The v2 parity check and the baseline for every other experiment | Not yet a gate |
| [`exp_001_xgboost/`](exp_001_xgboost/README.md) | Habitat stage fitted with xgboost, every taxon | Test; 5-draw check only |
| [`exp_002_soilgrids/`](exp_002_soilgrids/README.md) | SoilGrids 0–5 cm terms in the climate stage, plants and birds | Test; 5-draw check only |

exp_000 is the required gate before iterative R&D: every other
experiment is compared against its tables.

## An experiment's folder

| File | Holds |
| --- | --- |
| `run.R` | The entry point: loads the framework and the hooks, makes any spec changes, calls `experiment_config()` and `run_experiment()` (see the [harness README](../harness/README.md)) |
| `README.md` | The question, design, result and caveats |
| `species.csv` | The species fitted: `taxon,species,note`, one row each. The template's lists every species a run can fit (1,117); delete the rows not fitted. The rows left also set the runs, so `run.R` needs no `taxa` |
| `hooks/` | Optional. The experiment's own methods (an engine, selection rule, resampler or metric) or functions a spec field names, loaded by `load_framework(hooks = )` |
| `NN_*.R`, `utils/` | Optional. Step scripts, scripts that write inputs to `2_pipeline/<id>/inputs/`, and helpers |

## Adding an experiment

1. Scaffold it from the repository root:

   ```r
   source("1_code/harness/new_experiment.R")
   new_experiment("covariate scale")  # dry_run = TRUE to preview
   ```

   This takes the next free number across `1_code/experiments/`,
   `2_pipeline/` and `3_output/`, copies `_template/` with the id,
   title, author and date filled in, and creates
   `2_pipeline/<id>/logs/` and `3_output/<id>/` with `figures/`,
   `tables/` and a stub `report.md`. Leave `id` and `exp_dir` in
   `run.R` as they are.
2. State the question and design in its `README.md`.
3. Cut `species.csv` down to the species to fit. For a
   like-for-like comparison with exp_000, keep its species
   (`exp_000_parity_v2/species.csv`), draws and seed unless they
   are the question.
4. Change one thing relative to exp_000, in `run.R` or `hooks/`
   (below).
5. Run it at 5 draws to check it works, then at 100. Compare it
   with an exp_000 run at the same number of draws.

## What an experiment can change

All from its own folder:

| To change | Use |
| --- | --- |
| Species, and so the runs | Rows of `species.csv` |
| Regions fitted | `experiment_config(regions = )` |
| Region definitions, grid constants | `modify_region()` on a spec |
| Candidate formulas, added covariates | `stage_models` with `extend_models()`, `models_from_covariates()` or formulas |
| Removed covariates | `stage_models` with `drop_candidates()` or `strip_terms()` |
| Covariates the dataset does not hold | A script that writes them to `2_pipeline/<id>/inputs/`, named in `covariate_files` |
| Engine, selection rule, engine settings | `replace_stage_method()`, or `modify_stage()` |
| Any other stage setting (`ic`, `min_detections`, `scope`, weighting, carrying, `grid_constants`) | `modify_stage()` |
| Resampling scheme and its settings, including spatial block cut points (`long_breaks`, `lat_breaks`) | `modify_resample()` |
| Metrics scored, and those compared with exp_000 | `experiment_config(metrics = , compare_metrics = )` |
| A new engine, rule, resampler or metric | A file in `hooks/` that registers it |
| Per-unit predictions | `experiment_config(unit_predictions = "oob")` |
| Analysis beyond the standard tables | A step script, `steps = list(x = script_step(...))` |

`modify_stage()`, `modify_region()` and `modify_resample()` validate
the spec and record the change, so `run_record.md` says what differs
from v2. Never add columns to `0_data/` or change `_setup/` for an
experiment; `exp_002_soilgrids` is the example of bringing new
covariates.

Each lever is walked through in
[`docs/getting_started.md`](../../docs/getting_started.md#test-a-change).
