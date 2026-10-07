# ---
# title: Metric - Units Scored
# author: Brendan Casey
# created: 2026-09-09
# inputs: none
# outputs: registers the `n` metric
# notes:
#   - Metric contract: see register_metric() (harness/registry.R).
# ---

# 1. Setup ----

## 1.1 Load packages ----
# Base R only.

# 2. metric_n() ----

#' Number of Survey Units Scored
#'
#' @param observed,predicted Numeric vectors.
#' @return An integer.
#'
#' @example # Example usage of the function
#' # metric_n(c(0, 1), c(0.2, 0.7))
metric_n <- function(observed, predicted) {
  length(observed)
}

# 3. Register ----
register_metric(
  "n", metric_n,
  "Number of units scored"
)

# End of script ----
