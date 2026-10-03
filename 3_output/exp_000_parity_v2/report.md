# exp_000_parity_v2

Generated 2026-10-03 05:16:40

**Trial run.** 14 focal species, 100 of 100 draws. Its parity numbers show the pipeline ran; they are not a parity read.

Draws: `boot_seed = 20260909`, one derived seed per species.

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
| amphibian north habitat | TRUE | 364 | 4 | NA |
| amphibian south habitat | FALSE | 0 | 0 | NA |
| amphibian all climate | TRUE | 44 | 4 | NA |
| bird north habitat | TRUE | 10609 | 103 | NA |
| bird south habitat | TRUE | 1747 | 65 | NA |
| bird all climate | TRUE | 1240 | 124 | NA |
| bryophyte north habitat | TRUE | 12154 | 118 | NA |
| bryophyte south habitat | TRUE | 673 | 25 | NA |
| bryophyte all climate | TRUE | 2242 | 118 | NA |
| lichen north habitat | TRUE | 13596 | 132 | NA |
| lichen south habitat | TRUE | 1206 | 45 | NA |
| lichen all climate | TRUE | 2755 | 145 | NA |
| mammal north habitat | TRUE | 5760 | 15 | NA |
| mammal south habitat | TRUE | 1079 | 13 | NA |
| mammal all climate | TRUE | 105 | 21 | NA |
| mite north habitat | TRUE | 9785 | 95 | NA |
| mite south habitat | TRUE | 755 | 28 | NA |
| mite all climate | TRUE | 2052 | 108 | NA |
| vascular_plant north habitat | TRUE | 32754 | 318 | NA |
| vascular_plant south habitat | TRUE | 6257 | 233 | NA |
| vascular_plant all climate | TRUE | 8246 | 434 | NA |

What this run's comparison could not reach:

_Every taxon and region that ran had a reference to compare against._

## What ran

| taxon | run | region | season | part | species | draws | stages | has_coefficients | has_grid |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| bird | bird | north |  |  | 2 | 100 | climate, landcover, habitat | TRUE | FALSE |
| bird | bird | south |  |  | 2 | 100 | climate, landcover, habitat | TRUE | FALSE |
| bryophyte | bryophyte | north |  |  | 2 | 100 | climate, habitat | TRUE | FALSE |
| bryophyte | bryophyte | south |  |  | 2 | 100 | climate, habitat | TRUE | FALSE |
| lichen | lichen | north |  |  | 2 | 100 | climate, habitat | TRUE | FALSE |
| lichen | lichen | south |  |  | 2 | 100 | climate, habitat | TRUE | FALSE |
| mammal | mammal_summer | north | summer | hurdle | 2 | 100 | habitat_presence, habitat_abundance, habitat_total | TRUE | FALSE |
| mammal | mammal_summer | south | summer | hurdle | 2 | 100 | habitat_presence, habitat_abundance, habitat_total | TRUE | FALSE |
| mammal | mammal_winter | north | winter | hurdle | 2 | 100 | habitat_presence, habitat_abundance, habitat_total | TRUE | FALSE |
| mammal | mammal_winter | south | winter | hurdle | 2 | 100 | habitat_presence, habitat_abundance, habitat_total | TRUE | FALSE |
| mite | mite | north |  |  | 2 | 100 | climate, habitat | TRUE | TRUE |
| mite | mite | south |  |  | 2 | 100 | climate, habitat | TRUE | TRUE |
| vascular_plant | vascular_plant | north |  |  | 2 | 100 | climate, habitat | TRUE | TRUE |
| vascular_plant | vascular_plant | south |  |  | 2 | 100 | climate, habitat | TRUE | TRUE |

## Parity against v2, by stage

Every stage is compared against `v2_results.csv`. Climate is
scored against v2's province-wide fit in both regions. Terms v2
fixes at a placeholder are left out of the reachable scores.

`verdict` reads each row against the parity targets in `utils/parity_targets.R` (proposed, not yet agreed): numerical rows (iteration 1) pass when every reachable term is within 1e-06; distributional rows when at least 90% of reachable terms are in band, the median standardized difference is at most 0.25, and the median band-width ratio (this run's band over v2's) is between 0.75 and 1.33. `median_spearman` is reported, not gated. A trial run is not gated.

| taxon | region | stage | comparison | species | terms_compared | min_draws | in_band_pct | reachable_terms | reachable_in_band_pct | median_standardized_difference | median_absolute_difference | max_absolute_difference | negligible_terms | median_spearman | median_band_ratio | verdict | indicative_verdict |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| bird | north | climate | median | 2 | 20 | 100 | 100 | 20 | 100 | 0 | 0 | 2.2e-11 | 0 | 1 | 1 | not gated (trial run) | pass |
| bryophyte | north | climate | median | 1 | 19 | 100 | 100 | 19 | 100 | 0.035 | 0 | 1.4 | 6 | 1 | 1.062 | not gated (trial run) | pass |
| lichen | north | climate | median | 2 | 38 | 100 | 100 | 38 | 100 | 0 | 0 | 0.644 | 17 | 0.993 | 0.879 | not gated (trial run) | pass |
| mite | north | climate | median | 2 | 38 | 100 | 100 | 38 | 100 | 0 | 0 | 1.95 | 20 | 0.905 | 0.953 | not gated (trial run) | pass |
| vascular_plant | north | climate | median | 2 | 38 | 100 | 100 | 38 | 100 | 0 | 0 | 0.266 | 24 | 1 | 0.97 | not gated (trial run) | pass |
| bird | south | climate | median | 2 | 20 | 100 | 100 | 20 | 100 | 0 | 0 | 2.2e-11 | 0 | 1 | 1 | not gated (trial run) | pass |
| bryophyte | south | climate | median | 1 | 19 | 100 | 100 | 19 | 100 | 0.035 | 0 | 1.4 | 6 | 1 | 1.062 | not gated (trial run) | pass |
| lichen | south | climate | median | 2 | 38 | 100 | 100 | 38 | 100 | 0 | 0 | 0.644 | 17 | 0.993 | 0.879 | not gated (trial run) | pass |
| mite | south | climate | median | 2 | 38 | 100 | 100 | 38 | 100 | 0 | 0 | 1.95 | 20 | 0.905 | 0.953 | not gated (trial run) | pass |
| vascular_plant | south | climate | median | 2 | 38 | 100 | 100 | 38 | 100 | 0 | 0 | 0.266 | 24 | 1 | 0.97 | not gated (trial run) | pass |
| bird | north | habitat | median | 2 | 178 | 100 | 100 | 168 | 100 | 0 | 0 | 2.71e-11 | 0 | 1 | 1 | not gated (trial run) | pass |
| bryophyte | north | habitat | median | 1 | 94 | 100 | 100 | 94 | 100 | 0.072 | 0.023 | 0.0808 | 0 | 0.997 | 0.911 | not gated (trial run) | pass |
| lichen | north | habitat | median | 2 | 188 | 100 | 100 | 188 | 100 | 0.091 | 0.024 | 0.118 | 0 | 0.999 | 0.988 | not gated (trial run) | pass |
| mammal | north | habitat | iteration 1 | 2 | 448 | 65 | 100 | 436 | 100 | 0 | 0 | 9.77e-15 | 0 | 1 | NA | not gated (trial run) | pass |
| mite | north | habitat | median | 1 | 94 | 100 | 100 | 94 | 100 | 0.14 | 0.035 | 0.148 | 0 | 0.999 | 0.993 | not gated (trial run) | pass |
| vascular_plant | north | habitat | median | 2 | 188 | 100 | 100 | 188 | 100 | 0.108 | 0.022 | 0.125 | 0 | 0.999 | 0.95 | not gated (trial run) | pass |
| bird | south | habitat | median | 2 | 46 | 100 | 100 | 40 | 100 | 0 | 0 | 5.61e-11 | 0 | 1 | 1 | not gated (trial run) | pass |
| bryophyte | south | habitat | median | 1 | 19 | 100 | 100 | 19 | 100 | 0.047 | 0.021 | 0.0601 | 0 | 0.993 | 1.042 | not gated (trial run) | pass |
| lichen | south | habitat | median | 2 | 40 | 100 | 100 | 40 | 100 | 0.088 | 0.029 | 0.278 | 1 | 0.994 | 0.961 | not gated (trial run) | pass |
| mammal | south | habitat | iteration 1 | 2 | 126 | 99 | 100 | 120 | 100 | 0 | 0 | 5.33e-15 | 0 | 1 | NA | not gated (trial run) | pass |
| mite | south | habitat | median | 2 | 40 | 100 | 100 | 40 | 100 | 0.068 | 0.024 | 0.464 | 1 | 0.991 | 0.975 | not gated (trial run) | pass |
| vascular_plant | south | habitat | median | 2 | 40 | 100 | 100 | 40 | 100 | 0.074 | 0.027 | 0.184 | 0 | 0.997 | 1.021 | not gated (trial run) | pass |

Where v2 bootstraps, parity is **distributional**: v2 seeds no
random draw, so two v2 runs differ, and each term is scored on
whether the v2 median falls inside this run's
10th-to-90th percentile band. Where v2 fits once
(`comparison` = iteration 1: mammals), the run's full-data fit
is compared directly; read `median_absolute_difference`.

## Model fit

Median AUC over species. `insample` scores the units each draw fitted; `oob` the units it left out, the held-out read. `v2val` is v2's validation, scored from the coefficients as v2 does (plants only). Iteration 1 is the full data and has no out-of-bag units.

| taxon | region | species | median_insample_auc | median_oob_auc | median_v2val_full | median_oob_v2val_full |
| --- | --- | --- | --- | --- | --- | --- |
| bird | north | 2 | 0.751 | 0.73 | NA | NA |
| bryophyte | north | 2 | 0.666 | 0.646 | 0.668 | 0.652 |
| lichen | north | 2 | 0.807 | 0.798 | 0.808 | 0.802 |
| mammal | north | 4 | 0.751 | 0.73 | NA | NA |
| mite | north | 2 | 0.747 | 0.722 | 0.735 | 0.718 |
| vascular_plant | north | 2 | 0.836 | 0.829 | 0.833 | 0.829 |
| bird | south | 2 | 0.706 | 0.702 | NA | NA |
| bryophyte | south | 2 | 0.705 | 0.686 | 0.676 | 0.664 |
| lichen | south | 2 | 0.836 | 0.816 | 0.802 | 0.792 |
| mammal | south | 4 | 0.739 | 0.716 | NA | NA |
| mite | south | 2 | 0.809 | 0.774 | 0.796 | 0.781 |
| vascular_plant | south | 2 | 0.862 | 0.851 | 0.85 | 0.844 |

## What is still needed

See the experiment's `README.md` for what blocks the gate, and
`docs/reviews/2026-09-28_alignment_review.md` for the full
remediation plan.

