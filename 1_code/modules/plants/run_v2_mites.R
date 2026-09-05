# ---
# title: Run v2 Soil Mite Modelling Pipeline
# author: Brendan Casey
# created: 2026-09-05
# inputs:
#   scripts, in 0_data/v2_scripts/plants/:
#     - 02c_hierarchical-models-mites.R
#     - 03c_model-validation-mites.R
#   data and functions, in v2_root:
#     - 0_data/species/processed/mite-model-data.Rdata
#     - 0_data/bootstrap/mite-bootstrap-ids.Rdata
#     - 0_data/lookup/prediction-matrix/ (veg and soil, 2024)
#     - 1_code/r-scripts/hierarchical-model_functions.R
#     - 1_code/r-scripts/model-validation_functions.R
# outputs:
#   in v2_root:
#     - 3_output/models/mite-species-models.Rdata
#     - 3_output/validation/mite-models-validation.Rdata
#   in this repository:
#     - 2_pipeline/plants/logs/<timestamp>_<label>.log
# notes:
#   - Sources the unmodified v2 scripts behind a run_* flag, so
#     either stage can be re-run without editing the v2 code.
#   - Helpers come from 1_code/harness/utils/v2_script_runner.R,
#     which handles the v2 scripts' working directory and their
#     rm(list = ls()).
#   - v2_root is an external copy of the v2 species models
#     project; it holds the data and receives the outputs.
#   - The mite scripts arrived in the plants folder, so this
#     runner sits with them rather than in its own module.
#   - The v2 scripts hard-code 14 cores and 100 bootstraps and
#     register no foreach backend, so %dopar% runs sequentially.
#   - Future improvement - stage the v2 layout under 2_pipeline/
#     so a run needs only this repository and the test dataset.
# ---

# 1. Setup ----

## 1.1 Set the working directory ----
# Every path below is relative to this repository's root. In
# RStudio or Positron, uncomment to set it from this script's
# location.
# setwd(dirname(rstudioapi::getActiveDocumentContext()$path))
# setwd("../../..")

## 1.2 Configure paths ----
# Values a calling experiment has already set are kept, so this
# script runs either from 1_code/experiments/ or on its own.
# `v2_root` is the staged run root the experiment builds, or an
# external v2 project copy when running standalone. Paths are
# absolute, because run_step() changes the working directory
# while a step runs.
project_root <- normalizePath(getwd(), winslash = "/")

v2_code_dir <- file.path(project_root, "0_data/v2_scripts/plants")

if (!exists("log_path", inherits = FALSE)) {
  log_path <- file.path(project_root, "2_pipeline/plants/logs")
}

# Set SDM_V2_ROOT in .Renviron, or assign the path here.
if (!exists("v2_root", inherits = FALSE)) {
  v2_root <- Sys.getenv("SDM_V2_ROOT", unset = NA_character_)
  # v2_root <- "D:/path/to/species-models-v2"
}

## 1.3 Load the shared step runner ----
# Supplies resolve_v2_root(), check_inputs(),
# create_v2_output_dirs(), check_function_files(), and run_step().
source(file.path(
  project_root, "1_code/harness/utils/v2_script_runner.R"
))

## 1.4 Set run flags for each step ----
# Set to TRUE to run the corresponding script. Toggling a flag
# re-runs one stage without commenting out code, which keeps the
# pipeline's full sequence visible in version control. An
# experiment can set either flag before sourcing this script.
if (!exists("run_02c", inherits = FALSE)) {
  run_02c <- TRUE # 02c_hierarchical-models-mites.R
}
if (!exists("run_03c", inherits = FALSE)) {
  run_03c <- TRUE # 03c_model-validation-mites.R
}

## 1.5 Record what must survive rm(list = ls()) ----
# The v2 scripts clear the global environment as their first act.
# run_step() restores these objects afterwards, so the flags and
# helpers are still here for the next step. Taking the names with
# ls() means nothing has to be listed by hand.
runner_objects <- c(ls(), "runner_objects", "pipeline_start")

# 2. Prepare and validate the run environment ----
# The v2 scripts assume their inputs are in place and their output
# folders already exist; save() does not create a missing folder.
# Everything is checked here so a run fails early rather than
# after hours of model fitting.

## 2.1 Confirm the v2 project root ----
v2_root <- resolve_v2_root(v2_root)

## 2.2 Check the inputs each requested step reads ----
if (run_02c) {
  check_inputs(
    c(
      "1_code/r-scripts/hierarchical-model_functions.R",
      "0_data/species/processed/mite-model-data.Rdata",
      "0_data/bootstrap/mite-bootstrap-ids.Rdata",
      paste0(
        "0_data/lookup/prediction-matrix/",
        "veg-prediction-matrix-CC_2024.csv"
      ),
      paste0(
        "0_data/lookup/prediction-matrix/",
        "soil-prediction-matrix_2024.csv"
      )
    ),
    root = v2_root,
    what = "inputs for 02c"
  )
}

if (run_03c) {
  # 03c reads the models written by 02c. When 02c runs in the same
  # pass that file is produced first, so only require it up front
  # when validation is run on its own.
  step_03c_inputs <- c(
    "1_code/r-scripts/model-validation_functions.R",
    "0_data/species/processed/mite-model-data.Rdata",
    "0_data/bootstrap/mite-bootstrap-ids.Rdata"
  )
  if (!run_02c) {
    step_03c_inputs <- c(
      step_03c_inputs,
      "3_output/models/mite-species-models.Rdata"
    )
  }
  check_inputs(
    step_03c_inputs,
    root = v2_root,
    what = "inputs for 03c"
  )
}

## 2.3 Create the output folders the v2 scripts write to ----
create_v2_output_dirs(v2_root)

## 2.4 Compare the v2 function files with this repo's copies ----
check_function_files(repo_dir = v2_code_dir, root = v2_root)

# 3. Run pipeline scripts in order ----
# Per-script timing comes from run_step() and per-section timing
# from the scripts themselves, so the stages below print no
# banners of their own. Only the whole-pipeline total is recorded
# here.
pipeline_start <- Sys.time()

## 3.1 Modelling ----

### 3.1.1 Fit bootstrapped hierarchical models ----
# Fits the climate, vegetation, and soil model sets over 100
# bootstrap iterations and saves the coefficient lists to
# 3_output/models/mite-species-models.Rdata.
if (run_02c) {
  run_step(
    label = "02c: Hierarchical models (mites)",
    script = "02c_hierarchical-models-mites.R",
    code_dir = v2_code_dir,
    run_dir = v2_root,
    log_dir = log_path,
    protect = runner_objects
  )
}

## 3.2 Validation ----

### 3.2.1 Evaluate model fit ----
# Scores the fitted vegetation and soil models per bootstrap
# (AUC and related measures) and saves the fit summaries to
# 3_output/validation/mite-models-validation.Rdata.
if (run_03c) {
  run_step(
    label = "03c: Model validation (mites)",
    script = "03c_model-validation-mites.R",
    code_dir = v2_code_dir,
    run_dir = v2_root,
    log_dir = log_path,
    protect = runner_objects
  )
}

# 4. Pipeline complete ----
pipeline_time <- format(round(Sys.time() - pipeline_start, 1))
cat("\n========================================\n")
cat("PIPELINE EXECUTION COMPLETE\n")
cat("Total run time: ", pipeline_time, "\n", sep = "")
cat("========================================\n")
cat("Outputs are in ", file.path(v2_root, "3_output"), "\n",
    sep = "")

# End of script ----
