# ---
# title: Taxon Specs - Validation and Helpers
# author: Brendan Casey
# created: 2026-10-03
# inputs: none
# outputs: none; defines functions in memory
# notes:
#   - A spec states one taxon's configuration as data; methods it
#     names are looked up in the registry. Fields are documented
#     in docs/getting_started.md.
#   - validate_spec() reports every problem at once, before any
#     data is read. Unknown fields are errors, because a misspelt
#     field is otherwise silently ignored; arguments of the named
#     rule or resampler count as known fields.
# ---

# 1. Setup ----

## 1.1 Load packages ----
# Base R only.

# 2. Known fields ----

## 2.1 spec_fields() ----

#' The Fields a Spec, Region or Stage May Carry
#'
#' Fields the harness itself reads; method-specific settings are
#' known through the method's arguments.
#'
#' @return A named list of character vectors: `spec`, `region`,
#'   `stage` and `resample`.
#'
#' @example # Example usage of the function
#' # spec_fields()$stage
spec_fields <- function() {
  list(
    spec = c(
      "taxon", "response_name", "response_transform", "family",
      "weight_column", "tier", "season", "aliases",
      "regions", "stages", "resample", "v2_coverage", "validate",
      "final_prediction", "species_frame", "supplied_columns",
      "notes", "models_overridden", "covariate_files",
      # The stage a methods experiment replaces by default
      "habitat_stage",
      # Recorded facts a module keeps for its own reports
      "use_protocol", "protocol_is_v2", "climate_source"
    ),
    region = c(
      "filter", "grid", "term_block", "habitat_models",
      "grid_constants", "grid_drop_rows", "grid_drop_cols",
      "constants", "intercept_cats", "extra_covariates",
      "weight_column"
    ),
    stage = c(
      "name", "models", "engine", "selection", "ic", "control",
      "family", "scope", "weighted", "base_terms",
      "response_transform", "row_filter", "min_detections",
      "extra_covariates", "post_process", "calibrate",
      "carry_as", "carry_scale", "carry_offset", "carry_from",
      "carry_from_as",
      # Values held fixed when the final model is projected onto
      # the grid; rules that predict onto a grid read them too
      "constants", "grid_constants"
    ),
    resample = c("scheme", "seed", "scope")
  )
}

# 3. validate_spec() ----

#' Check a Spec Before Running It
#'
#' @param spec A taxon spec.
#' @param stop_on_error Logical. Stop with every problem listed,
#'   or return the problems.
#' @return The spec, invisibly, when it is valid; otherwise stops,
#'   or returns a character vector of problems when
#'   `stop_on_error` is FALSE.
#'
#' @example # Example usage of the function
#' # validate_spec(lichen_spec())
validate_spec <- function(spec, stop_on_error = TRUE) {
  problems <- character(0)
  problem <- function(...) {
    problems <<- c(problems, paste0(...))
  }
  fields <- spec_fields()
  unknown_fields <- function(x, known, where) {
    extra <- setdiff(names(x), known)

    if (length(extra) > 0) {
      problem(
        where, " has unknown field(s): ",
        paste(extra, collapse = ", "), "."
      )
    }
  }

  # Step 1: The spec itself
  if (!is.character(spec$taxon) || length(spec$taxon) != 1L) {
    problem("`taxon` must be one data slug, such as \"lichen\".")
  }

  label <- paste0("Spec `", spec$taxon %||% "?", "`")
  unknown_fields(spec, fields$spec, label)

  # Step 2: Regions
  if (!is.list(spec$regions) || length(spec$regions) == 0) {
    problem(label, " defines no regions.")
  }

  for (region in names(spec$regions)) {
    one <- spec$regions[[region]]
    unknown_fields(
      one, fields$region, paste0("Region `", region, "`")
    )

    if (!is.null(one$filter) && !inherits(one$filter, "formula")) {
      problem(
        "Region `", region, "`: `filter` must be a one-sided ",
        "formula, such as ~ nr != \"Grassland\"."
      )
    }
  }

  # Step 3: Stages, in order
  stage_names <- character(0)
  carried <- character(0)

  for (stage in spec$stages) {
    name <- stage$name %||% "?"
    where <- paste0("Stage `", name, "`")

    if (name %in% stage_names) {
      problem(where, " appears twice; stage names must differ.")
    }
    stage_names <- c(stage_names, name)

    engine <- tryCatch(
      get_engine(stage$engine),
      error = function(e) {
        problem(where, ": ", conditionMessage(e))
        NULL
      }
    )

    rule <- if (is.function(stage$selection)) {
      stage$selection
    } else {
      tryCatch(
        get_method("selection", stage$selection),
        error = function(e) {
          problem(where, ": ", conditionMessage(e))
          NULL
        }
      )
    }

    # A field the rule takes as an argument is a rule setting
    known <- c(fields$stage, if (!is.null(rule)) names(formals(rule)))
    unknown_fields(stage, known, where)

    # The rule's requirements against the engine's capabilities
    if (!is.null(engine) && is.character(stage$selection)) {
      needs <- get_method(
        "selection", stage$selection, entry = TRUE
      )$requires
      missing_capabilities <- setdiff(needs, engine$capabilities)

      if (length(missing_capabilities) > 0) {
        problem(
          where, ": selection rule `", stage$selection,
          "` needs ", paste(missing_capabilities, collapse = ", "),
          ", which engine `", engine$name, "` does not provide. ",
          "Choose a rule that does not, such as `single`."
        )
      }
    }

    # A composite rule (the hurdle) runs an inner rule per part;
    # that rule's requirements are checked against the engine too
    if (!is.null(engine) && !is.null(rule) &&
          "part_selection" %in% names(formals(rule))) {
      inner <- stage$part_selection %||% formals(rule)$part_selection
      entry <- tryCatch(
        get_method("selection", inner, entry = TRUE),
        error = function(e) {
          problem(where, ": `part_selection`: ", conditionMessage(e))
          NULL
        }
      )
      missing_capabilities <- setdiff(
        entry$requires, engine$capabilities
      )

      if (!is.null(entry) && length(missing_capabilities) > 0) {
        problem(
          where, ": inner rule `", inner, "` needs ",
          paste(missing_capabilities, collapse = ", "),
          ", which engine `", engine$name, "` does not provide. ",
          "Use `single` as the part_selection."
        )
      }
    }

    if (!is.null(stage$ic) &&
          !stage$ic %in% c("AIC", "AICc", "BIC")) {
      problem(where, ": `ic` must be \"AIC\", \"AICc\" or \"BIC\".")
    }

    # Or the carried column is attached per species via
    # `supplied_columns` (mammal precomputed climate)
    carried_column <- stage$carry_from_as %||% "Climate"

    if (!is.null(stage$carry_from) &&
          !stage$carry_from %in% carried &&
          !carried_column %in% spec$supplied_columns) {
      problem(
        where, " carries from `", stage$carry_from, "`, which is ",
        "not an earlier stage with `carry_as`, and `",
        carried_column, "` is not in `supplied_columns`."
      )
    }

    if (!is.null(stage$carry_as)) {
      carried <- c(carried, name)
    }

    # Models: a registered set name, formulas, or NULL to take
    # each region's habitat models
    if (is.null(stage$models)) {
      lacking <- names(spec$regions)[vapply(
        spec$regions, function(r) is.null(r$habitat_models),
        logical(1)
      )]

      if (length(lacking) > 0) {
        problem(
          where, " takes its models from the region, but ",
          paste(lacking, collapse = ", "), " define(s) no ",
          "`habitat_models`."
        )
      }
    } else {
      problems <- c(problems, check_model_set(stage$models, where))
    }
  }

  # Step 4: Resampling
  scheme <- spec$resample$scheme

  resampler <- tryCatch(
    get_method("resampler", scheme %||% ""),
    error = function(e) {
      problem("`resample$scheme`: ", conditionMessage(e))
      NULL
    }
  )

  if (!is.null(resampler)) {
    unknown_fields(
      spec$resample,
      c(fields$resample, names(formals(resampler))),
      "`resample`"
    )
  }

  if (length(problems) == 0) {
    return(invisible(spec))
  }

  if (!stop_on_error) {
    return(problems)
  }

  stop(
    label, " has ", length(problems), " problem(s):\n  - ",
    paste(problems, collapse = "\n  - "),
    call. = FALSE
  )
}

## 3.1 check_model_set() ----

#' Check a Stage's Models Name Something Real
#'
#' A lone string that is neither a set nor a formula is almost
#' always a misspelt set name.
#'
#' @param models A set name, or formulas as text.
#' @param where Character. Prefix for the message.
#' @return A character vector of problems, empty when fine.
#'
#' @example # Example usage of the function
#' # check_model_set("climate_plant_v2_ful", "Stage `climate`")
check_model_set <- function(models, where) {
  if (is.list(models)) {
    return(unlist(lapply(models, check_model_set, where = where)))
  }

  if (!is.character(models)) {
    return(paste0(where, ": `models` must be a set name or text."))
  }

  if (length(models) == 1L && !grepl("~", models, fixed = TRUE) &&
        !models %in% names(model_sets())) {
    return(paste0(
      where, ": `", models, "` is not a model set or a formula. ",
      "Sets: see names(model_sets())."
    ))
  }

  character(0)
}

# 4. spec_covariates() ----

#' Read the Covariates a Spec's Model Sets Name
#'
#' Read from the formulas, so a spec cannot name a term it forgot
#' to load. Excludes harness-supplied terms (response, offset,
#' weight, carried stages, `supplied_columns`).
#'
#' @param spec A taxon spec.
#' @param stage_names Character vector of stages to read, or NULL
#'   for all of them.
#' @return A character vector of covariate names.
#'
#' @example # Example usage of the function
#' # spec_covariates(bryophyte_spec())
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
    spec$supplied_columns
  )

  terms <- unlist(lapply(stages, function(stage) {
    models <- unlist(get_model_set(stage$models), use.names = FALSE)

    unlist(lapply(models, function(one) {
      all.vars(stats::as.formula(one))
    }))
  }))

  covariates <- setdiff(unique(terms), c(supplied, "."))

  # Columns no formula names, e.g. the plant age splines' aged
  # stand-cover columns
  extra <- unlist(lapply(stages, `[[`, "extra_covariates"))

  unique(c(covariates, extra, spec$weight_column))
}

# 5. apply_stage_models() ----

#' Swap a Spec's Candidate Sets for an Experiment's Own
#'
#' Keeps the spec as the record of v2 and the experiment as the
#' record of what changed. Entries are named `taxon.stage`, or
#' `stage` for every taxon; values are a model_sets() name or
#' formulas.
#'
#' \preformatted{
#' stage_models <- list(
#'   "lichen.climate" = extend_models(
#'     "climate_plant_v2_full", "elevation"
#'   ),
#'   "climate" = models_from_covariates(c("MAP", "FFP"))
#' )
#' }
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

  for (i in seq_along(spec$stages)) {
    stage <- spec$stages[[i]]

    # `taxon.stage` wins over a bare `stage`
    keys <- c(paste(spec$taxon, stage$name, sep = "."), stage$name)
    hit <- keys[keys %in% names(stage_models)][1]

    if (is.na(hit)) {
      next
    }

    spec$stages[[i]]$models <- stage_models[[hit]]
    changed <- c(changed, paste0(stage$name, " <- ", hit))
  }

  # Recorded in meta.json; otherwise indistinguishable from v2
  spec$models_overridden <- if (length(changed) > 0) {
    changed
  } else {
    NULL
  }

  spec
}

# 6. replace_stage_method() ----

#' Fit One Stage of a v2 Spec with a Different Method
#'
#' The rest of the spec stays v2's, so a difference in results is
#' the method's. By default the candidates become one formula of
#' all their covariates (models_union()). A composite rule (e.g.
#' the mammal `hurdle`) keeps its structure and runs the new rule
#' in each part.
#'
#' Removes what reads v2 coefficient tables a new engine may not
#' produce: the stage's `post_process`, fields only the old rule
#' took, and (for the last stage) `final_prediction` and
#' `validate`. The change is recorded in `v2_coverage` and
#' `models_overridden`.
#'
#' @param spec A taxon spec.
#' @param stage Character. The stage's name; the spec's
#'   `habitat_stage` by default.
#' @param engine Character. A registered engine.
#' @param selection Character. A registered rule; "single" for an
#'   engine with no information criterion.
#' @param control Named list of engine settings.
#' @param union Logical. Replace the candidate set with one formula
#'   holding all its covariates. FALSE keeps the candidates, for a
#'   rule that compares them.
#' @return The spec.
#'
#' @example # Example usage of the function
#' # spec <- replace_stage_method(lichen_spec(), engine = "xgboost")
replace_stage_method <- function(
  spec, stage = spec$habitat_stage, engine, selection = "single",
  control = list(), union = TRUE
) {
  names_in <- vapply(spec$stages, `[[`, character(1), "name")

  if (is.null(stage)) {
    stop(
      "Spec `", spec$taxon, "` names no `habitat_stage`; pass ",
      "`stage`. Stages: ", paste(names_in, collapse = ", "),
      call. = FALSE
    )
  }

  index <- match(stage, names_in)

  if (is.na(index)) {
    stop(
      "Spec `", spec$taxon, "` has no stage `", stage, "`. Stages: ",
      paste(names_in, collapse = ", "),
      call. = FALSE
    )
  }

  get_method("selection", selection)
  get_engine(engine)
  old <- spec$stages[[index]]

  # A composite rule keeps its place and takes the new rule inside
  old_rule <- if (is.function(old$selection)) {
    old$selection
  } else {
    get_method("selection", old$selection)
  }
  composite <- "part_selection" %in% names(formals(old_rule))
  rule <- if (composite) {
    old_rule
  } else {
    get_method("selection", selection)
  }

  # Step 1: The candidate formulas, per region where the region
  # supplies them
  if (union) {
    if (is.null(old$models)) {
      for (region in names(spec$regions)) {
        spec$regions[[region]]$habitat_models <- models_union(
          spec$regions[[region]]$habitat_models
        )
        spec$regions[[region]]$intercept_cats <- NULL
      }
    } else {
      old$models <- models_union(old$models)
    }
  }

  # Step 2: The stage, keeping only what the harness and the new
  # rule read
  known <- c(spec_fields()$stage, names(formals(rule)))
  new <- old[intersect(names(old), known)]
  new$engine <- engine
  new$control <- control
  new$ic <- NULL
  new$post_process <- NULL

  if (composite) {
    new$part_selection <- selection
  } else {
    new$selection <- selection
  }

  spec$stages[[index]] <- new

  # Step 3: Hooks that read v2 coefficient tables
  if (index == length(spec$stages)) {
    spec$final_prediction <- NULL
    spec$validate <- NULL
  }

  # Step 4: Say so
  label <- paste0(
    engine, " with `", selection, "`",
    if (composite) paste0(" inside `", old$selection, "`") else "",
    if (union) ", on every covariate the v2 candidates use" else ""
  )
  spec$v2_coverage[[stage]] <- v2_status(
    "not reproduced", paste0("Replaced: ", label, ".")
  )
  spec$models_overridden <- c(
    spec$models_overridden, paste0(stage, " <- ", label)
  )
  spec$notes <- paste0(
    spec$notes %||% "", " Stage `", stage, "` fitted with ",
    label, "."
  )

  spec
}

# 7. v2 coverage ----

## 7.1 v2_status() ----

#' State How Much of One v2 Stage a Spec Reproduces
#'
#' The status vocabulary is fixed, so a typo fails when the spec
#' is built.
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

## 7.2 spec_coverage() ----

#' Tabulate What a Set of Specs Reproduces of v2
#'
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
