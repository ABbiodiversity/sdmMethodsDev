# ---
# title: Run Experiment 000 - v2.0 Parity Check
# author: Brendan Casey
# created: 2026-09-05
# inputs:
#   harness, in 1_code/harness/utils/:
#     - step_runner.R
#   experiment:
#     - 1_code/experiments/exp_000_parity_v2/utils/species_lists.R
#   modules, in 1_code/modules/plants/:
#     - 01_bootstrap_ids.R
#     - 02_hierarchical_models.R
#     - 03_model_validation.R
#   data:
#     - 0_data/test_dataset/
# outputs:
#   in pipeline_dir (2_pipeline/exp_000_parity_v2/ by default):
#     - <taxon>/bootstrap/, <taxon>/models/, <taxon>/validation/
#     - logs/
#   in out_dir (3_output/exp_000_parity_v2/ by default):
#     - tables/, figures/, report.md
# notes:
#   - Entry point for the experiment, and the only file that has
#     to be edited to change what runs. Sections 1.2 to 1.6 are
#     the whole configuration: where output goes, which taxa run,
#     on which species, and at what run length.
#   - The modelling scripts in 1_code/modules/plants/ take every
#     path as an argument. Nothing is hard-coded to a project
#     layout, so pipeline_dir and out_dir can point anywhere
#     writable; the defaults follow this repository's
#     conventions.
#   - Reads 0_data/test_dataset/ only, which is the harmonized
#     snapshot 1_code/_setup/ builds. The v2 project itself is
#     not needed at run time, and 0_data/ is not written to.
#   - Species vectors live in utils/species_lists.R. NULL models
#     every species the snapshot declares as modelled.
#   - The three stages are ordered: 02 reads what 01 wrote and 03
#     reads what 02 wrote, all from pipeline_dir. Re-running one
#     stage means setting its flag alone, so long as the earlier
#     stages have run at least once.
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
# 2_pipeline/ and 3_output/, so all three paths derive from one
# variable rather than being typed per stage.
exp_id <- "exp_000_parity_v2"

project_root <- normalizePath(getwd(), winslash = "/")

exp_code_dir <- file.path(
  project_root, "1_code/experiments", exp_id
)

module_dir <- file.path(project_root, "1_code/modules/plants")

## 1.3 Choose where the run reads and writes ----
# The three paths a run needs. Point them anywhere writable - a
# scratch disk for a long run, say - and nothing else has to
# change. The defaults follow this repository's conventions.
#
# data_dir is read only. It holds the frozen test dataset, and
# no stage writes to it.
data_dir <- file.path(project_root, "0_data/test_dataset")

# pipeline_dir takes the intermediates: bootstrap ids, fitted
# models, validation objects, and the logs. These are large and
# gitignored.
pipeline_dir <- file.path(project_root, "2_pipeline", exp_id)

# out_dir takes the committed deliverables: tables, figures and
# the report.
out_dir <- file.path(project_root, "3_output", exp_id)

log_path <- file.path(pipeline_dir, "logs")

## 1.4 Set the taxa to run ----
# Set to TRUE to model that taxon. Toggling a flag re-runs one
# taxon without commenting out code.
bryophytes <- FALSE
lichens <- FALSE
mites <- TRUE
vascular_plants <- FALSE

## 1.5 Set the stages to run ----
# The three modelling stages, in order. 02 needs what 01 wrote
# and 03 needs what 02 wrote, so a stage can be run alone only
# once the ones before it have run at least once into the same
# pipeline_dir.
run_bootstrap <- TRUE # 01_bootstrap_ids.R
run_models <- TRUE # 02_hierarchical_models.R
run_validation <- TRUE # 03_model_validation.R

# The steps that turn raw model output into deliverables.
run_collect <- TRUE
run_compare <- TRUE
run_report <- TRUE

## 1.6 Set the run length ----
# v2 hard-coded 100 bootstraps and 14 cores. Both are parameters
# now, but parity means running at the v2 values, so leave these
# as they are for exp_000 and shorten a smoke test with the
# species vectors instead.
boot_iter <- 1:100
n_clusters <- 14

# NULL leaves the bootstrap stream unseeded, as v2 did. Set an
# integer to make a run repeatable.
boot_seed <- NULL

## 1.7 Load the species vectors ----
# Defines bryophyte_species, lichen_species, mite_species and
# vascular_plant_species. NULL means every modelled species.
source(file.path(exp_code_dir, "utils/species_lists.R"))

## 1.8 Load the step runner ----
# Supplies run_step(), which times each stage and mirrors its
# output to a log.
source(file.path(
  project_root, "1_code/harness/utils/step_runner.R"
))

# 2. Run the modelling stages ----
# One block per taxon. Each sets the parameters the module
# scripts read - taxon, species and the output root - then runs
# the three stages in order. Nothing outside pipeline_dir is
# written.

## 2.1 run_taxon() ----

#' Run the Three Modelling Stages for One Taxon
#'
#' Sets the configuration the module scripts read from the global
#' environment, then runs the stages whose flags are TRUE. The
#' scripts are sourced rather than called because they read their
#' parameters by name from there, which is also where their
#' parallel workers export from.
#'
#' @param taxon_name Character. Taxon slug, as used in the test
#'   dataset file names.
#' @param taxon_species Character vector of species to model, or
#'   NULL for every modelled species.
#' @param label Character. The taxon as it reads in a log line.
#' @return NULL, invisibly.
#'
#' @example
#' # Example usage of the function
#' # run_taxon("mite", mite_species, "mites")
run_taxon <- function(taxon_name, taxon_species, label) {
  # Step 1: Publish the parameters the module scripts read. They
  # are assigned to the global environment because that is where
  # the scripts are sourced and where clusterExport() looks.
  #
  # run_dir is the module's own output root, kept distinct from
  # out_dir so the intermediates and the deliverables cannot be
  # written to the same place by accident.
  taxon <<- taxon_name
  species_subset <<- taxon_species
  run_dir <<- file.path(pipeline_dir, taxon_name)

  # Step 2: Run each requested stage in order
  stages <- list(
    list(
      flag = run_bootstrap,
      label = paste0("01: Bootstrap ids (", label, ")"),
      script = file.path(module_dir, "01_bootstrap_ids.R")
    ),
    list(
      flag = run_models,
      label = paste0("02: Hierarchical models (", label, ")"),
      script = file.path(module_dir, "02_hierarchical_models.R")
    ),
    list(
      flag = run_validation,
      label = paste0("03: Model validation (", label, ")"),
      script = file.path(module_dir, "03_model_validation.R")
    )
  )

  for (stage in stages) {
    if (stage$flag) {
      run_step(
        label = stage$label,
        script = stage$script,
        log_dir = log_path
      )
    }
  }

  invisible(NULL)
}

## 2.2 Run each requested taxon ----
experiment_start <- Sys.time()

if (bryophytes) {
  run_taxon("bryophyte", bryophyte_species, "bryophytes")
}

if (lichens) {
  run_taxon("lichen", lichen_species, "lichens")
}

if (mites) {
  run_taxon("mite", mite_species, "mites")
}

if (vascular_plants) {
  run_taxon(
    "vascular_plant", vascular_plant_species, "vascular plants"
  )
}

# 3. Summarize the results ----
# These read the model output left in pipeline_dir and write the
# committed deliverables to out_dir. They are placeholders until
# the parity targets are agreed.
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

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
cat("Intermediates are in ", pipeline_dir, "\n", sep = "")
cat("Deliverables are in ", out_dir, "\n", sep = "")

# End of script ----
