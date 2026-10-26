# temp_bird: bird coefficients on old vs new Stratified.Rdata

A one-off check. Five birds (AMRO, YEWA, WTSP, CCSP, SAVS) are fitted
with the v2 bird spec on two copies of the test dataset that differ
only in the bird data:

- **Data 2025** (folder `new`): the published test dataset
  (2026-10-05), harmonized from v2's own `Stratified.Rdata`
  (`remote/birds_data_v2/`).
- **Data 2026-08** (folder `old`): the same dataset with the bird
  inputs taken from
  `0_data/test_dataset_backup_2026-10-02_aug2026_birds/`, harmonized
  from the BirdModels drive's `Data/Archive/2025/Stratified.Rdata`,
  which was rebuilt on 2026-08-19.

Both fits are compared with the v2 target: the pinned ABMIexploreR
reference for climate and translated habitat types, and v2's archived
per-draw files for the landcover model's own coefficients.

## Run order

From the repository root:

| Script | Does | Writes |
| --- | --- | --- |
| `01_build_old_dataset.R` | Copies the published dataset and swaps in the old bird inputs (~860 MB) | `2_pipeline/temp_bird/test_dataset_old/` |
| `02_fit_old_new.R` | Fits the five birds, 100 draws, seed 20260909, on both datasets (roughly 15–30 min each on 12 workers) | `2_pipeline/temp_bird/<new\|old>/` |
| `03_read_v2_landcover.R` | Reads v2's raw landcover coefficients, 1,000 per-draw files from the BirdModels archive (a few minutes, cached) | `2_pipeline/temp_bird/v2_landcover_draws.csv` |
| `04_plot_old_new_target.R` | Joins both fits to the v2 targets as exp_000 does, flags parity, and plots them | `3_output/temp_bird/figures/`, `tables/` |
| `05_correlate.R` | Pearson and Spearman tests between target, Data 2025 and Data 2026-08 coefficient medians, per species and component and pooled | `3_output/temp_bird/tables/bird_coefficient_correlations.csv` |
| `06_compare_draws.R` | Compares each run's 100 bootstrap climate coefficients with v2's 100 as two sets (Kolmogorov-Smirnov, Wilcoxon rank-sum), per predictor and species (reads 500 v2 files once, cached) | `3_output/temp_bird/tables/bird_climate_draw_comparison.csv` |

`run.R` runs all six; set a step to `FALSE` there to skip it.

## Outputs

- `bird_climate_variables_old_new_target.png`: the same, for the four
  climate variables only (MAP, FFP, TD, CMD), without the intercept
  or the spatial terms.
- `bird_landcover_first5_old_new_target.png`: the first five landcover
  variables per region in v2's model order (north: vegcCrop to
  vegcMarsh; south: soilcBlowout to soilcMine), without the intercept
  or the carried climate term.
- `bird_climate_old_new_target.png`,
  `bird_landcover_north_old_new_target.png` and
  `bird_landcover_south_old_new_target.png`: bootstrapped model
  coefficients on their own scale, one panel per term (rows) and
  species (columns), with v2 target, new and old in each: the median
  of 100 bootstrap fits and its 10–90% range. Landcover terms are
  summarized over the draws in which they were selected, on both
  sides.
- `bird_old_new_summary.csv`: per species and component, old against
  new, the share of terms at parity, the median standardized
  difference and band ratio, and a `parity` verdict (pass/fail) from
  exp_000's `parity_verdict()`.
- `bird_old_new_target_terms.csv`: one row per term, with exp_000's
  per-term flags: `in_band`, `within_tolerance` and `parity`.
- Each panel's axis is constrained to v2's 10–90% band plus one band
  width either side; a value beyond it is drawn at the edge with its
  real value labelled.
- `bird_coefficient_correlations.csv`: one row per species (or all
  five pooled), component, pair and method, with r, p-value and the
  number of terms. Read Spearman: terms span orders of magnitude, so
  Pearson is set by the largest ones.
- `bird_climate_draw_comparison.csv`: per predictor and species, each
  run's 100 bootstrap coefficients against v2's 100, unpaired: KS D
  and p (any difference in distribution), Wilcoxon p (a shift), and
  the median difference raw and in units of half v2's 10–90% range.
- The tables also score the translated habitat types (`stage` =
  `habitat`), the form exp_000 gates; they are not plotted.

Everything it writes is under gitignored folders. Delete
`1_code/temp_bird/`, `2_pipeline/temp_bird/` and `3_output/temp_bird/`
when done.
