# ---
# title: Configure and Run an Experiment
# author: Brendan Casey
# created: 2026-10-03
# inputs:
#   the published test dataset (see data_source.R)
# outputs:
#   in 2_pipeline/<id>/: the result stores, run_log.csv and
#   session_info.txt
#   in 3_output/<id>/: tables/, run_record.md, and whatever the
#   experiment's own steps write
# notes:
#   - The part every experiment shares, so each run.R is a short
#     list of decisions. experiment_config() checks them all
#     before anything is fitted and reports every problem at
#     once; run_experiment() fits, summarizes, compares with the
#     baseline (exp_000, v2), runs the experiment's own steps and
#     writes the run record.
#   - The argument defaults here, with standard_specs(), are the
#     v2 defaults: an experiment passes only what it changes.
#   - Steps receive everything through `config` and `results`.
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
#'   names(standard_specs()), or NULL. NULL with a species list
#'   runs only the runs that fit a listed species (e.g. a
#'   `Moose_Summer` row runs `mammal_summer`); NULL with no species
#'   list runs every run.
#' @param species The path to the experiment's species.csv (see
#'   read_species_file()), a species vector named by taxon, or
#'   NULL for every species. Names are checked against the
#'   dataset's species queue.
#' @param n_bootstraps Integer. Draws per species. 100 is v2's.
#' @param seed Integer or NULL. The base seed; NULL leaves the
#'   draws unseeded, as v2 did.
#' @param stage_models Named list of replacement candidate sets,
#'   or NULL for each spec's v2 sets; see apply_stage_models().
#' @param covariate_files Character vector of CSVs holding
#'   covariates the frozen dataset does not, keyed on
#'   survey_unit_id, or NULL. Written by the experiment's own
#'   scripts, never into 0_data/; their columns can then be named
#'   in `stage_models`.
#' @param specs Named list of specs, or NULL for
#'   standard_specs(plant_bootstrap). An experiment that changes
#'   a spec builds its own and passes it here.
#' @param plant_bootstrap Character. Passed to standard_specs().
#' @param workers Integer. Species fitted at once.
#' @param unit_predictions Character. "none", "oob" or "all".
#' @param prediction A prediction_config() (predict_spatial.R).
#'   Off by default; `prediction_config(enabled = TRUE)` maps
#'   every fitted species onto the prediction grid after fitting.
#' @param baseline Character. The experiment every result is
#'   compared with, by id; NULL for none. Ignored by the baseline
#'   itself.
#' @param v2_bootstraps Integer. v2's draw count, which a run must
#'   reach to be gated.
#' @param regions Character vector of regions to fit, e.g.
#'   "north", or NULL for every region each spec defines.
#' @param metrics Character vector of registered metrics to score
#'   each draw with, or NULL for all of them (default_metrics()).
#' @param compare_metrics Character vector of prefixed metrics
#'   (e.g. "oob_auc") to compare with the baseline, or NULL for
#'   default_compare_metrics().
#' @param project_root Character. The repository root.
#' @param data_dir,pipeline_dir,out_dir Character, or NULL for
#'   test_dataset_dir(), 2_pipeline/<id> and 3_output/<id>.
#' @return A list of class `experiment_config`. Every problem
#'   found is reported in one error before anything is fitted.
#'
#' @example # Example usage of the function
#' # config <- experiment_config(
#' #   "exp_001_test",
#' #   species = "1_code/experiments/exp_001_test/species.csv",
#' #   n_bootstraps = 5
#' # )
experiment_config <- function(
  id,
  taxa = NULL,
  species = NULL,
  n_bootstraps = 100L,
  seed = 20260909L,
  stage_models = NULL,
  covariate_files = NULL,
  specs = NULL,
  plant_bootstrap = "spatial_block",
  workers = 1L,
  unit_predictions = "none",
  prediction = prediction_config(),
  baseline = "exp_000_parity_v2",
  v2_bootstraps = 100L,
  regions = NULL,
  metrics = NULL,
  compare_metrics = NULL,
  project_root = getOption("sdm.project_root", "."),
  data_dir = NULL,
  pipeline_dir = NULL,
  out_dir = NULL
) {
  # Problems are collected and reported together, so one run of
  # run.R shows everything to fix
  problems <- character(0)
  problem <- function(...) {
    problems <<- c(problems, paste0(...))
  }

  specs <- specs %||% standard_specs(plant_bootstrap)
  data_dir <- test_dataset_dir(data_dir)

  # Step 1: The species: the experiment's species.csv, or a
  # vector named by taxon
  species_file <- is.character(species) && length(species) == 1L &&
    is.null(names(species))
  focal <- species

  if (species_file) {
    focal <- tryCatch(
      read_species_file(species),
      error = function(e) {
        problem(conditionMessage(e))
        NULL
      }
    )
  }

  for (one in check_species_names(focal, data_dir)) {
    problem(one)
  }

  # Step 2: The runs. Without `taxa`, a species list names them:
  # only runs that fit a listed species, so editing species.csv
  # alone sets what runs.
  taxa_given <- !is.null(taxa)

  if (!taxa_given && !is.null(focal) && length(problems) == 0) {
    covered <- runs_for_species(specs, focal, data_dir)
    taxa <- names(specs)[vapply(covered, length, integer(1)) > 0]
    uncovered <- setdiff(
      paste(names(focal), focal),
      unlist(lapply(names(covered), function(key) {
        paste(specs[[key]]$taxon, covered[[key]])
      }))
    )

    if (length(uncovered) > 0) {
      problem(
        "No run fits ", paste(uncovered, collapse = ", "),
        " (e.g. a species not \"modelled\" in any region)."
      )
    }
  }

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

  # A run given in `taxa` whose taxon the list does not name runs
  # every species, so say so: it makes a partial list the longest
  # run
  if (taxa_given && !is.null(focal)) {
    slugs <- vapply(specs, `[[`, character(1), "taxon")
    unnamed <- names(slugs)[!slugs %in% names(focal)]

    if (length(unnamed) > 0) {
      message(
        "Note: ", paste(unnamed, collapse = ", "), " are not named ",
        "in the species list, so every species will be run for ",
        "them. Leave `taxa` out to run only the listed species."
      )
    }
  }

  # Step 3: The draw count, checked now rather than hours in
  if (!is.numeric(n_bootstraps) || length(n_bootstraps) != 1L ||
        is.na(n_bootstraps) || n_bootstraps < 1 ||
        n_bootstraps != round(n_bootstraps)) {
    problem(
      "n_bootstraps must be a single whole number of 1 or more."
    )
  } else {
    n_bootstraps <- as.integer(n_bootstraps)

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
        problem(
          "n_bootstraps is ", n_bootstraps, " but only ", stored,
          " ", spec$taxon, " draws are stored. Lower it, or drop `",
          key, "`."
        )
      }
    }
  }

  if (is.integer(n_bootstraps) && n_bootstraps < v2_bootstraps) {
    message(
      "Note: running ", n_bootstraps, " of ", v2_bootstraps,
      " v2 draws. This is a trial; its parity numbers are not a ",
      "parity read."
    )
  }

  # Step 4: Covariates the experiment adds from its own files.
  # Absolute paths, so parallel workers find them too.
  if (!is.null(covariate_files)) {
    covariate_files <- normalizePath(
      covariate_files, winslash = "/", mustWork = FALSE
    )
    files_ok <- tryCatch({
      check_covariate_files(covariate_files, data_dir)
      TRUE
    }, error = function(e) {
      problem(conditionMessage(e))
      FALSE
    })

    if (files_ok) {
      specs <- lapply(specs, function(spec) {
        spec$covariate_files <- covariate_files
        spec
      })
    }
  }

  # Step 5: Regions and metrics
  for (key in names(specs)) {
    absent <- setdiff(regions, names(specs[[key]]$regions))

    if (length(absent) > 0) {
      problem(
        "Run `", key, "` has no region(s) ",
        paste(absent, collapse = ", "), ". Its regions: ",
        paste(names(specs[[key]]$regions), collapse = ", "), "."
      )
    }
  }

  unknown_metrics <- setdiff(metrics, registered_names("metric"))

  if (length(unknown_metrics) > 0) {
    problem(
      "Unknown metric(s): ", paste(unknown_metrics, collapse = ", "),
      ". Registered: ",
      paste(registered_names("metric"), collapse = ", "), "."
    )
  }

  # Prefixed as the summaries are; v2val_ rows come from the plant
  # specs' own validation, not the registry
  compare_base <- sub("^(insample_|oob_)", "", compare_metrics)
  unknown_compare <- compare_metrics[
    !compare_base %in% registered_names("metric") &
      !startsWith(compare_base, "v2val_")
  ]

  if (length(unknown_compare) > 0) {
    problem(
      "Unknown compare_metrics: ",
      paste(unknown_compare, collapse = ", "), ". Use a registered ",
      "metric with an `oob_` or `insample_` prefix, e.g. oob_auc."
    )
  }

  # Step 5b: The prediction settings, and a grid to predict onto
  if (!inherits(prediction, "prediction_config")) {
    problem("`prediction` must be made by prediction_config().")
  } else if (isTRUE(prediction$enabled)) {
    tryCatch(
      prediction_grid_dir(prediction$grid_dir),
      error = function(e) problem(conditionMessage(e))
    )

    unmapped <- names(specs)[vapply(
      specs, function(s) is.null(s$spatial), logical(1)
    )]

    if (length(unmapped) > 0) {
      message(
        "Note: ", paste(unmapped, collapse = ", "), " have no ",
        "`spatial` settings and will not be mapped."
      )
    }
  }

  # Step 6: Every spec as it will run, and the covariates it
  # names, checked before any data is read
  for (key in names(specs)) {
    spec <- apply_stage_models(specs[[key]], stage_models)
    spec_problems <- validate_spec(spec, stop_on_error = FALSE)

    if (is.character(spec_problems)) {
      problem(
        "Run `", key, "`:\n    - ",
        paste(spec_problems, collapse = "\n    - ")
      )
      next
    }

    for (one in check_spec_covariates(
      spec, data_dir,
      regions = intersect(regions %||% names(spec$regions),
                          names(spec$regions)),
      label = key
    )) {
      problem(one)
    }
  }

  if (length(problems) > 0) {
    stop(
      "experiment_config() found ", length(problems),
      " problem(s):\n  - ", paste(problems, collapse = "\n  - "),
      call. = FALSE
    )
  }

  structure(
    list(
      id = id,
      taxa = taxa,
      specs = specs,
      # For the record: the file's name, "inline" or "all"
      species_set = if (species_file) {
        basename(species)
      } else if (is.null(focal)) {
        "all"
      } else {
        "inline"
      },
      focal_species = focal,
      n_bootstraps = n_bootstraps,
      v2_bootstraps = as.integer(v2_bootstraps),
      seed = seed,
      stage_models = stage_models,
      covariate_files = covariate_files,
      plant_bootstrap = plant_bootstrap,
      regions = regions,
      metrics = metrics,
      compare_metrics = compare_metrics,
      # Loaded by load_framework(hooks = ); workers load them too
      hooks = getOption("sdm.hook_files"),
      workers = as.integer(workers),
      unit_predictions = unit_predictions,
      prediction = prediction,
      # The baseline does not compare with itself
      baseline = if (identical(baseline, id)) NULL else baseline,
      project_root = project_root,
      data_dir = data_dir,
      pipeline_dir = pipeline_dir %||%
        file.path(project_root, "2_pipeline", id),
      out_dir = out_dir %||% file.path(project_root, "3_output", id)
    ),
    class = "experiment_config"
  )
}

## 2.1 runs_for_species() ----

#' Which Listed Species Each Run Fits
#'
#' A run fits a listed species when the species is in the run's
#' queue: its taxon, tier and, for mammals, season.
#'
#' @param specs Named list of specs.
#' @param species A species vector named by taxon.
#' @param data_dir Character. The test dataset folder.
#' @return A named list, one character vector of species per run
#'   (empty when the run fits none).
#'
#' @example # Example usage of the function
#' # runs_for_species(standard_specs(), c(mammal = "Moose_Summer"),
#' #                  data_dir)
runs_for_species <- function(specs, species, data_dir) {
  lapply(specs, function(spec) {
    listed <- unname(species[names(species) == spec$taxon])

    if (length(listed) == 0) {
      return(character(0))
    }

    intersect(listed, list_species(
      data_dir, spec$taxon, tier = spec$tier, season = spec$season
    ))
  })
}

## 2.2 print.experiment_config() ----

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
  changes <- experiment_changes(x)
  cat("  changes:  ", if (length(changes) == 0) {
    "none; every spec is v2's"
  } else {
    paste(changes, collapse = "\n            ")
  }, "\n", sep = "")
  if (!is.null(x$regions)) {
    cat("  regions:  ", paste(x$regions, collapse = ", "), "\n",
        sep = "")
  }
  if (!is.null(x$hooks)) {
    cat("  hooks:    ", paste(basename(x$hooks), collapse = ", "),
        "\n", sep = "")
  }
  cat("  workers:  ", x$workers, "\n", sep = "")
  cat("  predict:  ", prediction_label(x$prediction), "\n", sep = "")
  cat("  baseline: ", x$baseline %||% "none (this is the baseline)",
      "\n", sep = "")
  cat("  writes:   ", x$pipeline_dir, "\n            ", x$out_dir,
      "\n", sep = "")

  invisible(x)
}

# 3. run_experiment() ----

#' Fit, Summarize, Compare with the Baseline, Run the
#' Experiment's Steps, and Record
#'
#' @param config An experiment_config().
#' @param fit Logical. FALSE skips fitting and re-summarizes the
#'   stores already in pipeline_dir.
#' @param predict Logical or NULL. Map the stored models onto the
#'   prediction grid (run_spatial_predictions()). NULL follows
#'   `config$prediction$enabled`; with `fit = FALSE` this re-maps
#'   existing stores without refitting.
#' @param steps Named list of functions, run in order after the
#'   summary tables are written. Each takes `config` and
#'   `results` and returns `results`, which it may add to.
#' @param translate Named list of coefficient translations by
#'   taxon, passed to collect_results().
#' @param record Logical. Write run_record.md.
#' @return The results list, invisibly: the summary tables, the
#'   run log, the comparison with the baseline, and whatever the
#'   steps added.
#'
#' @example # Example usage of the function
#' # results <- run_experiment(config)
run_experiment <- function(
  config,
  fit = TRUE,
  predict = NULL,
  steps = list(),
  translate = list(),
  record = TRUE
) {
  started <- Sys.time()
  predict <- predict %||% isTRUE(config$prediction$enabled)

  # Asked for here but off in the config: predict with its other
  # settings
  if (predict) {
    config$prediction$enabled <- TRUE
  }

  print(config)

  # Step 1: Fit
  run_log <- NULL

  if (fit) {
    run_log <- run_specs(
      specs = config$specs,
      data_dir = config$data_dir,
      pipeline_dir = config$pipeline_dir,
      species = config$focal_species,
      regions = config$regions,
      iterations = seq_len(config$n_bootstraps),
      stage_models = config$stage_models,
      metrics = config$metrics,
      boot_seed = config$seed,
      workers = config$workers,
      unit_predictions = config$unit_predictions,
      # Engines without coefficients keep their fitted objects,
      # so they can be mapped (predict_spatial.R)
      save_models = isTRUE(config$prediction$enabled)
    )

    fwrite(run_log, file.path(config$pipeline_dir, "run_log.csv"),
           na = "")
    # The full session, beside the stores it produced
    writeLines(
      utils::capture.output(utils::sessionInfo()),
      file.path(config$pipeline_dir, "session_info.txt")
    )
    cat("\nRun log:\n")
    print(table(run_log$taxon, run_log$status))
  }

  # Step 1b: Map the fitted models onto the prediction grid
  prediction <- NULL

  if (predict) {
    cat("\n== predict ==\n")
    prediction <- run_spatial_predictions(config)
  }

  # Step 2: Summarize the stores
  results <- collect_results(
    config$pipeline_dir, config$data_dir, translate = translate
  )
  results$run_log <- run_log
  results$prediction <- prediction
  write_summaries(results, config$out_dir)

  # Step 3: Compare with the baseline, for every experiment but
  # the baseline itself
  if (!is.null(config$baseline)) {
    cat("\n== compare with ", config$baseline, " ==\n", sep = "")
    results <- compare_to_baseline(config, results)
  }

  # Step 4: The experiment's own steps, in order
  for (name in names(steps)) {
    cat("\n== ", name, " ==\n", sep = "")
    results <- steps[[name]](config, results)
  }

  # Step 5: The committed record of what ran
  if (record) {
    record_file <- run_record(
      pipeline_dir = config$pipeline_dir,
      out_file = file.path(config$out_dir, "run_record.md"),
      exp_id = config$id,
      config = record_config(config, run_log),
      collected = results,
      hook_files = config$hooks
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
#' Settings, not absolute paths, which differ between machines.
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
    species_file = config$species_set,
    regions = config$regions %||% "all",
    metrics = config$metrics %||% "all registered",
    compare_metrics = config$compare_metrics %||%
      default_compare_metrics(),
    hooks = if (is.null(config$hooks)) {
      "none"
    } else {
      basename(config$hooks)
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
    covariate_files = if (is.null(config$covariate_files)) {
      "none"
    } else {
      basename(config$covariate_files)
    },
    changes_from_v2 = {
      changes <- experiment_changes(config)
      if (length(changes) == 0) "none" else changes
    },
    engines = stage_values("engine"),
    selection = stage_values("selection"),
    compared_with = config$baseline %||% "none (baseline)",
    data_dir = published_label(config$data_dir),
    prediction = prediction_label(config$prediction %||%
                                    prediction_config())
  )

  # The grid a mapping read, when there was one
  if (isTRUE(config$prediction$enabled)) {
    out$prediction_grid <- published_label(
      prediction_grid_dir(config$prediction$grid_dir, check = FALSE)
    )
  }

  # Record failures, or a run that lost jobs looks complete
  if (!is.null(run_log)) {
    ok <- sum(run_log$status == "ok", na.rm = TRUE)
    out$jobs_total <- nrow(run_log)
    out$jobs_ok <- ok
    out$jobs_not_ok <- nrow(run_log) - ok
  }

  out
}

## 4.1 experiment_changes() ----

#' What an Experiment Changes from the v2 Specs
#'
#' Changes made through `stage_models`, and through specs changed
#' with replace_stage_method(), which records them.
#'
#' @param config An experiment_config().
#' @return A character vector, one entry per run and change.
#'
#' @example # Example usage of the function
#' # experiment_changes(config)
experiment_changes <- function(config) {
  from_specs <- unlist(lapply(names(config$specs), function(key) {
    changed <- config$specs[[key]]$models_overridden

    if (is.null(changed)) NULL else paste0(key, ": ", changed)
  }))

  from_models <- if (is.null(config$stage_models)) {
    NULL
  } else {
    paste0("stage_models: ", names(config$stage_models))
  }

  from_files <- if (is.null(config$covariate_files)) {
    NULL
  } else {
    paste0("covariate_files: ", basename(config$covariate_files))
  }

  c(from_specs, from_models, from_files)
}

# 5. compare_to_baseline() ----

#' Compare an Experiment's Summaries with the Baseline's
#'
#' Writes tables/comparison_metrics.csv and prints the headline
#' (see compare_experiments()). A baseline not yet run is
#' reported and skipped, not an error.
#'
#' @param config An experiment_config().
#' @param results The results so far.
#' @param baseline Character. The baseline experiment's id.
#' @return `results`, with `comparison` added when there was a
#'   baseline to compare with.
#'
#' @example # Example usage of the function
#' # results <- compare_to_baseline(config, results)
compare_to_baseline <- function(
  config, results, baseline = config$baseline
) {
  baseline_dir <- file.path(
    config$project_root, "3_output", baseline
  )
  baseline_table <- file.path(
    baseline_dir, "tables", "metric_summary.csv"
  )

  if (!file.exists(baseline_table)) {
    message(
      "No comparison: ", baseline, " has no summary tables yet. ",
      "Run it first, then re-summarize this experiment with ",
      "run_experiment(config, fit = FALSE)."
    )
    return(results)
  }

  compared <- config$compare_metrics %||% default_compare_metrics()
  comparison <- compare_experiments(
    candidate_dir = config$out_dir,
    baseline_dir = baseline_dir,
    metrics = compared
  )

  # The headline, for the console; per-species rows are written.
  # An experiment's own metrics are shown when it names no default.
  headline <- intersect(
    c("oob_auc", "oob_deviance_explained", "oob_calibration_slope"),
    compared
  )
  shown <- comparison$summary[
    comparison$summary$metric %in% (if (length(headline) > 0) {
      headline
    } else {
      compared
    }),
    c("taxon", "region", "metric", "median_baseline",
      "median_candidate", "median_difference", "share_better")
  ]
  numbers <- vapply(shown, is.numeric, logical(1))
  shown[numbers] <- lapply(shown[numbers], round, 3)

  cat(
    "Against ", baseline,
    " (out-of-bag; per species in comparison_metrics.csv):\n",
    sep = ""
  )
  print(shown, row.names = FALSE)

  results$comparison <- comparison
  results
}

# 6. script_step() ----

#' Turn an Experiment Script into a Step
#'
#' Runs the script in a fresh environment (parent: global)
#' holding `config` and `results`, so it leaves nothing behind,
#' and returns the updated `results`.
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
