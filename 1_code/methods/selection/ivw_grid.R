# ---
# title: Selection Rule - Inverse-Variance Averaging onto a Grid
# author: Brendan Casey
# created: 2026-09-09
# inputs: none
# outputs: registers the `ivw_grid` rule
# notes:
#   - The v2 plant habitat rule, and the one place where a
#     "coefficient" is not a regression coefficient. v2 fits each
#     candidate, predicts it onto the prediction matrix - one row
#     per habitat type - and combines those predictions across
#     candidates weighting each by the precision of its own
#     prediction. The result is an effect per habitat type on the
#     link scale, which is what the v2 coefficient tables hold.
#   - Weighting by precision rather than by AICc is a different
#     claim: a candidate that is confident about a habitat type
#     dominates there even if it is a poor model overall, and the
#     weighting is per habitat type rather than per model.
#   - Non-converged candidates are dropped from the grid average,
#     not down-weighted, matching v2. A zero standard error is
#     floored at 1e-4, because a precision weight of 1/0 would take
#     the whole average.
#   - The site-level prediction - v2 keeps it as `data$prediction`
#     and uses it as the offset of its stand-age splines - is the
#     result's `predict()` on the link scale. It averages every
#     fitted candidate, converged or not, as v2 does; one that
#     failed outright is left out, where v2's would turn the whole
#     average into NaN. It is computed when a step asks for it,
#     not on every draw.
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

  # A zero standard error would carry infinite weight
  error[error == 0] <- 1e-4

  grid_coefficients <- ivw_combine(estimate, error)

  # Step 2: The leading coefficients are averaged the same way,
  # from each model's own coefficient table rather than from a
  # prediction. Read by position, as v2 reads them: the head
  # terms lead every candidate's formula.
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

  # Each fitted candidate's own coefficients, for steps that
  # average a term the grid does not carry: v2's pAspen.
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

  # The variance of the combined estimate is the reciprocal of
  # the summed precision, not its mean, so adding candidates
  # sharpens rather than dilutes it.
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
