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
| Static test dataset | Not yet assembled |
| Taxon modules | Plants (v2 runners) scaffolded; birds and mammals not started |
| v2.0 parity check (`exp_000`) | Scaffolded; not yet run |


## Pipeline flow

Three layers, each with one job. Code flows down; results flow back up.

```
0_data/v2_scripts/<taxon>/            (a) untouchable v2 code
        │                                 as received; never edited, never run in place
        │  sourced by
        ▼
1_code/modules/<taxon>/run_v2_*.R     (b) taxon modules
        │                                 one per taxon; runs its two v2 scripts in order
        │  sourced by
        ▼
1_code/experiments/exp_00x_*/run.R    (c) experiments
                                          taxon flags + species vectors; drives everything
```

An experiment run does three things in order:

1. **Selects.** `run.R` sets taxon flags (`mites <- TRUE`) and reads the
   species vector for each taxon from `utils/species_lists.R`.
2. **Stages.** `stage_v2_inputs()` builds a v2-shaped run root under
   `2_pipeline/<exp_id>/<taxon>/` and copies the data into it, with the
   species queue narrowed to the requested vector.
3. **Runs.** The module runner sources the unmodified v2 scripts with the
   working directory set to that run root, so their relative paths resolve
   inside the sandbox.

Nothing outside `2_pipeline/` is written during a run, and no v2 script is
edited.

### How a species vector reaches an unmodified script

The v2 scripts take no arguments. They build their work queue from disk:

```r
species.list <- unique(c(veg.species.list, soil.species.list))   # 02x
```

So a species selection is applied by rewriting **those two vectors only**
in a staged copy of `<taxon>-model-data.Rdata`. Every other object is
staged untouched — `02x` addresses covariates positionally, as
`colnames(veg.data)[1408:1494]`, so dropping species columns would shift
those indices and break the v2 code.

`bootstrap.ids` is staged whole; the v2 code reads it as
`boot.data[[species]]`, so extra entries are ignored.

Species count is the only way to shorten a run: `boot.iter <- 1:100` and
`n.clusters <- 14` are hard-coded in every `02x` script.

## Directory structure

```
sdm_methods_dev/
├── README.md
│
├── 0_data/                        # read-only inputs; nothing written here by code
│   ├── manifest.md                # dataset version, paths, checksums
│   ├── covariates/                # versioned catalogue (metadata; rasters on server)
│   │   └── catalogue_v1.csv
│   ├── test_dataset/              # frozen: response records, design, evaluation split
│   └── v2_scripts/                # as-received from leads, unmodified
│       ├── birds/
│       ├── mammals/
│       └── plants/
│
├── 1_code/
│   ├── harness/                   # shared, taxon-agnostic
│   │   ├── data_load.R
│   │   ├── data_split.R
│   │   ├── covar_attach.R
│   │   ├── eval_metrics.R
│   │   └── utils/                 # helpers outside the processing sequence
│   │       ├── v2_script_runner.R # run_step() and the pre-run checks
│   │       └── stage_v2_inputs.R  # species vector → staged run root
│   ├── modules/                   # taxon-specific; one runner per taxon
│   │   ├── birds/
│   │   ├── mammals/
│   │   └── plants/
│   │       ├── run_v2_bryophytes.R
│   │       ├── run_v2_lichens.R
│   │       ├── run_v2_mites.R
│   │       └── run_v2_vascular_plants.R
│   └── experiments/
│       ├── exp_000_parity_v2/
│       │   ├── README.md          # question, design, how to run
│       │   ├── run.R              # taxon flags; stages and sources modules
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
│   │   └── <taxon>/               # staged run root + raw v2 model output
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

Read-only. Nothing in this folder is written by code in this repository.

`test_dataset/` holds the frozen cross-taxa dataset. Its contents do not
change between experiments. Amendments require a version increment and a
corresponding update to `manifest.md`.

`covariates/catalogue_v1.csv` is a versioned catalogue of covariate layers.
It stores metadata and server paths only; rasters live on the ABMI server.
Unlike the test dataset, the catalogue is extensible: new covariates can be
added under a new catalogue version without invalidating the dataset.

`v2_scripts/` holds modelling scripts as received from taxon leads,
unmodified, in one subfolder per taxon. Subfolder names match those under
`1_code/modules/`, so each module has an obvious reference.

`manifest.md` is the only tracked file in this folder. It records dataset
version, file paths, and is what experiment configurations
point at.

### `1_code/`

`harness/` holds the shared, taxon-agnostic pipeline: loading the frozen
dataset, applying the evaluation split, attaching covariates, and computing
evaluation metrics. Changes here affect every experiment, past and future,
and should be reviewed accordingly.

`harness/utils/` holds helpers that sit outside the processing sequence.
`v2_script_runner.R` supplies `run_step()`, which sources a v2 script with
the working directory set to its run root and mirrors output to a log; it
also restores the runner's own objects afterwards, because every v2 script
opens with `rm(list = ls())`. `stage_v2_inputs.R` builds the run root.

`modules/` holds taxon-specific modelling code.
Modules stay thin (just what is needed to run a model): experiment-specific logic
belongs in the experiment, not the module. Note that not all taxa need every
component, for example QPAD offsets apply to birds but not to plants.

Each `run_v2_<taxon>.R` names that taxon's v2 scripts, lists the inputs they
read, and runs them in order behind `run_*` flags. It takes `v2_root`,
`log_path`, and its flags from the calling experiment when they are set, and
falls back to `SDM_V2_ROOT` when run on its own.

`experiments/` holds one folder per R&D question. Each contains a `README.md`
stating the question and design, a `run.R` entry point, and numbered scripts.
Experiments call the harness and modules; they do not reimplement them.

`run.R` is where the user decides what runs: taxon flags in one section,
species vectors sourced from `utils/species_lists.R`, then one block per
taxon that stages inputs and sources that taxon's module. The numbered
scripts turn the raw v2 output into the committed deliverables.

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

The minimum acceptable parity target has not yet been defined and will need
to be agreed per taxon. 

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
   They are never edited and never run in place.
2. Add `1_code/modules/<taxon>/run_v2_<name>.R`, modelled on the plants
   runners. It supplies the script names, the input list, and the step
   order; `run_step()` and the checks come from `harness/utils/`.
3. Check what the scripts read at startup. If they build a species queue
   from an object on disk, `stage_v2_inputs()` needs to know which object
   to rewrite for that taxon.
4. Note any deviation from these conventions, and why, in the module's
   header.

Module folder names match the subfolder names under `0_data/v2_scripts/`, so
each module has an obvious reference. Soil mites currently sit in `plants/`
for that reason.

## Setup


## Related resources

- [code_standards](https://github.com/ABbiodiversity/code_standards) — Science
  Centre coding conventions
- [sciCentRverse](https://github.com/ABbiodiversity/sciCentRverse) — Science
  Centre R functions



## Contact

For any questions regarding the contents of this repository or data access, please contact Brendan Casey at brendan.casey@ualberta.ca.
