# Run record: exp_000_parity_v2

Written by `run_record()`. The result stores this describes are gitignored; this file is what remains.

## Provenance

_Volatile. Excluded from cross-run comparison._

- **git_commit**: 60d95ae
- **pipeline_dir**: D:/local_projects/active/sdmMethodsDev/2_pipeline/exp_000_parity_v2
- **r_version**: 4.5.0
- **written_at**: 2026-10-06 10:47:32

## Configuration

- **boot_seed**: 20260909.0000
- **changes_from_v2**: none
- **compared_with**: none (baseline)
- **covariate_files**: none
- **data_dir**: published 2026-10-05 (//ABMI-DATA2/science/sdmMethodsDev/0_data/test_dataset/2026-10-05)
- **engines**: bayesglm, glm
- **focal_species**: bird=AMRO, bird=YEWA, bryophyte=Bryum.All, bryophyte=Ceratodon.purpureus, lichen=Cladonia.chlorophaea, lichen=Physcia.adscendens, mammal=Coyote_Summer, mammal=Coyote_Winter, mammal=Moose_Summer, mammal=Moose_Winter, mite=Ceratozetes.gracilis, mite=Trhypochthonius.tectorum, vascular_plant=Galium.boreale, vascular_plant=Vicia.americana
- **jobs_not_ok**: 0
- **jobs_ok**: 140
- **jobs_total**: 140
- **n_bootstraps**: 5
- **plant_bootstrap**: spatial_block
- **selection**: aic_average, hurdle, ivw_grid, staged_bic
- **species_n**: 14
- **stage_models**: spec defaults (v2 candidate sets)
- **taxa**: bird, bryophyte, lichen, mammal_summer, mammal_winter, mite, vascular_plant
- **v2_bootstraps**: 100

## Coverage

| taxon | region | species | draws | coefficient_rows | metric_rows | grid_rows |
| --- | --- | --- | --- | --- | --- | --- |
| bird | north | 2 | 5 | 467 | 140 | 890 |
| bird | south | 2 | 5 | 350 | 140 | 170 |
| bryophyte | north | 2 | 5 | 1100 | 280 | 430 |
| bryophyte | south | 2 | 5 | 390 | 280 | 160 |
| lichen | north | 2 | 5 | 1100 | 280 | 430 |
| lichen | south | 2 | 5 | 390 | 280 | 160 |
| mammal_summer | north | 2 | 5 | 2204 | 140 | 450 |
| mammal_summer | south | 2 | 5 | 690 | 140 | 200 |
| mammal_winter | north | 2 | 5 | 2222 | 140 | 450 |
| mammal_winter | south | 2 | 5 | 690 | 140 | 200 |
| mite | north | 2 | 5 | 1090 | 280 | 430 |
| mite | south | 2 | 5 | 380 | 280 | 160 |
| vascular_plant | north | 2 | 5 | 1090 | 280 | 430 |
| vascular_plant | south | 2 | 5 | 380 | 280 | 160 |

## Metrics

| taxon | region | metric | n | median | p10 | p90 | mean | sd |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| bird | north | insample_auc | 10 | 0.7522 | 0.7235 | 0.7796 | 0.7516 | 0.0288 |
| bird | north | insample_calibration_slope | 10 | 0.7559 | 0.6982 | 0.8102 | 0.7542 | 0.0543 |
| bird | north | insample_deviance_explained | 10 | 0.1996 | 0.1409 | 0.2605 | 0.2005 | 0.0613 |
| bird | north | insample_n | 10 | 46747.0000 | 46744.0000 | 46750.0000 | 46747.6000 | 2.3664 |
| bird | north | insample_prevalence | 10 | 0.1851 | 0.1178 | 0.2520 | 0.1850 | 0.0702 |
| bird | north | insample_rmse | 10 | 0.6070 | 0.5467 | 0.6643 | 0.6056 | 0.0609 |
| bird | north | insample_spearman | 10 | 0.3277 | 0.3148 | 0.3446 | 0.3293 | 0.0149 |
| bird | north | oob_auc | 10 | 0.7299 | 0.7284 | 0.7308 | 0.7296 | 0.0010 |
| bird | north | oob_calibration_slope | 10 | 0.7875 | 0.6454 | 0.8810 | 0.7730 | 0.1073 |
| bird | north | oob_deviance_explained | 10 | 0.1647 | 0.1509 | 0.1821 | 0.1658 | 0.0150 |
| bird | north | oob_n | 10 | 124877.0000 | 124874.0000 | 124880.0000 | 124876.4000 | 2.3664 |
| bird | north | oob_prevalence | 10 | 0.1877 | 0.1343 | 0.2411 | 0.1877 | 0.0561 |
| bird | north | oob_rmse | 10 | 0.6250 | 0.5831 | 0.6583 | 0.6230 | 0.0372 |
| bird | north | oob_spearman | 10 | 0.3117 | 0.2736 | 0.3483 | 0.3110 | 0.0389 |
| bird | south | insample_auc | 10 | 0.7052 | 0.6892 | 0.7215 | 0.7054 | 0.0153 |
| bird | south | insample_calibration_slope | 10 | 0.8775 | 0.8649 | 0.8901 | 0.8777 | 0.0119 |
| bird | south | insample_deviance_explained | 10 | 0.1561 | 0.0911 | 0.2337 | 0.1609 | 0.0728 |
| bird | south | insample_n | 10 | 23639.0000 | 23636.0000 | 23640.0000 | 23638.4000 | 1.4298 |
| bird | south | insample_prevalence | 10 | 0.2142 | 0.1711 | 0.2590 | 0.2149 | 0.0459 |
| bird | south | insample_rmse | 10 | 0.6840 | 0.6232 | 0.7452 | 0.6839 | 0.0623 |
| bird | south | insample_spearman | 10 | 0.2943 | 0.2880 | 0.2978 | 0.2933 | 0.0046 |
| bird | south | oob_auc | 10 | 0.7013 | 0.6892 | 0.7156 | 0.7019 | 0.0134 |
| bird | south | oob_calibration_slope | 10 | 0.9220 | 0.8622 | 0.9549 | 0.9086 | 0.0414 |
| bird | south | oob_deviance_explained | 10 | 0.1483 | 0.0969 | 0.2066 | 0.1498 | 0.0555 |
| bird | south | oob_n | 10 | 67168.0000 | 67167.0000 | 67171.0000 | 67168.6000 | 1.4298 |
| bird | south | oob_prevalence | 10 | 0.2178 | 0.1757 | 0.2603 | 0.2180 | 0.0444 |
| bird | south | oob_rmse | 10 | 0.6869 | 0.6369 | 0.7359 | 0.6867 | 0.0513 |
| bird | south | oob_spearman | 10 | 0.2916 | 0.2888 | 0.2927 | 0.2913 | 0.0017 |
| bryophyte | north | insample_auc | 10 | 0.6642 | 0.6314 | 0.7085 | 0.6676 | 0.0347 |
| bryophyte | north | insample_calibration_slope | 10 | 0.8499 | 0.7585 | 0.8973 | 0.8326 | 0.0644 |
| bryophyte | north | insample_deviance_explained | 10 | -0.1896 | -0.2902 | -0.0937 | -0.1928 | 0.0883 |
| bryophyte | north | insample_n | 10 | 3091.0000 | 3041.1000 | 4852.0000 | 3429.3000 | 750.2771 |
| bryophyte | north | insample_prevalence | 10 | 0.4175 | 0.3976 | 0.4423 | 0.4194 | 0.0223 |
| bryophyte | north | insample_rmse | 10 | 0.4736 | 0.4634 | 0.4802 | 0.4727 | 0.0076 |
| bryophyte | north | insample_spearman | 10 | 0.2805 | 0.2228 | 0.3578 | 0.2866 | 0.0614 |
| bryophyte | north | oob_auc | 8 | 0.6562 | 0.6254 | 0.6808 | 0.6537 | 0.0253 |
| bryophyte | north | oob_calibration_slope | 8 | 0.7707 | 0.6959 | 0.8841 | 0.7784 | 0.0797 |
| bryophyte | north | oob_deviance_explained | 8 | -0.1858 | -0.2157 | -0.1326 | -0.1818 | 0.0371 |
| bryophyte | north | oob_n | 10 | 1761.0000 | 0.0000 | 1810.9000 | 1422.7000 | 750.2771 |
| bryophyte | north | oob_prevalence | 8 | 0.4201 | 0.4007 | 0.4503 | 0.4233 | 0.0233 |
| bryophyte | north | oob_rmse | 8 | 0.4801 | 0.4711 | 0.4829 | 0.4781 | 0.0053 |
| bryophyte | north | oob_spearman | 8 | 0.2675 | 0.2128 | 0.3105 | 0.2630 | 0.0449 |
| bryophyte | north | oob_v2val_Climate | 8 | 0.6045 | 0.5487 | 0.6482 | 0.5986 | 0.0463 |
| bryophyte | north | oob_v2val_Climate_Truncated | 8 | 0.6045 | 0.5486 | 0.6482 | 0.5986 | 0.0463 |
| bryophyte | north | oob_v2val_Full | 8 | 0.6562 | 0.6254 | 0.6808 | 0.6537 | 0.0253 |
| bryophyte | north | oob_v2val_Full_Joint | 8 | 0.6538 | 0.6242 | 0.6786 | 0.6519 | 0.0247 |
| bryophyte | north | oob_v2val_Full_Joint_Truncated | 8 | 0.6546 | 0.6248 | 0.6788 | 0.6524 | 0.0246 |
| bryophyte | north | oob_v2val_Full_Truncated | 8 | 0.6571 | 0.6259 | 0.6811 | 0.6542 | 0.0252 |
| bryophyte | north | oob_v2val_Landcover | 8 | 0.5971 | 0.5798 | 0.6148 | 0.5974 | 0.0150 |
| bryophyte | north | v2val_Climate | 10 | 0.6069 | 0.5555 | 0.6643 | 0.6086 | 0.0518 |
| bryophyte | north | v2val_Climate_Truncated | 10 | 0.6069 | 0.5555 | 0.6643 | 0.6086 | 0.0518 |
| bryophyte | north | v2val_Full | 10 | 0.6642 | 0.6314 | 0.7085 | 0.6676 | 0.0347 |
| bryophyte | north | v2val_Full_Joint | 10 | 0.6615 | 0.6293 | 0.7047 | 0.6648 | 0.0336 |
| bryophyte | north | v2val_Full_Joint_Truncated | 10 | 0.6621 | 0.6299 | 0.7052 | 0.6652 | 0.0334 |
| bryophyte | north | v2val_Full_Truncated | 10 | 0.6647 | 0.6320 | 0.7089 | 0.6679 | 0.0346 |
| bryophyte | north | v2val_Landcover | 10 | 0.6082 | 0.5829 | 0.6350 | 0.6089 | 0.0226 |
| bryophyte | south | insample_auc | 10 | 0.6741 | 0.6221 | 0.7221 | 0.6723 | 0.0498 |
| bryophyte | south | insample_calibration_slope | 10 | 0.8833 | 0.8604 | 0.9293 | 0.8836 | 0.0487 |
| bryophyte | south | insample_deviance_explained | 10 | -0.0076 | -0.1062 | 0.0587 | -0.0180 | 0.0817 |
| bryophyte | south | insample_n | 10 | 1454.5000 | 1440.8000 | 2310.0000 | 1623.0000 | 362.3789 |
| bryophyte | south | insample_prevalence | 10 | 0.3052 | 0.2352 | 0.3713 | 0.3043 | 0.0687 |
| bryophyte | south | insample_rmse | 10 | 0.4407 | 0.3994 | 0.4751 | 0.4384 | 0.0377 |
| bryophyte | south | insample_spearman | 10 | 0.2678 | 0.2042 | 0.3271 | 0.2668 | 0.0610 |
| bryophyte | south | oob_auc | 8 | 0.6737 | 0.6156 | 0.7162 | 0.6682 | 0.0497 |
| bryophyte | south | oob_calibration_slope | 8 | 0.8626 | 0.7944 | 0.9233 | 0.8595 | 0.0569 |
| bryophyte | south | oob_deviance_explained | 8 | 0.0177 | -0.0430 | 0.0521 | 0.0106 | 0.0409 |
| bryophyte | south | oob_n | 10 | 855.5000 | 0.0000 | 869.2000 | 687.0000 | 362.3789 |
| bryophyte | south | oob_prevalence | 8 | 0.3139 | 0.2297 | 0.3751 | 0.3071 | 0.0716 |
| bryophyte | south | oob_rmse | 8 | 0.4447 | 0.3999 | 0.4766 | 0.4408 | 0.0371 |
| bryophyte | south | oob_spearman | 8 | 0.2693 | 0.1933 | 0.3245 | 0.2610 | 0.0620 |
| bryophyte | south | oob_v2val_Climate | 8 | 0.6045 | 0.5487 | 0.6482 | 0.5986 | 0.0463 |
| bryophyte | south | oob_v2val_Climate_Truncated | 8 | 0.6045 | 0.5486 | 0.6482 | 0.5986 | 0.0463 |
| bryophyte | south | oob_v2val_Full | 8 | 0.6737 | 0.6156 | 0.7162 | 0.6682 | 0.0497 |
| bryophyte | south | oob_v2val_Full_Joint | 8 | 0.6754 | 0.6148 | 0.7178 | 0.6689 | 0.0510 |
| bryophyte | south | oob_v2val_Full_Joint_Truncated | 8 | 0.6754 | 0.6148 | 0.7178 | 0.6689 | 0.0510 |
| bryophyte | south | oob_v2val_Full_Truncated | 8 | 0.6737 | 0.6156 | 0.7162 | 0.6682 | 0.0497 |
| bryophyte | south | oob_v2val_Landcover | 8 | 0.6029 | 0.5970 | 0.6332 | 0.6102 | 0.0172 |
| bryophyte | south | v2val_Climate | 10 | 0.6069 | 0.5555 | 0.6643 | 0.6086 | 0.0518 |
| bryophyte | south | v2val_Climate_Truncated | 10 | 0.6069 | 0.5555 | 0.6643 | 0.6086 | 0.0518 |
| bryophyte | south | v2val_Full | 10 | 0.6741 | 0.6221 | 0.7221 | 0.6723 | 0.0498 |
| bryophyte | south | v2val_Full_Joint | 10 | 0.6743 | 0.6214 | 0.7227 | 0.6726 | 0.0505 |
| bryophyte | south | v2val_Full_Joint_Truncated | 10 | 0.6743 | 0.6215 | 0.7227 | 0.6726 | 0.0505 |
| bryophyte | south | v2val_Full_Truncated | 10 | 0.6741 | 0.6221 | 0.7221 | 0.6723 | 0.0498 |
| bryophyte | south | v2val_Landcover | 10 | 0.6137 | 0.5905 | 0.6386 | 0.6139 | 0.0223 |
| lichen | north | insample_auc | 10 | 0.8074 | 0.7781 | 0.8388 | 0.8083 | 0.0311 |
| lichen | north | insample_calibration_slope | 10 | 1.0001 | 0.9745 | 1.0269 | 0.9999 | 0.0221 |
| lichen | north | insample_deviance_explained | 10 | 0.1360 | 0.1091 | 0.1649 | 0.1405 | 0.0261 |
| lichen | north | insample_n | 10 | 3692.0000 | 3654.0000 | 5811.0000 | 4109.1000 | 897.3877 |
| lichen | north | insample_prevalence | 10 | 0.3839 | 0.3815 | 0.3891 | 0.3840 | 0.0037 |
| lichen | north | insample_rmse | 10 | 0.4112 | 0.3929 | 0.4298 | 0.4111 | 0.0183 |
| lichen | north | insample_spearman | 10 | 0.5176 | 0.4685 | 0.5707 | 0.5194 | 0.0520 |
| lichen | north | oob_auc | 8 | 0.7997 | 0.7622 | 0.8453 | 0.8016 | 0.0403 |
| lichen | north | oob_calibration_slope | 8 | 0.9794 | 0.9485 | 1.0076 | 0.9784 | 0.0272 |
| lichen | north | oob_deviance_explained | 8 | 0.1271 | 0.0891 | 0.1748 | 0.1334 | 0.0469 |
| lichen | north | oob_n | 10 | 2119.0000 | 0.0000 | 2157.0000 | 1701.9000 | 897.3877 |
| lichen | north | oob_prevalence | 8 | 0.3864 | 0.3761 | 0.3921 | 0.3853 | 0.0072 |
| lichen | north | oob_rmse | 8 | 0.4171 | 0.3889 | 0.4363 | 0.4142 | 0.0224 |
| lichen | north | oob_spearman | 8 | 0.5059 | 0.4420 | 0.5824 | 0.5084 | 0.0681 |
| lichen | north | oob_v2val_Climate | 8 | 0.7041 | 0.6878 | 0.7158 | 0.7028 | 0.0127 |
| lichen | north | oob_v2val_Climate_Truncated | 8 | 0.7041 | 0.6878 | 0.7158 | 0.7028 | 0.0127 |
| lichen | north | oob_v2val_Full | 8 | 0.7997 | 0.7622 | 0.8453 | 0.8016 | 0.0403 |
| lichen | north | oob_v2val_Full_Joint | 8 | 0.7969 | 0.7616 | 0.8417 | 0.7996 | 0.0394 |
| lichen | north | oob_v2val_Full_Joint_Truncated | 8 | 0.7969 | 0.7615 | 0.8418 | 0.7996 | 0.0396 |
| lichen | north | oob_v2val_Full_Truncated | 8 | 0.7997 | 0.7624 | 0.8453 | 0.8016 | 0.0404 |
| lichen | north | oob_v2val_Landcover | 8 | 0.7481 | 0.6957 | 0.8186 | 0.7528 | 0.0579 |
| lichen | north | v2val_Climate | 10 | 0.7093 | 0.6916 | 0.7289 | 0.7101 | 0.0183 |
| lichen | north | v2val_Climate_Truncated | 10 | 0.7093 | 0.6916 | 0.7290 | 0.7101 | 0.0183 |
| lichen | north | v2val_Full | 10 | 0.8074 | 0.7781 | 0.8388 | 0.8083 | 0.0311 |
| lichen | north | v2val_Full_Joint | 10 | 0.8057 | 0.7771 | 0.8370 | 0.8071 | 0.0308 |
| lichen | north | v2val_Full_Joint_Truncated | 10 | 0.8057 | 0.7770 | 0.8372 | 0.8071 | 0.0309 |
| lichen | north | v2val_Full_Truncated | 10 | 0.8074 | 0.7780 | 0.8390 | 0.8083 | 0.0312 |
| lichen | north | v2val_Landcover | 10 | 0.7424 | 0.7115 | 0.8121 | 0.7566 | 0.0468 |
| lichen | south | insample_auc | 10 | 0.8021 | 0.7789 | 0.8223 | 0.8009 | 0.0226 |
| lichen | south | insample_calibration_slope | 10 | 0.9035 | 0.8740 | 1.0439 | 0.9436 | 0.0783 |
| lichen | south | insample_deviance_explained | 10 | 0.1705 | 0.0924 | 0.2412 | 0.1684 | 0.0753 |
| lichen | south | insample_n | 10 | 1484.5000 | 1478.5000 | 2346.0000 | 1657.8000 | 362.9370 |
| lichen | south | insample_prevalence | 10 | 0.1511 | 0.0868 | 0.2167 | 0.1525 | 0.0659 |
| lichen | south | insample_rmse | 10 | 0.3163 | 0.2688 | 0.3582 | 0.3146 | 0.0440 |
| lichen | south | insample_spearman | 10 | 0.3667 | 0.2735 | 0.4597 | 0.3676 | 0.0948 |
| lichen | south | oob_auc | 8 | 0.7976 | 0.7632 | 0.8185 | 0.7926 | 0.0270 |
| lichen | south | oob_calibration_slope | 8 | 0.9438 | 0.7927 | 1.1880 | 0.9710 | 0.1829 |
| lichen | south | oob_deviance_explained | 8 | 0.1218 | -0.0135 | 0.2395 | 0.1153 | 0.1246 |
| lichen | south | oob_n | 10 | 861.5000 | 0.0000 | 867.5000 | 688.2000 | 362.9370 |
| lichen | south | oob_prevalence | 8 | 0.1578 | 0.0943 | 0.2207 | 0.1582 | 0.0637 |
| lichen | south | oob_rmse | 8 | 0.3261 | 0.2806 | 0.3630 | 0.3232 | 0.0402 |
| lichen | south | oob_spearman | 8 | 0.3688 | 0.2665 | 0.4581 | 0.3651 | 0.0946 |
| lichen | south | oob_v2val_Climate | 8 | 0.7041 | 0.6878 | 0.7158 | 0.7028 | 0.0127 |
| lichen | south | oob_v2val_Climate_Truncated | 8 | 0.7041 | 0.6878 | 0.7158 | 0.7028 | 0.0127 |
| lichen | south | oob_v2val_Full | 8 | 0.7976 | 0.7632 | 0.8185 | 0.7926 | 0.0270 |
| lichen | south | oob_v2val_Full_Joint | 8 | 0.7958 | 0.7656 | 0.8153 | 0.7914 | 0.0240 |
| lichen | south | oob_v2val_Full_Joint_Truncated | 8 | 0.7958 | 0.7656 | 0.8153 | 0.7914 | 0.0240 |
| lichen | south | oob_v2val_Full_Truncated | 8 | 0.7976 | 0.7632 | 0.8185 | 0.7926 | 0.0270 |
| lichen | south | oob_v2val_Landcover | 8 | 0.7535 | 0.7464 | 0.7630 | 0.7537 | 0.0086 |
| lichen | south | v2val_Climate | 10 | 0.7093 | 0.6916 | 0.7289 | 0.7101 | 0.0183 |
| lichen | south | v2val_Climate_Truncated | 10 | 0.7093 | 0.6916 | 0.7290 | 0.7101 | 0.0183 |
| lichen | south | v2val_Full | 10 | 0.8021 | 0.7789 | 0.8223 | 0.8009 | 0.0226 |
| lichen | south | v2val_Full_Joint | 10 | 0.8018 | 0.7799 | 0.8189 | 0.8001 | 0.0202 |
| lichen | south | v2val_Full_Joint_Truncated | 10 | 0.8018 | 0.7799 | 0.8189 | 0.8001 | 0.0202 |
| lichen | south | v2val_Full_Truncated | 10 | 0.8021 | 0.7789 | 0.8223 | 0.8009 | 0.0226 |
| lichen | south | v2val_Landcover | 10 | 0.7535 | 0.7435 | 0.7653 | 0.7532 | 0.0119 |
| mammal_summer | north | insample_auc | 10 | 0.7207 | 0.6085 | 0.8216 | 0.7173 | 0.1099 |
| mammal_summer | north | insample_calibration_slope | 10 | 0.9417 | 0.8161 | 1.0198 | 0.9320 | 0.0845 |
| mammal_summer | north | insample_deviance_explained | 10 | 0.1542 | 0.0268 | 0.2763 | 0.1529 | 0.1296 |
| mammal_summer | north | insample_n | 10 | 2587.5000 | 2542.1000 | 4053.0000 | 2865.2000 | 626.3850 |
| mammal_summer | north | insample_prevalence | 10 | 0.2736 | 0.2243 | 0.3206 | 0.2726 | 0.0496 |
| mammal_summer | north | insample_rmse | 10 | 0.3836 | 0.3234 | 0.4410 | 0.3831 | 0.0608 |
| mammal_summer | north | insample_spearman | 10 | 0.3160 | 0.1627 | 0.4610 | 0.3131 | 0.1542 |
| mammal_summer | north | oob_auc | 8 | 0.7007 | 0.5879 | 0.8116 | 0.7020 | 0.1114 |
| mammal_summer | north | oob_calibration_slope | 8 | 0.8971 | 0.7046 | 0.9590 | 0.8583 | 0.1139 |
| mammal_summer | north | oob_deviance_explained | 8 | 0.1194 | 0.0155 | 0.2466 | 0.1282 | 0.1142 |
| mammal_summer | north | oob_n | 10 | 1465.5000 | 0.0000 | 1510.9000 | 1187.8000 | 626.3850 |
| mammal_summer | north | oob_prevalence | 8 | 0.2774 | 0.2208 | 0.3261 | 0.2746 | 0.0539 |
| mammal_summer | north | oob_rmse | 8 | 0.3919 | 0.3312 | 0.4445 | 0.3895 | 0.0585 |
| mammal_summer | north | oob_spearman | 8 | 0.2911 | 0.1268 | 0.4415 | 0.2892 | 0.1555 |
| mammal_summer | south | insample_auc | 10 | 0.7054 | 0.6336 | 0.8030 | 0.7149 | 0.0833 |
| mammal_summer | south | insample_calibration_slope | 10 | 0.9832 | 0.8710 | 1.0087 | 0.9605 | 0.0585 |
| mammal_summer | south | insample_deviance_explained | 10 | 0.1016 | 0.0257 | 0.2383 | 0.1233 | 0.1035 |
| mammal_summer | south | insample_n | 10 | 676.5000 | 670.8000 | 1065.0000 | 753.7000 | 164.1402 |
| mammal_summer | south | insample_prevalence | 10 | 0.4451 | 0.1814 | 0.7098 | 0.4419 | 0.2704 |
| mammal_summer | south | insample_rmse | 10 | 0.3814 | 0.3405 | 0.4191 | 0.3811 | 0.0380 |
| mammal_summer | south | insample_spearman | 10 | 0.2798 | 0.1705 | 0.4148 | 0.2864 | 0.1148 |
| mammal_summer | south | oob_auc | 8 | 0.6568 | 0.5888 | 0.7557 | 0.6672 | 0.0845 |
| mammal_summer | south | oob_calibration_slope | 8 | 0.6589 | 0.4354 | 1.0000 | 0.7200 | 0.2938 |
| mammal_summer | south | oob_deviance_explained | 8 | 0.0059 | -0.0790 | 0.1356 | 0.0219 | 0.1214 |
| mammal_summer | south | oob_n | 10 | 388.5000 | 0.0000 | 394.2000 | 311.3000 | 164.1402 |
| mammal_summer | south | oob_prevalence | 8 | 0.4195 | 0.1726 | 0.6930 | 0.4251 | 0.2678 |
| mammal_summer | south | oob_rmse | 8 | 0.3986 | 0.3422 | 0.4425 | 0.3948 | 0.0479 |
| mammal_summer | south | oob_spearman | 8 | 0.2181 | 0.1135 | 0.3243 | 0.2204 | 0.1080 |
| mammal_winter | north | insample_auc | 10 | 0.7608 | 0.6687 | 0.8445 | 0.7578 | 0.0888 |
| mammal_winter | north | insample_calibration_slope | 10 | 0.9604 | 0.9077 | 1.0052 | 0.9518 | 0.0647 |
| mammal_winter | north | insample_deviance_explained | 10 | 0.1877 | 0.0712 | 0.3014 | 0.1868 | 0.1161 |
| mammal_winter | north | insample_n | 10 | 2624.5000 | 2596.8000 | 4127.0000 | 2921.0000 | 635.9504 |
| mammal_winter | north | insample_prevalence | 10 | 0.1752 | 0.1467 | 0.2040 | 0.1753 | 0.0287 |
| mammal_winter | north | insample_rmse | 10 | 0.3149 | 0.2994 | 0.3346 | 0.3161 | 0.0165 |
| mammal_winter | north | insample_spearman | 10 | 0.3463 | 0.2134 | 0.4714 | 0.3427 | 0.1314 |
| mammal_winter | north | oob_auc | 8 | 0.7383 | 0.6458 | 0.8353 | 0.7401 | 0.0953 |
| mammal_winter | north | oob_calibration_slope | 8 | 0.8540 | 0.6612 | 0.9533 | 0.8259 | 0.1149 |
| mammal_winter | north | oob_deviance_explained | 8 | 0.1614 | 0.0413 | 0.2853 | 0.1646 | 0.1234 |
| mammal_winter | north | oob_n | 10 | 1502.5000 | 0.0000 | 1530.2000 | 1206.0000 | 635.9504 |
| mammal_winter | north | oob_prevalence | 8 | 0.1756 | 0.1450 | 0.2025 | 0.1746 | 0.0269 |
| mammal_winter | north | oob_rmse | 8 | 0.3180 | 0.3015 | 0.3423 | 0.3198 | 0.0192 |
| mammal_winter | north | oob_spearman | 8 | 0.3198 | 0.1800 | 0.4528 | 0.3184 | 0.1382 |
| mammal_winter | south | insample_auc | 10 | 0.7642 | 0.6906 | 0.8292 | 0.7651 | 0.0684 |
| mammal_winter | south | insample_calibration_slope | 10 | 0.9542 | 0.8588 | 1.0389 | 0.9614 | 0.0769 |
| mammal_winter | south | insample_deviance_explained | 10 | 0.1574 | 0.0675 | 0.2501 | 0.1637 | 0.0946 |
| mammal_winter | south | insample_n | 10 | 694.0000 | 684.8000 | 1098.0000 | 773.7000 | 171.0842 |
| mammal_winter | south | insample_prevalence | 10 | 0.3450 | 0.0865 | 0.6052 | 0.3446 | 0.2704 |
| mammal_winter | south | insample_rmse | 10 | 0.3145 | 0.2215 | 0.4071 | 0.3127 | 0.0960 |
| mammal_winter | south | insample_spearman | 10 | 0.3224 | 0.2964 | 0.3373 | 0.3206 | 0.0167 |
| mammal_winter | south | oob_auc | 8 | 0.7095 | 0.6257 | 0.7915 | 0.7074 | 0.0854 |
| mammal_winter | south | oob_calibration_slope | 8 | 0.7307 | 0.4495 | 0.8353 | 0.6770 | 0.1665 |
| mammal_winter | south | oob_deviance_explained | 8 | 0.0389 | 0.0035 | 0.1901 | 0.0790 | 0.0856 |
| mammal_winter | south | oob_n | 10 | 404.0000 | 0.0000 | 413.2000 | 324.3000 | 171.0842 |
| mammal_winter | south | oob_prevalence | 8 | 0.3501 | 0.0777 | 0.6225 | 0.3492 | 0.2818 |
| mammal_winter | south | oob_rmse | 8 | 0.3337 | 0.2202 | 0.4271 | 0.3264 | 0.1027 |
| mammal_winter | south | oob_spearman | 8 | 0.2450 | 0.1833 | 0.2817 | 0.2399 | 0.0463 |
| mite | north | insample_auc | 10 | 0.7336 | 0.6697 | 0.7962 | 0.7334 | 0.0621 |
| mite | north | insample_calibration_slope | 10 | 1.0028 | 0.9276 | 1.0341 | 0.9867 | 0.0488 |
| mite | north | insample_deviance_explained | 10 | 0.0502 | -0.0427 | 0.1395 | 0.0479 | 0.0867 |
| mite | north | insample_n | 10 | 3630.0000 | 3598.5000 | 5711.0000 | 4041.0000 | 880.4163 |
| mite | north | insample_prevalence | 10 | 0.1545 | 0.0943 | 0.2113 | 0.1531 | 0.0602 |
| mite | north | insample_rmse | 10 | 0.3279 | 0.2873 | 0.3658 | 0.3272 | 0.0404 |
| mite | north | insample_spearman | 10 | 0.2958 | 0.1729 | 0.4186 | 0.2953 | 0.1234 |
| mite | north | oob_auc | 8 | 0.7189 | 0.6461 | 0.7894 | 0.7187 | 0.0708 |
| mite | north | oob_calibration_slope | 8 | 0.9472 | 0.7462 | 1.0295 | 0.9187 | 0.1294 |
| mite | north | oob_deviance_explained | 8 | 0.0324 | -0.0828 | 0.1165 | 0.0211 | 0.1006 |
| mite | north | oob_n | 10 | 2081.0000 | 0.0000 | 2112.5000 | 1670.0000 | 880.4163 |
| mite | north | oob_prevalence | 8 | 0.1509 | 0.0925 | 0.2048 | 0.1495 | 0.0588 |
| mite | north | oob_rmse | 8 | 0.3263 | 0.2853 | 0.3680 | 0.3268 | 0.0416 |
| mite | north | oob_spearman | 8 | 0.2764 | 0.1475 | 0.4035 | 0.2761 | 0.1298 |
| mite | north | oob_v2val_Climate | 8 | 0.6835 | 0.6308 | 0.7383 | 0.6832 | 0.0539 |
| mite | north | oob_v2val_Climate_Truncated | 8 | 0.6834 | 0.6308 | 0.7383 | 0.6832 | 0.0539 |
| mite | north | oob_v2val_Full | 8 | 0.7189 | 0.6461 | 0.7894 | 0.7187 | 0.0708 |
| mite | north | oob_v2val_Full_Joint | 8 | 0.7191 | 0.6447 | 0.7888 | 0.7183 | 0.0712 |
| mite | north | oob_v2val_Full_Joint_Truncated | 8 | 0.7192 | 0.6448 | 0.7887 | 0.7183 | 0.0712 |
| mite | north | oob_v2val_Full_Truncated | 8 | 0.7190 | 0.6462 | 0.7893 | 0.7188 | 0.0708 |
| mite | north | oob_v2val_Landcover | 8 | 0.6850 | 0.6172 | 0.7620 | 0.6890 | 0.0750 |
| mite | north | v2val_Climate | 10 | 0.6950 | 0.6449 | 0.7401 | 0.6928 | 0.0480 |
| mite | north | v2val_Climate_Truncated | 10 | 0.6950 | 0.6449 | 0.7401 | 0.6928 | 0.0480 |
| mite | north | v2val_Full | 10 | 0.7336 | 0.6697 | 0.7962 | 0.7334 | 0.0621 |
| mite | north | v2val_Full_Joint | 10 | 0.7336 | 0.6692 | 0.7962 | 0.7334 | 0.0622 |
| mite | north | v2val_Full_Joint_Truncated | 10 | 0.7336 | 0.6692 | 0.7962 | 0.7334 | 0.0621 |
| mite | north | v2val_Full_Truncated | 10 | 0.7336 | 0.6697 | 0.7961 | 0.7334 | 0.0620 |
| mite | north | v2val_Landcover | 10 | 0.7057 | 0.6335 | 0.7708 | 0.7020 | 0.0683 |
| mite | south | insample_auc | 10 | 0.7997 | 0.7044 | 0.8840 | 0.7968 | 0.0893 |
| mite | south | insample_calibration_slope | 10 | 0.7882 | 0.6097 | 0.9768 | 0.7906 | 0.1787 |
| mite | south | insample_deviance_explained | 10 | 0.0405 | -0.0053 | 0.1740 | 0.0764 | 0.0831 |
| mite | south | insample_n | 10 | 1493.0000 | 1480.9000 | 2363.0000 | 1665.8000 | 367.6444 |
| mite | south | insample_prevalence | 10 | 0.0721 | 0.0556 | 0.0841 | 0.0703 | 0.0144 |
| mite | south | insample_rmse | 10 | 0.2482 | 0.2139 | 0.2709 | 0.2446 | 0.0273 |
| mite | south | insample_spearman | 10 | 0.2519 | 0.1954 | 0.3151 | 0.2550 | 0.0557 |
| mite | south | oob_auc | 8 | 0.7769 | 0.6582 | 0.8839 | 0.7745 | 0.1136 |
| mite | south | oob_calibration_slope | 8 | 0.6139 | 0.5353 | 0.8012 | 0.6444 | 0.1288 |
| mite | south | oob_deviance_explained | 8 | 0.0535 | 0.0095 | 0.2026 | 0.0819 | 0.0851 |
| mite | south | oob_n | 10 | 870.0000 | 0.0000 | 882.1000 | 697.2000 | 367.6444 |
| mite | south | oob_prevalence | 8 | 0.0719 | 0.0489 | 0.0868 | 0.0689 | 0.0174 |
| mite | south | oob_rmse | 8 | 0.2447 | 0.2147 | 0.2788 | 0.2456 | 0.0307 |
| mite | south | oob_spearman | 8 | 0.2233 | 0.1492 | 0.3189 | 0.2298 | 0.0764 |
| mite | south | oob_v2val_Climate | 8 | 0.6835 | 0.6308 | 0.7383 | 0.6832 | 0.0539 |
| mite | south | oob_v2val_Climate_Truncated | 8 | 0.6834 | 0.6308 | 0.7383 | 0.6832 | 0.0539 |
| mite | south | oob_v2val_Full | 8 | 0.7769 | 0.6582 | 0.8839 | 0.7745 | 0.1136 |
| mite | south | oob_v2val_Full_Joint | 8 | 0.7766 | 0.6587 | 0.8846 | 0.7751 | 0.1137 |
| mite | south | oob_v2val_Full_Joint_Truncated | 8 | 0.7766 | 0.6587 | 0.8846 | 0.7751 | 0.1137 |
| mite | south | oob_v2val_Full_Truncated | 8 | 0.7769 | 0.6582 | 0.8839 | 0.7745 | 0.1136 |
| mite | south | oob_v2val_Landcover | 8 | 0.6792 | 0.6125 | 0.7124 | 0.6651 | 0.0460 |
| mite | south | v2val_Climate | 10 | 0.6950 | 0.6449 | 0.7401 | 0.6928 | 0.0480 |
| mite | south | v2val_Climate_Truncated | 10 | 0.6950 | 0.6449 | 0.7401 | 0.6928 | 0.0480 |
| mite | south | v2val_Full | 10 | 0.7997 | 0.7044 | 0.8840 | 0.7968 | 0.0893 |
| mite | south | v2val_Full_Joint | 10 | 0.8014 | 0.7048 | 0.8843 | 0.7975 | 0.0894 |
| mite | south | v2val_Full_Joint_Truncated | 10 | 0.8014 | 0.7048 | 0.8843 | 0.7975 | 0.0894 |
| mite | south | v2val_Full_Truncated | 10 | 0.7997 | 0.7044 | 0.8840 | 0.7968 | 0.0893 |
| mite | south | v2val_Landcover | 10 | 0.7027 | 0.6602 | 0.7282 | 0.6970 | 0.0287 |
| vascular_plant | north | insample_auc | 10 | 0.8331 | 0.8298 | 0.8373 | 0.8332 | 0.0032 |
| vascular_plant | north | insample_calibration_slope | 10 | 0.9949 | 0.9743 | 1.0061 | 0.9918 | 0.0148 |
| vascular_plant | north | insample_deviance_explained | 10 | 0.1616 | 0.1396 | 0.1816 | 0.1602 | 0.0191 |
| vascular_plant | north | insample_n | 10 | 4347.5000 | 4314.6000 | 6874.0000 | 4846.9000 | 1068.6395 |
| vascular_plant | north | insample_prevalence | 10 | 0.3951 | 0.3770 | 0.4211 | 0.3974 | 0.0209 |
| vascular_plant | north | insample_rmse | 10 | 0.4022 | 0.3958 | 0.4067 | 0.4017 | 0.0048 |
| vascular_plant | north | insample_spearman | 10 | 0.5651 | 0.5611 | 0.5668 | 0.5644 | 0.0038 |
| vascular_plant | north | oob_auc | 8 | 0.8283 | 0.8227 | 0.8329 | 0.8284 | 0.0052 |
| vascular_plant | north | oob_calibration_slope | 8 | 0.9755 | 0.9539 | 1.0021 | 0.9776 | 0.0210 |
| vascular_plant | north | oob_deviance_explained | 8 | 0.1803 | 0.1354 | 0.2064 | 0.1750 | 0.0321 |
| vascular_plant | north | oob_n | 10 | 2526.5000 | 0.0000 | 2559.4000 | 2027.1000 | 1068.6395 |
| vascular_plant | north | oob_prevalence | 8 | 0.3990 | 0.3725 | 0.4275 | 0.3991 | 0.0248 |
| vascular_plant | north | oob_rmse | 8 | 0.4052 | 0.3988 | 0.4110 | 0.4048 | 0.0061 |
| vascular_plant | north | oob_spearman | 8 | 0.5545 | 0.5499 | 0.5651 | 0.5564 | 0.0065 |
| vascular_plant | north | oob_v2val_Climate | 8 | 0.6916 | 0.6808 | 0.6996 | 0.6902 | 0.0106 |
| vascular_plant | north | oob_v2val_Climate_Truncated | 8 | 0.6916 | 0.6808 | 0.6996 | 0.6902 | 0.0106 |
| vascular_plant | north | oob_v2val_Full | 8 | 0.8283 | 0.8227 | 0.8329 | 0.8284 | 0.0052 |
| vascular_plant | north | oob_v2val_Full_Joint | 8 | 0.8258 | 0.8182 | 0.8325 | 0.8258 | 0.0065 |
| vascular_plant | north | oob_v2val_Full_Joint_Truncated | 8 | 0.8258 | 0.8183 | 0.8323 | 0.8258 | 0.0064 |
| vascular_plant | north | oob_v2val_Full_Truncated | 8 | 0.8285 | 0.8228 | 0.8328 | 0.8284 | 0.0051 |
| vascular_plant | north | oob_v2val_Landcover | 8 | 0.8009 | 0.7954 | 0.8101 | 0.8024 | 0.0067 |
| vascular_plant | north | v2val_Climate | 10 | 0.6886 | 0.6855 | 0.6950 | 0.6902 | 0.0048 |
| vascular_plant | north | v2val_Climate_Truncated | 10 | 0.6886 | 0.6855 | 0.6949 | 0.6902 | 0.0048 |
| vascular_plant | north | v2val_Full | 10 | 0.8331 | 0.8298 | 0.8373 | 0.8332 | 0.0032 |
| vascular_plant | north | v2val_Full_Joint | 10 | 0.8318 | 0.8275 | 0.8367 | 0.8320 | 0.0039 |
| vascular_plant | north | v2val_Full_Joint_Truncated | 10 | 0.8319 | 0.8277 | 0.8366 | 0.8321 | 0.0038 |
| vascular_plant | north | v2val_Full_Truncated | 10 | 0.8330 | 0.8299 | 0.8373 | 0.8332 | 0.0031 |
| vascular_plant | north | v2val_Landcover | 10 | 0.8087 | 0.8049 | 0.8130 | 0.8092 | 0.0040 |
| vascular_plant | south | insample_auc | 10 | 0.8460 | 0.8042 | 0.8967 | 0.8490 | 0.0462 |
| vascular_plant | south | insample_calibration_slope | 10 | 0.9608 | 0.9208 | 0.9855 | 0.9580 | 0.0297 |
| vascular_plant | south | insample_deviance_explained | 10 | 0.2841 | 0.1600 | 0.3822 | 0.2752 | 0.1074 |
| vascular_plant | south | insample_n | 10 | 1688.5000 | 1654.9000 | 2648.0000 | 1869.6000 | 410.6067 |
| vascular_plant | south | insample_prevalence | 10 | 0.2438 | 0.2212 | 0.2654 | 0.2437 | 0.0227 |
| vascular_plant | south | insample_rmse | 10 | 0.3477 | 0.3070 | 0.3827 | 0.3458 | 0.0374 |
| vascular_plant | south | insample_spearman | 10 | 0.5180 | 0.4628 | 0.5647 | 0.5163 | 0.0529 |
| vascular_plant | south | oob_auc | 8 | 0.8412 | 0.8038 | 0.8909 | 0.8455 | 0.0409 |
| vascular_plant | south | oob_calibration_slope | 8 | 0.9408 | 0.9073 | 0.9701 | 0.9401 | 0.0277 |
| vascular_plant | south | oob_deviance_explained | 8 | 0.2459 | 0.1728 | 0.3387 | 0.2532 | 0.0850 |
| vascular_plant | south | oob_n | 10 | 959.5000 | 0.0000 | 993.1000 | 778.4000 | 410.6067 |
| vascular_plant | south | oob_prevalence | 8 | 0.2418 | 0.2131 | 0.2706 | 0.2421 | 0.0259 |
| vascular_plant | south | oob_rmse | 8 | 0.3513 | 0.3168 | 0.3827 | 0.3502 | 0.0336 |
| vascular_plant | south | oob_spearman | 8 | 0.5033 | 0.4643 | 0.5589 | 0.5099 | 0.0446 |
| vascular_plant | south | oob_v2val_Climate | 8 | 0.6916 | 0.6808 | 0.6996 | 0.6902 | 0.0106 |
| vascular_plant | south | oob_v2val_Climate_Truncated | 8 | 0.6916 | 0.6808 | 0.6996 | 0.6902 | 0.0106 |
| vascular_plant | south | oob_v2val_Full | 8 | 0.8412 | 0.8038 | 0.8909 | 0.8455 | 0.0409 |
| vascular_plant | south | oob_v2val_Full_Joint | 8 | 0.8369 | 0.8023 | 0.8809 | 0.8406 | 0.0373 |
| vascular_plant | south | oob_v2val_Full_Joint_Truncated | 8 | 0.8369 | 0.8023 | 0.8809 | 0.8406 | 0.0373 |
| vascular_plant | south | oob_v2val_Full_Truncated | 8 | 0.8412 | 0.8038 | 0.8908 | 0.8455 | 0.0409 |
| vascular_plant | south | oob_v2val_Landcover | 8 | 0.7762 | 0.7677 | 0.7961 | 0.7793 | 0.0125 |
| vascular_plant | south | v2val_Climate | 10 | 0.6886 | 0.6855 | 0.6950 | 0.6902 | 0.0048 |
| vascular_plant | south | v2val_Climate_Truncated | 10 | 0.6886 | 0.6855 | 0.6949 | 0.6902 | 0.0048 |
| vascular_plant | south | v2val_Full | 10 | 0.8460 | 0.8042 | 0.8967 | 0.8490 | 0.0462 |
| vascular_plant | south | v2val_Full_Joint | 10 | 0.8411 | 0.8013 | 0.8920 | 0.8446 | 0.0448 |
| vascular_plant | south | v2val_Full_Joint_Truncated | 10 | 0.8411 | 0.8013 | 0.8920 | 0.8446 | 0.0448 |
| vascular_plant | south | v2val_Full_Truncated | 10 | 0.8460 | 0.8042 | 0.8967 | 0.8490 | 0.0462 |
| vascular_plant | south | v2val_Landcover | 10 | 0.7783 | 0.7609 | 0.8028 | 0.7802 | 0.0202 |

