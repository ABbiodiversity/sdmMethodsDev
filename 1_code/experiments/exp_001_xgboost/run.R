# ---
# title: Run Experiment 001 - Boosted Regression Trees for Habitat
# author: Brendan Casey
# created: 2026-10-03
# inputs:
#   - the published test dataset (harness/data_source.R)
#   - 3_output/exp_000_parity_v2/tables/, the v2 baseline
# outputs:
#   in 2_pipeline/exp_001_xgboost/:
#     - <run>/<region>/ result stores, and run_log.csv
#   in 3_output/exp_001_xgboost/:
#     - tables/ (summaries, and comparison_metrics.csv against
#       exp_000), run_record.md
# notes:
#   - Does xgboost fit the habitat stage better than v2's GLMs?
#     See README.md. Only each spec's `habitat_stage` changes
#     (via replace_stage_method()); v2's climate stage is kept
#     and carried as `Climate`. For mammals, xgboost fits both
#     hurdle halves.
#   - Settings are untuned (see methods/engines/xgboost.R): this
#     tests the pipeline, not the method's best.
# ---

# 1. Setup ----

## 1.1 Load the framework ----
source("1_code/harness/harness.R")
load_framework()

## 1.2 The change: fit the habitat stage with xgboost ----
xgb_settings <- list(
  nrounds = 1000, # the most rounds; early stopping picks
  eta = 0.05, # learning rate
  max_depth = 3, # tree complexity
  subsample = 0.5, # share of rows each tree sees
  min_child_weight = 1 # smallest leaf, in weighted rows
)

# One call per run: each spec names its own habitat stage
specs <- lapply(
  standard_specs(),
  replace_stage_method,
  engine = "xgboost",
  control = xgb_settings
)

## 1.3 Configure the run ----
# Same species and seed as exp_000
config <- experiment_config(
  id = "exp_001_xgboost",
  taxa = names(specs),
  species = "parity_check",
  # 5 checks the pipeline runs; 100 for a result to read
  n_bootstraps = 100,
  seed = 20260909,
  specs = specs,
  workers = 12
)

# 2. Run ----
# Fit, summarize, and compare with exp_000
results <- run_experiment(config)

# End of script ----
