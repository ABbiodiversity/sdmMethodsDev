# Getting started

This guide covers running the v2 baseline, reading what it writes,
and testing a change against it. It assumes you know R. It does not
assume you know how the v2 models were built.

- [The idea in one paragraph](#the-idea-in-one-paragraph)
- [Words used throughout](#words-used-throughout)
- [Run the baseline](#run-the-baseline)
- [Read the outputs](#read-the-outputs)
- [Test a change](#test-a-change)
- [Add a method](#add-a-method)
- [Check that nothing broke](#check-that-nothing-broke)
- [Where things are](#where-things-are)

## The idea in one paragraph

Every taxon's v2 model follows the same sequence:

1. Pick survey units.
2. Fit a set of candidate models.
3. Choose among them or average them.
4. Predict and score.

What differs between taxa is the contents of each step: the
response, the formulas, the selection rule. Here those contents are
data, in a **spec**, one per taxon. One shared pipeline, the
**harness**, runs any spec.

So a methods question is asked once, by changing one entry, and
answered for every taxon. `exp_000_parity_v2` runs the v2 specs and
checks they reproduce v2. Every later experiment changes one thing
and is compared against it.

## Words used throughout

| Word | Means |
| --- | --- |
| **Spec** | A taxon's v2 configuration as a list: response, family, regions, stages, resampling. Built by functions such as `lichen_spec()` in `1_code/modules/<taxon>/spec.R`. Holds no modelling code. |
| **Run** | One spec in an experiment, named as its output folder: `lichen`, `mammal_summer`. `standard_specs()` lists them. |
| **Stage** | One model fitted in order. Plants and birds fit `climate`, then `habitat` (or `landcover`). |
| **Carry** | Passing one stage's prediction into the next as a covariate called `Climate`, which is how v2 combines its climate and habitat models. |
| **Candidate set** | The formulas a stage chooses among. The v2 sets are in `harness/model_sets.R`. |
| **Engine** | How one formula is fitted: `glm`, `bayesglm`. |
| **Selection rule** | How a candidate set becomes one result: `aic_average`, `staged_bic`, `ivw_grid`, and so on. |
| **Draw** | One bootstrap resample of the survey units. v2 uses 100. Draw 1 is the full data. |
| **Store** | A folder of results for one run and region: `coefficients.csv`, `metrics.csv`, `grid_predictions.csv`, `meta.json`. |
| **Grid** | A prediction matrix with one row per habitat type, each row a pure stand of that type. Predicting onto it gives each method's effect per habitat type, so methods without coefficients can be compared. |
| **Out-of-bag (oob)** | Scored on the survey units a draw left out, which is the held-out read. `insample` scores the units the draw fitted. |
| **Parity** | Whether a run reproduces v2. Distributional, not numerical: v2 sets no random seed, so two v2 runs differ. |

## Run the baseline

Open the project in RStudio or Positron. The working directory is
then the repository root. Then:

```r
source("1_code/experiments/exp_000_parity_v2/run.R")
```

`run.R` is a page of decisions, `experiment_config()`, followed by
one call, `run_experiment()`. Before you run it, check three
settings:

| Setting | For a quick check | For the real thing |
| --- | --- | --- |
| `species` | `"one_each"` (one species per taxon) | `"parity_check"`, or `NULL` for every species |
| `n_bootstraps` | `5` | `100` |
| `workers` | 4 | up to the cores you can spare |

`experiment_config()` checks the configuration before anything is
fitted, and prints what it will do. Shorten a trial by cutting
species, not draws: a 10–90% band read from five draws does not
mean much.

On a 24-core machine, for the 14 `parity_check` species (5-draw rows measured):

| Draws | Workers | Time |
| --- | --- | --- |
| 5 | 1 | about 6 min |
| 5 | 12 | about 1.6 min, set by the slowest species (a bird, about 1 min) |
| 100 | 12 | estimated 25–30 min (not yet run); the previous, serial code took 3.3 h |

Parallel workers are separate R sessions that load the framework from
disk when the run starts, so do not edit `1_code/` files while one is
starting.

## Read the outputs

Everything lands in `3_output/<id>/`. Read these in order:

1. **`run_record.md`**: what ran. If it is not every species at 100
   draws, the numbers describe a trial.
2. **`report.md`**: what each spec reproduces of v2, parity by
   stage, and model fit (AUC).
3. **`tables/parity_summary.csv`**: one row per taxon, region and
   stage, with a verdict.
4. **`tables/metric_summary.csv`**: fit metrics per species. Read
   the `oob_` rows.
5. **`tables/grid_summary.csv`**: the predicted effect of each
   habitat type, per species.

The column definitions are in the
[README's output key](../README.md#output-key).

The model behind every metric and grid prediction is each stage's
**final** model. That is the averaged one where v2 averages
candidates, and v2's own prediction from its coefficient tables
for plants. It is not the single best candidate.

## Test a change

Copy `1_code/experiments/_template/` to
`1_code/experiments/exp_001_short_description/`, set `id`, and
write the question in the README. Then change one thing. There are
three levers, from least to most invasive.

### 1. Different candidate formulas: `stage_models`

The covariates a run loads are read off the formulas it fits.
Changing the formulas is therefore all it takes to try new
covariates.

```r
stage_models = list(
  # every v2 climate candidate, plus elevation
  climate = extend_models("climate_plant_v2_full", "elevation"),
  # or, for mites only, a ladder built from covariates
  mite.climate = models_from_covariates(
    c("MAP", "FFP", "CMD"), form = "ladder"
  )
)
```

Keys are `stage` (every taxon) or `taxon.stage` (one taxon).
`meta.json` records the override, so a run that did not fit the v2
sets cannot be mistaken for one that did.

### 2. A different engine or rule: `specs`

Build the standard specs, change a stage, and pass them in. For
example, to fit the bird landcover stage with a registered engine
called `my_engine`, one formula, no ranking:

```r
specs <- standard_specs()
specs$bird$stages[[2]]$engine <- "my_engine"
specs$bird$stages[[2]]$selection <- "single"

config <- experiment_config(
  id = "exp_002_my_engine", taxa = "bird", specs = specs, ...
)
```

`validate_spec()` checks the combination before anything runs. A
rule that needs something the engine cannot give, such as standard
errors for inverse-variance averaging, stops the run with a
sentence that says so.

v2 post-processing steps that read coefficients do not apply to an
engine without them. Examples are the plant stand-age splines and
footprint pooling, set in a stage's `post_process`. Remove them
when you swap such an engine in:

```r
specs$lichen$stages[[2]]$post_process <- NULL
```

### 3. A new method

See [`1_code/methods/README.md`](../1_code/methods/README.md). A new
engine, rule, resampling scheme or metric is one file there. After
that, it is a name in a spec, as in lever 2.

### Reading the comparison

The template's `run.R` ends with `compare_to_baseline`, which
writes three tables:

| File | Holds |
| --- | --- |
| `comparison_summary.csv` | Per taxon, region and metric: the median difference from exp_000, and the share of species that did better |
| `comparison_metrics.csv` | Per species and metric, with both runs' 10–90% bands |
| `comparison_grid.csv` | Per species: rank correlation and absolute difference of the habitat effects on the grid |

"Better" means:

- higher AUC, deviance explained and Spearman;
- lower RMSE;
- a calibration slope closer to 1.

A difference is only worth reading if it is consistent across
species (`share_better`) and large relative to the bands.

## Add a method

The short version:

1. Copy the matching template from `1_code/methods/_templates/`
   into the matching folder of `1_code/methods/`.
2. Fill it in, and register it.
3. Check it:

   ```r
   source("1_code/harness/harness.R")
   load_framework()
   check_engine(engine_mine())  # for an engine
   list_methods()               # it should be listed
   ```

4. Run `Rscript 1_code/tests/run_tests.R`.
5. Name it in a spec (lever 2 above), then try it on
   `species = "one_each"` with `n_bootstraps = 5`.

## Check that nothing broke

A change to `harness/`, `methods/` or `modules/` affects every
experiment, past and future. Before relying on one, take two steps.

**1. Run the tests.** These take seconds:

```sh
Rscript 1_code/tests/run_tests.R
```

**2. Confirm the v2 results are unchanged.** Draws are seeded per
species and made in order, so draws 1–5 of a 5-draw run are the
same rows as draws 1–5 of the 100-draw baseline. Run the parity
species at 5 draws to a scratch folder, then compare:

```sh
Rscript 1_code/tests/compare_stores.R \
  2_pipeline/exp_000_parity_v2 2_pipeline/<scratch> 5
```

Every coefficient file should match to 1e-10. A change that is
meant to alter results should alter only what it says it does.

## Where things are

| Folder | Holds | Edit it to |
| --- | --- | --- |
| `1_code/harness/` | The shared pipeline: loading, the fitting loop, summaries, comparison | Change how every experiment runs (review as such) |
| `1_code/methods/` | Engines, selection rules, resampling schemes, metrics | Add a method |
| `1_code/modules/<taxon>/` | Each taxon's v2 spec | Record what v2 does for a taxon |
| `1_code/experiments/exp_NNN_*/` | One folder per question | Ask a question |
| `1_code/experiments/_shared/` | Named focal-species sets | Add a reusable species set |
| `1_code/_setup/` | One-off scripts that build `0_data/` | Rebuild or extend the dataset |
| `0_data/test_dataset/` | The frozen dataset. `lookup/dataset_manifest.csv` says which file is whose | Nothing; it is rebuilt by `_setup/` |
| `docs/` | Design, taxon quirks, this guide | |
