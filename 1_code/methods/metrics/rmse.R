# ---
# title: Metric - Root Mean Squared Error
# author: Brendan Casey
# created: 2026-09-09
# inputs: none
# outputs: registers the `rmse` metric
# notes:
#   - Metric contract: see register_metric() (harness/registry.R).
# ---

# 1. Setup ----

## 1.1 Load packages ----
# Base R only.

# 2. metric_rmse() ----

#' Root Mean Squared Error
#'
#' @param observed,predicted Numeric vectors.
#' @return A number.
#'
#' @example # Example usage of the function
#' # metric_rmse(c(0, 1), c(0.1, 0.8))
metric_rmse <- function(observed, predicted) {
  sqrt(mean((observed - predicted)^2))
}

# 3. Register ----
register_metric(
  "rmse", metric_rmse,
  "Root mean squared error"
)

# End of script ----
