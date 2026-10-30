# Prediction grid

These scripts build, check, and publish the unified 1 km prediction
grid that every taxon's spatial predictions use. The design is in
[docs/prediction_design.md](../../docs/prediction_design.md) §1. The
latest QA report is
[docs/prediction_grid_qa.md](../../docs/prediction_grid_qa.md).

Only maintainers run these scripts. Runs read the published copy
through `prediction_grid_dir()` in `1_code/harness/data_source.R`,
which pins the version.

## What the grid is

- The v2.0 `kgrid_2.2` attributes and the backfill v7 (2021 HFI)
  land-cover proportions.
- On the `sciSpatialR::ab_grid()` lattice: 1234 × 695 cells of 1 km,
  in EPSG:3400, with 664,762 cells in Alberta.
- Cells in the same order as the v2.0 kgrid, so the crosswalk to v2.0
  is the identity on `LinkID`.
- Land cover at the v2020 lookups' `UseInAnalysis_Simplified` level,
  for the current and reference scenarios. Veg is the north region and
  soil is the south region.

## Run order

Run from the repository root:

| Script | Does | Time |
| --- | --- | --- |
| `01_build_prediction_grid.R` | Reads the sources and checks their md5s. Writes `2_pipeline/shared/prediction_grid/<version>/` and `manifest.md` | About 2 minutes |
| `02_qa_prediction_grid.R` | Checks the build against its sources, the lattice, and the training covariate ranges. Writes `qa_summary.csv`, `qa_covariate_ranges.csv`, and `docs/prediction_grid_qa.md` | About 3 minutes |
| `03_publish_prediction_grid.R` | Copies a build with no QA failures to `//ABMI-DATA2/science/sdmMethodsDev/0_data/prediction_grid/<version>/`. Writes `checksums.csv` | About 1 minute |

`utils/grid_settings.R` holds the version name, the source paths and
their md5s, and the manifest writer.

## Versions

Each version name lists its sources and resolution, for example
`kgrid22_bf7hfi2021_1km_v1`.

- A source with a different md5 stops the build. Make a new version
  in `utils/grid_settings.R` instead.
- Published versions are never overwritten.
- After publishing, move the pin in `data_source.R`.

## Settings

| Variable | Default | Use |
| --- | --- | --- |
| `SDM_GRID_KGRID`, `SDM_GRID_BACKFILL`, `SDM_GRID_VEG_LOOKUP`, `SDM_GRID_SOIL_LOOKUP` | The paths in `utils/grid_settings.R` | Read a local copy of a source |
| `SDM_GRID_BUILD_ROOT` | `2_pipeline/shared/prediction_grid` | Local build folder |
| `SDM_GRID_RES_M` | `1000` | Other values stop. A 500 m grid needs the backfill summarized at 500 m first |
| `SDM_GRID_OVERWRITE` | `FALSE` | Rebuild an existing local version |
| `SDM_SHARE_ROOT` | `//ABMI-DATA2/science/sdmMethodsDev/0_data` | Publish somewhere else |
| `SDM_PREDICTION_GRID` | Unset | For runs: read a local grid folder instead of the pinned copy |
