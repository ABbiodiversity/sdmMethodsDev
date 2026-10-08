# Worked example: adding an experiment

This walkthrough builds an experiment from start to finish, using
[`exp_002_soilgrids`][exp002] as the example. It asks whether
near-surface soil properties from SoilGrids 2.0 improve the models
for the plant-group taxa and birds.

 To change the engine or selection rule instead, see the
[method-swap worked example](example_experiment_xgboost.md).

Read [Getting started](getting_started.md) first. This page
assumes you can load the framework and reach the published
dataset, and that you know what a spec, stage, and draw are. Run
every code block from the repository root.

- [Before you start](#before-you-start)
- [Step 1: Scaffold the folders](#step-1-scaffold-the-folders)
- [Step 2: Write down the question](#step-2-write-down-the-question)
- [Step 3: Produce the new covariates](#step-3-produce-the-new-covariates)
- [Step 4: Put the covariates in the formulas](#step-4-put-the-covariates-in-the-formulas)
- [Step 5: Configure the run](#step-5-configure-the-run)
- [Step 6: Run it at 5 draws](#step-6-run-it-at-5-draws)
- [Step 7: Check that it worked](#step-7-check-that-it-worked)
- [Step 8: Read the comparison](#step-8-read-the-comparison)
- [Step 9: Run at 100 draws and write it up](#step-9-run-at-100-draws-and-write-it-up)
- [Checklist](#checklist)

## Before you start

You need:

- **Read access to `//ABMI-DATA2`**, for the published dataset and,
  in this example, the SoilGrids layer.
- **exp_000 tables at the draw count you will run.** Every
  experiment is compared with
  `3_output/exp_000_parity_v2/tables/`.
  `run_experiment()` warns when the two differ.
- **Any packages your covariate script needs.** Here, that is
  `sf`, `terra`, and
  [sciSpatialR](https://github.com/ABbiodiversity/sciSpatialR).

## Step 1: Scaffold the folders

`new_experiment()` numbers the experiment and creates its three
folders. `exp_002_soilgrids` already exists, so to follow along,
give your own description. Preview first:

```r
source("1_code/harness/new_experiment.R")
new_experiment("soilgrids walkthrough", dry_run = TRUE)
#> exp_003_soilgrids_walkthrough (dry run; nothing written)
#>   ./1_code/experiments/exp_003_soilgrids_walkthrough
#>   ./2_pipeline/exp_003_soilgrids_walkthrough
#>   ./3_output/exp_003_soilgrids_walkthrough
```

Then drop `dry_run = TRUE` to create them. You get:

```
1_code/experiments/<id>/
├── README.md     # the question; from _template/
└── run.R         # the decisions; id, title, author, date filled in
2_pipeline/<id>/
└── logs/
3_output/<id>/
├── figures/
├── tables/
└── report.md     # a stub
```

Leave `id` in `run.R` as it is. The rest of this page fills in
those two files and adds one script beside them.

## Step 2: Write down the question

Before writing code, fill in the experiment's `README.md`. Its
sections come from the template: Question, Design, How to read the
result, Result, and Assumptions and caveats.

The most useful part is a design table that says what changes
relative to exp_000 and what does not. exp_002's:

| | exp_000 (baseline) | exp_002 (this) |
| --- | --- | --- |
| Climate stage | v2's candidates (plants 58, birds 25), model-averaged | The same candidates, each with the nine soil terms added |
| Climate → habitat | Carried as `Climate` | The same; the carried prediction now includes soil |
| Habitat stage | v2 | v2, unchanged |
| Species, draws, seed | `parity_check`, 20260909 | The same |

Write down the reasoning for each choice while you still have it.
exp_002 records three:

- **Why the climate stage.** It is fitted once, province-wide, so
  one set of formulas serves every region. Adding soil to the
  habitat stage would need different formulas per region and a
  soil value for every row of the habitat grids.
- **Why every candidate gets the terms.** The comparison between
  candidates stays v2's, so the only change is the soil.
- **Why mammals are left out.** Their v2 climate is a precomputed
  prediction, not a fitted stage, and their deployments have no
  coordinates in the dataset.

One change per experiment. If you find yourself changing two
things, make two experiments.

## Step 3: Produce the new covariates

The test dataset is frozen: never add columns to `0_data/` or
change `_setup/` for an experiment. Instead, write a script in the
experiment's folder that saves a CSV to `2_pipeline/<id>/inputs/`.
exp_002's is
[`01_extract_soilgrids_covariates.R`][exp002-extract].

### The file contract

`experiment_config()` checks the file with
`check_covariate_files()` before anything is fitted. The file must:

- have a `survey_unit_id` column, with **one row per unit** (no
  repeats);
- use **column names not already in `covariates.csv`** or another
  covariate file. exp_002 prefixes every column with `sg_` for
  this reason.

Units the file does not list, or lists with `NA`, drop out of any
model that uses the column. That is how exp_002 handles mammals with no coordinates and twelve plant-group units just outside the
1 km grid. Report how many units that removes, as exp_002's README
does, because those models fit on fewer units than exp_000.

### What the script does

The essentials of exp_002's script, in order:

```r
library(data.table)
library(sciSpatialR)
library(sf)

# 1. Locate the survey units, read only, from the published dataset
source("1_code/harness/data_source.R")
sites <- fread(
  file.path(test_dataset_dir(), "sites.csv"),
  select = c("survey_unit_id", "easting", "northing"),
  colClasses = list(character = "survey_unit_id")
)

# 2. Read the layer from the catalogue and keep the 0-5 cm bands
soil <- get_layer(
  "geoscientificInformation/soilgrids_250_v2_ab/abmi1km"
)
soil <- soil[[grep("_0-5cm_mean$", names(soil), value = TRUE)]]

# 3. Extract at each located unit (EPSG:3400, the layer's grid)
located <- sites[!is.na(easting) & !is.na(northing)]
points <- st_as_sf(
  located, coords = c("easting", "northing"), crs = 3400
)
values <- extract_points(soil, points, bind = FALSE)

# 4. Write one row per survey unit, NA where there is no value
#    (soil_table is built from `values`; see the full script)
fwrite(
  soil_table,
  "2_pipeline/exp_002_soilgrids/inputs/soilgrids_0_5cm.csv",
  na = ""
)
```

Read the full script for the steps this excerpt skips: renaming
bands to `sg_<property>_0_5cm`, checking that exactly ten bands
were found, matching rows back to every unit, and a printed
report. It also writes `soilgrids_0_5cm_source.csv`, recording the
layer, DOI, depth, date, and method, so the inputs can be traced
later. Do the same for your own covariates.

The script reads `SDM_SOILGRIDS`, adjust to use a local copy of
the raster instead of the share.

## Step 4: Put the covariates in the formulas

The covariates a run loads are read off the formulas it fits. So
naming a column in a formula is all it takes for the harness to
join it from `covariate_files`.

Use `stage_models` in `run.R`. Keys are `stage` (every taxon in
the run) or `taxon.stage` (one taxon). exp_002 needs different v2
sets for plants and birds, so it uses `taxon.stage` keys:

```r
# Silt is left out: sand, silt, and clay sum to 100%
soil_terms <- c(
  "sg_bdod_0_5cm", "sg_cec_0_5cm", "sg_cfvo_0_5cm",
  "sg_clay_0_5cm", "sg_sand_0_5cm", "sg_nitrogen_0_5cm",
  "sg_phh2o_0_5cm", "sg_soc_0_5cm", "sg_ocd_0_5cm"
)

plant_taxa <- c("bryophyte", "lichen", "mite", "vascular_plant")

stage_models <- c(
  stats::setNames(
    rep(list(extend_models("climate_plant_v2_full", soil_terms)),
        length(plant_taxa)),
    paste0(plant_taxa, ".climate")
  ),
  list(bird.climate = extend_models("climate_bird_v2", soil_terms))
)
```

`extend_models()` takes a named v2 candidate set and adds the
terms to every formula in it, so the set keeps its size:

```r
bird_soil <- extend_models(
  "climate_bird_v2", c("sg_clay_0_5cm", "sg_sand_0_5cm")
)
length(bird_soil)
#> [1] 25
bird_soil[1]
#> [1] ". ~ . + sg_clay_0_5cm + sg_sand_0_5cm"
```

To build a candidate set from covariates alone instead, see
`models_from_covariates()` in `1_code/harness/model_sets.R`.


## Step 5: Configure the run

Everything else in `experiment_config()` matches exp_000, so the
comparison is like for like:

```r
config <- experiment_config(
  id = "exp_002_soilgrids",
  taxa = c(plant_taxa, "bird"),
  species = "parity_check",     # exp_000's species
  n_bootstraps = 5,             # 5 checks; 100 for a result
  seed = 20260909,              # exp_000's seed
  stage_models = stage_models,  # the change
  covariate_files = soil_file,  # where the sg_ columns come from
  workers = 12
)
```

`soil_file` is the CSV from Step 3. exp_002's `run.R` also runs
the extraction script when that file is missing, so one `source()`
call does everything:

```r
soil_file <- "2_pipeline/exp_002_soilgrids/inputs/soilgrids_0_5cm.csv"

if (!file.exists(soil_file)) {
  source(file.path(
    "1_code", "experiments", "exp_002_soilgrids",
    "01_extract_soilgrids_covariates.R"
  ))
}
```

Delete the CSV to extract again.

`experiment_config()` checks the covariate file (Step 3's
contract), the runs named in `taxa`, and the draw count before
anything is fitted, and prints what it will do. A problem with any
of them stops it here, not hours in.

## Step 6: Run it at 5 draws

The last section of `run.R` is one call:

```r
results <- run_experiment(
  config,
  translate = list(bird = bird_habitat_translation)
)
```

`translate` puts bird landcover coefficients onto v2's habitat
template, as exp_000 does. Keep it whenever birds are in the run.

Then run the whole script:

```r
source("1_code/experiments/exp_002_soilgrids/run.R")
```

Parallel workers load the framework from disk as they start, so do
not edit files in `1_code/` while the run is starting.

## Step 7: Check that it worked

Before reading any metric, confirm the run did what you asked.

**Every job ran.** `2_pipeline/<id>/run_log.csv` has one row per
taxon, species, region, and draw, with `status` `ok` or the reason
it failed:

```r
library(data.table)

run_log <- fread("2_pipeline/exp_002_soilgrids/run_log.csv")
run_log[, .N, by = .(taxon, status)]
```

`run_experiment()` prints the same table at the end of fitting.

**The right things were written.** `3_output/<id>/tables/coverage.csv`
has one row per run and region. `species = 0` means nothing ran;
check `run_log.csv` for why.

**The change is on record.** `run_record.md` in `3_output/<id>/`
lists the `stage_models` keys and the covariate files. Each store's `meta.json`
records the covariates fitted and `models_overridden`, so a run
that did not fit the v2 sets cannot be mistaken for one that did.

## Step 8: Read the comparison

`run_experiment()` compares the run with exp_000 automatically. It
prints a headline per taxon, region, and metric: the median
difference from exp_000, and `share_better`, the share of species
that did better. It writes the per-species detail to
`3_output/<id>/tables/comparison_metrics.csv`:

```r
comparison <- fread(
  "3_output/exp_002_soilgrids/tables/comparison_metrics.csv"
)
comparison[metric == "oob_auc", .(
  taxon, region, species,
  median_baseline, median_candidate, difference, better
)]
```

| Column | Means |
| --- | --- |
| `median_baseline`, `p10_baseline`, `p90_baseline` | exp_000's median and 10-90% band over draws |
| `median_candidate`, `p10_candidate`, `p90_candidate` | This run's |
| `n_baseline`, `n_candidate` | Draws behind each side |
| `difference` | Candidate median minus baseline median |
| `better` | Whether the candidate moved the right way for that metric |

The metrics are out-of-bag: each draw scored on the units it left
out. "Better" is higher AUC, deviance explained, and Spearman;
lower RMSE; and a calibration slope closer to 1.

A difference is worth reading only if it is consistent across
species (`share_better`) and large relative to the bands. **A
5-draw run is a pipeline check, not a result.** Its bands are
unstable, and `parity_check` is two species per taxon. Say so
wherever you report it, as exp_002's README does.

## Step 9: Run at 100 draws and write it up

When the 5-draw run is clean:

1. Set `n_bootstraps = 100` in `run.R`, and run again.
2. Compare it with a 100-draw exp_000. Check `n_baseline` and
   `n_candidate` in `comparison_metrics.csv` are both 100.
3. Fill in the README's **Result** section. Report the comparison
   and say what was run (species, draws, date).
4. Fill in **Assumptions and caveats**. exp_002's are a model:
   what the covariate does and does not represent (a 1 km cell is
   not a plot), correlated terms (so individual coefficients are
   hard to interpret), units dropped for missing values, and the
   extra parameters.
5. Commit the code folder and the small summaries in
   `3_output/<id>/`: `run_record.md`, `report.md`, and the
   `tables/` files `.gitignore` keeps. Commit only runs that count,
   every species at 100 draws, and check `run_record.md` says so.
   `2_pipeline/` is never committed.

## Checklist

- [ ] Scaffolded with `new_experiment()`; `id` in `run.R`
      unchanged.
- [ ] Question, design table, and reasoning in the README before
      the first run.
- [ ] One change relative to exp_000; species, seed, and draws
      match it.
- [ ] New covariates written by a script in the experiment folder
      to `2_pipeline/<id>/inputs/`, never to `0_data/`, with a
      source record.
- [ ] Covariate file has one row per `survey_unit_id` and new
      column names.
- [ ] Units lost to missing values counted and reported.
- [ ] 5-draw run: `run_log.csv` all `ok`, `coverage.csv` complete,
      comparison written.
- [ ] 100-draw run compared with a 100-draw exp_000 before any
      result is written.
- [ ] Result, assumptions, and caveats in the README.

[exp002]: https://github.com/ABbiodiversity/sdmMethodsDev/blob/main/1_code/experiments/exp_002_soilgrids/README.md
[exp002-extract]: https://github.com/ABbiodiversity/sdmMethodsDev/blob/main/1_code/experiments/exp_002_soilgrids/01_extract_soilgrids_covariates.R
