<img src="docs/images/abmi_logo.png" alt="ABMI Logo" width="300" style="margin-top: 40px;">

# SDMs Methods Development
![In Development](https://img.shields.io/badge/Status-In%20Development-yellow)
![Lifecycle](https://img.shields.io/badge/Lifecycle-Experimental-orange)
![Languages](https://img.shields.io/badge/Languages-R-blue)

<img src="docs/images/science_centre_logo_unofficial.png" alt="ABMI Science Centre (Unofficial)" width="185">

> [!IMPORTANT]
> This repository is developed by and for the Science Centre at the Alberta Biodiversity Monitoring
Institute (ABMI). It is intended for internal use.
> 

Shared pipeline and static cross-taxa test dataset for methods R&D on ABMI
species models.

## Contents

- [Overview](#overview)
- [Status](#status)
- [Directory structure](#directory-structure)
  - [`0_data/`](#0_data)
  - [`1_code/`](#1_code)
  - [`2_pipeline/`](#2_pipeline)
  - [`3_output/`](#3_output)
- [Parity gate](#parity-gate)
- [Known gaps](#known-gaps)
- [Naming conventions](#naming-conventions)
- [Adding an experiment](#adding-an-experiment)
- [Contributing a taxon module](#contributing-a-taxon-module)
- [Setup](#setup)
- [Related resources](#related-resources)
- [Contact](#contact)

## Overview

A shared environment for testing methods across taxa. It holds a static cross-taxa test dataset and a companion R&D pipeline: a taxon-agnostic harness, thin taxon-specific modules, and a versioned covariate catalogue.

Because the dataset and pipeline are fixed, R&D questions can be run once across all taxa rather than reimplemented per taxon, and results stay comparable over time.

This repository is for methods research and development. It is not for the final species models and does not generate reporting products.

## Status

| Component | State |
| --- | --- |
| Repository and pipeline structure | In development |
| Static test dataset | Built from the `model_ready_v2` snapshot; responses and covariates for plants and mammals; validated |
| Taxon modules | Plants run on the test dataset; mammal covariates sourced but no module yet; birds not started |
| v2.0 parity check (`exp_000`) | Climate and soil models run; vegetation blocked on a missing lookup |


## Pipeline flow

Three layers, each with one job. Code flows down; results flow back up.

```
0_data/test_dataset/                  (a) the frozen dataset
        │                                 responses, covariates, lookups; read only
        │  read by
        ▼
1_code/modules/<taxon>/0N_*.R         (b) taxon modules
        │                                 the modelling stages, in order
        │  sourced by
        ▼
1_code/experiments/exp_00x_*/run.R    (c) experiments
                                          paths, taxon flags, species vectors
```

An experiment run does two things:

1. **Configures.** `run.R` is the only file to edit. It sets where the run
   reads and writes (`data_dir`, `pipeline_dir`, `out_dir`), which taxa and
   stages run, the species vector per taxon, and the run length.
2. **Runs.** `run_step()` sources each module stage in order, timing it and
   mirroring its output to a log.

Nothing outside `pipeline_dir` and `out_dir` is written during a run, and
`0_data/` is never written to outside `1_code/_setup/`.

### Where the modelling code came from

`0_data/v2_scripts/<taxon>/` holds the scripts as received from the taxon
leads. They are kept unmodified as the reference the rewrite is checked
against, and are **not run**. The runnable code is
`1_code/modules/<taxon>/`, rewritten so that:

- **Paths are arguments.** v2 hard-coded `0_data/species/processed/…` and
  `3_output/models/…` relative to the v2 project root. Every path is now
  set by the calling experiment.
- **Inputs come from the test dataset.** v2 loaded a
  `<taxon>-model-data.Rdata`; `load_model_data.R` rebuilds the same three
  frames — `climate.data`, `veg.data`, `soil.data` — from the harmonized
  CSVs.
- **The four near-identical scripts per stage became one.** v2's `02a`–`02d`
  differed only in the taxon they loaded and in whether they fitted a
  `Protocol` term, so they are one script parameterized by `taxon`. Same for
  `03a`–`03d`.
- **Covariates are named, not positional.** v2 built its vegetation
  coefficient template from `colnames(veg.data)[403:489]`, with a different
  span per taxon. Those spans are all the same 87 habitat types, which are
  now named.
- **Run length is configurable.** `boot.iter <- 1:100` and
  `n.clusters <- 14` were hard-coded in every `02x`. They default to the v2
  values and can be lowered for a smoke test.

The rewrite is checked against the originals rather than trusted: all 42
model formulas per taxon and both coefficient templates are reproduced
exactly, and `1_code/_setup/02_validate_test_dataset.R` traces every value
in the dataset back to the snapshot.

## Directory structure

```
sdm_methods_dev/
├── README.md
│
├── 0_data/                        # read-only inputs; written only by 1_code/_setup/
│   ├── manifest.md                # dataset version, paths, checksums
│   ├── covariates/                # versioned catalogue (metadata; rasters on server)
│   │   └── catalogue_v1.csv
│   ├── test_dataset/              # frozen: built by 1_code/_setup/01_
│   │   ├── sites.csv              # one row per survey unit, all sources
│   │   ├── vascular_plant.csv     # survey_unit_id + species columns
│   │   ├── bryophyte.csv
│   │   ├── lichen.csv
│   │   ├── mite.csv
│   │   ├── mammal.csv
│   │   ├── covariates/            # what the models regress against
│   │   │   ├── <taxon>_climate.csv
│   │   │   ├── <taxon>_veg.csv    # north: vegetation and HF
│   │   │   ├── <taxon>_soil.csv   # south: soil and HF
│   │   │   ├── mammal_north_climate.csv
│   │   │   ├── mammal_north_veg.csv
│   │   │   ├── mammal_south_climate.csv
│   │   │   └── mammal_south_soil.csv
│   │   └── lookup/
│   │       ├── veg_prediction_matrix.csv
│   │       ├── soil_prediction_matrix.csv
│   │       ├── modelled_species.csv   # the work queue, per plant taxon
│   │       ├── mammal_<region>_prediction_matrix.csv
│   │       ├── mammal_modelled_species.csv
│   │       └── mammal_climate_predictions.csv
│   └── v2_scripts/                # as-received snapshots; reference only
│       ├── README.md              # sources, commits, snapshot date
│       ├── birds/
│       ├── mammals/
│       └── plants/
│
├── 1_code/
│   ├── _setup/                    # one-off; not run per experiment
│   │   ├── 01_harmonize_model_ready_v2.R
│   │   ├── 02_validate_test_dataset.R
│   │   └── _scratch.R             # temporary workspace
│   ├── harness/                   # shared, taxon-agnostic
│   │   ├── data_load.R
│   │   ├── data_split.R
│   │   ├── covar_attach.R
│   │   ├── eval_metrics.R
│   │   └── utils/                 # helpers outside the processing sequence
│   │       └── step_runner.R      # run_step(): timing and logging
│   ├── modules/                   # taxon-specific modelling code
│   │   ├── birds/
│   │   ├── mammals/
│   │   └── plants/
│   │       ├── load_model_data.R  # test dataset → the v2 model frames
│   │       ├── 01_bootstrap_ids.R
│   │       ├── 02_hierarchical_models.R
│   │       ├── 03_model_validation.R
│   │       └── functions/         # the v2 function files, unmodified
│   └── experiments/
│       ├── exp_000_parity_v2/
│       │   ├── README.md          # question, design, how to run
│       │   ├── run.R              # paths, taxon flags, stage flags
│       │   ├── utils/
│       │   │   └── species_lists.R  # species vector per taxon
│       │   ├── 01_collect_results.R
│       │   ├── 02_compare_to_v2.R
│       │   └── 03_build_report.R
│       ├── exp_001_description/
│       └── exp_002_description/
│
├── 2_pipeline/                    # intermediates, cached; gitignored
│   ├── exp_000_parity_v2/
│   │   ├── logs/                  # one log per pipeline step
│   │   └── <taxon>/               # bootstrap/, models/, validation/
│   └── exp_001_description/
│
└── 3_output/                      # deliverables; committed
    ├── exp_000_parity_v2/
    │   ├── figures/
    │   ├── tables/
    │   └── report.md
    └── exp_001_description/
```


### `0_data/`

Read-only during experiments. The one exception is `1_code/_setup/`, which
builds `test_dataset/` by hand and once per source snapshot; nothing in the
harness, modules, or experiments writes here.

`test_dataset/` holds the frozen cross-taxa dataset. Its contents do not
change between experiments. Amendments require a version increment and a
corresponding update to `manifest.md`.

`covariates/catalogue_v1.csv` is a versioned catalogue of covariate layers.
It stores metadata and server paths only; rasters live on the ABMI server.
Unlike the test dataset, the catalogue is extensible: new covariates can be
added under a new catalogue version without invalidating the dataset.

`test_dataset/covariates/` holds what the models regress against: one
climate, one vegetation and one soil table per plant-group taxon, each keyed
on `survey_unit_id` like the response tables. They are written per taxon
rather than once because the four source files do not agree — bryophyte,
lichen and vascular plant share identical values on shared survey units, but
mite does not, which points at a different spatial support or HF vintage in
the mite source.

Seven columns are deliberately **not** stored: `Easting2`, `Northing2`,
`EastingNorthing`, `MAPPET`, `MAT2`, `CMDMAT` and `MWMT2`. They are products
of other stored columns, and `load_model_data.R` recomputes them. A CSV
carries about 15 significant digits, so a separately stored `Northing2`
would not equal `Northing` squared, and a model fitting both would see an
inconsistent pair.

Mammal covariates come from the same two `SpTable` files as the mammal
response, because those files are themselves the output of the v2 scripts in
`0_data/v2_scripts/mammals/`. They are written **per region** rather than per
taxon: north and south are separate models on overlapping deployments — 512
`location_project` values appear in both files — so their covariates cannot
be stacked into one table the way the response is. The north habitat block is
VegHF age classes, the south block is soil types, matching the model each
one feeds.

`test_dataset/lookup/` holds the habitat prediction matrices and the work
queues — which species each model set is fitted for, and in what order — that
the v2 scripts read out of the `.Rdata`.

Mammals get their own `mammal_modelled_species.csv` rather than rows in
`modelled_species.csv`, because their queue is season by occurrence
threshold: `sp_table_*` are the species with at least 20 detections, which
get the full habitat model, and `sp_table_*_ua` those with at least 3, which
get the use-availability model. The plant north/south schema has no room for
that.

`mammal_climate_predictions.csv` is the climate offset the mammal habitat
models take. Unlike the plant pipeline, which fits climate itself in `02`,
the mammal models read a prediction produced by a separate climate pipeline,
so it is copied in and re-keyed on `survey_unit_id`. 509 of 5822 deployments
have no prediction and carry `NA`, which is what the v2 join produced.

The mammal prediction matrices are taken from the snapshot rather than the
ABMI Mammals drive: the embedded `pred_matrix` objects were checked against
`prediction-matrix_north.csv` and `Prediction matrix for ABMI South
coefficients 2020.csv` and are identical.

`v2_scripts/` holds modelling scripts as received from taxon leads,
unmodified, in one subfolder per taxon. They are the reference the rewritten
modules are checked against and are **not run**. Subfolder names match those
under `1_code/modules/`.

All three are cloned snapshots taken on 2026-09-08. Their sources and
commits are recorded in [`0_data/v2_scripts/README.md`](0_data/v2_scripts/README.md),
which is also where a refreshed snapshot gets logged.

`manifest.md` records dataset version and file paths, and is what experiment
configurations point at. It and `v2_scripts/` are the tracked parts of this
folder; the data itself is gitignored.

### `1_code/`

`harness/` holds the shared, taxon-agnostic pipeline: loading the frozen
dataset, applying the evaluation split, attaching covariates, and computing
evaluation metrics. Changes here affect every experiment, past and future,
and should be reviewed accordingly.

`harness/utils/` holds helpers that sit outside the processing sequence.
`step_runner.R` supplies `run_step()`, which sources one module stage, times
it, and mirrors its output to a timestamped log.

`_setup/` holds one-off scripts that prepare the repository itself. Nothing
here runs as part of an experiment: these are run by hand, once, when the
repository or its dataset is first assembled or a source snapshot is
replaced. They are numbered because they have a run order among themselves,
and the leading underscore keeps them sorted clear of the run-time code.

`_setup/01_harmonize_model_ready_v2.R` reads the six `model_ready_v2`
snapshot files (four plant-group `.Rdata` files and the two mammal
`SpTable` files) and writes them to `0_data/test_dataset/` as CSVs
sharing one convention: `sites.csv` holds one row per survey unit with
every identity, design and location field, and one CSV per taxon
(`vascular_plant`, `bryophyte`, `lichen`, `mite`, `mammal`) holds
`survey_unit_id` plus that taxon's species columns. Join any taxon CSV to
`sites.csv` on `survey_unit_id`.

It also writes the covariate and lookup tables described above, so the
modelling code can run from `0_data/test_dataset/` alone rather than
reaching back to the snapshot.

Mammal species names are resolved against `WildTrax Species Strings.RData`
on the ABMI Mammals shared drive, so the North and South files reach the
same column name by way of that lookup rather than a local naming rule. A
species the lookup does not carry keeps its source spelling and is reported
at run time; as of the 2024 snapshot that is `Raccoon` alone.

`_setup/02_validate_test_dataset.R` is run after it, and again whenever
the snapshot or the harmonizer changes. It makes two passes over the
result: the first describes the six CSVs (sizes, coverage, value ranges,
and whether the two-file layout joins), and the second traces every
written value back to the snapshot it came from, ending in a pass/fail
tally. That second pass does not call the harmonizer's functions and
restates the few rules it needs, so a bug there shows up rather than
cancelling itself out. It writes nothing, so it is safe to re-run.

`_setup/_scratch.R` is a dated workspace for exploration. Work that
proves durable is promoted into a numbered script and removed from it.

Set `SDM_SNAPSHOT_V2` and `SDM_WT_SPECIES` to read the snapshot and the
lookup from somewhere other than ABMI-DATA2 and the shared drive, and
`SDM_V2_LOOKUP` to the v2 project folder holding the two prediction-matrix
CSVs (see [Known gaps](#known-gaps)).

`modules/` holds taxon-specific modelling code.
Modules stay thin (just what is needed to run a model): experiment-specific logic
belongs in the experiment, not the module. Note that not all taxa need every
component, for example QPAD offsets apply to birds but not to plants.

For plants, `load_model_data.R` rebuilds the three frames the v2 code
expects — `climate.data`, `veg.data` and `soil.data` — from the harmonized
CSVs, and is also where `plant_taxa()` records which taxa fit a `Protocol`
term. The numbered scripts are the stages, in order:

| Stage | Reads | Writes |
| --- | --- | --- |
| `01_bootstrap_ids.R` | `data_dir` | `run_dir/bootstrap/` |
| `02_hierarchical_models.R` | `data_dir`, `run_dir/bootstrap/` | `run_dir/models/` |
| `03_model_validation.R` | `data_dir`, `run_dir/models/` | `run_dir/validation/` |

Each reads `taxon`, `data_dir`, `run_dir`, `species_subset`, `boot_iter` and
`n_clusters` from the calling experiment, and falls back to documented
defaults when run on its own. `functions/` holds the v2 function files
unmodified — they are the modelling method itself and were not rewritten.

`experiments/` holds one folder per R&D question. Each contains a `README.md`
stating the question and design, a `run.R` entry point, and numbered scripts.
Experiments call the harness and modules; they do not reimplement them.

`run.R` is where the user decides what runs, and the only file that has to
be edited to change a run: the three paths in section 1.3, the taxon flags
in 1.4, the stage flags in 1.5, the run length in 1.6, and the species
vectors in `utils/species_lists.R`. The numbered scripts turn the model
output into the committed deliverables.

Output locations are the experiment's to choose. `pipeline_dir` takes the
intermediates and `out_dir` the deliverables; both can point anywhere
writable — a scratch disk for a long run, say — and nothing else changes.

### `2_pipeline/`

Intermediate and cached files, organized by experiment. Gitignored.

Each taxon gets a run root here, `<exp_id>/<taxon>/`, shaped like the v2
project: `0_data/` for the staged inputs, `1_code/r-scripts/` for the v2
function files, and `3_output/` for the raw model and validation objects the
v2 scripts write. Those raw objects stay here — 100 bootstraps by every
species by three model families is too large to commit.

### `3_output/`

Committed deliverables, organized by experiment. Because outputs are tracked,
comparisons across experiments and over time can be made from the repository
alone.

Only derived artefacts belong here: summary tables, figures, and the report.

## Parity gate

`exp_000` is the validation gate. It runs the v2.0 models through this
repository's code pipeline and compares the results against the species models v2.0
outputs.

Experiment results will be compared against the results of `exp_000`.

Two things are still needed before the gate can be closed:

- The vegetation prediction matrix — see [Known gaps](#known-gaps).
- The minimum acceptable parity target, which has not been defined and will
  need to be agreed per taxon.

One thing the gate has to account for: the v2 bootstrap resamples without a
fixed seed, so two runs of the same code do not produce identical
coefficients. `boot_seed` in `run.R` fixes the stream when a run needs to be
repeatable; leaving it `NULL` reproduces v2's behaviour.

## Known gaps

**The vegetation models cannot be fitted yet.** The v2 `02x` scripts read
their habitat prediction matrices from two CSVs in the v2 project:

```
0_data/lookup/prediction-matrix/veg-prediction-matrix-CC_2024.csv
0_data/lookup/prediction-matrix/soil-prediction-matrix_2024.csv
```

Neither is in the `model_ready_v2` snapshot. The snapshot carries `veg.pm`
and `soil.pm` instead, and those are not the same objects: `veg.pm` has no
column for `Peatland`, `Mineral`, `Upland` or `CCR1234`, which four of the
twelve vegetation models are predicted onto. `soil.pm` is complete, so the
climate and soil models run today.

Set `SDM_V2_LOOKUP` to the folder holding those two CSVs and re-run
`1_code/_setup/01_harmonize_model_ready_v2.R`; they are preferred over the
snapshot copies whenever they are reachable. Until then
`02_hierarchical_models.R` stops before fitting anything, naming the missing
columns, and `02_validate_test_dataset.R` reports the same as its one
failing check.

## Naming conventions

| Item | Convention | Example |
| --- | --- | --- |
| Experiments | `exp_NNN_short_description` | `exp_001_covariate_scale` |

An experiment identifier is used verbatim in `1_code/experiments/`,
`2_pipeline/`, and `3_output/`. Derive all three paths from a single variable
in `run.R` rather than typing the identifier per stage.

## Adding an experiment

1. Copy `1_code/experiments/exp_000_parity_v2/` to
   `exp_00N_short_description/` and create the matching folders under
   `2_pipeline/` and `3_output/`.
2. Set `exp_id` in `run.R` to the new identifier. Every other path derives
   from it.
3. State the question and design in the experiment's `README.md`.
4. Set the taxon flags in `run.R` and the species vectors in
   `utils/species_lists.R`.
5. Write the numbered scripts. They read what the modules produced in
   `2_pipeline/<exp_id>/` and write to `3_output/<exp_id>/`.

Experiment-specific logic stays in the experiment. If a change is needed in
`harness/` or `modules/`, it affects every experiment and should be reviewed
on that basis.

## Contributing a taxon module

1. Put the scripts as received in `0_data/v2_scripts/<taxon>/`, unmodified.
   They are the reference, and are never edited and never run.
2. Extend `1_code/_setup/01_harmonize_model_ready_v2.R` to write that
   taxon's covariates and lookups into `0_data/test_dataset/`, and
   `02_validate_test_dataset.R` to trace them back to the snapshot.
3. Add `1_code/modules/<taxon>/`, modelled on `plants/`: a
   `load_model_data.R` that rebuilds the frames the scripts expect, the
   numbered stages, and `functions/` for the v2 function files.
4. Take every path as a parameter, with a documented default. A stage
   should read `taxon`, `data_dir`, `run_dir` and `species_subset` from the
   caller and hard-code nothing.
5. Check the rewrite against the originals rather than trusting it. For
   plants that meant reproducing all 42 model formulas per taxon and both
   coefficient templates exactly.
6. Note any deviation from these conventions, and why, in the script header.

Module folder names match the subfolder names under `0_data/v2_scripts/`, so
each module has an obvious reference. Soil mites currently sit in `plants/`
for that reason.

## Setup

R 4.4 or later, plus the packages the v2 modelling code uses:

```r
install.packages(c(
  "data.table", "foreach", "AICcmodavg", "arm", "binom",
  "mapproj", "mgcv", "MuMIn", "pROC", "RcmdrMisc"
))
```

Build the test dataset once per snapshot, from the repository root:

```r
source("1_code/_setup/01_harmonize_model_ready_v2.R")
source("1_code/_setup/02_validate_test_dataset.R")
```

Both read the sources over the network. Set these when they are not in the
default locations:

| Variable | Points at |
| --- | --- |
| `SDM_SNAPSHOT_V2` | the `model_ready_v2` snapshot folder |
| `SDM_WT_SPECIES` | `WildTrax Species Strings.RData` |
| `SDM_V2_LOOKUP` | the v2 folder holding the two plant prediction-matrix CSVs |
| `SDM_MAMMAL_CLIMATE_PRED` | `All Species Climate Predictions.csv` |

Then run an experiment, also from the repository root:

```r
source("1_code/experiments/exp_000_parity_v2/run.R")
```

Building the dataset needs the snapshot; running an experiment does not.

## Related resources

- [code_standards](https://github.com/ABbiodiversity/code_standards) — Science
  Centre coding conventions
- [sciCentRverse](https://github.com/ABbiodiversity/sciCentRverse) — Science
  Centre R functions



## Contact

For any questions regarding the contents of this repository or data access, please contact Brendan Casey at brendan.casey@ualberta.ca.
