# ---
# title: Selection Rule - [Name]
# author: [Your Name]
# created: [YYYY-MM-DD]
# inputs: none
# outputs: registers the `[name]` rule
# notes:
#   - A template. Copy to 1_code/methods/selection/[name].R and
#     fill it in. Then name it in a spec stage:
#     `selection = "[name]"`.
#   - A rule turns a candidate set into one result. It fits its
#     own candidates, with fit_candidates(), and returns
#     selection_result().
#   - Any argument beyond the standard nine is a setting, filled
#     from the stage field of the same name. A stage with
#     `my_threshold = 3` passes 3 to a rule declaring
#     `my_threshold`. No harness change is needed.
#   - Read coefficients with engine_coef(engine, fit), never with
#     coef() on the fitted object, so the rule works with any
#     engine that declares `coefficients`.
#   - When the rule combines candidates, pass `predict` to
#     selection_result() - combined_predictor() builds one - so
#     metrics and grid predictions use the combined model rather
#     than one candidate.
# ---

# 1. Setup ----

## 1.1 Load packages ----
# Base R only.

# 2. select_[name]() ----

#' [One-line title of the rule]
#'
#' @inheritParams select_single
#' @param [setting] [What the stage field sets.]
#' @return A selection result.
#'
#' @example # Example usage of the function
#' # select_[name](models, response ~ 1, d, get_engine("glm"),
#' #               "binomial")
select_template <- function(
  models, base, data, engine, family,
  weights = NULL, offset = NULL, ic = "AICc", control = list()
) {
  # Step 1: Fit every candidate
  fitted <- fit_candidates(
    models, base, data, engine, family, weights, offset, ic,
    control
  )
  table <- candidate_table(fitted)

  if (!any(table$ok)) {
    return(selection_result(NULL, NULL, table, fitted))
  }

  # Step 2: Choose or combine. [Replace with the rule.]
  chosen <- which(table$ok)[1]

  # Step 3: Return the result
  selection_result(
    fit = fitted$fits[[chosen]],
    coefficients = engine_coef(engine, fitted$fits[[chosen]]),
    ic_table = table,
    fitted = fitted,
    engine = engine
  )
}

# 3. Register ----
# Name the engine capabilities the rule needs in `requires`.
# Uncomment when ready:
# register_selection(
#   "[name]", select_template,
#   "[One line for list_methods()]",
#   requires = character(0)
# )

# End of script ----
