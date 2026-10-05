# Run record: exp_001_gbm

Written by `run_record()`. The result stores this describes are gitignored; this file is what remains.

## Provenance

_Volatile. Excluded from cross-run comparison._

- **git_commit**: 2b72a2b
- **pipeline_dir**: D:/local_projects/active/sdmMethodsDev/2_pipeline/exp_001_gbm
- **r_version**: 4.5.0
- **written_at**: 2026-10-05 11:05:10

## Configuration

- **boot_seed**: 20260909.0000
- **changes_from_v2**: bryophyte: habitat <- gbm with `single`, on every covariate the v2 candidates use, lichen: habitat <- gbm with `single`, on every covariate the v2 candidates use, mite: habitat <- gbm with `single`, on every covariate the v2 candidates use, vascular_plant: habitat <- gbm with `single`, on every covariate the v2 candidates use, bird: landcover <- gbm with `single`, on every covariate the v2 candidates use
- **compared_with**: exp_000_parity_v2
- **covariate_files**: none
- **data_dir**: test_dataset
- **engines**: bayesglm, gbm, glm
- **focal_species**: bird=AMRO, bird=YEWA, bryophyte=Bryum.All, bryophyte=Ceratodon.purpureus, lichen=Cladonia.chlorophaea, lichen=Physcia.adscendens, mammal=Coyote_Summer, mammal=Coyote_Winter, mammal=Moose_Summer, mammal=Moose_Winter, mite=Ceratozetes.gracilis, mite=Trhypochthonius.tectorum, vascular_plant=Galium.boreale, vascular_plant=Vicia.americana
- **jobs_not_ok**: 0
- **jobs_ok**: 100
- **jobs_total**: 100
- **n_bootstraps**: 5
- **plant_bootstrap**: spatial_block
- **selection**: aic_average, single
- **species_n**: 14
- **stage_models**: spec defaults (v2 candidate sets)
- **taxa**: bird, bryophyte, lichen, mite, vascular_plant
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
| mite | north | 2 | 5 | 190 | 140 | 430 |
| mite | south | 2 | 5 | 190 | 140 | 160 |
| vascular_plant | north | 2 | 5 | 190 | 140 | 430 |
| vascular_plant | south | 2 | 5 | 190 | 140 | 160 |

## Metrics

| taxon | region | metric | n | median | p10 | p90 | mean | sd |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| bird | north | insample_auc | 10 | 0.7785 | 0.7489 | 0.8120 | 0.7803 | 0.0313 |
| bird | north | insample_calibration_slope | 10 | 1.0157 | 0.9398 | 1.0902 | 1.0143 | 0.0764 |
| bird | north | insample_deviance_explained | 10 | 0.2513 | 0.1907 | 0.3191 | 0.2536 | 0.0648 |
| bird | north | insample_n | 10 | 46747.0000 | 46744.0000 | 46750.0000 | 46747.6000 | 2.3664 |
| bird | north | insample_prevalence | 10 | 0.1851 | 0.1178 | 0.2520 | 0.1850 | 0.0702 |
| bird | north | insample_rmse | 10 | 0.5699 | 0.4958 | 0.6433 | 0.5696 | 0.0767 |
| bird | north | insample_spearman | 10 | 0.3669 | 0.3497 | 0.3859 | 0.3670 | 0.0184 |
| bird | north | oob_auc | 10 | 0.7577 | 0.7505 | 0.7677 | 0.7588 | 0.0081 |
| bird | north | oob_calibration_slope | 10 | 0.9984 | 0.8836 | 1.0873 | 0.9861 | 0.0985 |
| bird | north | oob_deviance_explained | 10 | 0.2094 | 0.1936 | 0.2312 | 0.2118 | 0.0181 |
| bird | north | oob_n | 10 | 124877.0000 | 124874.0000 | 124880.0000 | 124876.4000 | 2.3664 |
| bird | north | oob_prevalence | 10 | 0.1877 | 0.1343 | 0.2411 | 0.1877 | 0.0561 |
| bird | north | oob_rmse | 10 | 0.5970 | 0.5494 | 0.6433 | 0.5964 | 0.0487 |
| bird | north | oob_spearman | 10 | 0.3491 | 0.3173 | 0.3809 | 0.3491 | 0.0323 |
| bird | south | insample_auc | 10 | 0.7285 | 0.7218 | 0.7332 | 0.7273 | 0.0052 |
| bird | south | insample_calibration_slope | 10 | 1.0529 | 0.9549 | 1.1534 | 1.0555 | 0.1016 |
| bird | south | insample_deviance_explained | 10 | 0.1974 | 0.1381 | 0.2650 | 0.1993 | 0.0635 |
| bird | south | insample_n | 10 | 23761.0000 | 23761.0000 | 23762.0000 | 23761.2000 | 0.4216 |
| bird | south | insample_prevalence | 10 | 0.2140 | 0.1710 | 0.2587 | 0.2147 | 0.0458 |
| bird | south | insample_rmse | 10 | 0.6629 | 0.5920 | 0.7266 | 0.6604 | 0.0674 |
| bird | south | insample_spearman | 10 | 0.3249 | 0.3082 | 0.3425 | 0.3261 | 0.0169 |
| bird | south | oob_auc | 10 | 0.7187 | 0.7120 | 0.7265 | 0.7192 | 0.0064 |
| bird | south | oob_calibration_slope | 10 | 1.0383 | 0.8966 | 1.1462 | 1.0252 | 0.1141 |
| bird | south | oob_deviance_explained | 10 | 0.1766 | 0.1312 | 0.2252 | 0.1776 | 0.0473 |
| bird | south | oob_n | 10 | 67240.0000 | 67239.0000 | 67240.0000 | 67239.8000 | 0.4216 |
| bird | south | oob_prevalence | 10 | 0.2177 | 0.1756 | 0.2603 | 0.2179 | 0.0444 |
| bird | south | oob_rmse | 10 | 0.6723 | 0.6223 | 0.7223 | 0.6723 | 0.0523 |
| bird | south | oob_spearman | 10 | 0.3173 | 0.3034 | 0.3307 | 0.3170 | 0.0130 |
| bryophyte | north | insample_auc | 10 | 0.7086 | 0.6715 | 0.7459 | 0.7084 | 0.0308 |
| bryophyte | north | insample_calibration_slope | 10 | 1.4240 | 1.2679 | 1.6795 | 1.4476 | 0.1675 |
| bryophyte | north | insample_deviance_explained | 10 | 0.0925 | 0.0563 | 0.1338 | 0.0955 | 0.0313 |
| bryophyte | north | insample_n | 10 | 3091.0000 | 3041.1000 | 4852.0000 | 3429.3000 | 750.2771 |
| bryophyte | north | insample_prevalence | 10 | 0.4175 | 0.3976 | 0.4423 | 0.4194 | 0.0223 |
| bryophyte | north | insample_rmse | 10 | 0.4619 | 0.4513 | 0.4702 | 0.4609 | 0.0078 |
| bryophyte | north | insample_spearman | 10 | 0.3563 | 0.2904 | 0.4231 | 0.3562 | 0.0549 |
| bryophyte | north | oob_auc | 8 | 0.6584 | 0.6253 | 0.6892 | 0.6573 | 0.0287 |
| bryophyte | north | oob_calibration_slope | 8 | 0.9836 | 0.9203 | 1.2616 | 1.0484 | 0.2043 |
| bryophyte | north | oob_deviance_explained | 8 | 0.0546 | 0.0335 | 0.0839 | 0.0571 | 0.0233 |
| bryophyte | north | oob_n | 10 | 1761.0000 | 0.0000 | 1810.9000 | 1422.7000 | 750.2771 |
| bryophyte | north | oob_prevalence | 8 | 0.4201 | 0.4007 | 0.4503 | 0.4233 | 0.0233 |
| bryophyte | north | oob_rmse | 8 | 0.4753 | 0.4683 | 0.4789 | 0.4744 | 0.0049 |
| bryophyte | north | oob_spearman | 8 | 0.2708 | 0.2127 | 0.3255 | 0.2692 | 0.0509 |
| bryophyte | south | insample_auc | 10 | 0.7794 | 0.7467 | 0.8338 | 0.7873 | 0.0374 |
| bryophyte | south | insample_calibration_slope | 10 | 1.4260 | 1.2580 | 1.5426 | 1.4072 | 0.1245 |
| bryophyte | south | insample_deviance_explained | 10 | 0.1566 | 0.1188 | 0.2508 | 0.1742 | 0.0546 |
| bryophyte | south | insample_n | 10 | 1454.5000 | 1440.8000 | 2310.0000 | 1623.0000 | 362.3789 |
| bryophyte | south | insample_prevalence | 10 | 0.3052 | 0.2352 | 0.3713 | 0.3043 | 0.0687 |
| bryophyte | south | insample_rmse | 10 | 0.4105 | 0.3644 | 0.4427 | 0.4058 | 0.0377 |
| bryophyte | south | insample_spearman | 10 | 0.4487 | 0.4111 | 0.4920 | 0.4496 | 0.0374 |
| bryophyte | south | oob_auc | 8 | 0.7207 | 0.6806 | 0.7473 | 0.7181 | 0.0294 |
| bryophyte | south | oob_calibration_slope | 8 | 0.9618 | 0.8329 | 1.2123 | 1.0005 | 0.1715 |
| bryophyte | south | oob_deviance_explained | 8 | 0.1044 | 0.0719 | 0.1210 | 0.1000 | 0.0221 |
| bryophyte | south | oob_n | 10 | 855.5000 | 0.0000 | 869.2000 | 687.0000 | 362.3789 |
| bryophyte | south | oob_prevalence | 8 | 0.3139 | 0.2297 | 0.3751 | 0.3071 | 0.0716 |
| bryophyte | south | oob_rmse | 8 | 0.4332 | 0.3943 | 0.4605 | 0.4295 | 0.0315 |
| bryophyte | south | oob_spearman | 8 | 0.3453 | 0.3021 | 0.3715 | 0.3418 | 0.0279 |
| lichen | north | insample_auc | 10 | 0.8493 | 0.8126 | 0.8810 | 0.8475 | 0.0329 |
| lichen | north | insample_calibration_slope | 10 | 1.1590 | 1.1210 | 1.1941 | 1.1576 | 0.0325 |
| lichen | north | insample_deviance_explained | 10 | 0.2945 | 0.2280 | 0.3648 | 0.2963 | 0.0655 |
| lichen | north | insample_n | 10 | 3692.0000 | 3654.0000 | 5811.0000 | 4109.1000 | 897.3877 |
| lichen | north | insample_prevalence | 10 | 0.3839 | 0.3815 | 0.3891 | 0.3840 | 0.0037 |
| lichen | north | insample_rmse | 10 | 0.3910 | 0.3634 | 0.4162 | 0.3903 | 0.0253 |
| lichen | north | insample_spearman | 10 | 0.5882 | 0.5267 | 0.6415 | 0.5854 | 0.0551 |
| lichen | north | oob_auc | 8 | 0.8152 | 0.7659 | 0.8618 | 0.8143 | 0.0472 |
| lichen | north | oob_calibration_slope | 8 | 1.0450 | 0.9951 | 1.0841 | 1.0386 | 0.0452 |
| lichen | north | oob_deviance_explained | 8 | 0.2479 | 0.1757 | 0.3237 | 0.2488 | 0.0737 |
| lichen | north | oob_n | 10 | 2119.0000 | 0.0000 | 2157.0000 | 1701.9000 | 897.3877 |
| lichen | north | oob_prevalence | 8 | 0.3864 | 0.3761 | 0.3921 | 0.3853 | 0.0072 |
| lichen | north | oob_rmse | 8 | 0.4083 | 0.3782 | 0.4346 | 0.4072 | 0.0274 |
| lichen | north | oob_spearman | 8 | 0.5306 | 0.4488 | 0.6079 | 0.5298 | 0.0797 |
| lichen | south | insample_auc | 10 | 0.8956 | 0.8812 | 0.9057 | 0.8967 | 0.0122 |
| lichen | south | insample_calibration_slope | 10 | 1.3200 | 1.1592 | 1.5184 | 1.3383 | 0.1754 |
| lichen | south | insample_deviance_explained | 10 | 0.3397 | 0.2759 | 0.3865 | 0.3309 | 0.0483 |
| lichen | south | insample_n | 10 | 1484.5000 | 1478.5000 | 2346.0000 | 1657.8000 | 362.9370 |
| lichen | south | insample_prevalence | 10 | 0.1511 | 0.0868 | 0.2167 | 0.1525 | 0.0659 |
| lichen | south | insample_rmse | 10 | 0.2859 | 0.2441 | 0.3241 | 0.2854 | 0.0367 |
| lichen | south | insample_spearman | 10 | 0.4770 | 0.3889 | 0.5739 | 0.4802 | 0.0892 |
| lichen | south | oob_auc | 8 | 0.8479 | 0.8283 | 0.8594 | 0.8455 | 0.0183 |
| lichen | south | oob_calibration_slope | 8 | 1.0660 | 0.9709 | 1.2289 | 1.0928 | 0.1204 |
| lichen | south | oob_deviance_explained | 8 | 0.2402 | 0.1839 | 0.2955 | 0.2404 | 0.0553 |
| lichen | south | oob_n | 10 | 861.5000 | 0.0000 | 867.5000 | 688.2000 | 362.9370 |
| lichen | south | oob_prevalence | 8 | 0.1578 | 0.0943 | 0.2207 | 0.1582 | 0.0637 |
| lichen | south | oob_rmse | 8 | 0.3176 | 0.2721 | 0.3469 | 0.3122 | 0.0364 |
| lichen | south | oob_spearman | 8 | 0.4298 | 0.3408 | 0.5167 | 0.4288 | 0.0871 |
| mite | north | insample_auc | 10 | 0.7751 | 0.7246 | 0.8270 | 0.7771 | 0.0501 |
| mite | north | insample_calibration_slope | 10 | 1.3671 | 1.1895 | 1.5446 | 1.3738 | 0.1717 |
| mite | north | insample_deviance_explained | 10 | 0.1492 | 0.0874 | 0.2341 | 0.1586 | 0.0737 |
| mite | north | insample_n | 10 | 3630.0000 | 3598.5000 | 5711.0000 | 4041.0000 | 880.4163 |
| mite | north | insample_prevalence | 10 | 0.1545 | 0.0943 | 0.2113 | 0.1531 | 0.0602 |
| mite | north | insample_rmse | 10 | 0.3190 | 0.2812 | 0.3537 | 0.3185 | 0.0366 |
| mite | north | insample_spearman | 10 | 0.3397 | 0.2336 | 0.4623 | 0.3461 | 0.1176 |
| mite | north | oob_auc | 8 | 0.7280 | 0.6556 | 0.8020 | 0.7272 | 0.0740 |
| mite | north | oob_calibration_slope | 8 | 1.0507 | 1.0138 | 1.0967 | 1.0539 | 0.0425 |
| mite | north | oob_deviance_explained | 8 | 0.1142 | 0.0469 | 0.1936 | 0.1175 | 0.0732 |
| mite | north | oob_n | 10 | 2081.0000 | 0.0000 | 2112.5000 | 1670.0000 | 880.4163 |
| mite | north | oob_prevalence | 8 | 0.1509 | 0.0925 | 0.2048 | 0.1495 | 0.0588 |
| mite | north | oob_rmse | 8 | 0.3244 | 0.2836 | 0.3649 | 0.3242 | 0.0404 |
| mite | north | oob_spearman | 8 | 0.2862 | 0.1567 | 0.4212 | 0.2869 | 0.1352 |
| mite | south | insample_auc | 10 | 0.8847 | 0.8300 | 0.9505 | 0.8859 | 0.0628 |
| mite | south | insample_calibration_slope | 10 | 1.3229 | 1.2157 | 1.6087 | 1.3739 | 0.1840 |
| mite | south | insample_deviance_explained | 10 | 0.3208 | 0.1925 | 0.4704 | 0.3211 | 0.1336 |
| mite | south | insample_n | 10 | 1493.0000 | 1480.9000 | 2363.0000 | 1665.8000 | 367.6444 |
| mite | south | insample_prevalence | 10 | 0.0721 | 0.0556 | 0.0841 | 0.0703 | 0.0144 |
| mite | south | insample_rmse | 10 | 0.2145 | 0.1779 | 0.2555 | 0.2170 | 0.0377 |
| mite | south | insample_spearman | 10 | 0.3358 | 0.3165 | 0.3669 | 0.3365 | 0.0305 |
| mite | south | oob_auc | 8 | 0.8020 | 0.7046 | 0.9029 | 0.8030 | 0.0999 |
| mite | south | oob_calibration_slope | 8 | 0.9625 | 0.6221 | 1.2186 | 0.9225 | 0.2535 |
| mite | south | oob_deviance_explained | 8 | 0.1787 | 0.0568 | 0.3516 | 0.1970 | 0.1340 |
| mite | south | oob_n | 10 | 870.0000 | 0.0000 | 882.1000 | 697.2000 | 367.6444 |
| mite | south | oob_prevalence | 8 | 0.0719 | 0.0489 | 0.0868 | 0.0689 | 0.0174 |
| mite | south | oob_rmse | 8 | 0.2407 | 0.1866 | 0.2748 | 0.2330 | 0.0405 |
| mite | south | oob_spearman | 8 | 0.2440 | 0.1925 | 0.3314 | 0.2567 | 0.0647 |
| vascular_plant | north | insample_auc | 10 | 0.8813 | 0.8662 | 0.8883 | 0.8789 | 0.0088 |
| vascular_plant | north | insample_calibration_slope | 10 | 1.1149 | 1.1050 | 1.1230 | 1.1136 | 0.0114 |
| vascular_plant | north | insample_deviance_explained | 10 | 0.3633 | 0.3325 | 0.3847 | 0.3593 | 0.0209 |
| vascular_plant | north | insample_n | 10 | 4347.5000 | 4314.6000 | 6874.0000 | 4846.9000 | 1068.6395 |
| vascular_plant | north | insample_prevalence | 10 | 0.3951 | 0.3770 | 0.4211 | 0.3974 | 0.0209 |
| vascular_plant | north | insample_rmse | 10 | 0.3673 | 0.3621 | 0.3804 | 0.3692 | 0.0071 |
| vascular_plant | north | insample_spearman | 10 | 0.6425 | 0.6247 | 0.6639 | 0.6418 | 0.0168 |
| vascular_plant | north | oob_auc | 8 | 0.8530 | 0.8434 | 0.8579 | 0.8515 | 0.0066 |
| vascular_plant | north | oob_calibration_slope | 8 | 1.0172 | 1.0024 | 1.0567 | 1.0236 | 0.0239 |
| vascular_plant | north | oob_deviance_explained | 8 | 0.3088 | 0.2858 | 0.3170 | 0.3033 | 0.0140 |
| vascular_plant | north | oob_n | 10 | 2526.5000 | 0.0000 | 2559.4000 | 2027.1000 | 1068.6395 |
| vascular_plant | north | oob_prevalence | 8 | 0.3990 | 0.3725 | 0.4275 | 0.3991 | 0.0248 |
| vascular_plant | north | oob_rmse | 8 | 0.3900 | 0.3851 | 0.3925 | 0.3893 | 0.0040 |
| vascular_plant | north | oob_spearman | 8 | 0.6042 | 0.5762 | 0.6066 | 0.5956 | 0.0143 |
| vascular_plant | south | insample_auc | 10 | 0.9117 | 0.8709 | 0.9501 | 0.9112 | 0.0379 |
| vascular_plant | south | insample_calibration_slope | 10 | 1.1452 | 1.1004 | 1.1789 | 1.1412 | 0.0364 |
| vascular_plant | south | insample_deviance_explained | 10 | 0.4382 | 0.3407 | 0.5528 | 0.4445 | 0.1050 |
| vascular_plant | south | insample_n | 10 | 1688.5000 | 1654.9000 | 2648.0000 | 1869.6000 | 410.6067 |
| vascular_plant | south | insample_prevalence | 10 | 0.2438 | 0.2212 | 0.2654 | 0.2437 | 0.0227 |
| vascular_plant | south | insample_rmse | 10 | 0.3061 | 0.2623 | 0.3412 | 0.3038 | 0.0394 |
| vascular_plant | south | insample_spearman | 10 | 0.6124 | 0.5653 | 0.6498 | 0.6095 | 0.0391 |
| vascular_plant | south | oob_auc | 8 | 0.8853 | 0.8312 | 0.9205 | 0.8792 | 0.0429 |
| vascular_plant | south | oob_calibration_slope | 8 | 1.0210 | 0.9849 | 1.0742 | 1.0266 | 0.0484 |
| vascular_plant | south | oob_deviance_explained | 8 | 0.3656 | 0.2638 | 0.4639 | 0.3647 | 0.0958 |
| vascular_plant | south | oob_n | 10 | 959.5000 | 0.0000 | 993.1000 | 778.4000 | 410.6067 |
| vascular_plant | south | oob_prevalence | 8 | 0.2418 | 0.2131 | 0.2706 | 0.2421 | 0.0259 |
| vascular_plant | south | oob_rmse | 8 | 0.3303 | 0.2915 | 0.3670 | 0.3289 | 0.0371 |
| vascular_plant | south | oob_spearman | 8 | 0.5672 | 0.5040 | 0.6055 | 0.5602 | 0.0470 |

