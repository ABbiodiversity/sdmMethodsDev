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
#     and regions, which focal species, how many draws, and the
#     random seed.
#   - What each taxon reproduces of v2 is stated once, in its
#     spec's `v2_coverage`, and the report prints it from there.
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

# Translates bird landcover coefficients onto v2's standardized
# habitat terms, so the comparison can join them.
source(file.path(
  project_root,
  "1_code/modules/birds/standardize.R"
))

# v2's mammal hurdle model, which the mammal specs select by
# default.
source(file.path(project_root, "1_code/modules/mammals/hurdle.R"))

exp_id <- "exp_000_parity_v2"

exp_code_dir <- file.path(
  project_root,
  "1_code/experiments",
  exp_id
)

# Named focal-species sets, so run.R chooses rather than lists.
source(file.path(exp_code_dir, "utils/focal_species.R"))

# The parity targets the comparison reads its verdict against
source(file.path(exp_code_dir, "utils/parity_targets.R"))

## 1.3 Choose where the run reads and writes ----
# data_dir is read only. pipeline_dir takes the result stores,
# which are large and gitignored. out_dir takes the committed
# deliverables. Point them anywhere writable.
data_dir <- file.path(project_root, "0_data/test_dataset")

pipeline_dir <- file.path(project_root, "2_pipeline", exp_id)

out_dir <- file.path(project_root, "3_output", exp_id)

## 1.3a Choose the v2 reference ----
# Which build of the published v2 coefficients the run is scored
# against. Both write the same schema.
#
#   abmiexplorer  ABMI's ABMIexploreR package, pinned to a commit;
#                 1_code/_setup/08_harmonize_abmiexplorer_results.R.
#                 The published species only; every taxon.
#   drives        the v2 project outputs on the network drives;
#                 1_code/_setup/05_harmonize_v2_results.R.
#                 Every species v2 fitted.
v2_reference <- "abmiexplorer"

v2_reference_dir <- switch(
  v2_reference,
  abmiexplorer = file.path(
    project_root,
    "0_data/v2_results/abmiexplorer"
  ),
  drives = file.path(project_root, "0_data/v2_results"),
  stop("v2_reference must be \"abmiexplorer\" or \"drives\".", call. = FALSE)
)

## 1.4 Set the taxa to run ----
# Each entry names a spec. Comment one out to skip it.
# A key names the run and its folder under pipeline_dir; the
# data slug the spec reads is its own `taxon` field, which is
# what focal_species matches on. Soil mites use the slug "mite".
#
# Mammals run once per season. v2's mammal references average
# the summer and winter fits, so the comparison needs both.
#
# The plant bootstrap. "spatial_block" draws v2's bootstrap
# afresh, so parity is distributional. "v2_ids" replays the draws
# v2 stored, which makes it numerical draw by draw - but only
# against a reference fitted on those draws. The published
# lichen, mite and vascular plant models were not (checked: no
# published draw matches beyond the full-data one), so it pays
# off only for the bryophyte reference _setup/03 regenerated.
# "v2_ids" needs _setup/07 run for every species in the run.
plant_bootstrap <- "spatial_block"

specs <- list(
  bryophyte = bryophyte_spec(bootstrap = plant_bootstrap),
  lichen = lichen_spec(bootstrap = plant_bootstrap),
  mite = soil_mite_spec(bootstrap = plant_bootstrap),
  vascular_plant = vascular_plant_spec(bootstrap = plant_bootstrap),
  mammal_summer = mammal_spec(
    season = "summer"
  ),
  mammal_winter = mammal_spec(
    season = "winter"
  ),
  bird = bird_spec()
)

# Every spec. Drop keys to run fewer.
run_taxa <- c(
  "bryophyte",
  "lichen",
  "mite",
  "vascular_plant",
  "mammal_summer",
  "mammal_winter",
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
# Matched on each spec's data slug, not its key, because the two
# mammal keys share the slug "mammal".
run_slugs <- vapply(
  specs[intersect(run_taxa, names(specs))],
  function(one) one$taxon,
  character(1)
)

unnamed_taxa <- if (is.null(focal_species)) {
  character(0)
} else {
  names(run_slugs)[!run_slugs %in% names(focal_species)]
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
#
# `v2_bootstraps` is v2's draw count, fixed; the run length is
# `n_bootstraps`. A run shorter than v2's, or on a species
# subset, is a trial and is not gated.
v2_bootstraps <- 100L

n_bootstraps <- 100L

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

## 1.6b Set the random seed ----
# One number governs every random draw in the run. Each species
# resamples under its own seed, derived from this one and its
# name, so species are drawn independently as in v2 and a
# species' draws do not change when the focal set does.
#
# v2 set no seed, so its draws cannot be matched either way; the
# comparison is distributional. Seeding makes this side of it
# repeatable: the same seed and settings give the same stores.
# NULL leaves the draws unseeded, which is what v2 did.
#
# Birds are unaffected. Their draws are the stored v2 ids.
boot_seed <- 20260909L

## 1.7 Set the stages to run ----
run_models <- FALSE
run_collect <- FALSE
run_compare <- TRUE
run_plots <- TRUE
run_report <- TRUE

# Named write_record rather than run_record, which would shadow
# the function it calls.
write_record <- TRUE

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
      stage_models = stage_models,
      boot_seed = boot_seed
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

## 3.3 Plot parity against v2 ----
# One figure per taxon in figures/, gitignored like the
# per-species tables it is drawn from.
if (run_plots) {
  source(file.path(exp_code_dir, "04_plot_parity.R"))
}

## 3.4 Build the report ----
if (run_report) {
  source(file.path(exp_code_dir, "03_build_report.R"))
}

## 3.5 Write the run record ----
# Committed with the report and summary tables. The stores in
# 2_pipeline/ and the per-species tables are gitignored, so when
# the stores are cleared this is what is left to say what
# happened.
#
# The config below is what makes two records comparable, so it
# holds settings rather than paths: an absolute directory
# differs between machines and would diff on every line without
# meaning anything. Volatile values belong in the record's own
# Provenance section, which run_record() writes.
if (write_record) {
  stage_engines <- function(field) {
    sort(unique(unlist(lapply(
      specs[run_taxa],
      function(one) {
        vapply(
          one$stages,
          function(st) {
            value <- st[[field]]
            if (is.function(value)) "custom" else value
          },
          character(1)
        )
      }
    ))))
  }

  record_config <- list(
    taxa = sort(run_taxa),
    focal_species = if (is.null(focal_species)) {
      "all"
    } else {
      sort(paste0(names(focal_species), "=", focal_species))
    },
    species_n = if (is.null(focal_species)) {
      NA_integer_
    } else {
      length(focal_species)
    },
    n_bootstraps = n_bootstraps,
    v2_bootstraps = v2_bootstraps,
    boot_seed = if (is.null(boot_seed)) "unseeded" else boot_seed,
    plant_bootstrap = plant_bootstrap,
    stage_models = if (is.null(stage_models)) {
      "spec defaults (v2 candidate sets)"
    } else {
      sort(names(stage_models))
    },
    engines = stage_engines("engine"),
    selection = stage_engines("selection"),
    data_dir = basename(data_dir)
  )

  # Failures belong in the record. Coverage says what was
  # produced; without this, a run that lost half its jobs and
  # one that lost none look alike wherever the survivors agree.
  if (!is.null(run_log)) {
    ok_n <- sum(run_log$status == "ok", na.rm = TRUE)

    record_config$jobs_total <- as.integer(nrow(run_log))
    record_config$jobs_ok <- as.integer(ok_n)
    record_config$jobs_not_ok <- as.integer(nrow(run_log) - ok_n)
  }

  record_file <- run_record(
    pipeline_dir = pipeline_dir,
    out_file = file.path(out_dir, "run_record.md"),
    exp_id = exp_id,
    config = record_config
  )

  cat("Run record: ", record_file, "\n", sep = "")
}

# 4. Experiment complete ----
experiment_time <- format(round(Sys.time() - experiment_start, 1))
cat("\n========================================\n")
cat("EXPERIMENT ", exp_id, " COMPLETE\n", sep = "")
cat("Total run time: ", experiment_time, "\n", sep = "")
cat("========================================\n")
cat("Intermediates are in ", pipeline_dir, "\n", sep = "")
cat("Deliverables are in ", out_dir, "\n", sep = "")
cat(
  "Committed: run_record.md, report.md and the summary ",
  "tables. Commit them only after a full run.",
  "\n",
  sep = ""
)

# End of script ----
