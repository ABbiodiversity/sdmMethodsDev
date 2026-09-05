# ---
# title: Run Experiment 000 - v2.0 Parity Check
# author: Brendan Casey
# created: 2026-09-05
# inputs:
#   harness, in 1_code/harness/utils/:
#     - v2_script_runner.R
#     - stage_v2_inputs.R
#   experiment:
#     - 1_code/experiments/exp_000_parity_v2/utils/species_lists.R
#   modules, in 1_code/modules/plants/:
#     - run_v2_bryophytes.R
#     - run_v2_lichens.R
#     - run_v2_mites.R
#     - run_v2_vascular_plants.R
# outputs:
#   in 2_pipeline/exp_000_parity_v2/:
#     - <taxon>/ (staged inputs and raw v2 model output)
#     - logs/
#   in 3_output/exp_000_parity_v2/:
#     - tables/
#     - figures/
#     - report.md
# notes:
#   - Entry point for the experiment. Sets which taxa run and on
#     which species, stages the inputs, then sources the taxon
#     modules, which in turn source the unmodified v2 scripts.
#   - Species vectors live in utils/species_lists.R. A vector of
#     NULL models every species in the source data.
#   - Each taxon is staged into its own run root under
#     2_pipeline/, so a run writes nothing to 0_data/ and edits
#     no v2 code.
#   - Set SDM_V2_ROOT to the v2 project holding the source data.
#     It is read only, and only at staging.
# ---

# 1. Setup ----

## 1.1 Set the working directory ----
# Every path below is relative to this repository's root. In
# RStudio or Positron, uncomment to set it from this script's
# location.
# setwd(dirname(rstudioapi::getActiveDocumentContext()$path))
# setwd("../../..")

## 1.2 Configure the experiment ----
# The identifier is used verbatim in 1_code/experiments/,
# 2_pipeline/, and 3_output/, so all three paths derive from one
# variable rather than being typed per stage.
exp_id <- "exp_000_parity_v2"

project_root <- normalizePath(getwd(), winslash = "/")

exp_code_dir <- file.path(
  project_root, "1_code/experiments", exp_id
)

log_path <- file.path(project_root, "2_pipeline", exp_id, "logs")

out_dir <- file.path(project_root, "3_output", exp_id)

## 1.3 Load harness helpers ----
# v2_script_runner.R supplies run_step() and the pre-run checks;
# stage_v2_inputs.R builds each taxon's run root.
source(file.path(
  project_root, "1_code/harness/utils/v2_script_runner.R"
))
source(file.path(
  project_root, "1_code/harness/utils/stage_v2_inputs.R"
))

## 1.4 Set the taxa to run ----
# Set to TRUE to model that taxon. Toggling a flag re-runs one
# taxon without commenting out code.
bryophytes <- FALSE
lichens <- FALSE
mites <- TRUE
vascular_plants <- FALSE

## 1.5 Load the species vectors ----
# Defines bryophyte_species, lichen_species, mite_species, and
# vascular_plant_species. NULL means every species in the data.
source(file.path(exp_code_dir, "utils/species_lists.R"))

## 1.6 Set the analysis flags ----
# The steps that turn raw v2 output into committed deliverables.
run_collect <- TRUE
run_compare <- TRUE
run_report <- TRUE

# 2. Run the taxon modules ----
# Each block stages that taxon's inputs, then sources its module
# runner. The module reads v2_root and log_path from here, so the
# staged run root is what the v2 scripts see. Nothing outside
# 2_pipeline/ is written.
experiment_start <- Sys.time()

## 2.1 Bryophytes ----
if (bryophytes) {
  v2_root <- stage_v2_inputs(
    exp_id = exp_id,
    taxon = "bryophyte",
    species = bryophyte_species,
    project_root = project_root
  )
  source(file.path(
    project_root, "1_code/modules/plants/run_v2_bryophytes.R"
  ))
}

## 2.2 Lichens ----
if (lichens) {
  v2_root <- stage_v2_inputs(
    exp_id = exp_id,
    taxon = "lichen",
    species = lichen_species,
    project_root = project_root
  )
  source(file.path(
    project_root, "1_code/modules/plants/run_v2_lichens.R"
  ))
}

## 2.3 Soil mites ----
if (mites) {
  v2_root <- stage_v2_inputs(
    exp_id = exp_id,
    taxon = "mite",
    species = mite_species,
    project_root = project_root
  )
  source(file.path(
    project_root, "1_code/modules/plants/run_v2_mites.R"
  ))
}

## 2.4 Vascular plants ----
if (vascular_plants) {
  v2_root <- stage_v2_inputs(
    exp_id = exp_id,
    taxon = "vascular-plant",
    species = vascular_plant_species,
    project_root = project_root
  )
  source(file.path(
    project_root,
    "1_code/modules/plants/run_v2_vascular_plants.R"
  ))
}

# 3. Summarize the results ----
# These read the raw v2 output left in 2_pipeline/ and write the
# committed deliverables to 3_output/. They are placeholders
# until the parity targets are agreed.

## 3.1 Collect model output ----
if (run_collect) {
  source(file.path(exp_code_dir, "01_collect_results.R"))
}

## 3.2 Compare against the v2.0 reference ----
if (run_compare) {
  source(file.path(exp_code_dir, "02_compare_to_v2.R"))
}

## 3.3 Build the report ----
if (run_report) {
  source(file.path(exp_code_dir, "03_build_report.R"))
}

# 4. Experiment complete ----
experiment_time <- format(round(Sys.time() - experiment_start, 1))
cat("\n========================================\n")
cat("EXPERIMENT ", exp_id, " COMPLETE\n", sep = "")
cat("Total run time: ", experiment_time, "\n", sep = "")
cat("========================================\n")
cat("Deliverables are in ", out_dir, "\n", sep = "")

# End of script ----
