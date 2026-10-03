# ---
# title: Configure and Run an Experiment
# author: Brendan Casey
# created: 2026-10-03
# inputs:
#   0_data/test_dataset/
# outputs:
#   in 2_pipeline/<id>/: the result stores and run_log.csv
#   in 3_output/<id>/: tables/, run_record.md, and whatever the
#   experiment's own steps write
# notes:
#   - An experiment is a configuration plus a few steps. This
#     holds the part every experiment shares, so each run.R is a
#     short list of decisions:
#     - experiment_config() states and checks the decisions -
#       which runs, species, draws, seed, candidate models and
#       workers - before anything is fitted. Every check that used
#       to sit in run.R lives here.
#     - run_experiment() fits (optionally), collects the stores
#       into summary tables, runs the experiment's own steps in
#       order, and writes the run record.
#   - Everything the steps need travels in the config and the
#     results passed to them; nothing is read from the global
#     environment, so a step can be run on its own.
# ---

# 1. Setup ----

## 1.1 Load packages ----
library(data.table) # run log writing (version: 1.16.4)

# 2. experiment_config() ----

#' State and Check an Experiment's Configuration
#'
#' @param id Character. The experiment identifier, e.g.
#'   "exp_001_covariate_scale". Names its 2_pipeline/ and
#'   3_output/ folders.
#' @param taxa Character vector of runs, from
#'   names(standard_specs()), or NULL for all of them.
#' @param species A focal-species set name (see
#'   focal_species_sets()), a species vector named by taxon, or
#'   NULL for every species.
#' @param n_bootstraps Integer. Draws per species. 100 is v2's.
#' @param seed Integer or NULL. The base seed; NULL leaves the
#'   draws unseeded, as v2 did.
#' @param stage_models Named list of replacement candidate sets,
#'   or NULL for each spec's v2 sets; see apply_stage_models().
#' @param specs Named list of specs, or NULL for
#'   standard_specs(plant_bootstrap). An experiment that changes
#'   a spec builds its own and passes it here.
#' @param plant_bootstrap Character. Passed to standard_specs().
#' @param workers Integer. Species fitted at once.
#' @param unit_predictions Character. "none", "oob" or "all".
#' @param v2_bootstraps Integer. v2's draw count, which a run must
#'   reach to be gated.
#' @param project_root Character. The repository root.
#' @param data_dir,pipeline_dir,out_dir Character, or NULL for
#'   0_data/test_dataset, 2_pipeline/<id> and 3_output/<id>.
#' @return A list of class `experiment_config`.
#'
#' @example # Example usage of the function
#' # config <- experiment_config("exp_001_test", taxa = "lichen",
#' #                             species = "one_each",
#' #                             n_bootstraps = 5)
experiment_config <- function(
  id,
  taxa = NULL,
  species = NULL,
  n_bootstraps = 100L,
  seed = 20260909L,
  stage_models = NULL,
  specs = NULL,
  plant_bootstrap = "spatial_block",
  workers = 1L,
  unit_predictions = "none",
  v2_bootstraps = 100L,
  project_root = getOption("sdm.project_root", "."),
  data_dir = NULL,
  pipeline_dir = NULL,
  out_dir = NULL
) {
  # Step 1: The runs
  specs <- specs %||% standard_specs(plant_bootstrap)
  taxa <- taxa %||% names(specs)
  unknown <- setdiff(taxa, names(specs))

  if (length(unknown) > 0) {
    stop(
      "Unknown run(s): ", paste(unknown, collapse = ", "),
      ". Available: ", paste(names(specs), collapse = ", "),
      call. = FALSE
    )
  }

  specs <- specs[taxa]

  # Step 2: The draw count, checked now rather than hours in
  if (!is.numeric(n_bootstraps) || length(n_bootstraps) != 1L ||
        is.na(n_bootstraps) || n_bootstraps < 1 ||
        n_bootstraps != round(n_bootstraps)) {
    stop(
      "n_bootstraps must be a single whole number of 1 or more.",
      call. = FALSE
    )
  }

  n_bootstraps <- as.integer(n_bootstraps)
  data_dir <- data_dir %||% file.path(
    project_root, "0_data", "test_dataset"
  )

  # Stored draws have a hard ceiling; drawn ones do not
  for (key in names(specs)) {
    spec <- specs[[key]]

    if (!identical(spec$resample$scheme, "precomputed") ||
          isTRUE(spec$resample$per_species)) {
      next
    }

    location <- manifest_entry(data_dir, spec$taxon)$bootstrap_ids
    stored <- length(names(fread(
      file.path(data_dir, location), nrows = 0
    )))

    if (n_bootstraps > stored) {
      stop(
        "n_bootstraps is ", n_bootstraps, " but only ", stored,
        " ", spec$taxon, " draws are stored. Lower it, or drop `",
        key, "`.",
        call. = FALSE
      )
    }
  }

  if (n_bootstraps < v2_bootstraps) {
    message(
      "Note: running ", n_bootstraps, " of ", v2_bootstraps,
      " v2 draws. This is a trial; its parity numbers are not a ",
      "parity read."
    )
  }

  # Step 3: The species. A taxon the set does not name runs every
  # species, because an absent taxon means "no restriction". Said
  # out loud, because it makes a partial set the longest run.
  focal <- get_focal_species(species)

  if (!is.null(focal)) {
    slugs <- vapply(specs, `[[`, character(1), "taxon")
    unnamed <- names(slugs)[!slugs %in% names(focal)]

    if (length(unnamed) > 0) {
      message(
        "Note: ", paste(unnamed, collapse = ", "), " are not named ",
        "in the species set, so every species will be run for ",
        "them. Narrow `taxa` to avoid it."
      )
    }
  }

  structure(
    list(
      id = id,
      taxa = taxa,
      specs = specs,
      # The set's name, for the record; "inline" for a vector
      species_set = if (is.character(species) &&
                          length(species) == 1L &&
                          is.null(names(species))) {
        species
      } else {
        "inline"
      },
      focal_species = focal,
      n_bootstraps = n_bootstraps,
      v2_bootstraps = as.integer(v2_bootstraps),
      seed = seed,
      stage_models = stage_models,
      plant_bootstrap = plant_bootstrap,
      workers = as.integer(workers),
      unit_predictions = unit_predictions,
      project_root = project_root,
      data_dir = data_dir,
      pipeline_dir = pipeline_dir %||%
        file.path(project_root, "2_pipeline", id),
      out_dir = out_dir %||% file.path(project_root, "3_output", id)
    ),
    class = "experiment_config"
  )
}

## 2.1 print.experiment_config() ----

#' Print an Experiment's Configuration
#'
#' @param x An experiment_config().
#' @param ... Unused.
#' @return `x`, invisibly.
#'
#' @example # Example usage of the function
#' # print(config)
print.experiment_config <- function(x, ...) {
  cat("Experiment ", x$id, "\n", sep = "")
  cat("  runs:     ", paste(x$taxa, collapse = ", "), "\n", sep = "")
  cat("  species:  ", if (is.null(x$focal_species)) {
    "every species"
  } else {
    paste0(length(x$focal_species), " focal (", x$species_set, ")")
  }, "\n", sep = "")
  cat("  draws:    ", x$n_bootstraps, " (v2: ", x$v2_bootstraps,
      ")\n", sep = "")
  cat("  seed:     ", x$seed %||% "unseeded", "\n", sep = "")
  cat("  models:   ", if (is.null(x$stage_models)) {
    "each spec's v2 candidate sets"
  } else {
    paste(names(x$stage_models), collapse = ", ")
  }, "\n", sep = "")
  cat("  workers:  ", x$workers, "\n", sep = "")
  cat("  writes:   ", x$pipeline_dir, "\n            ", x$out_dir,
      "\n", sep = "")

  invisible(x)
}

# 3. run_experiment() ----

#' Fit, Summarize, Run the Experiment's Steps, and Record
#'
#' @param config An experiment_config().
#' @param fit Logical. FALSE skips fitting and re-summarizes the
#'   stores already in pipeline_dir.
#' @param steps Named list of functions, run in order after the
#'   summary tables are written. Each takes `config` and
#'   `results` and returns `results`, which it may add to.
#' @param translate Named list of coefficient translations by
#'   taxon, passed to collect_results().
#' @param record Logical. Write run_record.md.
#' @return The results list, invisibly: the summary tables, the
#'   run log, and whatever the steps added.
#'
#' @example # Example usage of the function
#' # results <- run_experiment(config,
#' #   steps = list(compare = compare_to_baseline))
run_experiment <- function(
  config,
  fit = TRUE,
  steps = list(),
  translate = list(),
  record = TRUE
) {
  started <- Sys.time()
  print(config)

  # Step 1: Fit
  run_log <- NULL

  if (fit) {
    run_log <- run_specs(
      specs = config$specs,
      data_dir = config$data_dir,
      pipeline_dir = config$pipeline_dir,
      species = config$focal_species,
      iterations = seq_len(config$n_bootstraps),
      stage_models = config$stage_models,
      boot_seed = config$seed,
      workers = config$workers,
      unit_predictions = config$unit_predictions
    )

    fwrite(run_log, file.path(config$pipeline_dir, "run_log.csv"),
           na = "")
    cat("\nRun log:\n")
    print(table(run_log$taxon, run_log$status))
  }

  # Step 2: Summarize the stores
  results <- collect_results(
    config$pipeline_dir, config$data_dir, translate = translate
  )
  results$run_log <- run_log
  write_summaries(results, config$out_dir)

  # Step 3: The experiment's own steps, in order
  for (name in names(steps)) {
    cat("\n== ", name, " ==\n", sep = "")
    results <- steps[[name]](config, results)
  }

  # Step 4: The committed record of what ran
  if (record) {
    record_file <- run_record(
      pipeline_dir = config$pipeline_dir,
      out_file = file.path(config$out_dir, "run_record.md"),
      exp_id = config$id,
      config = record_config(config, run_log),
      collected = results
    )
    cat("Run record: ", record_file, "\n", sep = "")
  }

  cat(
    "\n", config$id, " complete in ",
    format(round(Sys.time() - started, 1)), "\n",
    "Intermediates: ", config$pipeline_dir, "\n",
    "Deliverables:  ", config$out_dir, "\n",
    sep = ""
  )

  invisible(results)
}

# 4. record_config() ----

#' The Settings a Run Record States
#'
#' Settings rather than paths: an absolute directory differs
#' between machines and would diff on every line without meaning
#' anything.
#'
#' @param config An experiment_config().
#' @param run_log The run log, or NULL when nothing was fitted.
#' @return A named list.
#'
#' @example # Example usage of the function
#' # record_config(config, run_log)
record_config <- function(config, run_log = NULL) {
  stage_values <- function(field) {
    sort(unique(unlist(lapply(config$specs, function(spec) {
      vapply(spec$stages, function(stage) {
        value <- stage[[field]]
        if (is.function(value)) "custom" else value
      }, character(1))
    }))))
  }

  out <- list(
    taxa = sort(config$taxa),
    focal_species = if (is.null(config$focal_species)) {
      "all"
    } else {
      sort(paste0(names(config$focal_species), "=",
                  config$focal_species))
    },
    species_n = if (is.null(config$focal_species)) {
      NA_integer_
    } else {
      length(config$focal_species)
    },
    n_bootstraps = config$n_bootstraps,
    v2_bootstraps = config$v2_bootstraps,
    boot_seed = config$seed %||% "unseeded",
    plant_bootstrap = config$plant_bootstrap,
    stage_models = if (is.null(config$stage_models)) {
      "spec defaults (v2 candidate sets)"
    } else {
      sort(names(config$stage_models))
    },
    engines = stage_values("engine"),
    selection = stage_values("selection"),
    data_dir = basename(config$data_dir)
  )

  # Failures belong in the record. Without them, a run that lost
  # half its jobs and one that lost none look alike wherever the
  # survivors agree.
  if (!is.null(run_log)) {
    ok <- sum(run_log$status == "ok", na.rm = TRUE)
    out$jobs_total <- nrow(run_log)
    out$jobs_ok <- ok
    out$jobs_not_ok <- nrow(run_log) - ok
  }

  out
}

# 5. compare_to_baseline() ----

#' An Experiment Step: Compare Against exp_000
#'
#' Ready to pass in run_experiment()'s `steps`. Compares this
#' experiment's summaries with the v2 baseline's; see
#' compare_experiments().
#'
#' @param config An experiment_config().
#' @param results The results so far.
#' @param baseline Character. The baseline experiment's id.
#' @return `results`, with `comparison` added.
#'
#' @example # Example usage of the function
#' # run_experiment(config, steps = list(
#' #   compare = compare_to_baseline))
compare_to_baseline <- function(
  config, results, baseline = "exp_000_parity_v2"
) {
  comparison <- compare_experiments(
    candidate_dir = config$out_dir,
    baseline_dir = file.path(
      config$project_root, "3_output", baseline
    )
  )

  cat("\nAgainst ", baseline, ", per taxon, region and metric:\n",
      sep = "")
  print(comparison$summary, row.names = FALSE)

  results$comparison <- comparison
  results
}

# 6. script_step() ----

#' Turn an Experiment Script into a Step
#'
#' An experiment's own scripts - a comparison, a figure, a
#' report - are written top to bottom and read `config` and
#' `results`. This runs one in an environment of its own holding
#' only those two, so it cannot depend on, or leave behind, any
#' other variable, and hands back the `results` it updated.
#'
#' @param path Character. The script.
#' @return A function(config, results) for run_experiment()'s
#'   `steps`.
#'
#' @example # Example usage of the function
#' # steps <- list(report = script_step("03_build_report.R"))
script_step <- function(path) {
  force(path)

  if (!file.exists(path)) {
    stop("Step script not found:
  ", path, call. = FALSE)
  }

  function(config, results) {
    env <- new.env(parent = globalenv())
    env$config <- config
    env$results <- results

    sys.source(path, envir = env, keep.source = FALSE)

    env$results
  }
}

# End of script ----
