# Worked example: swapping the modelling method

This walkthrough builds an experiment that changes **how a stage
is fitted**, using [`exp_001_xgboost`][exp001] as the example. It
asks whether boosted regression trees fit the habitat stage better
than v2's linear models, for every taxon: the plant-group taxa,
mammals, and birds.

It uses the `specs` lever: build the standard specs, change a
stage, and pass the specs in. No new data is needed. For an
experiment that adds covariates instead, see the
[SoilGrids worked example](example_experiment.md). 

Read [Getting started](getting_started.md) first. Run every code
block from the repository root.

- [Before you start](#before-you-start)
- [Step 1: Scaffold and write down the question](#step-1-scaffold-and-write-down-the-question)
- [Step 2: Why you cannot just swap the engine](#step-2-why-you-cannot-just-swap-the-engine)
- [Step 3: Make the change with replace_stage_method()](#step-3-make-the-change-with-replace_stage_method)
- [Step 4: Set the engine's settings](#step-4-set-the-engines-settings)
- [Step 5: Check the specs before running](#step-5-check-the-specs-before-running)
- [Step 6: Configure and run at 5 draws](#step-6-configure-and-run-at-5-draws)
- [Step 7: Check that it worked](#step-7-check-that-it-worked)
- [Step 8: Read the comparison](#step-8-read-the-comparison)
- [Step 9: Tune, run at 100 draws, and write it up](#step-9-tune-run-at-100-draws-and-write-it-up)
- [Checklist](#checklist)

## Before you start

You need:

- **The engine's package.** Here, `xgboost`. Engines load their
  package only when used, so a run that does not use xgboost does
  not need it.
- **The engine registered.** `xgboost` already is, in
  `1_code/methods/engines/xgboost.R`. To test a method that is not
  registered yet, add it first; see the
  [methods README][methods].
- **exp_000 tables at the draw count you will run**, as in the
  [SoilGrids example](example_experiment.md#before-you-start).

Check what is registered, and what each selection rule needs from
an engine:

```r
source("1_code/harness/harness.R")
load_framework()

list_methods("engine")
list_methods("selection")  # the `requires` column
```

## Step 1: Scaffold and write down the question

Scaffold with `new_experiment()` and fill in the README, as in
Steps 1 and 2 of the
[SoilGrids example](example_experiment.md#step-1-scaffold-the-folders).

exp_001's design table:

| | exp_000 (baseline) | exp_001 (this) |
| --- | --- | --- |
| Climate stage | v2: GLM candidates, AICc model averaging (mammals: v2's precomputed prediction) | The same |
| Habitat stage (each spec's `habitat_stage`; birds: landcover) | v2: GLM candidates; IVW averaging (plants), staged BIC (birds), or the hurdle with best-by-AICc halves (mammals); v2's post-processing | `xgboost` with the `single` rule, on every covariate v2's habitat candidates use, `Climate` included |
| Climate → habitat | Carried as `Climate` | The same |
| Species, draws, seed | `parity_check`, 20260909 | The same |

And the reasoning behind it:

- **Why one formula.** A tree chooses its own variables, splits,
  and interactions. So it is given every candidate covariate once,
  as main effects, instead of v2's competing formulas.
- **What is dropped, and why.** v2's post-processing of habitat
  coefficients: the plant stand-age splines, cutblock convergence,
  pAspen, and footprint pooling, and the mammal tables,
  calibration, and adjustments. They all read coefficients a tree
  does not have. Say so in the README, because the baseline still
  includes them.

## Step 2: Why you cannot just swap the engine

A stage names an **engine** (how one formula is fitted) and a
**selection rule** (how a candidate set becomes one result). Rules
need things from the engine. `ivw_grid`, v2's plant habitat rule,
averages coefficients weighted by their standard errors, so it
needs an engine that gives both. xgboost gives neither.

Swap only the engine, and `validate_spec()` says so before
anything runs:

```r
spec <- lichen_spec()
spec$stages[[2]]$engine <- "xgboost"
validate_spec(spec, stop_on_error = FALSE)
# (output wrapped to fit)
#> [1] "Stage `habitat`: selection rule `ivw_grid` needs
#> coefficients, se, which engine `xgboost` does not provide.
#> Choose a rule that does not, such as `single`."
```

So changing the method means changing three things together: the
engine, the rule, and the candidate set the rule chooses from.
Then v2 steps that read coefficients have to go too.

## Step 3: Make the change with replace_stage_method()

`replace_stage_method()` makes all of those changes in one call.
For a spec, it:

1. Finds the stage to change: the spec's `habitat_stage`.
2. Replaces the candidate set with **one formula holding every
   covariate the v2 candidates use** (`union = TRUE`, the
   default).
3. Sets the engine, `control` settings, and rule (`single` by
   default), and removes the information criterion and
   `post_process`. For the last stage, it also removes
   `final_prediction` and `validate`, which read v2 coefficient
   tables.
4. Records the change in `v2_coverage` and `models_overridden`, so
   no one can mistake the run for v2.

Because each spec names its own habitat stage, one call works for
every taxon:

```r
specs <- lapply(
  standard_specs(), replace_stage_method,
  engine = "xgboost", control = xgb_settings
)

sapply(specs, function(spec) spec$habitat_stage)
#>      bryophyte         lichen           mite vascular_plant  mammal_summer
#>      "habitat"      "habitat"      "habitat"      "habitat"      "habitat"
#>  mammal_winter           bird
#>      "habitat"    "landcover"
```

What changed for lichens:

```r
before <- lichen_spec()
after <- replace_stage_method(
  before, engine = "xgboost", control = xgb_settings
)

before$stages[[2]][c("engine", "selection")]  # bayesglm, ivw_grid
after$stages[[2]][c("engine", "selection")]   # xgboost, single

length(before$regions$north$habitat_models)
#> [1] 12
length(after$regions$north$habitat_models)
#> [1] 1

after$models_overridden
# (output wrapped to fit)
#> [1] "habitat <- xgboost with `single`, on every covariate the
#> v2 candidates use"
```

**Composite rules keep their structure.** The mammal `hurdle` is a
rule that runs another rule in each part. `replace_stage_method()`
keeps the hurdle and puts the new rule inside it:

```r
mammal <- replace_stage_method(
  mammal_spec(season = "summer"), engine = "xgboost"
)
# Mammals have one fitted stage; v2's climate is precomputed
mammal$stages[[1]][c("selection", "part_selection")]
# hurdle, single
```

Two arguments change the defaults. `stage` changes a stage other
than `habitat_stage`. `union = FALSE` keeps the candidate set, for
a rule that compares candidates (it needs an engine with an
information criterion).

## Step 4: Set the engine's settings

Settings reach the engine through `control`. exp_001's, in
section 1.2 of its `run.R`:

```r
xgb_settings <- list(
  nrounds = 1000,      # the most rounds; early stopping picks
  eta = 0.05,          # learning rate
  max_depth = 3,       # tree complexity
  subsample = 0.5,     # share of rows each tree sees
  min_child_weight = 1 # smallest leaf, in weighted rows
)
```

The xgboost engine also takes `colsample_bytree`,
`early_stopping_rounds` (default 50), `valid_fraction` (default
0.2), and `seed`. It picks the number of rounds by early stopping
on a seeded holdout of each draw, then refits on the whole draw.
The full list and defaults are in the header of
[`1_code/methods/engines/xgboost.R`][xgboost].

These settings are **untuned**. They test the pipeline, not the
method at its best. Record that as a caveat until you tune them.

## Step 5: Check the specs before running

Before spending compute, confirm that every changed spec is valid
and says what it does:

```r
invisible(lapply(specs, validate_spec))  # stops on any problem

spec_coverage(list(lichen = specs$lichen))
#>        stage         status
#> 1    climate     reproduced
#> 2    habitat not reproduced
#> 3 validation     reproduced
#> 4 resampling     reproduced
```

The habitat stage is now `not reproduced`. Each store's
`meta.json` records these statuses and `models_overridden`, so the
stores themselves say this run is not v2.

To check the engine itself on synthetic data:

```r
check_engine("xgboost")
#> Engine `xgboost`: 9 of 9 checks pass
```

It fits small binomial and Poisson data with weights, an offset,
and a factor, and checks each part of the engine contract. Every
row should read `TRUE`.

## Step 6: Configure and run at 5 draws

Pass the changed specs to `experiment_config()`. Everything else
matches exp_000:

```r
config <- experiment_config(
  id = "exp_001_xgboost",
  taxa = names(specs),
  species = "parity_check",   # exp_000's species
  n_bootstraps = 5,           # 5 checks; 100 for a result
  seed = 20260909,            # exp_000's seed
  specs = specs,              # the change
  workers = 12
)

results <- run_experiment(config)
```

exp_001 does not pass `translate = list(bird =
bird_habitat_translation)`, which exp_000 and exp_002 do. That
step translates bird landcover coefficients onto v2's habitat
template, and a tree has no coefficients to translate.

To try the change on fewer taxa first, narrow `taxa`, for example
`taxa = c("lichen", "bird")`.

Run the whole script:

```r
source("1_code/experiments/exp_001_xgboost/run.R")
```

## Step 7: Check that it worked

Check `run_log.csv`, `coverage.csv`, and `run_record.md` as in
[Step 7 of the SoilGrids example](example_experiment.md#step-7-check-that-it-worked).
A new engine is more likely than a new covariate to fail on some
species or draws, so read the `note` column of any row whose
status is not `ok`.

Two things are specific to a method without coefficients:

- **Grid predictions carry the comparison.** With no
  coefficients, each habitat type's effect is read from the tree's
  prediction on the grid, in `grid_predictions.csv` and
  `grid_summary.csv`.
- **`coefficients.csv` changes shape.** For plants and birds it
  holds only the climate stage.

## Step 8: Read the comparison

The comparison table and its columns are described in
[Step 8 of the SoilGrids example](example_experiment.md#step-8-read-the-comparison).
Keep in mind:

- **The baseline still has v2's post-processing**, and this run
  does not. Differences in aged, cutblock, or footprint habitat
  types partly reflect that. exp_000's mammal tables are v2's
  calibrated tables; this run's grid predictions are not
  calibrated.

As always, a 5-draw run on `parity_check` is a pipeline check,
not a result.

## Step 9: Tune, run at 100 draws, and write it up

1. **Tune the settings** before judging the method/
2. Set `n_bootstraps = 100` and run again. Compare with a
   100-draw exp_000 of the same species.
3. Fill in the README's **Result** and **Assumptions and
   caveats** sections. exp_001's caveats are a model: untuned
   settings, the grid comparison, and the post-processing the baseline
   keeps.
4. Commit only runs that count, as in
   [Step 9 of the SoilGrids example](example_experiment.md#step-9-run-at-100-draws-and-write-it-up).

## Checklist

- [ ] The engine is registered and `check_engine()` passes.
- [ ] Question, design table, and what is dropped in the README
      before the first run.
- [ ] Specs changed with `replace_stage_method()`, or by hand with
      the same four changes.
- [ ] Every changed spec passes `validate_spec()`, and
      `spec_coverage()` shows the replaced stage as not
      reproduced.
- [ ] Species, seed, and draws match exp_000.
- [ ] 5-draw run: `run_log.csv` all `ok`, `coverage.csv`
      complete, comparison written.
- [ ] Out-of-bag metrics and calibration read together; grid and
      post-processing caveats stated.
- [ ] Settings tuned, and a 100-draw run compared with a 100-draw
      exp_000, before any result is written.

[exp001]: https://github.com/ABbiodiversity/sdmMethodsDev/blob/main/1_code/experiments/exp_001_xgboost/README.md
[methods]: https://github.com/ABbiodiversity/sdmMethodsDev/blob/main/1_code/methods/README.md
[xgboost]: https://github.com/ABbiodiversity/sdmMethodsDev/blob/main/1_code/methods/engines/xgboost.R
