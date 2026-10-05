# ---
# title: Selection Rule - Hurdle: Presence, Then Abundance Given
#   Presence
# author: Brendan Casey
# created: 2026-10-05
# inputs: none
# outputs: registers the `hurdle` rule
# notes:
#   - A two-part model for a response that is zero at most units
#     and a right-skewed amount where it is not. Presence is fitted
#     on every unit; abundance given presence on the units where
#     the species was found. Their product is total abundance.
#     v2's mammal habitat models are this shape.
#   - Engine-agnostic. Both halves are fitted with the stage's
#     engine through an inner rule, `part_selection`: `aic_best`
#     for v2's GLMs, `single` for an engine with no information
#     criterion. replace_stage_method() swaps the inner rule and
#     the engine, so a boosted tree fits both halves.
#   - What the rule reports works for any engine: each half and
#     their product predicted onto the prediction grid, one value
#     per habitat type, as three outputs (`presence`, `abundance`,
#     `total`). The harness writes them as the stages
#     `<stage>_presence`, `<stage>_abundance` and `<stage>_total`.
#     v2's own post-processing (modules/mammals/hurdle.R) replaces
#     them with v2's tables when the stage keeps v2's GLMs.
#   - The final model the harness scores and projects is the
#     presence half, so metrics compare like with like across
#     engines and with the presence response.
#   - The abundance candidates are the presence candidates with
#     `abundance_drop` removed - v2 notes that climate effects on
#     abundance given presence are minimal - plus a null carrying
#     sampling effort. For an engine with coefficients, a
#     candidate whose cover terms account for all the cover at
#     every present unit is left out, as v2 leaves it out: with an
#     intercept as well it cannot be estimated. Terms the stage
#     holds constant (Climate, sampling effort, pAspen) are not
#     cover.
# ---

# 1. Setup ----

## 1.1 Load packages ----
# Base R only.

# 2. select_hurdle() ----

#' Fit a Hurdle Model: Presence, Then Abundance Given Presence
#'
#' @inheritParams select_single
#' @param grid A prediction grid, or NULL; without one there are
#'   no outputs, only the presence half's coefficients.
#' @param constants,grid_constants Named lists of values held
#'   fixed on the grid: sampling effort, Climate, pAspen. Their
#'   names are also the terms that are not cover.
#' @param intercept_cats Character vector, parallel to `models`,
#'   naming each candidate's reference category, or NULL.
#' @param part_selection Character. The rule each half runs.
#' @param abundance_family A family for the abundance half.
#' @param abundance_response A function(values, data) computing
#'   the abundance response from the raw values, or NULL to take
#'   the raw values as they are.
#' @param abundance_drop Character vector of terms the abundance
#'   half leaves out.
#' @param abundance_null Character. An extra abundance candidate,
#'   or NULL for none.
#' @param abundance_weighted Logical. Weight the abundance half
#'   as the presence half is weighted. v2 does not.
#' @return A selection result for the presence half, with `parts`
#'   (both halves' selection results), `winner` (the presence
#'   candidate chosen), `reference_category` and `outputs`.
#'
#' @example # Example usage of the function
#' # select_hurdle(models, response ~ 1, d, get_engine("glm"),
#' #               "binomial", grid = grid)
select_hurdle <- function(
  models, base, data, engine, family,
  weights = NULL, offset = NULL, ic = "AICc", control = list(),
  grid = NULL, constants = list(), grid_constants = list(),
  intercept_cats = NULL,
  part_selection = "aic_best",
  abundance_family = stats::Gamma(link = "log"),
  abundance_response = NULL,
  abundance_drop = "Climate",
  abundance_null = ". ~ . + seas_days",
  abundance_weighted = FALSE
) {
  response <- all.vars(base[[2]])
  raw <- if ("response_raw" %in% names(data)) {
    data$response_raw
  } else {
    data[[response]]
  }
  failed <- function(table) {
    selection_result(NULL, NULL, table)
  }

  # Step 1: Presence, on every unit
  presence <- selection_run(
    part_selection, models, base, data, engine, family,
    weights, offset, ic, control
  )

  if (is.null(presence$fit) || !isTRUE(presence$fit$ok)) {
    return(failed(presence$ic_table))
  }

  scores <- presence$ic_table$ic
  winner <- if (any(is.finite(scores))) which.min(scores) else 1L

  # Step 2: Abundance given presence, on the units with any
  present <- !is.na(raw) & raw > 0

  if (sum(present) < 2) {
    return(failed(presence$ic_table))
  }

  d_p <- data[present, , drop = FALSE]
  d_p[[response]] <- if (is.function(abundance_response)) {
    abundance_response(raw[present], d_p)
  } else {
    raw[present]
  }

  abundance_models <- hurdle_abundance_models(
    presence, models, base, d_p, engine, abundance_drop,
    abundance_null, held = names(c(constants, grid_constants))
  )

  abundance <- selection_run(
    part_selection, abundance_models, base, d_p, engine,
    abundance_family,
    weights = if (abundance_weighted && !is.null(weights)) {
      weights[present]
    } else {
      NULL
    },
    offset = NULL, ic = ic, control = control
  )

  if (is.null(abundance$fit) || !isTRUE(abundance$fit$ok)) {
    return(failed(presence$ic_table))
  }

  # Step 3: Each half, and their product, on the grid
  result <- presence
  result$parts <- list(presence = presence, abundance = abundance)
  result$winner <- winner
  result$reference_category <- if (is.null(intercept_cats)) {
    NULL
  } else {
    intercept_cats[winner]
  }

  if (!is.null(grid)) {
    held <- c(constants, grid_constants)
    on_grid <- lapply(result$parts, predict_grid, grid = grid,
                      constants = held)

    if (!any(vapply(on_grid, is.null, logical(1)))) {
      table_of <- function(values) {
        data.frame(
          term = names(values), estimate = unname(values),
          se = NA_real_, stringsAsFactors = FALSE
        )
      }

      result$outputs <- list(
        presence = table_of(on_grid$presence),
        abundance = table_of(on_grid$abundance),
        total = table_of(on_grid$presence * on_grid$abundance)
      )
    }
  }

  result
}

# 3. hurdle_abundance_models() ----

#' The Abundance Half's Candidates
#'
#' @param presence The presence half's selection result.
#' @param models The presence candidates as given.
#' @param base The base formula.
#' @param d_p The units where the species was present.
#' @param engine An engine definition.
#' @param drop,null As `abundance_drop` and `abundance_null`.
#' @param held Character vector of terms that are not cover.
#' @return A list of formulas.
#'
#' @example # Example usage of the function
#' # hurdle_abundance_models(presence, models, response ~ 1, d_p,
#' #                         engine, "Climate", NULL, "seas_days")
hurdle_abundance_models <- function(presence, models, base, d_p,
                                    engine, drop, null, held) {
  response <- all.vars(base[[2]])
  base_text <- paste(deparse(base[[3]]), collapse = " ")
  has_offset <- grepl("offset(offset)", base_text, fixed = TRUE)

  # A presence candidate that could not be fitted has no abundance
  # counterpart, as in v2. A rule that fits only some candidates
  # (single) reports only those.
  table <- presence$ic_table
  formulas <- lapply(models, resolve_formula, base = base)

  fitted_n <- if (is.null(table)) 1L else nrow(table)

  formulas <- if (fitted_n == length(formulas)) {
    formulas[table$ok]
  } else {
    formulas[seq_len(min(fitted_n, length(formulas)))]
  }

  check_cover <- engine_has(engine, "coefficients")

  candidates <- lapply(formulas, function(f) {
    terms <- attr(stats::terms(f), "term.labels")

    # Identifiable with an intercept only if some cover is left
    # unaccounted for at some unit
    if (check_cover) {
      cover <- intersect(setdiff(terms, held), names(d_p))
      used <- sum(colSums(d_p[, cover, drop = FALSE]))

      if ((nrow(d_p) - used) <= 0) {
        return(NULL)
      }
    }

    kept <- setdiff(terms, drop)

    stats::as.formula(paste(
      response, "~",
      paste(c(if (length(kept) == 0) "1" else kept,
              if (has_offset) "offset(offset)"),
            collapse = " + ")
    ))
  })

  candidates <- Filter(Negate(is.null), candidates)

  if (!is.null(null)) {
    candidates <- c(
      candidates, list(resolve_formula(stats::as.formula(null), base))
    )
  }

  candidates
}

# 4. Register ----
register_selection(
  "hurdle", select_hurdle,
  paste(
    "Presence, then abundance given presence, each with an inner",
    "rule (v2 mammals)"
  ),
  requires = character(0)
)

# End of script ----
