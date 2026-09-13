# _deprecated

Code superseded by the framework described in
[`docs/framework_design.md`](../../docs/framework_design.md). Kept for
reference during the transition, and not sourced by anything.

Delete once the taxon specs in `1_code/modules/` reproduce v2 through the
new harness.

## What is here and why

| File | Superseded by | Note |
| --- | --- | --- |
| `01_bootstrap_ids.R` | `harness/resample.R` | Plant-only bootstrap generation |
| `02_hierarchical_models.R` | `harness/engines.R`, `harness/selection.R` | Plant-only two-stage fitting |
| `03_model_validation.R` | `harness/eval_metrics.R` | Plant-only scoring |
| `load_model_data.R` | `harness/data_load.R` | Read `covariates/<taxon>_*.csv`, a layout the dataset no longer has |
| `covar_attach.R`, `data_load.R`, `data_split.R`, `eval_metrics.R` | the harness files of the same names | Placeholders that stopped rather than returning anything |
| `plants_functions/` | — | Byte-identical copies of `0_data/v2_scripts/plants/` |
| `exp_000_parity_v2/` | `1_code/experiments/exp_000_parity_v2/` | The gate rebuilt on the harness; the old version drove the deleted plants module |

Two of these are worth knowing about.

**The plants module was already broken.** `load_model_data.R` reads
`covariates/<taxon>_climate.csv` and its siblings. The harmonizer now
writes one `covariates.csv` keyed on taxon instead, so that module could
not have run against the current test dataset regardless of the rewrite.

**`plants_functions/` was pure duplication.** All three files were
byte-identical to the frozen originals in `0_data/v2_scripts/plants/`,
which are tracked and have recorded provenance. A second copy could only
drift. When the plant spec needs `climate_models()`, `vegetation_models()`
or `model_validation()` for parity, it should source the frozen originals
rather than a copy.

## plants_module/spec.R

The combined plant-group spec, superseded on 2026-09-10 when the
four plant-group taxa were split into their own modules:
`bryophytes/`, `lichens/`, `soil_mites/` and `vascular_plants/`.
Its `plant_spec(taxon)` became `plant_group_spec()` in
`1_code/modules/_shared/plant_group.R`, called by four thin taxon
files that each state only what is true of that taxon.

Kept because it is what the split was verified against: every one
of the eight taxon-by-region model frames built from
`0_data/test_dataset` is identical between the old spec and the
new ones. The spec objects themselves differ only in the
environments captured by the region-filter formulas, which the
harness discards, evaluating the right-hand side against the data
frame instead.
