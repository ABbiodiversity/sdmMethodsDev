# ---
# title: Metric - Prevalence
# author: Brendan Casey
# created: 2026-09-09
# inputs: none
# outputs: registers the `prevalence` metric
# notes:
#   - Metric contract: see register_metric() (harness/registry.R).
# ---

# 1. Setup ----

## 1.1 Load packages ----
# Base R only.

# 2. metric_prevalence() ----

#' Proportion of Survey Units with a Detection
#'
#' Reported because most scores are only interpretable against
#' it.
#'
#' @param observed,predicted Numeric vectors.
#' @return A number between 0 and 1.
#'
#' @example # Example usage of the function
#' # metric_prevalence(c(0, 0, 1), c(0, 0, 0))
metric_prevalence <- function(observed, predicted) {
  mean(observed > 0)
}

# 3. Register ----
register_metric(
  "prevalence", metric_prevalence,
  "Proportion of units with a detection"
)

# End of script ----
