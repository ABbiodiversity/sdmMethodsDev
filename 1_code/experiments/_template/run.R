# ---
# title: Run Experiment NNN - [Short Description]
# author: [Your Name]
# created: [YYYY-MM-DD]
# inputs:
#   - the published test dataset (harness/data_source.R)
#   - 3_output/exp_000_parity_v2/tables/, the v2 baseline
# outputs:
#   in 2_pipeline/exp_NNN_short_description/:
#     - <run>/<region>/ result stores, and run_log.csv
#   in 3_output/exp_NNN_short_description/:
#     - tables/ (summaries, and comparison_*.csv against the
#       baseline), run_record.md
# notes:
#   - Copy this folder to 1_code/experiments/exp_NNN_*/, set `id`
#     below to the folder's name, and state the question in the
#     README.
#   - Change one thing relative to exp_000, so a difference in the
#     comparison is a difference in that thing. Use the same
#     species, draws and seed as exp_000 unless they are the
#     question.
#   - The usual levers, from least to most invasive:
#     - `stage_models`: different candidate formulas for a stage
#       (new covariates, a different model set).
#     - `covariate_files`: covariates the dataset does not hold,
#       from a CSV this experiment's own script writes to
#       2_pipeline/<id>/inputs/. Never add them to 0_data/ or
#       _setup/, which stay the v2 data.
#     - `specs`: a spec with a stage changed - a different engine
#       or selection rule. For a new habitat method in every
#       taxon, mammals included, one call:
#         specs <- lapply(standard_specs(), replace_stage_method,
#                         engine = "xgboost")
#       See exp_001_xgboost and docs/getting_started.md.
#     - A new method in 1_code/methods/, then named in a spec;
#       see 1_code/methods/README.md.
# ---

# 1. Setup ----

## 1.1 Load the framework ----
source("1_code/harness/harness.R")
load_framework()

## 1.2 Configure the run ----
config <- experiment_config(
  id = "exp_NNN_short_description",

  # The runs to fit, from names(standard_specs())
  taxa = c(
    "bryophyte", "lichen", "mite", "vascular_plant",
    "mammal_summer", "mammal_winter", "bird"
  ),

  # The same species exp_000 ran, so the comparison is like for
  # like
  species = "parity_check",
  n_bootstraps = 100,
  seed = 20260909,

  # The change this experiment tests. For example, every climate
  # candidate with elevation added:
  #   stage_models = list(
  #     climate = extend_models("climate_plant_v2_full", "elevation")
  #   ),
  stage_models = NULL,

  workers = 12
)

# 2. Run ----
# Fit, summarize, and compare with the v2 baseline (exp_000);
# every experiment is compared with it. The comparison is
# written to tables/comparison_*.csv. Add `steps` for anything
# this experiment needs beyond that.
results <- run_experiment(
  config,
  translate = list(bird = bird_habitat_translation)
)

# End of script ----
