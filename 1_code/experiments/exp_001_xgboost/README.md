# exp_001_xgboost

![Status](https://img.shields.io/badge/Status-Test-lightgrey)
![Languages](https://img.shields.io/badge/Languages-R-blue)

## Question

Does a boosted regression tree fit the habitat stage better than v2's linear
models, for every taxon: the plant-group taxa, mammals and birds?

This is a **test experiment**: its first job is to show that a method with
no coefficients runs through the pipeline for every taxon and is compared
with the v2 baseline. Read its numbers as a result only after a run at 100
draws with tuned settings.

## Design

| | exp_000 (baseline) | exp_001 (this) |
| --- | --- | --- |
| Climate stage | v2: GLM candidates, AICc model averaging (mammals: v2's precomputed prediction) | The same |
| Habitat stage (each spec's `habitat_stage`; birds: landcover) | v2: GLM candidates; IVW averaging (plants), staged BIC (birds), or the hurdle with best-by-AICc halves (mammals); v2's post-processing | `xgboost` with the `single` rule, on every covariate v2's habitat candidates use, `Climate` included |
| Climate → habitat | Carried as `Climate` | The same |
| Species, draws, seed | `parity_check`, 20260909 | The same |

- **What changes:** the habitat stage's engine, selection rule and
  candidate set. `run.R` makes the change with one call for every run:
  `lapply(standard_specs(), replace_stage_method, engine = "xgboost",
  control = xgb_settings)`.
- **Why one formula:** a tree chooses its own variables, splits and
  interactions, so it is given every candidate covariate once (as main
  effects) rather than v2's competing formulas.
- **Mammals.** The habitat stage is the generic `hurdle` rule. Its
  structure stays: presence on every deployment, on v2's lure-scaled
  response (`binary:logistic`, which takes a proportion), then abundance
  given presence on the deployments with detections (`reg:gamma`, a
  log-link Gamma), unweighted and without `Climate`, as in v2. Boosted
  trees fit both halves. The hurdle writes `habitat_presence`,
  `habitat_abundance` and `habitat_total` (their product) as grid
  predictions, the same tables v2 publishes.
- **What is dropped:**
  - v2's post-processing of habitat coefficients: the plant stand-age
    splines, cutblock convergence, pAspen and footprint pooling, and v2's
    plant validation AUCs;
  - the mammal one-hot tables, calibration, stand-age splines, Mule Deer
    adjustment and cutblock convergence.

  These all read coefficients a tree does not have. The metrics score the
  tree's own prediction: presence, for mammals.

## How to run

From the repository root:

```r
source("1_code/experiments/exp_001_xgboost/run.R")
```

It reads the published test dataset and exp_000's
`3_output/exp_000_parity_v2/tables/`, and writes stores to
`2_pipeline/exp_001_xgboost/` and summaries to
`3_output/exp_001_xgboost/`.

`run.R` uses 5 draws to check the pipeline. For a result, set
`n_bootstraps = 100`, and make sure the exp_000 tables it is compared
against are from a 100-draw run of the same species.

## How to read the result

`3_output/exp_001_xgboost/tables/`:

| File | Read it for |
| --- | --- |
| `comparison_metrics.csv` | Per species, both runs' out-of-bag metrics and 10–90% bands |

Out-of-bag metrics score each draw on the survey units it left out, which
matters here: a tree fits the units it trained on far more closely than a
GLM does, so in-sample metrics would flatter it.

## Assumptions and caveats

- **The xgboost settings are untuned.** At most 1000 rounds, learning
  rate 0.05, depth 3, subsample 0.5, minimum child weight 1 (`run.R`
  section 1.2). The number of rounds is chosen by early stopping on a
  seeded 20% holdout of each draw, then the model is refitted on all of
  the draw. A fair comparison tunes
  these, ideally per taxon.
- **The grid compares like with like only roughly.** The grid holds each
  habitat type as a pure stand at `Climate` 0. A GLM extrapolates to that
  linearly; a tree holds the value of its nearest split. Where a type is
  rare at the survey units, the two can differ for that reason alone.
- **The baseline includes v2's post-processing** (stand-age splines,
  footprint pooling, and for mammals calibration and convergence); this
  run does not. A difference in the aged, cutblock or footprint habitat
  types partly reflects that.
- **Mammal grid predictions are presence**, as in exp_000. Abundance and
  total are compared through the `habitat_abundance` and `habitat_total`
  coefficient summaries. Note that exp_000's mammal tables are v2's
  calibrated tables, so they are not like for like with this run's
  uncalibrated grid predictions.
- **Bird counts keep the QPAD offset**, which the engine passes as the
  base margin in fitting and prediction.
- **gbm was replaced.** The first version of this experiment
  (`exp_001_gbm`, 2026-10-03) used `gbm`, which cannot fit the mammal
  hurdle: its bernoulli rejects a 0–1 proportion and it has no Gamma
  family.

## Result

_Not yet run at 100 draws._

**Pipeline check, 2026-10-05: 5 draws, `parity_check` species.** All 160
species × region × draw jobs ran, mammals included. Against the exp_000
tables (whose draw counts match):

| Taxon | Out-of-bag AUC, north (v2 → xgboost) | South (v2 → xgboost) |
| --- | --- | --- |
| Birds | 0.729 → 0.769 | 0.702 → 0.745 |
| Bryophytes | 0.650 → 0.681 | 0.669 → 0.754 |
| Lichens | 0.803 → 0.827 | 0.792 → 0.860 |
| Mammals, summer | 0.704 → 0.727 | 0.660 → 0.684 |
| Mammals, winter | 0.741 → 0.768 | 0.710 → 0.725 |
| Soil mites | 0.716 → 0.739 | 0.774 → 0.811 |
| Vascular plants | 0.828 → 0.869 | 0.846 → 0.905 |

xgboost's out-of-bag AUC was higher in every taxon, region and season.
Except for birds, and soil mites in the south, its calibration slopes were
further from 1 than v2's.
Mammal slopes fell from 0.65–0.85 to 0.53–0.72, so the untuned trees are
overconfident there. The median rank correlation of the habitat grid
effects with v2's was 0.28–0.73 by taxon and region, but about 0 for
soil mites in the north. Mammals were 0.69 in the north and 0.68 in the
south.

**Do not read these as the finding.** Five draws give unstable bands, the
settings are untuned, and two species per taxon is a small sample. They
show the comparison works end to end, for every taxon.
