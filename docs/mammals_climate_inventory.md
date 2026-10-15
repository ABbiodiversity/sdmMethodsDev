# Mammal climate stage: inventory

Phase 1 of porting the v2.0 mammal climate stage into the shared
harness, so mammals follow the bird and plant pattern: a
province-wide climate stage fitted in the run, carried as `Climate`
into the regional habitat models. Read-only; nothing in the repository
was changed.

- **Source:** `ABbiodiversity/MammalModels` at `2874dec`
  (2026-09-01), `1_code/2_habitat-modeling/climate/`. Read from a
  shallow clone in a session scratchpad; never run.
- **Date:** 2026-10-14.
- **Checks run:** read-only R scripts (data.table only, no model
  fits) that rebuild v2's training set from v2's own inputs and from
  the test dataset, and compare both with v2's outputs.

## 1. The source climate stage

### 1.1 Run order

| Order | File | Does |
| --- | --- | --- |
| 1 | `01_prepare-data.R` | Joins camera climate to the 2022 SpTable, pools seasons into one presence per deployment and species, saves `d_model` |
| 2 | `02_run-models.R` | Sources `00_models.R`; fits nine binomial GLMs per species, averages by AICc, writes coefficients, site predictions, AUC, and maps |
| - | `00_models.R` | Defines `modelsclimate`, the nine formulas |

Nothing else is sourced. The climate scripts are **not** in
`0_data/v2_scripts/mammals/`, which holds only the `2024/` folder.
Those 21 files match `2874dec` blob for blob (checked 2026-10-14).

### 1.2 Inputs

| Input | Path in source | Made by | Reachable now |
| --- | --- | --- | --- |
| Density table `d` | `G:/Shared drives/ABMI Mammals/Results/Density/R Dataset SpTable for ABMI North and South mammal coefficients 2022.RData` (`01:50-55`) | Upstream density pipeline, outside this folder. `TODO: confirm with mammals lead` which script | Yes (dated 2024-10-09) |
| Camera climate `camera.climate` | `S:/sc/AB_data_v2023/sites/processed/climate/abmi-camera-climate_2023.Rdata` (`01:58-62`) | ABMI climate extraction | Yes (dated 2025-12-17); already mirrored for `_setup/01` |
| kgrid | `S:/sc/AB_data_v2023/kgrid/kgrid_2.2.Rdata` (`02:57-59`) | ABMI | Not checked. Used only for maps and the 1 km prediction |
| Provincial boundary | `G:/.../Data/Spatial/AB Provincial Boundary/lpr_000b21a_e.shp` (`02:62-66`) | Statistics Canada | Not checked. Maps only |

The 2022 SpTable is a different file from the two 2024 regional
SpTables that `_setup/01` builds the test dataset from
(`_setup/01_harmonize_model_ready_v2.R:106-115`).

### 1.3 Response

Built in `01_prepare-data.R:128-180`:

1. Pivot every `<Species>Summer` and `<Species>Winter` density column
   to long, with `days` = `SummerDays` or `WinterDays`.
2. Per `location_project` and species: `weighted.mean(density,
   w = days)`, then `present = full_density_km2 > 0`.
3. Drop rows where the mean is NA or `FFP` is NA.

Three details matter for a faithful port:

- **Zero-day seasons are ignored.** Base `weighted.mean()` drops
  zero-weight elements, so a season with 0 days and NA density does
  not make the mean NA. 97 of v2's Moose sites depend on this.
  (data.table's grouped `weighted.mean` does not drop them; a port
  must not use it.)
- **No lure correction, no scaling, no effort filter.** The response
  is raw 0/1. There is no `seas_days > 10`, `WetlandMargin`, or
  `Water` filter; every deployment with a density and climate is in.
- **Duplicate `location_project` rows are pooled.** `d` has 5,435
  rows and 5,431 unique `location_project`. Grouping pools
  duplicates into one weighted mean, giving 4,931 Moose rows for
  4,927 deployments.

### 1.4 Climate covariates

`01_prepare-data.R:81-106`. `camera.climate` rownames are
`location_YYYY`. The year suffix and `CMU-` / `NWSAR-` prefixes are
stripped, and one row is kept per `location`. The join is on
`location` only (normals do not vary by year). The SpTable's own
`AHM, PET, FFP, MAP, MAT, MCMT, MWMT` are dropped and replaced by
`FFP, MAP, TD, CMD, EMT` from the camera file. `EMT` is carried but no
formula uses it.

### 1.5 Model form

| Element | Value | Source |
| --- | --- | --- |
| Candidates | `present ~ 1`, `~ FFP`, `~ MAP`, `~ CMD`, `~ TD`, `~ TD + FFP`, `~ MAP + CMD`, `~ TD + FFP + CMD`, `~ MAP + FFP + TD + CMD` | `00:29-44` |
| Engine | `glm(f, data, family = binomial)`, defaults otherwise | `02:97-101` |
| Weights, offset | None | `02:100` |
| Transformations | None | `00:29-44` |
| Failed fits | Dropped silently (`try()`, then `keep()`) | `02:99-104` |
| Averaging | `MuMIn::model.avg(models, rank = "AICc")`; full average (absent terms zero) for coefficients | `02:105`, `02:213-216` |
| Site prediction | `plogis(predict(avg, type = "link", newdata = sp_data))`; MuMIn's default `full = TRUE` | `02:131-153` |
| Hyperparameters, seeds, bootstrap, CV | None. One fit per species on all data | `02:113-118` |

### 1.6 Fitting scope

- One model per species, **seasons pooled**, **province-wide** (north
  and south together), no regional split.
- All 39 species and species groups in the SpTable, including
  `Deer`, `Wolves, Coyotes and Allies`, and `Voles, Mice and Allies`.
  ABMIexploreR publishes 21 of them.

### 1.7 Outputs and how they are consumed

| Output | Written at | Consumed by |
| --- | --- | --- |
| `Coefficients/<sp> Climate Coefficients.RData`: `avg_coef` (term, full-average coef) and `climate_auc_sp` | `02:213-230` | `make-species-predictions.R:485-505`: `plogis(kgrid %*% coef)` per 1 km cell, capped at the 99th percentile; then `PA_adj = plogis(climate_logit + logit(PA_v))` |
| `Predictions/All Species Climate Predictions.csv`: one row per `location_project`, one probability column per species (full common names) | `02:131-153, 258` | North `03_basic-models.R:83-87, 128-129, 289-295, 328-331, 359-362` and south `88-92, 127-128, 237-264, 298-301, 329-332`: pivoted long, `inner_join` on `location_project`, `filter(!is.na(Climate), !is.na(Count))`, fitted as the `Climate` covariate in the presence models only. South first converts names to PascalCase |
| `Predictions/All Species Climate AUC.csv` | `02:163-190, 260-267` | Reporting only |
| `Prediction Maps/<sp> Climate Predictions.png` | `02:233-252` | Reporting only |

In the habitat stage, `Climate` enters presence only. Abundance drops
it (north `03:494-496`), and the stored `Climate` presence value is
`plogis(coef)` of its slope (north `03:581-584`). The harness already
ports all of this (`modules/mammals/hurdle.R`).

### 1.8 Paths and packages

- Hard-coded: `G:/Shared drives/ABMI Mammals/`, `S:/sc/AB_data_v2023/`,
  and a relative `2_pipeline/climate/`. Marked `!!` to update each
  cycle (`01:49, 57`).
- Packages: `tidyverse`, `sf` (maps), `MuMIn` (averaging). Installed
  here: MuMIn 1.48.11, R 4.5.0. The v2 run's versions are not recorded.
  `TODO: confirm with mammals lead`.

## 2. Checks against v2's outputs

| Check | Result |
| --- | --- |
| v2 coefficient file (Moose) against ABMIexploreR `v2_results.csv` | Identical on all five terms. The two v2 references agree |
| Prediction CSV sites in the 2022 SpTable | 4,927 of 4,927 |
| Training set rebuilt from v2's inputs (Moose), with base `weighted.mean` | 4,931 rows; matches the CSV's 4,927 deployments plus the 4 pooled duplicates |
| Same, from the test dataset (both regions) | 4,849 unique deployments. **120 of v2's sites are absent, 42 sites are extra** |
| Test dataset north rows against v2, matched sites | 4,195 matched; presence and days agree on all |
| Test dataset south rows against v2, matched sites | 1,125 matched; presence agrees on all but one (Coyote); **days disagree at 110** |
| Overlapping deployments (in both regions) | 516; climate agrees on all; days disagree at 103; Moose densities at 196 |
| Climate values, test dataset against camera file | Identical where matched (max difference 0) |

**Consequence.** Fitted on the test dataset, the climate stage cannot
match v2's coefficients to 1e-6, because its training set is not v2's.
The differences are in the data, not the method.

## 3. Target repository

### 3.1 What exists

| Piece | Location | State |
| --- | --- | --- |
| Province-scope climate stage | birds `modules/birds/spec.R:71-89`; plants `modules/_shared/plant_group.R:115-125` | `scope = "province"`, `weighted = FALSE`, `aic_average`, `carry_as = "Climate"` |
| Province draws | birds `modules/birds/spec.R:106-113` | `resample$scope = "province"`, filtered per region |
| Province fitting | `harness/run_model.R:398-470` (`province_context()`, `province_request()`), `610-748` (`fit_species()`, `fit_province_stages()`) | Frame built with `region = NULL`, no weight column |
| Carry | `harness/run_model.R:948-972` (`carry_values()`), `1027-1051` | `carry_scale`: response, link, exp |
| Averaging | `methods/selection/aic_average.R` | MuMIn-style full average; predictor averages link predictions |
| Candidate set | `harness/model_sets.R:35-45` `climate_bird_mammal_v2` | The same nine formulas as `00_models.R`, null included |
| Mammal climate today | `modules/mammals/spec.R:141-165`; `modules/mammals/hurdle.R:59-88` | Default `"precomputed"` reads v2's CSV (`lookup/mammal_climate_predictions.csv`). `"fitted"` is region-scope, per season, season-weighted, lure-corrected (`mammal_pa_response`); marked `partial` |
| v2 references | `0_data/v2_results/abmiexplorer/v2_results.csv` (21 species, `mammal,all,climate,presence,all`); `test_dataset/lookup/mammal_climate_predictions.csv` | Both present |
| Comparison | `experiments/exp_000_parity_v2/01_compare_to_v2.R:152-172` | Climate rows mapped to region `all`, part `presence` |

### 3.2 Climate covariates in `0_data/`

No `manifest.md` files exist in `0_data/`; the manifest is
`test_dataset/lookup/dataset_manifest.csv` plus `covariate_columns.csv`.

| Covariate | Mammal north | Mammal south | Source |
| --- | --- | --- | --- |
| FFP, MAP, TD, CMD | Yes | Yes | Camera climate, joined by `_setup/01:263-277, 1037-1070` |
| EMT | Yes | Yes | Same; unused by v2 formulas |
| `summer_days`, `winter_days` | Yes | Yes | `sites.csv` |
| Per-season density | Yes | Yes | `mammal.csv`, `<Species>_Summer`, `<Species>_Winter` |

Nothing the formulas need is missing. What is missing is v2's exact
training set (section 2).

### 3.3 Where the climate output plugs in

With the province stage, `carry_values()` writes `Climate` to each
regional frame (`run_model.R:1027-1031`). The hurdle stage reads it
with `carry_from = "climate"` (`modules/mammals/spec.R:247-248`),
replacing `mammal_precomputed_climate()` (`hurdle.R:59-88`), which
today attaches the CSV value and drops rows without one.

## 4. Mapping table

| Source element | Source location | Target location | Mechanism | Notes |
| --- | --- | --- | --- | --- |
| Nine candidate formulas | `00_models.R:29-44` | `harness/model_sets.R:35-45` (`climate_bird_mammal_v2`) | Config default (existing set) | Already identical; no change |
| Density input (2022 SpTable) | `01_prepare-data.R:50-55, 69` | `test_dataset/mammal.csv` (2024 regional SpTables) | Harness data layer | Different file; see section 2 and Q1 |
| Camera climate join on location | `01_prepare-data.R:58-62, 74-106` | `test_dataset/covariates.csv` via `_setup/01:263-277, 1037-1070` | Existing data | Values identical where matched |
| Drop deployments without climate | `01_prepare-data.R:108-117, 169` | Province frame: rows with NA climate | Engine `na.action` or module response helper | Design decides where |
| Season pooling: `weighted.mean(density, days)`, zero-day seasons ignored | `01_prepare-data.R:128-166` | New mammal climate response helper in `modules/mammals/` | Module function | Needs both season columns of one species; the harness gives a stage one column (Q3) |
| `present = mean > 0`, raw 0/1 | `01_prepare-data.R:167-175` | Same helper | Module function | No lure correction, unlike today's `"fitted"` |
| No filters (effort, wetland, water) | `01_prepare-data.R:156-170` | Province frame, `region_filter = NULL` | Harness (existing) | Already how province frames are built |
| One row per `location_project`; duplicates pooled | `01_prepare-data.R:156-160` | Province frame for a region-keyed taxon | Harness change (Q2) | 512-516 deployments sit in both regional files |
| Province-wide, seasons pooled, one fit per species | `02_run-models.R:113-118` | Stage `scope = "province"` | Spec field | Both season runs would fit the same model (Q3) |
| `glm(..., family = binomial)`, unweighted | `02_run-models.R:97-101` | `engine = "glm"`, `family = "binomial"`, `weighted = FALSE` | Spec fields | Today's `"fitted"` is weighted |
| Failed fits dropped | `02_run-models.R:99-104` | `harness/selection.R` `fit_candidates()` | Harness (existing) | Confirm it drops rather than stops (Phase 2) |
| `model.avg(rank = "AICc")`, full average | `02_run-models.R:105, 213-216` | `selection = "aic_average"`, `ic = "AICc"` | Registered rule | Bird parity already relies on it |
| Site prediction `plogis(link)` | `02_run-models.R:131-153` | `carry_values()`, `carry_scale = "response"` | Spec field (default) | Matches the CSV's 0-1 scale |
| Regional join `inner_join` + `filter(!is.na(Climate))` | north `03:359-362`; south `03:329-332` | `carry_from = "climate"` in the hurdle stage | Spec field (existing) | Carry gives every regional row a value; v2 dropped rows without one. Rows without climate must still drop (Q4) |
| Coefficient file `avg_coef` | `02_run-models.R:213-230` | `2_pipeline/<id>/<run>/<region>/coefficients.csv`, stage `climate` | Harness (existing) | Written once per region, identical values |
| Per-species AUC | `02_run-models.R:163-190` | Metrics: `insample_auc` | Harness (existing) | Province-stage metrics: confirm they are scored (Phase 2) |
| Site predictions CSV | `02_run-models.R:258` | `unit_predictions = "all"` (optional) | Config | Not needed for the hand-off; used for parity check (b) |
| kgrid prediction, 99th percentile cap, maps | `02_run-models.R:194-254`; `make-species-predictions.R:485-505` | None | Out of scope | Spatial prediction is deferred |
| Hard-coded paths | `01:40-64`; `02:46-77` | `harness/data_source.R`, `test_dataset_dir()` | Repo convention | No new paths needed if Q1 is answered "test dataset" |

## 5. Differences from the bird and plant climate stages

| Aspect | Mammals (v2) | Birds (v2) | Plants (v2) |
| --- | --- | --- | --- |
| Candidates | 9 (`climate_bird_mammal_v2`) | 25 (+ linear and quadratic space) | 58 (`climate_plant_v2_full`) |
| Engine | `glm` | `glm` | `bayesglm`, `maxit = 250` |
| Weights | None | None | (see plant spec) |
| Response | Presence pooled over two seasons | Count with QPAD offset | Detection |
| Carry scale | Probability (`plogis`) | `exp(link)`, no offset | Probability |
| Draws | Fitted once, no bootstrap | 100 stored draws | 100 spatial-block draws |
| Data frame | Union of two regional files (needs a harness change) | One province file | One province file |
| Seasons | Two harness runs share one climate model | None | None |

## 6. Missing inputs

- v2's exact climate training set (2022 SpTable based). Not in the
  test dataset; 120 sites absent and 42 extra. Reachable on G: and S:
  for a scratchpad-only check.
- Nothing else. Every formula covariate is present.

## 7. Open questions

**Resolved 2026-10-14** (see
[mammals_climate_design.md](mammals_climate_design.md)):

- Q1: parity is against ABMIexploreR, and the climate stage fits on
  v2's 2022 table, added to the test dataset.
- Q2: replaced by that table.
- Q3: seasons are pooled, one model per species.
- Q6: the table was written by `north-models/archive/03 Prepare Data
  for Prediction.R:370`, from
  `all-projects_all-years_wide-density-for-habitat-modeling.csv`.
- Q7: draws are province-wide.

The questions below are kept as first written.

**Q1. Parity target.** The test dataset cannot reproduce v2's
training set. Options:

- (a) Fit on the test dataset as the shipped default. In the parity
  run, check the method separately on v2's own training set, rebuilt
  in the scratchpad from the 2022 SpTable (exact, 1e-6), and report
  the test-dataset differences with their cause. **Recommended.**
- (b) Add v2's climate training set to the published dataset. Needs a
  `_setup` change and a new dataset version, against the "_setup is
  fixed" rule.
- (c) Accept a looser tolerance on test-dataset fits only.

**Q2. Province frame for mammals.** Covariates are keyed
`mammal_north` and `mammal_south`. A province frame needs both,
de-duplicated to one row per `location_project`. North values match
v2 everywhere; south days do not at 110 sites. Proposed rule: union
the region frames and keep the first region in manifest order (north)
for shared deployments. This is a taxon-agnostic harness change.

**Q3. Seasons.** v2 fits one climate model per species; the harness
runs `mammal_summer` and `mammal_winter` separately, and a stage sees
one response column. The pooled response needs both season columns
and both day counts. Phase 2 will propose how a stage response helper
reads the paired season column (e.g. loading both columns for the
province frame), and confirm the two runs fit identical models.

**Q4. Rows without climate.** v2 drops regional rows with no climate
prediction before the habitat fit. With a fitted stage, rows with NA
climate covariates get NA `Climate`. Phase 2 will confirm these rows
are dropped and not imputed, so the habitat stage sees the rows v2
saw (on the test dataset, minus the section 2 differences).

**Q5. Species groups.** v2 fits climate for groups (`Deer`,
`Wolves, Coyotes and Allies`, `Voles, Mice and Allies`) that the
habitat stage excludes or does not model. Out of scope unless they
are in the harness species queue. `TODO: confirm with mammals lead`
whether group climate models are used downstream.

**Q6. Upstream density script.** Which script writes the 2022
combined SpTable, and why the climate stage uses it rather than the
2024 regional tables the habitat stage uses. `TODO: confirm with
mammals lead`.

**Q7. Draws.** v2 fits climate once. Following birds and plants, the
harness refits it per draw (draw 1 is the full data). Province-scope
draws (`resample$scope = "province"`) are needed so both regions share
one climate fit per draw. Draws 2 and up then differ from today's
mammal draws; draw 1 does not.

## 8. Notes for later phases

- `mammal_spec()` default changes from `"precomputed"` to `"fitted"`.
  `"precomputed"` stays for the regression check.
- The source glosses CMD as "PET - MAP, >= 0". That is inaccurate
  (`docs/framework_design.md:497-500`) but does not affect the port:
  CMD is read, not derived.
- Sections needing updates after Phase 3: `1_code/modules/README.md`
  (mammals row), `experiments/exp_000_parity_v2/README.md` (coverage
  table), `docs/taxon_quirks.md` ("Climate is external" row),
  `docs/framework_design.md` (decision 3), and `harness/README.md` if
  the province frame changes.
