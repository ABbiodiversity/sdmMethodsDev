# Experiment configuration design

Phase 2 of the experiment-configuration work. It builds on the
existing R API and closes the leaks found in
`temp/experiment_config_inventory.md`.

**Status: approved and implemented** (uncommitted, on `development`).
This document now describes the code as built. Section 15 lists what
changed after approval and why; section 12 gives the verification
results.

## Decisions already made

| Decision | Source |
| --- | --- |
| Configuration stays in R: `experiment_config()` in each `run.R`. No YAML. | Session, option A |
| Each experiment holds its own species list in its own folder. | Session |
| The shared reference for valid species names is the dataset's `lookup/species_queue.csv`; no new shared file. | Phase 1 review, answer 2 |
| `focal_species_sets()` and `experiments/_shared/focal_species.R` are removed. | Phase 1 review, answer 3 |
| Users can change, from their own experiment: methods (L1), species (L2), any spec setting (L3), regions and metrics (L5), spatial block cut points (L6), and comparison metrics and metric direction (L7). | Phase 1 review, answer 1 |
| L8 (an experiment-supplied prediction grid) is not designed. Spatial prediction is deferred. | Memory; inventory |
| L9 and L10 (derived covariates, named sets) need documentation only. | Inventory |
| The template's `species.csv` lists every species a run can fit, as `taxon,species,note` with empty notes; an experiment deletes the rows it doesn't fit. | After implementation (section 15) |
| Without `taxa`, the species list sets the runs, so users edit `species.csv` alone. | After implementation (section 15) |

## The rule this design enforces

> A user edits files in `1_code/experiments/<exp_id>/` only.
> Everything else is the fixed back-end. Anything an experiment can
> change is either an argument to `experiment_config()`, a change to
> a spec made in `run.R`, or a function in the experiment's `hooks/`.

## 1. Experiment folder layout

```
1_code/experiments/exp_NNN_short_description/
  run.R          # entry point: load, configure, run
  README.md      # question, design, status, result
  species.csv    # the species this experiment fits; also sets the runs
  hooks/         # optional: the experiment's own methods (*.R)
  NN_*.R         # optional: step scripts and input builders
  utils/         # optional: helpers only this experiment uses
```

`run.R` keeps its current numbered sections, with one section per
kind of decision so a reviewer can find each change quickly:

```r
# 1. Setup ----
## 1.1 Load the framework and this experiment's hooks ----
exp_dir <- "1_code/experiments/exp_NNN_short_description"
source("1_code/harness/harness.R")
load_framework(hooks = file.path(exp_dir, "hooks"))

## 1.2 Spec changes ----
# What this experiment changes in the v2 specs, if anything
specs <- standard_specs()
specs$lichen <- modify_stage(specs$lichen, "habitat", ic = "BIC")

## 1.3 Configure the run ----
config <- experiment_config(
  id = "exp_NNN_short_description",
  specs = specs,
  # Sets the species and, with no `taxa`, the runs
  species = file.path(exp_dir, "species.csv"),
  ...
)

# 2. Run ----
results <- run_experiment(config, ...)
```

**`species.csv`**: columns `taxon`, `species` and `note`, one row
per species. `taxon` is the data slug (`bryophyte`, `lichen`,
`mite`, `vascular_plant`, `mammal`, `bird`), as in the former named
vectors. Mammal species carry their season (`Moose_Summer`). `note`
is free text (why a species was chosen) and is ignored by the
harness; other extra columns are ignored too.

- **The template's file lists every species a run can fit** (1,117
  of the 1,140 in the dataset's species queue), sorted
  alphabetically within each taxon, with empty notes. A new
  experiment deletes the rows it doesn't fit. The 23 mammals left
  out are in the `ua` tier only, which no mammal run fits.
- **The rows left set the runs.** When `run.R` passes no `taxa`,
  `experiment_config()` runs only the runs that fit a listed
  species (`runs_for_species()`): a `Moose_Summer` row runs
  `mammal_summer` but not `mammal_winter`. Users edit
  `species.csv` alone.
- **Given `taxa` still wins.** exp_000, exp_001 and exp_002 pass
  `taxa`, so they run exactly as before. A run in `taxa` whose
  taxon has no rows fits every species of that taxon, with a note
  saying so; leaving `taxa` out avoids it.
- **Every species, deliberately:** `species = NULL` and no `taxa`
  runs every run on every species, with no file.

**Alternatives considered**

- *Spec changes in a separate `specs.R` that `run.R` sources.* This
  is cleaner for a large change, but adds a second file for the
  common one-line case. The design allows it (users may add any
  file to their folder) but doesn't require it.
- *`config.R` holding a list, read by a generic runner.* Rejected:
  `run.R` already is that, and a second layer adds no isolation.

## 2. Defaults

The defaults stay where they are, and the design states that they
are the defaults file:

- `experiment_config()` argument defaults (`harness/experiment.R`)
  hold the run-level v2 defaults: seed, draws, plant bootstrap,
  baseline, and the new arguments below, each defaulting to today's
  behaviour.
- `standard_specs()` (`modules/_shared/standard_specs.R`) and the
  taxon spec functions hold the model-level v2 defaults.

An experiment passes only what it changes. An argument left out
falls back to the default, so exp_000 needs no overrides beyond its
`id`, `taxa`, `species`, `n_bootstraps`, and `workers`. (A new
experiment needs no `taxa` either; see section 1.)

**New `experiment_config()` arguments**, all defaulting to today's
behaviour:

| Argument | Default | Sets | Closes |
| --- | --- | --- | --- |
| `species` | `NULL` | Now also a path to a `species.csv`. Inline named vectors still work. Set names (`"parity_check"`) no longer exist. | L2 |
| `taxa` (new meaning when `NULL`) | `NULL` | With a species list: only the runs that fit a listed species. Without one: every run, as before. | Section 15 |
| `regions` | `NULL` (every region each spec defines) | Regions to fit, e.g. `"north"` | L5 |
| `metrics` | `NULL` (every registered metric) | Metrics scored per draw | L5 |
| `compare_metrics` | `NULL` (today's five `oob_` metrics) | Metrics in `comparison_metrics.csv` and the console headline | L7 |

The hook files are not an `experiment_config()` argument. They have
to be loaded before specs are built (a spec can name a hook engine),
so they go to `load_framework()`. `experiment_config()` reads them
from the session and records them.

**Alternative considered:** *a separate `harness/defaults.R` list
merged with overrides.* Rejected. It would duplicate the argument
defaults and the spec functions, and the two copies could drift. R
function defaults already give "specify only what changes" and are
documented in one roxygen block. **This departs from common practice**
in projects built on the `config` package, which keep defaults in a
YAML `default:` block. It suits this team, who write R and whose
settings include formulas and functions.

## 3. Swappable components: registry and hooks

### 3.1 The registry (unchanged)

Built-in methods stay in `1_code/methods/` and are selected by name
in a spec or a config. The registry already has four kinds:

| Kind | Built-in names | Selected by |
| --- | --- | --- |
| engine | `glm`, `bayesglm`, `xgboost` | stage `engine` |
| selection | `aic_average`, `aic_best`, `hurdle`, `ivw_grid`, `single`, `staged_bic` | stage `selection` |
| resampler | `precomputed`, `spatial_block`, `spatial_cv` | spec `resample$scheme` |
| metric | `auc`, `calibration_slope`, `deviance_explained`, `n`, `prevalence`, `rmse`, `spearman` | config `metrics` (new) |

`list_methods()` prints them.

### 3.2 Hooks

A hook is an R file in the experiment's `hooks/` folder. It does
either or both of the following:

1. Registers a method with the existing `register_engine()`,
   `register_selection()`, `register_resampler()`, or
   `register_metric()`.
2. Defines a plain function that a spec field names, such as a
   `response_transform`, `row_filter`, `post_process`, or mammal
   `abundance_response`. These functions are set with
   `modify_stage()` (section 4).

**Loading.** `load_framework(project_root = ".", hooks = NULL)`
gains a `hooks` argument: a folder, or a vector of `.R` files. After
the harness, methods, and modules load, it sources every `.R` file
in the folder in file-name order. It stores the normalized paths in
`options(sdm.hook_files = ...)`. `run_jobs()` passes those paths to
each worker, and `load_worker()` sources them after its own
`load_framework()`. Without that, a method registered in the main
session is unknown in a parallel run (inventory, L1).

**Clash rule.** While hooks are loading, registering a name that is
already registered is an error naming the file and the existing
method. A hook can't silently replace a built-in, which would change
every other experiment's meaning of that name within the session.
Re-sourcing the same hook file in the same session is allowed.

**Interfaces.** These are the registry's existing contracts, stated
here so a hook author needs only this document and
`1_code/methods/_templates/`.

| Kind | Register with | Must take | Must return |
| --- | --- | --- | --- |
| Engine | `register_engine(list(name, description, capabilities, fit, predict, coef?, ic?))` | `fit(formula, data, family, weights, offset, control)`; `predict(fit, newdata, type, se)` | `fit`: `list(fit, ok, message)`, never raises. `predict`: one number per row. `coef(fit)`: data frame `term`, `estimate`, `se`, if `"coefficients"` is declared. `ic(fit, type)`: a number, if `"ic"` is declared. |
| Selection rule | `register_selection(name, fn, description, requires)` | `models, base, data, engine, family` (plus `weights, offset, ic, control`; extra arguments are filled from stage fields of the same name) | `selection_result()` |
| Resampler | `register_resampler(name, fn, description)` | `frame, iterations, seed, context` (extra arguments are filled from `spec$resample`) | A list of survey-unit-id vectors, one per iteration |
| Metric | `register_metric(name, fn, description, direction)` | `observed, predicted` (response scale) | One number, or `NA` |
| Spec function | none | The signature of the field it fills; see `harness/run_model.R` | As the field requires |

`check_engine()` (`harness/engines.R:176`) tests a hook engine
against the contract, as it does for built-ins.

**Metric direction (L7).** `register_metric()` gains
`direction = NULL`, one of `"higher"`, `"lower"`, `"toward_one"`, or
`"none"`. `better_direction()` (`harness/compare.R:38`) reads the
registered direction first and falls back to today's table, so
built-in metrics need no edit. Loading a hook metric without a
`direction` gives a warning, because it would otherwise be treated
as "higher is better".

**Alternatives considered**

- *Auto-load `1_code/experiments/<id>/hooks/` from the id.* Rejected
  as implicit: the hook files would be loaded by a call that doesn't
  name them. An explicit `hooks =` path is one line and easy to
  read.
- *Pass functions directly in specs, with no registration.* This
  already works for selection rules (`stage$selection` may be a
  function) and spec function fields. It doesn't work for engines,
  resamplers, or metrics, which are looked up by name, and it
  records only `"custom"` in the run record. Registration gives a
  name for the record and for validation.
- *Let hooks override built-ins.* Rejected; see the clash rule.

## 4. Spec changes inside the experiment (L3)

Three helpers in `harness/spec.R`. Each one changes a spec the
experiment holds, validates it, and records the change so it
appears in `experiment_changes()`, `meta.json`, and the run record.

| Helper | Changes | Example |
| --- | --- | --- |
| `modify_stage(spec, stage, ...)` | Fields of one named stage. `NULL` removes a field. | `modify_stage(spec, "habitat", min_detections = 10L)` |
| `modify_region(spec, region, ...)` | Fields of one region | `modify_region(spec, "north", filter = ~ nr == "Boreal")` |
| `modify_resample(spec, ..., replace = FALSE)` | `spec$resample`. With `replace = TRUE`, the old settings are dropped except `scope`, for switching scheme. | `modify_resample(spec, scheme = "spatial_cv", replace = TRUE)` |

Each helper:

1. Stops if the stage or region isn't in the spec, listing the ones
   that are.
2. Sets the fields and runs `validate_spec()`, so a misspelt field
   (unknown fields are errors) fails here, in `run.R`, with the
   experiment's line in the traceback.
3. Appends `"<stage>: <field> = <value>"` to `models_overridden`
   (the existing record of changes), and marks the stage's
   `v2_coverage` entry `"not reproduced"` with the change as its
   note, as `replace_stage_method()` already does.

They apply across taxa the same way `replace_stage_method()` does:

```r
specs <- lapply(standard_specs(), modify_resample,
                scheme = "spatial_cv", replace = TRUE)
```

Module argument changes (`bryophyte_spec(use_protocol = FALSE)`,
`mammal_spec(climate_source = "fitted")`) stay as they are:
called in `run.R`, passed in `specs`.

**Recording a module argument change.** `experiment_changes()` lists
spec differences from `standard_specs()` only through
`models_overridden`. A spec built with a non-default module argument
already records it in `notes` and `protocol_is_v2`. No further change
is proposed.

**Alternatives considered**

- *Document hand edits of the spec list (`spec$stages[[2]]$ic <-
  "BIC"`).* Rejected: the change isn't recorded, is fragile to stage
  order, and gives no validation until run time.
- *One `modify_spec()` with a path argument.* Rejected as harder to
  read than three named helpers.

## 5. Spatial block cut points (L6)

`resampler_spatial_block()` and `resampler_spatial_cv()` gain
`long_breaks` and `lat_breaks` arguments that default to today's
values, and pass them to `spatial_blocks()`. They become `resample`
settings, set with `modify_resample()`:

```r
modify_resample(spec, scheme = "spatial_cv", replace = TRUE,
                lat_breaks = seq(49, 60, by = 1))
```

The defaults move from `spatial_blocks()` (`harness/resample.R:143`)
into one function, `v2_block_breaks()`, which all three read, so
there is one copy. Results with the defaults are unchanged. These
are `methods/` and `harness/` changes; no module changes.

## 6. Validation

`experiment_config()` collects every problem and stops once with the
full list, as `validate_spec()` already does. All checks run before
any fitting. As built, the species list is read and checked first,
because the runs can depend on it; then the runs, draws, covariate
files, regions and metrics, specs, and covariates. An unknown run in
`taxa` still stops at once, since everything after depends on it.

| Check | New? | Message names |
| --- | --- | --- |
| `taxa` are runs in `specs` | Existing | Unknown runs; available runs |
| With no `taxa`: every listed species is fitted by some run (its taxon, the run's tier and, for mammals, season) | New (section 15) | Each species no run fits |
| `n_bootstraps` is a whole number of 1 or more, and is within the stored draws for `precomputed` | Existing | |
| Species file exists, has `taxon` and `species` columns, and has no blank or duplicate rows | New | The path; the missing column |
| Every species exists in `species_queue.csv` for its taxon | New, moved from `prepare_spec()` | Each unknown name, with up to three close matches (`agrep`) |
| Every `taxon` in the species file is a known slug | New | |
| `regions` exist in every selected spec | New | Spec and its regions |
| `metrics` and `compare_metrics` are registered metrics | New | Unknown name; registered names |
| Each spec passes `validate_spec()` after `stage_models` are applied | New here, moved from `prepare_spec()` | As now |
| Every covariate a spec's formulas name exists in the dataset for that taxon and region (after `term_map()`), or in `covariate_files`, or is derivable | New, moved from load time | Each missing name per run and stage, with close matches |
| `covariate_files` exist and are keyed on `survey_unit_id` | Existing | |
| Hook files source cleanly and don't clash with registered names | New, at `load_framework()` | File, name, existing method |

`prepare_spec()` keeps its own checks, because `run_specs()` can be
called without `experiment_config()` (tests do this). For a valid
config the checks are only repeated, and results don't change.

**Risk in the covariate check.** It must reproduce the harness's
name resolution exactly: aliases, `supplied_columns`, carried
columns, block suffixes, and derived columns. A wrong check blocks
valid runs. As built, it shares code with the run rather than
copying it: `region_request()` and `province_request()` were
extracted from `prepare_region()` and `province_context()` in
`run_model.R`, and `covariate_columns_needed()` from
`load_covariates()` in `data_load.R`. Both the check and the run
call them. It passes on all three experiments and every taxon, takes
about a second, and suggests close matches (`bio155`: "did you mean
bio15?").

## 7. Provenance

`run_record.md`, in the committed file:

- **Provenance section** (volatile, so it doesn't affect run-to-run
  comparisons): `written_at`, full `git_commit`,
  `git_uncommitted_code` (how many files under `1_code/` differ
  from `HEAD`, untracked included), `r_version`, `platform`,
  versions of the modelling packages loaded in the main session
  (`data.table`, `arm`, `xgboost`, `mgcv`, `MuMIn`; packages loaded
  only in parallel workers don't appear), each hook file with its
  md5, and the path of `session_info.txt`.
- **Configuration section** (stable): today's keys, plus `regions`,
  `metrics`, `compare_metrics`, `species_file` (base name) with
  `species_n`, and `hooks` (base names). Changes made with
  `modify_*()` already appear under `changes_from_v2`.

In `2_pipeline/<id>/`, which is gitignored: `session_info.txt`
holds the full `sessionInfo()` output, written once fitting
finishes. `run_log.csv` and each store's `meta.json` are unchanged,
except that `meta.json` lists hook names.

**Alternative considered:** *`sessioninfo::session_info()`.* It is
installed and gives a richer listing, but base `sessionInfo()` is
enough and adds no dependency to the harness.

## 8. Experiment template

`1_code/experiments/_template/`:

| File | Change |
| --- | --- |
| `run.R` | Reorganized into the sections in section 1: hooks in `load_framework()`, a spec-changes section with one example per helper in the header notes, and `species = file.path(exp_dir, "species.csv")`. No `taxa` line: the species list sets the runs. The header lists the levers from least to most invasive, now ending in `hooks/` rather than "a new method in `1_code/methods/`". |
| `README.md` | New rows: species file, hooks, spec changes. |
| `species.csv` | Every species a run can fit (1,117 rows), `taxon,species,note`, notes empty. The experiment deletes the rows it doesn't fit. For a like-for-like comparison, keep exp_000's species (in `exp_000_parity_v2/species.csv`). |
| `hooks/.gitkeep` | Empty folder, so the layout is visible. |

`new_experiment()` copies the template recursively and fills
placeholders in every file. It needed one fix: it listed files
without `all.files = TRUE`, so `hooks/.gitkeep` (a dot file) never
reached a new experiment. A test now checks that `species.csv` and
`hooks/.gitkeep` arrive.

## 9. Module boundary

**No module changes.** Every module setting an experiment can
reasonably vary is reached by one of these:

- Module function arguments (`use_protocol`, `climate_source`,
  `tier`, `season`, `bootstrap`), called in `run.R`.
- `modify_stage()`, `modify_region()`, or `modify_resample()` on the
  spec the module returns.
- `replace_stage_method()` (existing).
- A replacement function in `hooks/`, set with `modify_stage()`, for
  logic inside a module function (e.g. the mammal 99% winsorizing
  cap).

Modules stay the record of v2. Taxon leads review only changes to
their v2 configuration.

## 10. Output layout

Unchanged:

- Intermediates go to `2_pipeline/<id>/`: result stores,
  `run_log.csv`, `inputs/`, and the new `session_info.txt`.
- Deliverables go to `3_output/<id>/`: `tables/`, `figures/`,
  `report.md`, `run_record.md`.

**Correction to the brief.** `.gitignore` doesn't keep all of
`tables/*.csv`. It keeps `run_record.md`, `report.md`, and five named
tables: `parity_summary`, `coverage`, `metric_summary`,
`grid_summary`, and `v2_self_agreement_summary`.
`comparison_metrics.csv` and `coefficient_summary.csv` stay ignored,
as the comment there explains. The design writes no new table, so
`.gitignore` needs no change.

## 11. Migration

| Experiment | Change |
| --- | --- |
| exp_000_parity_v2 | Added `species.csv` (the former `parity_check`, 14 rows), with a `note` column holding each species' detections and prevalence from the deleted file. The selection criteria moved to a comment in `run.R`. `run.R` sets `species` to the file; no other change. |
| exp_001_xgboost | Added `species.csv` (same 14 rows, no notes) and an `exp_dir` line; `run.R` otherwise unchanged. `replace_stage_method()` stays. |
| exp_002_soilgrids | Added `species.csv` (same 14 rows, no notes) and an `exp_dir` line; `run.R` otherwise unchanged. |
| `_template/` | As in section 8. |
| `experiments/_shared/` | `focal_species.R` deleted. The folder goes with it, because git doesn't track empty folders. `load_framework()` already tolerates a missing folder; the code says so in a comment. |

All three migrated; none was left unchanged. All three keep their
explicit `taxa`, so their runs are unchanged.

## 12. Parity and verification plan (Phases 3 and 5)

**Reduced parity run (approved and run).** This follows the repository's established check
(`1_code/tests/compare_stores.R`; memory: five-draw regression
check).

| Setting | Value |
| --- | --- |
| Config | exp_000's, run as a script from the scratchpad, not by editing `run.R` |
| Species | `parity_check`, all seven runs (14 species) |
| Draws | 5, seeded `20260909` |
| Workers | 12 |
| Output | `pipeline_dir = 2_pipeline/refactor_baseline/stores`; `out_dir = 2_pipeline/refactor_baseline/output`, so nothing in exp_000's `3_output/` is touched |
| Steps | None (`01`-`03` compare with v2 and plot; not needed for regression) |
| Baseline comparison | Off (`baseline = NULL`) |
| Also saved | `commit.txt` (`afdfe3b` plus a clean or dirty flag) and `session_info.txt` |
| Time taken | 1.9 minutes |

After the refactor, the same script runs against the new code into
`2_pipeline/refactor_after/` (species from `species.csv`).
`compare_stores()` compares `coefficients`, `metrics`, and
`grid_predictions` per run and region. The summary tables are
compared with `all.equal()`.

**Tolerance:** exact (`0`), because the run is seeded and the code
path is unchanged.

**Result: pass.** Baseline at `afdfe3b`; all 140 jobs `ok` on both
sides. All 14 run-and-region stores match on coefficients, metrics
and grid predictions with a largest absolute difference of 0;
`coverage`, `metric_summary`, `grid_summary` and
`coefficient_summary` are identical; `meta.json` differs only by
the new `hooks` field. Re-run after the last fitting-path edits
with the same result. The later changes in section 15 touch only
how the species list and runs are chosen; exp_000 passes `taxa`, so
its run is unaffected, and no further parity run was asked for.

**Phase 5 also covers:**

- `Rscript 1_code/tests/run_tests.R`, plus new tests for hooks
  (including the clash rule), `species.csv`, `modify_*()`,
  `regions`, `metrics`, `compare_metrics`, metric direction, block
  breaks, and each new validation message.
- A scratch experiment created with `new_experiment()`: one lichen
  species, 3 to 5 draws, `workers = 2` (so hooks are proven in
  workers). It uses a hook engine (a renamed `glm` wrapper) and a
  hook metric with `direction = "lower"`, `modify_stage()`, and
  `spatial_cv` with custom `lat_breaks`. It is then deleted with its
  `2_pipeline/` and `3_output/` folders.
- Validation checks: a misspelt covariate, an unknown engine, a
  missing species file, a misspelt species, and a hook name clash.
- `git status --porcelain` and `git check-ignore -v` on outputs.

**Results:** every test passes. The scratch experiment ran with
two lichen species on two workers (16 jobs `ok`), proving hooks
load in workers; the run record listed the hook, its md5 and every
change. A run with `regions = "north"` and `metrics = c("auc",
"mae")` produced only those. Each validation error gave a clear
message. From `3_output/<id>/`, only `run_record.md`, `report.md`,
the allowed tables and scaffold `.gitkeep` files surfaced; nothing
from `2_pipeline/`, including `session_info.txt`. The scratch
folders were deleted.

## 13. Where this departs from common R practice

1. **Defaults as function arguments, not a config file**
   (section 2). Most configurable R pipelines (`config`, `targets`
   with YAML) keep settings as data. Here settings include formulas
   and functions, and the users write R.
2. **Sourced files and a global registry, not a package.** This is
   the repository's existing pattern. Hooks extend it rather than
   introducing `pkgload` or an R package for the back-end. A package
   would give namespacing and `R CMD check`, at the cost of a build
   step for every taxon lead.
3. **Hooks registered into a session-wide registry**, rather than
   passed as arguments. The clash rule stops one experiment's hook
   from changing a built-in for others in the same session.

## 14. Files changed

| File | Change |
| --- | --- |
| `1_code/harness/harness.R` | `load_framework(hooks = )`; hook loading with the clash rule |
| `1_code/harness/registry.R` | Clash check while loading hooks; `direction` on `register_metric()` |
| `1_code/harness/experiment.R` | New arguments; collected validation; runs derived from the species list (`runs_for_species()`); `session_info.txt`; record fields; headline uses `compare_metrics` |
| `1_code/harness/run_model.R` | Pass hook files to workers; `region_request()` and `province_request()` extracted, unchanged in behaviour; `hooks` in `meta.json` |
| `1_code/harness/data_load.R` | `covariate_columns_needed()` extracted from `load_covariates()`, unchanged in behaviour |
| `1_code/harness/new_experiment.R` | Copies dot files (`all.files = TRUE`), so `hooks/.gitkeep` arrives |
| `1_code/harness/species.R` | `read_species_file()`; config-time name check with close matches |
| `1_code/harness/spec.R` | `modify_stage()`, `modify_region()`, `modify_resample()`; config-time covariate check |
| `1_code/harness/compare.R` | Registered direction first; `compare_metrics` |
| `1_code/harness/resample.R` | `v2_block_breaks()` |
| `1_code/harness/run_record.R` | Provenance fields |
| `1_code/methods/resampling/spatial_block.R`, `spatial_cv.R` | `long_breaks` and `lat_breaks` settings |
| `1_code/experiments/_shared/focal_species.R` | Deleted |
| `1_code/experiments/_template/` | `run.R` (no `taxa`), `README.md`, `species.csv` (every fittable species), `hooks/.gitkeep` |
| `1_code/experiments/exp_000…`, `exp_001…`, `exp_002…` | `species.csv`; `species =` line in `run.R` |
| `1_code/tests/testthat/` | New `test-experiment_config.R`; `test-new_experiment.R` extended |
| `1_code/modules/` | **None** |

## Assumptions

- A hook file is trusted code: it is sourced, not sandboxed.
- `species_queue.csv` in the pinned dataset is the authority for
  species names. A species missing from it can't be run, as today.
- `git` is on the PATH where runs happen. When it isn't, the record
  writes `-`, as now.
- Existing committed `run_record.md` files will differ in their
  Configuration section the next time each experiment runs (new
  keys). Their results won't.

**Confidence: High** that this closes L1 to L3 and L5 to L7 without
changing results: the parity run matched exactly. The config-time
covariate check, rated Moderate in the proposal, is now High: it
calls the same name-resolution code as the run and passed on every
taxon.

## 15. Revisions after approval

| Revision | Why |
| --- | --- |
| The template's `species.csv` lists every species a run can fit (1,117 rows, `taxon,species,note`, notes empty) instead of exp_000's 14. Users delete the rows they don't fit. | Requested after implementation: users choose from the full list rather than starting from exp_000's set. |
| A `use` column (TRUE/FALSE per row) was tried and removed. | The requested format is `taxon,species,note`, cut down by deleting rows; a selection column was not needed. |
| Without `taxa`, `experiment_config()` runs only the runs that fit a listed species, and the template drops its `taxa` line. | Before, a taxon with no rows in the list meant "every species" for any run still in `taxa`. Cutting the template to three lichens while `taxa` named all seven runs would have fitted over 1,000 other species. Deriving the runs makes `species.csv` the one file to edit. |
| A listed species that no run can fit is an error. | Found while deriving runs: 23 mammals are `ua` tier only, which the mammal runs never fit. They were also removed from the template. |
| `new_experiment()` copies dot files. | `hooks/.gitkeep` was not reaching new experiments. |

Not changed: an explicit `taxa` keeps its old meaning, so existing
experiments run as before. Making an explicit `taxa` with an
unlisted run an error was offered and not chosen.
