# ---
# title: Selection Rule - Single Model
# author: Brendan Casey
# created: 2026-09-09
# inputs: none
# outputs: registers the `single` rule
# notes:
#   - Fits the first formula and keeps it. No ranking, so it needs
#     nothing of the engine beyond fit and predict, which makes it
#     the rule for an engine with no information criterion - a
#     boosted tree, say - or for any one-model question.
# ---

# 1. Setup ----

## 1.1 Load packages ----
# Base R only.

# 2. select_single() ----

#' Fit One Model, No Selection
#'
#' @param models A list holding one formula, or a single formula.
#' @param base,data,engine,family,weights,offset,ic,control As in
#'   selection_run().
#' @return A selection result.
#'
#' @example # Example usage of the function
#' # select_single(list(. ~ . + MAP), response ~ 1, d, engine,
#' #               "binomial")
select_single <- function(
  models, base, data, engine, family,
  weights = NULL, offset = NULL, ic = "AICc", control = list()
) {
  if (inherits(models, "formula")) {
    models <- list(models)
  }

  fitted <- fit_candidates(
    models[1], base, data, engine, family, weights, offset, ic,
    control
  )

  selection_result(
    fit = fitted$fits[[1]],
    coefficients = engine_coef(engine, fitted$fits[[1]]),
    ic_table = candidate_table(fitted),
    fitted = fitted,
    engine = engine
  )
}

# 3. Register ----
register_selection(
  "single", select_single,
  "Fit the first candidate only; no ranking"
)

# End of script ----
