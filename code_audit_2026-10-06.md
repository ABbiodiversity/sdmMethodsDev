# Code audit: sdmMethodsDev, 2026-10-06

Phase 1: read-only static scan of branch `improve_code_efficiency`.
Nothing was executed: only `parse()`, token and `codetools` analysis,
and path checks. All 83 R files outside `0_data/v2_scripts/` and all
50 legacy v2 scripts were covered. ⚠ marks a file in exp_000 (the
parity gate); those are not edited without separate approval.


## Summary

- All 83 R files outside `v2_scripts/` parse cleanly.
- Every `source()` target and every `.R` path string resolves.
- `codetools` finds no function that is called but never defined,
  and no package that is used but never loaded. The remaining
  "global variable" notes are data.table column names or
  package-level environments (`.sdm_cache`, `.sdm_registry`).
- No pipes of either kind (`|>` or `%>%`) are used anywhere. This
  matches the repo's base-R/data.table, no-pipe convention, so
  nothing is flagged.
- Sequenced naming: `_setup/` runs 00–03 and 06–10. The 04/05 gap is
  deliberate history, since 08 says it replaced the old 04/05. There
  are no prefix collisions and no `MM_NN_` staging in use.
- Errors: **0 high, 1 medium, 7 low**, plus 4 informational items
  that need no change.
- Deprecated candidates: **1** (`1_code/_scratch.R`, low
  confidence). It is not eligible for deletion under the rules.

## Errors table

| # | file | line | issue | severity | proposed fix |
|---|------|------|-------|----------|--------------|
| E1 | `1_code/_setup/run.R` | 49–59 | Step defaults contradict the header (lines 21–29: "defaults rebuild everything local and publish nothing"; 00, 03 and 10 off). In the code every step is `FALSE` except `10_publish_datasets.R = TRUE`, so sourcing `run.R` publishes whatever is in `0_data/` as today's version, with no rebuild and no 02 tally. 10 refuses to overwrite an existing version, which limits the damage. | medium | Set the defaults to match the header: 01, 06, 09, 02, 07 and 08 `TRUE`; 00, 03 and 10 `FALSE`. (Alternative: only set 10 to `FALSE`. See J1.) |
| E2 | `1_code/experiments/exp_000_parity_v2/02_plot_parity.R` ⚠ exp_000 | 399 | A runtime `message()` tells the user to "rerun `02_compare_to_v2.R`", but the script is `01_compare_to_v2.R`. | low | Change the string to `01_compare_to_v2.R`. Message text only; no change to outputs. |
| E3 | `1_code/experiments/exp_000_parity_v2/v2_self_agreement.R` ⚠ exp_000 | 29 | Header comment says "Scored exactly as `02_compare_to_v2.R`"; the file is `01_`. | low | Fix the comment. |
| E4 | `1_code/_setup/01_harmonize_model_ready_v2.R` | 2384 | Comment cites `check_prediction_terms()`, which no longer exists anywhere in the repo. | low | Reword to "found later, at prediction time" without naming a function (the successor is not certain). |
| E5 | `1_code/harness/result.R` | 1–10 | The header has no `inputs:` field (template §5.1). | low | Add `# inputs: none; writes to the store directory it is given`. |
| E6 | `1_code/_setup/07_harmonize_v2_plant_bootstrap_ids.R:147`, `harness/spec.R:590`, `modules/birds/standardize.R:234`, `experiments/exp_000_parity_v2/utils/parity_targets.R:167` ⚠ exp_000 | — | Single lines over the 70-character limit. | low | Re-wrap each line. Line breaks only; no change to the code's logic. |
| E7 | `1_code/tests/testthat/test-*.R` (5 files) | 1 | No standard header and no `# End of script ----`. | low | See J5. Testthat files commonly omit headers, so this needs a decision. |
| E8 | `1_code/_scratch.R` | 30–33 | Code sits *after* `# End of script ----`. It holds a hard-coded UNC path to the old `science\sc\sdmMethodsDev\...` share and a line over 70 characters. | low | See J6 and the deprecated table. |
| I1 | `0_data/v2_scripts/mammals/north-models/archive/04 Basic Models Figures Maps.R` | 1465 | Parse error: unexpected `}`. | info | **No change** (`v2_scripts/` is off-limits). Recorded for taxon leads. |
| I2 | `1_code/harness/model_sets.R` | 154–200 (57 lines) | Lines over 70 characters. These are v2 habitat formula strings, spliced verbatim. | info | No change. Splitting them hurts the line-by-line match with v2. |
| I3 | `1_code/harness/model_sets.R` | 156 | `TreedFen + + NonTreedFen`. The doubled `+` is copied from v2 (`02a/b/c/d_hierarchical-models-*.R:102`) and is a harmless unary plus. | info | No change, to keep fidelity with v2. |
| I4 | `%||%` defined in `harness/spec.R:683`, `harness/new_experiment.R:345` (guarded), `_setup/07…:82`, `tests/compare_stores.R:166` | — | Duplicate definitions. All four are identical, and base R ≥ 4.4 also provides `%||%`. The other duplicated names (`combine`, `failed`, `table_of`, `take_block`, `rows`) are local to their functions, so they never collide. | info | No change. |

## Deprecated candidates

| file | reason | evidence it is unused | confidence |
|------|--------|-----------------------|------------|
| `1_code/_scratch.R` | `scratch` naming. Its only code is a stray 2026-09-09 `load()` of an old-share file, placed after the end marker. | No `source()` or path reference in any code. **However**, `README.md:593` documents it as the "dated workspace for exploration", and it follows the personal scratch-file convention. | **low**: documented and intentional, so do not delete. A better option is to clear the stray snippet (J6). |

Nothing else qualifies:
- Every other file is loaded by `load_framework()` (harness/,
  methods/ kind folders, modules/, experiments/_shared/), is an
  entry point (`run.R`, `run_tests.R`, `compare_stores.R`,
  `v2_self_agreement.R`, `new_experiment.R`), or is called from one.
- `methods/_templates/` and `experiments/_template/` are scaffolding
  referenced from READMEs and `new_experiment()`.
- Every file in `3_output/` has a generating script.

## Items needing human judgement

- **J1. `_setup/run.R` defaults (E1).** Should the defaults restore
  the header's stated behaviour (rebuild everything local), or just
  turn 10 off? The current state looks like a leftover from the
  2026-10-05 publish.
- **J2. Committed exp_000 summaries are from a 5-draw plumbing run.**
  `3_output/exp_000_parity_v2/run_record.md` records
  `n_bootstraps: 5` and 14 parity_check species, and every verdict
  reads "not gated (store holds 5 draws)". But `run.R:125–126` says
  to commit these only after a full run (all species, 100 draws). Is
  this a known interim state? exp_001 and exp_002 compare against
  this baseline.
- **J3. `v2_self_agreement_summary.csv` is missing.**
  `parity_targets.R` lists it as an input, and `.gitignore`
  whitelists it, but it is not in `3_output/exp_000_parity_v2/tables/`.
  - *What the script does.* v2 seeds none of its bootstraps, so two
    v2 runs of the same code on the same data give different
    coefficients. `v2_self_agreement.R` measures how far apart two
    such runs are. The first is v2's original bryophyte climate
    stage, as published in ABMIexploreR (from `_setup/08`). The
    second is `_setup/03`'s re-run of the frozen v2 functions, in
    `2_pipeline/v2_reference/`. It scores them against each other
    with the gate's own statistics, in both directions:
    - median-in-band (each run's median inside the other's
      10–90% band);
    - standardized median difference;
    - per-species band-width ratio;
    - Spearman of the medians (reported, not gated).
    It writes `v2_self_agreement.csv` (per term) and a one-row
    summary.
  - *Why it exists.* It sets the ceiling for the gate: a
    reimplementation cannot be expected to agree with v2 more
    closely than v2 agrees with itself. The results (100% in band,
    standardized difference 0.019, band ratio 0.78–1.21) are the
    stated evidence for the thresholds hard-coded in
    `parity_targets()`: 90%, 0.25, and 0.75–1.33.
  - *Is it necessary?* No experiment or test needs it at run time.
    It is not in `run.R`'s sequence, and nothing reads its CSV. It
    is the provenance for the gate's thresholds, which
    `parity_targets()` still labels "proposed, not yet agreed".
    Whoever agrees them, or later questions a pass/fail, needs that
    evidence. Keep the script.
  - *Limits.* It covers only the bryophyte climate stage; applying
    the same thresholds to the habitat and bird stages is an
    assumption. Re-running it needs `_setup/03` (hours) and the
    gitignored `2_pipeline/v2_reference/`. `_setup/07`'s `v2_ids`
    option also depends on 03.
  - *Where it runs.* By hand, from the repo root:
    `source("1_code/experiments/exp_000_parity_v2/v2_self_agreement.R")`.
    Its header says "Run once … after _setup/03 and 08. Not part of
    run.R's sequence". It is not one of `run.R`'s `script_step()`s
    (compare, plot, report).
  - *Should it join the exp_000 pipeline?* No. Its folder is right
    (it calibrates exp_000's gate), but it should not be a
    `run.R` step:
    1. It reads no harness result. Its output changes only when
       the v2 reference changes (`_setup/03` or `08`), not when
       exp_000 runs, so every run would recompute an identical
       table.
    2. Its key input, `2_pipeline/v2_reference/…Rdata`, is local
       and gitignored, and exists only on the machine that ran 03.
       Everything else in exp_000 reads the published datasets, so
       anyone can run it. As a step, this script would stop
       exp_000 for every other user.
    3. Moving it to `_setup/` breaks the rule that `_setup` is
       fixed and that experiments own their scripts.
    A cleaner long-term option, if wanted, is outside this audit.
    `_setup/10` could publish 03's re-run inside `v2_results/`, and
    the script could read it via `v2_results_dir()`. It could then
    become an optional step that anyone can run.
  - *Recommendation.* No code change. Either run it once and commit
    the summary CSV, which `.gitignore` already allows (this needs
    your go-ahead, because it reads data and writes outputs), or
    accept that the numbers recorded in `parity_targets.R:38–47`
    are the record and drop the CSV from that header's `inputs:`.
  - *Confidence: High* on what it does. *Moderate* on "necessary":
    that depends on whether the team treats the thresholds as
    settled.
- **J4. Absolute local path in a committed file.**
  `run_record.md` records `pipeline_dir:
  D:/local_projects/active/...`. It sits in the "volatile" section,
  so it is harmless, but the path is machine-specific.
- **J5. Test-file conventions (E7 and naming).** `test-*.R` uses a
  hyphen, which is the testthat convention. `test_*.R` also works,
  but renaming has little value. Should the 5 test files get
  standard headers?
- **J6. `_scratch.R` (E8).** Empty the 2026-09-09 snippet (keeping
  the header), leave it as is, or delete the file (it is documented
  in the README)?
- **J7. Out-of-scope leftovers I will not touch.**
  - `2_pipeline/exp_001_gbm/` is an orphan store from a renamed
    experiment.
  - `0_data/test_dataset_backup_2026-10-02_aug2026_birds/` is a
    backup dataset folder.
  - `3_output/exp_001_xgboost/` and `exp_002_soilgrids/` are empty
    folders.
  - None of these is tracked by git; you may want to clear them by
    hand.
- **J8. "the project file sets it"** (`exp_000/run.R:34`). No
  `.Rproj` is tracked in the repo. This is a documentation and setup
  question for the separate docs prompt.

## Appendix A: repository map

The table lists each file with its purpose, from its header title,
and its main reads and writes. Key reads: TD is the published test
dataset via `data_source.R`; V2R is the published v2 results; SI is
the `setup_inputs` mirror via `_setup/utils/input_paths.R`.

| file | purpose | reads → writes |
|------|---------|----------------|
| `_setup/run.R` | Entry point: runs the _setup steps in isolated environments | _setup scripts → `2_pipeline/_setup/run_log.csv` |
| `_setup/00_mirror_setup_inputs.R` | Mirror the original inputs (old shares, G: drives) onto ABMI-DATA2 | originals → SI |
| `_setup/01_harmonize_model_ready_v2.R` | v2 snapshot → harmonized CSVs | SI → `0_data/test_dataset/` |
| `_setup/02_validate_test_dataset.R` | Pass/fail tally of the dataset | `0_data/test_dataset/`, SI → console |
| `_setup/03_rerun_bryophyte_v2_reference.R` | Re-run the v2 bryophyte models (sources `v2_scripts/plants/*functions.R`) | SI → `2_pipeline/v2_reference/` |
| `_setup/06_…bird_translation_lookup.R` | Bird coefficient translation lookup | SI → `test_dataset/lookup/` |
| `_setup/07_…plant_bootstrap_ids.R` | v2's stored plant bootstrap ids | SI, v2_reference → `lookup/v2_bootstrap_ids/` |
| `_setup/08_…abmiexplorer_results.R` | ABMIexploreR coefficients at a pinned commit | GitHub → `0_data/v2_results/abmiexplorer/` |
| `_setup/09_harmonize_lookups.R` | Cross-taxa lookups | 01/06 outputs → `lookup/` |
| `_setup/10_publish_datasets.R` | Publish a versioned copy with checksums | `0_data/` → ABMI-DATA2 |
| `_setup/utils/input_paths.R` | `setup_input()` resolver | — |
| `harness/harness.R` | `load_framework()`: sources harness, then methods, then modules, then experiments/_shared | all of those |
| `harness/{registry,cache,data_source,spec,data_load,covariate_sets,species,model_sets,resample,engines,selection,eval_metrics,predict_grid,result,run_record,run_model,summarise,compare,experiment,new_experiment}.R` | Taxon-agnostic pipeline (loaded in this order) | TD/V2R → `2_pipeline/<exp>/`, `3_output/<exp>/` |
| `methods/engines/{_glm_family,glm,bayesglm,xgboost}.R` | Engine plug-ins | — |
| `methods/selection/{aic_average,aic_best,hurdle,ivw_grid,single,staged_bic}.R` | Selection plug-ins | — |
| `methods/resampling/{precomputed,spatial_block,spatial_cv}.R` | Resampling plug-ins (precomputed reads `lookup/v2_bootstrap_ids/`) | TD |
| `methods/metrics/{auc,calibration_slope,deviance_explained,n,prevalence,rmse,spearman}.R` | Metric plug-ins | — |
| `methods/_templates/*.R` | Skeletons; not loaded | — |
| `modules/_shared/{plant_group,standard_specs}.R` | Plant-group spec builder; the v2 spec list | — |
| `modules/<taxon>/spec.R` (+ `birds/standardize.R`, `mammals/hurdle.R`) | Per-taxon v2 specs and helpers | TD lookups |
| `experiments/_shared/focal_species.R` | Named focal-species sets | — |
| `experiments/_template/run.R` | Scaffold copied by `new_experiment()` | — |
| `experiments/exp_000_parity_v2/run.R` | Entry: parity gate; runs 01–03 as `script_step`s | TD, V2R → `2_pipeline/exp_000…`, `3_output/exp_000…` |
| `exp_000/01_compare_to_v2.R` | Coefficient parity vs v2 | stores, V2R → `parity_summary.csv`, `parity_terms.csv`, `coefficient_summary.csv` |
| `exp_000/02_plot_parity.R` | Parity figures | tables → `figures/*.png` |
| `exp_000/03_build_report.R` | `report.md` | tables → `report.md` |
| `exp_000/utils/parity_targets.R` | Gate thresholds | — |
| `exp_000/v2_self_agreement.R` | Stand-alone: v2 vs v2 calibration | `2_pipeline/v2_reference/`, V2R → `v2_self_agreement*.csv` |
| `experiments/exp_001_xgboost/run.R` | Entry: xgboost habitat stage | TD → `2_pipeline/exp_001_xgboost/`, `3_output/…` |
| `experiments/exp_002_soilgrids/run.R` | Entry: soil terms in the climate stage; sources 01 if the input is missing | soil CSV, TD → stores and outputs |
| `exp_002/01_extract_soilgrids_covariates.R` | sciSpatialR/sf extraction | TD sites, SoilGrids → `2_pipeline/exp_002…/inputs/soilgrids_0_5cm.csv` |
| `tests/run_tests.R` | Entry: testthat over `tests/testthat/` | TD (skipped if unreachable) |
| `tests/testthat/test-{dataset,methods,new_experiment,results,specs}.R` | Contract tests | TD |
| `tests/compare_stores.R` | Stand-alone/CLI: compare two store trees | `2_pipeline` stores |
| `_scratch.R` | Personal scratch | old-share `.Rdata` |

## Appendix B: dependency map

- **Entry points**:
  - `_setup/run.R`
  - each `experiments/*/run.R`
  - `tests/run_tests.R`
  - `tests/compare_stores.R` (CLI)
  - `exp_000/v2_self_agreement.R`
  - `harness/new_experiment.R` (also stand-alone)
  - `_scratch.R`
- **Sourced by `load_framework()`**: all of `harness/`, the
  `methods/{engines,selection,resampling,metrics}/` folders (files
  starting with `_` first), `modules/*/` (`_shared` first), and
  `experiments/_shared/`.
- **Also re-sourced**: parallel workers source it again via
  `run_model.R:555` (`load_worker`). exp_000's 01–03 run through
  `experiment.R:556` (`sys.source`).
- **Other `source()` edges**:
  - `_setup/{01,02,03,06,07,08}` → `_setup/utils/input_paths.R`
  - `00` → `input_paths.R` (via `helper`)
  - `10` → `harness/data_source.R` (via `resolver`)
  - `03` → `0_data/v2_scripts/plants/{hierarchical-model_functions,bootstrapping_functions}.R`
  - `v2_self_agreement.R` → `parity_targets.R` and `data_source.R`
  - `exp_002/run.R` → `exp_002/01_…R`
  - `exp_002/01` → `data_source.R`
- **Packages**:
  - Attached with `library()`: data.table, ggplot2 (exp_000/02),
    testthat, foreach and parallel (03), sciSpatialR and sf
    (exp_002/01).
  - Attached on cluster workers in 03 only: AICcmodavg, arm, binom,
    mapproj, mgcv, MuMIn, pROC, RcmdrMisc.
  - Called with `::` and guarded by `requireNamespace()`: arm,
    xgboost, MuMIn, mgcv, pROC, jsonlite, terra, withr, stats,
    utils, tools, parallel.
  - All the `::` packages are installed on this machine.

