# exp_000_parity_v2

Generated 2026-10-06 05:25:57

**Trial run.** 14 focal species, 5 of 100 draws. Its parity numbers show the pipeline ran; they are not a parity read.

Draws: `seed = 20260909`, one derived seed per species.

## What each spec reproduces of v2

Read from each spec's `v2_coverage`, which is where coverage is
stated. Change it there, not here.

| taxon | stage | status | note |
| --- | --- | --- | --- |
| bryophyte | climate | reproduced | The v2 58-model set, bayesglm, full AICc averaging, fitted once per draw on every unit and shared by both regions, as v2 fits it. |
| bryophyte | habitat | reproduced | IVW on the prediction grid, the stand-age splines, cutblock convergence, footprint pooling, the south pAspen and the 20-detection skip. Matches v2 to 2e-12 on the full-data draw, north and south. |
| bryophyte | validation | reproduced | v2's seven validation AUCs, in-bag as v2 scores them and out-of-bag as well. South exact; north within 2e-4, a residual v2's own coefficients show too. |
| bryophyte | resampling | reproduced | v2's spatial-block bootstrap, drawn once per species across the province with its 20-detection redraw rule. The same method, not the same draws: v2 is unseeded. |
| lichen | climate | reproduced | The v2 58-model set, bayesglm, full AICc averaging, fitted once per draw on every unit and shared by both regions, as v2 fits it. |
| lichen | habitat | reproduced | IVW on the prediction grid, the stand-age splines, cutblock convergence, footprint pooling, the south pAspen and the 20-detection skip. Matches v2 to 2e-12 on the full-data draw, north and south. |
| lichen | validation | reproduced | v2's seven validation AUCs, in-bag as v2 scores them and out-of-bag as well. South exact; north within 2e-4, a residual v2's own coefficients show too. |
| lichen | resampling | reproduced | v2's spatial-block bootstrap, drawn once per species across the province with its 20-detection redraw rule. The same method, not the same draws: v2 is unseeded. |
| mite | climate | reproduced | The v2 58-model set, bayesglm, full AICc averaging, fitted once per draw on every unit and shared by both regions, as v2 fits it. |
| mite | habitat | reproduced | IVW on the prediction grid, the stand-age splines, cutblock convergence, footprint pooling, the south pAspen and the 20-detection skip. Matches v2 to 2e-12 on the full-data draw, north and south. |
| mite | validation | reproduced | v2's seven validation AUCs, in-bag as v2 scores them and out-of-bag as well. South exact; north within 2e-4, a residual v2's own coefficients show too. |
| mite | resampling | reproduced | v2's spatial-block bootstrap, drawn once per species across the province with its 20-detection redraw rule. The same method, not the same draws: v2 is unseeded. |
| vascular_plant | climate | reproduced | The v2 58-model set, bayesglm, full AICc averaging, fitted once per draw on every unit and shared by both regions, as v2 fits it. |
| vascular_plant | habitat | reproduced | IVW on the prediction grid, the stand-age splines, cutblock convergence, footprint pooling, the south pAspen and the 20-detection skip. Matches v2 to 2e-12 on the full-data draw, north and south. |
| vascular_plant | validation | reproduced | v2's seven validation AUCs, in-bag as v2 scores them and out-of-bag as well. South exact; north within 2e-4, a residual v2's own coefficients show too. |
| vascular_plant | resampling | reproduced | v2's spatial-block bootstrap, drawn once per species across the province with its 20-detection redraw rule. The same method, not the same draws: v2 is unseeded. |
| mammal_summer | climate | reproduced | v2's precomputed climate prediction, read per species; deployments without one are dropped, as in v2. |
| mammal_summer | habitat | reproduced | v2's hurdle: presence, abundance and total abundance on the full habitat set, with the stand-age splines, calibration and cutblock convergence. Matches v2's published tables to 2e-14, north and south. |
| mammal_summer | resampling | partial | Spatial-block bootstrap. v2 fits the habitat stage once, so only iteration 1, the full data, is like for like. |
| mammal_summer | season | reproduced | One season per spec; run.R runs both, and the gate averages them as v2's `.all` references do. |
| mammal_winter | climate | reproduced | v2's precomputed climate prediction, read per species; deployments without one are dropped, as in v2. |
| mammal_winter | habitat | reproduced | v2's hurdle: presence, abundance and total abundance on the full habitat set, with the stand-age splines, calibration and cutblock convergence. Matches v2's published tables to 2e-14, north and south. |
| mammal_winter | resampling | partial | Spatial-block bootstrap. v2 fits the habitat stage once, so only iteration 1, the full data, is like for like. |
| mammal_winter | season | reproduced | One season per spec; run.R runs both, and the gate averages them as v2's `.all` references do. |
| bird | climate | reproduced | v2's 25 candidates, AICc averaged, fitted once on the province-wide draw, unweighted, and carried as exp(link) without the offset, as MuMIn predicts it. |
| bird | landcover | reproduced | Staged BIC over v2's groups, weighted by vegw or soilw, always advancing to each group's winner. Raw coefficients are translated onto v2's standardized template by standardize.R, a port checked exact against v2's packaged output. |
| bird | resampling | reproduced | v2's 100 stored draws, keyed on surveyid, each survey once per draw as v2's %in% selects them. Only when harmonized from the Stratified.Rdata v2 was fitted on (58,210 surveys per draw); the BirdModels Data/Archive/2025 copy was rewritten on 2026-08-19 with different draws. |

## v2 references

Scored against `abmiexplorer`, built by `1_code/_setup/08_harmonize_abmiexplorer_results.R`. What it holds, from `v2_results_coverage.csv`:

| source_label | reachable | rows | species | note |
| --- | --- | --- | --- | --- |
| amphibian north habitat | TRUE | 364 | 4 | - |
| amphibian south habitat | FALSE | 0 | 0 | - |
| amphibian all climate | TRUE | 44 | 4 | - |
| bird north habitat | TRUE | 10609 | 103 | - |
| bird south habitat | TRUE | 1747 | 65 | - |
| bird all climate | TRUE | 1240 | 124 | - |
| bryophyte north habitat | TRUE | 12154 | 118 | - |
| bryophyte south habitat | TRUE | 673 | 25 | - |
| bryophyte all climate | TRUE | 2242 | 118 | - |
| lichen north habitat | TRUE | 13596 | 132 | - |
| lichen south habitat | TRUE | 1206 | 45 | - |
| lichen all climate | TRUE | 2755 | 145 | - |
| mammal north habitat | TRUE | 5760 | 15 | - |
| mammal south habitat | TRUE | 1079 | 13 | - |
| mammal all climate | TRUE | 105 | 21 | - |
| mite north habitat | TRUE | 9785 | 95 | - |
| mite south habitat | TRUE | 755 | 28 | - |
| mite all climate | TRUE | 2052 | 108 | - |
| vascular_plant north habitat | TRUE | 32754 | 318 | - |
| vascular_plant south habitat | TRUE | 6257 | 233 | - |
| vascular_plant all climate | TRUE | 8246 | 434 | - |

What this run's comparison could not reach:

_Every taxon and region that ran had a reference to compare against._

## What ran

| taxon | run | region | season | part | species | draws | stages | has_coefficients | has_grid |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| bird | bird | north | - | - | 2 | 5 | climate, landcover, habitat | TRUE | TRUE |
| bird | bird | south | - | - | 2 | 5 | climate, landcover, habitat | TRUE | TRUE |
| bryophyte | bryophyte | north | - | - | 2 | 5 | climate, habitat | TRUE | TRUE |
| bryophyte | bryophyte | south | - | - | 2 | 5 | climate, habitat | TRUE | TRUE |
| lichen | lichen | north | - | - | 2 | 5 | climate, habitat | TRUE | TRUE |
| lichen | lichen | south | - | - | 2 | 5 | climate, habitat | TRUE | TRUE |
| mammal | mammal_summer | north | summer | hurdle | 2 | 5 | habitat_presence, habitat_abundance, habitat_total | TRUE | TRUE |
| mammal | mammal_summer | south | summer | hurdle | 2 | 5 | habitat_presence, habitat_abundance, habitat_total | TRUE | TRUE |
| mammal | mammal_winter | north | winter | hurdle | 2 | 5 | habitat_presence, habitat_abundance, habitat_total | TRUE | TRUE |
| mammal | mammal_winter | south | winter | hurdle | 2 | 5 | habitat_presence, habitat_abundance, habitat_total | TRUE | TRUE |
| mite | mite | north | - | - | 2 | 5 | climate, habitat | TRUE | TRUE |
| mite | mite | south | - | - | 2 | 5 | climate, habitat | TRUE | TRUE |
| vascular_plant | vascular_plant | north | - | - | 2 | 5 | climate, habitat | TRUE | TRUE |
| vascular_plant | vascular_plant | south | - | - | 2 | 5 | climate, habitat | TRUE | TRUE |

## Parity against v2, by stage

Every stage is compared against `v2_results.csv`. Climate is
scored against v2's province-wide fit in both regions. Terms v2
fixes at a placeholder are left out of the reachable scores.

`verdict` reads each row against the parity targets in `utils/parity_targets.R` (proposed, not yet agreed): numerical rows (iteration 1) pass when every reachable term is within 1e-06; distributional rows when at least 90% of reachable terms are in band, the median standardized difference is at most 0.25, and the median band-width ratio (this run's band over v2's) is between 0.75 and 1.33. `median_spearman` is reported, not gated. A trial run is not gated.

| taxon | region | stage | comparison | species | terms_compared | min_draws | in_band_pct | reachable_terms | reachable_in_band_pct | median_standardized_difference | median_absolute_difference | max_absolute_difference | negligible_terms | median_spearman | median_band_ratio | verdict | indicative_verdict |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| bird | north | climate | median | 2 | 20 | 5 | 90.000 | 20 | 90.000 | 0.351 | 0.000 | 0.651 | 0 | 1.000 | 0.694 | not gated (store holds 5 draws) | - |
| bryophyte | north | climate | median | 1 | 19 | 5 | 94.700 | 19 | 94.700 | 0.671 | 0.000 | 1.810 | 5 | 0.991 | 0.214 | not gated (store holds 5 draws) | - |
| lichen | north | climate | median | 2 | 38 | 5 | 89.500 | 38 | 89.500 | 0.003 | 0.000 | 1.990 | 17 | 0.991 | 0.301 | not gated (store holds 5 draws) | - |
| mite | north | climate | median | 2 | 38 | 5 | 94.700 | 38 | 94.700 | 0.082 | 0.000 | 3.790 | 20 | 0.973 | 0.656 | not gated (store holds 5 draws) | - |
| vascular_plant | north | climate | median | 2 | 38 | 5 | 97.400 | 38 | 97.400 | 0.000 | 0.000 | 0.120 | 24 | 0.982 | 0.602 | not gated (store holds 5 draws) | - |
| bird | south | climate | median | 2 | 20 | 5 | 90.000 | 20 | 90.000 | 0.351 | 0.000 | 0.651 | 0 | 1.000 | 0.694 | not gated (store holds 5 draws) | - |
| bryophyte | south | climate | median | 1 | 19 | 5 | 94.700 | 19 | 94.700 | 0.671 | 0.000 | 1.810 | 5 | 0.991 | 0.214 | not gated (store holds 5 draws) | - |
| lichen | south | climate | median | 2 | 38 | 5 | 89.500 | 38 | 89.500 | 0.003 | 0.000 | 1.990 | 17 | 0.991 | 0.301 | not gated (store holds 5 draws) | - |
| mite | south | climate | median | 2 | 38 | 5 | 94.700 | 38 | 94.700 | 0.082 | 0.000 | 3.790 | 20 | 0.973 | 0.656 | not gated (store holds 5 draws) | - |
| vascular_plant | south | climate | median | 2 | 38 | 5 | 97.400 | 38 | 97.400 | 0.000 | 0.000 | 0.120 | 24 | 0.982 | 0.602 | not gated (store holds 5 draws) | - |
| bird | north | habitat | median | 2 | 178 | 5 | 92.700 | 168 | 92.300 | 0.569 | 0.023 | 2.820 | 0 | 0.989 | 0.699 | not gated (store holds 5 draws) | - |
| bryophyte | north | habitat | median | 1 | 94 | 5 | 98.900 | 94 | 98.900 | 0.360 | 0.062 | 0.256 | 0 | 0.987 | 0.502 | not gated (store holds 5 draws) | - |
| lichen | north | habitat | median | 2 | 188 | 5 | 94.700 | 188 | 94.700 | 0.251 | 0.038 | 0.289 | 0 | 0.996 | 0.642 | not gated (store holds 5 draws) | - |
| mammal | north | habitat | iteration 1 | 2 | 448 | 4 | 100.000 | 436 | 100.000 | 0.000 | 0.000 | 0.000 | 0 | 1.000 | - | not gated (trial run) | - |
| mite | north | habitat | median | 1 | 94 | 5 | 76.600 | 94 | 76.600 | 0.579 | 0.078 | 0.673 | 0 | 0.993 | 0.642 | not gated (store holds 5 draws) | - |
| vascular_plant | north | habitat | median | 2 | 188 | 5 | 91.500 | 188 | 91.500 | 0.303 | 0.034 | 0.326 | 0 | 0.997 | 0.596 | not gated (store holds 5 draws) | - |
| bird | south | habitat | median | 2 | 46 | 5 | 80.400 | 40 | 77.500 | 0.334 | 0.021 | 0.121 | 0 | 0.995 | 0.508 | not gated (store holds 5 draws) | - |
| bryophyte | south | habitat | median | 1 | 19 | 5 | 100.000 | 19 | 100.000 | 0.399 | 0.066 | 0.267 | 0 | 0.991 | 0.633 | not gated (store holds 5 draws) | - |
| lichen | south | habitat | median | 2 | 40 | 5 | 87.500 | 40 | 87.500 | 0.337 | 0.048 | 0.655 | 1 | 0.985 | 0.554 | not gated (store holds 5 draws) | - |
| mammal | south | habitat | iteration 1 | 2 | 126 | 5 | 100.000 | 120 | 100.000 | 0.000 | 0.000 | 0.000 | 0 | 1.000 | - | not gated (trial run) | - |
| mite | south | habitat | median | 2 | 40 | 5 | 95.000 | 40 | 95.000 | 0.175 | 0.030 | 0.754 | 1 | 0.992 | 0.581 | not gated (store holds 5 draws) | - |
| vascular_plant | south | habitat | median | 2 | 40 | 5 | 75.000 | 40 | 75.000 | 0.585 | 0.070 | 0.552 | 0 | 0.977 | 0.566 | not gated (store holds 5 draws) | - |

Where v2 bootstraps, parity is **distributional**: v2 seeds no
random draw, so two v2 runs differ, and each term is scored on
whether the v2 median falls inside this run's
10th-to-90th percentile band. Where v2 fits once
(`comparison` = iteration 1: mammals), the run's full-data fit
is compared directly; read `median_absolute_difference`.

## Model fit

Median AUC over species, scored on each run's final model: for plants, v2's own prediction from its coefficient tables. `insample` scores the units each draw fitted; `oob` the units it left out, the held-out read. `v2val` is v2's validation, scored from the coefficients as v2 does (plants only), so for plants `v2val_full` equals `insample_auc`. Iteration 1 is the full data and has no out-of-bag units.

| taxon | region | species | median_insample_auc | median_oob_auc | median_v2val_full | median_oob_v2val_full |
| --- | --- | --- | --- | --- | --- | --- |
| bird | north | 2 | 0.752 | 0.729 | - | - |
| bryophyte | north | 2 | 0.668 | 0.650 | 0.668 | 0.650 |
| lichen | north | 2 | 0.808 | 0.803 | 0.808 | 0.803 |
| mammal | north | 4 | 0.746 | 0.731 | - | - |
| mite | north | 2 | 0.733 | 0.716 | 0.733 | 0.716 |
| vascular_plant | north | 2 | 0.833 | 0.828 | 0.833 | 0.828 |
| bird | south | 2 | 0.704 | 0.702 | - | - |
| bryophyte | south | 2 | 0.671 | 0.669 | 0.671 | 0.669 |
| lichen | south | 2 | 0.802 | 0.792 | 0.802 | 0.792 |
| mammal | south | 4 | 0.753 | 0.686 | - | - |
| mite | south | 2 | 0.799 | 0.774 | 0.799 | 0.774 |
| vascular_plant | south | 2 | 0.848 | 0.846 | 0.848 | 0.846 |

## What is still needed

See the experiment's `README.md` for what blocks the gate, and
`docs/reviews/2026-09-28_alignment_review.md` for the full
remediation plan.

