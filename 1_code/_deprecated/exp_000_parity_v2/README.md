# exp_000_parity_v2

![Status](https://img.shields.io/badge/Status-Partially%20running-yellow)
![Languages](https://img.shields.io/badge/Languages-R-blue)

The validation gate. Runs the v2.0 models through this repository's
pipeline and compares the results against the published species models
v2.0 outputs.

## Question

Does running the rewritten v2 modelling code, on the harmonized test
dataset, through this repository's pipeline reproduce the v2.0 results?

Everything downstream depends on the answer. Later experiments are
compared against this one, so a difference here is a difference in the
plumbing, not in the method being tested.

## Design

| Element | Value |
| --- | --- |
| Taxa | Set per run in `run.R` section 1.4 (`mites <- TRUE`, and so on) |
| Species | Set per taxon in `utils/species_lists.R`; `NULL` runs all |
| Bootstraps | `boot_iter` in `run.R`; must stay at the v2 value of `1:100` for parity |
| Reference | The published v2.0 output — source still to be agreed |
| Target | Not yet defined; to be agreed per taxon |

## Files

| File | Purpose |
| --- | --- |
| `run.R` | Entry point. Paths, taxon flags, stage flags, run length |
| `utils/species_lists.R` | The species vector for each taxon |
| `01_collect_results.R` | Model output → flat summary tables |
| `02_compare_to_v2.R` | The parity comparison itself |
| `03_build_report.R` | Tables and figures → `report.md` |

## How to run

1. Build the test dataset first, if it is not already there — see
   [Setup](../../../README.md#setup) in the repository README. A run needs
   only `0_data/test_dataset/`, not the v2 project.
2. Edit `run.R`:
   - **1.3** where the run reads and writes. The defaults follow the
     repository conventions; point `pipeline_dir` at a scratch disk for a
     long run.
   - **1.4** the taxon flags.
   - **1.5** the stage flags. `02` needs what `01` wrote and `03` needs what
     `02` wrote, so a stage can be run alone only once the ones before it
     have run into the same `pipeline_dir`.
   - **1.6** the run length. Leave it at the v2 values for parity.
3. Name the species in `utils/species_lists.R`. `NULL` runs every modelled
   species; a short vector is the smoke test, and is the right way to
   shorten a trial run since `boot_iter` has to stay at `1:100`.
4. Run from the repository root:

```r
source("1_code/experiments/exp_000_parity_v2/run.R")
```

## Outputs

Intermediates, per taxon, in `pipeline_dir`
(`2_pipeline/exp_000_parity_v2/` by default):

- `<taxon>/bootstrap/` — the per-species bootstrap site ids.
- `<taxon>/models/` — the fitted climate, vegetation and soil
  coefficients. Gitignored; 100 bootstraps by every species by three
  model families is too large to commit.
- `<taxon>/validation/` — the per-bootstrap fit measures.
- `logs/` — one timestamped log per stage.

Deliverables in `out_dir` (`3_output/exp_000_parity_v2/` by default):

- `tables/`, `figures/`, `report.md` — committed, so comparisons
  across experiments can be made from the repository alone.

## Status

The climate and soil model sets run end to end. Three things are
outstanding:

- **The vegetation models cannot be fitted.** The prediction matrix in the
  snapshot is missing four columns the v2 vegetation models are predicted
  onto. See [Known gaps](../../../README.md#known-gaps) — it is one file
  away from working, and `02_hierarchical_models.R` stops with the missing
  columns named rather than failing partway through a run.
- **The v2.0 reference source** is undecided: a frozen snapshot under
  `0_data/` or the external v2 project.
- **The parity target** is undefined, per taxon.

`01`–`03` are placeholders pending the last two.

Note that the v2 bootstrap draws without a fixed seed, so successive runs
of identical code differ. `boot_seed` in `run.R` fixes the stream when a
run needs to be repeatable; `NULL` reproduces v2.
