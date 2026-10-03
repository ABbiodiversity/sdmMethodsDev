# ---
# title: Metric - Calibration Slope
# author: Brendan Casey
# created: 2026-09-09
# inputs: none
# outputs: registers the `calibration_slope` metric
# notes:
#   - Takes observed and predicted vectors on the response scale
#     and returns one number. Computed from predictions only, so
#     every engine is scored the same way.
# ---

# 1. Setup ----

## 1.1 Load packages ----
# Base R only.

# 2. metric_calibration_slope() ----

#' Calibration Slope
#'
#' The slope of observed on predicted. One is perfect
#' calibration; below one means the predictions are too extreme,
#' which is the usual signature of overfitting and the thing a
#' regularized fit is trying to fix.
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
