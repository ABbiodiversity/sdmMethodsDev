# ---
# title: Metric - Area Under the ROC Curve
# author: Brendan Casey
# created: 2026-09-09
# inputs: none
# outputs: registers the `auc` metric
# notes:
#   - Metric contract: see register_metric() (harness/registry.R).
# ---

# 1. Setup ----

## 1.1 Load packages ----
# Base R only.

# 2. metric_auc() ----

#' Area Under the ROC Curve
#'
#' Mann-Whitney form (ties count a half). Values above zero are
#' detections, so counts and densities score like presences.
#'
#' @param observed,predicted Numeric vectors.
#' @return A number between 0 and 1, or NA when the observations
#'   are all detections or all non-detections.
#'
#' @example # Example usage of the function
#' # metric_auc(c(0, 0, 1, 1), c(0.1, 0.3, 0.4, 0.9))
metric_auc <- function(observed, predicted) {
  positive <- observed > 0

  # Both classes are needed; a draw without detections has none
  if (!any(positive) || all(positive)) {
    return(NA_real_)
  }

  ranks <- rank(predicted, ties.method = "average")

  # Doubles, not integers: at bird scale the product of the class
  # counts (~3.3e9) overflows 32-bit integers to NA
  n_pos <- as.numeric(sum(positive))
  n_neg <- as.numeric(sum(!positive))

  (sum(ranks[positive]) - n_pos * (n_pos + 1) / 2) /
    (n_pos * n_neg)
}

# 3. Register ----
register_metric(
  "auc", metric_auc,
  "Area under the ROC curve (Mann-Whitney, ties count a half)"
)

# End of script ----
