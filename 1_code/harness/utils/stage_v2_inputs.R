# ---
# title: Stage v2 Inputs for an Experiment Run
# author: Brendan Casey
# created: 2026-09-05
# inputs: none
# outputs: none
# notes:
#   - Builds the run root a v2 modelling script expects, under
#     2_pipeline/<exp_id>/<taxon>/, so an experiment can run the
#     untouched v2 code on its own species vector.
#   - The v2 scripts take no arguments. They build their work
#     queue from veg.species.list and soil.species.list, loaded
#     from <taxon>-model-data.Rdata, so a species selection is
#     applied by rewriting those two vectors in a staged copy of
#     that file.
#   - Only those two vectors change. climate.data, veg.data and
#     soil.data are staged untouched because 02x addresses
#     covariates positionally, as colnames(veg.data)[1408:1494],
#     and dropping species columns would shift those indices.
#   - bootstrap.ids is staged whole rather than subset. The v2
#     code reads it as boot.data[[species]], so extra entries are
#     ignored and the copy stays faithful to the source.
#   - Function files are staged from this repository's copies in
#     0_data/v2_scripts/, which makes the repository the source
#     of truth for the code that runs.
#   - Requires resolve_v2_root() from v2_script_runner.R.
# ---

# 1. stage_v2_inputs() ----

#' Stage v2 Inputs for One Taxon
#'
#' Creates a v2-shaped run root under 2_pipeline/<exp_id>/ and
#' fills it with the data, lookups, and function files the v2
#' scripts read, with the species queue narrowed to `species`.
#' The returned path is what a module runner takes as `v2_root`.
#'
#' @param exp_id Character. Experiment identifier, used verbatim
#'   as the folder name under 2_pipeline/ (e.g.
#'   "exp_000_parity_v2").
#' @param taxon Character. Taxon slug as it appears in the v2
#'   file names, one of "bryophyte", "lichen", "mite", or
#'   "vascular-plant".
#' @param species Character vector of species to model, or NULL
#'   to keep every species in the source data.
#' @param source_root Character. Path to the v2 project holding
#'   the source data. Defaults to the SDM_V2_ROOT environment
#'   variable.
#' @param project_root Character. Path to this repository.
#' @param code_dir Character. Directory holding this
#'   repository's copies of the v2 scripts, relative to
#'   `project_root`.
#' @param refresh Logical. Re-stage the model data even when a
#'   staged copy exists. Set FALSE to reuse a staged file across
#'   re-runs of the same species vector.
#' @return Character. Absolute path to the staged run root.
#'
#' @example
#' # Example usage of the function
#' v2_root <- stage_v2_inputs(
#'   exp_id = "exp_000_parity_v2",
#'   taxon = "mite",
#'   species = c("Oppiella.nova", "Tectocepheus.velatus")
#' )
stage_v2_inputs <- function(
  exp_id,
  taxon,
  species = NULL,
  source_root = NULL,
  project_root = getwd(),
  code_dir = "0_data/v2_scripts/plants",
  refresh = TRUE
) {
  # Step 1: Resolve both roots to absolute paths
  project_root <- normalizePath(project_root, winslash = "/")
  if (is.null(source_root)) {
    source_root <- Sys.getenv("SDM_V2_ROOT", unset = NA_character_)
  }
  source_root <- resolve_v2_root(source_root)

  staged_root <- file.path(
    project_root, "2_pipeline", exp_id, taxon
  )

  # Step 2: Create the v2 folder layout the scripts expect
  layout <- c(
    "0_data/species/processed",
    "0_data/bootstrap",
    "0_data/lookup/prediction-matrix",
    "1_code/r-scripts",
    "3_output/models",
    "3_output/validation"
  )
  for (sub_dir in layout) {
    dir.create(
      file.path(staged_root, sub_dir),
      recursive = TRUE, showWarnings = FALSE
    )
  }

  # Step 3: Stage the function files from this repository, so the
  # code that runs is the code held here
  function_files <- c(
    "hierarchical-model_functions.R",
    "model-validation_functions.R"
  )
  file.copy(
    file.path(project_root, code_dir, function_files),
    file.path(staged_root, "1_code/r-scripts"),
    overwrite = TRUE
  )

  # Step 4: Stage the lookups and bootstrap ids unchanged
  lookups <- file.path(
    "0_data/lookup/prediction-matrix",
    c(
      "veg-prediction-matrix-CC_2024.csv",
      "soil-prediction-matrix_2024.csv"
    )
  )
  boot_ids <- file.path(
    "0_data/bootstrap", paste0(taxon, "-bootstrap-ids.Rdata")
  )
  for (item in c(lookups, boot_ids)) {
    file.copy(
      file.path(source_root, item),
      file.path(staged_root, item),
      overwrite = TRUE
    )
  }

  # Step 5: Stage the model data with the species queue narrowed.
  # Every other object is written back untouched.
  model_data <- file.path(
    "0_data/species/processed",
    paste0(taxon, "-model-data.Rdata")
  )
  staged_data <- file.path(staged_root, model_data)

  if (refresh || !file.exists(staged_data)) {
    staged_env <- new.env(parent = emptyenv())
    objects <- load(
      file.path(source_root, model_data),
      envir = staged_env
    )

    if (!is.null(species)) {
      known <- unique(c(
        staged_env$veg.species.list,
        staged_env$soil.species.list
      ))
      unknown <- setdiff(species, known)
      if (length(unknown) > 0) {
        stop(
          "Species not in the ", taxon, " data:\n  ",
          paste(unknown, collapse = "\n  "),
          call. = FALSE
        )
      }
      # intersect() keeps the source ordering, so a staged run
      # queues species in the same order the v2 code would
      staged_env$veg.species.list <- intersect(
        staged_env$veg.species.list, species
      )
      staged_env$soil.species.list <- intersect(
        staged_env$soil.species.list, species
      )
    }

    # Step 6: Warn on an empty queue. 02x still runs, but the
    # matching model set comes back empty, which is easier to
    # diagnose here than three hours later.
    for (queue in c("veg.species.list", "soil.species.list")) {
      if (length(staged_env[[queue]]) == 0) {
        warning(
          "No species left in ", queue, " for ", taxon, ".",
          call. = FALSE
        )
      }
    }

    save(
      list = objects, envir = staged_env, file = staged_data
    )

    cat(
      "Staged ", taxon, " - ",
      length(staged_env$veg.species.list), " vegetation and ",
      length(staged_env$soil.species.list), " soil species\n",
      sep = ""
    )
  }

  staged_root
}

# End of script ----
