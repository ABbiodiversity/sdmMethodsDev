# _setup

Builds the frozen test dataset and the v2 reference in `0_data/`, then
publishes them to ABMI-DATA2. Run by hand, by maintainers, once per
source snapshot. No experiment runs these scripts: experiments read the
published copies (see `harness/data_source.R`).

The scripts read their external inputs from a mirror on
`//ABMI-DATA2/science/sdmMethodsDev/0_data/setup_inputs/`, through
`utils/input_paths.R`, so anyone with access to that share can
rebuild.

## Run

From the repository root:

```r
source("1_code/_setup/run.R")
```

`run.R` runs the steps in dependency order, with on/off switches in
section 1.2, and logs timings to `2_pipeline/_setup/run_log.csv`. `00`,
`03` and `08` are off by default. Run order: `01`, `04`, `07`, `02`,
`03`, `05`, `06`, then `08`. The original `04` and `05` were retired
once `06` replaced them; the later scripts were renumbered on
2026-10-08 to close the gap.

## Scripts

| Script | Reads | Writes |
| --- | --- | --- |
| `00_mirror_setup_inputs.R` | Every external input, at its original location | `setup_inputs/` on ABMI-DATA2, with `inputs_manifest.csv`. Run once; never overwrites |
| `01_harmonize_model_ready_v2.R` | The `model_ready_v2` snapshot, mammal camera climate, WildTrax species lookup, v2 prediction matrices, bird `Stratified.Rdata` | `0_data/test_dataset/`: responses, `sites.csv`, `covariates.csv`, `bird_offsets.csv`, and most of `lookup/` |
| `02_validate_test_dataset.R` | The test dataset and the same sources | Nothing; prints a pass / fail tally. Run after `01`, `04` and `07` |
| `03_rerun_bryophyte_v2_reference.R` | v2 plant project bryophyte data, frozen v2 functions in `0_data/v2_scripts/plants/` | `2_pipeline/v2_reference/`: `bryophyte-species-models.Rdata`, `bryophyte-bootstrap-ids.Rdata`. Takes hours |
| `04_harmonize_bird_translation_lookup.R` | v2's bird `Xn-veg-v2024.Rdata` | `lookup/bird_veg_age_matrix.csv`. Re-run whenever `01` rebuilds `lookup/` |
| `05_harmonize_v2_plant_bootstrap_ids.R` | v2's stored plant draws; `03`'s bryophyte draws | `lookup/v2_bootstrap_ids/<taxon>/<species>.rds`, for `plant_bootstrap = "v2_ids"` |
| `06_harmonize_abmiexplorer_results.R` | ABMIexploreR's `species-coefs.RData` at a pinned commit; bird `birdlist.csv` | `0_data/external/abmiexplorer/<sha>/`; `0_data/v2_results/abmiexplorer/v2_results.csv` and `v2_results_coverage.csv` |
| `07_harmonize_lookups.R` | `0_data/test_dataset/lookup/` only; offline, seconds | `species_queue.csv`, `factor_levels.csv`, `dataset_manifest.csv`, bird prediction grids |
| `08_publish_datasets.R` | `0_data/test_dataset/`, `0_data/v2_results/` | A new `<version>/` of each on ABMI-DATA2, with `checksums.csv` and `publish_record.md` |
| `run.R` | The scripts above | Runs them in order |
| `utils/input_paths.R` | | `setup_input()`: paths inside the input mirror |

After `08`, move the pin in `1_code/harness/data_source.R`. A
published version is never overwritten.

## The test dataset

`0_data/test_dataset/` holds the data the v2 models were fitted on. It
does not change between experiments.

| File | Holds |
| --- | --- |
| `sites.csv` | One row per survey unit: identity, design, location, and an `in_<taxon>` flag per taxon |
| `<taxon>.csv` | `survey_unit_id` plus one column per species: detections (plants), densities (mammals), counts (birds) |
| `bird_offsets.csv` | QPAD log offsets per survey unit and bird species |
| `covariates.csv` | Every covariate for every taxon, keyed on `survey_unit_id` and a taxon covariate key |
| `lookup/dataset_manifest.csv` | Per taxon and region: files, covariate key, grid and stored draws. The harness reads file locations only from here |
| `lookup/species_queue.csv` | Every taxon's species queue in one schema |
| `lookup/covariate_columns.csv` | Each covariate's block and v2 spelling, per taxon |
| `lookup/factor_levels.csv` | Source order of categorical levels, so contrasts match v2 |
| `lookup/*_prediction_matrix.csv` | Habitat grids: one row per habitat type, a pure stand |
| `lookup/bird_bootstrap_ids.csv`, `lookup/v2_bootstrap_ids/` | v2's stored draws: birds, and plants per species |
| `lookup/mammal_climate_predictions.csv` | v2's precomputed mammal climate prediction |
| `lookup/bird_veg_age_matrix.csv` | v2's bird landcover translation matrix |

Columns in more than one block are suffixed (`HardLin_veg`,
`HardLin_soil`). Ten derived columns (`TD`, `MAT2`, `Easting2` and
others) are computed on load, not stored. Taxon-specific details are in
[`docs/taxon_quirks.md`](../../docs/taxon_quirks.md).

## Environment variables

Each overrides a default path.

| Variable | Read by | Points at |
| --- | --- | --- |
| `SDM_SETUP_INPUT_ROOT` | `00`–`06` | The input mirror |
| `SDM_SNAPSHOT_V2` | `01`, `02` | The `model_ready_v2` snapshot folder |
| `SDM_MAMMAL_CAMERA_CLIMATE` | `01` | `abmi-camera-climate_2023.Rdata` |
| `SDM_MAMMAL_CLIMATE_PRED` | `01`, `02` | `All Species Climate Predictions.csv` |
| `SDM_V2_LOOKUP` | `01` | The v2 folder holding the plant prediction matrices |
| `SDM_WT_SPECIES` | `01` | `WildTrax Species Strings.RData` |
| `SDM_BIRD_DATA` | `01`, `02` | The bird `Stratified.Rdata` v2 was fitted on |
| `SDM_V2_PROJECT` | `03`, `05` | The v2 plant project (`VegetationModels`) |
| `SDM_V2_BIRD_ROOT` | `04` | The v2 bird project (`BirdModels`) |
| `SDM_V2_BOOT_TAXA`, `SDM_V2_BOOT_SPECIES` | `05` | Comma-separated subsets to copy |
| `SDM_ABMIEXPLORER_SHA` | `06` | The ABMIexploreR commit to download |
| `SDM_V2_BIRD_LOOKUP` | `06` | The v2 bird `birdlist.csv` |
| `SDM_SHARE_ROOT`, `SDM_DATASET_VERSION`, `SDM_PUBLISH` | `08` | Publish root, version folder (default today, `YYYY-MM-DD`), datasets |
