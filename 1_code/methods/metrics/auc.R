# ---
# title: Metric - Area Under the ROC Curve
# author: Brendan Casey
# created: 2026-09-09
# inputs: none
# outputs: registers the `auc` metric
# notes:
#   - Takes observed and predicted vectors on the response scale
#     and returns one number. Computed from predictions only, so
#     every engine is scored the same way.
# ---

# 1. Setup ----

## 1.1 Load packages ----
# Base R only.

# 2. metric_auc() ----

#' Area Under the ROC Curve
#'
#' The Mann-Whitney form: the probability that a randomly chosen
#' detection scores above a randomly chosen non-detection, with
#' ties counting a half. Values above zero are treated as
#' detections, so a count or a density scores the same way a
#' presence does.
#'
#' @param observed,predicted Numeric vectors.
#' @return A number between 0 and 1, or NA when the observations
#'   are all detections or all non-detections.
#'
#' @example # Example usage of the function
#' # metric_auc(c(0, 0, 1, 1), c(0.1, 0.3, 0.4, 0.9))
metric_auc <- function(observed, predicted) {
  positive <- observed > 0

  # An AUC needs both classes present. A bootstrap where a
  # species was never detected has none, which is a fact about
  # the draw rather than a failure.
  if (!any(positive) || all(positive)) {
    return(NA_real_)
  }

  ranks <- rank(predicted, ties.method = "average")

  # Counted as doubles, not integers. sum() of a logical returns
  # an integer, and at bird scale - 16,745 detections against
  # 199,013 non-detections - their product is 3.3e9, past the
  # 32-bit maximum. That overflows to NA silently, so every large
  # run would report no AUC at all.
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
