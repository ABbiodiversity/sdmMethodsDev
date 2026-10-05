# exp_002_soilgrids

![Status](https://img.shields.io/badge/Status-Test-lightgrey)
![Languages](https://img.shields.io/badge/Languages-R-blue)

## Question

Does adding near-surface soil properties from SoilGrids 2.0 improve the
models, for the plant-group taxa and birds?

This is a **test experiment**: its first job is to show that a covariate set
from the Science Centre's spatial catalogue
([sciSpatialR](https://github.com/ABbiodiversity/sciSpatialR)) can be tested
against the v2 baseline without changing the frozen dataset. Read its numbers as a
result only after a run at 100 draws.

## The covariates

SoilGrids 2.0 (Poggio et al. 2021, SOIL 7: 217–240;
doi:10.17027/isric-soilgrids.713396fa-1687-11ea-a7c0-a0481ca9e724), the ABMI
1 km variant in the catalogue (`geoscientificInformation/soilgrids_250_v2_ab/
abmi1km`), at its shallowest depth, 0–5 cm.

| Column | Property | Units | In the models |
| --- | --- | --- | --- |
| `sg_bdod_0_5cm` | Bulk density | kg/dm3 | yes |
| `sg_cec_0_5cm` | Cation exchange capacity | cmol(c)/kg | yes |
| `sg_cfvo_0_5cm` | Coarse fragments | vol % | yes |
| `sg_clay_0_5cm` | Clay | % | yes |
| `sg_sand_0_5cm` | Sand | % | yes |
| `sg_silt_0_5cm` | Silt | % | **no**: sand, silt and clay sum to 100%, so one is fixed by the other two |
| `sg_nitrogen_0_5cm` | Nitrogen | g/kg | yes |
| `sg_phh2o_0_5cm` | pH in water | pH | yes |
| `sg_soc_0_5cm` | Soil organic carbon | g/kg | yes |
| `sg_ocd_0_5cm` | Organic carbon density | kg/m3 | yes |

They are extracted by `01_extract_soilgrids_covariates.R` in this folder,
which takes the value of the 1 km cell each survey unit falls in and writes
`2_pipeline/exp_002_soilgrids/inputs/soilgrids_0_5cm.csv` (one row per survey
unit) with its source in `soilgrids_0_5cm_source.csv`. `run.R` names that file
in `experiment_config(covariate_files = )`, and the harness joins it on
`survey_unit_id` when it loads the data. `0_data/` and `_setup/` are not
touched. Organic carbon stock is published for 0–30 cm only and is not
included.

## Design

| | exp_000 (baseline) | exp_002 (this) |
| --- | --- | --- |
| Climate stage | v2's candidates (plants 58, birds 25), model-averaged | The same candidates, each with the nine soil terms added |
| Climate → habitat | Carried as `Climate` | The same; the carried prediction now includes soil |
| Habitat stage | v2 | v2, unchanged |
| Species, draws, seed | `parity_check`, 20260909 | The same |

- **Why the climate stage.** It is fitted once, province-wide, so one set of
  formulas serves every region, and it is v2's broad-scale environmental
  stage. Adding soil to the habitat stage instead would need different
  formulas per region and a soil value for every row of the habitat grids.
- **Every candidate gets the terms** (`extend_models()`), so the comparison
  between candidates is v2's and the only change is the soil.
- **Mammals are not run.** Their v2 climate is a precomputed prediction rather
  than a fitted stage, and their deployments carry no coordinates in the
  dataset, so they have no soil values.

## How to run

From the repository root:

```r
source("1_code/experiments/exp_002_soilgrids/run.R")
```

`run.R` runs the extraction first if the soil file is missing. That step
reads the layer from the `//ABMI-DATA2` share; set `SDM_SOILGRIDS` to a local
copy of the raster to read it from there instead. Delete the file to extract
again.

`run.R` uses 5 draws to check the pipeline. For a result, set
`n_bootstraps = 100` and compare against a 100-draw exp_000.

## How to read the result

Every experiment is compared with exp_000; see
`3_output/exp_002_soilgrids/tables/comparison_*.csv`. The habitat effects on
the grid (`comparison_grid.csv`) show whether adding soil to the climate stage
moved the habitat estimates through the carried `Climate` term.

## Assumptions and caveats

- **A 1 km cell is not a plot.** Each survey unit takes the mean of its 1 km
  cell, aggregated from SoilGrids' 250 m predictions, which are themselves
  model predictions, not measurements. Gap-filled cells are interpolated.
- **Some soil terms are correlated**: bulk density with coarse fragments
  (r = −0.83) and pH (0.79), sand with clay (−0.80), nitrogen with organic
  carbon (0.75). Model averaging spreads weight across them, so individual
  soil coefficients are hard to interpret; the fit metrics and grid
  predictions are the reliable read.
- **Raw units, unscaled.** As in v2's climate stage; `bayesglm` scales
  predictors internally for its priors.
- **Twelve plant-group survey units have no soil value** (just outside the
  1 km grid), so the climate stage fits on those 12 fewer units than
  exp_000. No bird unit is missing.
- **More parameters.** Each candidate gains nine terms; the AICc weights
  penalize them, but the averaged model is larger than v2's.

## Result

_Not yet run at 100 draws._

**Pipeline check, 2026-10-04: 5 draws, `parity_check` species.** All 100
species × region × draw jobs ran. Against exp_000 at the same species, seed
and draws:

| Taxon | Out-of-bag AUC, north (v2 → soil) | South (v2 → soil) |
| --- | --- | --- |
| Birds | 0.729 → 0.732 | 0.702 → 0.715 |
| Bryophytes | 0.650 → 0.657 | 0.669 → 0.664 |
| Lichens | 0.803 → 0.803 | 0.792 → 0.811 |
| Soil mites | 0.716 → 0.716 | 0.774 → 0.787 |
| Vascular plants | 0.828 → 0.824 | 0.846 → 0.842 |

The differences are small and mixed in sign, and calibration slopes moved
slightly away from 1 for most taxa. Habitat effects on the grid barely moved
(rank correlation with exp_000 of 0.86–1.00 by species).

**Do not read these as the finding.** Five draws give unstable bands and two
species per taxon is a small sample. They show the covariates load and the
comparison works end to end.
