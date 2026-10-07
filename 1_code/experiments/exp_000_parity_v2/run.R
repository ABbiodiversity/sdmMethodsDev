# ---
# title: Run Experiment 000 - v2.0 Parity Check
# author: Brendan Casey
# created: 2026-09-09
# inputs:
#   - the published test dataset (harness/data_source.R)
#   - the published v2 results, the ABMIexploreR reference
#     (section 1.3; see harness/data_source.R)
#   - the framework: 1_code/harness/, methods/, modules/
# outputs:
#   in 2_pipeline/exp_000_parity_v2/:
#     - <run>/<region>/ result stores, and run_log.csv
#   in 3_output/exp_000_parity_v2/:
#     - tables/, figures/, report.md, run_record.md
# notes:
#   - The validation gate and the baseline for every experiment:
#     each taxon's v2 spec against the published v2 output.
#   - Section 1.2 is the whole configuration.
#   - Parity is mostly distributional (v2 seeds nothing); see the
#     parity ledger in docs/framework_design.md.
# ---

# 1. Setup ----

## 1.1 Load the framework ----
# Run from the repository root
source("1_code/harness/harness.R")
load_framework()

exp_dir <- "1_code/experiments/exp_000_parity_v2"

source(file.path(exp_dir, "utils", "parity_targets.R"))

## 1.2 Configure the run ----
# See experiment_config() and docs/getting_started.md
config <- experiment_config(
  id = "exp_000_parity_v2",

  # Runs, from names(standard_specs())
  taxa = c(
    "bryophyte",
    "lichen",
    "mite",
    "vascular_plant",
    "mammal_summer",
    "mammal_winter",
    "bird"
  ),

  # A focal_species_sets() name, a vector named by taxon, or NULL
  # for every species. Shorten trials by species, not draws, so
  # the bands stay honest.
  species = "parity_check",

  # 100 is v2's and the only count the gate reads; below ~20 the
  # 10-90% bands are unstable. 5 checks the plumbing.
  n_bootstraps = 5,

  # Base seed; NULL is unseeded, as v2. Birds replay v2's draws.
  seed = 20260909,

  # "spatial_block" draws v2's plant bootstrap afresh;
  # "v2_ids" replays v2's stored draws (needs _setup/07).
  plant_bootstrap = "spatial_block",

  # NULL fits each spec's v2 candidate sets
  stage_models = NULL,

  # Species fitted at once, one R session each
  workers = 12,

  # "oob" or "all" write per-unit predictions (GBs for birds)
  unit_predictions = "none"
)

## 1.3 The v2 reference ----
# ABMIexploreR's published coefficients, pinned to a commit and
# harmonized by _setup/08
config$v2_reference <- "abmiexplorer"
config$v2_reference_dir <- file.path(
  v2_results_dir(), "abmiexplorer"
)
config$v2_reference_builder <-
  "1_code/_setup/08_harmonize_abmiexplorer_results.R"

# 2. Run ----
# `fit = FALSE` re-summarizes existing stores without fitting
results <- run_experiment(
  config,
  fit = TRUE,
  # Bird landcover onto v2's habitat template
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
