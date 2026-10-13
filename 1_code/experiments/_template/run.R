# ---
# title: Run Experiment NNN - [Short Description]
# author: [Your Name]
# created: [YYYY-MM-DD]
# inputs:
#   - the published test dataset (harness/data_source.R)
#   - 3_output/exp_000_parity_v2/tables/, the v2 baseline
#   - species.csv in this folder (columns taxon, species, note)
#   - hooks/*.R in this folder, if any
# outputs:
#   in 2_pipeline/exp_NNN_short_description/:
#     - <run>/<region>/ result stores, run_log.csv and
#       session_info.txt
#   in 3_output/exp_NNN_short_description/:
#     - tables/ (summaries, and comparison_metrics.csv against the
#       baseline), run_record.md
# notes:
#   - Start an experiment with new_experiment("description")
#     (harness/new_experiment.R), which numbers it, fills this
#     header and creates its 2_pipeline/ and 3_output/ folders.
#     Copying by hand instead, set `id` and `exp_dir` below to the
#     folder's name.
#   - Edit files in this folder only. harness/, methods/ and
#     modules/ are the shared back-end; everything an experiment
#     changes is set here.
#   - State the question in the README. Change one thing relative
#     to exp_000, so a difference in the comparison is a
#     difference in that thing. species.csv lists every species
#     in the dataset: before running, delete the rows this
#     experiment does not fit, and say why in `note` if useful.
#     The rows left set both the species and the runs; nothing
#     else needs editing. For a like-for-like comparison keep
#     exp_000's species (exp_000_parity_v2/species.csv), draws
#     and seed, unless they are the question.
#   - The levers, from least to most invasive:
#     - `stage_models`: different candidate formulas for a stage
#       (new covariates, a different model set). extend_models()
#       adds terms to a set; drop_candidates() and strip_terms()
#       remove them (all in harness/model_sets.R).
#     - `covariate_files`: covariates the dataset does not hold,
#       from a CSV a script in this folder writes to
#       2_pipeline/<id>/inputs/. Never add them to 0_data/ or
#       _setup/, which stay the v2 data.
#     - A spec change (section 1.2), made here, never in modules/:
#         replace_stage_method(spec, engine = "xgboost")
#         modify_stage(spec, "habitat", min_detections = 10L)
#         modify_region(spec, "north", filter = ~ nr == "Boreal")
#         modify_resample(spec, scheme = "spatial_cv",
#                         replace = TRUE)
#       Over every run at once:
#         specs <- lapply(standard_specs(), replace_stage_method,
#                         engine = "xgboost")
#     - `regions`, `metrics`, `compare_metrics`: fit one region,
#       score or compare on chosen metrics.
#     - A method of your own (engine, selection rule, resampler,
#       metric) in hooks/, registered with register_engine(),
#       register_selection(), register_resampler() or
#       register_metric(); see 1_code/methods/_templates/ and
#       1_code/methods/README.md for each contract. Name it, then
#       use it as a built-in one. A hook may not reuse a built-in
#       name.
#   - experiment_config() checks everything (species, regions,
#     metrics, specs, covariates) and lists every problem before
#     anything is fitted.
# ---

# 1. Setup ----

## 1.1 Load the framework and this experiment's hooks ----
exp_dir <- "1_code/experiments/exp_NNN_short_description"

source("1_code/harness/harness.R")
load_framework(hooks = file.path(exp_dir, "hooks"))

## 1.2 Spec changes ----
# The v2 specs, changed where this experiment tests something.
# For example, every climate candidate with elevation added is a
# `stage_models` change (section 1.3); a habitat stage fitted with
# a different engine is a spec change here.
specs <- standard_specs()

## 1.3 Configure the run ----
config <- experiment_config(
  id = "exp_NNN_short_description",

  specs = specs,

  # This folder's species.csv, cut down to the species to fit. It
  # also sets the runs: only those that fit a listed species
  # (a Moose_Summer row runs mammal_summer), so there is no
  # `taxa` to keep in step with it.
  species = file.path(exp_dir, "species.csv"),
  n_bootstraps = 100,
  seed = 20260909,

  # The change this experiment tests. For example, every climate
  # candidate with elevation added (extend_models()), or without
  # the spatial terms (drop_candidates()):
  #   stage_models = list(
  #     climate = extend_models("climate_plant_v2_full", "elevation")
  #   ),
  #   stage_models = list(
  #     climate = drop_candidates(
  #       "climate_plant_v2_full",
  #       c("Easting", "Northing", "Easting2", "Northing2",
  #         "EastingNorthing")
  #     )
  #   ),
  stage_models = NULL,

  workers = 12
)

# 2. Run ----
# Fit, summarize, and compare with the v2 baseline (exp_000);
# every experiment is compared with it. The comparison is
# written to tables/comparison_metrics.csv. Add `steps` for anything
# this experiment needs beyond that.
results <- run_experiment(
  config,
  translate = list(bird = bird_habitat_translation)
)

# End of script ----
