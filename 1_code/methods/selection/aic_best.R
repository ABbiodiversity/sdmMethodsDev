# ---
# title: Selection Rule - Best by Information Criterion
# author: Brendan Casey
# created: 2026-09-09
# inputs: none
# outputs: registers the `aic_best` rule
# notes:
#   - Keeps the single candidate with the lowest score (AICc by
#     default; the stage's `ic` sets it).
# ---

# 1. Setup ----

## 1.1 Load packages ----
# Base R only.

# 2. select_aic_best() ----

#' Keep the Single Best-Scoring Candidate
#'
#' @inheritParams select_single
#' @return A selection result.
#'
#' @example # Example usage of the function
#' # select_aic_best(models, response ~ 1, d, engine, "binomial")
select_aic_best <- function(
  models, base, data, engine, family,
  weights = NULL, offset = NULL, ic = "AICc", control = list()
) {
  fitted <- fit_candidates(
    models, base, data, engine, family, weights, offset, ic,
    control
  )

  table <- candidate_table(fitted)

  if (!any(table$ok)) {
    return(selection_result(NULL, NULL, table, fitted))
  }

  winner <- which.min(fitted$scores)

  selection_result(
    fit = fitted$fits[[winner]],
    coefficients = engine_coef(engine, fitted$fits[[winner]]),
    ic_table = table,
    fitted = fitted,
    engine = engine
  )
}

# 3. Register ----
register_selection(
  "aic_best", select_aic_best,
  "Keep the lowest-scoring candidate (AICc, AIC or BIC)",
  requires = "ic"
)

# End of script ----
