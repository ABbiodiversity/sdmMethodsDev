# ---
# title: Selection Rule - Inverse-Variance Averaging onto a Grid
# author: Brendan Casey
# created: 2026-09-09
# inputs: none
# outputs: registers the `ivw_grid` rule
# notes:
#   - The v2 plant habitat rule. Candidates are predicted onto the
#     grid and combined per habitat type by inverse variance, so a
#     "coefficient" is a link-scale effect per habitat type.
#   - Unlike AICc weighting, a candidate confident about one
#     habitat type dominates there even if it is poor overall.
#   - Non-converged candidates are dropped from the grid average
#     (as v2). Zero SEs are floored at 1e-4.
#   - `predict()` gives v2's site-level `data$prediction` (offset
#     of the stand-age splines): every fitted candidate, converged
#     or not, as v2; failed fits are left out (v2 would give NaN).
# ---

# 1. Setup ----

## 1.1 Load packages ----
# Base R only.

# 2. select_ivw_grid() ----

#' Inverse-Variance Average Predictions onto a Grid
#'
#' @inheritParams select_single
#' @param grid A prediction grid, one row per habitat type.
#' @param grid_constants Named list of values for terms the grid
#'   has no column for - v2 predicts at `Climate = 0` and, where
#'   Protocol is fitted, at the new protocol.
#' @param head_terms Character vector of leading model
#'   coefficients to average separately and prepend, which is how
#'   v2 carries Intercept, Climate and Protocol.
#' @return A selection result whose `coefficients` are the
#'   averaged per-habitat-type effects, with
#'   `candidate_coefficients` for steps that average a term the
#'   grid does not carry.
#'
#' @example # Example usage of the function
#' # select_ivw_grid(models, response ~ 1, d, engine, "binomial",
#' #                 grid = veg_grid,
#' #                 grid_constants = list(Climate = 0))
select_ivw_grid <- function(
  models, base, data, engine, family,
  weights = NULL, offset = NULL, ic = "AICc", control = list(),
  grid = NULL, grid_constants = list(),
  head_terms = c("Intercept", "Climate")
) {
  if (is.null(grid)) {
    stop(
      "The ivw_grid rule needs a prediction grid; the spec's ",
      "region defines one with `grid`.",
      call. = FALSE
    )
  }

  fitted <- fit_candidates(
    models, base, data, engine, family, weights, offset, ic,
    control
  )

  table <- candidate_table(fitted)
  converged <- vapply(
    fitted$fits, function(f) engine_converged(engine, f), logical(1)
  )

  if (!any(converged)) {
    return(selection_result(NULL, NULL, table, fitted))
  }

  # Step 1: Predict every converged candidate onto the grid, at
  # the constants v2 holds the non-habitat terms at
  newdata <- grid

  for (one in names(grid_constants)) {
    newdata[[one]] <- grid_constants[[one]]
  }

  predictions <- lapply(seq_along(fitted$fits), function(i) {
    if (!converged[i]) {
      return(NULL)
    }

    engine$predict(fitted$fits[[i]], newdata, "link", se = TRUE)
  })

  usable <- !vapply(predictions, is.null, logical(1))

  if (!any(usable)) {
    return(selection_result(NULL, NULL, table, fitted))
  }

  estimate <- do.call(
    rbind, lapply(predictions[usable], function(x) x$fit)
  )
  error <- do.call(
    rbind, lapply(predictions[usable], function(x) x$se.fit)
  )

  error[error == 0] <- 1e-4

  grid_coefficients <- ivw_combine(estimate, error)

  # Step 2: Head terms, from each model's coefficient table, read
  # by position as v2 does (they lead every formula)
  head_estimate <- do.call(rbind, lapply(
    which(converged), function(i) {
      fitted$fits[[i]]$coefficients$estimate[seq_along(head_terms)]
    }
  ))
  head_error <- do.call(rbind, lapply(
    which(converged), function(i) {
      fitted$fits[[i]]$coefficients$se[seq_along(head_terms)]
    }
  ))
  head_error[head_error == 0 | is.na(head_error)] <- 1e-4

  head_coefficients <- ivw_combine(head_estimate, head_error)

  coefficients <- data.frame(
    term = c(head_terms, rownames(grid)),
    estimate = c(head_coefficients$estimate,
                 grid_coefficients$estimate),
    se = c(head_coefficients$se, grid_coefficients$se),
    stringsAsFactors = FALSE
  )

  result <- selection_result(
    fit = fitted$fits[[which.min(fitted$scores)]],
    coefficients = coefficients,
    ic_table = table,
    fitted = fitted,
    engine = engine,
    # Step 3: The final model, averaged per site the same way
    predict = combined_predictor(
      fitted$fits[table$ok], engine, family
    )
  )

  # For steps averaging a term the grid lacks (v2's pAspen)
  result$candidate_coefficients <- lapply(
    which(table$ok), function(i) fitted$fits[[i]]$coefficients
  )

  result
}

# 3. ivw_combine() ----

#' Combine Estimates by Inverse-Variance Weight
#'
#' @param estimate Matrix of candidates by columns.
#' @param error Matrix of standard errors, the same shape.
#' @return A list of `estimate` and `se`, one per column.
#'
#' @example # Example usage of the function
#' # ivw_combine(rbind(c(1, 2), c(1.2, 2.1)),
#' #             rbind(c(0.1, 0.2), c(0.3, 0.1)))
ivw_combine <- function(estimate, error) {
  precision <- 1 / error^2

  list(
    estimate = colSums(estimate * precision) / colSums(precision),
    se = sqrt(1 / colSums(precision))
  )
}

# 4. Register ----
register_selection(
  "ivw_grid", select_ivw_grid,
  paste(
    "Inverse-variance average of candidate predictions onto a",
    "habitat grid (v2 plant habitat)"
  ),
  requires = c("coefficients", "se")
)

# End of script ----
