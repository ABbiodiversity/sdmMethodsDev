# ---
# title: Run Experiment 000 - v2.0 Parity Check
# author: Brendan Casey
# created: 2026-09-09
# inputs:
#   - 0_data/test_dataset/
#   - 0_data/v2_results/, the v2 reference (section 1.3)
#   - the framework: 1_code/harness/, methods/, modules/
# outputs:
#   in 2_pipeline/exp_000_parity_v2/:
#     - <run>/<region>/ result stores, and run_log.csv
#   in 3_output/exp_000_parity_v2/:
#     - tables/, figures/, report.md, run_record.md
# notes:
#   - The validation gate, and the baseline every later
#     experiment is compared against. Runs each taxon's v2 spec
#     through the framework and compares the result with the
#     published v2 output.
#   - The only file to edit. Section 1.2 is the whole
#     configuration; experiment_config() checks it before
#     anything is fitted.
#   - Parity here is distributional, not numerical: v2 seeds
#     nothing, so two v2 runs give different coefficients, and
#     the comparison is between bootstrap distributions. See the
#     parity ledger in docs/framework_design.md.
#   - What each taxon reproduces of v2 is stated once, in its
#     spec's `v2_coverage`, and the report prints it from there.
# ---

# 1. Setup ----

## 1.1 Load the framework ----
# Run from the repository root. In RStudio or Positron, the
# project file sets it.
source("1_code/harness/harness.R")
load_framework()

exp_dir <- "1_code/experiments/exp_000_parity_v2"

# The parity targets the comparison reads its verdict against
source(file.path(exp_dir, "utils", "parity_targets.R"))

## 1.2 Configure the run ----
# Every decision is here. See experiment_config() for each
# argument, and docs/getting_started.md for what they mean.
config <- experiment_config(
  id = "exp_000_parity_v2",

  # Runs, from names(standard_specs()). Mammals run once per
  # season, because v2's mammal references average the two.
  taxa = c(
    "bryophyte",
    "lichen",
    "mite",
    "vascular_plant",
    "mammal_summer",
    "mammal_winter",
    "bird"
  ),

  # A named set from focal_species_sets(), a vector named by
  # taxon, or NULL for every species (the full parity run).
  # "parity_check" is two species per taxon with tight bands.
  # Shortening the species list is the right way to shorten a
  # trial: it keeps every draw, so the parity bands stay honest.
  species = "parity_check",

  # Draws per species. 100 is v2's, and the only setting the gate
  # reads. Below about 20 the 10-90% bands are too unstable for
  # the parity numbers to mean anything; 5 checks the plumbing.
  n_bootstraps = 5,

  # One number governs every random draw; each species draws
  # under its own seed derived from it. NULL leaves the draws
  # unseeded, as v2 did. Birds replay v2's stored draws.
  seed = 20260909,

  # "spatial_block" draws v2's plant bootstrap afresh;
  # "v2_ids" replays v2's stored draws (needs _setup/07).
  plant_bootstrap = "spatial_block",

  # NULL fits each spec's v2 candidate sets, which is what a
  # parity run does. See extend_models() and
  # models_from_covariates() to fit others.
  stage_models = NULL,

  # Species fitted at once. Each worker is a separate R session.
  workers = 12,

  # "none" writes no per-unit predictions (metrics are scored in
  # memory); "oob" or "all" write them, at several GB for birds.
  unit_predictions = "none"
)

## 1.3 Choose the v2 reference ----
# Which build of the published v2 coefficients the run is scored
# against. Both write the same schema.
#   abmiexplorer  ABMI's ABMIexploreR package, pinned to a commit
#                 (_setup/08); the published species, every taxon
#   drives        the v2 project outputs on the network drives
#                 (_setup/05); every species v2 fitted
config$v2_reference <- "abmiexplorer"

config$v2_reference_dir <- file.path(
  config$project_root,
  "0_data",
  "v2_results",
  switch(
    config$v2_reference,
    abmiexplorer = "abmiexplorer",
    drives = "",
    stop("v2_reference must be \"abmiexplorer\" or \"drives\".", call. = FALSE)
  )
)

config$v2_reference_builder <- switch(
  config$v2_reference,
  abmiexplorer = "1_code/_setup/08_harmonize_abmiexplorer_results.R",
  drives = "1_code/_setup/05_harmonize_v2_results.R"
)

# 2. Run ----
# Fits every species, collects the stores into summary tables,
# then compares with v2, plots and reports. Set `fit = FALSE` to
# re-summarize the stores already in 2_pipeline/ without fitting.
results <- run_experiment(
  config,
  fit = TRUE,
  # Bird landcover is translated onto v2's habitat template so it
  # can be compared; see modules/birds/standardize.R.
  translate = list(bird = bird_habitat_translation),
  steps = list(
    compare = script_step(file.path(exp_dir, "01_compare_to_v2.R")),
    plot = script_step(file.path(exp_dir, "02_plot_parity.R")),
    report = script_step(file.path(exp_dir, "03_build_report.R"))
  )
)

# Commit run_record.md, report.md and the small summary tables
# only after a full run: every species, n_bootstraps = 100.

# End of script ----
