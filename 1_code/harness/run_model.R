# ---
# title: Run a Taxon Spec
# author: Brendan Casey
# created: 2026-09-09
# inputs:
#   a spec from 1_code/modules/<taxon>/spec.R
#   the harmonized test dataset
# outputs:
#   in run_dir, one result store per region; see result.R
# notes:
#   - The loop a spec drives: region, then species, then
#     resampling iteration, then stage. Everything it does is
#     taken from the spec, so this file names no taxon.
#   - Stages run in order and each may carry the previous one
#     forward. v2's habitat models take the fitted climate
#     prediction as a term called `Climate`; here that is
#     `carry_as` on a stage, and dropping it is how an experiment
#     asks whether staging helps at all.
#   - The covariates a run needs are read off the model sets
#     rather than declared twice. A spec that adds a term to a
#     formula therefore cannot forget to load its column.
#   - Predictions are written at survey units always, and onto the
#     prediction grid when the spec names one. Grid predictions
#     are the comparison currency; see docs/framework_design.md.
#   - A species or iteration that fails is recorded and the run
#     continues. Across 172 species and 100 iterations something
#     always fails, and losing the whole run to it would be
#     worse than losing the cell.
# ---

# 1. Setup ----

## 1.1 Load packages ----
# Sourced alongside the rest of the harness; no direct imports.

# 2. spec_covariates() ----

#' Read the Covariates a Spec's Model Sets Name
#'
#' Taken from the formulas rather than declared separately, so a
#' spec cannot name a term it forgot to load. Terms the harness
#' supplies itself - the response, the offset, and any stage
#' carried forward - are excluded.
#'
#' @param spec A taxon spec.
#' @param stage_names Character vector of stages to read, or NULL
#'   for all of them.
#' @return A character vector of covariate names.
#'
#' @example # Example usage of the function
#' # spec_covariates(bryophyte_spec)
spec_covariates <- function(spec, stage_names = NULL) {
  stages <- spec$stages

  if (!is.null(stage_names)) {
    stages <- stages[vapply(
      stages, function(s) s$name %in% stage_names, logical(1)
    )]
  }

  supplied <- c(
    spec$response_name %||% "response",
    "offset", "weight",
    vapply(spec$stages, function(s) s$carry_as %||% "", character(1))
  )

  terms <- unlist(lapply(stages, function(stage) {
    # A staged set is a list of groups; flatten before reading
    # terms off the formulas.
    models <- unlist(get_model_set(stage$models), use.names = FALSE)

    unlist(lapply(models, function(one) {
      all.vars(stats::as.formula(one))
    }))
  }))

  covariates <- setdiff(unique(terms), c(supplied, "."))

  # The weight is a covariate too, and is loaded with the rest
  unique(c(covariates, spec$weight_column))
}

# 3. apply_stage_models() ----

#' Swap a Spec's Candidate Sets for an Experiment's Own
#'
#' Lets an experiment define the models a stage fits without
#' editing the taxon spec, which keeps the spec as the record of
#' what v2 did and the experiment as the record of what was
#' changed.
#'
#' Entries are named `taxon.stage`, or `stage` to apply to every
#' taxon. Each value is either a name in model_sets() or a
#' character vector of formulas, so an experiment can hand over a
#' set built by extend_models() or models_from_covariates().
#'
#' \preformatted{
#' stage_models <- list(
#'   "lichen.climate" = extend_models(
#'     "climate_plant_v2_full", "elevation"
#'   ),
#'   "climate" = "climate_common_ladder"
#' )
#' }
#'
#' Because the covariates a run loads are read off the formulas,
#' swapping a set changes what is loaded too. Nothing else has to
#' be declared.
#'
#' @param spec A taxon spec.
#' @param stage_models Named list of replacement model sets, or
#'   NULL.
#' @return The spec, with matching stages replaced, and a record
#'   of what changed in `models_overridden`.
#'
#' @example # Example usage of the function
#' # apply_stage_models(spec, list(climate = my_models))
apply_stage_models <- function(spec, stage_models) {
  if (is.null(stage_models) || length(stage_models) == 0) {
    return(spec)
  }

  changed <- character(0)

  spec$stages <- lapply(spec$stages, function(stage) {
    # The taxon-specific key wins over the bare stage name, so a
    # run can set a default and then override one taxon.
    keys <- c(paste(spec$taxon, stage$name, sep = "."), stage$name)
    hit <- keys[keys %in% names(stage_models)][1]

    if (is.na(hit)) {
      return(stage)
    }

    stage$models <- stage_models[[hit]]
    changed <<- c(changed, paste0(stage$name, " <- ", hit))

    stage
  })

  # Recorded so meta.json shows a run that did not fit the v2
  # candidate sets, which otherwise looks identical to one that
  # did.
  spec$models_overridden <- if (length(changed) > 0) {
    changed
  } else {
    NULL
  }

  spec
}

# 4. run_stage() ----

#' Fit One Stage on One Draw
#'
#' @param stage A stage definition from a spec.
#' @param data A data frame for one species and one draw.
#' @param spec The taxon spec.
#' @param offset Numeric vector or NULL.
#' @param weights Numeric vector or NULL.
#' @return A selection result.
#'
#' @example # Example usage of the function
#' # run_stage(spec$stages[[1]], d, spec)
run_stage <- function(
  stage, data, spec, offset = NULL, weights = NULL,
  grid = NULL
) {
  models <- get_model_set(stage$models)

  # A staged rule takes groups of formulas; the others take a
  # flat list. Both arrive here as text and become formulas now.
  as_formulas <- function(x) {
    if (is.list(x)) {
      return(lapply(x, as_formulas))
    }

    lapply(x, stats::as.formula)
  }

  # The offset goes in the formula, not in an argument. An
  # offset supplied as an argument is not carried by predict()
  # onto new data: R silently recycles the fitted offset against
  # the new rows, which for birds means every prediction outside
  # the draw is wrong. v2 writes `offset(offset)` in the formula
  # for the same reason.
  response <- spec$response_name %||% "response"

  base <- stats::as.formula(
    if (is.null(offset)) {
      paste(response, "~ 1")
    } else {
      paste(response, "~ 1 + offset(offset)")
    }
  )

  selection_run(
    rule = stage$selection,
    models = as_formulas(models),
    base = base,
    data = data,
    engine = get_engine(stage$engine),
    family = stage$family %||% spec$family,
    weights = weights,
    offset = NULL,
    ic = stage$ic %||% "AICc",
    control = stage$control %||% list(),
    # Used only by rules that declare them; see selection_run().
    grid = grid,
    grid_constants = stage$grid_constants %||% list(),
    head_terms = stage$head_terms %||% c("Intercept", "Climate"),
    intercept_cats = get_model_set(stage$intercept_cats),
    constants = stage$constants %||% list(),
    slope_terms = stage$slope_terms %||% "Climate",
    scale = stage$scale %||% "link",
    calibrate_against = if (isTRUE(stage$calibrate)) {
      data[[spec$response_name %||% "response"]]
    } else {
      NULL
    }
  )
}

# 5. run_spec() ----

#' Run a Spec Across Species, Draws and Stages
#'
#' @param spec A taxon spec.
#' @param data_dir Character. Path to 0_data/test_dataset.
#' @param run_dir Character. Where result stores are written; one
#'   subdirectory per region.
#' @param species Character vector of focal species, or NULL for
#'   every species the spec's queue declares.
#' @param regions Character vector of regions to run, or NULL for
#'   all the spec defines.
#' @param iterations Integer vector of resampling iterations.
#' @param stage_models Named list of replacement candidate sets,
#'   or NULL to fit the spec's own. Keys are `taxon.stage` or
#'   `stage`; see apply_stage_models(). Because covariates are
#'   read off the formulas, replacing a set changes what is
#'   loaded too.
#' @param metrics Character vector of metric names, or NULL.
#' @param verbose Logical. Report progress per species.
#' @return A data frame, one row per species, region and
#'   iteration, recording what happened.
#'
#' @example # Example usage of the function
#' # run_spec(bryophyte_spec, data_dir, run_dir,
#' #          species = c("Aulacomnium.palustre"),
#' #          iterations = 1:5)
run_spec <- function(
  spec,
  data_dir,
  run_dir,
  species = NULL,
  regions = NULL,
  iterations = 1:100,
  stage_models = NULL,
  metrics = NULL,
  verbose = TRUE
) {
  # An experiment's own candidate sets replace the spec's before
  # anything is read, so the covariates follow from them.
  spec <- apply_stage_models(spec, stage_models)

  if (is.null(regions)) {
    regions <- names(spec$regions)
  }

  log_rows <- list()

  # A named species is validated once against the whole taxon,
  # so a typo stops the run here. Per region it is then
  # intersected rather than re-validated: a species modelled in
  # the north and not the south is a fact about the species, not
  # a mistake by the caller.
  # `species` may be a plain vector or one named by taxon; take
  # this taxon's entries either way.
  species <- taxon_values(species, spec$taxon) %||% species

  if (!is.null(species) && !is.null(names(species))) {
    species <- unname(species)
  }

  if (!is.null(species)) {
    resolve_species(
      species, data_dir, spec$taxon, tier = spec$tier
    )
  }

  for (region in regions) {
    region_spec <- spec$regions[[region]]

    if (is.null(region_spec)) {
      stop(
        "Spec for ", spec$taxon, " defines no region `", region,
        "`. Regions: ", paste(names(spec$regions), collapse = ", "),
        call. = FALSE
      )
    }

    # Step 1: Choose the species for this region. A species is
    # modelled in one region and not another, so the queue is
    # per region rather than per taxon.
    available <- list_species(
      data_dir, spec$taxon, region = region, tier = spec$tier
    )

    region_species <- if (is.null(species)) {
      available
    } else {
      intersect(available, species)
    }

    if (length(region_species) == 0) {
      next
    }

    if (verbose) {
      cat(
        "\n", spec$taxon, " / ", region, ": ",
        length(region_species), " species x ",
        length(iterations), " iterations\n",
        sep = ""
      )
    }

    # Step 2: A stage with no models of its own takes the
    # region's, which is how one spec fits vegetation types in
    # the north and soil types in the south. Covariates are read
    # off the resulting formulas, so they differ per region too.
    # The v2 formulas name columns as the source files did. Any
    # column appearing in more than one block was suffixed by the
    # harmonizer, so the names are rewritten here; see
    # term_map(). Without it a habitat model asks for HardLin,
    # gets a column belonging to another taxon, and reads NA.
    rename <- term_map(
      data_dir, spec$taxon, region,
      block = region_spec$term_block
    )

    region_spec_stages <- lapply(spec$stages, function(stage) {
      if (is.null(stage$models)) {
        stage$models <- region_spec$habitat_models
      }

      stage$models <- apply_term_map(
        get_model_set(stage$models), rename
      )

      stage
    })

    region_spec_full <- spec
    region_spec_full$stages <- region_spec_stages
    covariates <- spec_covariates(region_spec_full)

    # An alias is made from a column already loaded, so it is
    # not itself a covariate to read.
    covariates <- setdiff(
      covariates,
      c(names(spec$aliases), unlist(spec$aliases))
    )

    # A precomputed resampling scheme keys its stored ids on a
    # column of its own, so that column is loaded as well.
    if (!is.null(spec$resample$id_column)) {
      covariates <- unique(c(covariates, spec$resample$id_column))
    }

    # A region filter that names a covariate has to load it too.
    # Birds select their region on useNorth and useSouth, which
    # no model formula mentions. Site fields are already loaded
    # and are dropped from the request.
    if (!is.null(region_spec$filter)) {
      filter_terms <- all.vars(region_spec$filter)
      site_supplied <- c(
        "lat", "long", "nr", "nsr", "luf", "year",
        "lured", "location", "summer_days", "winter_days",
        "survey_unit_id"
      )
      covariates <- unique(c(
        covariates, setdiff(filter_terms, site_supplied)
      ))
    }

    # Step 3: Load once for the region, then cut per species
    model_data <- build_model_data(
      taxon = spec$taxon,
      data_dir = data_dir,
      species = region_species,
      covariates = covariates,
      region = region,
      region_filter = region_spec$filter,
      weight_column = spec$weight_column,
      aliases = spec$aliases %||% list()
    )

    store <- result_store(file.path(run_dir, region))

    # The grid's columns are renamed to match, but its rownames -
    # the habitat type names the coefficients are reported under
    # - are left as v2 wrote them.
    grid <- load_prediction_grid(data_dir, region_spec$grid)

    if (!is.null(grid)) {
      names(grid) <- apply_term_map(names(grid), rename)
    }

    for (one_species in region_species) {
      frame <- model_frame(
        model_data,
        species = one_species,
        transform = spec$response_transform %||% "identity",
        weight_column = spec$weight_column
      )

      # Step 4: Draws are species-specific where the scheme
      # depends on where that species was detected
      draws <- resample_for_species(
        spec, model_data, frame, iterations, data_dir
      )

      for (i in seq_along(iterations)) {
        outcome <- run_one_draw(
          spec = region_spec_full, frame = frame,
          draw = draws[[i]],
          units = model_data$units, store = store,
          species = one_species, region = region,
          boot = iterations[i], grid = grid, metrics = metrics
        )

        log_rows[[length(log_rows) + 1]] <- outcome
      }

      if (verbose) {
        cat(".")
      }
    }

    if (verbose) {
      cat("\n")
    }

    write_meta(store, list(
      taxon = spec$taxon,
      region = region,
      species_n = length(region_species),
      iterations = length(iterations),
      stages = vapply(spec$stages, function(s) s$name, character(1)),
      engines = vapply(
        spec$stages, function(s) s$engine, character(1)
      ),
      selection = vapply(
        spec$stages, function(s) s$selection, character(1)
      ),
      covariates = covariates,
      resample_scheme = spec$resample$scheme,
      seed = spec$resample$seed %||% harness_seed(),
      grid = region_spec$grid %||% NA_character_,
      models_overridden = spec$models_overridden %||% NA_character_,
      spec_notes = spec$notes %||% NA_character_
    ))
  }

  do.call(rbind, log_rows)
}

# 6. run_one_draw() ----

#' Fit Every Stage on One Species and One Draw
#'
#' @param spec A taxon spec.
#' @param frame The full one-species frame.
#' @param draw Character vector of survey unit ids in the draw.
#' @param units Character vector of the frame's survey unit ids.
#' @param store A result_store().
#' @param species,region Character.
#' @param boot Integer.
#' @param grid A prediction grid, or NULL.
#' @param metrics Character vector of metric names, or NULL.
#' @return A one-row data frame recording the outcome.
#'
#' @example # Example usage of the function
#' # run_one_draw(spec, frame, draw, units, store, sp, "north", 1)
run_one_draw <- function(
  spec, frame, draw, units, store, species, region, boot, grid,
  metrics
) {
  outcome <- function(status, note = NA_character_) {
    data.frame(
      taxon = spec$taxon, species = species, region = region,
      boot = as.integer(boot), status = status, note = note,
      stringsAsFactors = FALSE
    )
  }

  rows <- match(draw, units)
  rows <- rows[!is.na(rows)]

  if (length(rows) == 0) {
    return(outcome("empty_draw"))
  }

  fitting <- frame[rows, , drop = FALSE]
  response_name <- spec$response_name %||% "response"

  result <- tryCatch({
    carried <- NULL
    last <- NULL

    for (stage in spec$stages) {
      # A stage that carries the previous one forward gets it as
      # a column, which is how v2's habitat models take Climate
      if (!is.null(stage$carry_from) && !is.null(carried)) {
        fitting[[stage$carry_from_as %||% "Climate"]] <-
          carried$fitting
        frame[[stage$carry_from_as %||% "Climate"]] <- carried$full
      }

      # A stage may fit on a subset: the mammal abundance half
      # is estimated from the units where the species was
      # actually seen, because abundance given presence is not
      # defined where there was none.
      stage_data <- fitting

      # A stage may read the response differently from the spec's
      # default; recomputed from the retained raw values.
      if (!is.null(stage$response_transform)) {
        raw_name <- paste0(response_name, "_raw")

        if (raw_name %in% names(stage_data)) {
          stage_data[[response_name]] <- apply_response_transform(
            stage_data[[raw_name]], stage$response_transform,
            stage_data
          )
        }
      }

      if (!is.null(stage$row_filter)) {
        keep <- stage$row_filter(stage_data)
        keep[is.na(keep)] <- FALSE
        stage_data <- stage_data[keep, , drop = FALSE]

        if (nrow(stage_data) < 2) {
          return(outcome("too_few_rows", stage$name))
        }
      }

      selected <- run_stage(
        stage = stage, data = stage_data, spec = spec,
        grid = grid,
        offset = if ("offset" %in% names(stage_data)) {
          stage_data$offset
        } else {
          NULL
        },
        weights = if ("weight" %in% names(stage_data)) {
          stage_data$weight
        } else {
          NULL
        }
      )

      if (is.null(selected$fit) || !isTRUE(selected$fit$ok)) {
        return(outcome("stage_failed", stage$name))
      }

      # v2 pools a few poorly sampled footprint coefficients with
      # types they are assumed to resemble. Applied after the
      # averaging, as v2 does, and only where a stage asks.
      if (isTRUE(stage$coef_adjust)) {
        selected$coefficients <- coef_adjust_plant_veg(
          selected$coefficients
        )
      }

      engine <- get_engine(stage$engine)

      # Carry this stage forward from its averaged coefficients,
      # not from the best single candidate: the averaging is the
      # point of the stage. v2 carries it on the probability
      # scale, so the next stage's coefficient on it is read
      # against a term running 0 to 1.
      if (!is.null(stage$carry_as)) {
        scale <- stage$carry_scale %||% "response"

        carried <- list(
          fitting = predict_from_coefficients(
            selected$coefficients, fitting, scale
          ),
          full = predict_from_coefficients(
            selected$coefficients, frame, scale
          )
        )
      }

      last <- list(selected = selected, engine = engine,
                   stage = stage)
    }

    last
  }, error = function(e) {
    outcome("error", conditionMessage(e))
  })

  if (is.data.frame(result)) {
    return(result)
  }

  # Step 1: Record the final stage's coefficients and predictions
  write_coefficients(
    store, species, region, boot, result$selected$coefficients
  )

  predicted <- result$engine$predict(
    result$selected$fit, frame, "response"
  )

  if (is.null(predicted)) {
    return(outcome("predict_failed", result$stage$name))
  }

  write_unit_predictions(
    store, species, region, boot, frame$survey_unit_id,
    predicted, frame[[response_name]]
  )

  write_metrics(
    store, species, region, boot,
    compute_metrics(frame[[response_name]], predicted, metrics)
  )

  # Step 2: Project onto the prediction grid, the quantity that
  # makes engines comparable
  if (!is.null(grid)) {
    grid_prediction <- predict_grid(
      result$selected, result$engine, grid
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

# 7. resample_for_species() ----

#' Draw the Resampling Sets for One Species
#'
#' @param spec A taxon spec.
#' @param model_data From build_model_data().
#' @param frame The one-species frame.
#' @param iterations Integer vector.
#' @param data_dir Character.
#' @return A list of character vectors of survey unit ids.
#'
#' @example # Example usage of the function
#' # resample_for_species(spec, md, frame, 1:10, data_dir)
resample_for_species <- function(
  spec, model_data, frame, iterations, data_dir
) {
  scheme <- spec$resample$scheme
  args <- spec$resample[setdiff(names(spec$resample), "scheme")]

  if (scheme == "precomputed") {
    return(do.call(resample_precomputed, c(
      list(
        data_dir = data_dir, taxon = spec$taxon,
        iterations = iterations, frame = model_data$covariates
      ),
      args
    )))
  }

  if (scheme == "spatial_block") {
    return(do.call(resample_spatial_block, c(
      list(
        frame = model_data$covariates, iterations = iterations,
        response = frame[[spec$response_name %||% "response"]]
      ),
      args
    )))
  }

  do.call(resample_units, c(
    list(
      scheme = scheme, frame = model_data$covariates,
      iterations = iterations
    ),
    args
  ))
}

# 8. Helpers ----

## 8.1 `%||%` ----

#' Default for NULL
#'
#' @param a,b Any values.
#' @return `a` unless it is NULL, in which case `b`.
#'
#' @example # Example usage of the function
#' # NULL %||% "default"
`%||%` <- function(a, b) {
  if (is.null(a)) b else a
}

# End of script ----
