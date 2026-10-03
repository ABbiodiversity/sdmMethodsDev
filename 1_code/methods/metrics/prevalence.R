# ---
# title: Metric - Prevalence
# author: Brendan Casey
# created: 2026-09-09
# inputs: none
# outputs: registers the `prevalence` metric
# notes:
#   - Takes observed and predicted vectors on the response scale
#     and returns one number. Computed from predictions only, so
#     every engine is scored the same way.
# ---

# 1. Setup ----

## 1.1 Load packages ----
# Base R only.

# 2. metric_prevalence() ----

#' Proportion of Survey Units with a Detection
#'
#' Carried alongside the scores because most of them are only
#' interpretable against it: an AUC of 0.9 means something
#' different at 2 per cent prevalence than at 40.
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
