# Run record: exp_000_parity_v2

Written by `run_record()`. The result stores this describes are gitignored; this file is what remains.

## Provenance

_Volatile. Excluded from cross-run comparison._

- **git_commit**: e5a381a
- **pipeline_dir**: D:/local_projects/active/sdmMethodsDev/2_pipeline/exp_000_parity_v2
- **r_version**: 4.5.0
- **written_at**: 2026-09-13 13:06:52

## Configuration

- **data_dir**: test_dataset
- **engines**: bayesglm, glm
- **focal_species**: bird=AMRO, bryophyte=Ceratodon.purpureus, lichen=Physcia.adscendens, mammal=Moose_Summer, mite=Ceratozetes.gracilis, vascular_plant=Galium.boreale
- **jobs_not_ok**: 2
- **jobs_ok**: 22
- **jobs_total**: 24
- **n_bootstraps**: 2
- **selection**: aic_average, aic_best_onehot, ivw_grid, staged_bic
- **species_n**: 6
- **stage_models**: spec defaults (v2 candidate sets)
- **taxa**: bird, bryophyte, lichen, mammal, mite, vascular_plant
- **v2_bootstraps**: 5

## Coverage

| taxon | region | species | draws | coefficient_rows | metric_rows | grid_rows |
| --- | --- | --- | --- | --- | --- | --- |
| bird | north | 1 | 2 | 71 | 14 | 0 |
| bird | south | 1 | 2 | 46 | 14 | 0 |
| bryophyte | north | 1 | 2 | 92 | 14 | 0 |
| bryophyte | south | 1 | 2 | 38 | 14 | 0 |
| lichen | north | 1 | 2 | 92 | 14 | 0 |
| lichen | south | 1 | 2 | 38 | 14 | 0 |
| mammal | north | 1 | 2 | 48 | 14 | 0 |
| mammal | south | 0 | 0 | 0 | 0 | 0 |
| mite | north | 1 | 2 | 90 | 14 | 86 |
| mite | south | 1 | 2 | 36 | 14 | 0 |
| vascular_plant | north | 1 | 2 | 90 | 14 | 86 |
| vascular_plant | south | 1 | 2 | 36 | 14 | 0 |

## Metrics

| taxon | region | metric | n | median | p10 | p90 |
| --- | --- | --- | --- | --- | --- | --- |
| bird | north | auc | 2 | 0.7113 | 0.7111 | 0.7115 |
| bird | north | calibration_slope | 2 | 0.9831 | 0.9816 | 0.9846 |
| bird | north | deviance_explained | 2 | 0.1335 | 0.1331 | 0.1338 |
| bird | north | n | 2 | 171624.0000 | 171624.0000 | 171624.0000 |
| bird | north | prevalence | 2 | 0.2439 | 0.2439 | 0.2439 |
| bird | north | rmse | 2 | 0.6589 | 0.6589 | 0.6590 |
| bird | north | spearman | 2 | 0.3208 | 0.3205 | 0.3211 |
| bird | south | auc | 2 | 0.6887 | 0.6883 | 0.6892 |
| bird | south | calibration_slope | 2 | 0.9394 | 0.9361 | 0.9427 |
| bird | south | deviance_explained | 2 | 0.0956 | 0.0955 | 0.0956 |
| bird | south | n | 2 | 90807.0000 | 90807.0000 | 90807.0000 |
| bird | south | prevalence | 2 | 0.2596 | 0.2596 | 0.2596 |
| bird | south | rmse | 2 | 0.7372 | 0.7370 | 0.7373 |
| bird | south | spearman | 2 | 0.2896 | 0.2891 | 0.2901 |
| bryophyte | north | auc | 2 | 0.6889 | 0.6878 | 0.6901 |
| bryophyte | north | calibration_slope | 2 | 1.0108 | 1.0089 | 1.0127 |
| bryophyte | north | deviance_explained | 2 | 0.0817 | 0.0812 | 0.0821 |
| bryophyte | north | n | 2 | 4852.0000 | 4852.0000 | 4852.0000 |
| bryophyte | north | prevalence | 2 | 0.4411 | 0.4411 | 0.4411 |
| bryophyte | north | rmse | 2 | 0.4688 | 0.4686 | 0.4690 |
| bryophyte | north | spearman | 2 | 0.3250 | 0.3230 | 0.3270 |
| bryophyte | south | auc | 2 | 0.7427 | 0.7410 | 0.7444 |
| bryophyte | south | calibration_slope | 2 | 0.9152 | 0.8648 | 0.9655 |
| bryophyte | south | deviance_explained | 2 | 0.1279 | 0.1237 | 0.1321 |
| bryophyte | south | n | 2 | 2310.0000 | 2310.0000 | 2310.0000 |
| bryophyte | south | prevalence | 2 | 0.2398 | 0.2398 | 0.2398 |
| bryophyte | south | rmse | 2 | 0.3976 | 0.3964 | 0.3987 |
| bryophyte | south | spearman | 2 | 0.3590 | 0.3565 | 0.3615 |
| lichen | north | auc | 2 | 0.8500 | 0.8487 | 0.8513 |
| lichen | north | calibration_slope | 2 | 0.9972 | 0.9913 | 1.0031 |
| lichen | north | deviance_explained | 2 | 0.3036 | 0.3003 | 0.3069 |
| lichen | north | n | 2 | 5811.0000 | 5811.0000 | 5811.0000 |
| lichen | north | prevalence | 2 | 0.3841 | 0.3841 | 0.3841 |
| lichen | north | rmse | 2 | 0.3866 | 0.3851 | 0.3881 |
| lichen | north | spearman | 2 | 0.5896 | 0.5874 | 0.5919 |
| lichen | south | auc | 2 | 0.8447 | 0.8419 | 0.8475 |
| lichen | south | calibration_slope | 2 | 0.9460 | 0.9143 | 0.9777 |
| lichen | south | deviance_explained | 2 | 0.2734 | 0.2661 | 0.2808 |
| lichen | south | n | 2 | 2346.0000 | 2346.0000 | 2346.0000 |
| lichen | south | prevalence | 2 | 0.2157 | 0.2157 | 0.2157 |
| lichen | south | rmse | 2 | 0.3509 | 0.3488 | 0.3530 |
| lichen | south | spearman | 2 | 0.4911 | 0.4871 | 0.4951 |
| mammal | north | auc | 2 | 0.6345 | 0.6315 | 0.6374 |
| mammal | north | calibration_slope | 2 | 0.9090 | 0.8978 | 0.9202 |
| mammal | north | deviance_explained | 2 | 0.0480 | 0.0466 | 0.0494 |
| mammal | north | n | 2 | 4148.0000 | 4148.0000 | 4148.0000 |
| mammal | north | prevalence | 2 | 0.3197 | 0.3197 | 0.3197 |
| mammal | north | rmse | 2 | 0.4375 | 0.4372 | 0.4379 |
| mammal | north | spearman | 2 | 0.2045 | 0.2007 | 0.2083 |
| mite | north | auc | 2 | 0.8048 | 0.8026 | 0.8070 |
| mite | north | calibration_slope | 2 | 1.0152 | 1.0057 | 1.0247 |
| mite | north | deviance_explained | 2 | 0.2044 | 0.2008 | 0.2080 |
| mite | north | n | 2 | 5711.0000 | 5711.0000 | 5711.0000 |
| mite | north | prevalence | 2 | 0.2084 | 0.2084 | 0.2084 |
| mite | north | rmse | 2 | 0.3583 | 0.3570 | 0.3596 |
| mite | north | spearman | 2 | 0.4288 | 0.4257 | 0.4319 |
| mite | south | auc | 2 | 0.8851 | 0.8824 | 0.8878 |
| mite | south | calibration_slope | 2 | 0.9979 | 0.9878 | 1.0080 |
| mite | south | deviance_explained | 2 | 0.3159 | 0.3155 | 0.3164 |
| mite | south | n | 2 | 2363.0000 | 2363.0000 | 2363.0000 |
| mite | south | prevalence | 2 | 0.0563 | 0.0563 | 0.0563 |
| mite | south | rmse | 2 | 0.1992 | 0.1988 | 0.1995 |
| mite | south | spearman | 2 | 0.3075 | 0.3053 | 0.3096 |
| vascular_plant | north | auc | 2 | 0.8340 | 0.8327 | 0.8352 |
| vascular_plant | north | calibration_slope | 2 | 0.9977 | 0.9950 | 1.0004 |
| vascular_plant | north | deviance_explained | 2 | 0.2715 | 0.2693 | 0.2736 |
| vascular_plant | north | n | 2 | 6874.0000 | 6874.0000 | 6874.0000 |
| vascular_plant | north | prevalence | 2 | 0.4182 | 0.4182 | 0.4182 |
| vascular_plant | north | rmse | 2 | 0.4026 | 0.4019 | 0.4033 |
| vascular_plant | north | spearman | 2 | 0.5707 | 0.5686 | 0.5728 |
| vascular_plant | south | auc | 2 | 0.8907 | 0.8906 | 0.8909 |
| vascular_plant | south | calibration_slope | 2 | 0.9955 | 0.9841 | 1.0070 |
| vascular_plant | south | deviance_explained | 2 | 0.3829 | 0.3816 | 0.3842 |
| vascular_plant | south | n | 2 | 2648.0000 | 2648.0000 | 2648.0000 |
| vascular_plant | south | prevalence | 2 | 0.2221 | 0.2221 | 0.2221 |
| vascular_plant | south | rmse | 2 | 0.3188 | 0.3182 | 0.3195 |
| vascular_plant | south | spearman | 2 | 0.5626 | 0.5624 | 0.5628 |

