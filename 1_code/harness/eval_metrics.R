# ---
# title: Compute Evaluation Metrics
# author: Brendan Casey
# created: 2026-09-05
# inputs: none
# outputs: none
# notes:
#   - Placeholder. Metrics computed here are what experiments
#     are compared on, so changes affect every past and future
#     experiment and should be reviewed accordingly.
#   - The v2 validation scripts compute their own AUC through
#     model_validation(); this is for methods work that does
#     not run the v2 code.
# ---

# 1. eval_metrics() ----

#' Compute Evaluation Metrics
#'
#' Computes the shared evaluation metrics for a model's predictions.
#'
#' @param observed Numeric vector of observed values.
#' @param predicted Numeric vector of predicted values.
#' @param metrics Character vector of metric names to
#'   compute, or NULL for the full set.
#' @return A named numeric vector of metric values.
#'
#' @example
#' # Example usage of the function
#' # eval_metrics()
eval_metrics <- function(observed, predicted, metrics = NULL) {
  # Step 1: Validate that the two vectors align
  # Step 2: Compute each requested metric

  stop(
    "eval_metrics() is not implemented yet.",
    call. = FALSE
  )
}

# End of script ----
