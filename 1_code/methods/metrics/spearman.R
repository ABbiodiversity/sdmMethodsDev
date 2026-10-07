# ---
# title: Metric - Spearman Correlation
# author: Brendan Casey
# created: 2026-09-09
# inputs: none
# outputs: registers the `spearman` metric
# notes:
#   - Metric contract: see register_metric() (harness/registry.R).
# ---

# 1. Setup ----

## 1.1 Load packages ----
# Base R only.

# 2. metric_spearman() ----

#' Rank Correlation of Observed and Predicted
#'
#' Scale-free, so density and count models compare directly.
#'
#' @param observed,predicted Numeric vectors.
#' @return A number between -1 and 1.
#'
#' @example # Example usage of the function
#' # metric_spearman(c(0, 1, 2), c(0.1, 0.5, 0.9))
metric_spearman <- function(observed, predicted) {
  if (stats::sd(observed) == 0 || stats::sd(predicted) == 0) {
    return(NA_real_)
  }

  stats::cor(observed, predicted, method = "spearman")
}

# 3. Register ----
register_metric(
  "spearman", metric_spearman,
  "Rank correlation of observed and predicted"
)

# End of script ----
