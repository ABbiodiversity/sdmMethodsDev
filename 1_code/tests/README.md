# tests

Checks for any change to `harness/`, `methods/` or `modules/`. Run both
from the repository root.

| File | Does |
| --- | --- |
| `run_tests.R` | Loads the framework and runs `testthat/`. Takes seconds. Dataset checks are skipped when the published dataset cannot be reached |
| `compare_stores.R` | Compares two sets of result stores, matched on keys, to a tolerance (default 1e-10) |
| `testthat/test-dataset.R` | Manifest, species queue, covariate keys, bird grid, covariate cache, `covariate_files` joins |
| `testthat/test-methods.R` | Every engine passes `check_engine()`; registry lookups; metrics |
| `testthat/test-new_experiment.R` | Slugs, numbering and scaffolding of `new_experiment()` |
| `testthat/test-results.R` | Shard merging, seeds, spatial CV folds, baseline comparison, draw summaries |
| `testthat/test-specs.R` | Every standard spec validates; `replace_stage_method()`; hurdle; error reporting; `stage_models` |

```sh
Rscript 1_code/tests/run_tests.R
Rscript 1_code/tests/compare_stores.R <old_dir> <new_dir> [max_boot] [file,file]
```

The tests do not replace the parity check. For a change meant to leave
results alone, run the `parity_check` species at 5 draws to a scratch
folder and compare its stores with exp_000's, as in
[`docs/getting_started.md`](../../docs/getting_started.md#check-that-nothing-broke).
Draws are seeded per species and made in order, so draws 1–5 match
those of a 100-draw run.
