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
    vapply(spec$stages, function(s) s$carry_as %||% "", character(1)),
    # Columns a spec attaches per species rather than reads from
    # the dataset: the mammal precomputed Climate.
    spec$supplied_columns
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

  # A stage may need columns no formula names: the plant age
  # splines read the aged stand-cover columns.
  extra <- unlist(lapply(stages, function(stage) stage$extra_covariates))

  # The weight is a covariate too, and is loaded with the rest
  unique(c(covariates, extra, spec$weight_column))
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

  # A stage may start every candidate from terms of its own. v2's
  # bird landcover selection starts from `count ~ climate`, so
  # each group updates a model that already carries the climate
  # stage; without it the carried climate would never enter.
  base_terms <- c("1", stage$base_terms)

  base <- stats::as.formula(paste(
    response, "~", paste(base_terms, collapse = " + "),
    if (is.null(offset)) "" else "+ offset(offset)"
  ))

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
    always_advance = stage$always_advance %||% TRUE,
    species = species,
    stage = stage,
    scale = stage$scale %||% "link",
    calibrate_against = if (isTRUE(stage$calibrate)) {
      data[[spec$response_name %||% "response"]]
    } else {
      NULL
    }
  )
}

# 5. run_spec() ----

## 5.1 province_context() ----

#' Assemble the Province-Wide Data a Spec's Province Scope Needs
#'
#' v2 fits the plant and bird climate stages once, on every unit
#' in the draw, and draws the plant bootstrap once per species
#' across the province; only the habitat stage is fitted per
#' region. A spec says so with `scope = "province"` on a stage
#' and on `resample`. This loads the unfiltered data those need,
#' once per taxon.
#'
#' @param spec A taxon spec, with stage models already resolved.
#' @param data_dir Character.
#' @param species Character vector of the species to model.
#' @return A list of `model_data` and `stages`, or NULL when the
#'   spec has no province scope.
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

  # A province stage is fitted before any region exists, so it
  # can take nothing from a region-scope stage.
  for (stage in province_stages) {
    if (!is.null(stage$carry_from)) {
      stop(
        "Stage `", stage$name, "` has province scope but carries ",
        "from `", stage$carry_from, "`; a province stage must come ",
        "first.", call. = FALSE
      )
    }

    if (is.null(stage$models)) {
      stop(
        "Stage `", stage$name, "` has province scope but takes its ",
        "models from the region.", call. = FALSE
      )
    }
  }

  stage_names <- vapply(province_stages, `[[`, character(1), "name")
  covariates <- if (length(stage_names) > 0) {
    spec_covariates(spec, stage_names = stage_names)
  } else {
    character(0)
  }

  covariates <- setdiff(
    covariates, c(names(spec$aliases), unlist(spec$aliases))
  )

  if (!is.null(spec$resample$id_column)) {
    covariates <- unique(c(covariates, spec$resample$id_column))
  }

  # The region filters are evaluated on the province frame for
  # v2's redraw rule, so their columns are loaded too.
  site_supplied <- c(
    "lat", "long", "easting", "northing", "nr", "nsr", "luf", "year",
    "lured", "location",
    "summer_days", "winter_days", "survey_unit_id"
  )
  filter_terms <- unlist(lapply(spec$regions, function(one) {
    if (is.null(one$filter)) character(0) else all.vars(one$filter)
  }))
  covariates <- unique(c(
    covariates, setdiff(filter_terms, site_supplied)
  ))

  list(
    model_data = build_model_data(
      taxon = spec$taxon,
      data_dir = data_dir,
      species = species,
      covariates = covariates,
      region = NULL,
      region_filter = NULL,
      weight_column = NULL,
      aliases = spec$aliases %||% list()
    ),
    stages = province_stages,
    draws = province_draws
  )
}

## 5.2 run_spec() ----

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
#' @param boot_seed Integer or NULL. The experiment's base seed.
#'   Each species resamples under its own seed derived from it by
#'   species_seed(). NULL falls back to the spec's
#'   `resample$seed`, and when that is NULL too the draws are
#'   unseeded, as in v2. Ignored by the precomputed scheme, whose
#'   draws are stored rather than drawn.
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
  boot_seed = NULL,
  verbose = TRUE
) {
  # An experiment's own candidate sets replace the spec's before
  # anything is read, so the covariates follow from them.
  spec <- apply_stage_models(spec, stage_models)

  # One base seed governs the run. The experiment's wins over the
  # spec's, so a run can seed every taxon from one setting.
  base_seed <- boot_seed %||% spec$resample$seed
  draws_seeded <- !is.null(base_seed) &&
    spec$resample$scheme != "precomputed"

  if (is.null(regions)) {
    regions <- names(spec$regions)
  }

  log_rows <- list()

  log_outcome <- function(species_name, region, status, note) {
    for (boot in iterations) {
      log_rows[[length(log_rows) + 1]] <<- data.frame(
        taxon = spec$taxon, species = species_name, region = region,
        boot = as.integer(boot), status = status, note = note,
        stringsAsFactors = FALSE
      )
    }
  }

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

  # Step 1: The species each region models. A species is
  # modelled in one region and not another, so the queue is per
  # region rather than per taxon.
  region_queue <- lapply(stats::setNames(regions, regions), function(r) {
    if (is.null(spec$regions[[r]])) {
      stop(
        "Spec for ", spec$taxon, " defines no region `", r,
        "`. Regions: ", paste(names(spec$regions), collapse = ", "),
        call. = FALSE
      )
    }

    available <- list_species(
      data_dir, spec$taxon, region = r, tier = spec$tier,
      season = spec$season
    )

    if (is.null(species)) available else intersect(available, species)
  })

  # Step 2: The province-wide data, draws and stage fits, shared
  # by every region. Built once per taxon; each species' draws
  # and fits are made on first use and reused by later regions.
  province <- province_context(
    spec, data_dir, unique(unlist(region_queue))
  )
  province_cache <- new.env()

  province_for_species <- function(one_species) {
    if (!is.null(province_cache[[one_species]])) {
      return(province_cache[[one_species]])
    }

    frame <- model_frame(
      province$model_data,
      species = one_species,
      transform = spec$response_transform %||% "identity"
    )

    draws <- NULL

    if (province$draws) {
      draws <- tryCatch(
        resample_for_species(
          spec, province$model_data, frame, iterations, data_dir,
          seed = species_seed(base_seed, spec$taxon, one_species),
          species = one_species
        ),
        error = function(e) conditionMessage(e)
      )
    }

    entry <- list(frame = frame, draws = draws, fits = list())
    province_cache[[one_species]] <- entry

    entry
  }

  # A province stage is fitted once per species and draw, on the
  # draw's province-wide rows, and reused by every region.
  province_fits <- function(one_species, entry, boot, draw) {
    key <- as.character(boot)

    if (!is.null(entry$fits[[key]])) {
      return(entry$fits[[key]])
    }

    rows <- match(draw, entry$frame$survey_unit_id)
    fitting <- entry$frame[rows[!is.na(rows)], , drop = FALSE]

    fits <- lapply(province$stages, function(stage) {
      tryCatch(
        fit_one_stage(stage, fitting, spec, NULL, one_species),
        error = function(e) {
          list(status = "error", note = conditionMessage(e),
               selected = NULL)
        }
      )
    })
    names(fits) <- vapply(province$stages, `[[`, character(1), "name")

    entry$fits[[key]] <- fits
    province_cache[[one_species]] <- entry

    fits
  }

  for (region in regions) {
    region_spec <- spec$regions[[region]]
    region_species <- region_queue[[region]]

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

    # Step 3: A stage with no models of its own takes the
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
      # A region that supplies the models may also supply what
      # goes with them: the mammal one-hot rule needs each
      # candidate's reference category, and the south models
      # hold pAspen fixed as well.
      if (is.null(stage$models)) {
        stage$models <- region_spec$habitat_models
        stage$intercept_cats <- region_spec$intercept_cats %||%
          stage$intercept_cats
        stage$constants <- region_spec$constants %||% stage$constants
        stage$extra_covariates <- c(
          stage$extra_covariates, region_spec$extra_covariates
        )

        # Terms held fixed when predicting onto the grid can be
        # added per region: v2 predicts the south at pAspen = 0.
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

    region_spec_full <- spec
    region_spec_full$stages <- region_spec_stages
    covariates <- spec_covariates(region_spec_full)

    # A region may weight its models by a column of its own: v2
    # weights the bird landcover models by vegw in the north and
    # soilw in the south.
    weight_column <- region_spec$weight_column %||% spec$weight_column

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
        "lat", "long", "easting", "northing", "nr", "nsr", "luf", "year",
        "lured", "location", "summer_days", "winter_days",
        "survey_unit_id"
      )
      covariates <- unique(c(
        covariates, setdiff(filter_terms, site_supplied)
      ))
    }

    # Step 4: Load once for the region, then cut per species
    model_data <- build_model_data(
      taxon = spec$taxon,
      data_dir = data_dir,
      species = region_species,
      covariates = covariates,
      region = region,
      region_filter = region_spec$filter,
      weight_column = weight_column,
      aliases = spec$aliases %||% list()
    )

    store <- result_store(file.path(run_dir, region))

    # The grid's columns are renamed to match, but its rownames -
    # the habitat type names the coefficients are reported under
    # - are left as v2 wrote them.
    grid <- load_prediction_grid(data_dir, region_spec$grid)

    if (!is.null(grid)) {
      names(grid) <- apply_term_map(names(grid), rename)

      # A region may leave rows or columns of the grid out, as v2
      # drops the mammal north's WetlandMargin and Climate rows.
      grid <- grid[
        !rownames(grid) %in% region_spec$grid_drop_rows,
        !names(grid) %in% region_spec$grid_drop_cols,
        drop = FALSE
      ]
    }

    for (one_species in region_species) {
      frame <- model_frame(
        model_data,
        species = one_species,
        transform = spec$response_transform %||% "identity",
        weight_column = weight_column
      )

      # A spec may attach per-species columns, and drop rows,
      # before fitting: the mammal precomputed climate.
      if (is.function(spec$species_frame)) {
        frame <- spec$species_frame(frame, one_species, data_dir, spec)
      }

      # Step 5: The draws. Province-wide ones are shared by every
      # region, and filtered to the region's units when fitted,
      # which is how v2 subsets its draws. A species whose draws
      # cannot be made is logged and skipped, not fatal.
      entry <- if (is.null(province)) {
        NULL
      } else {
        province_for_species(one_species)
      }

      draws <- if (!is.null(entry) && province$draws) {
        entry$draws
      } else {
        tryCatch(
          resample_for_species(
            spec, model_data, frame, iterations, data_dir,
            seed = species_seed(base_seed, spec$taxon, one_species),
            species = one_species
          ),
          error = function(e) conditionMessage(e)
        )
      }

      if (is.character(draws)) {
        log_outcome(one_species, region, "resample_failed", draws)
        next
      }

      for (i in seq_along(iterations)) {
        fixed <- if (!is.null(entry) &&
                       length(province$stages) > 0) {
          province_fits(one_species, entry, iterations[i],
                        draws[[i]])
        } else {
          NULL
        }

        outcome <- run_one_draw(
          spec = region_spec_full, frame = frame,
          draw = draws[[i]],
          units = frame$survey_unit_id, store = store,
          species = one_species, region = region,
          boot = iterations[i], grid = grid, metrics = metrics,
          fixed = fixed,
          # The province-wide frame, where there is one, for
          # validation that scores climate over every unit
          validation_frame = if (is.null(entry)) NULL else entry$frame
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
      # Mammal specs are fitted per season and per hurdle part,
      # and the comparison needs both to find the right
      # reference. NA for every other taxon.
      season = spec$season %||% NA_character_,
      part = spec$part %||% NA_character_,
      species_n = length(region_species),
      iterations = length(iterations),
      stages = vapply(spec$stages, function(s) s$name, character(1)),
      stage_scope = vapply(
        spec$stages, function(s) s$scope %||% "region", character(1)
      ),
      engines = vapply(
        spec$stages, function(s) s$engine, character(1)
      ),
      selection = vapply(
        spec$stages,
        function(s) if (is.function(s$selection)) "custom" else s$selection,
        character(1)
      ),
      covariates = covariates,
      weight_column = weight_column %||% NA_character_,
      resample_scheme = spec$resample$scheme,
      resample_scope = spec$resample$scope %||% "region",
      # The seed actually used, never a default that was not.
      # Per-species seeds are derived from this base; see
      # species_seed().
      seed = if (draws_seeded) {
        paste0(base_seed, " (per species, via species_seed())")
      } else if (spec$resample$scheme == "precomputed") {
        "not used (precomputed draws)"
      } else {
        "unseeded"
      },
      grid = region_spec$grid %||% NA_character_,
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
    ))
  }

  do.call(rbind, log_rows)
}

# 6. run_one_draw() ----

## 6.1 fit_one_stage() ----

#' Prepare One Stage's Data and Fit It
#'
#' Shared by the per-region loop and by stages fitted once for
#' the whole province, so both prepare a stage the same way.
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

  # A stage may fit on a subset: the mammal abundance half is
  # estimated from the units where the species was actually
  # seen, because abundance given presence is not defined where
  # there was none.
  if (!is.null(stage$row_filter)) {
    keep <- stage$row_filter(stage_data)
    keep[is.na(keep)] <- FALSE
    stage_data <- stage_data[keep, , drop = FALSE]

    if (nrow(stage_data) < 2) {
      return(failed("too_few_rows"))
    }
  }

  # v2 skips a plant habitat model outright when the draw, after
  # the region filter, holds fewer than 20 detections.
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

  # A stage may reshape its coefficients after selection with
  # steps its spec supplies, applied in order: the plant stand-age
  # splines and cutblock convergence. Each takes and returns the
  # selection result, and sees the stage's data. They run before
  # the footprint pooling below, which is v2's order: the pooling
  # borrows from a spline-fitted age class.
  for (step in stage$post_process) {
    selected <- step(selected, stage_data)
  }

  # v2 pools a few poorly sampled footprint coefficients with
  # types they are assumed to resemble. Applied after the
  # averaging, as v2 does, and only where a stage asks.
  if (isTRUE(stage$coef_adjust)) {
    selected$coefficients <- coef_adjust_plant_veg(
      selected$coefficients
    )
  }

  list(status = "ok", note = NA_character_, selected = selected)
}

## 6.2 carry_values() ----

#' The Value a Stage Hands the Next One
#'
#' Computed from the averaged coefficients, not from the best
#' single candidate: the averaging is the point of the stage.
#'
#' @param coefficients A data frame of term and estimate.
#' @param data The rows to compute it for.
#' @param stage The stage being carried.
#' @return A numeric vector, one per row.
#'
#' @example # Example usage of the function
#' # carry_values(selected$coefficients, fitting, stage)
carry_values <- function(coefficients, data, stage) {
  link <- predict_from_coefficients(coefficients, data, "link")

  # v2's bird climate is predicted from the fitted models, whose
  # linear predictor includes the QPAD offset, so the landcover
  # model sees the expected count rather than the rate.
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

## 6.3 run_one_draw() ----

#' Fit Every Stage on One Species and One Draw
#'
#' @param spec A taxon spec.
#' @param frame The full one-species frame.
#' @param draw Character vector of survey unit ids in the draw.
#'   Ids not in `units` are dropped, so a province-wide draw
#'   passed to one region keeps only that region's units, with
#'   their repeats, as v2 filters its draws.
#' @param units Character vector of the frame's survey unit ids.
#' @param store A result_store().
#' @param species,region Character.
#' @param boot Integer.
#' @param grid A prediction grid, or NULL.
#' @param metrics Character vector of metric names, or NULL.
#' @param fixed Named list of fit_one_stage() results for stages
#'   already fitted at province scope, or NULL.
#' @param validation_frame The province-wide frame, or NULL; passed
#'   to the spec's `validate` function, which scores climate over
#'   every unit.
#' @return A one-row data frame recording the outcome.
#'
#' @example # Example usage of the function
#' # run_one_draw(spec, frame, draw, units, store, sp, "north", 1)
run_one_draw <- function(
  spec, frame, draw, units, store, species, region, boot, grid,
  metrics, fixed = NULL, validation_frame = NULL
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
    stage_coefficients <- list()

    for (stage in spec$stages) {
      # A stage that carries the previous one forward gets it as
      # a column, which is how v2's habitat models take Climate
      if (!is.null(stage$carry_from) && !is.null(carried)) {
        fitting[[stage$carry_from_as %||% "Climate"]] <-
          carried$fitting
        frame[[stage$carry_from_as %||% "Climate"]] <- carried$full
      }

      # A province-scope stage was fitted once for the species
      # and draw, and is shared by every region.
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
          fitting = carry_values(selected$coefficients, fitting, stage),
          full = carry_values(selected$coefficients, frame, stage)
        )
      }

      # Every stage's coefficients are kept, not only the last,
      # so each stage can be compared against its own v2
      # reference. They are written only once the whole draw
      # succeeds, so a store never holds half a draw.
      # A rule with several outputs - the mammal hurdle's
      # presence, abundance and total tables - writes each as its
      # own stage, `<stage>_<output>`.
      if (!is.null(selected$outputs)) {
        for (output in names(selected$outputs)) {
          stage_coefficients[[paste(stage$name, output, sep = "_")]] <-
            selected$outputs[[output]]
        }
      } else {
        stage_coefficients[[stage$name]] <- selected$coefficients
      }

      last <- list(
        selected = selected, engine = get_engine(stage$engine),
        stage = stage
      )
    }

    last$stage_coefficients <- stage_coefficients

    last
  }, error = function(e) {
    outcome("error", conditionMessage(e))
  })

  if (is.data.frame(result)) {
    return(result)
  }

  # Step 1: Record every stage's coefficients, then the final
  # stage's predictions
  for (stage_name in names(result$stage_coefficients)) {
    write_coefficients(
      store, species, region, boot,
      result$stage_coefficients[[stage_name]],
      stage = stage_name
    )
  }

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

  # Metrics are scored twice: on the units the draw fitted
  # (in-sample) and on the units it left out (out-of-bag), which
  # is the held-out read. Iteration 1 is the full data and has no
  # out-of-bag units, so its out-of-bag metrics are NA.
  in_bag <- frame$survey_unit_id %in% draw
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

  # A spec may add its own validation: the plant specs add v2's
  # seven validation AUCs, in-bag and out-of-bag.
  if (is.function(spec$validate)) {
    extra <- tryCatch(
      spec$validate(
        result$stage_coefficients, frame,
        validation_frame %||% frame, draw
      ),
      error = function(e) NULL
    )

    if (!is.null(extra)) {
      metric_rows <- rbind(metric_rows, extra)
    }
  }

  write_metrics(store, species, region, boot, metric_rows)

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
#' @param model_data From build_model_data(). Kept for the
#'   signature; the draws are made from `frame`, which carries the
#'   same covariates and may have dropped rows.
#' @param frame The one-species frame, one row per unit that
#'   can be drawn.
#' @param iterations Integer vector.
#' @param data_dir Character.
#' @param seed Integer or NULL. This species' seed, from
#'   species_seed(). Replaces any seed in the spec; NULL leaves
#'   the draw unseeded.
#' @param species Character. Names the stored draws where they
#'   are kept per species.
#' @return A list of character vectors of survey unit ids.
#'
#' @example # Example usage of the function
#' # resample_for_species(spec, md, frame, 1:10, data_dir,
#' #                      seed = 123L, species = "Physcia.adscendens")
resample_for_species <- function(
  spec, model_data, frame, iterations, data_dir, seed = NULL,
  species = NULL
) {
  scheme <- spec$resample$scheme

  # The spec's seed is a base, not a species seed, so it is
  # dropped here and the derived one passed instead. `scope` is
  # read by run_spec(), not by a resampler.
  args <- spec$resample[
    setdiff(names(spec$resample), c("scheme", "seed", "scope"))
  ]

  if (scheme == "precomputed") {
    return(do.call(resample_precomputed, c(
      list(
        data_dir = data_dir, taxon = spec$taxon,
        iterations = iterations, frame = frame,
        species = species
      ),
      args
    )))
  }

  if (scheme == "spatial_block") {
    response <- frame[[spec$response_name %||% "response"]]

    # v2 redraws a sample only when the full data could meet the
    # threshold in at least one model region; otherwise it takes
    # the first draw. Checked per region, on the full data.
    if (!is.null(args$min_detections) && args$min_detections > 0) {
      viable <- any(vapply(spec$regions, function(one) {
        # A region whose filter names columns this frame lacks -
        # another region's, when the draw is not province-wide -
        # cannot be judged here, and does not count.
        if (!is.null(one$filter) &&
              !all(all.vars(one$filter) %in% names(frame))) {
          return(FALSE)
        }

        in_region <- if (is.null(one$filter)) {
          rep(TRUE, nrow(frame))
        } else {
          keep <- eval(rlang_f_rhs(one$filter), frame)
          !is.na(keep) & keep
        }

        sum(response[in_region] > 0, na.rm = TRUE) >=
          args$min_detections
      }, logical(1)))

      if (!viable) {
        args$min_detections <- 0L
      }
    }

    return(do.call(resample_spatial_block, c(
      # `seed = NULL` is passed through deliberately: it means
      # unseeded, not the resampler's harness_seed() default.
      list(
        frame = frame, iterations = iterations,
        response = response, seed = seed
      ),
      args
    )))
  }

  do.call(resample_units, c(
    list(
      scheme = scheme, frame = frame,
      iterations = iterations, seed = seed
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

## 8.2 v2_status() ----

#' State How Much of One v2 Stage a Spec Reproduces
#'
#' The entries of a spec's `v2_coverage`. The status vocabulary
#' is fixed, so a typo fails when the spec is built rather than
#' reading as a fourth category in the report.
#'
#' @param status Character. "reproduced", "partial" or
#'   "not reproduced".
#' @param note Character. What is and is not reproduced, and why.
#' @return A list of `status` and `note`.
#'
#' @example # Example usage of the function
#' # v2_status("partial", "No age splines.")
v2_status <- function(status, note) {
  allowed <- c("reproduced", "partial", "not reproduced")

  if (!is.character(status) || length(status) != 1L ||
        !status %in% allowed) {
    stop(
      "v2 status must be one of: ",
      paste(allowed, collapse = ", "), ".",
      call. = FALSE
    )
  }

  if (!is.character(note) || length(note) != 1L ||
        !nzchar(note)) {
    stop("A v2 status needs a one-line note.", call. = FALSE)
  }

  list(status = status, note = note)
}

## 8.3 spec_coverage() ----

#' Tabulate What a Set of Specs Reproduces of v2
#'
#' Flattens each spec's `v2_coverage` into one table, which is
#' what the report prints. Coverage is stated once, in the specs,
#' and read from there.
#'
#' @param specs A named list of specs.
#' @return A data frame of taxon, stage, status and note.
#'
#' @example # Example usage of the function
#' # spec_coverage(list(lichen = lichen_spec()))
spec_coverage <- function(specs) {
  rows <- lapply(names(specs), function(key) {
    coverage <- specs[[key]]$v2_coverage

    if (is.null(coverage) || length(coverage) == 0) {
      return(data.frame(
        taxon = key, stage = NA_character_,
        status = "not stated",
        note = "The spec has no v2_coverage.",
        stringsAsFactors = FALSE
      ))
    }

    data.frame(
      taxon = key,
      stage = names(coverage),
      status = vapply(coverage, `[[`, character(1), "status"),
      note = vapply(coverage, `[[`, character(1), "note"),
      stringsAsFactors = FALSE,
      row.names = NULL
    )
  })

  do.call(rbind, rows)
}

# End of script ----
