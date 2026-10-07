# ---
# title: Run Experiment 002 - SoilGrids Terms in the Climate Stage
# author: Brendan Casey
# created: 2026-10-04
# inputs:
#   - the published test dataset, the frozen v2 data, unchanged
#   - 2_pipeline/exp_002_soilgrids/inputs/soilgrids_0_5cm.csv, the
#     soil covariates, written by 01_extract_soilgrids_covariates.R
#     in this folder (run here when the file is missing)
#   - 3_output/exp_000_parity_v2/tables/, the v2 baseline
# outputs:
#   in 2_pipeline/exp_002_soilgrids/:
#     - <run>/<region>/ result stores, and run_log.csv
#   in 3_output/exp_002_soilgrids/:
#     - tables/ (summaries, and comparison_metrics.csv against
#       exp_000), run_record.md
# notes:
#   - Does adding 0-5 cm SoilGrids properties to every climate
#     candidate improve the models? See README.md. Soil columns
#     come from this experiment's file via `covariate_files`.
#   - Mammals are not run: their v2 climate is precomputed, and
#     their deployments have no coordinates.
# ---

# 1. Setup ----

## 1.1 Load the framework ----
source("1_code/harness/harness.R")
load_framework()

## 1.2 The soil covariates ----
# Extracted once from the sciSpatialR catalogue; needs the
# network share. Delete the file to extract again.
soil_file <- "2_pipeline/exp_002_soilgrids/inputs/soilgrids_0_5cm.csv"

if (!file.exists(soil_file)) {
  source(file.path(
    "1_code", "experiments", "exp_002_soilgrids",
    "01_extract_soilgrids_covariates.R"
  ))
}

## 1.3 The change: soil terms in every climate candidate ----
# The 0-5 cm SoilGrids properties. Silt is left out: sand, silt
# and clay sum to 100%.
soil_terms <- c(
  "sg_bdod_0_5cm",     # bulk density, kg/dm3
  "sg_cec_0_5cm",      # cation exchange capacity, cmol(c)/kg
  "sg_cfvo_0_5cm",     # coarse fragments, vol %
  "sg_clay_0_5cm",     # clay, %
  "sg_sand_0_5cm",     # sand, %
  "sg_nitrogen_0_5cm", # nitrogen, g/kg
  "sg_phh2o_0_5cm",    # pH in water
  "sg_soc_0_5cm",      # soil organic carbon, g/kg
  "sg_ocd_0_5cm"       # organic carbon density, kg/m3
)

plant_taxa <- c("bryophyte", "lichen", "mite", "vascular_plant")

# Keys are "taxon.stage"
stage_models <- c(
  stats::setNames(
    rep(list(extend_models("climate_plant_v2_full", soil_terms)),
        length(plant_taxa)),
    paste0(plant_taxa, ".climate")
  ),
  list(bird.climate = extend_models("climate_bird_v2", soil_terms))
)

## 1.4 Configure the run ----
# Same species and seed as exp_000
config <- experiment_config(
  id = "exp_002_soilgrids",
  taxa = c(plant_taxa, "bird"),
  species = "parity_check",
  # 5 checks the pipeline runs; 100 for a result to read
  n_bootstraps = 5,
  seed = 20260909,
  stage_models = stage_models,
  # Where the soil columns named in stage_models are read from
  covariate_files = soil_file,
  workers = 12
)

# 2. Run ----
# Fit, summarize, and compare with exp_000
results <- run_experiment(
  config,
  translate = list(bird = bird_habitat_translation)
)

# End of script ----
