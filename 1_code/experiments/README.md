# experiments

One folder per methods question, keyed `exp_NNN_short_description`.
Each folder has a `run.R` entry point that calls `experiment_config()`
and `run_experiment()` (see the [harness README](../harness/README.md)),
and a `README.md` stating the question. The same id names the
experiment's folders in `2_pipeline/` and `3_output/`.

| Folder | Holds | Status |
| --- | --- | --- |
| `_shared/` | `focal_species.R`: `focal_species_sets()`, the named species sets (`full`, `parity_check`, `plants_only`, `one_each`) | |
| `_template/` | The `run.R` and `README.md` that `new_experiment()` fills in | |
| [`exp_000_parity_v2/`](exp_000_parity_v2/README.md) | The v2 parity check and the baseline for every other experiment | Not yet a gate |
| [`exp_001_xgboost/`](exp_001_xgboost/README.md) | Habitat stage fitted with xgboost, every taxon | Test; 5-draw check only |
| [`exp_002_soilgrids/`](exp_002_soilgrids/README.md) | SoilGrids 0–5 cm terms in the climate stage, plants and birds | Test; 5-draw check only |

exp_000 is the required gate before iterative R&D: every other
experiment is compared against its tables.

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
   `tables/` and a stub `report.md`. Leave `id` in `run.R` as it is.
2. State the question and design in its `README.md`.
3. Change one thing relative to exp_000: `stage_models`,
   `covariate_files` or `specs`. Keep exp_000's species, draws and seed
   unless they are the question.
4. Never add columns to `0_data/` or change `_setup/` for an
   experiment. Covariates the dataset lacks are written by a script in
   the experiment's folder to `2_pipeline/<id>/inputs/` and named in
   `covariate_files`; `exp_002_soilgrids` is the example.
5. Run it at 5 draws to check it works, then at 100. Compare it with
   an exp_000 run at the same number of draws.

Each lever is walked through in
[`docs/getting_started.md`](../../docs/getting_started.md#test-a-change).
