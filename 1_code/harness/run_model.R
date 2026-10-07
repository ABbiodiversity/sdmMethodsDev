# ---
# title: Run Taxon Specs
# author: Brendan Casey
# created: 2026-09-09
# inputs:
#   specs from 1_code/modules/<taxon>/spec.R
#   the harmonized test dataset
# outputs:
#   in each run directory, one result store per region; see
#   result.R
# notes:
#   - The spec-driven loop; names no taxon. prepare_spec() loads
#     each region once; fit_species() is the unit of (parallel)
#     work; merge_spec_shards() joins shards in queue order.
#   - Stages run in order; `carry_as` passes a stage's prediction
#     forward (v2's `Climate` term).
#   - Per-species seeds make parallel and serial runs identical.
#   - A failed species or draw is logged and the run continues.
# ---

# 1. Setup ----

## 1.1 Load packages ----
# parallel (base R), when `workers` is above 1.

# 2. run_specs() and run_spec() ----

## 2.1 run_specs() ----

#' Run Several Specs Through One Pool of Workers
#'
#' Every species of every spec is one job, so few species per
#' taxon still keeps every worker busy.
#'
#' @param specs A named list of taxon specs. The names name the
#'   runs, and so the folders under `pipeline_dir`.
#' @param data_dir Character. The test dataset folder.
#' @param pipeline_dir Character. Each spec writes to
#'   `pipeline_dir/<name>/<region>/`.
#' @param species Character vector of focal species, named by
#'   taxon (see taxon_values()), or NULL for every species each
#'   spec's queue declares.
#' @param regions Character vector of regions to run, or NULL for
#'   all each spec defines.
#' @param iterations Integer vector of resampling iterations.
#' @param stage_models Named list of replacement candidate sets,
#'   or NULL; see apply_stage_models().
#' @param metrics Character vector of metric names, or NULL for
#'   default_metrics().
#' @param boot_seed Integer or NULL. The base seed; NULL falls
#'   back to `spec$resample$seed`, then to unseeded (as v2).
#' @param workers Integer. Species fitted at once. 1 runs in this
#'   session; more start background R sessions.
#' @param unit_predictions Character. "none", "oob" or "all"; see
#'   result_store().
#' @param verbose Logical. Report progress.
#' @return A data frame, one row per spec, species, region and
#'   draw, recording what happened.
#'
#' @example # Example usage of the function
#' # run_specs(list(lichen = lichen_spec()), data_dir,
#' #           "2_pipeline/exp_001", iterations = 1:5, workers = 4)
run_specs <- function(
  specs,
  data_dir,
  pipeline_dir,
  species = NULL,
  regions = NULL,
  iterations = 1:100,
  stage_models = NULL,
  metrics = NULL,
  boot_seed = NULL,
  workers = 1L,
  unit_predictions = c("none", "oob", "all"),
  verbose = TRUE
) {
  unit_predictions <- match.arg(unit_predictions)

  if (is.null(names(specs)) || any(!nzchar(names(specs)))) {
    stop("`specs` must be a named list; the names name the runs.",
         call. = FALSE)
  }

  # Step 1: Prepare every spec first, so a bad spec fails early
  prepared <- lapply(stats::setNames(names(specs), names(specs)),
                     function(key) {
    prepare_spec(
      spec = specs[[key]], key = key, data_dir = data_dir,
      run_dir = file.path(pipeline_dir, key), species = species,
      regions = regions, iterations = iterations,
      stage_models = stage_models, metrics = metrics,
      boot_seed = boot_seed, unit_predictions = unit_predictions
    )
  })

  # Step 2: One job per spec and species
  jobs <- unlist(lapply(prepared, function(p) {
    lapply(p$species, function(one) list(key = p$key, species = one))
  }), recursive = FALSE)

  if (verbose) {
    cat(
      "Fitting ", length(jobs), " species across ", length(specs),
      " spec(s), ", length(iterations), " draw(s) each, on ",
      workers, " worker(s)\n",
      sep = ""
    )
  }

  logs <- run_jobs(jobs, prepared, workers, verbose)

  # Step 3: Join each spec's shards into its region stores
  for (p in prepared) {
    merge_spec_shards(p)
  }

  log <- do.call(rbind, logs)
  rownames(log) <- NULL

  log
}

## 2.2 run_spec() ----

#' Run One Spec
#'
#' run_specs() for a single spec, writing to `run_dir/<region>/`.
#'
#' @param spec A taxon spec.
#' @param data_dir Character. The test dataset folder.
#' @param run_dir Character. Where the region stores go.
#' @param ... Passed to run_specs(): species, regions,
#'   iterations, stage_models, metrics, boot_seed, workers,
#'   unit_predictions, verbose.
#' @return As run_specs().
#'
#' @example # Example usage of the function
#' # run_spec(bryophyte_spec(), data_dir, run_dir,
#' #          species = c("Aulacomnium.palustre"),
#' #          iterations = 1:5)
run_spec <- function(spec, data_dir, run_dir, ...) {
  run_specs(
    specs = stats::setNames(list(spec), basename(run_dir)),
    data_dir = data_dir,
    pipeline_dir = dirname(run_dir),
    ...
  )
}

# 3. Preparing a spec ----

## 3.1 prepare_spec() ----

#' Check a Spec and Load What Its Regions Need
#'
#' @param spec A taxon spec.
#' @param key Character. The run's name.
#' @param data_dir,run_dir Character.
#' @param species,regions,iterations,stage_models,metrics,boot_seed
#'   As in run_specs().
#' @param unit_predictions Character.
#' @return A list: the spec, its regions (each with its data,
#'   grid and species), the province-wide data, the species to
#'   fit, and the run settings a worker needs.
#'
#' @example # Example usage of the function
#' # p <- prepare_spec(lichen_spec(), "lichen", data_dir, run_dir)
prepare_spec <- function(
  spec, key, data_dir, run_dir, species = NULL, regions = NULL,
  iterations = 1:100, stage_models = NULL, metrics = NULL,
  boot_seed = NULL, unit_predictions = "none"
) {
  # Before any read, so covariates follow the replacement sets
  spec <- apply_stage_models(spec, stage_models)

  validate_spec(spec)

  # The experiment's seed wins over the spec's
  base_seed <- boot_seed %||% spec$resample$seed

  # Step 1: The species. Named species are validated against the
  # whole taxon, then intersected per region (a species may be
  # modelled in one region only).
  species <- taxon_values(species, spec$taxon) %||% species

  if (!is.null(species)) {
    species <- unname(species)
    resolve_species(species, data_dir, spec$taxon, tier = spec$tier)
  }

  regions <- regions %||% names(spec$regions)
  unknown_regions <- setdiff(regions, names(spec$regions))

  if (length(unknown_regions) > 0) {
    stop(
      "Spec for ", spec$taxon, " defines no region(s) ",
      paste(unknown_regions, collapse = ", "), ". Regions: ",
      paste(names(spec$regions), collapse = ", "),
      call. = FALSE
    )
  }

  named_regions <- stats::setNames(regions, regions)
  region_species <- lapply(named_regions, function(r) {
    available <- list_species(
      data_dir, spec$taxon, region = r, tier = spec$tier,
      season = spec$season
    )

    if (is.null(species)) available else intersect(available, species)
  })

  all_species <- unique(unlist(region_species, use.names = FALSE))

  # Step 2: Each region's stages, data and grid, loaded once
  prepared_regions <- lapply(
    regions[lengths(region_species[regions]) > 0],
    function(r) {
      prepare_region(spec, r, region_species[[r]], data_dir)
    }
  )
  names(prepared_regions) <- vapply(
    prepared_regions, `[[`, character(1), "name"
  )

  list(
    key = key,
    spec = spec,
    data_dir = data_dir,
    run_dir = run_dir,
    shard_dir = file.path(run_dir, "_shards"),
    regions = prepared_regions,
    province = province_context(spec, data_dir, all_species),
    species = all_species,
    iterations = iterations,
    base_seed = base_seed,
    metrics = metrics,
    unit_predictions = unit_predictions
  )
}

## 3.2 prepare_region() ----

#' Resolve One Region's Stages and Load Its Data and Grid
#'
#' A stage with no models takes the region's (veg in the north,
#' soil in the south). Formula terms are rewritten to the
#' dataset's block-suffixed names (see term_map()).
#'
#' @param spec A taxon spec.
#' @param region Character.
#' @param species Character vector of the region's species.
#' @param data_dir Character.
#' @return A list of the region's name, spec (with resolved
#'   stages), species, model data, grid, grid name, weight column
#'   and covariates.
#'
#' @example # Example usage of the function
#' # prepare_region(lichen_spec(), "north", "Physcia.adscendens",
#' #                data_dir)
prepare_region <- function(spec, region, species, data_dir) {
  region_spec <- spec$regions[[region]]
  rename <- term_map(
    data_dir, spec$taxon, region, block = region_spec$term_block
  )

  # Step 1: The stages, with the region's models where a stage
  # takes them, and every formula in the dataset's names
  spec$stages <- lapply(spec$stages, function(stage) {
    if (is.null(stage$models)) {
      # Plus what goes with them: reference categories,
      # constants, and columns the age splines read
      stage$models <- region_spec$habitat_models
      stage$intercept_cats <- region_spec$intercept_cats %||%
        stage$intercept_cats
      stage$constants <- region_spec$constants %||% stage$constants
      stage$extra_covariates <- c(
        stage$extra_covariates, region_spec$extra_covariates
      )

      # Terms held fixed on the grid can be added per region: v2
      # predicts the south at pAspen = 0.
      if (!is.null(region_spec$grid_constants)) {
        stage$grid_constants <- c(
          stage$grid_constants %||% list(),
          region_spec$grid_constants
        )
      }
    }

    stage$models <- apply_term_map(
      get_model_set(stage$models), rename
    )

    stage
  })

  # Step 2: The columns to load
  weight_column <- region_spec$weight_column %||% spec$weight_column
  covariates <- covariate_request(
    spec, spec_covariates(spec), region_spec$filter
  )

  # Step 3: Load once for the region; species are cut from it
  model_data <- build_model_data(
    taxon = spec$taxon,
    data_dir = data_dir,
    species = species,
    covariates = covariates,
    region = region,
    region_filter = region_spec$filter,
    weight_column = weight_column,
    aliases = spec$aliases %||% list(),
    covariate_files = spec$covariate_files
  )

  # Step 4: The grid (the spec's, else the manifest's). Columns
  # are renamed to the data's names; row names stay as v2 wrote
  # them.
  grid_name <- region_spec$grid %||%
    manifest_entry(data_dir, spec$taxon, region)$grid
  grid <- load_prediction_grid(data_dir, grid_name)

  if (!is.null(grid)) {
    names(grid) <- apply_term_map(names(grid), rename)

    # e.g. v2 drops the mammal north's WetlandMargin and Climate
    grid <- grid[
      !rownames(grid) %in% region_spec$grid_drop_rows,
      !names(grid) %in% region_spec$grid_drop_cols,
      drop = FALSE
    ]
  }

  list(
    name = region,
    spec = spec,
    species = species,
    model_data = model_data,
    grid = grid,
    grid_name = grid_name,
    weight_column = weight_column,
    covariates = covariates
  )
}

## 3.3 province_context() ----

#' Assemble the Province-Wide Data a Spec's Province Scope Needs
#'
#' v2 fits plant and bird climate stages, and draws the plant
#' bootstrap, province-wide; only habitat is per region. Specs
#' declare this with `scope = "province"`. Loads the unfiltered
#' data once per spec.
#'
#' @param spec A taxon spec, with stage models already resolved.
#' @param data_dir Character.
#' @param species Character vector of the species to model.
#' @return A list of `model_data`, `stages` and `draws`, or NULL
#'   when the spec has no province scope.
#'
#' @example # Example usage of the function
#' # province_context(spec, data_dir, c("Physcia.adscendens"))
province_context <- function(spec, data_dir, species) {
  province_stages <- Filter(
    function(s) identical(s$scope, "province"), spec$stages
  )
  province_draws <- identical(spec$resample$scope, "province")

  if ((length(province_stages) == 0 && !province_draws) ||
        length(species) == 0) {
    return(NULL)
  }

  # Province stages run first, so cannot carry from region stages
  for (stage in province_stages) {
    if (!is.null(stage$carry_from) || is.null(stage$models)) {
      stop(
        "Stage `", stage$name, "` has province scope, so it must ",
        "come first and name its own models.",
        call. = FALSE
      )
    }
  }

  stage_names <- vapply(province_stages, `[[`, character(1), "name")
  covariates <- if (length(stage_names) > 0) {
    spec_covariates(spec, stage_names = stage_names)
  } else {
    character(0)
  }

  # v2's redraw rule evaluates region filters on this frame
  filters <- lapply(spec$regions, `[[`, "filter")
  covariates <- covariate_request(spec, covariates, filters)

  list(
    model_data = build_model_data(
      taxon = spec$taxon,
      data_dir = data_dir,
      species = species,
      covariates = covariates,
      region = NULL,
      region_filter = NULL,
      weight_column = NULL,
      aliases = spec$aliases %||% list(),
      covariate_files = spec$covariate_files
    ),
    stages = province_stages,
    draws = province_draws
  )
}

## 3.4 covariate_request() ----

#' The Columns to Load, Given the Covariates the Formulas Name
#'
#' Adds the stored-draw key and region-filter columns; drops
#' aliases and site fields, which do not come from
#' covariates.csv.
#'
#' @param spec A taxon spec.
#' @param covariates Character vector from spec_covariates().
#' @param filters A one-sided formula, a list of them, or NULL.
#' @return A character vector of covariate names.
#'
#' @example # Example usage of the function
#' # covariate_request(spec, spec_covariates(spec), ~ useNorth == 1)
covariate_request <- function(spec, covariates, filters = NULL) {
  if (inherits(filters, "formula")) {
    filters <- list(filters)
  }

  filter_terms <- unlist(lapply(filters, function(one) {
    if (is.null(one)) character(0) else all.vars(one)
  }))

  covariates <- setdiff(
    covariates, c(names(spec$aliases), unlist(spec$aliases))
  )

  unique(c(
    covariates,
    spec$resample$id_column,
    setdiff(filter_terms, c(site_columns(), "survey_unit_id"))
  ))
}

# 4. Fitting one species ----

## 4.1 run_jobs() ----

#' Fit Every Job, in This Session or in Parallel
#'
#' In parallel, jobs are handed out as workers free up, so a
#' slow species does not hold up the rest.
#'
#' @param jobs List of `key` and `species` pairs.
#' @param prepared Named list of prepare_spec() results.
#' @param workers Integer.
#' @param verbose Logical.
#' @return A list of log data frames, one per job, in job order.
#'
#' @example # Example usage of the function
#' # run_jobs(jobs, prepared, workers = 4)
run_jobs <- function(jobs, prepared, workers = 1L, verbose = TRUE) {
  if (workers <= 1L || length(jobs) <= 1L) {
    return(lapply(jobs, function(job) {
      log <- fit_species(job$species, prepared[[job$key]])
      if (verbose) cat(".")
      log
    }))
  }

  project_root <- getOption("sdm.project_root")

  if (is.null(project_root)) {
    stop("Parallel runs need load_framework() to have been ",
         "called, so workers can load it too.", call. = FALSE)
  }

  # Step 1: Start the workers and load the framework
  cluster <- parallel::makePSOCKcluster(min(workers, length(jobs)))
  on.exit(parallel::stopCluster(cluster), add = TRUE)

  parallel::clusterCall(cluster, load_worker, project_root)

  # Step 2: Each job carries only its own spec's prepared data
  tasks <- lapply(jobs, function(job) {
    list(species = job$species, prepared = prepared[[job$key]])
  })

  parallel::clusterApplyLB(cluster, tasks, fit_species_worker)
}

## 4.2 load_worker() ----

#' Load the Framework in a Background Session
#'
#' @param project_root Character. The repository root.
#' @return NULL, invisibly.
#'
#' @example # Example usage of the function
#' # parallel::clusterCall(cluster, load_worker, root)
load_worker <- function(project_root) {
  session <- globalenv()

  source(
    file.path(project_root, "1_code", "harness", "harness.R"),
    local = session
  )
  load <- get("load_framework", envir = session)
  load(project_root, envir = session)

  invisible(NULL)
}

## 4.3 fit_species_worker() ----

#' Fit One Job in a Background Session
#'
#' Self-contained, so a worker needs only the job.
#'
#' @param task List of `species` and `prepared`.
#' @return The job's log data frame.
#'
#' @example # Example usage of the function
#' # fit_species_worker(task)
fit_species_worker <- function(task) {
  get("fit_species", envir = globalenv())(task$species, task$prepared)
}

## 4.4 fit_species() ----

#' Fit One Species in Every Region of a Spec
#'
#' Writes a shard store per region. Province-wide draws and
#' stage fits are made once and shared by the regions.
#'
#' @param species Character.
#' @param p A prepare_spec() result.
#' @return A data frame, one row per region and draw.
#'
#' @example # Example usage of the function
#' # fit_species("Physcia.adscendens", prepared$lichen)
fit_species <- function(species, p) {
  spec <- p$spec
  seed <- species_seed(p$base_seed, spec$taxon, species)
  logs <- list()

  log_all <- function(region, status, note) {
    data.frame(
      taxon = spec$taxon, species = species, region = region,
      boot = as.integer(p$iterations), status = status, note = note,
      stringsAsFactors = FALSE
    )
  }

  # Step 1: Province-wide frame and draws, if any. A species
  # whose draws cannot be made is logged and skipped.
  province <- NULL
  province_fits <- list()

  if (!is.null(p$province)) {
    province <- list(frame = model_frame(
      p$province$model_data, species = species,
      transform = spec$response_transform %||% "identity"
    ))

    if (p$province$draws) {
      province$draws <- tryCatch(
        resample_for_species(
          spec, province$frame, p$iterations, p$data_dir,
          seed = seed, species = species
        ),
        error = function(e) conditionMessage(e)
      )
    }
  }

  for (region in p$regions) {
    if (!species %in% region$species) {
      next
    }

    shard <- result_store(
      file.path(p$shard_dir, region$name, safe_name(species)),
      header = FALSE, unit_predictions = p$unit_predictions
    )

    frame <- model_frame(
      region$model_data, species = species,
      transform = spec$response_transform %||% "identity",
      weight_column = region$weight_column
    )

    # Per-species columns (e.g. mammal precomputed climate)
    if (is.function(spec$species_frame)) {
      frame <- spec$species_frame(frame, species, p$data_dir, spec)
    }

    # Step 2: The draws. Province-wide draws are filtered to the
    # region's units when fitted, as v2 subsets them.
    draws <- if (!is.null(province$draws)) {
      province$draws
    } else {
      tryCatch(
        resample_for_species(
          spec, frame, p$iterations, p$data_dir,
          seed = seed, species = species
        ),
        error = function(e) conditionMessage(e)
      )
    }

    if (is.character(draws)) {
      logs[[region$name]] <- log_all(
        region$name, "resample_failed", draws
      )
      next
    }

    # Step 3: Every draw, fitting province stages once per draw
    outcomes <- lapply(seq_along(p$iterations), function(i) {
      boot <- p$iterations[i]
      fixed <- NULL

      if (!is.null(province) && length(p$province$stages) > 0) {
        key <- as.character(boot)

        if (is.null(province_fits[[key]])) {
          province_fits[[key]] <<- fit_province_stages(
            p$province$stages, province$frame, draws[[i]], spec,
            species
          )
        }

        fixed <- province_fits[[key]]
      }

      run_one_draw(
        spec = region$spec, frame = frame, draw = draws[[i]],
        store = shard, species = species, region = region$name,
        boot = boot, grid = region$grid, metrics = p$metrics,
        fixed = fixed,
        validation_frame = province$frame
      )
    })

    logs[[region$name]] <- do.call(rbind, outcomes)
  }

  do.call(rbind, logs)
}

## 4.5 fit_province_stages() ----

#' Fit the Province-Scope Stages on One Draw
#'
#' @param stages List of province-scope stages.
#' @param frame The species' province-wide frame.
#' @param draw Character vector of survey unit ids.
#' @param spec The taxon spec.
#' @param species Character.
#' @return A named list of fit_one_stage() results.
#'
#' @example # Example usage of the function
#' # fit_province_stages(stages, frame, draws[[1]], spec, sp)
fit_province_stages <- function(stages, frame, draw, spec, species) {
  rows <- match(draw, frame$survey_unit_id)
  fitting <- frame[rows[!is.na(rows)], , drop = FALSE]

  fits <- lapply(stages, function(stage) {
    tryCatch(
      fit_one_stage(stage, fitting, spec, NULL, species),
      error = function(e) {
        list(status = "error", note = conditionMessage(e),
             selected = NULL)
      }
    )
  })

  stats::setNames(fits, vapply(stages, `[[`, character(1), "name"))
}

# 5. Fitting one draw ----

## 5.1 run_stage() ----

#' Fit One Stage on One Draw
#'
#' @param stage A stage definition from a spec.
#' @param data A data frame for one species and one draw.
#' @param spec The taxon spec.
#' @param offset Numeric vector or NULL.
#' @param weights Numeric vector or NULL.
#' @param grid A prediction grid, or NULL.
#' @param species Character. Passed to a rule that declares it.
#' @return A selection result.
#'
#' @example # Example usage of the function
#' # run_stage(spec$stages[[1]], d, spec)
run_stage <- function(
  stage, data, spec, offset = NULL, weights = NULL,
  grid = NULL, species = NA_character_
) {
  models <- get_model_set(stage$models)
  response <- spec$response_name %||% "response"

  # Text to formulas; staged rules take groups
  as_formulas <- function(x) {
    if (is.list(x)) {
      return(lapply(x, as_formulas))
    }

    lapply(x, stats::as.formula)
  }

  # The offset goes in the formula: an offset argument is not
  # applied by predict() to new data (R recycles the fitted one).
  # `base_terms` start every candidate from given terms, as v2's
  # bird landcover selection starts from `count ~ climate`.
  base <- stats::as.formula(paste(
    response, "~", paste(c("1", stage$base_terms), collapse = " + "),
    if (is.null(offset)) "" else "+ offset(offset)"
  ))

  # Stage fields the rule declares are passed by name
  rule <- if (is.function(stage$selection)) {
    stage$selection
  } else {
    get_method("selection", stage$selection)
  }

  core <- c(
    "models", "base", "data", "engine", "family", "weights",
    "offset", "ic", "control"
  )
  settings <- stage[
    setdiff(intersect(names(stage), names(formals(rule))), core)
  ]

  if (!is.null(settings$intercept_cats)) {
    settings$intercept_cats <- get_model_set(settings$intercept_cats)
  }

  do.call(selection_run, c(
    list(
      rule = stage$selection,
      models = as_formulas(models),
      base = base,
      data = data,
      engine = get_engine(stage$engine),
      family = stage$family %||% spec$family,
      weights = weights,
      offset = NULL,
      ic = stage$ic %||% "AICc",
      control = stage$control %||% list()
    ),
    settings,
    # Harness-supplied, only to rules that declare them
    list(
      grid = grid,
      species = species,
      stage = stage,
      calibrate_against = if (isTRUE(stage$calibrate)) {
        data[[response]]
      } else {
        NULL
      }
    )
  ))
}

## 5.2 fit_one_stage() ----

#' Prepare One Stage's Data and Fit It
#'
#' Shared by region-scope and province-scope stages.
#'
#' @param stage A stage definition.
#' @param fitting The draw's rows, with any carried stage added.
#' @param spec The taxon spec.
#' @param grid A prediction grid, or NULL.
#' @param species Character. Passed to a rule that declares it.
#' @return A list of `status` ("ok" or why not), `note` and
#'   `selected`.
#'
#' @example # Example usage of the function
#' # fit_one_stage(spec$stages[[1]], fitting, spec, NULL)
fit_one_stage <- function(stage, fitting, spec, grid = NULL,
                          species = NA_character_) {
  failed <- function(status) {
    list(status = status, note = stage$name, selected = NULL)
  }

  response_name <- spec$response_name %||% "response"
  stage_data <- fitting

  # Stage-specific response transform, from the raw values
  raw_name <- paste0(response_name, "_raw")

  if (!is.null(stage$response_transform) &&
        raw_name %in% names(stage_data)) {
    stage_data[[response_name]] <- apply_response_transform(
      stage_data[[raw_name]], stage$response_transform, stage_data
    )
  }

  # Row subset, e.g. the mammal abundance half fits only units
  # where the species was seen
  if (!is.null(stage$row_filter)) {
    keep <- stage$row_filter(stage_data)
    keep[is.na(keep)] <- FALSE
    stage_data <- stage_data[keep, , drop = FALSE]

    if (nrow(stage_data) < 2) {
      return(failed("too_few_rows"))
    }
  }

  # v2 skips a plant habitat model with fewer than 20
  # detections in the filtered draw
  if (!is.null(stage$min_detections)) {
    detections <- sum(stage_data[[response_name]] > 0, na.rm = TRUE)

    if (detections < stage$min_detections) {
      return(failed("too_few_detections"))
    }
  }

  # Weights apply unless a stage opts out. The bird climate stage
  # is unweighted in v2; its landcover stage is weighted.
  weights <- if (!isFALSE(stage$weighted) &&
                   "weight" %in% names(stage_data)) {
    stage_data$weight
  } else {
    NULL
  }

  selected <- run_stage(
    stage = stage, data = stage_data, spec = spec, grid = grid,
    species = species,
    offset = if ("offset" %in% names(stage_data)) {
      stage_data$offset
    } else {
      NULL
    },
    weights = weights
  )

  if (is.null(selected$fit) || !isTRUE(selected$fit$ok)) {
    return(failed("stage_failed"))
  }

  # Spec-supplied post-processing, in order (e.g. plant stand-age
  # splines, cutblock convergence, footprint pooling). Steps that
  # declare `grid`, `species` or `stage` are given them.
  for (step in stage$post_process) {
    context <- list(grid = grid, species = species, stage = stage)
    context <- context[names(context) %in% names(formals(step))]
    selected <- do.call(step, c(list(selected, stage_data), context))
  }

  list(status = "ok", note = NA_character_, selected = selected)
}

## 5.3 carry_values() ----

#' The Value a Stage Hands the Next One
#'
#' From the stage's final (averaged) model, not its best
#' candidate: averaged coefficients applied to the data, as v2
#' does, or the final model's prediction for engines without
#' coefficients.
#'
#' @param selected A selection result.
#' @param data The rows to compute it for.
#' @param stage The stage being carried.
#' @return A numeric vector, one per row.
#'
#' @example # Example usage of the function
#' # carry_values(selected, fitting, stage)
carry_values <- function(selected, data, stage) {
  link <- if (!is.null(selected$coefficients)) {
    predict_from_coefficients(selected$coefficients, data, "link")
  } else {
    selected$predict(data, "link")
  }

  # v2's bird climate is carried without the QPAD offset, as
  # MuMIn predicts it; a stage can ask for the offset to be added.
  if (isTRUE(stage$carry_offset) && "offset" %in% names(data)) {
    link <- link + data$offset
  }

  switch(
    stage$carry_scale %||% "response",
    # v2's plant models carry the probability, 0 to 1
    response = stats::plogis(link),
    link = link,
    # v2's bird inv.link, bounded as v2 bounds it
    exp = pmin(pmax(exp(link), .Machine$double.eps),
               .Machine$double.xmax),
    stop("Unknown carry_scale `", stage$carry_scale, "`.",
         call. = FALSE)
  )
}

## 5.4 run_one_draw() ----

#' Fit Every Stage on One Species and One Draw
#'
#' @param spec A taxon spec, with the region's stages.
#' @param frame The full one-species frame for the region.
#' @param draw Character vector of survey unit ids in the draw.
#'   Ids not in the frame are dropped (repeats kept), as v2
#'   filters province-wide draws per region.
#' @param store A result_store().
#' @param species,region Character.
#' @param boot Integer.
#' @param grid A prediction grid, or NULL.
#' @param metrics Character vector of metric names, or NULL.
#' @param fixed Named list of fit_one_stage() results for stages
#'   already fitted at province scope, or NULL.
#' @param validation_frame The province-wide frame, or NULL;
#'   passed to the spec's `validate` function.
#' @return A one-row data frame recording the outcome.
#'
#' @example # Example usage of the function
#' # run_one_draw(spec, frame, draw, store, sp, "north", 1, grid,
#' #              NULL)
run_one_draw <- function(
  spec, frame, draw, store, species, region, boot, grid,
  metrics, fixed = NULL, validation_frame = NULL
) {
  outcome <- function(status, note = NA_character_) {
    data.frame(
      taxon = spec$taxon, species = species, region = region,
      boot = as.integer(boot), status = status, note = note,
      stringsAsFactors = FALSE
    )
  }

  rows <- match(draw, frame$survey_unit_id)
  rows <- rows[!is.na(rows)]

  if (length(rows) == 0) {
    return(outcome("empty_draw"))
  }

  fitting <- frame[rows, , drop = FALSE]
  response_name <- spec$response_name %||% "response"

  # Step 1: Fit the stages in order
  result <- tryCatch({
    carried <- NULL
    last <- NULL
    stage_coefficients <- list()

    for (stage in spec$stages) {
      # Carried stage as a column (v2's `Climate` term)
      if (!is.null(stage$carry_from) && !is.null(carried)) {
        column <- stage$carry_from_as %||% "Climate"
        fitting[[column]] <- carried$fitting
        frame[[column]] <- carried$full
      }

      # Province-scope stages were fitted once per draw
      fitted <- if (stage$name %in% names(fixed)) {
        fixed[[stage$name]]
      } else {
        fit_one_stage(stage, fitting, spec, grid, species)
      }

      if (fitted$status != "ok") {
        return(outcome(fitted$status, fitted$note))
      }

      selected <- fitted$selected

      if (!is.null(stage$carry_as)) {
        carried <- list(
          fitting = carry_values(selected, fitting, stage),
          full = carry_values(selected, frame, stage)
        )
      }

      # Every stage's coefficients are kept, for per-stage v2
      # comparison. Multi-output rules (the mammal hurdle) write
      # `<stage>_<output>`.
      if (!is.null(selected$outputs)) {
        for (output in names(selected$outputs)) {
          key <- paste(stage$name, output, sep = "_")
          stage_coefficients[[key]] <- selected$outputs[[output]]
        }
      } else {
        stage_coefficients[[stage$name]] <- selected$coefficients
      }

      last <- list(selected = selected, stage = stage)
    }

    last$stage_coefficients <- stage_coefficients
    last$frame <- frame

    last
  }, error = function(e) {
    outcome("error", conditionMessage(e))
  })

  if (is.data.frame(result)) {
    return(result)
  }

  frame <- result$frame

  # Step 2: The final model's prediction at every unit (or the
  # spec's `final_prediction`, as the plant specs give v2's)
  predicted <- tryCatch(
    if (is.function(spec$final_prediction)) {
      spec$final_prediction(result$stage_coefficients, frame)
    } else {
      result$selected$predict(frame, "response")
    },
    error = function(e) NULL
  )

  if (is.null(predicted) || length(predicted) != nrow(frame)) {
    return(outcome("predict_failed", result$stage$name))
  }

  # Written only once the whole draw succeeded
  for (stage_name in names(result$stage_coefficients)) {
    write_coefficients(
      store, species, region, boot,
      result$stage_coefficients[[stage_name]],
      stage = stage_name
    )
  }

  in_bag <- frame$survey_unit_id %in% draw

  write_unit_predictions(
    store, species, region, boot, frame$survey_unit_id,
    predicted, frame[[response_name]], in_bag = in_bag
  )

  # Step 3: Score in-sample and out-of-bag. A full-data draw
  # (bootstrap iteration 1) has no out-of-bag units, so NA.
  scored <- function(keep, prefix) {
    out <- compute_metrics(
      frame[[response_name]][keep], predicted[keep], metrics
    )
    out$metric <- paste0(prefix, out$metric)
    out
  }

  metric_rows <- rbind(
    scored(in_bag, "insample_"),
    scored(!in_bag, "oob_")
  )

  # Spec validation, e.g. the plant specs' v2 validation AUCs
  if (is.function(spec$validate)) {
    extra <- tryCatch(
      spec$validate(
        result$stage_coefficients, frame,
        validation_frame %||% frame, draw
      ),
      error = function(e) NULL
    )

    metric_rows <- rbind(metric_rows, extra)
  }

  write_metrics(store, species, region, boot, metric_rows)

  # Step 4: Project the final model onto the prediction grid
  if (!is.null(grid)) {
    grid_prediction <- predict_grid(
      result$selected, grid,
      constants = c(
        result$stage$constants %||% list(),
        result$stage$grid_constants %||% list()
      )
    )

    if (!is.null(grid_prediction)) {
      write_grid_predictions(
        store, species, region, boot,
        names(grid_prediction), grid_prediction
      )
    }
  }

  outcome("ok")
}

# 6. Writing the stores ----

## 6.1 merge_spec_shards() ----

#' Join a Spec's Shards into One Store per Region
#'
#' Joins shards in queue order (matching a serial run), writes
#' meta.json, and removes the shards.
#'
#' @param p A prepare_spec() result.
#' @return NULL, invisibly.
#'
#' @example # Example usage of the function
#' # merge_spec_shards(prepared$lichen)
merge_spec_shards <- function(p) {
  for (region in p$regions) {
    store <- result_store(
      file.path(p$run_dir, region$name),
      unit_predictions = p$unit_predictions
    )

    merge_result_shards(
      store,
      file.path(p$shard_dir, region$name, safe_name(region$species))
    )

    write_meta(store, run_meta(p, region))
  }

  unlink(p$shard_dir, recursive = TRUE)

  invisible(NULL)
}

## 6.2 run_meta() ----

#' What a Region Store Records About Its Run
#'
#' @param p A prepare_spec() result.
#' @param region A prepare_region() result.
#' @return A named list for write_meta().
#'
#' @example # Example usage of the function
#' # run_meta(prepared$lichen, prepared$lichen$regions$north)
run_meta <- function(p, region) {
  spec <- p$spec
  stages <- region$spec$stages

  list(
    taxon = spec$taxon,
    region = region$name,
    # Mammals only: needed to find the right v2 reference
    season = spec$season %||% NA_character_,
    part = if (any(vapply(
      stages, function(s) identical(s$selection, "hurdle"), logical(1)
    ))) {
      "hurdle"
    } else {
      NA_character_
    },
    species_n = length(region$species),
    iterations = length(p$iterations),
    stages = vapply(stages, `[[`, character(1), "name"),
    stage_scope = vapply(
      stages, function(s) s$scope %||% "region", character(1)
    ),
    engines = vapply(stages, `[[`, character(1), "engine"),
    selection = vapply(
      stages,
      function(s) {
        if (is.function(s$selection)) "custom" else s$selection
      },
      character(1)
    ),
    covariates = region$covariates,
    weight_column = region$weight_column %||% NA_character_,
    resample_scheme = spec$resample$scheme,
    resample_scope = spec$resample$scope %||% "region",
    # The seed actually used, never a default that was not
    seed = if (spec$resample$scheme == "precomputed") {
      "not used (precomputed draws)"
    } else if (!is.null(p$base_seed)) {
      paste0(p$base_seed, " (per species, via species_seed())")
    } else {
      "unseeded"
    },
    grid = region$grid_name %||% NA_character_,
    unit_predictions = p$unit_predictions,
    models_overridden = spec$models_overridden %||% NA_character_,
    v2_coverage = if (is.null(spec$v2_coverage)) {
      NA_character_
    } else {
      paste0(
        names(spec$v2_coverage), ": ",
        vapply(spec$v2_coverage, `[[`, character(1), "status")
      )
    },
    spec_notes = spec$notes %||% NA_character_
  )
}

## 6.3 safe_name() ----

#' Make a Species Name Safe as a Folder Name
#'
#' @param x Character vector.
#' @return `x` with anything but letters, digits, dots, hyphens
#'   and underscores replaced.
#'
#' @example # Example usage of the function
#' # safe_name("Black Bear") # "Black_Bear"
safe_name <- function(x) {
  gsub("[^A-Za-z0-9._-]", "_", x)
}

# End of script ----
