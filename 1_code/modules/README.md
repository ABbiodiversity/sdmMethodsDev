# modules

One v2 spec per taxon. A module holds configuration, not modelling
code: it states what v2 does for a taxon as a spec list, and the
[harness](../harness/) runs it. A change here affects every
experiment; review it as such.

`load_framework()` sources `_shared/` first, then every other folder,
each in file-name order.

## Files

| Folder | File | Defines |
| --- | --- | --- |
| `_shared/` | `plant_group.R` | `plant_group_spec()`, the builder for the four plant-group taxa, and their v2 post-processing (`plant_age_splines()`, `plant_cutblock_convergence()`, `plant_paspen()`, `plant_footprint_pooling()`) |
| `_shared/` | `standard_specs.R` | `standard_specs(plant_bootstrap)`: every run in its v2 configuration |
| `bryophytes/` | `spec.R` | `bryophyte_spec(use_protocol, bootstrap)` |
| `lichens/` | `spec.R` | `lichen_spec(use_protocol, bootstrap)` |
| `soil_mites/` | `spec.R` | `soil_mite_spec(use_protocol, bootstrap)` |
| `vascular_plants/` | `spec.R` | `vascular_plant_spec(use_protocol, bootstrap)` |
| `mammals/` | `spec.R` | `mammal_spec(climate_source, season, tier)` |
| `mammals/` | `hurdle.R` | v2's hurdle tables: presence and abundance effects, splines, calibration, convergence |
| `birds/` | `spec.R` | `bird_spec()` |
| `birds/` | `standardize.R` | `bird_habitat_translation()`: landcover coefficients onto v2's standardized habitat types (port of v2's `08.PackageCoefficients.R`) |

`standard_specs()` returns seven runs: `bryophyte`, `lichen`, `mite`,
`vascular_plant`, `mammal_summer`, `mammal_winter` and `bird`.

## The module interface

A taxon module must:

1. Define a function `<taxon>_spec(...)` in
   `modules/<taxon_plural>/spec.R` that returns a spec list.
2. Return a spec that passes `validate_spec()`. Unknown fields are
   errors, and every named engine, rule and resampler must be
   registered.
3. Add its run to `standard_specs()` in `_shared/standard_specs.R`.

Spec fields the harness reads (full list: `spec_fields()` in
`harness/spec.R`):

| Field | Sets |
| --- | --- |
| `taxon` | Data slug that keys the response file, covariates and lookups |
| `response_name`, `response_transform`, `family`, `weight_column` | How the recorded value becomes a response; error family; weights |
| `regions` | Per region: `filter` (one-sided formula), `grid`, `habitat_models`, constants |
| `stages` | In order: `name`, `models`, `engine`, `selection`, `ic`, `post_process`, and `carry_as` for the stage carried into the next as `Climate` |
| `habitat_stage` | The stage `replace_stage_method()` replaces by default |
| `resample` | `scheme` and its settings |
| `final_prediction` | Optional. The model scored and projected |
| `v2_coverage` | Per stage, what the spec reproduces of v2. The one place coverage is stated; `report.md` prints it |
| `notes` | Configuration facts, such as whether `Protocol` is fitted |

Fields that a stage's selection rule or resampler takes as arguments
are also accepted, as settings for that method.

## Adding a taxon module

1. Put the v2 scripts as received in `0_data/v2_scripts/<source>/` and
   log the source and commit in its README.
2. Extend `_setup/01` to write the taxon's response, covariates,
   lookups, and any grid or stored draws; extend `_setup/02` to trace
   them to the source.
3. Add the taxon's species queue and manifest rows to `_setup/09`,
   and re-run it.
4. Splice the v2 candidate formulas into `harness/model_sets.R`,
   verbatim.
5. Add `spec.R`, modelled on `lichens/spec.R` (plant group),
   `birds/spec.R` or `mammals/spec.R`, and add the run to
   `standard_specs()`. If v2 does something no registered method
   covers, add one to [`methods/`](../methods/README.md).
6. Add the taxon's published v2 results to `_setup/08`, if
   ABMIexploreR publishes them.
7. Check that `validate_spec()` passes and
   `Rscript 1_code/tests/run_tests.R` runs clean. Record each
   taxon-specific behaviour in
   [`docs/taxon_quirks.md`](../../docs/taxon_quirks.md).
