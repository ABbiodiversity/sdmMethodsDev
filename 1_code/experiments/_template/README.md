# exp_NNN_short_description

![Status](https://img.shields.io/badge/Status-Planned-lightgrey)
![Languages](https://img.shields.io/badge/Languages-R-blue)

## Question

One sentence: what does this experiment ask?

## Design

- **What changes relative to exp_000:** the one thing this
  experiment varies (a covariate, a model set, an engine, a
  selection rule).
- **What stays the same:** taxa, species, draws and seed, unless
  they are the question.
- **How it is set:** `stage_models` or `specs` in `run.R`.

## How to read the result

Every experiment is compared with the v2 baseline (exp_000):
`run_experiment()` prints the headline per taxon, region and
metric (median difference, and the share of species that did
better), and writes one comparison table to `3_output/<id>/tables/`:

| File | One row per | Read it for |
| --- | --- | --- |
| `comparison_metrics.csv` | species and metric | Which species moved, with both runs' 10-90% bands |

The metrics are out-of-bag: each draw scored on the survey units it
left out. "Better" is higher AUC, deviance explained and Spearman,
lower RMSE, and a calibration slope closer to 1.

## Result

_To be written after a full run._

## Assumptions and caveats

-
