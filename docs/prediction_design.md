# Spatial prediction: design

Phase 2 of adding spatial prediction to the shared harness, as part of
the R&D for Species Models 3.0. This is a proposal: no code has
changed. It builds on [prediction_inventory.md](prediction_inventory.md),
cited below as "inventory §N".

- **Date:** 2026-10-26.
- **Status:** approved 2026-10-27, with the §7 answers below. Phase
  3 (grid build) is done; see
  [prediction_grid_qa.md](prediction_grid_qa.md).

## Decisions already made

| # | Question | Decision (2026-10-26) |
| --- | --- | --- |
| D1 | Focal grids or kgrid summaries? | Predict to the kgrid. Prediction covariates must match the covariates used in training, so there are no focal grids |
| D2 | Fitted objects aren't saved | Acceptable. Spatial prediction can be part of the modelling run |
| D3 | Which bootstrap draw to map | Default to the median draw. Allow an option to predict every draw and write mean and SD rasters |

## Summary

1. **Grid.** One canonical prediction grid: kgrid 2.2 attributes plus
   backfill v7 (2021 HFI) land-cover proportions, on the
   `sciSpatialR::ab_grid()` 1 km lattice.
   - This *is* the v2.0 grid for every taxon (inventory §5.2), so the
     crosswalk to v2.0 cells is the identity on `LinkID`.
   - Resolution is a build parameter, but only 1 km can be built now.
     A 500 m grid needs a 500 m backfill summary, which doesn't exist
     (§1.1).
2. **Stage.** A new taxon-agnostic harness step, `predict_spatial`. It
   runs inside `run_experiment()`, between fitting and summarizing, so
   it is part of the modelling run. It reads each run's stored
   coefficients, so it needs no refit.
   - Coefficients cover every parity stage.
   - Engines without coefficients have their fitted objects saved
     during the fit, but only when prediction is on (§2.6).
3. **Prediction rule.** v2.0's own rule, ported per taxon:
   1. Predict climate per cell and cap it.
   2. Shift each habitat class by `Climate × slope`, and add `pAspen`
      in the south.
   3. Back-transform and mix by the cell's class proportions.
   4. Blend north and south with `wN`/`wS`.
   5. Apply the final cap.

   Modules supply the taxon-specific pieces as data and settings,
   matching the current interface (§2.3).
4. **Draws.** `draws = "median"` by default (§2.4). `draws = "all"`
   also writes per-cell mean and SD. A vector of draw numbers is
   allowed, for example `1` to match v2.0 plants.
5. **Parity.** Two layers (§4):
   - A strict port check: v2.0 coefficients run through the new stage
     must reproduce v2.0's maps to floating-point precision.
   - A model check: harness-fitted maps compared with the v2.0 maps by
     correlation, mean absolute difference, and provincial totals.
6. **Departures from v2.0** are listed in §6. The main ones:
   - The default draw rule.
   - Maps placed by `Row`/`Col` instead of `X`/`Y`.
   - Area-weighted provincial totals, reported next to the v2.0
     unweighted totals.

## 1. Unified prediction grid

### 1.1 Resolution, extent, alignment, CRS, IDs

| Property | Canonical grid | Source |
| --- | --- | --- |
| Lattice | `sciSpatialR::ab_grid()`: 1234 rows × 695 columns, 1000 m, origin (-383.8178, -467.5689) | inventory §5.2 |
| Extent | 170616.2 to 865616.2 × 5425532 to 6659532 (EPSG:3400) | same |
| Cells | 664,762, the non-NA `ab_grid()` cells. Every kgrid row, no gaps | same |
| CRS | EPSG:3400 (`sciSpatialR::ab_crs()`) | |
| Cell ID | `LinkID = "<Row>_<Col>"`, the kgrid and `GRID1SQKM_AB2020` label. Also `cell`, the terra cell number `(Row - 1) × 695 + Col`, for writing rasters | inventory §5.1 |
| Coordinates | `Easting`/`Northing` (EPSG:3400 centroids). `X`/`Y` are dropped, because they aren't EPSG:3400 centres | inventory §5.3 |

**The resolution parameter.** The build script takes `res_m`.

- `res_m = 1000` is the canonical grid, built from the kgrid and the
  backfill summaries.
- For `res_m = 500`, the lattice is easy: `terra::disagg(ab_grid(), 2)`
  keeps the origin, and each 500 m cell nests in exactly one 1 km
  parent. The covariates are the problem:
  - The land-cover proportions exist only as 1 km summaries.
  - A 500 m grid would need the backfill v7 polygons re-summarized at
    500 m. That is a new GIS product.
  - Copying the 1 km proportions to the four 500 m children would
    create no new information, and would break D1 ("match the
    covariates used").
- So for `res_m != 1000` the script stops with a message naming the
  missing input. Building a 500 m backfill summary is listed as a
  follow-up.

| Alternative considered | Why not |
| --- | --- |
| A new grid from sciSpatialR catalogue layers | Its covariates wouldn't match the training covariates (D1), and the catalogue has no per-cell land-cover composition |
| Copying 1 km values to 500 m | False resolution. Same values, four times the size |

### 1.2 Attributes

All attributes come straight from the v2.0 files (inventory §5).
Nothing is recomputed from rasters. That keeps training and prediction
covariates on the same definitions, as D1 requires. Columns are named
as the harness training covariates are, so the harness's existing
`derived_covariates()` (`1_code/harness/covariate_sets.R:92-160`)
derives `Easting2`, `MAPPET` and the rest identically on the grid.

| Group | Columns stored | Notes |
| --- | --- | --- |
| IDs | `LinkID`, `Row`, `Col`, `cell`, `LinkID10` | |
| Geometry | `Easting`, `Northing`, `UTMX` (= `Easting`), `UTMY` (= `Northing`), `AreaKm2` | `UTMX`/`UTMY` aliases are needed because the training data name the coordinates that way (inventory §5.6) |
| Regions and strata | `NrName`, `NsrName`, `LufName`, `ReportingBoundaries`, `wN`, `wS` | `wN`/`wS` are stored as given. Their derivation is a TODO (inventory §9 #1) |
| Cell covariates | `pAspen`, `pWater`, `Elevation` | |
| Climate | All 27 kgrid climate columns, plus `PET` (= `Eref`) | `PET = Eref` matches the plant training data (inventory §5.6). `HTV` has 4 NA cells |
| Land cover, current | Sparse cells × classes matrix of **proportions**, veg and soil | Classes are the shared v2020 lookups' `UseInAnalysis_Simplified` (inventory §2.1), the level all three taxa used |
| Land cover, reference | Same, from `veg.reference` / `soil.reference` | |

The land cover is stored at the shared simplified-class level, not as
raw backfill IDs. All three taxa applied the same
`landscape_hf_summary(..., class.out = "UseInAnalysis_Simplified")`
step. Each taxon then renamed or merged classes. That per-taxon step is
module data (§2.3), not part of the grid.

The lookups used are the v2020 veg and soil CSVs on the mammal shared
drive (md5 `2bbd27d4...` veg, `b38cec8c...` soil). The bird copy
wasn't reachable, so whether it is identical is unconfirmed
(inventory §9 #7).

### 1.3 Scenarios

| Scenario | Land cover | v2.0 use |
| --- | --- | --- |
| `current` | `veg.current`, `soil.current` (backfill v7, 2021 HFI) | All taxa (live scripts) |
| `reference` | `veg.reference`, `soil.reference` (same file, backfilled, native only) | Plants `05` behaviour check; archived mammal maps (on an older land-cover file) |

Climate, `pAspen` and the weights are the same in both scenarios, as in
v2.0. `reference` is offered but isn't the default (§3). The
reference definitions for mammals and plants are TODOs (inventory §9
#5, #8).

### 1.4 Masks, regions, stratification

The grid applies no mask. v2.0's live scripts don't mask the grid; they
exclude classes through coefficients (inventory §2.2). The grid carries
the fields that every taxon's rules need:

| Field | Used for |
| --- | --- |
| `wN`, `wS` | North/south blend (all taxa) |
| `NrName` | Plant single-region NA rule (`04c:425-470`) |
| `NsrName`, `LufName`, `ReportingBoundaries` | Extent subsets and summaries |
| `pWater` | Optional summary filters. Not used by v2.0 prediction |

The mammal `01_process-grid.R` masks (`UNK`, `TrueLat < 56.7`) belong
to a different land-cover product, which the prediction script doesn't
use (inventory §8.5). They aren't ported unless the mammal lead says
otherwise.

### 1.5 Crosswalks

| From | To | Method | Limits |
| --- | --- | --- | --- |
| Unified 1 km | v2.0 kgrid (all taxa) | Identity on `LinkID` | None. Same cells, same order (inventory §5.2, §5.4) |
| Unified 1 km | Mammal `km2_*` north/south grids | `LinkID` subset (filter) | Those grids use other land cover, so values differ by design |
| Unified 1 km | `ab_grid()` raster | `cell` | Exact |
| Future 500 m | 1 km | Child-to-parent by containment (`terra::disagg` nesting) | Exact for geometry. Covariates are a separate issue (§1.1) |

Because the 1 km crosswalk is the identity, the build writes no
crosswalk file for it. `manifest.md` records the identity and the
evidence for it.

### 1.6 Storage and versioning

There are two copies:

- **Built** (local, gitignored): `2_pipeline/shared/prediction_grid/<version>/`.
- **Published** (pinned for runs):
  `//ABMI-DATA2/science/sdmMethodsDev/0_data/prediction_grid/<version>/`.

The published copy follows the existing pattern for `test_dataset` and
`v2_results`:

- a `checksums.csv`;
- a pin in `1_code/harness/data_source.R`, as
  `prediction_grid = "<version>"`;
- `published_dir("prediction_grid")`.

Runs never read `2_pipeline/shared/` directly. Other users then get the
same grid without rebuilding it, and it stays fixed on the back end.
Publishing writes to the network share, so I'll ask before doing it in
Phase 3.

The version name is `kgrid22_bf7hfi2021_1km_v1`: it names the
sources, the resolution, and a build counter.

| File | Format | Content |
| --- | --- | --- |
| `cells.rds` | `data.table`, rows in `LinkID` order | §1.2 attributes |
| `landcover_veg_current.rds`, `landcover_veg_reference.rds`, `landcover_soil_current.rds`, `landcover_soil_reference.rds` | `dgCMatrix` of proportions, rows identical to `cells$LinkID` | §1.2 land cover |
| `lookups/lookup-veg-hf-age-v2020.csv`, `lookups/lookup-soil-hf-v2020.csv` | Byte copies | Provenance |
| `checksums.csv` | md5 and size per file | Used by `check_published()` |
| `README.md` | | What the version is |

`manifest.md` sits in `2_pipeline/shared/prediction_grid/`, with a
copy in the published root. It has one entry per version:

- source paths and md5;
- the build script and commit;
- the date and `res_m`;
- the cell count;
- QA results, linked to `docs/prediction_grid_qa.md`.

On format: RDS is used because `arrow`, `fst` and `qs` aren't
installed, and `readRDS` of a `data.table` plus sparse matrices is
fast and keeps the class. CSV of a 664,762 × 60 table is slow, and it
loses precision unless written at full digits. GeoTIFF layers would
make the sparse land cover dense: 137 layers × 664k cells.

### 1.7 Build script location

The build goes in a new back-end folder, `1_code/_prediction_grid/`.
It is separate from `_setup/`, which stays limited to the test dataset
(project rule).

| Script | Does |
| --- | --- |
| `01_build_prediction_grid.R` | Reads the S: sources and the lookups, builds §1.2, and writes `2_pipeline/shared/prediction_grid/<version>/` |
| `02_qa_prediction_grid.R` | §1.8 checks. Writes `docs/prediction_grid_qa.md` |
| `03_publish_prediction_grid.R` | Copies to ABMI-DATA2 and writes `checksums.csv`. Never overwrites. Run only with approval |
| `utils/` | Shared helpers, if needed |

Input paths go through a small path helper with environment-variable
overrides, like `_setup/utils/input_paths.R`. There is no heavy
extraction and no Google Earth Engine (GEE) step: everything comes from
two RData files and two CSVs.

### 1.8 Grid QA (Phase 3)

The QA script checks:

- the cell count (664,762);
- extent and CRS;
- `check_alignment()` against `ab_grid()`;
- no duplicate or missing `LinkID`s;
- proportions summing to 1 per row and scenario, with a tolerance and
  a list of exceptions;
- NA counts per column;
- covariate ranges compared with the training ranges in
  `covariates.csv`, by taxon, with the share of cells outside the
  training range;
- spot checks: 200 random `LinkID`s compared value by value with the
  raw kgrid and backfill files, after applying the lookup.

## 2. Prediction stage

### 2.1 Where it runs

`run_experiment()` gets a new step, **predict**, between fit and
summarize:

1. Fit (unchanged, plus saving fitted objects where §2.6 applies).
2. **Predict** (new).
3. Summarize.
4. Compare.
5. The experiment's own steps.
6. Record.

| Option | Pros | Cons | Chosen |
| --- | --- | --- | --- |
| Inside `run_one_draw()` | Has the live model | The median draw isn't known until every draw is done. Mammal seasons are separate runs, and v2.0 averages their tables before predicting (`north-models/03_basic-models.R:1067-1100`). Doing it here would add grid memory to every worker for the whole fit | No |
| End of `fit_species()` (per species, per run) | Has all draws | Still can't combine mammal seasons | No |
| **Post-fit step reading the stores** | Has all draws and all runs. Parallel per species. Can be rerun alone (`run_experiment(config, fit = FALSE, predict = TRUE)`) | Needs saved fitted objects for engines without coefficients (§2.6) | **Yes** |
| A separate experiment script | Simple | Not shared; every experiment would copy it | No |

D2 holds, because the step runs inside the modelling run.

### 2.2 Per-species algorithm

The steps below run for each species, scenario, and selected draw.
Every taxon-specific choice is a module setting (§2.3).

1. **Climate per cell.**
   - `eta_clim = predict_from_coefficients(climate coefficients,
     cells, "link")`, using the existing function
     (`1_code/harness/predict_grid.R:151-211`).
   - Back-transform with the module's link: `plogis` for plants and
     mammals; for birds, `exp` clamped to `[eps, xmax]`
     (`birds/09.Predict.R:30`).
   - Cap at the module's `climate_cap` quantile (0.99 for all taxa).
2. **Habitat per region.** For each region `r` (north = veg,
   south = soil):
   1. Get the per-class link coefficients `b_v` from the stored
      habitat tables:
      - plants: the `habitat` stage;
      - birds: `standardize_bird_coefficients()` applied per draw
        (`1_code/modules/birds/standardize.R:503-511`);
      - mammals: `habitat_presence` and `habitat_abundance`.
   2. Map grid classes to model classes with the module class map.
      Excluded classes get the module's fixed value.
   3. Compute, per chunk of cells:
      `eta[c, v] = b_v + beta_clim × Climate_c (+ beta_aspen × pAspen_c)`.
   4. Combine with the module's `combine` rule:
      - `mixture` (birds, plants):
        `pred_r[c] = sum_v p[c, v] × g(eta[c, v])`;
      - `mammal_hurdle`:
        `sum_v p[c, v] × AGP_v × plogis(beta × Climate_c + qlogis(PA_v)) / PA_v`,
        plus the south `pAspen` terms (`make-species-predictions.R:516-618`).
3. **Blend.** `pred = wN × pred_north + wS × pred_south`, with the
   module's single-region rule:
   - birds: the weight-0 side is set to 0;
   - mammals: NA where the weight is 0;
   - plants: NA by `NrName`.

   Birds also replace infinite values with the median
   (`09.Predict.R:222-238`).
4. **Final cap.** Cap at the module's `final_cap` quantile:
   - birds: `PlotQuantile` per species (default 0.995);
   - mammals: 0.999;
   - plants: 0.99.

Both caps are computed over the **full province** even when an extent
subset is requested. Otherwise subset caps would differ from v2.0's
(§5).

**Mammal seasons.** For each draw `b`, the summer and winter habitat
tables are averaged on the scale v2.0 averaged them (`Coef.pa`,
`Coef.agp`). The prediction then uses the averaged tables. Species
modelled in one season only use that season, as v2.0 does
(`03_basic-models.R:1067-1100`). Draw 1 (the full data, in both
seasons) is the direct analogue of v2.0's single mammal fit.

**Plants: grid formula, not site formula.**
`plant_v2_full_prediction()` (`1_code/modules/_shared/plant_group.R:854-861`)
mixes classes, then adds climate. v2.0's grid code (`04c:121-133`)
adds climate per class, then mixes. The grid stage ports `04c`, so the
two functions stay separate on purpose.

### 2.3 Module interface

There is one new optional spec field, `spatial`: a plain list,
validated by `validate_spec()`. It holds configuration, not code, like
the rest of the module interface (`1_code/modules/README.md:36-63`). A
spec without `spatial` is skipped by the predict step with a logged
message.

```r
spatial = list(
  link = "logit",             # "logit" | "log"
  link_bounds = NULL,         # birds: c(eps, xmax)
  climate_stage = "climate",
  climate_cap = 0.99,
  combine = "mixture",        # "mixture" | "mammal_hurdle"
  habitat_stages = "habitat", # mammals: presence + abundance
  aspen = list(south = "paspen"),   # term name per region
  class_map = "spatial_classes.csv",# in the module folder
  single_region = "zero",     # "zero" | "na" | "na_by_nr"
  final_cap = 0.995,          # or a per-species column name
  season_average = FALSE      # mammals: TRUE
)
```

`class_map` is one CSV per module, in `1_code/modules/<taxon>/`, with
columns `region, grid_class, model_class, fixed_value`. It ports the
v2.0 renames:

- **Birds:** `TreedFen` from `TreedFenR..8`, `Urban`/`Industrial` to
  `UrbInd`, `GrassHerb` to `Grass`, `MineV` dropped
  (`09.Predict.R:82-115`). Excluded classes get 0 on the response
  scale.
- **Mammals:** `make-species-predictions.R:184-313`.
- **Plants:** the `04a` templates (`04a_coefficient_standardization.R:97-104, 164-170`).
  Those templates come from `vegetation-model-labels_2024.csv`, which
  isn't in `v2_scripts`. `TODO: confirm with plant lead`. If it can't
  be found, the map is rebuilt from `plant_v2_term_labels()`, and
  Phase 5 checks it against `04c`.

**Module changes for taxon-lead review.** None is made until approval.

| File | Change |
| --- | --- |
| `1_code/modules/birds/spec.R` | Add `spatial` with a per-species `final_cap`. `PlotQuantile` isn't in `bird_modelled_species.csv` or anywhere in `1_code/`; v2.0 sets it in `08.PackageCoefficients.R:735-737, 753-755`. The port encodes those listed species as module data (`TODO: confirm with bird lead`) |
| `1_code/modules/birds/spatial_classes.csv` | New |
| `1_code/modules/mammals/spec.R` | Add `spatial` (`combine = "mammal_hurdle"`, `season_average = TRUE`, `single_region = "na"`) |
| `1_code/modules/mammals/spatial_classes.csv` | New |
| `1_code/modules/_shared/plant_group.R` | Add `spatial` in `plant_group_spec()` (`single_region = "na_by_nr"`) |
| `1_code/modules/_shared/plant_spatial_classes.csv` | New, shared by the four plant taxa |

**Harness changes:**

| File | Change |
| --- | --- |
| `1_code/harness/spec.R` | `spatial` in `spec_fields()`; validation |
| `1_code/harness/predict_spatial.R` | New: grid loading, draw selection, the §2.2 algorithm, writers |
| `1_code/harness/experiment.R` | `prediction` argument; predict step; record lines |
| `1_code/harness/data_source.R` | `prediction_grid` pin |
| `1_code/harness/harness.R` | Load `predict_spatial.R` |
| `1_code/harness/run_model.R` | Save fitted objects for engines without coefficients when prediction is on (§2.6) |
| `1_code/harness/run_record.R` | Grid version, draw rule, scenarios |

### 2.4 Draw selection

`draws = "median"` (the default, D3) picks one real draw, so the map is
a coherent prediction from a single model.

**The rule:**

1. Predict every draw at a fixed, seeded sample of 10,000 cells,
   stratified by `wN` band so both regions and the overlap zone are
   represented.
2. Take the per-cell median across draws.
3. Choose the draw with the smallest sum of squared differences from
   that median, on the link scale (log for birds and mammals, logit
   for plants).
4. Break ties with the lowest draw number.

Doing this on 10,000 cells costs about 1 % of a full prediction.

| Alternative considered | Why not the default |
| --- | --- |
| v2.0 bird rule: the draw nearest the NMDS centroid of the coefficients | Only defined for coefficient engines; it depends on an ordination choice; and it measures distance in coefficient space, not on the map |
| Nearest to the median coefficient vector | Not engine-agnostic. Term scales differ |
| Per-cell median map | Not a single model. Not what D3 asks for |
| Draw 1 (v2.0 plants) | Not a median. Still available as `draws = 1` |

`draws = "all"` predicts every draw and keeps a running per-cell mean
and SD (Welford's method). Memory is two vectors per region per cell,
not cells × draws. The median-draw map is still written. `draws = <int
vector>` predicts only those draws.

### 2.5 Outputs

| Output | Location | Tracked |
| --- | --- | --- |
| Per-cell predictions per species, scenario, and draw rule: `LinkID`-ordered vectors for `climate`, `north`, `south`, `combined`, and with `draws = "all"`, `mean` and `sd` | `2_pipeline/<exp>/predictions/<run>/<species>__<scenario>.rds` | No |
| GeoTIFF per species, scenario, and statistic (`median`, `mean`, `sd`), FLT4S, DEFLATE, tiled, on `ab_grid()` via `cell` | `3_output/<exp>/maps/<run>/<species>__<scenario>__<stat>.tif` | No |
| Optional PNG quick-looks (`sciSpatialR::plot_raster()`) | `3_output/<exp>/maps/<run>/png/` | No |
| `prediction_summary.csv`: species, run, scenario, draw, chosen draw, cells, NA cells, mean, q50, q99, cap values, provincial total (area-weighted, and unweighted as in v2.0), totals by `NrName` | `3_output/<exp>/tables/` | **Yes** |
| `prediction_parity.csv` (exp_000 only, §4) | `3_output/<exp>/tables/` | **Yes** |

`.gitignore` currently ignores `3_output/**` except named CSVs. Two
whitelist lines are needed, one for each new table. That is the only
`.gitignore` change. Rasters stay ignored.

### 2.6 Engines without coefficients

When prediction is on and a stage's selection result has no
coefficients (for example xgboost), `run_one_draw()` saves the stage's
fitted object to
`2_pipeline/<exp>/<run>/<region>/_models/<species>/<boot>__<stage>.rds`.

The predict step then builds pure-stand rows: one row per cell and
model class, with the class indicator, the cell's climate, and the
stage constants. It predicts those rows with the saved object and
mixes the results as in §2.2.

This is new and has no v2.0 counterpart, so it isn't part of parity.
When prediction is off, nothing is saved, and stores are unchanged.
`compare_stores.R` doesn't read `_models/`.

## 3. Config

There is one new argument, `experiment_config(prediction = ...)`,
filled by a helper:

```r
prediction = prediction_config(
  enabled   = FALSE,          # harness default: off (run time)
  species   = NULL,           # NULL = every species fitted
  scenarios = "current",      # v2.0 live scripts: current only
  draws     = "median",       # "median" | "all" | integer vector
  extent    = NULL,           # NULL = province, or a filter
  outputs   = c("table", "raster"), # + "png"
  summaries = c("province", "natural_region"),
  sample_cells = 10000,       # median-draw selection sample
  chunk_cells  = 50000,
  workers   = NULL            # NULL = config$workers
)
```

- **Extent subsets.** `extent` takes `list(LufName = "Lower Peace")`,
  any `cells` column filter, `list(bbox = c(xmin, xmax, ymin, ymax))`,
  or the preset `"parity_test"`.
  - `"parity_test"` is the `Col 300:400` strip, about 120,000 cells. It
    crosses Grassland, Parkland, and Boreal, so it covers both regions
    and the blend zone.
  - Caps still come from the full province (§2.2).
- **Grid version.** It isn't an experiment setting: it comes from the
  `data_source.R` pin. Experiments select from the grid and never
  rebuild it.
- **exp_000_parity_v2.** It sets `prediction_config(enabled = TRUE)`,
  with every other setting at its default. Its parity steps add the
  checks in §4.
- **`_template/`.** It gets a commented `prediction = prediction_config(...)`
  block listing every key and its default.

## 4. Parity approach

The unified grid is the v2.0 grid (§1.5), so the "v2.0 grid adapter"
option isn't needed: nothing is lost through the crosswalk. What can
differ is (a) the port of v2.0's prediction code and (b) the fitted
coefficients. Those are tested separately.

| Layer | What is compared | Achievable agreement | Use |
| --- | --- | --- | --- |
| **A. Port check (strict)** | The new stage run on **v2.0's published coefficients** (pinned `v2_results`) vs an independent transcription of each v2.0 script's math (`09.Predict.R`, `make-species-predictions.R`, `04c`), on the same grid | Floating point: target max relative difference < 1e-8. Any larger difference is a port bug | Gate for Phase 4 |
| **B. Model check** | Harness-fitted maps (median draw, and with `draws = "all"`, the mean) vs the layer A v2.0 maps | Bounded by coefficient parity, which is indicative only so far (`3_output/exp_000_parity_v2/tables/parity_summary.csv`) | Reported in `prediction_parity.csv` |
| **C. Published outputs** (if found) | Layer A maps vs v2.0's saved per-cell predictions (`Predictions2024.RData` and similar) | Exact if same coefficients and draw | Confirms layer A against v2.0's actual files. Inventory §9 #10 |

Layer B metrics, by taxon, species, region, and scenario:

- Pearson and Spearman correlation over cells;
- mean absolute difference, also relative to the v2.0 mean;
- provincial total ratio (new / v2.0), both weightings;
- the share of cells within ±20 %.

Proposed indicative targets: Spearman ≥ 0.95 and totals within 10 %.
They would be recorded in `utils/parity_targets.R` and **not gated**
while coefficient parity is a trial. Draw choice matters for B:

| Taxon | v2.0 draw | Layer B uses | Why |
| --- | --- | --- | --- |
| Birds | NMDS-median draw | The harness median draw, plus `draws = "all"` mean | Same intent, different metric. Reported, not forced |
| Plants | Draw 1 | Draw 1 and the median | Draw 1 is like for like; the median shows the default's effect |
| Mammals | Single full-data fit | Draw 1 (full data) and the median | Draw 1 is the like-for-like analogue |

**Recommendation:** layer A as the gate, layer B reported, and layer C
if the v2.0 outputs can be found. The alternative was to predict only
through adapters to each v2.0 grid. It gives nothing here, because the
grids are identical, and it would add code to maintain.

## 5. Compute

The machine has 24 cores and 128 GB of memory.

| Item | Estimate / approach |
| --- | --- |
| Grid in memory | `cells.rds` about 250 MB; sparse land cover about 150 MB (current) and about 80 MB (reference). Loaded once per worker through the existing `cache.R` |
| Per-chunk work | 50,000 cells × about 100 classes = 5 M doubles (40 MB) per `eta` matrix |
| Run time | About 1 s per species, draw, and scenario for coefficient engines. The median rule adds a 10,000-cell pass over every draw (seconds). `draws = "all"` × 100 is about 2 minutes per species and scenario |
| Parallel | Species-level PSOCK workers, as in `run_jobs()`, capped by `prediction$workers`. 12 workers use about 6 GB for the grid |
| terra | Used only to write rasters: `rast(ab_grid())`, set values by `cell`, `writeRaster(datatype = "FLT4S", gdal = c("COMPRESS=DEFLATE", "TILED=YES"))`. `terraOptions(tempdir = 2_pipeline/<exp>/tmp)` |
| Disk | About 3 MB per GeoTIFF; about 15 MB per species and scenario RDS |
| Testing | `extent = "parity_test"` with 2 species per taxon (the exp_000 species list) |

Province-wide and multi-taxon prediction runs only with your approval
(constraint).

## 6. Departures from v2.0 and common practice

| # | Departure | Effect on results | Why |
| --- | --- | --- | --- |
| 1 | Default draw is the harness median draw (§2.4) | Plants (v2.0 draw 1) and mammals (v2.0 full fit) map a different draw by default. Birds use the same intent with a different metric | D3. `draws = 1` reproduces plants and mammals |
| 2 | Rasters placed by `Row`/`Col` on `ab_grid()`, not by `X`/`Y` | Maps shift by up to about 480 m against v2.0 PNGs; cell values are unchanged | v2.0's `X`/`Y` aren't EPSG:3400 centres (inventory §5.3) |
| 3 | Provincial totals area-weighted by `AreaKm2` | Edge cells weigh less (4,282 cells) | Common practice. The v2.0 unweighted total is reported alongside |
| 4 | Mammal outputs keyed by `LinkID` | None | v2.0 relies on row order (inventory §8.4) |
| 5 | Caps from the full province on subset runs | None for the province; subsets match v2.0 caps | Keeps subset tests comparable |
| 6 | Engines without coefficients predicted from pure-stand rows (§2.6) | New; no v2.0 counterpart | Lets any engine map |
| 7 | Plant grid uses `04c`'s per-class climate shift, not the site-level formula | None for v2.0 grid parity | Faithful port |

All quantile caps (q99, q99.5, q99.9) and the infinite-to-median
replacement are ported unchanged, even though capping is uncommon in
SDM mapping. Suggested improvements, which are not made:

- report uncapped maps alongside;
- replace the bird infinite-to-median fix with a link-scale bound.

## 7. Open items for approval

**Answers (2026-10-27):** item 1 yes (published and pinned); item 2
yes (Phase 4 includes engines without coefficients); item 3 was not
answered, so the defaults below apply until a taxon lead says
otherwise.

1. **Publishing.** Do you approve publishing the grid to
   `//ABMI-DATA2/science/sdmMethodsDev/0_data/prediction_grid/` and
   pinning it in `data_source.R`? The alternative is local
   `2_pipeline/shared/` only, which other users would have to rebuild.
2. **Engines without coefficients (§2.6).** Should Phase 4 include
   them, or should it error clearly and leave them for later? I
   recommend including them, since D2 allows saving fitted objects in
   the run.
3. **Inventory TODOs** that affect Phase 4, with defaults if no answer
   comes:
   - `wN`/`wS` (used as given);
   - the mammal reference scenario (backfill v7 `*.reference`);
   - the plant class templates (rebuilt from `plant_v2_term_labels()`);
   - the bird `PlotQuantile` values (ported from the `08` species
     lists).

## 8. READMEs and docs to update later (not edited)

These are in addition to inventory §10:

- `1_code/harness/README.md`: the `prediction` config, and the predict
  step in the stage list.
- `1_code/modules/README.md`: the `spatial` field and the class-map
  CSVs.
- A new `1_code/_prediction_grid/README.md`, which is part of Phase 3's
  new folder, not an edit to an existing README.
- `docs/framework_design.md`: the prediction stage.

## 9. Phase 4 implementation notes (2026-10-27)

What the build changed or settled. Each item is a decision made
while porting, for review.

| # | Item | What was done | Why |
| --- | --- | --- | --- |
| 1 | Layer A input | The port check gives both sides the harness's own mapped draw, not v2's published coefficients | The published table uses ABMIexploreR labels with aliases (`IndustrialRural`, a single `TreedFen`), not the names v2's map scripts read. Feeding it to the transcription would need a rename that isn't v2's code. Layer B still uses the published coefficients |
| 2 | Logit inverse | `binomial()$linkinv`, not `plogis()` | v2's plant and mammal scripts use it. It is bounded at machine epsilon beyond ±30 on the link scale. The port check found the 2e-16 difference |
| 3 | `caps_from` | New setting. `"province"` (default) computes every cell and writes the extent; `"extent"` computes and caps the extent only | Quick tests without a province-wide run. Not v2's caps |
| 4 | Statistic names | `median_draw`, `mean`, `sd`, `draw<b>` | `median` reads as a per-cell median, which §2.4 rejected |
| 5 | Mammal pAspen | The south hurdle tables now carry `pAspen` in presence (`plogis(slope)`) and abundance (`exp(slope)`), as v2 publishes them | v2's map needs the slopes, and the stores lacked them. The five-draw regression check found every existing value identical and only these 20 rows per south store new. Season-averaged, they match v2's published values (Moose 0.8668 and 0.7056; Coyote 0.6409 and 1.630) |
| 6 | Class maps | `model_class` may list several terms, separated by `;`, averaged on the link scale | v2's bird `TreedFen` and `UrbInd` means (`09.Predict.R:76-111`), as data, not code |
| 7 | Engine classes | A fourth class-map column, `engine_class`, names the prediction-matrix rows for engines without coefficients | The matrices are coarser than the grid classes |
| 8 | Draw choice and scenarios | The median draw is chosen on `current`, then used for every scenario. It is chosen on values before the final cap | One model per species across scenarios. The final cap needs a full map per draw |
| 9 | Mammal climate | The season runs' climate coefficients are averaged term by term | Both runs fit the same pooled climate model, so draw 1 is identical in both |
| 10 | Bird regions | A bird species is mapped in the regions it was fitted in. v2 used `show` from `birds-v2024.csv` (`08:731-733`) | `show` isn't in the test dataset. `TODO: confirm with bird lead` |

**Limits of the engine path (§2.6).**

- It supports `combine = "mixture"` only. A mammal hurdle fitted with
  another engine stops with a message.
- Plant prediction-matrix rows have no stand ages, so aged classes
  take their stand type's row.
- The bird matrices have no rows for linear features or wellsites,
  so those classes add nothing with an engine.

**Found, not changed.**

- The pinned test dataset (2026-10-05) has no mammal province table,
  so exp_000, the unit tests, and any mammal run need
  `SDM_TEST_DATASET` set to the local `0_data/test_dataset`, as
  exp_000's last run did. A new published version would fix this.
- `bird_translation_context()` is rebuilt for every species and
  region. That costs a few seconds per bird species; caching it would
  speed up runs with many species.

## 10. Phase 5 verification (2026-10-27)

**The run.** exp_000's 14 species were refitted at 100 draws into a
scratch folder. They were mapped on the `parity_test` strip (113,530
cells) with `caps_from = "province"`, so every cell was computed and
the caps are v2's. The real exp_000 stores were not touched.

**Coefficient parity is unchanged.** Every existing term matches
the current exp_000 `parity_summary.csv`. Every stage has 100% of
its reachable terms in band. The new mammal `pAspen` rows match v2's
published values within 5e-15.

**Layer A (port check): 24 of 24 pass.** Climate and map, for every
species, agree with the v2 transcriptions within 9.6e-16 relative.

**Layer B (model check, not gated), harness median draw against
v2's published coefficients:**

| Taxon | Result |
| --- | --- |
| Mammals | Moose and Coyote agree within 3e-14 |
| Birds | AMRO: Spearman 0.997, totals 1.05. YEWA: 0.996, 0.88 |
| Plants | Galium, Vicia, Ceratozetes and Ceratodon: Spearman ≥ 0.997, totals 1.01 to 1.05. Physcia: 0.999, 1.11. Cladonia: 0.978, 1.69. Trhypochthonius: 0.87, 0.83 on the cells v2 maps (see below) |
| Bryum.All | Not compared; v2 publishes no coefficients for it |

Mammals agree because draw 1 is v2's single fit, and the median
draw was draw 1.

**Reading layer B.** For birds and plants, v2 publishes the median of
each term on its own, not one fitted model. Those medians can come
from different draws, so together they need not describe a model
any draw resembles:

- Built the same way from the harness's own draws, the bird maps
  match v2's exactly (totals 1.000, Spearman 1.000). The bird gap is
  this construction, not the fit.
- Built that way, Cladonia's total ratio falls from 1.69 to 1.19.
- Trhypochthonius (corrected the same day). v2 publishes no north
  habitat model for it, although the test dataset lists it as
  modelled in the north and the harness fits one. The model check
  had read the missing north as zero everywhere. That compared real
  boreal predictions with zeros, which gave the 25 times total and
  the negative correlation. `published_set()` now drops a region v2
  does not publish, so v2's south-only rule applies. On the
  Grassland and Parkland cells left:
  - the map has Spearman 0.87 and total 0.83;
  - the south models alone have Spearman 0.997 and ratio 0.90;
  - the gap left comes from the Parkland, where the harness blends
    its north model (mean weight wN 0.68) and v2 maps the south
    model alone.

  Why v2 has no north model for this species is a
  `TODO: confirm with mite lead`. It has 546 north detections, so
  the 20-detection rule does not explain it.
- So layer B is a weak test for plants. The right reference is v2's
  draw-1 maps, layer C, which have not been found.

**Bugs found and fixed in Phase 5.**

- With `caps_from = "province"`, the final cap was taken over the
  written extent only. Maps are now mixed and capped over every
  computed cell, then cut to the extent.
- `prediction_config(extent = "parity_test")` failed its own check.
- `01_compare_to_v2.R` averaged the new `pAspen` rows across seasons
  on the published scale. It now averages on v2's logit and log
  scales.

**Scratch experiment.** `exp_003_prediction_scratch_test` was made
by `new_experiment()` from `_template/` and run with non-default
settings:

- an xgboost habitat stage for Galium boreale;
- `draws = "all"`;
- both scenarios;
- the Lower Peace extent, with `caps_from = "extent"`;
- PNG output, sample size 2,000, 2 workers.

All 60 summary rows were `ok`, and GeoTIFFs, PNGs, RDS files and the
run record were written. The experiment and its `2_pipeline/` and
`3_output/` folders were then deleted.

**.gitignore.** Grid files, prediction RDS files, saved models,
GeoTIFFs and PNGs are ignored. Only `prediction_summary.csv` and
`prediction_parity.csv` are tracked.
