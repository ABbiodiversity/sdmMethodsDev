<img src="docs/images/abmi_logo.png" alt="ABMI Logo" width="300" style="margin-top: 40px;">

# SDMs Methods Development
![In Development](https://img.shields.io/badge/Status-In%20Development-yellow)
![Lifecycle](https://img.shields.io/badge/Lifecycle-Experimental-orange)
![Languages](https://img.shields.io/badge/Languages-R-blue)

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
| Taxon modules | Not yet built |
| v2.0 parity check (`exp_000`) | Not yet run |


## Directory structure

```
sdm_methods_dev/
├── README.md
├── .Rprofile
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
│   │   └── eval_metrics.R
│   ├── modules/                   # taxon-specific, standard interface
│   │   ├── birds/                 # prepare.R, offsets.R, fit.R, module.yml
│   │   ├── mammals/
│   │   └── plants/
│   └── experiments/
│       ├── exp_000_description/
│       │   ├── README.md
│       │   ├── run.R
│       │   ├── 01_script.R
│       │   ├── 02_script.R
│       │   └── 03_script.R
│       ├── exp_001_description/
│       └── exp_002_description/
│
├── 2_pipeline/                    # intermediates, cached; gitignored
│   ├── exp_000_description/
│   │   └── logs/                  # log files
│   └── exp_001_description/
│
└── 3_output/                      # deliverables; committed
    ├── exp_000_description/
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

`modules/` holds taxon-specific modelling code. 
Modules stay thin (just what is needed to run a model): experiment-specific logic
belongs in the experiment, not the module. Note that not all taxa need every
component, for example QPAD offsets apply to birds but not to plants.

`experiments/` holds one folder per R&D question. Each contains a `README.md`
stating the question and design, a `run.R` entry point, and numbered scripts.
Experiments call the harness and modules; they do not reimplement them.

### `2_pipeline/`

Intermediate and cached files, organized by experiment. Gitignored.

### `3_output/`

Committed deliverables, organized by experiment. Because outputs are tracked,
comparisons across experiments and over time can be made from the repository
alone.

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


## Contributing a taxon module


## Setup


## Related resources

- [code_standards](https://github.com/ABbiodiversity/code_standards) — Science
  Centre coding conventions
- [sciCentRverse](https://github.com/ABbiodiversity/sciCentRverse) — Science
  Centre R functions



## Contact

For any questions regarding the contents of this repository or data access, please contact Brendan Casey at brendan.casey@ualberta.ca.
