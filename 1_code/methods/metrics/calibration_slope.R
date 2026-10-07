# ---
# title: Metric - Calibration Slope
# author: Brendan Casey
# created: 2026-09-09
# inputs: none
# outputs: registers the `calibration_slope` metric
# notes:
#   - Metric contract: see register_metric() (harness/registry.R).
# ---

# 1. Setup ----

## 1.1 Load packages ----
# Base R only.

# 2. metric_calibration_slope() ----

#' Calibration Slope
#'
#' Slope of observed on predicted. One is perfect; below one
#' means predictions are too extreme (typical of overfitting).
#'
#' @param observed,predicted Numeric vectors.
#' @return A number.
#'
#' @example # Example usage of the function
#' # metric_calibration_slope(c(0, 1, 1), c(0.2, 0.6, 0.8))
metric_calibration_slope <- function(observed, predicted) {
  if (stats::sd(predicted) == 0) {
    return(NA_real_)
  }

  unname(stats::coef(stats::lm(observed ~ predicted))[2])
}

# 3. Register ----
register_metric(
  "calibration_slope", metric_calibration_slope,
  "Slope of observed on predicted; 1 is well calibrated"
)

# End of script ----
