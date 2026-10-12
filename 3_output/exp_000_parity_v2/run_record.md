# Run record: exp_000_parity_v2

Written by `run_record()`. The result stores this describes are gitignored; this file is what remains.

## Provenance

_Volatile. Excluded from cross-run comparison._

- **git_commit**: 4a8cb32
- **pipeline_dir**: D:/local_projects/active/sdmMethodsDev/2_pipeline/exp_000_parity_v2
- **r_version**: 4.5.0
- **written_at**: 2026-10-08 09:59:23

## Configuration

- **boot_seed**: 20260909.0000
- **changes_from_v2**: none
- **compared_with**: none (baseline)
- **covariate_files**: none
- **data_dir**: published 2026-10-05 (//ABMI-DATA2/science/sdmMethodsDev/0_data/test_dataset/2026-10-05)
- **engines**: bayesglm, glm
- **focal_species**: bird=AMRO, bird=YEWA, bryophyte=Bryum.All, bryophyte=Ceratodon.purpureus, lichen=Cladonia.chlorophaea, lichen=Physcia.adscendens, mammal=Coyote_Summer, mammal=Coyote_Winter, mammal=Moose_Summer, mammal=Moose_Winter, mite=Ceratozetes.gracilis, mite=Trhypochthonius.tectorum, vascular_plant=Galium.boreale, vascular_plant=Vicia.americana
- **jobs_not_ok**: 1
- **jobs_ok**: 2799
- **jobs_total**: 2800
- **n_bootstraps**: 100
- **plant_bootstrap**: spatial_block
- **selection**: aic_average, hurdle, ivw_grid, staged_bic
- **species_n**: 14
- **stage_models**: spec defaults (v2 candidate sets)
- **taxa**: bird, bryophyte, lichen, mammal_summer, mammal_winter, mite, vascular_plant
- **v2_bootstraps**: 100

## Coverage

| taxon | region | species | draws | coefficient_rows | metric_rows | grid_rows |
| --- | --- | --- | --- | --- | --- | --- |
| bird | north | 2 | 100 | 9380 | 2800 | 17800 |
| bird | south | 2 | 100 | 6986 | 2800 | 3400 |
| bryophyte | north | 2 | 100 | 22000 | 5600 | 8600 |
| bryophyte | south | 2 | 100 | 7800 | 5600 | 3200 |
| lichen | north | 2 | 100 | 22000 | 5600 | 8600 |
| lichen | south | 2 | 100 | 7800 | 5600 | 3200 |
| mammal_summer | north | 2 | 100 | 43450 | 2800 | 9000 |
| mammal_summer | south | 2 | 100 | 13731 | 2786 | 3980 |
| mammal_winter | north | 2 | 100 | 44008 | 2800 | 9000 |
| mammal_winter | south | 2 | 100 | 13800 | 2800 | 4000 |
| mite | north | 2 | 100 | 21800 | 5600 | 8600 |
| mite | south | 2 | 100 | 7600 | 5600 | 3200 |
| vascular_plant | north | 2 | 100 | 21800 | 5600 | 8600 |
| vascular_plant | south | 2 | 100 | 7600 | 5600 | 3200 |

## Metrics

| taxon | region | metric | n | median | p10 | p90 | mean | sd |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| bird | north | insample_auc | 200 | 0.7500 | 0.7218 | 0.7798 | 0.7506 | 0.0276 |
| bird | north | insample_calibration_slope | 200 | 0.7722 | 0.6665 | 0.8113 | 0.7438 | 0.0642 |
| bird | north | insample_deviance_explained | 200 | 0.1986 | 0.1403 | 0.2614 | 0.2004 | 0.0587 |
| bird | north | insample_n | 200 | 46751.0000 | 46746.9000 | 46756.1000 | 46751.0000 | 3.7804 |
| bird | north | insample_prevalence | 200 | 0.1847 | 0.1183 | 0.2520 | 0.1850 | 0.0662 |
| bird | north | insample_rmse | 200 | 0.6168 | 0.5471 | 0.6665 | 0.6079 | 0.0561 |
| bird | north | insample_spearman | 200 | 0.3268 | 0.3129 | 0.3440 | 0.3282 | 0.0135 |
| bird | north | oob_auc | 200 | 0.7300 | 0.7283 | 0.7318 | 0.7300 | 0.0014 |
| bird | north | oob_calibration_slope | 200 | 0.7890 | 0.6073 | 0.8883 | 0.7598 | 0.1235 |
| bird | north | oob_deviance_explained | 200 | 0.1637 | 0.1508 | 0.1808 | 0.1654 | 0.0135 |
| bird | north | oob_n | 200 | 124873.0000 | 124867.9000 | 124877.1000 | 124873.0000 | 3.7804 |
| bird | north | oob_prevalence | 200 | 0.1874 | 0.1341 | 0.2415 | 0.1877 | 0.0536 |
| bird | north | oob_rmse | 200 | 0.6356 | 0.5854 | 0.6588 | 0.6249 | 0.0334 |
| bird | north | oob_spearman | 200 | 0.3108 | 0.2728 | 0.3502 | 0.3113 | 0.0376 |
| bird | south | insample_auc | 200 | 0.7048 | 0.6906 | 0.7212 | 0.7057 | 0.0137 |
| bird | south | insample_calibration_slope | 200 | 0.8737 | 0.8625 | 0.9017 | 0.8790 | 0.0150 |
| bird | south | insample_deviance_explained | 200 | 0.1578 | 0.0908 | 0.2349 | 0.1620 | 0.0698 |
| bird | south | insample_n | 200 | 23638.0000 | 23635.0000 | 23641.0000 | 23638.2600 | 2.2174 |
| bird | south | insample_prevalence | 200 | 0.2151 | 0.1714 | 0.2596 | 0.2153 | 0.0429 |
| bird | south | insample_rmse | 200 | 0.6840 | 0.6223 | 0.7470 | 0.6847 | 0.0588 |
| bird | south | insample_spearman | 200 | 0.2942 | 0.2895 | 0.2994 | 0.2941 | 0.0039 |
| bird | south | oob_auc | 200 | 0.7012 | 0.6882 | 0.7164 | 0.7019 | 0.0131 |
| bird | south | oob_calibration_slope | 200 | 0.8829 | 0.8479 | 0.9478 | 0.8932 | 0.0402 |
| bird | south | oob_deviance_explained | 200 | 0.1475 | 0.0919 | 0.2042 | 0.1483 | 0.0529 |
| bird | south | oob_n | 200 | 67169.0000 | 67166.0000 | 67172.0000 | 67168.7400 | 2.2174 |
| bird | south | oob_prevalence | 200 | 0.2175 | 0.1751 | 0.2606 | 0.2178 | 0.0425 |
| bird | south | oob_rmse | 200 | 0.6870 | 0.6369 | 0.7370 | 0.6869 | 0.0488 |
| bird | south | oob_spearman | 200 | 0.2911 | 0.2888 | 0.2936 | 0.2911 | 0.0019 |
| bryophyte | north | insample_auc | 200 | 0.6680 | 0.6329 | 0.7027 | 0.6686 | 0.0297 |
| bryophyte | north | insample_calibration_slope | 200 | 0.8589 | 0.7752 | 0.9074 | 0.8466 | 0.0529 |
| bryophyte | north | insample_deviance_explained | 200 | -0.1748 | -0.2679 | -0.0981 | -0.1825 | 0.0656 |
| bryophyte | north | insample_n | 200 | 3069.0000 | 3035.0000 | 3101.0000 | 3086.6150 | 179.5128 |
| bryophyte | north | insample_prevalence | 200 | 0.4195 | 0.3957 | 0.4466 | 0.4205 | 0.0215 |
| bryophyte | north | insample_rmse | 200 | 0.4729 | 0.4647 | 0.4804 | 0.4726 | 0.0064 |
| bryophyte | north | insample_spearman | 200 | 0.2870 | 0.2261 | 0.3483 | 0.2883 | 0.0526 |
| bryophyte | north | oob_auc | 198 | 0.6547 | 0.6113 | 0.6909 | 0.6520 | 0.0321 |
| bryophyte | north | oob_calibration_slope | 198 | 0.7839 | 0.6265 | 0.8891 | 0.7652 | 0.1028 |
| bryophyte | north | oob_deviance_explained | 198 | -0.1941 | -0.3103 | -0.0973 | -0.2016 | 0.0836 |
| bryophyte | north | oob_n | 200 | 1783.0000 | 1751.0000 | 1817.0000 | 1765.3850 | 179.5128 |
| bryophyte | north | oob_prevalence | 198 | 0.4186 | 0.3933 | 0.4485 | 0.4206 | 0.0219 |
| bryophyte | north | oob_rmse | 198 | 0.4775 | 0.4677 | 0.4866 | 0.4775 | 0.0071 |
| bryophyte | north | oob_spearman | 198 | 0.2648 | 0.1893 | 0.3288 | 0.2600 | 0.0564 |
| bryophyte | north | oob_v2val_Climate | 198 | 0.6045 | 0.5460 | 0.6535 | 0.5999 | 0.0478 |
| bryophyte | north | oob_v2val_Climate_Truncated | 198 | 0.6045 | 0.5459 | 0.6535 | 0.5999 | 0.0479 |
| bryophyte | north | oob_v2val_Full | 198 | 0.6547 | 0.6113 | 0.6909 | 0.6520 | 0.0321 |
| bryophyte | north | oob_v2val_Full_Joint | 198 | 0.6525 | 0.6101 | 0.6885 | 0.6498 | 0.0313 |
| bryophyte | north | oob_v2val_Full_Joint_Truncated | 198 | 0.6534 | 0.6104 | 0.6886 | 0.6501 | 0.0311 |
| bryophyte | north | oob_v2val_Full_Truncated | 198 | 0.6555 | 0.6115 | 0.6910 | 0.6523 | 0.0320 |
| bryophyte | north | oob_v2val_Landcover | 198 | 0.5970 | 0.5707 | 0.6262 | 0.5975 | 0.0219 |
| bryophyte | north | v2val_Climate | 200 | 0.6069 | 0.5588 | 0.6582 | 0.6085 | 0.0456 |
| bryophyte | north | v2val_Climate_Truncated | 200 | 0.6069 | 0.5588 | 0.6582 | 0.6085 | 0.0457 |
| bryophyte | north | v2val_Full | 200 | 0.6680 | 0.6329 | 0.7027 | 0.6686 | 0.0297 |
| bryophyte | north | v2val_Full_Joint | 200 | 0.6660 | 0.6316 | 0.6994 | 0.6661 | 0.0288 |
| bryophyte | north | v2val_Full_Joint_Truncated | 200 | 0.6662 | 0.6326 | 0.6996 | 0.6665 | 0.0286 |
| bryophyte | north | v2val_Full_Truncated | 200 | 0.6682 | 0.6341 | 0.7028 | 0.6689 | 0.0295 |
| bryophyte | north | v2val_Landcover | 200 | 0.6103 | 0.5865 | 0.6342 | 0.6103 | 0.0195 |
| bryophyte | south | insample_auc | 200 | 0.6758 | 0.6249 | 0.7251 | 0.6759 | 0.0435 |
| bryophyte | south | insample_calibration_slope | 200 | 0.8998 | 0.8402 | 0.9680 | 0.9030 | 0.0527 |
| bryophyte | south | insample_deviance_explained | 200 | 0.0102 | -0.0965 | 0.0790 | -0.0061 | 0.0681 |
| bryophyte | south | insample_n | 200 | 1461.5000 | 1440.9000 | 1484.0000 | 1469.9300 | 86.4473 |
| bryophyte | south | insample_prevalence | 200 | 0.3038 | 0.2345 | 0.3768 | 0.3050 | 0.0656 |
| bryophyte | south | insample_rmse | 200 | 0.4411 | 0.3996 | 0.4745 | 0.4379 | 0.0349 |
| bryophyte | south | insample_spearman | 200 | 0.2761 | 0.2093 | 0.3338 | 0.2731 | 0.0521 |
| bryophyte | south | oob_auc | 198 | 0.6605 | 0.6050 | 0.7223 | 0.6633 | 0.0484 |
| bryophyte | south | oob_calibration_slope | 198 | 0.8186 | 0.6598 | 1.0048 | 0.8291 | 0.1351 |
| bryophyte | south | oob_deviance_explained | 198 | -0.0111 | -0.1185 | 0.0835 | -0.0144 | 0.0734 |
| bryophyte | south | oob_n | 200 | 848.5000 | 826.0000 | 869.1000 | 840.0700 | 86.4473 |
| bryophyte | south | oob_prevalence | 198 | 0.3062 | 0.2295 | 0.3842 | 0.3056 | 0.0673 |
| bryophyte | south | oob_rmse | 198 | 0.4439 | 0.3996 | 0.4797 | 0.4415 | 0.0356 |
| bryophyte | south | oob_spearman | 198 | 0.2511 | 0.1747 | 0.3324 | 0.2529 | 0.0613 |
| bryophyte | south | oob_v2val_Climate | 198 | 0.6045 | 0.5460 | 0.6535 | 0.5999 | 0.0478 |
| bryophyte | south | oob_v2val_Climate_Truncated | 198 | 0.6045 | 0.5459 | 0.6535 | 0.5999 | 0.0479 |
| bryophyte | south | oob_v2val_Full | 198 | 0.6605 | 0.6050 | 0.7223 | 0.6633 | 0.0484 |
| bryophyte | south | oob_v2val_Full_Joint | 198 | 0.6613 | 0.6046 | 0.7229 | 0.6636 | 0.0489 |
| bryophyte | south | oob_v2val_Full_Joint_Truncated | 198 | 0.6613 | 0.6048 | 0.7229 | 0.6636 | 0.0489 |
| bryophyte | south | oob_v2val_Full_Truncated | 198 | 0.6605 | 0.6050 | 0.7223 | 0.6634 | 0.0484 |
| bryophyte | south | oob_v2val_Landcover | 198 | 0.6058 | 0.5744 | 0.6394 | 0.6074 | 0.0243 |
| bryophyte | south | v2val_Climate | 200 | 0.6069 | 0.5588 | 0.6582 | 0.6085 | 0.0456 |
| bryophyte | south | v2val_Climate_Truncated | 200 | 0.6069 | 0.5588 | 0.6582 | 0.6085 | 0.0457 |
| bryophyte | south | v2val_Full | 200 | 0.6758 | 0.6249 | 0.7251 | 0.6759 | 0.0435 |
| bryophyte | south | v2val_Full_Joint | 200 | 0.6771 | 0.6255 | 0.7263 | 0.6763 | 0.0442 |
| bryophyte | south | v2val_Full_Joint_Truncated | 200 | 0.6771 | 0.6256 | 0.7263 | 0.6764 | 0.0442 |
| bryophyte | south | v2val_Full_Truncated | 200 | 0.6759 | 0.6249 | 0.7251 | 0.6760 | 0.0435 |
| bryophyte | south | v2val_Landcover | 200 | 0.6182 | 0.5948 | 0.6421 | 0.6183 | 0.0179 |
| lichen | north | insample_auc | 200 | 0.8091 | 0.7720 | 0.8423 | 0.8075 | 0.0317 |
| lichen | north | insample_calibration_slope | 200 | 0.9953 | 0.9646 | 1.0282 | 0.9962 | 0.0251 |
| lichen | north | insample_deviance_explained | 200 | 0.1415 | 0.1093 | 0.1775 | 0.1421 | 0.0262 |
| lichen | north | insample_n | 200 | 3674.5000 | 3639.0000 | 3709.0000 | 3695.5700 | 214.7712 |
| lichen | north | insample_prevalence | 200 | 0.3844 | 0.3787 | 0.3905 | 0.3847 | 0.0044 |
| lichen | north | insample_rmse | 200 | 0.4121 | 0.3905 | 0.4311 | 0.4114 | 0.0185 |
| lichen | north | insample_spearman | 200 | 0.5199 | 0.4581 | 0.5773 | 0.5182 | 0.0534 |
| lichen | north | oob_auc | 198 | 0.8039 | 0.7636 | 0.8410 | 0.8021 | 0.0333 |
| lichen | north | oob_calibration_slope | 198 | 0.9760 | 0.9323 | 1.0323 | 0.9797 | 0.0398 |
| lichen | north | oob_deviance_explained | 198 | 0.1292 | 0.0853 | 0.1698 | 0.1284 | 0.0356 |
| lichen | north | oob_n | 200 | 2136.5000 | 2102.0000 | 2172.0000 | 2115.4300 | 214.7712 |
| lichen | north | oob_prevalence | 198 | 0.3841 | 0.3745 | 0.3945 | 0.3839 | 0.0076 |
| lichen | north | oob_rmse | 198 | 0.4153 | 0.3918 | 0.4350 | 0.4140 | 0.0186 |
| lichen | north | oob_spearman | 198 | 0.5109 | 0.4440 | 0.5747 | 0.5088 | 0.0560 |
| lichen | north | oob_v2val_Climate | 198 | 0.7084 | 0.6845 | 0.7263 | 0.7051 | 0.0168 |
| lichen | north | oob_v2val_Climate_Truncated | 198 | 0.7084 | 0.6845 | 0.7263 | 0.7051 | 0.0168 |
| lichen | north | oob_v2val_Full | 198 | 0.8039 | 0.7636 | 0.8410 | 0.8021 | 0.0333 |
| lichen | north | oob_v2val_Full_Joint | 198 | 0.8020 | 0.7631 | 0.8384 | 0.8006 | 0.0327 |
| lichen | north | oob_v2val_Full_Joint_Truncated | 198 | 0.8021 | 0.7631 | 0.8386 | 0.8007 | 0.0328 |
| lichen | north | oob_v2val_Full_Truncated | 198 | 0.8040 | 0.7638 | 0.8411 | 0.8021 | 0.0333 |
| lichen | north | oob_v2val_Landcover | 198 | 0.7459 | 0.6978 | 0.8174 | 0.7562 | 0.0508 |
| lichen | north | v2val_Climate | 200 | 0.7072 | 0.6898 | 0.7278 | 0.7085 | 0.0159 |
| lichen | north | v2val_Climate_Truncated | 200 | 0.7072 | 0.6898 | 0.7278 | 0.7085 | 0.0159 |
| lichen | north | v2val_Full | 200 | 0.8091 | 0.7720 | 0.8423 | 0.8075 | 0.0317 |
| lichen | north | v2val_Full_Joint | 200 | 0.8077 | 0.7715 | 0.8400 | 0.8061 | 0.0312 |
| lichen | north | v2val_Full_Joint_Truncated | 200 | 0.8077 | 0.7716 | 0.8402 | 0.8062 | 0.0313 |
| lichen | north | v2val_Full_Truncated | 200 | 0.8092 | 0.7718 | 0.8425 | 0.8075 | 0.0318 |
| lichen | north | v2val_Landcover | 200 | 0.7453 | 0.7048 | 0.8159 | 0.7581 | 0.0496 |
| lichen | south | insample_auc | 200 | 0.8072 | 0.7724 | 0.8287 | 0.8021 | 0.0232 |
| lichen | south | insample_calibration_slope | 200 | 0.9202 | 0.8580 | 1.0346 | 0.9299 | 0.0703 |
| lichen | south | insample_deviance_explained | 200 | 0.1751 | 0.0455 | 0.2520 | 0.1563 | 0.0871 |
| lichen | south | insample_n | 200 | 1482.5000 | 1459.0000 | 1509.0000 | 1491.0850 | 88.0622 |
| lichen | south | insample_prevalence | 200 | 0.1501 | 0.0887 | 0.2202 | 0.1537 | 0.0613 |
| lichen | south | insample_rmse | 200 | 0.3151 | 0.2719 | 0.3608 | 0.3162 | 0.0405 |
| lichen | south | insample_spearman | 200 | 0.3713 | 0.2697 | 0.4685 | 0.3709 | 0.0892 |
| lichen | south | oob_auc | 198 | 0.7929 | 0.7520 | 0.8241 | 0.7913 | 0.0286 |
| lichen | south | oob_calibration_slope | 198 | 0.8842 | 0.7349 | 1.0758 | 0.8967 | 0.1312 |
| lichen | south | oob_deviance_explained | 198 | 0.1669 | -0.0025 | 0.2428 | 0.1355 | 0.0992 |
| lichen | south | oob_n | 200 | 863.5000 | 837.0000 | 887.0000 | 854.9150 | 88.0622 |
| lichen | south | oob_prevalence | 198 | 0.1503 | 0.0880 | 0.2276 | 0.1554 | 0.0631 |
| lichen | south | oob_rmse | 198 | 0.3204 | 0.2710 | 0.3680 | 0.3203 | 0.0424 |
| lichen | south | oob_spearman | 198 | 0.3640 | 0.2520 | 0.4637 | 0.3594 | 0.0921 |
| lichen | south | oob_v2val_Climate | 198 | 0.7084 | 0.6845 | 0.7263 | 0.7051 | 0.0168 |
| lichen | south | oob_v2val_Climate_Truncated | 198 | 0.7084 | 0.6845 | 0.7263 | 0.7051 | 0.0168 |
| lichen | south | oob_v2val_Full | 198 | 0.7929 | 0.7520 | 0.8241 | 0.7913 | 0.0286 |
| lichen | south | oob_v2val_Full_Joint | 198 | 0.7932 | 0.7527 | 0.8219 | 0.7903 | 0.0270 |
| lichen | south | oob_v2val_Full_Joint_Truncated | 198 | 0.7932 | 0.7527 | 0.8219 | 0.7903 | 0.0270 |
| lichen | south | oob_v2val_Full_Truncated | 198 | 0.7929 | 0.7520 | 0.8241 | 0.7913 | 0.0286 |
| lichen | south | oob_v2val_Landcover | 198 | 0.7499 | 0.7160 | 0.7745 | 0.7475 | 0.0223 |
| lichen | south | v2val_Climate | 200 | 0.7072 | 0.6898 | 0.7278 | 0.7085 | 0.0159 |
| lichen | south | v2val_Climate_Truncated | 200 | 0.7072 | 0.6898 | 0.7278 | 0.7085 | 0.0159 |
| lichen | south | v2val_Full | 200 | 0.8072 | 0.7724 | 0.8287 | 0.8021 | 0.0232 |
| lichen | south | v2val_Full_Joint | 200 | 0.8057 | 0.7733 | 0.8261 | 0.8013 | 0.0213 |
| lichen | south | v2val_Full_Joint_Truncated | 200 | 0.8057 | 0.7733 | 0.8261 | 0.8013 | 0.0213 |
| lichen | south | v2val_Full_Truncated | 200 | 0.8072 | 0.7724 | 0.8287 | 0.8021 | 0.0232 |
| lichen | south | v2val_Landcover | 200 | 0.7520 | 0.7339 | 0.7705 | 0.7526 | 0.0143 |
| mammal_summer | north | insample_auc | 200 | 0.7195 | 0.6076 | 0.8295 | 0.7195 | 0.1048 |
| mammal_summer | north | insample_calibration_slope | 200 | 0.9415 | 0.7950 | 0.9994 | 0.9143 | 0.0790 |
| mammal_summer | north | insample_deviance_explained | 200 | 0.1457 | 0.0267 | 0.2897 | 0.1557 | 0.1242 |
| mammal_summer | north | insample_n | 200 | 2563.5000 | 2538.0000 | 2587.0000 | 2577.0800 | 149.9873 |
| mammal_summer | north | insample_prevalence | 200 | 0.2733 | 0.2209 | 0.3269 | 0.2735 | 0.0486 |
| mammal_summer | north | insample_rmse | 200 | 0.3850 | 0.3230 | 0.4431 | 0.3836 | 0.0575 |
| mammal_summer | north | insample_spearman | 200 | 0.3181 | 0.1570 | 0.4710 | 0.3152 | 0.1473 |
| mammal_summer | north | oob_auc | 198 | 0.7008 | 0.5803 | 0.8199 | 0.7002 | 0.1098 |
| mammal_summer | north | oob_calibration_slope | 198 | 0.8458 | 0.5527 | 0.9867 | 0.7990 | 0.1680 |
| mammal_summer | north | oob_deviance_explained | 198 | 0.0563 | 0.0013 | 0.2662 | 0.1234 | 0.1179 |
| mammal_summer | north | oob_n | 200 | 1489.5000 | 1466.0000 | 1515.0000 | 1475.9200 | 149.9873 |
| mammal_summer | north | oob_prevalence | 198 | 0.2735 | 0.2193 | 0.3287 | 0.2728 | 0.0485 |
| mammal_summer | north | oob_rmse | 198 | 0.3917 | 0.3259 | 0.4480 | 0.3883 | 0.0571 |
| mammal_summer | north | oob_spearman | 198 | 0.2890 | 0.1134 | 0.4545 | 0.2851 | 0.1566 |
| mammal_summer | south | insample_auc | 199 | 0.7546 | 0.6196 | 0.7995 | 0.7107 | 0.0791 |
| mammal_summer | south | insample_calibration_slope | 199 | 0.9613 | 0.8460 | 1.0524 | 0.9550 | 0.0819 |
| mammal_summer | south | insample_deviance_explained | 199 | 0.1647 | 0.0214 | 0.2324 | 0.1205 | 0.0943 |
| mammal_summer | south | insample_n | 199 | 674.0000 | 662.0000 | 689.0000 | 678.4171 | 40.4188 |
| mammal_summer | south | insample_prevalence | 199 | 0.2069 | 0.1750 | 0.6994 | 0.4351 | 0.2552 |
| mammal_summer | south | insample_rmse | 199 | 0.3563 | 0.3391 | 0.4250 | 0.3822 | 0.0389 |
| mammal_summer | south | insample_spearman | 199 | 0.3342 | 0.1592 | 0.3998 | 0.2818 | 0.1044 |
| mammal_summer | south | oob_auc | 197 | 0.7154 | 0.5675 | 0.7903 | 0.6784 | 0.0930 |
| mammal_summer | south | oob_calibration_slope | 197 | 0.7382 | 0.3358 | 1.0724 | 0.7360 | 0.2780 |
| mammal_summer | south | oob_deviance_explained | 197 | 0.0147 | -0.0349 | 0.2068 | 0.0619 | 0.1132 |
| mammal_summer | south | oob_n | 199 | 391.0000 | 376.0000 | 403.0000 | 386.5829 | 40.4188 |
| mammal_summer | south | oob_prevalence | 197 | 0.2300 | 0.1685 | 0.7076 | 0.4357 | 0.2560 |
| mammal_summer | south | oob_rmse | 197 | 0.3897 | 0.3411 | 0.4384 | 0.3914 | 0.0411 |
| mammal_summer | south | oob_spearman | 197 | 0.2707 | 0.0727 | 0.3889 | 0.2325 | 0.1292 |
| mammal_winter | north | insample_auc | 200 | 0.7665 | 0.6675 | 0.8446 | 0.7591 | 0.0814 |
| mammal_winter | north | insample_calibration_slope | 200 | 0.9541 | 0.8712 | 1.0110 | 0.9464 | 0.0554 |
| mammal_winter | north | insample_deviance_explained | 200 | 0.1900 | 0.0702 | 0.3056 | 0.1876 | 0.1090 |
| mammal_winter | north | insample_n | 200 | 2609.5000 | 2585.0000 | 2640.1000 | 2626.3900 | 152.6091 |
| mammal_winter | north | insample_prevalence | 200 | 0.1764 | 0.1455 | 0.2061 | 0.1760 | 0.0269 |
| mammal_winter | north | insample_rmse | 200 | 0.3161 | 0.2973 | 0.3353 | 0.3168 | 0.0164 |
| mammal_winter | north | insample_spearman | 200 | 0.3518 | 0.2111 | 0.4734 | 0.3443 | 0.1214 |
| mammal_winter | north | oob_auc | 198 | 0.7540 | 0.6364 | 0.8417 | 0.7404 | 0.0916 |
| mammal_winter | north | oob_calibration_slope | 198 | 0.8826 | 0.6191 | 1.0325 | 0.8552 | 0.1596 |
| mammal_winter | north | oob_deviance_explained | 198 | 0.0839 | 0.0080 | 0.2921 | 0.1494 | 0.1240 |
| mammal_winter | north | oob_n | 200 | 1517.5000 | 1486.9000 | 1542.0000 | 1500.6100 | 152.6091 |
| mammal_winter | north | oob_prevalence | 198 | 0.1742 | 0.1426 | 0.2060 | 0.1734 | 0.0271 |
| mammal_winter | north | oob_rmse | 198 | 0.3199 | 0.2972 | 0.3413 | 0.3193 | 0.0172 |
| mammal_winter | north | oob_spearman | 198 | 0.3263 | 0.1702 | 0.4645 | 0.3186 | 0.1319 |
| mammal_winter | south | insample_auc | 200 | 0.7315 | 0.6779 | 0.8331 | 0.7557 | 0.0673 |
| mammal_winter | south | insample_calibration_slope | 200 | 0.9493 | 0.8167 | 1.0904 | 0.9489 | 0.1093 |
| mammal_winter | south | insample_deviance_explained | 200 | 0.1130 | 0.0574 | 0.2652 | 0.1552 | 0.0897 |
| mammal_winter | south | insample_n | 200 | 695.0000 | 682.0000 | 709.0000 | 699.1600 | 41.4843 |
| mammal_winter | south | insample_prevalence | 200 | 0.3351 | 0.0822 | 0.6144 | 0.3449 | 0.2590 |
| mammal_winter | south | insample_rmse | 200 | 0.3196 | 0.2155 | 0.4099 | 0.3142 | 0.0927 |
| mammal_winter | south | insample_spearman | 200 | 0.3081 | 0.2774 | 0.3331 | 0.3064 | 0.0216 |
| mammal_winter | south | oob_auc | 198 | 0.7123 | 0.6520 | 0.8075 | 0.7227 | 0.0632 |
| mammal_winter | south | oob_calibration_slope | 198 | 0.7412 | 0.4709 | 1.0531 | 0.7570 | 0.2412 |
| mammal_winter | south | oob_deviance_explained | 198 | 0.0619 | 0.0061 | 0.1945 | 0.0691 | 0.1295 |
| mammal_winter | south | oob_n | 200 | 403.0000 | 389.0000 | 416.0000 | 398.8400 | 41.4843 |
| mammal_winter | south | oob_prevalence | 198 | 0.3423 | 0.0803 | 0.6235 | 0.3480 | 0.2608 |
| mammal_winter | south | oob_rmse | 198 | 0.3325 | 0.2222 | 0.4211 | 0.3238 | 0.0914 |
| mammal_winter | south | oob_spearman | 198 | 0.2687 | 0.2234 | 0.3096 | 0.2658 | 0.0350 |
| mite | north | insample_auc | 200 | 0.7415 | 0.6711 | 0.7964 | 0.7353 | 0.0572 |
| mite | north | insample_calibration_slope | 200 | 0.9839 | 0.8742 | 1.0308 | 0.9642 | 0.0621 |
| mite | north | insample_deviance_explained | 200 | 0.0588 | -0.0563 | 0.1372 | 0.0443 | 0.0839 |
| mite | north | insample_n | 200 | 3611.0000 | 3575.8000 | 3648.1000 | 3631.9500 | 211.3664 |
| mite | north | insample_prevalence | 200 | 0.1491 | 0.0931 | 0.2122 | 0.1518 | 0.0567 |
| mite | north | insample_rmse | 200 | 0.3256 | 0.2845 | 0.3667 | 0.3259 | 0.0384 |
| mite | north | insample_spearman | 200 | 0.2993 | 0.1746 | 0.4176 | 0.2962 | 0.1150 |
| mite | north | oob_auc | 198 | 0.7251 | 0.6397 | 0.7915 | 0.7189 | 0.0675 |
| mite | north | oob_calibration_slope | 198 | 0.9315 | 0.6371 | 1.0449 | 0.8882 | 0.1596 |
| mite | north | oob_deviance_explained | 198 | 0.0502 | -0.0980 | 0.1381 | 0.0288 | 0.0941 |
| mite | north | oob_n | 200 | 2100.0000 | 2062.9000 | 2135.2000 | 2079.0500 | 211.3664 |
| mite | north | oob_prevalence | 198 | 0.1509 | 0.0922 | 0.2141 | 0.1524 | 0.0568 |
| mite | north | oob_rmse | 198 | 0.3320 | 0.2860 | 0.3708 | 0.3290 | 0.0386 |
| mite | north | oob_spearman | 198 | 0.2784 | 0.1432 | 0.4123 | 0.2784 | 0.1237 |
| mite | north | oob_v2val_Climate | 198 | 0.6902 | 0.6270 | 0.7420 | 0.6865 | 0.0501 |
| mite | north | oob_v2val_Climate_Truncated | 198 | 0.6902 | 0.6270 | 0.7420 | 0.6865 | 0.0501 |
| mite | north | oob_v2val_Full | 198 | 0.7251 | 0.6397 | 0.7915 | 0.7189 | 0.0675 |
| mite | north | oob_v2val_Full_Joint | 198 | 0.7243 | 0.6393 | 0.7914 | 0.7186 | 0.0677 |
| mite | north | oob_v2val_Full_Joint_Truncated | 198 | 0.7243 | 0.6394 | 0.7914 | 0.7186 | 0.0676 |
| mite | north | oob_v2val_Full_Truncated | 198 | 0.7251 | 0.6398 | 0.7913 | 0.7188 | 0.0674 |
| mite | north | oob_v2val_Landcover | 198 | 0.6958 | 0.5964 | 0.7674 | 0.6853 | 0.0750 |
| mite | north | v2val_Climate | 200 | 0.6938 | 0.6397 | 0.7436 | 0.6922 | 0.0464 |
| mite | north | v2val_Climate_Truncated | 200 | 0.6938 | 0.6396 | 0.7436 | 0.6922 | 0.0464 |
| mite | north | v2val_Full | 200 | 0.7415 | 0.6711 | 0.7964 | 0.7353 | 0.0572 |
| mite | north | v2val_Full_Joint | 200 | 0.7411 | 0.6708 | 0.7961 | 0.7352 | 0.0574 |
| mite | north | v2val_Full_Joint_Truncated | 200 | 0.7411 | 0.6708 | 0.7961 | 0.7352 | 0.0574 |
| mite | north | v2val_Full_Truncated | 200 | 0.7414 | 0.6710 | 0.7964 | 0.7353 | 0.0572 |
| mite | north | v2val_Landcover | 200 | 0.7117 | 0.6394 | 0.7723 | 0.7069 | 0.0604 |
| mite | south | insample_auc | 200 | 0.7987 | 0.6949 | 0.8911 | 0.7952 | 0.0884 |
| mite | south | insample_calibration_slope | 200 | 0.7827 | 0.5943 | 1.0282 | 0.8015 | 0.1774 |
| mite | south | insample_deviance_explained | 200 | 0.0714 | -0.0206 | 0.2038 | 0.0867 | 0.0874 |
| mite | south | insample_n | 200 | 1492.5000 | 1471.0000 | 1516.1000 | 1501.9250 | 88.5699 |
| mite | south | insample_prevalence | 200 | 0.0681 | 0.0529 | 0.0865 | 0.0696 | 0.0144 |
| mite | south | insample_rmse | 200 | 0.2450 | 0.2088 | 0.2746 | 0.2431 | 0.0281 |
| mite | south | insample_spearman | 200 | 0.2518 | 0.1872 | 0.3139 | 0.2515 | 0.0542 |
| mite | south | oob_auc | 198 | 0.7758 | 0.6618 | 0.8935 | 0.7787 | 0.0971 |
| mite | south | oob_calibration_slope | 198 | 0.6830 | 0.5045 | 1.0690 | 0.7293 | 0.2066 |
| mite | south | oob_deviance_explained | 198 | 0.0527 | -0.0600 | 0.2229 | 0.0656 | 0.1095 |
| mite | south | oob_n | 200 | 870.5000 | 846.9000 | 892.0000 | 861.0750 | 88.5699 |
| mite | south | oob_prevalence | 198 | 0.0680 | 0.0520 | 0.0901 | 0.0702 | 0.0148 |
| mite | south | oob_rmse | 198 | 0.2468 | 0.2122 | 0.2827 | 0.2473 | 0.0274 |
| mite | south | oob_spearman | 198 | 0.2340 | 0.1528 | 0.3192 | 0.2377 | 0.0653 |
| mite | south | oob_v2val_Climate | 198 | 0.6902 | 0.6270 | 0.7420 | 0.6865 | 0.0501 |
| mite | south | oob_v2val_Climate_Truncated | 198 | 0.6902 | 0.6270 | 0.7420 | 0.6865 | 0.0501 |
| mite | south | oob_v2val_Full | 198 | 0.7758 | 0.6618 | 0.8935 | 0.7787 | 0.0971 |
| mite | south | oob_v2val_Full_Joint | 198 | 0.7761 | 0.6619 | 0.8938 | 0.7791 | 0.0972 |
| mite | south | oob_v2val_Full_Joint_Truncated | 198 | 0.7761 | 0.6619 | 0.8938 | 0.7791 | 0.0972 |
| mite | south | oob_v2val_Full_Truncated | 198 | 0.7758 | 0.6618 | 0.8935 | 0.7787 | 0.0971 |
| mite | south | oob_v2val_Landcover | 198 | 0.6739 | 0.6215 | 0.7295 | 0.6766 | 0.0400 |
| mite | south | v2val_Climate | 200 | 0.6938 | 0.6397 | 0.7436 | 0.6922 | 0.0464 |
| mite | south | v2val_Climate_Truncated | 200 | 0.6938 | 0.6396 | 0.7436 | 0.6922 | 0.0464 |
| mite | south | v2val_Full | 200 | 0.7987 | 0.6949 | 0.8911 | 0.7952 | 0.0884 |
| mite | south | v2val_Full_Joint | 200 | 0.7990 | 0.6953 | 0.8919 | 0.7956 | 0.0885 |
| mite | south | v2val_Full_Joint_Truncated | 200 | 0.7990 | 0.6953 | 0.8919 | 0.7956 | 0.0885 |
| mite | south | v2val_Full_Truncated | 200 | 0.7987 | 0.6949 | 0.8911 | 0.7952 | 0.0884 |
| mite | south | v2val_Landcover | 200 | 0.6921 | 0.6525 | 0.7356 | 0.6942 | 0.0329 |
| vascular_plant | north | insample_auc | 200 | 0.8328 | 0.8275 | 0.8378 | 0.8327 | 0.0042 |
| vascular_plant | north | insample_calibration_slope | 200 | 0.9892 | 0.9680 | 1.0125 | 0.9905 | 0.0170 |
| vascular_plant | north | insample_deviance_explained | 200 | 0.1656 | 0.1397 | 0.1936 | 0.1658 | 0.0210 |
| vascular_plant | north | insample_n | 200 | 4350.0000 | 4321.9000 | 4383.0000 | 4375.3700 | 253.0075 |
| vascular_plant | north | insample_prevalence | 200 | 0.3962 | 0.3735 | 0.4214 | 0.3976 | 0.0206 |
| vascular_plant | north | insample_rmse | 200 | 0.4020 | 0.3958 | 0.4080 | 0.4020 | 0.0047 |
| vascular_plant | north | insample_spearman | 200 | 0.5639 | 0.5550 | 0.5729 | 0.5636 | 0.0072 |
| vascular_plant | north | oob_auc | 198 | 0.8282 | 0.8186 | 0.8382 | 0.8282 | 0.0083 |
| vascular_plant | north | oob_calibration_slope | 198 | 0.9793 | 0.9252 | 1.0295 | 0.9764 | 0.0399 |
| vascular_plant | north | oob_deviance_explained | 198 | 0.1626 | 0.1196 | 0.2008 | 0.1599 | 0.0327 |
| vascular_plant | north | oob_n | 200 | 2524.0000 | 2491.0000 | 2552.1000 | 2498.6300 | 253.0075 |
| vascular_plant | north | oob_prevalence | 198 | 0.3937 | 0.3713 | 0.4251 | 0.3985 | 0.0225 |
| vascular_plant | north | oob_rmse | 198 | 0.4051 | 0.3960 | 0.4145 | 0.4050 | 0.0071 |
| vascular_plant | north | oob_spearman | 198 | 0.5570 | 0.5414 | 0.5706 | 0.5560 | 0.0128 |
| vascular_plant | north | oob_v2val_Climate | 198 | 0.6889 | 0.6788 | 0.6980 | 0.6887 | 0.0077 |
| vascular_plant | north | oob_v2val_Climate_Truncated | 198 | 0.6890 | 0.6788 | 0.6980 | 0.6887 | 0.0077 |
| vascular_plant | north | oob_v2val_Full | 198 | 0.8282 | 0.8186 | 0.8382 | 0.8282 | 0.0083 |
| vascular_plant | north | oob_v2val_Full_Joint | 198 | 0.8270 | 0.8155 | 0.8373 | 0.8268 | 0.0087 |
| vascular_plant | north | oob_v2val_Full_Joint_Truncated | 198 | 0.8272 | 0.8157 | 0.8374 | 0.8268 | 0.0087 |
| vascular_plant | north | oob_v2val_Full_Truncated | 198 | 0.8282 | 0.8187 | 0.8384 | 0.8282 | 0.0082 |
| vascular_plant | north | oob_v2val_Landcover | 198 | 0.8033 | 0.7927 | 0.8137 | 0.8036 | 0.0082 |
| vascular_plant | north | v2val_Climate | 200 | 0.6903 | 0.6846 | 0.6956 | 0.6903 | 0.0046 |
| vascular_plant | north | v2val_Climate_Truncated | 200 | 0.6903 | 0.6846 | 0.6956 | 0.6903 | 0.0046 |
| vascular_plant | north | v2val_Full | 200 | 0.8328 | 0.8275 | 0.8378 | 0.8327 | 0.0042 |
| vascular_plant | north | v2val_Full_Joint | 200 | 0.8314 | 0.8249 | 0.8370 | 0.8312 | 0.0047 |
| vascular_plant | north | v2val_Full_Joint_Truncated | 200 | 0.8315 | 0.8250 | 0.8370 | 0.8313 | 0.0047 |
| vascular_plant | north | v2val_Full_Truncated | 200 | 0.8329 | 0.8276 | 0.8377 | 0.8328 | 0.0042 |
| vascular_plant | north | v2val_Landcover | 200 | 0.8077 | 0.8018 | 0.8141 | 0.8080 | 0.0048 |
| vascular_plant | south | insample_auc | 200 | 0.8496 | 0.8025 | 0.8978 | 0.8500 | 0.0416 |
| vascular_plant | south | insample_calibration_slope | 200 | 0.9564 | 0.9107 | 0.9952 | 0.9536 | 0.0316 |
| vascular_plant | south | insample_deviance_explained | 200 | 0.2665 | 0.1598 | 0.3861 | 0.2718 | 0.0952 |
| vascular_plant | south | insample_n | 200 | 1674.0000 | 1652.0000 | 1698.1000 | 1683.8950 | 98.6476 |
| vascular_plant | south | insample_prevalence | 200 | 0.2431 | 0.2173 | 0.2692 | 0.2430 | 0.0219 |
| vascular_plant | south | insample_rmse | 200 | 0.3493 | 0.3072 | 0.3835 | 0.3459 | 0.0344 |
| vascular_plant | south | insample_spearman | 200 | 0.5166 | 0.4618 | 0.5723 | 0.5173 | 0.0472 |
| vascular_plant | south | oob_auc | 198 | 0.8408 | 0.7938 | 0.8962 | 0.8438 | 0.0428 |
| vascular_plant | south | oob_calibration_slope | 198 | 0.9330 | 0.8603 | 1.0131 | 0.9369 | 0.0606 |
| vascular_plant | south | oob_deviance_explained | 198 | 0.2357 | 0.1368 | 0.3882 | 0.2562 | 0.0968 |
| vascular_plant | south | oob_n | 200 | 974.0000 | 949.9000 | 996.0000 | 964.1050 | 98.6476 |
| vascular_plant | south | oob_prevalence | 198 | 0.2453 | 0.2136 | 0.2763 | 0.2436 | 0.0247 |
| vascular_plant | south | oob_rmse | 198 | 0.3523 | 0.3086 | 0.3883 | 0.3502 | 0.0344 |
| vascular_plant | south | oob_spearman | 198 | 0.5059 | 0.4492 | 0.5736 | 0.5083 | 0.0495 |
| vascular_plant | south | oob_v2val_Climate | 198 | 0.6889 | 0.6788 | 0.6980 | 0.6887 | 0.0077 |
| vascular_plant | south | oob_v2val_Climate_Truncated | 198 | 0.6890 | 0.6788 | 0.6980 | 0.6887 | 0.0077 |
| vascular_plant | south | oob_v2val_Full | 198 | 0.8408 | 0.7938 | 0.8962 | 0.8438 | 0.0428 |
| vascular_plant | south | oob_v2val_Full_Joint | 198 | 0.8371 | 0.7904 | 0.8903 | 0.8392 | 0.0413 |
| vascular_plant | south | oob_v2val_Full_Joint_Truncated | 198 | 0.8371 | 0.7904 | 0.8903 | 0.8391 | 0.0413 |
| vascular_plant | south | oob_v2val_Full_Truncated | 198 | 0.8408 | 0.7938 | 0.8962 | 0.8438 | 0.0428 |
| vascular_plant | south | oob_v2val_Landcover | 198 | 0.7754 | 0.7521 | 0.8003 | 0.7766 | 0.0186 |
| vascular_plant | south | v2val_Climate | 200 | 0.6903 | 0.6846 | 0.6956 | 0.6903 | 0.0046 |
| vascular_plant | south | v2val_Climate_Truncated | 200 | 0.6903 | 0.6846 | 0.6956 | 0.6903 | 0.0046 |
| vascular_plant | south | v2val_Full | 200 | 0.8496 | 0.8025 | 0.8978 | 0.8500 | 0.0416 |
| vascular_plant | south | v2val_Full_Joint | 200 | 0.8441 | 0.8002 | 0.8908 | 0.8451 | 0.0397 |
| vascular_plant | south | v2val_Full_Joint_Truncated | 200 | 0.8441 | 0.8001 | 0.8908 | 0.8451 | 0.0397 |
| vascular_plant | south | v2val_Full_Truncated | 200 | 0.8496 | 0.8025 | 0.8978 | 0.8500 | 0.0416 |
| vascular_plant | south | v2val_Landcover | 200 | 0.7822 | 0.7595 | 0.8038 | 0.7817 | 0.0174 |

