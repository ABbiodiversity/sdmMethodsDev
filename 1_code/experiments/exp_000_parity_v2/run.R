# ---
# title: Run Experiment 000 - v2.0 Parity Check
# author: Brendan Casey
# created: 2026-09-09
# inputs:
#   - 0_data/test_dataset/
#   - 1_code/harness/harness.R
#   - 1_code/modules/_shared/plant_group.R
#   - 1_code/modules/<taxon>/spec.R
#   - utils/focal_species.R
# outputs:
#   in pipeline_dir (2_pipeline/exp_000_parity_v2/ by default):
#     - <taxon>/<region>/ result stores
#     - run_log.csv
#   in out_dir (3_output/exp_000_parity_v2/ by default):
#     - tables/, figures/, report.md
# notes:
#   - The validation gate. Runs each taxon's v2 spec through the
#     harness and compares the result against the published v2
#     output.
#   - The only file to edit. Sections 1.3 to 1.7 are the whole
#     configuration: where the run reads and writes, which taxa
#     and regions, which focal species, and how many draws.
#   - Coverage is the climate stage. No taxon's habitat stage is
#     reproduced yet - each needs machinery the harness does not
#     have - and each spec records why in its notes. The report
#     states coverage rather than implying more.
#   - Parity here is distributional, not numerical. v2 seeds
#     nothing, so v2 does not reproduce against itself; two v2
#     runs give different coefficients. The comparison is
#     therefore between bootstrap distributions. See the parity
#     ledger in docs/framework_design.md.
# ---

# 1. Setup ----

## 1.1 Set the working directory ----
# Every path below is relative to this repository's root. In
# RStudio or Positron, uncomment to set it from this script's
# location.
# setwd(dirname(rstudioapi::getActiveDocumentContext()$path))
# setwd("../../..")

## 1.2 Load the harness and the specs ----
project_root <- normalizePath(getwd(), winslash = "/")

source(file.path(project_root, "1_code/harness/harness.R"))
load_harness(file.path(project_root, "1_code/harness"))

# Shared machinery first: the four plant-group modules call it.
source(file.path(
  project_root,
  "1_code/modules/_shared/plant_group.R"
))

for (taxon_dir in c(
  "bryophytes",
  "lichens",
  "soil_mites",
  "vascular_plants",
  "mammals",
  "birds"
)) {
  source(file.path(
    project_root,
    "1_code/modules",
    taxon_dir,
    "spec.R"
  ))
}

exp_id <- "exp_000_parity_v2"

exp_code_dir <- file.path(
  project_root,
  "1_code/experiments",
  exp_id
)

# Named focal-species sets, so run.R chooses rather than lists.
source(file.path(exp_code_dir, "utils/focal_species.R"))

## 1.3 Choose where the run reads and writes ----
# data_dir is read only. pipeline_dir takes the result stores,
# which are large and gitignored. out_dir takes the committed
# deliverables. Point them anywhere writable.
data_dir <- file.path(project_root, "0_data/test_dataset")

pipeline_dir <- file.path(project_root, "2_pipeline", exp_id)

out_dir <- file.path(project_root, "3_output", exp_id)

## 1.4 Set the taxa to run ----
# Each entry names a spec. Comment one out to skip it.
# Keys are data slugs, which is what run_taxa and focal_species
# match on. Soil mites key on "mite".
specs <- list(
  bryophyte = bryophyte_spec(),
  lichen = lichen_spec(),
  mite = soil_mite_spec(),
  vascular_plant = vascular_plant_spec(),
  mammal = mammal_spec(climate_source = "fitted"),
  bird = bird_spec()
)

# All six. Drop names to run fewer; birds run but cannot be
# gated, so a parity-only pass can leave "bird" out.
run_taxa <- c(
  "bryophyte",
  "lichen",
  "mite",
  "vascular_plant",
  "mammal",
  "bird"
)

## 1.5 Choose the focal species ----
# Named sets live in utils/focal_species.R, so this stays a
# decision rather than a list of names. See that file for what
# each set is and why its species were chosen.
#
#   full          every species each spec declares; the parity run
#   parity_check  two per taxon, chosen for tight bootstrap bands
#   plants_only   the four plant-group taxa
#   one_each      one per taxon; the shortest run that touches
#                 every module
#
# A species vector written inline is also accepted and passes
# straight through, so a one-off does not need a named set:
#
#   focal_species <- get_focal_species(c(
#     lichen = "Alectoria.sarmentosa",
#     mite   = "Oppiella.nova"
#   ))
#
# Shortening the species list is the right way to shorten a
# trial: it keeps every draw, so the parity bands stay honest.
# Lowering `n_bootstraps` in section 1.6 is cheaper still, but
# it widens those bands and costs you the parity read.
focal_species <- get_focal_species("parity_check")

# A taxon in run_taxa that the species set does not name runs
# EVERY species, because an absent taxon means "no restriction"
# rather than "none". That is the convention working as intended,
# but it turns a set like plants_only into the longest run in the
# file rather than the shortest, so it is said out loud here.
unnamed_taxa <- if (is.null(focal_species)) {
  character(0)
} else {
  setdiff(run_taxa, unique(names(focal_species)))
}

if (length(unnamed_taxa) > 0) {
  message(
    "Note: ",
    paste(unnamed_taxa, collapse = ", "),
    " are in run_taxa but not named in focal_species, so every ",
    "species will be run for them. Narrow run_taxa to avoid it."
  )
}

## 1.5b Choose the candidate models ----
# NULL fits each spec's own v2 candidate set, which is what a
# parity run does. To ask a different question, name a stage and
# hand it a set: either a name from model_sets(), or formulas
# built with extend_models() or models_from_covariates().
#
# Keys are "taxon.stage", or "stage" to apply to every taxon.
#
# Covariates are not named anywhere. They are read off whichever
# formulas end up being fitted, so changing the models changes
# what is loaded, and a term can never be fitted without its
# column being read.
#
#   stage_models <- list(
#     # the v2 climate set, plus topography in every candidate
#     "climate" = extend_models(
#       "climate_plant_v2_full", c("elevation", "slope")
#     ),
#     # or a set built from covariates alone
#     "mite.climate" = models_from_covariates(
#       c("MAP", "FFP", "CMD"), form = "ladder"
#     )
#   )
#
# An override is recorded in each run's meta.json, so a run that
# did not fit the v2 sets cannot be mistaken for one that did.
stage_models <- NULL

## 1.6 Set the run length ----
# How many bootstrap draws each species gets. Cost is close to
# linear in this number, so 10 draws is roughly a tenth of the
# run, and it is the cheapest way to make a trial affordable.
#
# It is also the one setting that invalidates the parity read.
# The gate scores a term on whether the v2 value falls inside
# this run's 10th-to-90th percentile band, and a band estimated
# from a handful of draws is wide and unstable, so almost
# everything falls inside it and the test stops discriminating.
# Below roughly 20 draws, treat the parity numbers as evidence
# the pipeline ran, not as evidence it agrees with v2.
#
# Shorten the species list instead when you want a cheap run
# whose parity numbers still mean something. See section 1.5.
#
#   100  the v2 value, and the only setting that gates
#    20  a usable band, for a slow-but-real check
#     5  plumbing only
v2_bootstraps <- 5L

n_bootstraps <- v2_bootstraps

## 1.6a Validate the run length ----
# Checked here rather than several hours into a run.
if (
  !is.numeric(n_bootstraps) ||
    length(n_bootstraps) != 1L ||
    is.na(n_bootstraps) ||
    n_bootstraps < 1 ||
    n_bootstraps != round(n_bootstraps)
) {
  stop(
    "n_bootstraps must be a single whole number of 1 or more; ",
    "got ",
    paste(format(n_bootstraps), collapse = ", "),
    ".",
    call. = FALSE
  )
}

n_bootstraps <- as.integer(n_bootstraps)

# Birds resample from stored ids and so have a hard ceiling.
# Every other taxon draws spatial blocks on the fly and has
# none. Counting the columns is cheap; discovering the limit
# from a failed bird run is not.
if ("bird" %in% run_taxa) {
  bird_ids_path <- file.path(
    data_dir,
    "lookup",
    "bird_bootstrap_ids.csv"
  )

  if (file.exists(bird_ids_path)) {
    bird_draws <- length(names(
      data.table::fread(bird_ids_path, nrows = 0)
    ))

    if (n_bootstraps > bird_draws) {
      stop(
        "n_bootstraps is ",
        n_bootstraps,
        " but only ",
        bird_draws,
        " bird bootstrap draws are stored. Lower ",
        "it, or drop \"bird\" from run_taxa.",
        call. = FALSE
      )
    }
  }
}

if (n_bootstraps < v2_bootstraps) {
  message(
    "Note: running ",
    n_bootstraps,
    " of ",
    v2_bootstraps,
    " v2 bootstrap draws. This is a trial run; its parity ",
    "numbers are not a parity read."
  )
}

iterations <- seq_len(n_bootstraps)

## 1.7 Set the stages to run ----
run_models <- TRUE
run_collect <- TRUE
run_compare <- TRUE
run_report <- TRUE

# 2. Fit ----
# One spec per taxon, each writing a result store per region.

experiment_start <- Sys.time()
run_log <- NULL

if (run_models) {
  logs <- list()

  for (taxon in run_taxa) {
    spec <- specs[[taxon]]

    if (is.null(spec)) {
      stop(
        "No spec defined for `",
        taxon,
        "` in section 1.4.",
        call. = FALSE
      )
    }

    logs[[taxon]] <- run_spec(
      spec = spec,
      data_dir = data_dir,
      run_dir = file.path(pipeline_dir, taxon),
      species = focal_species,
      iterations = iterations,
      stage_models = stage_models
    )
  }

  run_log <- do.call(rbind, logs)

  dir.create(pipeline_dir, recursive = TRUE, showWarnings = FALSE)
  data.table::fwrite(
    run_log,
    file.path(pipeline_dir, "run_log.csv"),
    na = ""
  )

  cat("\nRun log:\n")
  print(table(run_log$taxon, run_log$status))
}

# 3. Summarize ----
# These read the result stores and write the committed
# deliverables.

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
