# ---
# title: Selection Rule - Best Model, Predicted onto a Grid
# author: Brendan Casey
# created: 2026-09-09
# inputs: none
# outputs: registers the `aic_best_grid` rule
# notes:
#   - The v2 mammal abundance-given-presence rule. Predicts the
#     winning model onto the shared prediction matrix and reports
#     one effect per grid row.
#   - No calibration is applied. v2 calibrates the product of the
#     two hurdle halves multiplicatively rather than each half
#     separately, because an additive shift on a log-scale
#     abundance can send a small prediction negative and `log` of
#     that is not a number.
# ---

# 1. Setup ----

## 1.1 Load packages ----
# Base R only.

# 2. select_aic_best_grid() ----

#' Best Model, Predicted onto a Prediction Grid
#'
#' @inheritParams select_single
#' @param grid A prediction grid.
#' @param constants Named list of values held fixed across the
#'   grid - sampling effort and climate.
#' @param scale Character. "link" reports the linear predictor,
#'   which for a log-link Gamma is log abundance; "response"
#'   exponentiates it.
#' @return A selection result, one effect per grid row.
#'
#' @example # Example usage of the function
#' # select_aic_best_grid(models, response ~ 1, d, engine,
#' #                      Gamma(link = "log"), grid = grid)
select_aic_best_grid <- function(
  models, base, data, engine, family,
  weights = NULL, offset = NULL, ic = "AICc", control = list(),
  grid = NULL, constants = list(), scale = "link"
) {
  if (is.null(grid)) {
    stop(
      "The aic_best_grid rule needs a prediction grid.",
      call. = FALSE
    )
  }

  fitted <- fit_candidates(
    models, base, data, engine, family, weights, offset, ic,
    control
  )

  table <- candidate_table(fitted)

  if (!any(table$ok)) {
    return(selection_result(NULL, NULL, table, fitted))
  }

  winner <- which.min(fitted$scores)
  best <- fitted$fits[[winner]]

  newdata <- grid

  for (one in names(constants)) {
    newdata[[one]] <- constants[[one]]
  }

  # A grid row describes a pure stand, so a term the grid has no
  # column for is genuinely absent rather than unknown.
  terms <- formula_variables(fitted$formulas[[winner]])

  for (one in setdiff(terms, names(newdata))) {
    newdata[[one]] <- 0
  }

  predicted <- engine$predict(best, newdata, scale, se = TRUE)

  if (is.null(predicted)) {
    return(selection_result(NULL, NULL, table, fitted))
  }

  selection_result(
    fit = best,
    coefficients = data.frame(
      term = rownames(grid),
      estimate = predicted$fit,
      se = predicted$se.fit,
      stringsAsFactors = FALSE
    ),
    ic_table = table,
    fitted = fitted,
    engine = engine
  )
}

# 3. Register ----
register_selection(
  "aic_best_grid", select_aic_best_grid,
  paste(
    "Best candidate by AICc, predicted onto the habitat grid",
    "(v2 mammal abundance)"
  ),
  requires = c("ic", "se")
)

# End of script ----
