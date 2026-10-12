# Run record: exp_001_xgboost

Written by `run_record()`. The result stores this describes are gitignored; this file is what remains.

## Provenance

_Volatile. Excluded from cross-run comparison._

- **git_commit**: a19b94c
- **pipeline_dir**: D:/local_projects/active/sdmMethodsDev/2_pipeline/exp_001_xgboost
- **r_version**: 4.5.0
- **written_at**: 2026-10-08 13:51:37

## Configuration

- **boot_seed**: 20260909.0000
- **changes_from_v2**: bryophyte: habitat <- xgboost with `single`, on every covariate the v2 candidates use, lichen: habitat <- xgboost with `single`, on every covariate the v2 candidates use, mite: habitat <- xgboost with `single`, on every covariate the v2 candidates use, vascular_plant: habitat <- xgboost with `single`, on every covariate the v2 candidates use, mammal_summer: habitat <- xgboost with `single` inside `hurdle`, on every covariate the v2 candidates use, mammal_winter: habitat <- xgboost with `single` inside `hurdle`, on every covariate the v2 candidates use, bird: landcover <- xgboost with `single`, on every covariate the v2 candidates use
- **compared_with**: exp_000_parity_v2
- **covariate_files**: none
- **data_dir**: published 2026-10-05 (//ABMI-DATA2/science/sdmMethodsDev/0_data/test_dataset/2026-10-05)
- **engines**: bayesglm, glm, xgboost
- **focal_species**: bird=AMRO, bird=YEWA, bryophyte=Bryum.All, bryophyte=Ceratodon.purpureus, lichen=Cladonia.chlorophaea, lichen=Physcia.adscendens, mammal=Coyote_Summer, mammal=Coyote_Winter, mammal=Moose_Summer, mammal=Moose_Winter, mite=Ceratozetes.gracilis, mite=Trhypochthonius.tectorum, vascular_plant=Galium.boreale, vascular_plant=Vicia.americana
- **jobs_not_ok**: 0
- **jobs_ok**: 2800
- **jobs_total**: 2800
- **n_bootstraps**: 100
- **plant_bootstrap**: spatial_block
- **selection**: aic_average, hurdle, single
- **species_n**: 14
- **stage_models**: spec defaults (v2 candidate sets)
- **taxa**: bird, bryophyte, lichen, mammal_summer, mammal_winter, mite, vascular_plant
- **v2_bootstraps**: 100

## Coverage

| taxon | region | species | draws | coefficient_rows | metric_rows | grid_rows |
| --- | --- | --- | --- | --- | --- | --- |
| bird | north | 2 | 100 | 2000 | 2800 | 17800 |
| bird | south | 2 | 100 | 2000 | 2800 | 3400 |
| bryophyte | north | 2 | 100 | 3800 | 2800 | 8600 |
| bryophyte | south | 2 | 100 | 3800 | 2800 | 3200 |
| lichen | north | 2 | 100 | 3800 | 2800 | 8600 |
| lichen | south | 2 | 100 | 3800 | 2800 | 3200 |
| mammal_summer | north | 2 | 100 | 27000 | 2800 | 9000 |
| mammal_summer | south | 2 | 100 | 12000 | 2800 | 4000 |
| mammal_winter | north | 2 | 100 | 27000 | 2800 | 9000 |
| mammal_winter | south | 2 | 100 | 12000 | 2800 | 4000 |
| mite | north | 2 | 100 | 3800 | 2800 | 8600 |
| mite | south | 2 | 100 | 3800 | 2800 | 3200 |
| vascular_plant | north | 2 | 100 | 3800 | 2800 | 8600 |
| vascular_plant | south | 2 | 100 | 3800 | 2800 | 3200 |

## Metrics

| taxon | region | metric | n | median | p10 | p90 | mean | sd |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| bird | north | insample_auc | 200 | 0.7958 | 0.7636 | 0.8329 | 0.7982 | 0.0333 |
| bird | north | insample_calibration_slope | 200 | 1.0287 | 0.9421 | 1.1209 | 1.0317 | 0.0852 |
| bird | north | insample_deviance_explained | 200 | 0.2863 | 0.2197 | 0.3668 | 0.2927 | 0.0713 |
| bird | north | insample_n | 200 | 46751.0000 | 46746.9000 | 46756.1000 | 46751.0000 | 3.7804 |
| bird | north | insample_prevalence | 200 | 0.1847 | 0.1183 | 0.2520 | 0.1850 | 0.0662 |
| bird | north | insample_rmse | 200 | 0.5610 | 0.4868 | 0.6361 | 0.5617 | 0.0723 |
| bird | north | insample_spearman | 200 | 0.3846 | 0.3732 | 0.4097 | 0.3908 | 0.0162 |
| bird | north | oob_auc | 200 | 0.7696 | 0.7572 | 0.7839 | 0.7702 | 0.0125 |
| bird | north | oob_calibration_slope | 200 | 0.9774 | 0.8847 | 1.0659 | 0.9741 | 0.0795 |
| bird | north | oob_deviance_explained | 200 | 0.2333 | 0.2085 | 0.2651 | 0.2360 | 0.0267 |
| bird | north | oob_n | 200 | 124873.0000 | 124867.9000 | 124877.1000 | 124873.0000 | 3.7804 |
| bird | north | oob_prevalence | 200 | 0.1874 | 0.1341 | 0.2415 | 0.1877 | 0.0536 |
| bird | north | oob_rmse | 200 | 0.5918 | 0.5419 | 0.6398 | 0.5910 | 0.0478 |
| bird | north | oob_spearman | 200 | 0.3640 | 0.3360 | 0.3906 | 0.3637 | 0.0260 |
| bird | south | insample_auc | 200 | 0.7674 | 0.7599 | 0.7870 | 0.7727 | 0.0116 |
| bird | south | insample_calibration_slope | 200 | 1.0599 | 0.9572 | 1.2415 | 1.0943 | 0.1338 |
| bird | south | insample_deviance_explained | 200 | 0.2581 | 0.2012 | 0.3378 | 0.2681 | 0.0644 |
| bird | south | insample_n | 200 | 23760.0000 | 23758.0000 | 23763.0000 | 23760.3200 | 1.8205 |
| bird | south | insample_prevalence | 200 | 0.2148 | 0.1713 | 0.2592 | 0.2150 | 0.0428 |
| bird | south | insample_rmse | 200 | 0.6495 | 0.5778 | 0.7079 | 0.6436 | 0.0612 |
| bird | south | insample_spearman | 200 | 0.3881 | 0.3775 | 0.4056 | 0.3910 | 0.0124 |
| bird | south | oob_auc | 200 | 0.7431 | 0.7321 | 0.7606 | 0.7458 | 0.0127 |
| bird | south | oob_calibration_slope | 200 | 0.9770 | 0.8766 | 1.0879 | 0.9815 | 0.0908 |
| bird | south | oob_deviance_explained | 200 | 0.2112 | 0.1610 | 0.2656 | 0.2127 | 0.0502 |
| bird | south | oob_n | 200 | 67241.0000 | 67238.0000 | 67243.0000 | 67240.6800 | 1.8205 |
| bird | south | oob_prevalence | 200 | 0.2174 | 0.1750 | 0.2605 | 0.2177 | 0.0425 |
| bird | south | oob_rmse | 200 | 0.6668 | 0.6148 | 0.7159 | 0.6655 | 0.0491 |
| bird | south | oob_spearman | 200 | 0.3539 | 0.3455 | 0.3613 | 0.3539 | 0.0065 |
| bryophyte | north | insample_auc | 200 | 0.8683 | 0.8559 | 0.8812 | 0.8674 | 0.0153 |
| bryophyte | north | insample_calibration_slope | 200 | 1.3566 | 1.2953 | 1.4262 | 1.3594 | 0.0532 |
| bryophyte | north | insample_deviance_explained | 200 | 0.2994 | 0.2778 | 0.3385 | 0.3046 | 0.0299 |
| bryophyte | north | insample_n | 200 | 3069.0000 | 3035.0000 | 3101.0000 | 3086.6150 | 179.5128 |
| bryophyte | north | insample_prevalence | 200 | 0.4195 | 0.3957 | 0.4466 | 0.4205 | 0.0215 |
| bryophyte | north | insample_rmse | 200 | 0.3901 | 0.3812 | 0.3973 | 0.3905 | 0.0087 |
| bryophyte | north | insample_spearman | 200 | 0.6241 | 0.6040 | 0.6556 | 0.6277 | 0.0288 |
| bryophyte | north | oob_auc | 198 | 0.6800 | 0.6466 | 0.7181 | 0.6815 | 0.0290 |
| bryophyte | north | oob_calibration_slope | 198 | 0.7007 | 0.5948 | 0.8109 | 0.7052 | 0.0831 |
| bryophyte | north | oob_deviance_explained | 198 | 0.0498 | 0.0142 | 0.0987 | 0.0551 | 0.0316 |
| bryophyte | north | oob_n | 200 | 1783.0000 | 1751.0000 | 1817.0000 | 1765.3850 | 179.5128 |
| bryophyte | north | oob_prevalence | 198 | 0.4186 | 0.3933 | 0.4485 | 0.4206 | 0.0219 |
| bryophyte | north | oob_rmse | 198 | 0.4727 | 0.4617 | 0.4817 | 0.4723 | 0.0077 |
| bryophyte | north | oob_spearman | 198 | 0.3073 | 0.2492 | 0.3755 | 0.3104 | 0.0514 |
| bryophyte | south | insample_auc | 200 | 0.9144 | 0.8876 | 0.9415 | 0.9139 | 0.0214 |
| bryophyte | south | insample_calibration_slope | 200 | 1.2433 | 1.1911 | 1.2929 | 1.2431 | 0.0448 |
| bryophyte | south | insample_deviance_explained | 200 | 0.4184 | 0.3527 | 0.5001 | 0.4209 | 0.0564 |
| bryophyte | south | insample_n | 200 | 1461.5000 | 1440.9000 | 1484.0000 | 1469.9300 | 86.4473 |
| bryophyte | south | insample_prevalence | 200 | 0.3038 | 0.2345 | 0.3768 | 0.3050 | 0.0656 |
| bryophyte | south | insample_rmse | 200 | 0.3375 | 0.2902 | 0.3681 | 0.3296 | 0.0310 |
| bryophyte | south | insample_spearman | 200 | 0.6527 | 0.6142 | 0.6891 | 0.6508 | 0.0313 |
| bryophyte | south | oob_auc | 198 | 0.7418 | 0.7022 | 0.7845 | 0.7449 | 0.0320 |
| bryophyte | south | oob_calibration_slope | 198 | 0.7110 | 0.6316 | 0.8122 | 0.7190 | 0.0749 |
| bryophyte | south | oob_deviance_explained | 198 | 0.0965 | 0.0407 | 0.1563 | 0.0952 | 0.0438 |
| bryophyte | south | oob_n | 200 | 848.5000 | 826.0000 | 869.1000 | 840.0700 | 86.4473 |
| bryophyte | south | oob_prevalence | 198 | 0.3062 | 0.2295 | 0.3842 | 0.3056 | 0.0673 |
| bryophyte | south | oob_rmse | 198 | 0.4259 | 0.3873 | 0.4641 | 0.4260 | 0.0327 |
| bryophyte | south | oob_spearman | 198 | 0.3832 | 0.3382 | 0.4233 | 0.3831 | 0.0315 |
| lichen | north | insample_auc | 200 | 0.9130 | 0.9012 | 0.9430 | 0.9222 | 0.0196 |
| lichen | north | insample_calibration_slope | 200 | 1.1519 | 1.1119 | 1.2103 | 1.1580 | 0.0405 |
| lichen | north | insample_deviance_explained | 200 | 0.4242 | 0.3972 | 0.5389 | 0.4670 | 0.0660 |
| lichen | north | insample_n | 200 | 3674.5000 | 3639.0000 | 3709.0000 | 3695.5700 | 214.7712 |
| lichen | north | insample_prevalence | 200 | 0.3844 | 0.3787 | 0.3905 | 0.3847 | 0.0044 |
| lichen | north | insample_rmse | 200 | 0.3500 | 0.3033 | 0.3592 | 0.3319 | 0.0261 |
| lichen | north | insample_spearman | 200 | 0.6966 | 0.6767 | 0.7476 | 0.7115 | 0.0331 |
| lichen | north | oob_auc | 198 | 0.8290 | 0.7826 | 0.8702 | 0.8271 | 0.0396 |
| lichen | north | oob_calibration_slope | 198 | 0.9030 | 0.8380 | 0.9499 | 0.8968 | 0.0430 |
| lichen | north | oob_deviance_explained | 198 | 0.2629 | 0.1840 | 0.3415 | 0.2619 | 0.0691 |
| lichen | north | oob_n | 200 | 2136.5000 | 2102.0000 | 2172.0000 | 2115.4300 | 214.7712 |
| lichen | north | oob_prevalence | 198 | 0.3841 | 0.3745 | 0.3945 | 0.3839 | 0.0076 |
| lichen | north | oob_rmse | 198 | 0.4018 | 0.3726 | 0.4305 | 0.4019 | 0.0258 |
| lichen | north | oob_spearman | 198 | 0.5544 | 0.4750 | 0.6237 | 0.5510 | 0.0667 |
| lichen | south | insample_auc | 200 | 0.9712 | 0.9569 | 0.9803 | 0.9694 | 0.0105 |
| lichen | south | insample_calibration_slope | 200 | 1.1705 | 1.1245 | 1.2644 | 1.1844 | 0.0546 |
| lichen | south | insample_deviance_explained | 200 | 0.6081 | 0.5243 | 0.6704 | 0.6002 | 0.0626 |
| lichen | south | insample_n | 200 | 1482.5000 | 1459.0000 | 1509.0000 | 1491.0850 | 88.0622 |
| lichen | south | insample_prevalence | 200 | 0.1501 | 0.0887 | 0.2202 | 0.1537 | 0.0613 |
| lichen | south | insample_rmse | 200 | 0.2159 | 0.1883 | 0.2442 | 0.2172 | 0.0225 |
| lichen | south | insample_spearman | 200 | 0.5605 | 0.4577 | 0.6814 | 0.5698 | 0.1012 |
| lichen | south | oob_auc | 198 | 0.8647 | 0.8359 | 0.8858 | 0.8632 | 0.0207 |
| lichen | south | oob_calibration_slope | 198 | 0.8139 | 0.6209 | 0.9302 | 0.7852 | 0.1214 |
| lichen | south | oob_deviance_explained | 198 | 0.2584 | 0.1366 | 0.3479 | 0.2472 | 0.0857 |
| lichen | south | oob_n | 200 | 863.5000 | 837.0000 | 887.0000 | 854.9150 | 88.0622 |
| lichen | south | oob_prevalence | 198 | 0.1503 | 0.0880 | 0.2276 | 0.1554 | 0.0631 |
| lichen | south | oob_rmse | 198 | 0.3071 | 0.2667 | 0.3400 | 0.3026 | 0.0308 |
| lichen | south | oob_spearman | 198 | 0.4424 | 0.3345 | 0.5536 | 0.4450 | 0.0962 |
| mammal_summer | north | insample_auc | 200 | 0.8581 | 0.8016 | 0.9232 | 0.8625 | 0.0515 |
| mammal_summer | north | insample_calibration_slope | 200 | 1.1981 | 1.0736 | 1.3503 | 1.2003 | 0.1134 |
| mammal_summer | north | insample_deviance_explained | 200 | 0.3281 | 0.2188 | 0.5058 | 0.3563 | 0.1192 |
| mammal_summer | north | insample_n | 200 | 2563.5000 | 2538.0000 | 2587.0000 | 2577.0800 | 149.9873 |
| mammal_summer | north | insample_prevalence | 200 | 0.2733 | 0.2209 | 0.3269 | 0.2735 | 0.0486 |
| mammal_summer | north | insample_rmse | 200 | 0.3381 | 0.2718 | 0.3921 | 0.3329 | 0.0529 |
| mammal_summer | north | insample_spearman | 200 | 0.5427 | 0.4776 | 0.6083 | 0.5443 | 0.0550 |
| mammal_summer | north | oob_auc | 198 | 0.7320 | 0.6239 | 0.8311 | 0.7279 | 0.0939 |
| mammal_summer | north | oob_calibration_slope | 198 | 0.7328 | 0.5138 | 0.9043 | 0.7140 | 0.1560 |
| mammal_summer | north | oob_deviance_explained | 198 | 0.1175 | -0.0039 | 0.2809 | 0.1324 | 0.1232 |
| mammal_summer | north | oob_n | 200 | 1489.5000 | 1466.0000 | 1515.0000 | 1475.9200 | 149.9873 |
| mammal_summer | north | oob_prevalence | 198 | 0.2735 | 0.2193 | 0.3287 | 0.2728 | 0.0485 |
| mammal_summer | north | oob_rmse | 198 | 0.3881 | 0.3254 | 0.4475 | 0.3871 | 0.0567 |
| mammal_summer | north | oob_spearman | 198 | 0.3434 | 0.1906 | 0.4736 | 0.3326 | 0.1280 |
| mammal_summer | south | insample_auc | 200 | 0.9372 | 0.8497 | 0.9834 | 0.9236 | 0.0581 |
| mammal_summer | south | insample_calibration_slope | 200 | 1.3248 | 1.1967 | 1.4731 | 1.3418 | 0.1705 |
| mammal_summer | south | insample_deviance_explained | 200 | 0.4830 | 0.2127 | 0.7205 | 0.4694 | 0.2018 |
| mammal_summer | south | insample_n | 200 | 674.5000 | 662.0000 | 689.0000 | 678.4000 | 40.3178 |
| mammal_summer | south | insample_prevalence | 200 | 0.4333 | 0.1750 | 0.6993 | 0.4364 | 0.2552 |
| mammal_summer | south | insample_rmse | 200 | 0.2750 | 0.2031 | 0.3572 | 0.2821 | 0.0615 |
| mammal_summer | south | insample_spearman | 200 | 0.6063 | 0.4993 | 0.6518 | 0.5879 | 0.0693 |
| mammal_summer | south | oob_auc | 198 | 0.6964 | 0.5793 | 0.8222 | 0.7000 | 0.1072 |
| mammal_summer | south | oob_calibration_slope | 198 | 0.6194 | 0.2620 | 0.9144 | 0.5829 | 0.2462 |
| mammal_summer | south | oob_deviance_explained | 198 | 0.0110 | -0.1348 | 0.2337 | 0.0397 | 0.1496 |
| mammal_summer | south | oob_n | 200 | 390.5000 | 376.0000 | 403.0000 | 386.6000 | 40.3178 |
| mammal_summer | south | oob_prevalence | 198 | 0.4362 | 0.1686 | 0.7076 | 0.4370 | 0.2560 |
| mammal_summer | south | oob_rmse | 198 | 0.4024 | 0.3277 | 0.4540 | 0.3920 | 0.0549 |
| mammal_summer | south | oob_spearman | 198 | 0.2732 | 0.0934 | 0.4331 | 0.2647 | 0.1456 |
| mammal_winter | north | insample_auc | 200 | 0.9002 | 0.8548 | 0.9364 | 0.8983 | 0.0312 |
| mammal_winter | north | insample_calibration_slope | 200 | 1.1917 | 1.0741 | 1.3188 | 1.1931 | 0.0985 |
| mammal_winter | north | insample_deviance_explained | 200 | 0.4193 | 0.3160 | 0.5419 | 0.4265 | 0.0850 |
| mammal_winter | north | insample_n | 200 | 2609.5000 | 2585.0000 | 2640.1000 | 2626.3900 | 152.6091 |
| mammal_winter | north | insample_prevalence | 200 | 0.1764 | 0.1455 | 0.2061 | 0.1760 | 0.0269 |
| mammal_winter | north | insample_rmse | 200 | 0.2731 | 0.2476 | 0.2941 | 0.2715 | 0.0170 |
| mammal_winter | north | insample_spearman | 200 | 0.5120 | 0.4346 | 0.6058 | 0.5227 | 0.0662 |
| mammal_winter | north | oob_auc | 198 | 0.7752 | 0.6821 | 0.8527 | 0.7692 | 0.0752 |
| mammal_winter | north | oob_calibration_slope | 198 | 0.7656 | 0.5352 | 0.9157 | 0.7370 | 0.1418 |
| mammal_winter | north | oob_deviance_explained | 198 | 0.1574 | 0.0360 | 0.3124 | 0.1707 | 0.1157 |
| mammal_winter | north | oob_n | 200 | 1517.5000 | 1486.9000 | 1542.0000 | 1500.6100 | 152.6091 |
| mammal_winter | north | oob_prevalence | 198 | 0.1742 | 0.1426 | 0.2060 | 0.1734 | 0.0271 |
| mammal_winter | north | oob_rmse | 198 | 0.3196 | 0.2964 | 0.3391 | 0.3189 | 0.0167 |
| mammal_winter | north | oob_spearman | 198 | 0.3637 | 0.2263 | 0.4812 | 0.3550 | 0.1141 |
| mammal_winter | south | insample_auc | 200 | 0.9264 | 0.8584 | 0.9852 | 0.9277 | 0.0461 |
| mammal_winter | south | insample_calibration_slope | 200 | 1.2845 | 1.1743 | 1.4493 | 1.3122 | 0.1691 |
| mammal_winter | south | insample_deviance_explained | 200 | 0.4432 | 0.2834 | 0.7411 | 0.4947 | 0.1691 |
| mammal_winter | south | insample_n | 200 | 695.0000 | 682.0000 | 709.0000 | 699.1600 | 41.4843 |
| mammal_winter | south | insample_prevalence | 200 | 0.3351 | 0.0822 | 0.6144 | 0.3449 | 0.2590 |
| mammal_winter | south | insample_rmse | 200 | 0.2440 | 0.1354 | 0.3408 | 0.2378 | 0.0826 |
| mammal_winter | south | insample_spearman | 200 | 0.5022 | 0.4257 | 0.7170 | 0.5554 | 0.1160 |
| mammal_winter | south | oob_auc | 198 | 0.7337 | 0.6532 | 0.8294 | 0.7352 | 0.0705 |
| mammal_winter | south | oob_calibration_slope | 198 | 0.5300 | 0.3979 | 0.7960 | 0.5699 | 0.1857 |
| mammal_winter | south | oob_deviance_explained | 198 | 0.0265 | -0.1157 | 0.1905 | 0.0299 | 0.1202 |
| mammal_winter | south | oob_n | 200 | 403.0000 | 389.0000 | 416.0000 | 398.8400 | 41.4843 |
| mammal_winter | south | oob_prevalence | 198 | 0.3423 | 0.0803 | 0.6235 | 0.3480 | 0.2608 |
| mammal_winter | south | oob_rmse | 198 | 0.3335 | 0.2224 | 0.4321 | 0.3301 | 0.0948 |
| mammal_winter | south | oob_spearman | 198 | 0.2794 | 0.2280 | 0.3279 | 0.2804 | 0.0381 |
| mite | north | insample_auc | 200 | 0.8908 | 0.8388 | 0.9127 | 0.8824 | 0.0336 |
| mite | north | insample_calibration_slope | 200 | 1.2278 | 1.1697 | 1.4382 | 1.2864 | 0.1128 |
| mite | north | insample_deviance_explained | 200 | 0.3219 | 0.2244 | 0.4135 | 0.3281 | 0.0801 |
| mite | north | insample_n | 200 | 3611.0000 | 3575.8000 | 3648.1000 | 3631.9500 | 211.3664 |
| mite | north | insample_prevalence | 200 | 0.1491 | 0.0931 | 0.2122 | 0.1518 | 0.0567 |
| mite | north | insample_rmse | 200 | 0.2929 | 0.2516 | 0.3117 | 0.2838 | 0.0257 |
| mite | north | insample_spearman | 200 | 0.4590 | 0.3441 | 0.5817 | 0.4682 | 0.1073 |
| mite | north | oob_auc | 198 | 0.7426 | 0.6494 | 0.8156 | 0.7357 | 0.0721 |
| mite | north | oob_calibration_slope | 198 | 0.7788 | 0.5045 | 0.9033 | 0.7287 | 0.1586 |
| mite | north | oob_deviance_explained | 198 | 0.1001 | -0.0038 | 0.2095 | 0.1031 | 0.0918 |
| mite | north | oob_n | 200 | 2100.0000 | 2062.9000 | 2135.2000 | 2079.0500 | 211.3664 |
| mite | north | oob_prevalence | 198 | 0.1509 | 0.0922 | 0.2141 | 0.1524 | 0.0568 |
| mite | north | oob_rmse | 198 | 0.3273 | 0.2868 | 0.3655 | 0.3267 | 0.0351 |
| mite | north | oob_spearman | 198 | 0.3038 | 0.1536 | 0.4454 | 0.2998 | 0.1326 |
| mite | south | insample_auc | 200 | 0.9674 | 0.9280 | 0.9911 | 0.9636 | 0.0277 |
| mite | south | insample_calibration_slope | 200 | 1.2165 | 1.1203 | 1.3296 | 1.2269 | 0.0958 |
| mite | south | insample_deviance_explained | 200 | 0.5554 | 0.3978 | 0.7458 | 0.5731 | 0.1376 |
| mite | south | insample_n | 200 | 1492.5000 | 1471.0000 | 1516.1000 | 1501.9250 | 88.5699 |
| mite | south | insample_prevalence | 200 | 0.0681 | 0.0529 | 0.0865 | 0.0696 | 0.0144 |
| mite | south | insample_rmse | 200 | 0.1826 | 0.1223 | 0.2226 | 0.1735 | 0.0421 |
| mite | south | insample_spearman | 200 | 0.3997 | 0.3735 | 0.4403 | 0.4044 | 0.0272 |
| mite | south | oob_auc | 198 | 0.8169 | 0.7260 | 0.9202 | 0.8244 | 0.0813 |
| mite | south | oob_calibration_slope | 198 | 0.7516 | 0.5094 | 1.0019 | 0.7545 | 0.1928 |
| mite | south | oob_deviance_explained | 198 | 0.1527 | 0.0051 | 0.3972 | 0.1903 | 0.1555 |
| mite | south | oob_n | 200 | 870.5000 | 846.9000 | 892.0000 | 861.0750 | 88.5699 |
| mite | south | oob_prevalence | 198 | 0.0680 | 0.0520 | 0.0901 | 0.0702 | 0.0148 |
| mite | south | oob_rmse | 198 | 0.2237 | 0.1833 | 0.2785 | 0.2313 | 0.0408 |
| mite | south | oob_spearman | 198 | 0.2777 | 0.2173 | 0.3399 | 0.2792 | 0.0493 |
| vascular_plant | north | insample_auc | 200 | 0.9388 | 0.9354 | 0.9423 | 0.9387 | 0.0028 |
| vascular_plant | north | insample_calibration_slope | 200 | 1.1336 | 1.1237 | 1.1458 | 1.1341 | 0.0084 |
| vascular_plant | north | insample_deviance_explained | 200 | 0.5207 | 0.5082 | 0.5339 | 0.5207 | 0.0102 |
| vascular_plant | north | insample_n | 200 | 4350.0000 | 4321.9000 | 4383.0000 | 4375.3700 | 253.0075 |
| vascular_plant | north | insample_prevalence | 200 | 0.3962 | 0.3735 | 0.4214 | 0.3976 | 0.0206 |
| vascular_plant | north | insample_rmse | 200 | 0.3118 | 0.3066 | 0.3157 | 0.3117 | 0.0036 |
| vascular_plant | north | insample_spearman | 200 | 0.7424 | 0.7316 | 0.7549 | 0.7432 | 0.0091 |
| vascular_plant | north | oob_auc | 198 | 0.8721 | 0.8634 | 0.8805 | 0.8721 | 0.0068 |
| vascular_plant | north | oob_calibration_slope | 198 | 0.9594 | 0.9266 | 0.9918 | 0.9598 | 0.0258 |
| vascular_plant | north | oob_deviance_explained | 198 | 0.3469 | 0.3252 | 0.3683 | 0.3462 | 0.0179 |
| vascular_plant | north | oob_n | 200 | 2524.0000 | 2491.0000 | 2552.1000 | 2498.6300 | 253.0075 |
| vascular_plant | north | oob_prevalence | 198 | 0.3937 | 0.3713 | 0.4251 | 0.3985 | 0.0225 |
| vascular_plant | north | oob_rmse | 198 | 0.3745 | 0.3673 | 0.3815 | 0.3744 | 0.0057 |
| vascular_plant | north | oob_spearman | 198 | 0.6297 | 0.6140 | 0.6474 | 0.6304 | 0.0132 |
| vascular_plant | south | insample_auc | 200 | 0.9759 | 0.9630 | 0.9890 | 0.9763 | 0.0106 |
| vascular_plant | south | insample_calibration_slope | 200 | 1.1009 | 1.0691 | 1.1473 | 1.1069 | 0.0316 |
| vascular_plant | south | insample_deviance_explained | 200 | 0.6700 | 0.6049 | 0.7701 | 0.6839 | 0.0657 |
| vascular_plant | south | insample_n | 200 | 1674.0000 | 1652.0000 | 1698.1000 | 1683.8950 | 98.6476 |
| vascular_plant | south | insample_prevalence | 200 | 0.2431 | 0.2173 | 0.2692 | 0.2430 | 0.0219 |
| vascular_plant | south | insample_rmse | 200 | 0.2267 | 0.1864 | 0.2570 | 0.2235 | 0.0285 |
| vascular_plant | south | insample_spearman | 200 | 0.7064 | 0.6905 | 0.7226 | 0.7060 | 0.0122 |
| vascular_plant | south | oob_auc | 198 | 0.9063 | 0.8665 | 0.9427 | 0.9061 | 0.0313 |
| vascular_plant | south | oob_calibration_slope | 198 | 0.9211 | 0.8591 | 0.9652 | 0.9174 | 0.0422 |
| vascular_plant | south | oob_deviance_explained | 198 | 0.4039 | 0.3138 | 0.5322 | 0.4185 | 0.0869 |
| vascular_plant | south | oob_n | 200 | 974.0000 | 949.9000 | 996.0000 | 964.1050 | 98.6476 |
| vascular_plant | south | oob_prevalence | 198 | 0.2453 | 0.2136 | 0.2763 | 0.2436 | 0.0247 |
| vascular_plant | south | oob_rmse | 198 | 0.3083 | 0.2698 | 0.3486 | 0.3099 | 0.0323 |
| vascular_plant | south | oob_spearman | 198 | 0.6019 | 0.5614 | 0.6427 | 0.6012 | 0.0313 |

