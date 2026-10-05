# Run record: exp_002_soilgrids

Written by `run_record()`. The result stores this describes are gitignored; this file is what remains.

## Provenance

_Volatile. Excluded from cross-run comparison._

- **git_commit**: 2b72a2b
- **pipeline_dir**: D:/local_projects/active/sdmMethodsDev/2_pipeline/exp_002_soilgrids
- **r_version**: 4.5.0
- **written_at**: 2026-10-05 11:17:49

## Configuration

- **boot_seed**: 20260909.0000
- **changes_from_v2**: stage_models: bryophyte.climate, stage_models: lichen.climate, stage_models: mite.climate, stage_models: vascular_plant.climate, stage_models: bird.climate, covariate_files: soilgrids_0_5cm.csv
- **compared_with**: exp_000_parity_v2
- **covariate_files**: soilgrids_0_5cm.csv
- **data_dir**: test_dataset
- **engines**: bayesglm, glm
- **focal_species**: bird=AMRO, bird=YEWA, bryophyte=Bryum.All, bryophyte=Ceratodon.purpureus, lichen=Cladonia.chlorophaea, lichen=Physcia.adscendens, mammal=Coyote_Summer, mammal=Coyote_Winter, mammal=Moose_Summer, mammal=Moose_Winter, mite=Ceratozetes.gracilis, mite=Trhypochthonius.tectorum, vascular_plant=Galium.boreale, vascular_plant=Vicia.americana
- **jobs_not_ok**: 0
- **jobs_ok**: 100
- **jobs_total**: 100
- **n_bootstraps**: 5
- **plant_bootstrap**: spatial_block
- **selection**: aic_average, ivw_grid, staged_bic
- **species_n**: 14
- **stage_models**: bird.climate, bryophyte.climate, lichen.climate, mite.climate, vascular_plant.climate
- **taxa**: bird, bryophyte, lichen, mite, vascular_plant
- **v2_bootstraps**: 100

## Coverage

| taxon | region | species | draws | coefficient_rows | metric_rows | grid_rows |
| --- | --- | --- | --- | --- | --- | --- |
| bird | north | 2 | 5 | 557 | 140 | 890 |
| bird | south | 2 | 5 | 440 | 140 | 170 |
| bryophyte | north | 2 | 5 | 1190 | 140 | 430 |
| bryophyte | south | 2 | 5 | 480 | 140 | 160 |
| lichen | north | 2 | 5 | 1190 | 140 | 430 |
| lichen | south | 2 | 5 | 480 | 140 | 160 |
| mite | north | 2 | 5 | 1180 | 140 | 430 |
| mite | south | 2 | 5 | 470 | 140 | 160 |
| vascular_plant | north | 2 | 5 | 1180 | 140 | 430 |
| vascular_plant | south | 2 | 5 | 470 | 140 | 160 |

## Metrics

| taxon | region | metric | n | median | p10 | p90 | mean | sd |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| bird | north | insample_auc | 10 | 0.7541 | 0.7265 | 0.7797 | 0.7534 | 0.0272 |
| bird | north | insample_calibration_slope | 10 | 0.7426 | 0.6693 | 0.8183 | 0.7415 | 0.0763 |
| bird | north | insample_deviance_explained | 10 | 0.1980 | 0.1450 | 0.2531 | 0.1983 | 0.0554 |
| bird | north | insample_n | 10 | 46747.0000 | 46744.0000 | 46750.0000 | 46747.6000 | 2.3664 |
| bird | north | insample_prevalence | 10 | 0.1851 | 0.1178 | 0.2520 | 0.1850 | 0.0702 |
| bird | north | insample_rmse | 10 | 0.6097 | 0.5551 | 0.6618 | 0.6085 | 0.0554 |
| bird | north | insample_spearman | 10 | 0.3308 | 0.3152 | 0.3508 | 0.3321 | 0.0174 |
| bird | north | oob_auc | 10 | 0.7320 | 0.7284 | 0.7342 | 0.7316 | 0.0027 |
| bird | north | oob_calibration_slope | 10 | 0.7087 | 0.5676 | 0.8262 | 0.7015 | 0.1264 |
| bird | north | oob_deviance_explained | 10 | 0.1607 | 0.1527 | 0.1701 | 0.1611 | 0.0085 |
| bird | north | oob_n | 10 | 124877.0000 | 124874.0000 | 124880.0000 | 124876.4000 | 2.3664 |
| bird | north | oob_prevalence | 10 | 0.1877 | 0.1343 | 0.2411 | 0.1877 | 0.0561 |
| bird | north | oob_rmse | 10 | 0.6351 | 0.5991 | 0.6592 | 0.6308 | 0.0299 |
| bird | north | oob_spearman | 10 | 0.3143 | 0.2731 | 0.3536 | 0.3139 | 0.0416 |
| bird | south | insample_auc | 10 | 0.7199 | 0.7050 | 0.7330 | 0.7193 | 0.0130 |
| bird | south | insample_calibration_slope | 10 | 0.8244 | 0.7483 | 0.8920 | 0.8215 | 0.0726 |
| bird | south | insample_deviance_explained | 10 | 0.1618 | 0.1076 | 0.2277 | 0.1653 | 0.0602 |
| bird | south | insample_n | 10 | 23639.0000 | 23636.0000 | 23640.0000 | 23638.4000 | 1.4298 |
| bird | south | insample_prevalence | 10 | 0.2142 | 0.1711 | 0.2590 | 0.2149 | 0.0459 |
| bird | south | insample_rmse | 10 | 0.6964 | 0.6536 | 0.7409 | 0.6963 | 0.0446 |
| bird | south | insample_spearman | 10 | 0.3123 | 0.3086 | 0.3190 | 0.3130 | 0.0049 |
| bird | south | oob_auc | 10 | 0.7138 | 0.7067 | 0.7233 | 0.7148 | 0.0083 |
| bird | south | oob_calibration_slope | 10 | 0.8552 | 0.7698 | 0.9213 | 0.8423 | 0.0664 |
| bird | south | oob_deviance_explained | 10 | 0.1520 | 0.1115 | 0.1988 | 0.1535 | 0.0434 |
| bird | south | oob_n | 10 | 67168.0000 | 67167.0000 | 67171.0000 | 67168.6000 | 1.4298 |
| bird | south | oob_prevalence | 10 | 0.2178 | 0.1757 | 0.2603 | 0.2180 | 0.0444 |
| bird | south | oob_rmse | 10 | 0.6957 | 0.6590 | 0.7327 | 0.6958 | 0.0384 |
| bird | south | oob_spearman | 10 | 0.3092 | 0.3014 | 0.3182 | 0.3096 | 0.0083 |
| bryophyte | north | insample_auc | 10 | 0.6745 | 0.6438 | 0.7147 | 0.6758 | 0.0333 |
| bryophyte | north | insample_calibration_slope | 10 | 0.8566 | 0.7743 | 0.9035 | 0.8452 | 0.0569 |
| bryophyte | north | insample_deviance_explained | 10 | -0.1839 | -0.2821 | -0.0897 | -0.1872 | 0.0875 |
| bryophyte | north | insample_n | 10 | 3082.5000 | 3033.0000 | 4840.0000 | 3420.2000 | 748.7630 |
| bryophyte | north | insample_prevalence | 10 | 0.4173 | 0.3971 | 0.4428 | 0.4192 | 0.0226 |
| bryophyte | north | insample_rmse | 10 | 0.4717 | 0.4613 | 0.4780 | 0.4708 | 0.0074 |
| bryophyte | north | insample_spearman | 10 | 0.2983 | 0.2437 | 0.3686 | 0.3006 | 0.0590 |
| bryophyte | north | oob_auc | 8 | 0.6598 | 0.6322 | 0.6871 | 0.6600 | 0.0250 |
| bryophyte | north | oob_calibration_slope | 8 | 0.7792 | 0.7056 | 0.8636 | 0.7830 | 0.0679 |
| bryophyte | north | oob_deviance_explained | 8 | -0.1849 | -0.2080 | -0.1268 | -0.1777 | 0.0375 |
| bryophyte | north | oob_n | 10 | 1757.5000 | 0.0000 | 1807.0000 | 1419.8000 | 748.7630 |
| bryophyte | north | oob_prevalence | 8 | 0.4207 | 0.3999 | 0.4507 | 0.4233 | 0.0238 |
| bryophyte | north | oob_rmse | 8 | 0.4788 | 0.4695 | 0.4806 | 0.4767 | 0.0053 |
| bryophyte | north | oob_spearman | 8 | 0.2736 | 0.2243 | 0.3214 | 0.2738 | 0.0446 |
| bryophyte | south | insample_auc | 10 | 0.6764 | 0.6294 | 0.7213 | 0.6751 | 0.0458 |
| bryophyte | south | insample_calibration_slope | 10 | 0.8915 | 0.8418 | 0.9308 | 0.8875 | 0.0505 |
| bryophyte | south | insample_deviance_explained | 10 | -0.0045 | -0.1013 | 0.0597 | -0.0151 | 0.0810 |
| bryophyte | south | insample_n | 10 | 1454.5000 | 1440.8000 | 2310.0000 | 1623.0000 | 362.3789 |
| bryophyte | south | insample_prevalence | 10 | 0.3052 | 0.2352 | 0.3713 | 0.3043 | 0.0687 |
| bryophyte | south | insample_rmse | 10 | 0.4397 | 0.3995 | 0.4742 | 0.4378 | 0.0375 |
| bryophyte | south | insample_spearman | 10 | 0.2745 | 0.2165 | 0.3280 | 0.2716 | 0.0546 |
| bryophyte | south | oob_auc | 8 | 0.6723 | 0.6100 | 0.7113 | 0.6648 | 0.0465 |
| bryophyte | south | oob_calibration_slope | 8 | 0.8245 | 0.7429 | 0.8828 | 0.8190 | 0.0712 |
| bryophyte | south | oob_deviance_explained | 8 | 0.0152 | -0.0449 | 0.0489 | 0.0069 | 0.0399 |
| bryophyte | south | oob_n | 10 | 855.5000 | 0.0000 | 869.2000 | 687.0000 | 362.3789 |
| bryophyte | south | oob_prevalence | 8 | 0.3139 | 0.2297 | 0.3751 | 0.3071 | 0.0716 |
| bryophyte | south | oob_rmse | 8 | 0.4450 | 0.4014 | 0.4768 | 0.4420 | 0.0365 |
| bryophyte | south | oob_spearman | 8 | 0.2677 | 0.1840 | 0.3107 | 0.2559 | 0.0577 |
| lichen | north | insample_auc | 10 | 0.8108 | 0.7822 | 0.8398 | 0.8110 | 0.0287 |
| lichen | north | insample_calibration_slope | 10 | 0.9970 | 0.9817 | 1.0040 | 0.9950 | 0.0122 |
| lichen | north | insample_deviance_explained | 10 | 0.1447 | 0.1127 | 0.1682 | 0.1437 | 0.0233 |
| lichen | north | insample_n | 10 | 3683.5000 | 3648.0000 | 5799.0000 | 4101.0000 | 895.3279 |
| lichen | north | insample_prevalence | 10 | 0.3838 | 0.3809 | 0.3889 | 0.3839 | 0.0037 |
| lichen | north | insample_rmse | 10 | 0.4098 | 0.3943 | 0.4274 | 0.4103 | 0.0166 |
| lichen | north | insample_spearman | 10 | 0.5233 | 0.4764 | 0.5719 | 0.5239 | 0.0482 |
| lichen | north | oob_auc | 8 | 0.7988 | 0.7671 | 0.8385 | 0.8014 | 0.0360 |
| lichen | north | oob_calibration_slope | 8 | 0.9671 | 0.9172 | 1.0156 | 0.9636 | 0.0425 |
| lichen | north | oob_deviance_explained | 8 | 0.1175 | 0.0897 | 0.1810 | 0.1312 | 0.0457 |
| lichen | north | oob_n | 10 | 2115.5000 | 0.0000 | 2151.0000 | 1698.0000 | 895.3279 |
| lichen | north | oob_prevalence | 8 | 0.3867 | 0.3758 | 0.3919 | 0.3854 | 0.0074 |
| lichen | north | oob_rmse | 8 | 0.4177 | 0.3946 | 0.4339 | 0.4154 | 0.0192 |
| lichen | north | oob_spearman | 8 | 0.5050 | 0.4502 | 0.5688 | 0.5081 | 0.0609 |
| lichen | south | insample_auc | 10 | 0.8159 | 0.8090 | 0.8227 | 0.8145 | 0.0081 |
| lichen | south | insample_calibration_slope | 10 | 0.9040 | 0.8837 | 0.9858 | 0.9213 | 0.0510 |
| lichen | south | insample_deviance_explained | 10 | 0.1833 | 0.1122 | 0.2365 | 0.1800 | 0.0594 |
| lichen | south | insample_n | 10 | 1484.5000 | 1478.5000 | 2346.0000 | 1657.8000 | 362.9370 |
| lichen | south | insample_prevalence | 10 | 0.1511 | 0.0868 | 0.2167 | 0.1525 | 0.0659 |
| lichen | south | insample_rmse | 10 | 0.3165 | 0.2665 | 0.3571 | 0.3136 | 0.0448 |
| lichen | south | insample_spearman | 10 | 0.3796 | 0.3059 | 0.4536 | 0.3801 | 0.0749 |
| lichen | south | oob_auc | 8 | 0.8102 | 0.8051 | 0.8167 | 0.8106 | 0.0052 |
| lichen | south | oob_calibration_slope | 8 | 0.9501 | 0.8320 | 1.0148 | 0.9351 | 0.0882 |
| lichen | south | oob_deviance_explained | 8 | 0.1248 | 0.0288 | 0.2400 | 0.1297 | 0.1064 |
| lichen | south | oob_n | 10 | 861.5000 | 0.0000 | 867.5000 | 688.2000 | 362.9370 |
| lichen | south | oob_prevalence | 8 | 0.1578 | 0.0943 | 0.2207 | 0.1582 | 0.0637 |
| lichen | south | oob_rmse | 8 | 0.3253 | 0.2761 | 0.3630 | 0.3220 | 0.0415 |
| lichen | south | oob_spearman | 8 | 0.3824 | 0.3133 | 0.4564 | 0.3831 | 0.0708 |
| mite | north | insample_auc | 10 | 0.7389 | 0.6689 | 0.8071 | 0.7375 | 0.0683 |
| mite | north | insample_calibration_slope | 10 | 0.9673 | 0.9418 | 1.0141 | 0.9757 | 0.0339 |
| mite | north | insample_deviance_explained | 10 | 0.0604 | -0.0403 | 0.1524 | 0.0561 | 0.0924 |
| mite | north | insample_n | 10 | 3625.0000 | 3591.6000 | 5699.0000 | 4033.4000 | 878.0981 |
| mite | north | insample_prevalence | 10 | 0.1545 | 0.0942 | 0.2110 | 0.1529 | 0.0599 |
| mite | north | insample_rmse | 10 | 0.3251 | 0.2868 | 0.3645 | 0.3251 | 0.0388 |
| mite | north | insample_spearman | 10 | 0.3036 | 0.1717 | 0.4335 | 0.3012 | 0.1316 |
| mite | north | oob_auc | 8 | 0.7219 | 0.6345 | 0.7914 | 0.7182 | 0.0766 |
| mite | north | oob_calibration_slope | 8 | 0.8853 | 0.7204 | 1.0177 | 0.8727 | 0.1335 |
| mite | north | oob_deviance_explained | 8 | 0.0326 | -0.0820 | 0.1157 | 0.0210 | 0.1014 |
| mite | north | oob_n | 10 | 2074.0000 | 0.0000 | 2107.4000 | 1665.6000 | 878.0981 |
| mite | north | oob_prevalence | 8 | 0.1509 | 0.0926 | 0.2051 | 0.1496 | 0.0589 |
| mite | north | oob_rmse | 8 | 0.3269 | 0.2857 | 0.3682 | 0.3271 | 0.0417 |
| mite | north | oob_spearman | 8 | 0.2814 | 0.1360 | 0.4065 | 0.2767 | 0.1366 |
| mite | south | insample_auc | 10 | 0.8090 | 0.7263 | 0.8899 | 0.8085 | 0.0824 |
| mite | south | insample_calibration_slope | 10 | 0.8655 | 0.6364 | 1.0239 | 0.8420 | 0.1769 |
| mite | south | insample_deviance_explained | 10 | 0.0741 | 0.0211 | 0.2135 | 0.1104 | 0.0917 |
| mite | south | insample_n | 10 | 1493.0000 | 1480.9000 | 2363.0000 | 1665.8000 | 367.6444 |
| mite | south | insample_prevalence | 10 | 0.0721 | 0.0556 | 0.0841 | 0.0703 | 0.0144 |
| mite | south | insample_rmse | 10 | 0.2418 | 0.2082 | 0.2675 | 0.2389 | 0.0293 |
| mite | south | insample_spearman | 10 | 0.2617 | 0.2163 | 0.3199 | 0.2658 | 0.0493 |
| mite | south | oob_auc | 8 | 0.7973 | 0.6948 | 0.8805 | 0.7897 | 0.0920 |
| mite | south | oob_calibration_slope | 8 | 0.6161 | 0.5692 | 0.8871 | 0.7014 | 0.2137 |
| mite | south | oob_deviance_explained | 8 | 0.0782 | 0.0309 | 0.2029 | 0.1035 | 0.0744 |
| mite | south | oob_n | 10 | 870.0000 | 0.0000 | 882.1000 | 697.2000 | 367.6444 |
| mite | south | oob_prevalence | 8 | 0.0719 | 0.0489 | 0.0868 | 0.0689 | 0.0174 |
| mite | south | oob_rmse | 8 | 0.2425 | 0.2097 | 0.2762 | 0.2428 | 0.0311 |
| mite | south | oob_spearman | 8 | 0.2435 | 0.1802 | 0.3147 | 0.2449 | 0.0581 |
| vascular_plant | north | insample_auc | 10 | 0.8299 | 0.8275 | 0.8344 | 0.8306 | 0.0031 |
| vascular_plant | north | insample_calibration_slope | 10 | 0.9989 | 0.9805 | 1.0079 | 0.9964 | 0.0112 |
| vascular_plant | north | insample_deviance_explained | 10 | 0.1577 | 0.1325 | 0.1769 | 0.1561 | 0.0207 |
| vascular_plant | north | insample_n | 10 | 4338.5000 | 4308.5000 | 6862.0000 | 4838.4000 | 1066.7948 |
| vascular_plant | north | insample_prevalence | 10 | 0.3951 | 0.3773 | 0.4205 | 0.3973 | 0.0204 |
| vascular_plant | north | insample_rmse | 10 | 0.4028 | 0.3977 | 0.4063 | 0.4025 | 0.0036 |
| vascular_plant | north | insample_spearman | 10 | 0.5607 | 0.5560 | 0.5626 | 0.5599 | 0.0044 |
| vascular_plant | north | oob_auc | 8 | 0.8248 | 0.8193 | 0.8282 | 0.8239 | 0.0057 |
| vascular_plant | north | oob_calibration_slope | 8 | 0.9729 | 0.9608 | 0.9918 | 0.9756 | 0.0206 |
| vascular_plant | north | oob_deviance_explained | 8 | 0.1764 | 0.1264 | 0.2002 | 0.1683 | 0.0334 |
| vascular_plant | north | oob_n | 10 | 2523.5000 | 0.0000 | 2553.5000 | 2023.6000 | 1066.7948 |
| vascular_plant | north | oob_prevalence | 8 | 0.3990 | 0.3730 | 0.4273 | 0.3992 | 0.0244 |
| vascular_plant | north | oob_rmse | 8 | 0.4067 | 0.4013 | 0.4115 | 0.4067 | 0.0053 |
| vascular_plant | north | oob_spearman | 8 | 0.5488 | 0.5418 | 0.5583 | 0.5489 | 0.0072 |
| vascular_plant | south | insample_auc | 10 | 0.8434 | 0.8003 | 0.8883 | 0.8446 | 0.0436 |
| vascular_plant | south | insample_calibration_slope | 10 | 0.9422 | 0.9125 | 0.9698 | 0.9389 | 0.0248 |
| vascular_plant | south | insample_deviance_explained | 10 | 0.2676 | 0.1548 | 0.3656 | 0.2616 | 0.0993 |
| vascular_plant | south | insample_n | 10 | 1688.5000 | 1654.9000 | 2648.0000 | 1869.6000 | 410.6067 |
| vascular_plant | south | insample_prevalence | 10 | 0.2438 | 0.2212 | 0.2654 | 0.2437 | 0.0227 |
| vascular_plant | south | insample_rmse | 10 | 0.3499 | 0.3139 | 0.3859 | 0.3501 | 0.0355 |
| vascular_plant | south | insample_spearman | 10 | 0.5101 | 0.4587 | 0.5581 | 0.5098 | 0.0494 |
| vascular_plant | south | oob_auc | 8 | 0.8358 | 0.8038 | 0.8840 | 0.8404 | 0.0376 |
| vascular_plant | south | oob_calibration_slope | 8 | 0.9177 | 0.8994 | 0.9463 | 0.9212 | 0.0221 |
| vascular_plant | south | oob_deviance_explained | 8 | 0.2348 | 0.1654 | 0.3159 | 0.2393 | 0.0767 |
| vascular_plant | south | oob_n | 10 | 959.5000 | 0.0000 | 993.1000 | 778.4000 | 410.6067 |
| vascular_plant | south | oob_prevalence | 8 | 0.2418 | 0.2131 | 0.2706 | 0.2421 | 0.0259 |
| vascular_plant | south | oob_rmse | 8 | 0.3552 | 0.3225 | 0.3848 | 0.3544 | 0.0311 |
| vascular_plant | south | oob_spearman | 8 | 0.4955 | 0.4610 | 0.5476 | 0.5025 | 0.0399 |

