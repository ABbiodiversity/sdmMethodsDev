# Mammal climate stage: design

Phase 2 of porting the v2.0 mammal climate stage. It builds on
[mammals_climate_inventory.md](mammals_climate_inventory.md). This is
a proposal only; no code or data has changed.

Revised 2026-10-14: the climate stage fits on v2's own training data
(the 2022 combined SpTable), added to the test dataset as
province-wide mammal rows (option 1). This replaces the earlier plan
to merge the two regional files.

**Status, 2026-10-14:**

- Implemented and verified on a local rebuild of the dataset (see
  7.3 and the session summary).
- Not yet published: the new dataset version and the pin move in
  `harness/data_source.R` wait for approval. Until then the default
  mammal spec cannot run on the pinned `2026-10-05` dataset, which
  has no province rows.

## 1. Decisions taken

| # | Question | Decision |
| --- | --- | --- |
| D1 | Parity target | ABMIexploreR's published outputs (`0_data/v2_results/abmiexplorer/v2_results.csv`) |
| D2 | Climate training data | v2's own: `R Dataset SpTable for ABMI North and South mammal coefficients 2022.RData`, added to the test dataset by `_setup` (section 3) |
| D3 | Seasons | As the original code: one climate model per species, seasons pooled |
| D4 | Draws and staging | As birds and plants: a province-wide climate stage, refitted on each province-wide draw, carried as `Climate` into the regional habitat stage |

`mammal_spec()` defaults to `climate_source = "fitted"`, so
`standard_specs()` and `exp_000_parity_v2` use it with no config edit.
`"precomputed"` stays available for regression checks.

## 2. Shape

```text
province frame: v2's 2022 table, one row per deployment
  └─ province draw (spatial blocks, draw 1 = all data)
       └─ climate stage: 9 binomial GLMs on pooled presence,
          AICc full average, unweighted
            └─ carry plogis(link) as `Climate`
                 ├─ north habitat hurdle (draw mapped to north units)
                 └─ south habitat hurdle (draw mapped to south units)
```

This is the bird and plant shape. Three things differ, each because of
how the mammal data are laid out:

- the climate data are a separate table from the habitat data;
- the response pools two seasons;
- v2 drops habitat rows with no climate prediction.

## 3. The data: v2's climate table in the test dataset

### 3.1 Why this file

The climate stage reads this file (`climate/01_prepare-data.R:50-55`),
and it holds all 4,927 deployments v2 predicted for. The 2024 regional
files the test dataset is built from lack 120 of them: 107 Grassland
and 13 Boreal sites, dropped by regional habitat filters the climate
stage never applied. The file sits at
`G:/Shared drives/ABMI Mammals/Results/Density/`, dated 2024-10-09.

It was written by `north-models/archive/03 Prepare Data for
Prediction.R:370`. That script blanks *summer* densities when
`WinterDays < 10`, a bug the 2026 regional scripts fixed. v2's climate
fit includes the bug, and so will the port, through the data.

### 3.2 What `_setup` adds

The new rows sit under a new covariate key, `mammal_province`, beside
`mammal_north` and `mammal_south`. Existing rows and files do not
change.

| File | Adds | From |
| --- | --- | --- |
| `mammal.csv` | 5,435 rows, `survey_unit_id` = `mammal_province\|<location_project>`. The 4 duplicated deployments get the suffix convention `_setup/01` already uses for regional duplicates | The 2022 table's 78 species-season density columns, renamed to harness names through `species_queue.csv` `source_name`. Species with no `mammal.csv` column are left out; columns with no 2022 species are NA |
| `sites.csv` | The same 5,435 units: `location`, `project`, `lured`, `summer_days`, `winter_days`, `lat`, `long`, `nr`, `nsr`, `luf`, `in_mammal = TRUE`, `region = "province"` | `location`, `project`, `Lured`, `SummerDays`, `WinterDays`, `Lat`, `Long`, `NR`, `NSR`, `LUF` |
| `covariates.csv` | The same units, key `mammal_province`: `location_project`, `FFP`, `MAP`, `TD`, `CMD`, `EMT`, `WetlandMargin`, `Water`; other columns NA | Climate from `abmi-camera-climate_2023.Rdata`, joined **as `01_prepare-data.R:81-106` does**: strip `_YYYY`, then `CMU-` and `NWSAR-`, one row per `location`, left join on `location`. `WetlandMargin` and `Water` from the 2022 table (the region filters read them) |
| `lookup/covariate_columns.csv` | Rows for `mammal_province` | `_setup/01` |
| `lookup/dataset_manifest.csv` | `mammal,province,mammal.csv,,mammal_province,,,` | `_setup/07` |

The table keeps raw densities and days. Pooling to presence is model
logic, so it stays in the module (3.4 and 4.2), where an experiment
can change it.

### 3.3 `_setup` changes

| Script | Change |
| --- | --- |
| `00_mirror_setup_inputs.R` | Add the 2022 table to the `abmi_mammals` paths, so it is mirrored to ABMI-DATA2 |
| `01_harmonize_model_ready_v2.R` | New section: read the 2022 table and the camera climate, write the province rows (3.2). Reuses `read_camera_climate()`, which already applies v2's join (year suffix, then `CMU-` and `NWSAR-` stripped, one row per location) |
| `02_validate_test_dataset.R` | Trace province rows back to the 2022 table and camera file. Check that the deployments with a non-NA pooled Moose response equal `mammal_climate_predictions.csv`'s 4,927 |
| `07_harmonize_lookups.R` | The manifest row |
| `08_publish_datasets.R` | No change; run it to publish a new version |
| `harness/data_source.R` | Move the `test_dataset` pin to the new version (one line), after the checks in 7.3 pass |

**Before publishing**, regenerate locally and compare with the
published `2026-10-05` copy. Every file except the four above must be
byte-identical, and in those four every existing row must be
unchanged. This guards against re-harmonizing other taxa from drifted
sources (see the bird data-version memory). Runs read the local copy
through `SDM_TEST_DATASET` until the new version is published.

## 4. Where logic lives

### 4.1 Harness (taxon-agnostic), three changes

Each is off unless the manifest or a spec sets the new item. Bird and
plant data and specs set none, so their code paths are unchanged.

**H1. A province frame from the manifest.**

- *Why:* `province_context()` (`harness/run_model.R:398`) builds the
  frame with `region = NULL`, which reads covariate key `mammal`, and
  that has no rows. The climate table is a separate province dataset.
- *What:* if the taxon's manifest has a `province` row,
  `province_context()` builds with `region = "province"`. Otherwise it
  keeps `region = NULL`, as birds and plants do today. The
  configuration check (`check_spec_covariates()`,
  `harness/spec.R:447-459`) checks province covariates the same way.
  Any code that lists a taxon's regions from the manifest must skip
  `province`; the implementation will search for such uses.

**H2. Province draws mapped to regions by key.** New spec field
`province_key = "location_project"`.

- *Why:* bird and plant regions share `survey_unit_id`s with the
  province frame, so a draw is filtered per region by id
  (`run_model.R:1009-1010`). Mammal province and regional units have
  different ids for the same deployment.
- *What:* when `province_key` is set, `fit_species()`
  (`run_model.R:610`) builds a lookup from each region unit to one
  province unit: the first with the same key. Each drawn province unit
  expands to the region units that map to it, keeping repeats.
  - At draw 1 every mapped region unit appears exactly once, so the
    regional frames at draw 1 equal today's, less units with no
    province row.
  - Units with no province row are never drawn. These are the 42
    test-dataset deployments missing from v2's table. Dropping them is
    v2's `inner_join` on `location_project`.

**H3. Paired response columns.** New spec field
`response_companions = function(species)`, returning a named vector
of other response columns the province frame should carry.

- *Why:* the pooled response needs both seasons, but a frame holds
  one species column (`model_frame()`, `harness/data_load.R:802`).
- *What:* `province_context()` also loads the companion columns.
  `model_frame()` gets an optional `companions` argument and attaches
  each as `response_<name>`, e.g. `response_summer`. Only the
  province frame uses it.

**Found during implementation** (also taxon-agnostic; no effect
on birds or plants, whose specs leave `weight_column` NULL and set
no `province_key`):

- `province_request()` no longer asks for the spec's
  `weight_column`. Province frames are built unweighted, and the
  mammal climate rows have no `wt_summer`.
- `fit_species()` fits province stages on the province draw, not on
  the region's mapped copy (part of H2; the two are the same object
  when no key is set).
- `check_spec_covariates()` says plainly when a spec needs a
  province table that the dataset lacks.

**Not changed:**

- selection (`aic_average` already does MuMIn's full average);
- the glm engine (its AICc and `na.omit` match MuMIn and `glm`);
- `carry_values()`. Regional climate covariates equal the province
  values at every deployment with a v2 prediction (checked: no
  regional row with a v2 prediction lacks climate, and matched values
  differ by 0). So computing `Climate` on regional rows gives v2's
  joined prediction.
- the result store and the comparison scripts.

### 4.2 Mammal module (`1_code/modules/mammals/`)

New file `climate.R`, a port of `01_prepare-data.R` and the regional
join:

| Function | Ports | Does |
| --- | --- | --- |
| `mammal_season_pair(species)` | `01:128-152` | `Moose_Summer` gives `c(summer = "Moose_Summer", winter = "Moose_Winter")`. The spec's `response_companions` |
| `mammal_pooled_density(summer, winter, summer_days, winter_days)` | `01:156-166` | Base `weighted.mean(c(s, w), c(sd, wd))` per unit. Base R drops zero-day seasons; data.table's version does not, and would lose 97 of v2's Moose sites |
| `mammal_climate_response(values, frame)` | `01:156-175` | The climate stage's `response_transform`. Pools seasons per `location_project` across distinct units (v2's `group_by`, which merges the 4 duplicated deployments). Presence = pooled > 0, on the first unit's rows; NA on other units sharing that deployment, and where pooled density or `FFP` is NA. Bootstrap repeats are kept. `glm`'s `na.omit` drops the NA rows, giving v2's 4,927 rows at draw 1 |
| `mammal_climate_available(frame, species, data_dir, spec)` | north `03:359-362`, south `03:329-332` | The spec's `species_frame` when fitted. Keeps regional rows whose `location_project` has a non-NA pooled response in the province data, as v2's `inner_join` + `filter(!is.na(Climate))` does. Recomputes the response, since lure correction and scaling depend on the rows kept, as `mammal_precomputed_climate()` does |

`spec.R` changes:

- `climate_source = c("fitted", "precomputed")`: fitted is the
  default.
- The climate stage becomes:

  ```r
  list(
    name = "climate",
    models = "climate_bird_mammal_v2",
    engine = "glm",
    selection = "aic_average",
    ic = "AICc",
    scope = "province",
    weighted = FALSE,
    response_transform = mammal_climate_response,
    carry_as = "Climate"
  )
  ```

  `family` stays the spec's `"binomial"`. `carry_scale` stays
  `"response"` (`plogis`), matching v2's 0-1 site predictions.
- New fields when fitted: `province_key = "location_project"`,
  `response_companions = mammal_season_pair`,
  `species_frame = mammal_climate_available`, and
  `resample$scope = "province"`.
- The habitat stage is unchanged: `carry_from = "climate"`, Climate in
  presence only, `abundance_drop = "Climate"`.
- `v2_coverage$climate` becomes "reproduced"; `v2_coverage$resampling`
  notes province draws; `notes` is updated.

`hurdle.R` keeps `mammal_precomputed_climate()` for the non-default
path.

### 4.3 Not changed

The bird and plant modules, the `exp_000_parity_v2` config, READMEs,
and vignettes.

## 5. Interface

### 5.1 New spec fields (validated in `harness/spec.R`)

| Field | Type | Default | Used by |
| --- | --- | --- | --- |
| `province_key` | character, a column in both province and region frames | absent: today's behaviour | H2 |
| `response_companions` | `function(species)` returning a named character vector | absent | H3 |

H1 is driven by the manifest, not a spec field.

### 5.2 Module functions

| Function | Arguments | Returns |
| --- | --- | --- |
| `mammal_season_pair` | `species` | Named character, `summer`, `winter` |
| `mammal_pooled_density` | four numeric vectors | Numeric; NA as base `weighted.mean` gives |
| `mammal_climate_response` | `values`, `frame` | Integer 0/1 with NA, one per row |
| `mammal_climate_available` | `frame`, `species`, `data_dir`, `spec` | The frame, rows kept, response recomputed |

These follow the existing `response_transform` and `species_frame`
signatures (`harness/data_load.R:935-957`, `run_model.R:662-664`).

## 6. Config (what an experiment can change)

| Setting | v2 default | Changed with |
| --- | --- | --- |
| Candidate set | `climate_bird_mammal_v2` (9) | `stage_models = list("mammal.climate" = …)`, `extend_models()`, `drop_candidates()` |
| Engine, selection, `ic` | `glm`, `aic_average`, `AICc` | `modify_stage(spec, "climate", …)`, `replace_stage_method()` |
| Weighting | unweighted | `modify_stage(spec, "climate", weighted = TRUE)` |
| Climate covariates | FFP, MAP, CMD, TD | The candidate set; `covariate_files` (keyed on `survey_unit_id`, so province ids) for new ones |
| Species | every mammal | `species.csv` |
| Draws | spatial block, province scope, 20 detections | `modify_resample()` |
| Source of `Climate` | fitted | `mammal_spec(climate_source = "precomputed")` |

Fixed in the module: the pooled-season response and dropping
deployments with no climate response. These define v2's data, not the
model.

## 7. Hand-off, outputs, and parity

### 7.1 Hand-off and outputs

- **Hand-off:** `carry_values()` applies the averaged coefficients to
  the regional `fitting` and `frame` rows, then `plogis`. The result
  is the `Climate` column for the hurdle (`run_model.R:1027-1051`).
- **Stores:** `2_pipeline/<id>/<run>/<region>/coefficients.csv` gets
  stage `climate` rows (Intercept, FFP, MAP, CMD, TD; full average,
  absent terms 0).
  - They are written in both regions and both season runs, identical
    at draw 1.
  - `01_compare_to_v2.R` already maps them to region `all`, part
    `presence`, and averages seasons.
- **Not produced:** v2's per-species climate AUC and 1 km map
  (spatial prediction is deferred).

### 7.2 Seasons and draws

At draw 1, summer and winter runs fit the same model: same rows, same
response. Later draws differ, because each season run seeds its own
species name (`species_seed()`). v2 has no climate bootstrap, so
nothing to match. Sharing draws would need a seeding change; I propose
not making it. **Confidence: Moderate.** This is a choice, not a v2
fact.

### 7.3 Parity plan

All at draw 1, against ABMIexploreR, with the existing mammal
numerical rule (every term within 1e-6,
`exp_000_parity_v2/README.md:105`):

- (a) climate coefficients (Intercept, FFP, MAP, CMD, TD), Moose and
  Coyote;
- (b) habitat presence, abundance, and total tables, north and south,
  seasons averaged, same species.

Internal checks:

- (c) summer and winter runs give identical climate coefficients;
- (d) regional rows kept equal the `"precomputed"` path's rows;
- (e) carried `Climate` against `lookup/mammal_climate_predictions.csv`,
  within 1e-6 on every kept regional row;
- (f) the province rows give 4,927 deployments with a non-NA pooled
  response for Moose and Coyote.

**Result (2026-10-14, local rebuild):** pass.

- (a) Climate, 10 of 10 terms; max difference 7.0e-14.
- (b) Habitat, north 436 of 436 reachable terms (9.8e-15), south
  120 of 120 (5.3e-15). The precomputed path gives the same.
- (c) Identical (difference 0).
- (d) Identical rows in all four run and region pairs; habitat
  coefficients within 1e-14.
- (e) Within 5.2e-15 on every deployment with a v2 prediction.
- (f) 39 of 39 species (`_setup/02`).

**Expected result (before the run):** pass on (a) and (b).

- With v2's training data, rows, response, and model all match, so
  (a) should agree to numerical precision.
- If (a) and (e) pass, the habitat stage sees v2's rows and v2's
  `Climate`, so (b) should stay within 1e-6. It matches to 1e-15
  under `"precomputed"` today.

**Confidence: Moderate.** Residual risks:

- `aic_average` against `MuMIn::model.avg` at 1e-6. The weights and
  AICc are the same formulas, but untested at this tolerance for
  mammals.
- `glm` convergence differences across R versions.
- The precision of v2's prediction CSV.

The report gives, per term: v2 value, harness value, absolute and
relative difference, pass or fail, and the cause of any failure.

### 7.4 Runs

| Run | What | Notes |
| --- | --- | --- |
| Data | `_setup/00` (mirror the file), `01`, `07`, `02` locally; compare with published `2026-10-05` (3.3) | Writes `0_data/test_dataset/` locally. Nothing published yet |
| Parity | Scratchpad driver, `run_experiment()` with its own `id` and pipeline and output directories in the scratchpad. `taxa = c("mammal_summer", "mammal_winter")`, Moose and Coyote, `n_bootstraps = 1`, `baseline = NULL`, `SDM_TEST_DATASET` = local copy | Nothing written to `2_pipeline/exp_000_parity_v2/` |
| Draw plumbing | Same, `n_bootstraps = 3`, Moose summer | Province draws reach both regions. Not scored |
| Regression | Five seeded draws of `mammal_spec(climate_source = "precomputed")`, before and after, compared with `1_code/tests/compare_stores.R` | Expected identical; province rows are never read by regional frames |
| Birds and plants | `validate_spec()` on every `standard_specs()` entry; `Rscript 1_code/tests/run_tests.R`; parse checks | A five-draw bird and plant run only with your approval |
| Tests | `1_code/tests/testthat/`: H1 (manifest province row read), H2 (draw 1 maps each region unit once; repeats kept; unmatched units dropped), H3 (companions attached), `mammal_pooled_density()` against base `weighted.mean` | |
| Publish | `_setup/08`, then move the pin in `data_source.R` | **Only after you approve the results.** A published version cannot be overwritten |

## 8. Consequences to accept

1. A new published test dataset version. Earlier runs stay
   reproducible on the old pin.
2. Mammal draws 2 and up change (province blocks instead of regional
   blocks). Draw 1 does not.
3. `exp_000_parity_v2`'s committed `report.md` and `run_record.md` are
   stale for mammals until a full rerun.
4. Mammal runs fit nine extra small GLMs per species and draw.
5. v2's winter-days bug stays in the climate fit, deliberately, for
   parity.

## 9. Suggested improvements (not in scope)

- Rebuild the climate table from the current density data with the
  bug fixed, as an experiment.
- Score the climate stage's own AUC, as v2's `All Species Climate
  AUC.csv` does.
- Share province draws across the two season runs (7.2).
- The 1 km climate prediction with v2's 99th-percentile cap
  (`make-species-predictions.R:485-505`), once spatial prediction is
  in scope.

## 10. Files that will change

| File | Change |
| --- | --- |
| `1_code/_setup/00_mirror_setup_inputs.R` | Mirror the 2022 table |
| `1_code/_setup/01_harmonize_model_ready_v2.R` | Province rows (3.2) |
| `1_code/_setup/02_validate_test_dataset.R` | Province-row checks |
| `1_code/_setup/07_harmonize_lookups.R` | Manifest row; grid check skips a row with no grid |
| `1_code/harness/run_model.R` | H1 in `province_context()`, H2 in `fit_species()`, H3 loading |
| `1_code/harness/data_load.R` | `model_frame()` companions |
| `1_code/harness/spec.R` | `spec_fields()`, `validate_spec()`; `check_spec_covariates()` province check |
| `1_code/harness/data_source.R` | Pin bump, after publishing |
| `1_code/modules/mammals/climate.R` | New (4.2) |
| `1_code/modules/mammals/spec.R` | Default, climate stage, new fields, coverage text |
| `1_code/tests/testthat/` | Tests in 7.4 |

READMEs and docs to update afterwards:

- `1_code/_setup/README.md`: new input, province rows;
- `1_code/modules/README.md`: mammals rows, `climate.R`;
- `1_code/harness/README.md`: `province_key`, `response_companions`,
  the manifest `province` row;
- `exp_000_parity_v2/README.md`: coverage table and parity status;
- `docs/taxon_quirks.md`: "Climate is external" and the winter-days
  bug;
- `docs/framework_design.md`: decision 3.

## 11. Open items for the mammals lead

- `TODO: confirm with mammals lead`: whether the climate stage should
  keep reading the 2022 table, now that the regional scripts no
  longer write a combined file, and whether the winter-days bug is
  known.
- `TODO: confirm with mammals lead`: whether v2's climate models for
  species groups (`Deer`, `Wolves, Coyotes and Allies`, `Voles, Mice
  and Allies`) are used downstream.
- `TODO: confirm with mammals lead`: package versions of the v2
  climate run (MuMIn 1.48.11 here).
- `TODO: confirm with mammals lead`: the south density CSV named in
  `south-models/02_process-data-files.R`
  (`Results/Density/Deployments/Archive/abmi-cmu-bg-nwsar_all-years_density_wide_2022-01-13.csv`)
  is no longer on G:.
