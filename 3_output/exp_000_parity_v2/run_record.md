# Run record: exp_000_parity_v2

Written by `run_record()`. The result stores this describes are gitignored; this file is what remains.

## Provenance

_Volatile. Excluded from cross-run comparison._

- **git_commit**: 4d2583e
- **pipeline_dir**: D:/local_projects/active/sdmMethodsDev/2_pipeline/exp_000_parity_v2
- **r_version**: 4.5.0
- **written_at**: 2026-09-29 10:40:24

## Configuration

- **boot_seed**: 20260909
- **data_dir**: test_dataset
- **engines**: bayesglm, glm
- **focal_species**: bird=AMRO, bird=YEWA, bryophyte=Bryum.All, bryophyte=Ceratodon.purpureus, lichen=Cladonia.chlorophaea, lichen=Physcia.adscendens, mammal=Coyote_Summer, mammal=Moose_Summer, mite=Ceratozetes.gracilis, mite=Trhypochthonius.tectorum, vascular_plant=Galium.boreale, vascular_plant=Vicia.americana
- **n_bootstraps**: 5
- **selection**: aic_average, aic_best_onehot, ivw_grid, staged_bic
- **species_n**: 12
- **stage_models**: spec defaults (v2 candidate sets)
- **taxa**: bird, bryophyte, lichen, mammal, mite, vascular_plant
- **v2_bootstraps**: 5

## Coverage

| taxon | region | species | draws | coefficient_rows | metric_rows | grid_rows |
| --- | --- | --- | --- | --- | --- | --- |
| bird | north | 2 | 5 | 349 | 70 | 0 |
| bird | south | 2 | 5 | 235 | 70 | 0 |
| bryophyte | north | 2 | 5 | 460 | 70 | 0 |
| bryophyte | south | 2 | 5 | 190 | 70 | 0 |
| lichen | north | 2 | 5 | 460 | 70 | 0 |
| lichen | south | 2 | 5 | 190 | 70 | 0 |
| mammal | north | 2 | 5 | 185 | 70 | 0 |
| mammal | south | 0 | 0 | 0 | 0 | 0 |
| mite | north | 2 | 5 | 450 | 70 | 430 |
| mite | south | 2 | 5 | 180 | 70 | 80 |
| vascular_plant | north | 2 | 5 | 450 | 70 | 430 |
| vascular_plant | south | 2 | 5 | 180 | 70 | 0 |

## Metrics

| taxon | region | metric | n | median | p10 | p90 |
| --- | --- | --- | --- | --- | --- | --- |
| bird | north | auc | 10 | 0.7144 | 0.7110 | 0.7177 |
| bird | north | calibration_slope | 10 | 0.9607 | 0.9200 | 0.9853 |
| bird | north | deviance_explained | 10 | 0.1411 | 0.1331 | 0.1497 |
| bird | north | n | 10 | 171624.0000 | 171624.0000 | 171624.0000 |
| bird | north | prevalence | 10 | 0.1870 | 0.1302 | 0.2439 |
| bird | north | rmse | 10 | 0.6187 | 0.5781 | 0.6591 |
| bird | north | spearman | 10 | 0.2887 | 0.2565 | 0.3207 |
| bird | south | auc | 10 | 0.6939 | 0.6887 | 0.7000 |
| bird | south | calibration_slope | 10 | 0.8882 | 0.8257 | 0.9454 |
| bird | south | deviance_explained | 10 | 0.1320 | 0.0956 | 0.1751 |
| bird | south | n | 10 | 90807.0000 | 90807.0000 | 90807.0000 |
| bird | south | prevalence | 10 | 0.2172 | 0.1747 | 0.2596 |
| bird | south | rmse | 10 | 0.6989 | 0.6603 | 0.7373 |
| bird | south | spearman | 10 | 0.2804 | 0.2712 | 0.2902 |
| bryophyte | north | auc | 10 | 0.6634 | 0.6360 | 0.6895 |
| bryophyte | north | calibration_slope | 10 | 0.9405 | 0.8642 | 0.9943 |
| bryophyte | north | deviance_explained | 10 | 0.0624 | 0.0414 | 0.0809 |
| bryophyte | north | n | 10 | 4852.0000 | 4852.0000 | 4852.0000 |
| bryophyte | north | prevalence | 10 | 0.4205 | 0.4000 | 0.4411 |
| bryophyte | north | rmse | 10 | 0.4724 | 0.4687 | 0.4767 |
| bryophyte | north | spearman | 10 | 0.2794 | 0.2308 | 0.3259 |
| bryophyte | south | auc | 10 | 0.7079 | 0.6648 | 0.7438 |
| bryophyte | south | calibration_slope | 10 | 0.9144 | 0.8523 | 0.9797 |
| bryophyte | south | deviance_explained | 10 | 0.0978 | 0.0585 | 0.1286 |
| bryophyte | south | n | 10 | 2310.0000 | 2310.0000 | 2310.0000 |
| bryophyte | south | prevalence | 10 | 0.3052 | 0.2398 | 0.3706 |
| bryophyte | south | rmse | 10 | 0.4298 | 0.3973 | 0.4649 |
| bryophyte | south | spearman | 10 | 0.3245 | 0.2757 | 0.3606 |
| lichen | north | auc | 10 | 0.8068 | 0.7660 | 0.8466 |
| lichen | north | calibration_slope | 10 | 1.0023 | 0.9696 | 1.0170 |
| lichen | north | deviance_explained | 10 | 0.2387 | 0.1839 | 0.2971 |
| lichen | north | n | 10 | 5811.0000 | 5811.0000 | 5811.0000 |
| lichen | north | prevalence | 10 | 0.3844 | 0.3841 | 0.3848 |
| lichen | north | rmse | 10 | 0.4110 | 0.3883 | 0.4331 |
| lichen | north | spearman | 10 | 0.5170 | 0.4484 | 0.5840 |
| lichen | south | auc | 10 | 0.8419 | 0.8250 | 0.8464 |
| lichen | south | calibration_slope | 10 | 0.9598 | 0.8428 | 0.9864 |
| lichen | south | deviance_explained | 10 | 0.2501 | 0.2090 | 0.2792 |
| lichen | south | n | 10 | 2346.0000 | 2346.0000 | 2346.0000 |
| lichen | south | prevalence | 10 | 0.1543 | 0.0929 | 0.2157 |
| lichen | south | rmse | 10 | 0.3111 | 0.2705 | 0.3500 |
| lichen | south | spearman | 10 | 0.4157 | 0.3268 | 0.4936 |
| mammal | north | auc | 10 | 0.7273 | 0.6310 | 0.8209 |
| mammal | north | calibration_slope | 10 | 0.9369 | 0.8280 | 0.9882 |
| mammal | north | deviance_explained | 10 | 0.1589 | 0.0425 | 0.2720 |
| mammal | north | n | 10 | 4148.0000 | 4148.0000 | 4148.0000 |
| mammal | north | prevalence | 10 | 0.2724 | 0.2252 | 0.3197 |
| mammal | north | rmse | 10 | 0.3830 | 0.3281 | 0.4390 |
| mammal | north | spearman | 10 | 0.3307 | 0.1996 | 0.4584 |
| mite | north | auc | 10 | 0.7515 | 0.6910 | 0.8051 |
| mite | north | calibration_slope | 10 | 0.9801 | 0.8987 | 1.0284 |
| mite | north | deviance_explained | 10 | 0.1356 | 0.0568 | 0.2032 |
| mite | north | n | 10 | 5711.0000 | 5711.0000 | 5711.0000 |
| mite | north | prevalence | 10 | 0.1520 | 0.0956 | 0.2084 |
| mite | north | rmse | 10 | 0.3224 | 0.2877 | 0.3589 |
| mite | north | spearman | 10 | 0.3151 | 0.1946 | 0.4292 |
| mite | south | auc | 10 | 0.8096 | 0.7283 | 0.8797 |
| mite | south | calibration_slope | 10 | 0.9539 | 0.8517 | 1.0111 |
| mite | south | deviance_explained | 10 | 0.1936 | 0.0843 | 0.2995 |
| mite | south | n | 10 | 2363.0000 | 2363.0000 | 2363.0000 |
| mite | south | prevalence | 10 | 0.0698 | 0.0563 | 0.0834 |
| mite | south | rmse | 10 | 0.2343 | 0.1995 | 0.2672 |
| mite | south | spearman | 10 | 0.2668 | 0.2186 | 0.3031 |
| vascular_plant | north | auc | 10 | 0.8342 | 0.8304 | 0.8357 |
| vascular_plant | north | calibration_slope | 10 | 0.9952 | 0.9711 | 1.0049 |
| vascular_plant | north | deviance_explained | 10 | 0.2704 | 0.2647 | 0.2743 |
| vascular_plant | north | n | 10 | 6874.0000 | 6874.0000 | 6874.0000 |
| vascular_plant | north | prevalence | 10 | 0.3979 | 0.3777 | 0.4182 |
| vascular_plant | north | rmse | 10 | 0.3999 | 0.3969 | 0.4049 |
| vascular_plant | north | spearman | 10 | 0.5640 | 0.5613 | 0.5705 |
| vascular_plant | south | auc | 10 | 0.8532 | 0.8149 | 0.8887 |
| vascular_plant | south | calibration_slope | 10 | 1.0014 | 0.9621 | 1.0395 |
| vascular_plant | south | deviance_explained | 10 | 0.3041 | 0.2275 | 0.3789 |
| vascular_plant | south | n | 10 | 2648.0000 | 2648.0000 | 2648.0000 |
| vascular_plant | south | prevalence | 10 | 0.2432 | 0.2221 | 0.2644 |
| vascular_plant | south | rmse | 10 | 0.3485 | 0.3189 | 0.3763 |
| vascular_plant | south | spearman | 10 | 0.5225 | 0.4810 | 0.5596 |

