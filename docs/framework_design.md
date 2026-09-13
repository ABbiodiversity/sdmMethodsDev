# Modelling framework design

![Status](https://img.shields.io/badge/Status-Steps%201--3%20built-yellow)

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
│   ├── data_load.R          # readers + build_model_data + model_frame
│   ├── covariate_sets.R     # named bundles → the column catalogue
│   ├── species.R            # one species catalogue across three schemas
│   ├── resample.R           # precomputed | spatial_block | spatial_cv
│   ├── engines.R            # registry: glm, bayesglm
│   ├── selection.R          # single, aic_best, aic_average, staged_bic
│   ├── eval_metrics.R       # scores computed from predictions only
│   ├── result.R             # the five-file result store
│   └── utils/step_runner.R  # timing and logging
├── modules/
│   ├── _shared/plant_group.R # the four plant-group taxa share this
│   └── <taxon>/spec.R        # that taxon's v2 configuration   (step 4)
├── experiments/exp_NNN_*/
│   └── run.R                # taxon, species, covariates, engine
└── _deprecated/             # superseded; see its README
```

The harness knows nothing about any taxon. A module contributes only a
spec. An experiment overrides parts of a spec.

There are six taxon modules: `bryophytes`, `lichens`, `soil_mites`,
`vascular_plants`, `mammals` and `birds`. The first four were one
`plants` module until they were split, so that a taxon-specific
quirk has one obvious home and the four can diverge. What they still
share is the v2 pipeline shape, which lives in
`_shared/plant_group.R` so four copies cannot drift apart.

Directory names are plural and readable; **taxon slugs are the data
keys and are not**. Soil mites live in `soil_mites/` and key on
`mite`, which is what `run_taxa`, `focal_species` and every harness
call expect.

Files are consolidated rather than one function per file: `engines.R`
holds the registry and both engines, and splits when `gbm` and `brms`
arrive. Two pieces named in the original sketch are deliberately not
built yet, because both depend on decisions a spec makes:

- `predict_grid.R` — projecting a fitted model onto a prediction matrix.
  v2 does this inside its habitat-model functions, and how the terms map
  onto grid rows is spec-dependent. `write_grid_predictions()` is ready
  for it; nothing produces grid predictions yet.
- `run_model.R` — the species-by-bootstrap loop. It is the glue a spec
  drives, so it lands with the first spec.

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

Every run writes the same five files, whatever the engine. This is what
makes a GLM run and a BRT run comparable.

| File | Columns | Notes |
| --- | --- | --- |
| `grid_predictions.csv` | species, region, boot, grid_unit, prediction | **the common currency** |
| `unit_predictions.csv` | species, region, boot, survey_unit_id, prediction, observed | held-out scoring |
| `coefficients.csv` | species, region, boot, term, estimate, se | absent for engines without coefficients |
| `metrics.csv` | species, region, boot, metric, value | AUC, deviance, calibration |
| `meta.json` | engine, selection, covariate set, spec hash, seed, timing | provenance |

`grid_predictions` is the linchpin. Coefficients cannot compare a GLM to
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

- **The mammal and bird climate sets are the same set.** Written
  separately by different authors, they arrived at the same eight
  combinations of the same four variables. `model_sets.R` carries one
  `climate_bird_mammal_v2` covering both; the mammal script's explicit
  null is the harness's base formula.
- **Mammals store neither `CMD` nor `TD`.** The climate pipeline joined
  them from `abmi-camera-climate_2023.Rdata` on `S:/`, which is not the
  SpTable file the test dataset was built from, and is not currently
  mounted.
  - `TD` is **derived** on load as `MWMT - MCMT`, verified against the
    vascular plant table to 0.1 °C, the storage precision of the
    normals.
  - `CMD` is **not derivable**. The mammal script glosses it as
    "PET − MAP, ≥ 0", but checked against the plant table that formula
    is off by up to 195 mm (r = 0.975): climatic moisture deficit is a
    monthly sum, not an annual difference. It must be sourced before
    mammals can fit the full set. `climate_mammal_available` is the
    four-model subset that runs today.

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

1. **Built.** Harness data layer and covariate sets —
   `data_load.R`, `covariate_sets.R`, `species.R`.
2. **Built.** Result object and its writers — `result.R`.
3. **Built.** Engines `glm` and `bayesglm` (`engines.R`); selection
   `single`, `aic_best`, `aic_average`, `staged_bic` (`selection.R`);
   resample `precomputed`, `spatial_block`, `spatial_cv`
   (`resample.R`); metrics (`eval_metrics.R`).
4. **Built.** Specs for all six taxa, in
   `1_code/modules/<taxon>/spec.R`, plus `run_model.R` (the
   species-by-draw-by-stage loop) and `predict_grid.R`.
5. **Built.** `exp_000_parity_v2` runs each spec and compares
   against the published v2 output, on both the climate and the
   habitat stage, for all three taxa. Plants reach **90.9% of
   terms in band** among those the harness fits; the mammal
   presence stage correlates **0.98** with `Coef.pa.all`. Birds
   run but have no reachable reference. Coverage and the
   remaining gaps are in the experiment's README and report.

   Five selection rules now cover the three pipelines'
   different ideas of what a coefficient is: `aic_average`
   (plants and birds, climate), `ivw_grid` (plants, habitat -
   precision-weighted predictions onto a prediction matrix),
   `staged_bic` (birds, landcover), and `aic_best_onehot`
   (mammals - one-hot predictions on the probability scale with
   a calibration shift).
6. Engines `gbm` and `brms`; the topography and remote-sensing covariate
   extension; exp_001 onward.

Steps 1–3 are taxon-agnostic and were built and exercised before any
taxon spec exists. All four taxon-and-region combinations —
bryophyte north, mammal north, mammal south, bird north — run through
one interface, covering the three response types, the offset path and
the weighted path.

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
