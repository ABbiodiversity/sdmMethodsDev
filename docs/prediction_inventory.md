# Spatial prediction: inventory

Phase 1 of adding spatial prediction to the shared harness, as part of
the R&D for Species Models 3.0. This records how v2.0 made provincial
predictions for each taxon, what `sciSpatialR` offers, and where a
prediction stage would plug into this repository. Read-only. The only
repository change is this file.

- **Sources:**
  - `0_data/v2_scripts/{birds,mammals,plants}/`, at the snapshots named
    in that folder's README: BirdModels `1a3e086`, MammalModels
    `2874dec`, VegetationModels `24e97e3`.
  - The MammalModels clone at `2874dec`, held in a session scratchpad.
    It adds the `climate/` folder, which isn't in `v2_scripts`.
  - `sciSpatialR` v0.1.0 at `D:/local_projects/active/sciSpatialR`.
  - `1_code/` on branch `spatial_predictions`, at `6976a7e`.
- **Date:** 2026-10-26.
- **Checks run:**
  - Two read-only R scripts loaded the v2.0 grid files from the S:
    drive and compared them with `sciSpatialR::ab_grid()` (Section 5).
    They wrote nothing outside a scratchpad.
  - A column check on `0_data/test_dataset/covariates.csv`.
  - No models were fitted.
- **Not reachable:**
  - The bird copy of the grid files, under
    `G:/Shared drives/ABMI_RHedley/...`.
  - The plant copy, under `0_data/external/kgrid/`.
  - So only the S: copy was checked.
- **Notation:** paths are relative to `0_data/v2_scripts/` unless they
  start with `1_code/`, `docs/`, a drive letter, or `sciSpatialR/`.
  `file:N` is a line number.

## Summary

1. **All three taxa predict on the same grid.** The v2.0 grid is
   `kgrid_2.2.Rdata`, with 664,762 cells of 1 km² keyed by
   `LinkID = "<Row>_<Col>"`. Land cover comes from
   `backfillV7_w2w_2021HFI.Rdata`. No taxon has its own grid.
2. **The kgrid is the same lattice as `sciSpatialR::ab_grid()`.**
   - Rows, columns, and cell count match exactly.
   - `Easting`/`Northing` sit within 0.5 m of the `ab_grid()` cell
     centres for every full cell.
   - The kgrid `X`/`Y` columns are **not** EPSG:3400 cell centres
     (Section 5.3).
3. **Every taxon follows the same pattern.**
   1. Predict climate.
   2. Cap it at the 99th percentile.
   3. Shift each habitat coefficient by `Climate × slope` on the link
      scale.
   4. Weight by the cell's land-cover proportions.
   5. Blend north (veg) and south (soil) with the kgrid's `wN`/`wS`.
   6. Cap the result again.

   The link, the bootstrap used, the caps, and the handling of
   single-region species differ by taxon (Section 4).
4. **v2.0 predicted the current landscape only.** Reference
   (backfilled) predictions appear only in a plant behaviour check and
   in archived mammal scripts. No live script predicts a reference
   scenario for birds or mammals.
5. **`wN`/`wS` are inherited kgrid columns.** No code in the mammal,
   bird, or plant sources derives them. In practice they are fractional
   only in Parkland and Dry Mixedwood cells, where they track `pAspen`
   closely (r = 0.97). Their rule is `TODO: confirm with mammal lead`.
6. **v2.0 has no focal grids.** The brief says training covariates
   come from native-resolution focal grids. In v2.0 they don't:
   - Grid covariates are 1 km cell-area proportions and cell-level
     climate.
   - Training covariates are site-level values in
     `0_data/test_dataset/covariates.csv`.
   - No focal-grid code exists in v2.0, in this repository, or in
     `sciSpatialR`.

   This affects the Phase 2 design (Section 8.1).
7. **The harness keeps coefficients, not fitted objects.** Glm-based
   stages can be projected from the stored coefficients. Xgboost stages
   can't, because their models are never saved (Section 7.3).

## 1. Scope and method

Phase 1 recorded:

- every grid each v2.0 script reads;
- every prediction step, with the transforms and caps;
- where outputs went.

The grid files were then loaded read-only to confirm their structure,
rather than relying on the scripts' comments. Anything not found in
the sources is marked `TODO: confirm with <taxon> lead` and listed in
Section 9.

## 2. v2.0 prediction grids

The three taxa share the grid files below. Per-taxon rows follow.

### 2.1 Shared grid files

| Grid | Location (S: copy, checked) | Format | Content |
| --- | --- | --- | --- |
| `kgrid` | `S:/sc/AB_data_v2023/kgrid/kgrid_2.2.Rdata`, md5 `5cb58d609acc54c575832e0785943790` | RData, one `data.frame`, 664,762 × 52 | Cell attributes: IDs, coordinates, regions, climate, `pAspen`, `wN`/`wS` (Section 5) |
| `d.wide` | `S:/sc/AB_data_v2023/landcover/backfillV7_w2w_2021HFI.Rdata`, md5 `f3c034c6e38868e63035562834fb0a6f` | RData, list of four `dgCMatrix` | Area in m² per cell for `veg.current` (137 columns), `veg.reference` (80), `soil.current` (62), `soil.reference` (24) |
| Veg lookup | `lookup-veg-hf-age-v2020.csv` | CSV | `ID` to `UseInAnalysis_Simplified` |
| Soil lookup | `lookup-soil-hf-v2020.csv` | CSV | Same, for soil |

The kgrid `metadata.txt` describes version 2.2 like this:

- It is a 1 km² grid that "aligns with the backfill version 7.0
  boundaries".
- Its climate comes from ClimateNA 7.40.
- It adds Bio9, Bio15, and HTV 2.0 to version 2.1, and is otherwise
  identical.
- The object's `comment` attribute dates it to 2024-03-20 and points
  to "the ABMI ClimateData GitHub page" for metadata.

### 2.2 By taxon

| Taxon | Grid | Source (file:line) | Data location | Format | Resolution | Extent | CRS | Cell ID | Attributes used | Scenarios | Masks / exclusions | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Birds | `kgrid`, `d.wide` | `birds/09.Predict.R:34-35` (root at `:21`); `birds/10.Visualize.R:38` | `G:/Shared drives/ABMI_RHedley/Projects/BirdModels/Data/gis/` | RData | 1 km (from the shared file; not stated in the bird scripts) | Province | EPSG:3400, given only when rasterizing (`10.Visualize.R:102,109`) | `LinkID` | `Easting, Northing, MAP, FFP, TD, CMD, pAspen, wN, wS, X, Y`. Derived: `Intercept, Easting2, Northing2, EastingNorthing` (`09.Predict.R:47-52`). `veg.current` and `soil.current` as proportions (`:57-74`) | Current only. The backfill file is loaded, but no reference prediction is made | None at grid level. Excluded classes get coefficient 0 on the response scale (`08.PackageCoefficients.R:293-301, 485-495`). `log(0)` is clamped to `-10^4` (`:322-324, 511-513`) | `create_kgrid()` (`birds/00.Functions.R:47-62`) is defined but unused |
| Mammals (current) | `kgrid`, `d.wide` | `mammals/make-species-predictions.R:393, 396-399` | `S:/sc/AB_data_v2023/kgrid/` and `.../landcover/` | RData | 1 km² (header, `:24-26`) | Province, about 665k cells (`:547`) | EPSG:3400 (`:658`) | `LinkID`. The output is **not** keyed by `LinkID` (Section 3.2) | `(Intercept)`, `Easting2`, `Northing2`, `EastingNorthing` (`:416-420`); `wN, wS, pAspen` (`:457-459`); `X, Y` for maps. `veg.current`/`soil.current` proportions (`:425-454`) | Current only | Excluded through coefficients: north `Mine, SnowIce, HWater` = 0 (`:276-293`); south `SoilUnknown, HWater, HFor` = 0 (`:296-313`) | Lookups from `G:/Shared drives/ABMI Mammals/Data/Habitat Models/` (`:403-413`) |
| Mammals (grid prep, not used by the prediction script) | `km2_current`, `km2_reference` | `mammals/north-models/01_process-grid.R:49-61, 155-161, 301-305`; `mammals/south-models/01_process-grid.R:49-58, 170-176` | `G:/.../veg-hf_grid_v61hf2016v3WildFireUpTo2016.Rdata` (`dd_kgrid`), `kgrid_2.2.Rdata`, `kgrid_table_km.Rdata` | RData | 1 km² | North: `NR != "Grassland"`. South: soil area | Not stated | `LinkID` | North: `Lat = pmax(TrueLat, 51.5)`, `NSR1*` dummies, HF groups. South: `Lat = pmin(TrueLat, 56.5)` | Current and reference | South: `UNK == 0`, `UNK + Water < 0.99`, `TrueLat < 56.7`. Both: `WetlandMargin = 0` | Uses the older v6.1 / 2016 land-cover summary, not backfill v7 |
| Mammals (archived legacy) | `km2.1`, `km2.b.1`, `km2.sc` | `mammals/north-models/archive/02 Process 1km2 Grid.R:27-39, 181-183`; `.../archive/04 Basic Models Figures Maps.R:37, 80-97`; `mammals/south-models/archive/South Step 0.1 ...R:5-10, 55-59, 106` | `G:/.../km2-grid-north_current-backfilled_processed_*.Rdata`, `S:/samba/abmisc/AB_data_v2023/kgrid/kgrid_2.2.Rdata`, `C:/Dave/...` | RData | 1 km² | North / south | Not stated | `LinkID` | Space/climate matrix of `Lat, Long, AHM, FFP, MAP, MAT, MCMT, MWMT, NSR1*` plus polynomials (north `:95-97`; south adds `PET, MAPPET, PeaceRiver`) | Current and reference; maps of Ref / Curr / Difference | Water-dominated mask `km2.water` (`04 ...R:89`); south soil masks | Not runnable as is (Section 8.3) |
| Plants (four taxa) | `kgrid`, `d.wide` | `plants/04c_prediction-comparison.R:35-38`; `plants/05_model-behaviour-checks.R:39-40` | `0_data/external/kgrid/` (repo-relative in VegetationModels) | RData | 1 km | Province | Not stated | `LinkID` | Up to 19 climate terms: `Intercept, MAP, FFP, TD, CMD, bio9, bio15, PET, MAT, MWMT, Easting, Northing, Easting2, Northing2, EastingNorthing, MAPPET, CMDMAT, MAT2, MWMT2`. Built at `04c:72-80`, with `PET <- Eref`. Also `pAspen, wN, wS, NrName, X, Y` | `04c`: current. `05`: reference (`veg.reference`, still named `veg.cur`, `05:54`) plus simulated conversions | Coefficient `-10000` (logit) for veg `MineV, Mine, HWater, Water, Bare, SnowIce` and soil `Mine, MineV, Water, HWater, SoilUnknown` (`04a_coefficient_standardization.R:97-104, 164-170`) | `MineV` column added as 0 (`04c:82-83`) |

## 3. v2.0 prediction logic

### 3.1 Birds (`birds/09.Predict.R`)

| Step | What v2.0 does | Lines |
| --- | --- | --- |
| Coefficients | `Birds2024.RData`, built by `08.PackageCoefficients.R:764-771`. `birds$<region>$marginal` holds climate; `$joint` holds habitat | `:27` |
| Bootstrap | One draw per species, `spp$Bootstrap[i]`, the draw nearest the NMDS centroid | `:121-123`; `08:556-606` |
| Coefficient tidy | North `TreedFenR..8` averaged to `TreedFen`; `Urban` and `Industrial` averaged to `UrbInd`; `MineV` dropped; `GrassHerb` renamed `Grass` | `:82-115` |
| Climate | `inv.link(use.climate %*% climate.i)`, with `inv.link = pmin(pmax(exp(eta), eps), xmax)`. Capped at q99 | `:30, 146-157` |
| Climate source | North marginal coefficients if the species is "both" or "north", otherwise south | `:135-141` |
| North veg | `veg.coef <- t(t(pred.climate * Climate) + veg.i)`; `Veg = rowSums(prop * inv.link(veg.coef))` | `:160-184` |
| South soil | Same, plus `pAspen * coef["pAspen"]` on the log scale | `:187-220` |
| Blend | `Provincial = Veg*wN + Soil*wS`. `Veg`/`Soil` set to 0 where the weight is 0. Infinite values replaced by the median. Capped at `quantile(Provincial, PlotQuantile)`, where `PlotQuantile` is 0.995 by default and 0.990 or 0.999 for listed species | `:222-238`; `08:735-737, 753-755` |
| Offsets | QPAD offsets are used in fitting (`06.ModelClimate.R:111`, `07.ModelLandcover.R:98`). None at prediction, so the output is on the offset-free density scale. `method`, `road` and `pWater_KM` aren't packaged, so they are implicitly 0 / reference | |
| Coefficient adjustments | Linear features and wellsites adjusted and capped at `lam.max`. NESP `Climate × 0.1` | `08:224-287, 353, 423-482, 542` |
| Outputs | `predictions` list (per cell: `Climate, Veg, Soil, wN, wS, LinkID, Provincial, species, Bootstrap`) saved to `.../Results/Predictions2024.RData` | `:247` |
| Rasters and totals | `raster::rasterFromXYZ(crs = 3400)` on `X`/`Y`; provincial total `global(pred, "sum")`; comparison with old models and eBird in `ModelComparison.csv` | `10.Visualize.R:99-110, 114-126, 142, 236` |

### 3.2 Mammals (`mammals/make-species-predictions.R`)

| Step | What v2.0 does | Lines |
| --- | --- | --- |
| Coefficients | North and south 2024 coefficient `.Rdata` files. Climate `avg_coef` per species | `:71-83, 487-495` |
| Column fixes | Renames; `Urban` dropped; `Industrial` renamed to `UrbInd`; north AGP expanded across age classes; "Deer" removed from the south | `:145-218, 244-270` |
| Climate | `inv_logit(use_climate %*% coef)`, from a binomial model-averaged GLM on `FFP, MAP, CMD, TD`. Capped at q99 | `:497-512` |
| Climate source | MammalModels `climate/02_run-models.R` (clone) predicts with `predict(avg_model, type = "link")` then `linkinv`, and saves `avg_coef` | clone `:201-230` |
| North | Per habitat, `pa_adj = inv_logit(Climate * beta + logit(PA_v))` and `TA_v = AGP_v × pa_adj / PA_v`, accumulated as `prop_v × TA_v`. `beta = logit(Climate entry)`, because it is stored as `plogis(beta)` | `:516-563`; `north-models/03_basic-models.R:583-585` |
| South | Same, plus `pAspen` on the logit scale for PA and `exp(pAspen)` for AGP | `:567-618` |
| Blend | `pred_north*wN + pred_south*wS` for two-region species. North-only species get NA where `wN == 0`; south-only species get NA where `wS == 0` | `:622-637` |
| Final cap | q99.9, `na.rm = TRUE` | `:644-647` |
| Standardization baked into coefficients | `seas_days = 100`, `Climate = 0`, south `pAspen = 0`, unlured, calibrated to mean observed PA, summer and winter averaged, cutblock convergence, `Bare`/`Water` = 0, AGP Climate = 1 | `03_basic-models.R:382-398, 533-611, 646-673, 1074-1164` |
| Outputs | `results[[sp]]$Predictions = cbind(Climate, Combined)`, saved as `.../2024 Full Province Mammal Coefficients and Predictions_<date>.Rdata`. PNG maps from `terra::rast(type = "xyz", crs = "EPSG:3400")`. No provincial totals | `:94-100, 651-698, 775` |

The archived legacy scripts (`north-models/archive/04 ...R`,
`south-models/archive/South Step 2 ...R`) differ from this:

- `km2.pveg = colSums(Coef × t(km2))`.
- Then either `km2.pveg × exp(km2.pres)`, or
  `plogis(qlogis(0.998pa + 0.001) + km2.pres) × agp`.
  - North: `:1473-1506`.
  - South: `:666-692`.
- A reference prediction on backfilled native types.
- Per-species overrides, such as Grizzly Bear NSR censoring and
  Wolverine ÷ 3 (`:1396-1410`).
- Maps scaled to q99.
- Per-species CSVs of `LinkID, Ref, Curr` (`:1561-1563`).

### 3.3 Plants (`plants/04c_prediction-comparison.R`)

| Step | What v2.0 does | Lines |
| --- | --- | --- |
| Link | `binomial()$linkinv` | `:49` |
| Coefficients | `3_output/coefficients/COEFS.RData` (`COEFS[[taxon]]$vegetation/$soil/$climate`), compared with `previous-coefficients/COEFS.RData` | `:41-44` |
| Bootstrap | Draw 1 (`[species, , 1]`). `06_median-bootstrap.R` saves a median draw that `04c` doesn't use | `:107-108` |
| Row alignment | `merge(kgrid, veg.cur, by = "LinkID")`; `veg.cur[rownames(soil.cur), ]` | `:86-90` |
| Climate | `inv.link(climate %*% spp.clim)`, capped at q99 | `:111-119` |
| Veg | `t(t(Climate × spp.veg["Climate"]) + veg.coef)`, then `rowSums(prop × inv.link(...))` | `:121-133` |
| Soil | Same, plus `pAspen × spp.soil["pAspen"]`. The first two soil coefficient names are dropped from the land-cover matrix | `:214-329, 243` |
| Protocol | Not in the grid. Habitat coefficients are made at `Protocol = "New"` ("All predictions made with new protocol") | `hierarchical-model_functions.R:236, 245` |
| Blend (maps) | Two-model species: `NewPred*wN + NewSoil*wS`. Veg-only species: NA in Grassland. Soil-only species: NA outside Grassland and Parkland. Each map capped at q99 | `:425-470` |
| Outputs | `3_output/temporary/<taxon>/<species>/vegetation-model.Rdata` and `soil-model.Rdata` (`LinkID, NewPred, OldPred`); JPEG figures. No rasters or totals | `:204-205, 322-323, 414, 522` |
| Reference and simulations | `05_model-behaviour-checks.R`: reference veg; `Crop` = -10000 conversions; age shifts. Saved to `3_output/validation/*.Rdata` | `05:54, 157, 260` |

### 3.4 Helpers

- `landscape_hf_summary()` collapses backfill classes to model classes.
  It has one copy per taxon:
  - `birds/00.Functions.R:14-41`
  - `mammals/00_functions.R:14-41`
  - `plants/data-standardization_functions.R:19`
- No source uses `cure4insect` or `mefa4`.
- The `create_kgrid()` helpers read `rownames(kgrid)`, `POINT_X` and
  `NRNAME`. None of these exist in `kgrid_2.2` (the row names are
  `1..n`), so the helpers would fail on it. Neither is called.

## 4. Differences across taxa

| Item | Birds | Mammals | Plants |
| --- | --- | --- | --- |
| Grid | kgrid 2.2 + backfill v7 2021 HFI | Same | Same |
| Resolution / extent / origin / cell ID | 1 km, province, `LinkID` | Same | Same |
| Response | Density, offset-free (QPAD offset dropped) | Density (animals/km²) = PA × AGP hurdle | Probability of occurrence |
| Link and back-transform | `exp`, clamped to `[eps, xmax]` | `plogis` (PA) and `exp` (AGP, `pAspen`) | `plogis` |
| Climate terms | `MAP, FFP, TD, CMD`, Easting/Northing polynomial | `FFP, MAP, CMD, TD` (plus model averaging) | Up to 19, including `bio9, bio15, PET (= Eref), MAT, MWMT`, products and polynomial |
| Climate cap | q99 | q99 | q99 |
| Climate entry into habitat | `+ Climate × β` on the log scale | `+ Climate × logit(stored)` on the logit scale (PA only) | `+ Climate × β` on the logit scale |
| South `pAspen` | Log scale | Logit (PA) and log (AGP) | Logit |
| Bootstrap used | NMDS-median draw | Single fit (full data) | Draw 1 |
| Final cap | q`PlotQuantile` (0.995 default) | q99.9 | q99 per map |
| Single-region species | Weight-0 side set to 0, so the result is 0 there | NA where the weight is 0 | NA by `NrName` (Grassland or outside Grassland and Parkland) |
| Excluded classes | Coefficient 0 on the response scale, clamped to `-10^4` | Coefficient 0 | Coefficient `-10000` on the logit scale |
| Class collapsing | TreedFen, UrbInd, Mine/MineV averaged; `GrassHerb` to `Grass` | `UrbInd`, AGP age expansion | Via the `04a` templates |
| Protocol / detection | `method`, `road` at reference (absent) | Unlured, `seas_days = 100` | `Protocol = "New"` |
| Scenarios | Current only | Current (live); current + reference (archived) | Current (`04c`); reference (`05`) |
| Outputs | Per-cell RData, rasters, totals | Per-cell RData (row order, not keyed), PNG | Per-cell RData keyed by `LinkID`, JPEG |
| Blend weights | kgrid `wN`/`wS` | Same | Same |

## 5. Grid file facts (checked)

From `kgrid_2.2.Rdata` and `backfillV7_w2w_2021HFI.Rdata`, S: copy.

### 5.1 kgrid columns

| Group | Columns |
| --- | --- |
| IDs | `LinkID` (factor, unique, `"<Row>_<Col>"`), `Row` 1-1234, `Col` 1-695, `LinkID10` / `Row10` / `Col10` (the 10 km grid, 6,834 cells) |
| Coordinates | `Longitude`, `Latitude`, `Easting`, `Northing`, `X`, `Y` |
| Regions | `NrName` (6 levels), `NsrName` (21), `LufName` (7), `ReportingBoundaries` (Forested 440,326, Prairie 224,436) |
| Cell properties | `AreaKm2` (clipped edge cells, 1.8e-6 to 1.0), `Elevation`, `pAspen`, `pWater`, `wN`, `wS` |
| Climate (ClimateNA 7.40) | `MAT, MWMT, MCMT, TD, MAP, MSP, AHM, SHM, DD_0, DD5, DD_18, DD18, NFFD, bFFP, eFFP, FFP, PAS, EMT, EXT, Eref, CMD, RH, CMI, DD1040, bio9, bio15, HTV` |
| Age | `AgeOffset`, `AgeUnknownOffset`, `UnknownOrigin` |

The only NAs in the file are in `HTV` (4 cells).

`NrName` counts:

| Natural region | Cells |
| --- | --- |
| Boreal | 381,955 |
| Foothills | 66,480 |
| Grassland | 95,877 |
| Parkland | 60,826 |
| Rocky Mountain | 49,822 |
| Canadian Shield | 9,802 |

### 5.2 Alignment with `sciSpatialR::ab_grid()`

| Check | Result |
| --- | --- |
| `ab_grid()` | 1234 × 695, 1000 m, EPSG:3400, extent 170616.2 to 865616.2 × 5425532 to 6659532, origin (-383.8178, -467.5689) |
| Non-NA `ab_grid()` cells | 664,762, the same as the kgrid rows |
| `cellFromRowCol(Row, Col)` vs `cellFromXY(Easting, Northing)` | Identical for all cells |
| `ab_grid()` value at each kgrid cell | 1 for all 664,762 cells; no kgrid cell falls on NA |
| `Easting`/`Northing` minus the cell centre, full cells (`AreaKm2 > 0.999`, 660,480) | Within ±0.48 m |
| Same, all cells | Up to ±500 m. Edge-cell centroids are of the clipped polygon |

So `ab_grid()` is the kgrid lattice. `LinkID` equals the
`GRID1SQKM_AB2020` `GRID_LABEL`, and its terra cell number is
`(Row - 1) × 695 + Col`.

### 5.3 `X`/`Y` are not EPSG:3400 cell centres

`X` and `Y` form a regular lattice, but the steps are 998.977 m and
999.813 m (`X = 170344.8 + 998.977 × Col`;
`Y = 6659843.9 - 999.813 × Row`). They are offset from the `ab_grid()`
centres by up to 482 m. v2.0 birds and mammals still rasterize `X`/`Y`
as EPSG:3400 (`birds/10.Visualize.R:102`,
`mammals/make-species-predictions.R:658`). Those v2.0 maps are
therefore slightly stretched and shifted against the true grid. This
affects how maps look, not the per-cell values. Use `Row`/`Col` or
`Easting`/`Northing`, not `X`/`Y`. What CRS `X`/`Y` are in is
`TODO: confirm with the ClimateData / kgrid maintainer`.

### 5.4 Backfill matrices

- All four matrices have row names identical to `kgrid$LinkID`, **in
  the same order**.
- Values are m², with each row summing to about 1e6 for full cells.
- Birds and mammals put climate predictions (in kgrid order) next to
  `veg.cur` (in `d.wide` order) without an explicit alignment step.
  That is correct for these two files, but only because their orders
  match. Plants align explicitly.

### 5.5 `wN` / `wS`

| Check | Result |
| --- | --- |
| `wN + wS` | 1 in every cell |
| `wN` fractional (strictly between 0 and 1) | 124,018 cells, all in Boreal (63,211) or Parkland (60,807) |
| Mean `wN` | Grassland 0. Canadian Shield, Foothills and Rocky Mountain 1. Boreal 0.968. Parkland 0.654 |
| Fractional by natural subregion | Central Parkland 100%, Foothills Parkland 99.5%, Peace River Parkland 100%, Dry Mixedwood 74%. No other subregion has any |
| Correlation of fractional `wN` with `pAspen` | 0.97; with `Latitude`, 0.30 |

The weights come from the kgrid itself. Searching all 110 files of
MammalModels at `2874dec`, and all of `0_data/v2_scripts/`, finds only
reads of `wN`/`wS`, never a derivation. The data suggest a rule on
`pAspen` within the north/south overlap zone (Parkland and Dry
Mixedwood), but it isn't the identity. For example, `pAspen` 0.71
gives `wN` 0.591. `TODO: confirm with mammal lead` (and the kgrid
maintainer) how they are built.

### 5.6 Training covariates (`0_data/test_dataset/covariates.csv`)

- `Easting`/`Northing` are built from `UTMX`/`UTMY`
  (`1_code/harness/covariate_sets.R:133-160`). The ranges, 171,797 to
  855,117 by 5,425,852 to 6,657,373, match the kgrid
  `Easting`/`Northing` (10-TM).
- **Plants:** `PET == Eref` in every row (bryophyte, lichen, mite,
  vascular plant). The v2.0 grid's `PET <- Eref` matches training.
- **Mammals:** `PET` differs from `Eref` (by up to 121), but the mammal
  climate model doesn't use either.
- **Birds:** `PET` is NA, and the bird climate model doesn't use it.

## 6. `sciSpatialR` (v0.1.0)

The README badges say "In Development" and "Lifecycle: Experimental".
No function carries a lifecycle tag, TODO, or deprecation note. Each
function has a test file in `tests/testthat/`, but no other QA status
is recorded.

### 6.1 Relevant functions

| Use | Function and signature | Location |
| --- | --- | --- |
| CRS | `ab_crs()`, returns `"EPSG:3400"` | `R/reference.R:40` |
| Boundary | `ab_boundary()`, the 2020 dissolved boundary | `R/reference.R:64` |
| Reference grid | `ab_grid()`, `inst/extdata/grid_1km.tif` (value 1 on the 664,762 source cells) | `R/reference.R:100` |
| Alignment | `check_alignment(x, ref = ab_grid(), tol = 1e-6, verbose = TRUE)` | `R/check_alignment.R:50` |
| Resample | `resample_to_grid(x, ref = ab_grid(), method = "auto", quiet = FALSE, ...)`, with `auto` using `near` at equal resolution | `R/resample_to_grid.R:127` |
| Mask | `mask_to_boundary(x, boundary = "alberta", inverse = FALSE, ...)` | `R/mask_to_boundary.R:61` |
| CRS for points | `harmonize_crs(points, raster = ab_grid(), warn = TRUE)` | `R/harmonize_crs.R:60` |
| Point extraction | `extract_points(x, points, bind = TRUE, ...)` | `R/extract_points.R:48` |
| Buffer summary | `extract_buffer(x, points, radii, fun = mean, fun_name = NULL, bind = TRUE, ...)` | `R/extract_buffer.R:66` |
| Class proportions | `extract_proportion(x, points, radius, bind = TRUE, ...)` | `R/extract_proportion.R:59` |
| Polygon join | `extract_vector(points, polygons, cols = NULL, ...)` | `R/extract_vector.R:45` |
| Catalogue root | `spatial_root(check = TRUE)`, defaulting to `//ABMI-DATA2/science/spatial_data` | `R/catalogue.R:135` |
| Catalogue | `build_catalogue(root = spatial_root(), files = TRUE, refresh = FALSE, quiet = FALSE)` | `R/catalogue.R:227` |
| Search | `find_layer(theme, keyword, year, extent, resolution, crs, verbose, ...)` | `R/catalogue.R:801` |
| Read | `get_layer(name, file = NULL, return_path = FALSE, ...)` | `R/catalogue.R:914` |
| Other catalogue | `list_layers`, `layer_files`, `list_themes`, `list_variables`, `download_layer`, `read_metadata`, `layer_meta`, `check_metadata` | `R/catalogue.R`, `R/variables.R`, `R/download_layer.R`, `R/metadata.R` |
| Viewing | `plot_raster(x, stretch, col, boundary, ..., maxcell = 5e5)`, `plot_hist()`, `raster_stats(x, aoi = "alberta", ...)`, `theme_science_map()` | `R/plot_raster.R:119, 320`; `R/plot_hist.R:87`; `R/raster_stats.R:128` |

### 6.2 Gaps that matter for this work

These are reported only. `sciSpatialR` is read-only for this work.

| Gap | Effect | Possible change upstream |
| --- | --- | --- |
| `ab_grid()` is fixed at 1 km, and no function builds a grid at another resolution | A 500 m grid has to be built here, with `terra::disagg(ab_grid(), 2)` | `ab_grid(res = 1000)` or `make_grid(res, ref = ab_grid())`, keeping the same origin |
| No cell-ID output | `LinkID` has to be built from row and column here | `grid_ids(x)` returning `Row`, `Col`, `LinkID` |
| No extraction to cell centres | Prediction covariates from rasters have to use `terra::extract()` or `resample_to_grid(method = "near")` directly | `extract_grid(x, grid, method = "near")` |
| No focal / moving-window grids | No route to the brief's "focal grids" | `focal_grid(x, radius, fun)` (Section 8.1) |
| No 10 km grid or 1 km to 10 km link | kgrid already has `LinkID10`, so this can be used instead | Publishing it is already listed as a proposed improvement |
| `extract_*` with `bind = TRUE` drops geometry; no count of valid cells | QA has to count NAs itself | Listed in the vignette's known gaps |
| Stale doc: `inst/extdata/README.md` still names the removed `aggregate_to_grid()` | None | Fix the README |

## 7. Target repository

### 7.1 Run flow and stores

The harness has no prediction-to-map stage today. Runs go through
`run_experiment()` (`1_code/harness/experiment.R:457-538`):

1. Fit (`run_specs()`).
2. Summarize to `3_output/<id>/tables/`.
3. Compare with the exp_000 baseline.
4. Run the experiment's own `steps`.
5. Write `run_record.md`.

The store layout is `2_pipeline/<id>/<run>/<region>/`. Each store holds
`coefficients.csv`, `metrics.csv`, `grid_predictions.csv`, optional
`unit_predictions.csv`, and `meta.json` (`1_code/harness/result.R:41-55`).

- There is no resume, because every rerun refits.
- There is no `2_pipeline/shared/` and no `manifest.md`.

### 7.2 Where a prediction stage would plug in

| Point | Location | Use |
| --- | --- | --- |
| After the draws, per store | `run_one_draw()`, `1_code/harness/run_model.R:1079-1244` (habitat-table prediction at `:1226-1241`) | The only place the fitted objects are in memory. A cell prediction could run here, at the cost of every draw's run time |
| From stored coefficients | `predict_from_coefficients(coefficients, data, scale)`, `1_code/harness/predict_grid.R:151-211` | Already evaluates terms, interactions and `I()` against a frame. Covers the glm climate stages and the averaged habitat coefficients |
| As a run step | `run_experiment(steps = ...)`, `experiment.R:511-514, 739-756` | A post-fit step reading the stores. It fits the "harness stage after fitting" pattern and needs no refit |
| Config | `experiment_config()` arguments (`experiment.R:85-106`); `harness/README.md:74-94` | No prediction keys exist. Unknown fields aren't validated, so exp_000 adds ad hoc ones (`exp_000_parity_v2/run.R:84-90`) |
| Spec fields | region `grid`, `grid_constants`, `grid_drop_rows/cols`; stage `carry_*`, `constants`; spec `final_prediction` (`1_code/harness/spec.R:39-75`) | Carry and constants already encode the v2.0 standardization (Climate = 0, `pAspen` = 0, `seas_days` = 100) |
| Final plant formula | `plant_v2_full_prediction()`, `1_code/modules/_shared/plant_group.R:854-861` | Already the v2.0 `plogis(qlogis(x %*% plogis(effects)) + climate × slope + aspen)` |

### 7.3 What modules supply today, and what prediction would need

| Needed for grid prediction | Available now | Gap |
| --- | --- | --- |
| Climate coefficients per draw | `coefficients.csv`, stage `climate` (birds, plants, mammals fitted) | Mammals with `climate_source = "precomputed"` have no climate coefficients, only site values in `lookup/mammal_climate_predictions.csv` |
| Habitat coefficients per class | `coefficients.csv` habitat stage; birds through `bird_habitat_translation` at summary time (`modules/birds/standardize.R:503-511`) | The class names must map to the backfill lookup classes (`UseInAnalysis_Simplified`). That mapping isn't in the harness |
| Mammal PA and AGP tables | `habitat_presence`, `habitat_abundance`, `habitat_total` (`run_model.R:1138-1145`; `modules/mammals/hurdle.R:166-265`) | None |
| Fitted objects | Not saved (no `saveRDS` in harness, methods, or modules) | Xgboost and other non-coefficient engines can't be projected after the run |
| Offsets | Birds only; set to 0 for habitat-table prediction (`predict_grid.R:117-119`) | Same choice as v2.0 |
| Region assignment | Region filters per spec (plants by `nr`, birds `useNorth/useSouth`, mammals by filter) | Grid-side blending uses `wN`/`wS`, which no module holds |
| Bootstrap selection | All draws are stored | Birds use an NMDS-median draw; plants use draw 1. Neither rule is in the harness |
| Caps and back-transforms | Not in the harness | All taxon-specific (Section 4) |

## 8. Risks and inconsistencies

### 8.1 Focal grids premise

The brief says training covariates are extracted to points from
native-resolution focal grids, and prediction covariates come from the
same grids at cell centres. That isn't how v2.0 works:

- Prediction covariates are 1 km cell summaries: backfill area
  proportions, and the cell's climate.
- Training covariates are site-level values from the v2.0 data
  pipelines.

There is no focal-grid code to reuse. A focal-grid approach would be a
new covariate definition, and would change results compared with v2.0.
`TODO: confirm with leads` whether focal grids are planned for 3.0, or
whether the brief meant the kgrid summaries.

### 8.2 Map geometry

The v2.0 maps rasterize `X`/`Y`, which are not EPSG:3400 cell centres
(Section 5.3). Maps rebuilt on `ab_grid()` will look slightly different
from the v2.0 PNGs, but the per-cell values are the same.

### 8.3 Archived mammal scripts don't run

- `04 Basic Models Figures Maps.R` expects `kgrid_veg_*_north`, but
  `01_process-grid.R` saves `km2_current`/`km2_reference`.
- Its species loop closes at `:1465`, before the map and CSV block at
  `:1467-1569`.
- So the archived reference prediction can't be reproduced from these
  scripts as they are.

### 8.4 Mammal output isn't keyed

`results[[sp]]$Predictions` follows the row order of `veg_cur`, with
no `LinkID`. The row order matches the kgrid (Section 5.4), so a
`LinkID` can be attached by position.

### 8.5 Two mammal grid preparations

`01_process-grid.R` uses the v6.1 / 2016 land-cover summary (`dd_kgrid`)
with masks. The prediction script uses backfill v7 2021 with no masks.
The fitting grids and the prediction grid are not the same product.
`TODO: confirm with mammal lead` which is canonical for 3.0.

### 8.6 Mammal climate source wording

`1_code/modules/mammals/spec.R:143` defaults to `"fitted"`, but
`1_code/experiments/exp_000_parity_v2/README.md:69` and
`docs/mammals_climate_inventory.md:152` say "precomputed".

### 8.7 Bird reference scenario

Birds have no v2.0 reference prediction, so there is no v2.0 target
for bird parity on the reference scenario.

### 8.8 Bootstrap choice differs by taxon

Birds use the NMDS-median draw, plants use draw 1, and mammals use a
single fit. A shared stage must allow each, or parity will differ by
design.

### 8.9 Edge cells

`AreaKm2` is 0.999 or less for 4,282 cells. v2.0 predictions are densities
or probabilities per cell and ignore cell area. Provincial totals that
sum densities without weighting by `AreaKm2` overstate the edge cells
slightly, as the bird totals in `10.Visualize.R:142` do.

### 8.10 `HTV`

`HTV` has 4 NA cells. It isn't in any v2.0 model set read here, so
there is no effect now.

## 9. TODOs

| # | Item | Owner |
| --- | --- | --- |
| 1 | How kgrid `wN`/`wS` are derived (`pAspen`-based rule in Parkland and Dry Mixedwood?) | `TODO: confirm with mammal lead` (and the kgrid maintainer) |
| 2 | The CRS and purpose of kgrid `X`/`Y` | `TODO: confirm with the kgrid maintainer` |
| 3 | Whether "focal grids" are planned for 3.0, or the brief meant the kgrid cell summaries | `TODO: confirm with leads` |
| 4 | The canonical mammal prediction land cover: v6.1 / 2016 `km2_*` with masks, or backfill v7 2021 | `TODO: confirm with mammal lead` |
| 5 | The reference (backfill) scenario definition for mammals: `veg.reference` / `soil.reference` from backfill v7, or the archived `km2.b` native-only types | `TODO: confirm with mammal lead` |
| 6 | Whether a bird reference scenario is wanted, given that v2.0 has none | `TODO: confirm with bird lead` |
| 7 | Whether the bird and plant v2.0 copies (G: and `0_data/external/kgrid`) are the same files as the S: copy. Only the S: copy was reachable to checksum | `TODO: confirm with bird lead` and `plant lead` |
| 8 | The plant reference scenario: only a behaviour check (`05`) exists. Is it a deliverable? | `TODO: confirm with plant lead` |
| 9 | Which bootstrap the 3.0 maps should use (median of draws, a chosen draw, or the mean of draws) | `TODO: confirm with leads` |
| 10 | The v2.0 published prediction outputs to compare with (bird `Predictions2024.RData`, mammal `2024 Full Province ... Predictions_<date>.Rdata`, plant `3_output/temporary/...`). Their locations weren't checked | `TODO: confirm with each taxon lead` |

## 10. Docs that will need updating later

These are listed only; none was edited.

- `README.md`: "How it works" (a new prediction stage and its outputs)
  and "Repository structure" (`2_pipeline/shared/`).
- `1_code/harness/README.md`: the config table (`:74-94`) and the
  stage list.
- `1_code/modules/README.md`: the module interface, if modules gain
  prediction fields.
- `1_code/experiments/exp_000_parity_v2/README.md`: prediction parity,
  and the mammal climate source wording (Section 8.6).
- `1_code/experiments/_template/` README and config notes.
- `docs/framework_design.md:567-571`: "spatial prediction onto the
  1 km grid", currently listed as still to come.
- `docs/mammals_climate_inventory.md:37, 200` and
  `docs/mammals_climate_design.md:282, 375`: these say spatial
  prediction is deferred.
- `docs/getting_started.md` and `docs/index.md`: a pointer to the
  prediction settings.
