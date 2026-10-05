# ---
# title: Run Experiment 001 - Boosted Regression Trees for Habitat
# author: Brendan Casey
# created: 2026-10-03
# inputs:
#   - 0_data/test_dataset/
#   - 3_output/exp_000_parity_v2/tables/, the v2 baseline
# outputs:
#   in 2_pipeline/exp_001_gbm/:
#     - <run>/<region>/ result stores, and run_log.csv
#   in 3_output/exp_001_gbm/:
#     - tables/ (summaries, and comparison_*.csv against
#       exp_000), run_record.md
# notes:
#   - A test experiment: does a boosted regression tree fit the
#     habitat stage better than v2's linear models? See README.md.
#   - One change from exp_000. Each taxon keeps v2's climate stage
#     (a GLM, model-averaged) and carries its prediction into the
#     habitat stage as `Climate`, as v2 does. Only the habitat
#     stage - landcover for birds - is fitted with gbm, on every
#     covariate v2's habitat candidates use, through
#     replace_stage_method().
#   - Mammals are not run: their habitat stage is v2's hurdle
#     model, two linked GLMs with custom post-processing, which
#     has no single engine to swap.
#   - The GBM settings are untuned starting points (see
#     1_code/methods/engines/gbm.R). Read the result as "does the
#     pipeline run GBM and compare it", not as GBM's best.
# ---

# 1. Setup ----

## 1.1 Load the framework ----
source("1_code/harness/harness.R")
load_framework()

## 1.2 The change: fit the habitat stage with gbm ----
# Every other stage and setting stays v2's, so a difference from
# exp_000 is the habitat method's.
gbm_settings <- list(
  n.trees = 1000,          # the most trees; out-of-bag picks fewer
  interaction.depth = 3,   # tree complexity
  shrinkage = 0.05,        # learning rate
  bag.fraction = 0.5,      # share of rows each tree sees
  n.minobsinnode = 10      # smallest leaf
)

specs <- standard_specs()

for (key in c("bryophyte", "lichen", "mite", "vascular_plant")) {
  specs[[key]] <- replace_stage_method(
    specs[[key]], "habitat", engine = "gbm", control = gbm_settings
  )
}

specs$bird <- replace_stage_method(
  specs$bird, "landcover", engine = "gbm", control = gbm_settings
)

## 1.3 Configure the run ----
# The same species, seed and draws as the exp_000 run it is
# compared against, so the comparison is like for like.
config <- experiment_config(
  id = "exp_001_gbm",
  taxa = c("bryophyte", "lichen", "mite", "vascular_plant", "bird"),
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
