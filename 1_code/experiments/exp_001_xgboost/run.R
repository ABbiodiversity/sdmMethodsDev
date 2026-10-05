# ---
# title: Run Experiment 001 - Boosted Regression Trees for Habitat
# author: Brendan Casey
# created: 2026-10-03
# inputs:
#   - 0_data/test_dataset/
#   - 3_output/exp_000_parity_v2/tables/, the v2 baseline
# outputs:
#   in 2_pipeline/exp_001_xgboost/:
#     - <run>/<region>/ result stores, and run_log.csv
#   in 3_output/exp_001_xgboost/:
#     - tables/ (summaries, and comparison_*.csv against
#       exp_000), run_record.md
# notes:
#   - A test experiment: does a boosted regression tree fit the
#     habitat stage better than v2's linear models? See README.md.
#   - One change from exp_000, made the same way for every taxon.
#     Each keeps v2's climate stage (a GLM) and carries it into the
#     habitat stage as `Climate`, as v2 does. Only the habitat
#     stage - each spec's `habitat_stage`, landcover for birds -
#     is fitted with xgboost, on every covariate v2's habitat
#     candidates use, through replace_stage_method().
#   - Mammals run too. Their habitat stage is the generic `hurdle`
#     rule, so the boosted trees fit both halves: presence on the
#     lure-scaled response, abundance given presence on a log-link
#     Gamma. v2's table-building, which reads GLM coefficients, is
#     removed with the GLMs.
#   - The settings are untuned starting points (see
#     1_code/methods/engines/xgboost.R). Read the result as "does
#     the pipeline run boosted trees and compare them", not as
#     their best.
# ---

# 1. Setup ----

## 1.1 Load the framework ----
source("1_code/harness/harness.R")
load_framework()

## 1.2 The change: fit the habitat stage with xgboost ----
# Every other stage and setting stays v2's, so a difference from
# exp_000 is the habitat method's.
xgb_settings <- list(
  nrounds = 1000,          # the most rounds; early stopping picks
  eta = 0.05,              # learning rate
  max_depth = 3,           # tree complexity
  subsample = 0.5,         # share of rows each tree sees
  min_child_weight = 1     # smallest leaf, in weighted rows
)

# One call per run: each spec names its own habitat stage
specs <- lapply(
  standard_specs(), replace_stage_method,
  engine = "xgboost", control = xgb_settings
)

## 1.3 Configure the run ----
# The same species, seed and draws as the exp_000 run it is
# compared against, so the comparison is like for like.
config <- experiment_config(
  id = "exp_001_xgboost",
  taxa = names(specs),
  species = "parity_check",
  # 5 checks the pipeline runs; 100 for a result to read
  n_bootstraps = 5,
  seed = 20260909,
  specs = specs,
  workers = 12
)

# 2. Run ----
# Fit, summarize, and compare with exp_000; every experiment is
# compared with it. The comparison is written to
# tables/comparison_*.csv.
results <- run_experiment(config)

# End of script ----
