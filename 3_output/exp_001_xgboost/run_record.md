# Run record: exp_001_xgboost

Written by `run_record()`. The result stores this describes are gitignored; this file is what remains.

## Provenance

_Volatile. Excluded from cross-run comparison._

- **git_commit**: 7de25de
- **pipeline_dir**: D:/local_projects/active/sdmMethodsDev/2_pipeline/exp_001_xgboost
- **r_version**: 4.5.0
- **written_at**: 2026-10-05 15:19:05

## Configuration

- **boot_seed**: 20260909.0000
- **changes_from_v2**: bryophyte: habitat <- xgboost with `single`, on every covariate the v2 candidates use, lichen: habitat <- xgboost with `single`, on every covariate the v2 candidates use, mite: habitat <- xgboost with `single`, on every covariate the v2 candidates use, vascular_plant: habitat <- xgboost with `single`, on every covariate the v2 candidates use, mammal_summer: habitat <- xgboost with `single` inside `hurdle`, on every covariate the v2 candidates use, mammal_winter: habitat <- xgboost with `single` inside `hurdle`, on every covariate the v2 candidates use, bird: landcover <- xgboost with `single`, on every covariate the v2 candidates use
- **compared_with**: exp_000_parity_v2
- **covariate_files**: none
- **data_dir**: test_dataset
- **engines**: bayesglm, glm, xgboost
- **focal_species**: bird=AMRO, bird=YEWA, bryophyte=Bryum.All, bryophyte=Ceratodon.purpureus, lichen=Cladonia.chlorophaea, lichen=Physcia.adscendens, mammal=Coyote_Summer, mammal=Coyote_Winter, mammal=Moose_Summer, mammal=Moose_Winter, mite=Ceratozetes.gracilis, mite=Trhypochthonius.tectorum, vascular_plant=Galium.boreale, vascular_plant=Vicia.americana
- **jobs_not_ok**: 0
- **jobs_ok**: 140
- **jobs_total**: 140
- **n_bootstraps**: 5
- **plant_bootstrap**: spatial_block
- **selection**: aic_average, hurdle, single
- **species_n**: 14
- **stage_models**: spec defaults (v2 candidate sets)
- **taxa**: bird, bryophyte, lichen, mammal_summer, mammal_winter, mite, vascular_plant
- **v2_bootstraps**: 100

## Coverage

| taxon | region | species | draws | coefficient_rows | metric_rows | grid_rows |
| --- | --- | --- | --- | --- | --- | --- |
| bird | north | 2 | 5 | 100 | 140 | 890 |
| bird | south | 2 | 5 | 100 | 140 | 170 |
| bryophyte | north | 2 | 5 | 190 | 140 | 430 |
| bryophyte | south | 2 | 5 | 190 | 140 | 160 |
| lichen | north | 2 | 5 | 190 | 140 | 430 |
| lichen | south | 2 | 5 | 190 | 140 | 160 |
| mammal_summer | north | 2 | 5 | 1350 | 140 | 450 |
| mammal_summer | south | 2 | 5 | 600 | 140 | 200 |
| mammal_winter | north | 2 | 5 | 1350 | 140 | 450 |
| mammal_winter | south | 2 | 5 | 600 | 140 | 200 |
| mite | north | 2 | 5 | 190 | 140 | 430 |
| mite | south | 2 | 5 | 190 | 140 | 160 |
| vascular_plant | north | 2 | 5 | 190 | 140 | 430 |
| vascular_plant | south | 2 | 5 | 190 | 140 | 160 |

## Metrics

| taxon | region | metric | n | median | p10 | p90 | mean | sd |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| bird | north | insample_auc | 10 | 0.7994 | 0.7657 | 0.8325 | 0.7988 | 0.0344 |
| bird | north | insample_calibration_slope | 10 | 1.0349 | 0.9469 | 1.1278 | 1.0347 | 0.0896 |
| bird | north | insample_deviance_explained | 10 | 0.2915 | 0.2222 | 0.3641 | 0.2927 | 0.0734 |
| bird | north | insample_n | 10 | 46747.0000 | 46744.0000 | 46750.0000 | 46747.6000 | 2.3664 |
| bird | north | insample_prevalence | 10 | 0.1851 | 0.1178 | 0.2520 | 0.1850 | 0.0702 |
| bird | north | insample_rmse | 10 | 0.5619 | 0.4883 | 0.6343 | 0.5614 | 0.0758 |
| bird | north | insample_spearman | 10 | 0.3894 | 0.3723 | 0.4105 | 0.3913 | 0.0183 |
| bird | north | oob_auc | 10 | 0.7698 | 0.7568 | 0.7831 | 0.7698 | 0.0131 |
| bird | north | oob_calibration_slope | 10 | 0.9891 | 0.9030 | 1.0588 | 0.9794 | 0.0748 |
| bird | north | oob_deviance_explained | 10 | 0.2358 | 0.2089 | 0.2637 | 0.2361 | 0.0279 |
| bird | north | oob_n | 10 | 124877.0000 | 124874.0000 | 124880.0000 | 124876.4000 | 2.3664 |
| bird | north | oob_prevalence | 10 | 0.1877 | 0.1343 | 0.2411 | 0.1877 | 0.0561 |
| bird | north | oob_rmse | 10 | 0.5913 | 0.5422 | 0.6392 | 0.5908 | 0.0507 |
| bird | north | oob_spearman | 10 | 0.3634 | 0.3366 | 0.3901 | 0.3633 | 0.0272 |
| bird | south | insample_auc | 10 | 0.7737 | 0.7584 | 0.7861 | 0.7724 | 0.0134 |
| bird | south | insample_calibration_slope | 10 | 1.1005 | 0.9536 | 1.2339 | 1.0982 | 0.1427 |
| bird | south | insample_deviance_explained | 10 | 0.2678 | 0.1979 | 0.3324 | 0.2660 | 0.0690 |
| bird | south | insample_n | 10 | 23761.0000 | 23761.0000 | 23762.0000 | 23761.2000 | 0.4216 |
| bird | south | insample_prevalence | 10 | 0.2140 | 0.1710 | 0.2587 | 0.2147 | 0.0458 |
| bird | south | insample_rmse | 10 | 0.6438 | 0.5799 | 0.7083 | 0.6433 | 0.0653 |
| bird | south | insample_spearman | 10 | 0.3845 | 0.3773 | 0.4048 | 0.3899 | 0.0125 |
| bird | south | oob_auc | 10 | 0.7438 | 0.7318 | 0.7591 | 0.7446 | 0.0135 |
| bird | south | oob_calibration_slope | 10 | 1.0053 | 0.8916 | 1.1044 | 0.9973 | 0.0926 |
| bird | south | oob_deviance_explained | 10 | 0.2126 | 0.1601 | 0.2646 | 0.2126 | 0.0542 |
| bird | south | oob_n | 10 | 67240.0000 | 67239.0000 | 67240.0000 | 67239.8000 | 0.4216 |
| bird | south | oob_prevalence | 10 | 0.2177 | 0.1756 | 0.2603 | 0.2179 | 0.0444 |
| bird | south | oob_rmse | 10 | 0.6649 | 0.6147 | 0.7156 | 0.6651 | 0.0527 |
| bird | south | oob_spearman | 10 | 0.3524 | 0.3456 | 0.3586 | 0.3524 | 0.0058 |
| bryophyte | north | insample_auc | 10 | 0.8614 | 0.7699 | 0.8810 | 0.8447 | 0.0445 |
| bryophyte | north | insample_calibration_slope | 10 | 1.3758 | 1.2991 | 1.5011 | 1.3844 | 0.0860 |
| bryophyte | north | insample_deviance_explained | 10 | 0.2854 | 0.1545 | 0.3357 | 0.2691 | 0.0724 |
| bryophyte | north | insample_n | 10 | 3091.0000 | 3041.1000 | 4852.0000 | 3429.3000 | 750.2771 |
| bryophyte | north | insample_prevalence | 10 | 0.4175 | 0.3976 | 0.4423 | 0.4194 | 0.0223 |
| bryophyte | north | insample_rmse | 10 | 0.3948 | 0.3812 | 0.4407 | 0.4023 | 0.0237 |
| bryophyte | north | insample_spearman | 10 | 0.6135 | 0.4586 | 0.6543 | 0.5888 | 0.0773 |
| bryophyte | north | oob_auc | 8 | 0.6870 | 0.6446 | 0.7122 | 0.6829 | 0.0307 |
| bryophyte | north | oob_calibration_slope | 8 | 0.7215 | 0.6216 | 0.8656 | 0.7325 | 0.1018 |
| bryophyte | north | oob_deviance_explained | 8 | 0.0639 | 0.0214 | 0.0849 | 0.0585 | 0.0307 |
| bryophyte | north | oob_n | 10 | 1761.0000 | 0.0000 | 1810.9000 | 1422.7000 | 750.2771 |
| bryophyte | north | oob_prevalence | 8 | 0.4201 | 0.4007 | 0.4503 | 0.4233 | 0.0233 |
| bryophyte | north | oob_rmse | 8 | 0.4704 | 0.4663 | 0.4809 | 0.4716 | 0.0078 |
| bryophyte | north | oob_spearman | 8 | 0.3188 | 0.2457 | 0.3659 | 0.3129 | 0.0543 |
| bryophyte | south | insample_auc | 10 | 0.9033 | 0.8781 | 0.9252 | 0.8951 | 0.0386 |
| bryophyte | south | insample_calibration_slope | 10 | 1.2668 | 1.2203 | 1.3172 | 1.2782 | 0.0742 |
| bryophyte | south | insample_deviance_explained | 10 | 0.3912 | 0.3258 | 0.4512 | 0.3749 | 0.0794 |
| bryophyte | south | insample_n | 10 | 1454.5000 | 1440.8000 | 2310.0000 | 1623.0000 | 362.3789 |
| bryophyte | south | insample_prevalence | 10 | 0.3052 | 0.2352 | 0.3713 | 0.3043 | 0.0687 |
| bryophyte | south | insample_rmse | 10 | 0.3432 | 0.3058 | 0.3751 | 0.3441 | 0.0369 |
| bryophyte | south | insample_spearman | 10 | 0.6324 | 0.5665 | 0.6859 | 0.6207 | 0.0595 |
| bryophyte | south | oob_auc | 8 | 0.7517 | 0.7225 | 0.7802 | 0.7520 | 0.0273 |
| bryophyte | south | oob_calibration_slope | 8 | 0.7373 | 0.7015 | 0.8020 | 0.7471 | 0.0439 |
| bryophyte | south | oob_deviance_explained | 8 | 0.1116 | 0.0774 | 0.1399 | 0.1117 | 0.0272 |
| bryophyte | south | oob_n | 10 | 855.5000 | 0.0000 | 869.2000 | 687.0000 | 362.3789 |
| bryophyte | south | oob_prevalence | 8 | 0.3139 | 0.2297 | 0.3751 | 0.3071 | 0.0716 |
| bryophyte | south | oob_rmse | 8 | 0.4258 | 0.3890 | 0.4556 | 0.4235 | 0.0313 |
| bryophyte | south | oob_spearman | 8 | 0.3968 | 0.3723 | 0.4231 | 0.3953 | 0.0229 |
| lichen | north | insample_auc | 10 | 0.9092 | 0.8901 | 0.9416 | 0.9112 | 0.0322 |
| lichen | north | insample_calibration_slope | 10 | 1.1532 | 1.1179 | 1.1949 | 1.1548 | 0.0380 |
| lichen | north | insample_deviance_explained | 10 | 0.4173 | 0.3855 | 0.5321 | 0.4402 | 0.0848 |
| lichen | north | insample_n | 10 | 3692.0000 | 3654.0000 | 5811.0000 | 4109.1000 | 897.3877 |
| lichen | north | insample_prevalence | 10 | 0.3839 | 0.3815 | 0.3891 | 0.3840 | 0.0037 |
| lichen | north | insample_rmse | 10 | 0.3517 | 0.3052 | 0.3641 | 0.3413 | 0.0324 |
| lichen | north | insample_spearman | 10 | 0.6891 | 0.6572 | 0.7431 | 0.6928 | 0.0538 |
| lichen | north | oob_auc | 8 | 0.8279 | 0.7798 | 0.8701 | 0.8265 | 0.0450 |
| lichen | north | oob_calibration_slope | 8 | 0.9007 | 0.8358 | 0.9603 | 0.8959 | 0.0575 |
| lichen | north | oob_deviance_explained | 8 | 0.2584 | 0.1785 | 0.3420 | 0.2603 | 0.0816 |
| lichen | north | oob_n | 10 | 2119.0000 | 0.0000 | 2157.0000 | 1701.9000 | 897.3877 |
| lichen | north | oob_prevalence | 8 | 0.3864 | 0.3761 | 0.3921 | 0.3853 | 0.0072 |
| lichen | north | oob_rmse | 8 | 0.4044 | 0.3737 | 0.4325 | 0.4031 | 0.0286 |
| lichen | north | oob_spearman | 8 | 0.5535 | 0.4722 | 0.6241 | 0.5503 | 0.0760 |
| lichen | south | insample_auc | 10 | 0.9686 | 0.9482 | 0.9792 | 0.9663 | 0.0147 |
| lichen | south | insample_calibration_slope | 10 | 1.1831 | 1.1308 | 1.2935 | 1.1991 | 0.0688 |
| lichen | south | insample_deviance_explained | 10 | 0.6087 | 0.5214 | 0.6729 | 0.5882 | 0.0813 |
| lichen | south | insample_n | 10 | 1484.5000 | 1478.5000 | 2346.0000 | 1657.8000 | 362.9370 |
| lichen | south | insample_prevalence | 10 | 0.1511 | 0.0868 | 0.2167 | 0.1525 | 0.0659 |
| lichen | south | insample_rmse | 10 | 0.2174 | 0.1882 | 0.2497 | 0.2191 | 0.0286 |
| lichen | south | insample_spearman | 10 | 0.5637 | 0.4448 | 0.6833 | 0.5634 | 0.1102 |
| lichen | south | oob_auc | 8 | 0.8649 | 0.8298 | 0.8846 | 0.8581 | 0.0288 |
| lichen | south | oob_calibration_slope | 8 | 0.8251 | 0.6691 | 0.8954 | 0.8012 | 0.1214 |
| lichen | south | oob_deviance_explained | 8 | 0.2582 | 0.1012 | 0.3352 | 0.2293 | 0.1168 |
| lichen | south | oob_n | 10 | 861.5000 | 0.0000 | 867.5000 | 688.2000 | 362.9370 |
| lichen | south | oob_prevalence | 8 | 0.1578 | 0.0943 | 0.2207 | 0.1582 | 0.0637 |
| lichen | south | oob_rmse | 8 | 0.3147 | 0.2702 | 0.3334 | 0.3048 | 0.0292 |
| lichen | south | oob_spearman | 8 | 0.4496 | 0.3334 | 0.5524 | 0.4451 | 0.1063 |
| mammal_summer | north | insample_auc | 10 | 0.8510 | 0.7867 | 0.9224 | 0.8472 | 0.0788 |
| mammal_summer | north | insample_calibration_slope | 10 | 1.2105 | 1.0951 | 1.3878 | 1.2388 | 0.1326 |
| mammal_summer | north | insample_deviance_explained | 10 | 0.3169 | 0.2021 | 0.5029 | 0.3355 | 0.1508 |
| mammal_summer | north | insample_n | 10 | 2587.5000 | 2542.1000 | 4053.0000 | 2865.2000 | 626.3850 |
| mammal_summer | north | insample_prevalence | 10 | 0.2736 | 0.2243 | 0.3206 | 0.2726 | 0.0496 |
| mammal_summer | north | insample_rmse | 10 | 0.3414 | 0.2707 | 0.3961 | 0.3374 | 0.0617 |
| mammal_summer | north | insample_spearman | 10 | 0.5275 | 0.4545 | 0.6076 | 0.5196 | 0.1036 |
| mammal_summer | north | oob_auc | 8 | 0.7264 | 0.6348 | 0.8195 | 0.7274 | 0.0929 |
| mammal_summer | north | oob_calibration_slope | 8 | 0.7018 | 0.5771 | 0.8626 | 0.7166 | 0.1354 |
| mammal_summer | north | oob_deviance_explained | 8 | 0.1000 | 0.0198 | 0.2566 | 0.1270 | 0.1141 |
| mammal_summer | north | oob_n | 10 | 1465.5000 | 0.0000 | 1510.9000 | 1187.8000 | 626.3850 |
| mammal_summer | north | oob_prevalence | 8 | 0.2774 | 0.2208 | 0.3261 | 0.2746 | 0.0539 |
| mammal_summer | north | oob_rmse | 8 | 0.3953 | 0.3314 | 0.4438 | 0.3903 | 0.0567 |
| mammal_summer | north | oob_spearman | 8 | 0.3364 | 0.2091 | 0.4532 | 0.3341 | 0.1225 |
| mammal_summer | south | insample_auc | 10 | 0.9288 | 0.8453 | 0.9790 | 0.9117 | 0.0726 |
| mammal_summer | south | insample_calibration_slope | 10 | 1.3495 | 1.2208 | 1.5068 | 1.3944 | 0.2498 |
| mammal_summer | south | insample_deviance_explained | 10 | 0.4206 | 0.2223 | 0.7037 | 0.4326 | 0.2145 |
| mammal_summer | south | insample_n | 10 | 676.5000 | 670.8000 | 1065.0000 | 753.7000 | 164.1402 |
| mammal_summer | south | insample_prevalence | 10 | 0.4451 | 0.1814 | 0.7098 | 0.4419 | 0.2704 |
| mammal_summer | south | insample_rmse | 10 | 0.2920 | 0.2235 | 0.3561 | 0.2933 | 0.0622 |
| mammal_summer | south | insample_spearman | 10 | 0.5872 | 0.5123 | 0.6435 | 0.5691 | 0.0908 |
| mammal_summer | south | oob_auc | 8 | 0.6859 | 0.5980 | 0.7912 | 0.6933 | 0.0999 |
| mammal_summer | south | oob_calibration_slope | 8 | 0.5395 | 0.3744 | 0.8810 | 0.5899 | 0.2334 |
| mammal_summer | south | oob_deviance_explained | 8 | -0.0275 | -0.0673 | 0.1741 | 0.0253 | 0.1236 |
| mammal_summer | south | oob_n | 10 | 388.5000 | 0.0000 | 394.2000 | 311.3000 | 164.1402 |
| mammal_summer | south | oob_prevalence | 8 | 0.4195 | 0.1726 | 0.6930 | 0.4251 | 0.2678 |
| mammal_summer | south | oob_rmse | 8 | 0.4015 | 0.3273 | 0.4526 | 0.3937 | 0.0597 |
| mammal_summer | south | oob_spearman | 8 | 0.2479 | 0.1202 | 0.3897 | 0.2536 | 0.1325 |
| mammal_winter | north | insample_auc | 10 | 0.8918 | 0.8420 | 0.9162 | 0.8846 | 0.0355 |
| mammal_winter | north | insample_calibration_slope | 10 | 1.1597 | 1.0523 | 1.3024 | 1.1679 | 0.1117 |
| mammal_winter | north | insample_deviance_explained | 10 | 0.3971 | 0.2938 | 0.4736 | 0.3908 | 0.0848 |
| mammal_winter | north | insample_n | 10 | 2624.5000 | 2596.8000 | 4127.0000 | 2921.0000 | 635.9504 |
| mammal_winter | north | insample_prevalence | 10 | 0.1752 | 0.1467 | 0.2040 | 0.1753 | 0.0287 |
| mammal_winter | north | insample_rmse | 10 | 0.2768 | 0.2641 | 0.2973 | 0.2793 | 0.0151 |
| mammal_winter | north | insample_spearman | 10 | 0.5047 | 0.4253 | 0.5759 | 0.5032 | 0.0691 |
| mammal_winter | north | oob_auc | 8 | 0.7732 | 0.6849 | 0.8485 | 0.7690 | 0.0808 |
| mammal_winter | north | oob_calibration_slope | 8 | 0.7510 | 0.5146 | 0.8766 | 0.7196 | 0.1504 |
| mammal_winter | north | oob_deviance_explained | 8 | 0.1849 | 0.0312 | 0.2981 | 0.1708 | 0.1308 |
| mammal_winter | north | oob_n | 10 | 1502.5000 | 0.0000 | 1530.2000 | 1206.0000 | 635.9504 |
| mammal_winter | north | oob_prevalence | 8 | 0.1756 | 0.1450 | 0.2025 | 0.1746 | 0.0269 |
| mammal_winter | north | oob_rmse | 8 | 0.3147 | 0.3000 | 0.3429 | 0.3194 | 0.0203 |
| mammal_winter | north | oob_spearman | 8 | 0.3595 | 0.2344 | 0.4739 | 0.3548 | 0.1223 |
| mammal_winter | south | insample_auc | 10 | 0.9224 | 0.8432 | 0.9792 | 0.9074 | 0.0697 |
| mammal_winter | south | insample_calibration_slope | 10 | 1.2937 | 1.2545 | 1.5652 | 1.3634 | 0.1374 |
| mammal_winter | south | insample_deviance_explained | 10 | 0.4273 | 0.2637 | 0.6930 | 0.4422 | 0.1882 |
| mammal_winter | south | insample_n | 10 | 694.0000 | 684.8000 | 1098.0000 | 773.7000 | 171.0842 |
| mammal_winter | south | insample_prevalence | 10 | 0.3450 | 0.0865 | 0.6052 | 0.3446 | 0.2704 |
| mammal_winter | south | insample_rmse | 10 | 0.2487 | 0.1472 | 0.3456 | 0.2525 | 0.0902 |
| mammal_winter | south | insample_spearman | 10 | 0.4705 | 0.4147 | 0.7062 | 0.5243 | 0.1212 |
| mammal_winter | south | oob_auc | 8 | 0.6976 | 0.6411 | 0.8063 | 0.7182 | 0.0757 |
| mammal_winter | south | oob_calibration_slope | 8 | 0.5301 | 0.4351 | 0.7396 | 0.5684 | 0.1485 |
| mammal_winter | south | oob_deviance_explained | 8 | 0.0058 | -0.1998 | 0.1763 | -0.0059 | 0.1875 |
| mammal_winter | south | oob_n | 10 | 404.0000 | 0.0000 | 413.2000 | 324.3000 | 171.0842 |
| mammal_winter | south | oob_prevalence | 8 | 0.3501 | 0.0777 | 0.6225 | 0.3492 | 0.2818 |
| mammal_winter | south | oob_rmse | 8 | 0.3397 | 0.2197 | 0.4332 | 0.3307 | 0.1041 |
| mammal_winter | south | oob_spearman | 8 | 0.2590 | 0.2345 | 0.2899 | 0.2608 | 0.0276 |
| mite | north | insample_auc | 10 | 0.8861 | 0.8490 | 0.9130 | 0.8770 | 0.0512 |
| mite | north | insample_calibration_slope | 10 | 1.2393 | 1.1764 | 1.3996 | 1.2771 | 0.1014 |
| mite | north | insample_deviance_explained | 10 | 0.3175 | 0.2511 | 0.4143 | 0.3223 | 0.0980 |
| mite | north | insample_n | 10 | 3630.0000 | 3598.5000 | 5711.0000 | 4041.0000 | 880.4163 |
| mite | north | insample_prevalence | 10 | 0.1545 | 0.0943 | 0.2113 | 0.1531 | 0.0602 |
| mite | north | insample_rmse | 10 | 0.2930 | 0.2520 | 0.3097 | 0.2855 | 0.0279 |
| mite | north | insample_spearman | 10 | 0.4624 | 0.3562 | 0.5826 | 0.4640 | 0.1221 |
| mite | north | oob_auc | 8 | 0.7476 | 0.6487 | 0.8046 | 0.7358 | 0.0755 |
| mite | north | oob_calibration_slope | 8 | 0.7520 | 0.5290 | 0.8442 | 0.7104 | 0.1543 |
| mite | north | oob_deviance_explained | 8 | 0.1131 | -0.0237 | 0.1876 | 0.0947 | 0.1030 |
| mite | north | oob_n | 10 | 2081.0000 | 0.0000 | 2112.5000 | 1670.0000 | 880.4163 |
| mite | north | oob_prevalence | 8 | 0.1509 | 0.0925 | 0.2048 | 0.1495 | 0.0588 |
| mite | north | oob_rmse | 8 | 0.3281 | 0.2834 | 0.3631 | 0.3250 | 0.0388 |
| mite | north | oob_spearman | 8 | 0.3080 | 0.1536 | 0.4270 | 0.2969 | 0.1371 |
| mite | south | insample_auc | 10 | 0.9592 | 0.9376 | 0.9939 | 0.9618 | 0.0251 |
| mite | south | insample_calibration_slope | 10 | 1.2129 | 1.1367 | 1.3093 | 1.2269 | 0.0874 |
| mite | south | insample_deviance_explained | 10 | 0.5182 | 0.4315 | 0.7601 | 0.5606 | 0.1372 |
| mite | south | insample_n | 10 | 1493.0000 | 1480.9000 | 2363.0000 | 1665.8000 | 367.6444 |
| mite | south | insample_prevalence | 10 | 0.0721 | 0.0556 | 0.0841 | 0.0703 | 0.0144 |
| mite | south | insample_rmse | 10 | 0.1851 | 0.1250 | 0.2161 | 0.1770 | 0.0411 |
| mite | south | insample_spearman | 10 | 0.4054 | 0.3708 | 0.4408 | 0.4054 | 0.0280 |
| mite | south | oob_auc | 8 | 0.8217 | 0.7176 | 0.9044 | 0.8152 | 0.0913 |
| mite | south | oob_calibration_slope | 8 | 0.6549 | 0.4859 | 0.9202 | 0.6803 | 0.1978 |
| mite | south | oob_deviance_explained | 8 | 0.1333 | -0.0105 | 0.3578 | 0.1547 | 0.1687 |
| mite | south | oob_n | 10 | 870.0000 | 0.0000 | 882.1000 | 697.2000 | 367.6444 |
| mite | south | oob_prevalence | 8 | 0.0719 | 0.0489 | 0.0868 | 0.0689 | 0.0174 |
| mite | south | oob_rmse | 8 | 0.2426 | 0.1842 | 0.2757 | 0.2335 | 0.0451 |
| mite | south | oob_spearman | 8 | 0.2530 | 0.2087 | 0.3351 | 0.2668 | 0.0542 |
| vascular_plant | north | insample_auc | 10 | 0.9376 | 0.9310 | 0.9410 | 0.9367 | 0.0044 |
| vascular_plant | north | insample_calibration_slope | 10 | 1.1354 | 1.1200 | 1.1411 | 1.1330 | 0.0098 |
| vascular_plant | north | insample_deviance_explained | 10 | 0.5183 | 0.4948 | 0.5237 | 0.5139 | 0.0151 |
| vascular_plant | north | insample_n | 10 | 4347.5000 | 4314.6000 | 6874.0000 | 4846.9000 | 1068.6395 |
| vascular_plant | north | insample_prevalence | 10 | 0.3951 | 0.3770 | 0.4211 | 0.3974 | 0.0209 |
| vascular_plant | north | insample_rmse | 10 | 0.3144 | 0.3092 | 0.3227 | 0.3144 | 0.0058 |
| vascular_plant | north | insample_spearman | 10 | 0.7385 | 0.7305 | 0.7504 | 0.7397 | 0.0107 |
| vascular_plant | north | oob_auc | 8 | 0.8697 | 0.8604 | 0.8766 | 0.8691 | 0.0076 |
| vascular_plant | north | oob_calibration_slope | 8 | 0.9589 | 0.9312 | 0.9797 | 0.9563 | 0.0248 |
| vascular_plant | north | oob_deviance_explained | 8 | 0.3414 | 0.3159 | 0.3587 | 0.3391 | 0.0210 |
| vascular_plant | north | oob_n | 10 | 2526.5000 | 0.0000 | 2559.4000 | 2027.1000 | 1068.6395 |
| vascular_plant | north | oob_prevalence | 8 | 0.3990 | 0.3725 | 0.4275 | 0.3991 | 0.0248 |
| vascular_plant | north | oob_rmse | 8 | 0.3753 | 0.3705 | 0.3834 | 0.3765 | 0.0055 |
| vascular_plant | north | oob_spearman | 8 | 0.6268 | 0.6048 | 0.6427 | 0.6255 | 0.0160 |
| vascular_plant | south | insample_auc | 10 | 0.9750 | 0.9565 | 0.9889 | 0.9738 | 0.0136 |
| vascular_plant | south | insample_calibration_slope | 10 | 1.1189 | 1.0822 | 1.1506 | 1.1168 | 0.0321 |
| vascular_plant | south | insample_deviance_explained | 10 | 0.6677 | 0.5715 | 0.7691 | 0.6713 | 0.0805 |
| vascular_plant | south | insample_n | 10 | 1688.5000 | 1654.9000 | 2648.0000 | 1869.6000 | 410.6067 |
| vascular_plant | south | insample_prevalence | 10 | 0.2438 | 0.2212 | 0.2654 | 0.2437 | 0.0227 |
| vascular_plant | south | insample_rmse | 10 | 0.2318 | 0.1862 | 0.2693 | 0.2280 | 0.0344 |
| vascular_plant | south | insample_spearman | 10 | 0.7011 | 0.6914 | 0.7153 | 0.7029 | 0.0117 |
| vascular_plant | south | oob_auc | 8 | 0.9043 | 0.8724 | 0.9382 | 0.9053 | 0.0328 |
| vascular_plant | south | oob_calibration_slope | 8 | 0.9306 | 0.8921 | 0.9559 | 0.9256 | 0.0269 |
| vascular_plant | south | oob_deviance_explained | 8 | 0.4119 | 0.3408 | 0.5093 | 0.4192 | 0.0820 |
| vascular_plant | south | oob_n | 10 | 959.5000 | 0.0000 | 993.1000 | 778.4000 | 410.6067 |
| vascular_plant | south | oob_prevalence | 8 | 0.2418 | 0.2131 | 0.2706 | 0.2421 | 0.0259 |
| vascular_plant | south | oob_rmse | 8 | 0.3105 | 0.2780 | 0.3427 | 0.3108 | 0.0317 |
| vascular_plant | south | oob_spearman | 8 | 0.6007 | 0.5669 | 0.6277 | 0.5987 | 0.0306 |

