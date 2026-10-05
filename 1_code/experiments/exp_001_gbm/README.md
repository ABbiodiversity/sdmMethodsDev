# exp_001_gbm

![Status](https://img.shields.io/badge/Status-Test-lightgrey)
![Languages](https://img.shields.io/badge/Languages-R-blue)

## Question

Does a boosted regression tree (GBM) fit the habitat stage better than v2's
linear models, for the plant-group taxa and birds?

This is a **test experiment**: its first job is to show that a method with
no coefficients runs through the pipeline and is compared with the v2
baseline. Read its numbers as a result only after a run at 100 draws with
tuned settings.

## Design

| | exp_000 (baseline) | exp_001 (this) |
| --- | --- | --- |
| Climate stage | v2: GLM candidates, AICc model averaging | The same |
| Habitat stage (birds: landcover) | v2: GLM candidates; IVW averaging (plants) or staged BIC (birds); plant stand-age splines and footprint pooling | `gbm` with the `single` rule, on every covariate v2's habitat candidates use, `Climate` included |
| Climate → habitat | Carried as `Climate` | The same |
| Species, draws, seed | `parity_check`, 20260909 | The same |

- **What changes:** the habitat stage's engine, selection rule and
  candidate set, set in `run.R` with `replace_stage_method()`.
- **Why one formula:** a tree chooses its own variables, splits and
  interactions, so it is given every candidate covariate once (as main
  effects) rather than v2's competing formulas.
- **What is dropped with it:** v2's post-processing of habitat coefficients
  (stand-age splines, cutblock convergence, pAspen, footprint pooling) and
  v2's plant validation AUCs, which all read coefficients a tree does not
  have. The metrics score the tree's own prediction.
- **Mammals are not run.** Their habitat stage is v2's hurdle model: two
  linked GLMs with custom post-processing, so there is no single engine to
  swap.

## How to run

From the repository root:

```r
source("1_code/experiments/exp_001_gbm/run.R")
```

`run.R` uses 5 draws to check the pipeline. For a result, set
`n_bootstraps = 100`, and make sure the exp_000 tables it is compared
against are from a 100-draw run of the same species.

## How to read the result

`3_output/exp_001_gbm/tables/`:

| File | Read it for |
| --- | --- |
| `comparison_summary.csv` | Per taxon, region and metric: the median difference from exp_000, and the share of species that did better |
| `comparison_metrics.csv` | Per species, both runs' out-of-bag metrics and 10–90% bands |
| `comparison_grid.csv` | Whether the habitat effects moved: rank correlation and absolute difference on the habitat grid |

Out-of-bag metrics score each draw on the survey units it left out, which
matters here: a tree fits the units it trained on far more closely than a
GLM does, so in-sample metrics would flatter it.

## Assumptions and caveats

- **GBM settings are untuned.** 1000 trees at most, depth 3, learning rate
  0.05, bag fraction 0.5, minimum leaf 10; the number of trees is chosen by
  the out-of-bag estimate, which tends to choose too few. A fair comparison
  tunes these, ideally per taxon.
- **The grid compares like with like only roughly.** The grid holds each
  habitat type as a pure stand at `Climate` 0. A GLM extrapolates to that
  linearly; a tree holds the value of its nearest split. Where a type is
  rare at the survey units, the two can differ for that reason alone.
- **The plant baseline includes v2's post-processing** (stand-age splines,
  footprint pooling); the GBM run does not. A difference in the aged or
  footprint habitat types partly reflects that.
- **Bird counts keep the QPAD offset**, which the engine adds on the link
  scale in fitting and prediction.

## Result

_Not yet run at 100 draws._

**Pipeline check, 2026-10-03: 5 draws, `parity_check` species.** All 100
species × region × draw jobs ran. Against an exp_000 run with the same
species, seed and draws:

| Taxon | Out-of-bag AUC, north (v2 → GBM) | South (v2 → GBM) |
| --- | --- | --- |
| Birds | 0.729 → 0.760 | 0.702 → 0.719 |
| Bryophytes | 0.650 → 0.654 | 0.669 → 0.718 |
| Lichens | 0.803 → 0.814 | 0.792 → 0.847 |
| Soil mites | 0.716 → 0.730 | 0.774 → 0.805 |
| Vascular plants | 0.828 → 0.850 | 0.846 → 0.877 |

GBM's out-of-bag AUC and deviance explained were higher in every taxon and
region, and its calibration slopes sat closer to 1 (0.93–1.07, against
0.61–0.99). Its habitat effects on the grid ranked broadly like v2's for
the plant taxa (rank correlation 0.4–0.97 by species), but not for American
robin in the north (0.08).

**Do not read these as the finding.** Five draws give unstable bands, the
settings are untuned, and two species per taxon is a small sample. They
show the comparison works end to end.
