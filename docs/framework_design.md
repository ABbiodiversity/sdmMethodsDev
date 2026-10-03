# Modelling framework design

![Status](https://img.shields.io/badge/Status-Steps%201--5%20built-yellow)

How the three taxon pipelines become one configurable framework, so that
a methods question can be asked once and answered across taxa.

- [Purpose](#purpose)
- [The shape the three pipelines share](#the-shape-the-three-pipelines-share)
- [Architecture](#architecture)
- [Contract 1: the taxon spec](#contract-1-the-taxon-spec)
- [Contract 2: the result object](#contract-2-the-result-object)
- [Choosing covariates](#choosing-covariates)
- [Parity ledger](#parity-ledger)
- [Build order](#build-order)
- [Taxon-specific quirks](taxon_quirks.md) — separate file

## Purpose

This repository exists to answer questions that apply across taxa —
bioclimatic model form, modelling framework, data integration and
ensembling, spatial autocorrelation, remote-sensing covariates. Answering
one of those once, rather than three times in three idioms, requires the
taxon to become a *configuration* rather than a codebase.

Two constraints shape everything below:

1. **Parity.** Running the framework in v2 configuration must reproduce
   v2 results, so a difference in a later experiment is attributable to
   the method rather than to the plumbing.
2. **Usability.** A user picks a taxon, a species set and a covariate
   set, and the pipeline runs. Where parity and usability conflict, the
   conflict is recorded in the [parity ledger](#parity-ledger) rather
   than resolved silently.

## The shape the three pipelines share

> Every behaviour that differs between the taxa is enumerated
> in [`taxon_quirks.md`](taxon_quirks.md), with the harness's
> status against each. The claim that the taxon is only
> configuration is worth exactly as much as that list.

The v2 scripts differ in nearly every detail and agree on one sequence:

```
select units (region filter → resample)
  → assemble frame (response + offset + weights + covariates)
    → fit a candidate model set
      → select or average among candidates
        → reduce onto a prediction grid
          → score
```

What varies is the contents of each slot:

| Slot | Plants | Mammals | Birds |
| --- | --- | --- | --- |
| Response | 0/1 detection | density / PA | count |
| Engine | `bayesglm` binomial | `glm` binomial, then GAM splines | `glm` poisson |
| Offset | — | — | QPAD log-offset |
| Weights | — | season-days | survey weight |
| Climate stage | 14 formulas → AICc-weighted average | precomputed, read in | 8 formulas, staged |
| Habitat stage | 12 veg / 16 soil → IVW average | AICc best | staged forward, BIC ≤ 2, fewest params |
| Resample | spatial-block bootstrap | — | precomputed ids |
| Regions | veg / soil | north / south | north / south |

Every one of those cells is data or a named strategy. None of them
requires a separate pipeline.

## Architecture

```
1_code/
├── harness/                 # taxon-agnostic; the framework
│   ├── harness.R            # load_framework(): everything below, in order
│   ├── registry.R           # register_*(), get_method(), list_methods()
│   ├── spec.R               # validate_spec() and spec helpers
│   ├── data_load.R          # dataset manifest, readers, model frames
│   ├── covariate_sets.R     # named bundles → the column catalogue
│   ├── species.R            # the one species queue
│   ├── resample.R           # seeds, spatial blocks, scheme dispatch
│   ├── engines.R            # engine interface, check_engine()
│   ├── selection.R          # candidate fitting, combined predictors
│   ├── eval_metrics.R       # compute_metrics()
│   ├── predict_grid.R       # final model onto a habitat grid
│   ├── result.R             # the result store, and shards
│   ├── run_model.R          # run_specs(): prepare, fit (parallel), merge
│   ├── summarise.R          # collect_results()
│   ├── compare.R            # compare_experiments()
│   └── experiment.R         # experiment_config(), run_experiment()
├── methods/                 # one file per method, each self-registering
│   ├── engines/             # glm, bayesglm
│   ├── selection/           # single, aic_best, aic_average, staged_bic,
│   │                        #   ivw_grid, aic_best_grid, aic_best_onehot
│   ├── resampling/          # precomputed, spatial_block, spatial_cv
│   └── metrics/             # auc, deviance_explained, rmse, …
├── modules/
│   ├── _shared/             # plant_group.R; standard_specs.R
│   └── <taxon>/spec.R       # that taxon's v2 configuration
├── experiments/
│   ├── _shared/             # focal-species sets
│   ├── _template/           # the starting point for a new one
│   └── exp_NNN_*/run.R      # configuration, then run_experiment()
└── tests/                   # contract tests; store comparison
```

The harness knows nothing about any taxon, and nothing about any
particular method: it looks methods up by the name a spec gives. A
module contributes only a spec. An experiment changes parts of a
spec, or names different methods in it.

There are six taxon modules: `bryophytes`, `lichens`, `soil_mites`,
`vascular_plants`, `mammals` and `birds`. The first four share the v2
pipeline shape in `_shared/plant_group.R`, so four copies cannot
drift apart. Directory names are plural and readable; **taxon slugs
are the data keys and are not**. Soil mites live in `soil_mites/` and
key on `mite`.

### Methods are plug-ins

An engine, selection rule, resampling scheme or metric is one file in
`1_code/methods/` that registers itself. Each kind has a contract,
stated in `1_code/methods/README.md`, and a rule states the engine
capabilities it needs (`coefficients`, `ic`, `se`). `validate_spec()`
checks a spec against the registry before any data is read, so an
engine paired with a rule it cannot serve - a boosted tree with
inverse-variance averaging, say - stops with a sentence rather than
silently returning nothing hours into a run. `check_engine()` tests a
new engine against the contract on synthetic data.

The rules talk to an engine only through its interface: coefficients
come from `engine$coef()`, computed once per fit, and every rule's
result carries a `predict()` for its final model. That is what lets
an engine without coefficients run any stage with the `single` rule,
be carried into a later stage, and be projected onto the grid.

### The data is described, not assumed

`0_data/test_dataset/lookup/dataset_manifest.csv`, written by
`_setup/09`, names each taxon's response, offset and grid files, its
key in `covariates.csv`, and its stored draws. The species queue and
factor levels are one table each for every taxon. The harness reads
file locations from the manifest and nowhere else, so a new taxon is
manifest rows plus its files.

### Runs are parallel and reproducible

Each species of each spec is one job. Jobs run on a cluster of R
sessions, each writing a shard of its own, and the shards are joined
in queue order, so a parallel run writes byte for byte what a serial
one does. Draws are seeded per species from one base seed, under R's
default generator named explicitly, so a run's results do not depend
on the number of workers or the order jobs finish in.

## Contract 1: the taxon spec

A spec is data, not code. It is what makes parity auditable: the v2
configuration is a value that can be diffed, not a script that has to be
read.

```r
bryophyte_spec <- list(
  taxon    = "bryophyte",
  response = list(column_source = "bryophyte.csv",
                  transform = "detection"),   # >0 → 1
  family   = "binomial",
  offset   = NULL,
  weights  = NULL,

  regions = list(
    north = list(filter = ~ nr != "Grassland",
                 grid   = "veg_prediction_matrix"),
    south = list(filter = ~ nr %in% c("Grassland", "Parkland"),
                 grid   = "soil_prediction_matrix")),

  stages = list(
    list(name      = "climate",
         models    = "plant_climate_v2",
         engine    = "bayesglm",
         selection = "aic_average"),
    list(name       = "habitat",
         models     = "plant_veg_v2",
         engine     = "bayesglm",
         selection  = "aic_average_ivw",
         carry_from = "climate")),      # previous stage enters as a term

  resample = list(scheme = "spatial_block", n = 100, seed = NULL),
  species  = "modelled_species.csv")
```

`stages` is a list, not a fixed pair. One stage is a joint model; three
stages is a deeper hierarchy. `carry_from` is how v2's climate term
reaches the habitat model, and dropping it is how an experiment asks
whether staging helps at all.

An experiment overrides by name:

```r
run_experiment(
  spec      = bryophyte_spec,
  species   = c("Aulacomnium.palustre", "Sphagnum.fuscum"),
  overrides = list(
    stages = list(climate = list(models = "climate_plus_topography")),
    engine = "gbm"))
```

## Contract 2: the result object

Every run writes the same files, whatever the engine. This is what
makes a GLM run and a BRT run comparable.

| File | Columns | Notes |
| --- | --- | --- |
| `grid_predictions.csv` | species, region, boot, grid_unit, prediction | **the common currency** |
| `unit_predictions.csv` | species, region, boot, survey_unit_id, prediction, observed | optional (`unit_predictions = "oob"` or `"all"`); metrics are scored in memory |
| `coefficients.csv` | species, region, boot, term, estimate, se | absent for engines without coefficients |
| `metrics.csv` | species, region, boot, metric, value | AUC, deviance, calibration |
| `meta.json` | engine, selection, covariate set, spec hash, seed, timing | provenance |

`grid_predictions` is the linchpin. It is the stage's **final** model
projected onto the grid: the averaged or combined one where a rule
combines candidates, not the best single candidate. Every taxon has a
grid; the bird grids are v2's coefficient translation matrix rebuilt
in covariate space by `_setup/09`. Coefficients cannot compare a GLM to
a boosted tree — a tree has no `Peatland` coefficient — but every engine
can predict onto the 43 rows of the vegetation prediction matrix or the
16 of the soil matrix. Comparing there keeps the comparison on the
quantity v2 actually reports, while admitting methods that have no
coefficients at all.

Coefficients are still written when the engine has them, because parity
against v2 is checked on coefficients.

## Choosing covariates

`0_data/test_dataset/lookup/covariate_columns.csv` maps every taxon and
block to a master column name. Named bundles sit on top of it:

```r
covariate_sets <- list(
  veg_all               = "block:veg",       # whatever that block holds
  climate_v2            = c("MAT", "MAP", "PET", "CMD", "FFP", ...),
  climate_common        = c("MAP", "FFP"),   # what all three taxa share
  topography            = c("elevation", "slope", "TRI", ...),
  climate_v2_topography = c("climate_v2", "topography"))
```

An experiment names sets; the harness resolves them against the
catalogue for the chosen taxon and fails loudly on a column that taxon
does not have.

### Covariates are never selected directly

They are read off whatever model formulas a run ends up fitting —
`spec_covariates()` takes `all.vars()` from every candidate. The chain is
one-directional:

```
model set (text formulas)  →  all.vars()  →  covariates loaded
```

That means a spec cannot name a term it forgot to load, and it means
selecting covariates on their own would do nothing: loading `elevation`
while every candidate still fits `MAP + FFP` changes only the I/O.

So **the model set is the lever**, and an experiment sets it directly:

```r
stage_models <- list(
  # the v2 set, plus topography in every candidate
  "climate" = extend_models(
    "climate_plant_v2_full", c("elevation", "slope")
  ),
  # or built from covariates alone
  "mite.climate" = models_from_covariates(
    c("MAP", "FFP", "CMD"), form = "ladder"
  )
)
```

Keys are `taxon.stage`, or `stage` for every taxon. `form` decides the
shape of a covariate comparison — `single`, `each`, `ladder` or
`all_subsets`, the last capped because ten covariates is 1,023 models per
species per draw. Swapping the set changes the covariates automatically:
the v2 plant climate set loads 18, a two-covariate ladder loads 2.

An override is recorded in `meta.json`, so a run that did not fit the v2
candidate sets cannot be mistaken for one that did.

Species are selected the same way, by a named vector whose names are
taxa; names may repeat and an unnamed entry applies to every taxon.

```r
focal_species <- c(
  lichen = "Alectoria.sarmentosa",
  lichen = "Bryoria.fremontii",
  mite   = "Oppiella.nova"
)
```

Sets compose, and `block:<name>` means whatever that block holds for the
taxon being resolved, so a parity run asks for `block:veg` rather than
listing 163 columns. `resolve_covariates(strict = FALSE)` lets each
taxon fit its best available set, with a warning — a legitimate research
choice, never the default, because a silently different model per taxon
would invalidate the comparison.

New covariates — topography, canopy height and cover — enter through a
new `1_code/_setup/` script that extends `covariates.csv` and the
catalogue, with a dataset version bump, so the frozen dataset stays the
single source of truth and `02_validate_test_dataset.R` keeps covering
everything.

## Parity ledger

Parity is strict by default. This section records every place it is
deliberately not, and why. **Nothing is relaxed silently.**

### Kept strict — parity is free here

These cost nothing in usability because they are data or self-contained
strategies:

- Model formula sets, verbatim per taxon and region.
- Family, offset, weights, response transform.
- Prediction grids and the species work queues.
- Selection rules: AICc weighting with IVW averaging (plants), AICc best
  plus GAM age splines (mammals), staged BIC with the ≤ 2 and
  fewest-parameters tie-break (birds).
- Region definitions, normalized to explicit predicates but numerically
  identical.

### Relaxed — no effect on results

Already done in the plants module and carried forward:

| Relaxation | Why it is safe |
| --- | --- |
| No `rm(list = ls())`; no `.GlobalEnv` coupling | Housekeeping, not method |
| Covariates named, not positional (`[403:489]`) | Same columns, and a reordered snapshot can no longer rename every coefficient silently |
| Bootstraps and cores are parameters | Default to the v2 values |
| Paths are arguments | v2 hard-coded a project root |

### Relaxed — flagged, because these change what can be asked

Four places where holding strict parity would defeat the purpose of the
repository. All four are **decided**; the decision is recorded with each.

**1. Unseeded bootstrap RNG. — Decided: seed by default.** v2 sets no
seed, so *v2 is not reproducible against itself*: two v2 runs give
different coefficients. Strict numerical parity is impossible by
construction.

`harness_seed()` in `resample.R` supplies a default of `20260909`, and
every scheme that draws at random uses it unless told otherwise. Passing
`seed = NULL` restores the v2 behaviour explicitly. The seed is written
to each run's `meta.json`.

The consequence stands and is not removed by seeding: **exp_000 can only
demonstrate distributional agreement** — that v2's and the framework's
bootstrap coefficient distributions overlap within Monte Carlo error —
never identical numbers. A numeric parity target, per taxon, still has
to be agreed before the gate is meaningful.

**2. `Protocol` fitted for bryophytes and lichens only. — Decided:
preserve, and expose.** Mites and vascular plants omit the term; the
four v2 scripts are otherwise identical, so this reads as drift rather
than a considered choice. It confounds exactly the cross-taxa comparison
this repository exists to make.

The v2 spec keeps the asymmetry so parity holds. `use_protocol` is
exposed so an experiment can equalize across taxa and report both. Worth
confirming with the plant lead whether it was deliberate.

**3. Mammal climate is read in, not fitted. — Decided: adapt the mammal
climate pipeline into the framework.** Mammals take a climate offset from
`mammal_climate_predictions.csv`; plants and birds fit climate as stage
1. Under strict parity mammals have no climate stage, so no bioclimatic
question could be asked of them at all.

The producing pipeline is `1_code/2_habitat-modeling/climate/` in
`ABbiodiversity/MammalModels` — `00_models.R`, `01_prepare-data.R`,
`02_run-models.R`. It fits nine binomial GLMs over `{FFP, MAP, CMD, TD}`
to presence/absence and averages them by AICc weight, writing
model-averaged coefficients and a per-species AUC to
`Results/Habitat Modeling/2024/Climate/` on the ABMI Mammals drive.

Two findings from adapting it:

- **The mammal and bird climate sets share eight combinations, not
  the whole set.** Written separately by different authors, both use
  the same eight combinations of the same four variables, and
  `model_sets.R` carries them as `climate_bird_mammal_v2`. The bird
  pipeline also fits each of the eight with linear and with quadratic
  spatial terms, 25 candidates in all; those are not in the harness
  yet, and need `Easting` and `Northing`, which the bird covariates
  lack. See the bird spec's `v2_coverage`.
- **Mammal `CMD` and `TD` — resolved.** They were missing from the
  SpTable file the test dataset was first built from. The harmonizer
  now joins the mammal climate from `abmi-camera-climate_2023.Rdata`,
  the file the v2 climate pipeline fitted against, and mammals fit the
  full nine-model set. Two findings from the search still hold:
  - `TD` equals `MWMT - MCMT`, verified against the vascular plant
    table to 0.1 °C, the storage precision of the normals.
  - `CMD` is **not derivable**. The mammal script glosses it as
    "PET − MAP, ≥ 0", but checked against the plant table that formula
    is off by up to 195 mm (r = 0.975): climatic moisture deficit is a
    monthly sum, not an annual difference.

**4. Plants are regularized; mammals and birds are not. — Decided:
`bayesglm` is a registered engine.** Plants fit with `arm::bayesglm`,
the other two with plain `glm`. So "compare GLM across taxa" is not
like for like today: plant coefficients are already shrunk toward zero
and the others are not.

The regularization is load-bearing rather than incidental. Plant models
fit rare species — some detected at ~20 of 6,500 units — against
30-term habitat formulas, where complete separation is near certain and
plain `glm` returns infinite coefficients. Swapping plants to `glm` as
a control will fail outright at the rare end of the species list rather
than give a clean comparison.

`bayesglm` is registered in `engines.R` with the v2 `maxit = 250`, so
plants run at parity. Note that it is penalized maximum likelihood, not
a Bayesian framework: augmented IRLS under weakly informative Cauchy
priors, giving a point estimate and a standard error with no posterior.
It sits on a regularization axis. A Bayesian framework comparison needs
`brms` or `rstanarm`.

## Build order

1. **Built.** Harness data layer and covariate sets.
2. **Built.** Result object and its writers.
3. **Built.** Engines `glm` and `bayesglm`; selection `single`,
   `aic_best`, `aic_average`, `staged_bic`; resample `precomputed`,
   `spatial_block`, `spatial_cv`; metrics.
4. **Built.** Specs for all six taxa, the fitting loop and grid
   prediction.
5. **Built.** `exp_000_parity_v2` runs each spec and compares
   against the published v2 output, on every stage, for all three
   taxa. Five selection rules cover the three pipelines' different
   ideas of what a coefficient is: `aic_average`, `ivw_grid`,
   `staged_bic`, `aic_best_grid` and `aic_best_onehot`.
5a. **Built (2026-10-03).** The plug-in method layer
   (`1_code/methods/`, the registry, `validate_spec()`,
   `check_engine()`); the dataset manifest and harmonized lookups
   (`_setup/09`); parallel species with byte-identical shards;
   metrics and grids from each stage's final model, and grids for
   every taxon; `experiment_config()` and `run_experiment()`; the
   experiment template and `compare_experiments()`; contract tests.
   Checked against the previous code at 5 draws for the 14 parity
   species: every stage's coefficients identical.
6. New engines (`gbm`, `mgcv` GAMs, `brms`) as method files; the
   topography and remote-sensing covariate extension; spatial
   prediction onto the 1 km grid; exp_001 onward.

### What steps 1-3 settled

Three things surfaced in the build that the design had not anticipated:

- **The taxa barely share climate covariates — and one reason was a
  wrong source.** The shared set was two columns (`MAP`, `FFP`).
  Mammals turned out to be carrying the SpTable's climate block, which
  is a different and narrower extraction than the one their models were
  fitted against; joining `abmi-camera-climate_2023.Rdata` instead took
  the shared set to five (`+ TD`, `CMD`, `EMT`) and let mammals fit the
  full 9-model climate set. Birds still lack `MAT` and `PET`.
  `common_covariates()` re-derives this rather than trusting the list.
- **AUC overflowed at bird scale.** `sum()` on a logical returns an
  integer, and 16,745 detections against 199,013 non-detections gives a
  product of 3.3e9, past the 32-bit maximum. It overflowed to `NA`
  silently, so every large run would have reported no AUC. Fixed, with
  the reason recorded at the call site.
- **A weight column has to be loaded before it can be used.** The
  framework now adds it to the covariate request automatically, rather
  than making the caller remember.
