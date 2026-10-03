# ---
# title: Evaluation Metrics
# author: Brendan Casey
# created: 2026-09-09
# inputs: none
# outputs: none; returns objects in memory
# notes:
#   - Metrics are what experiments are compared on, so a change
#     affects every past and future experiment and should be
#     reviewed on that basis.
#   - The metrics themselves live in 1_code/methods/metrics/, one
#     file each, registered by name. Every metric takes observed
#     and predicted vectors on the response scale and returns one
#     number.
#   - Metrics are computed from predictions, never from a fitted
#     object, so a GLM and a boosted tree are scored the same way.
#   - A metric that cannot be computed returns NA rather than
#     stopping. A bootstrap where a species was never detected
#     has no AUC, and that is a fact about the draw, not an error.
# ---

# 1. Setup ----

## 1.1 Load packages ----
# Base R only.

# 2. default_metrics() ----

#' The Metrics Scored When a Run Names None
#'
#' Every registered metric. The seven original ones come first in
#' their original order, so a metrics table lists them the same
#' way it always has; any added later follow alphabetically.
#'
#' @return A character vector of metric names.
#'
#' @example # Example usage of the function
#' # default_metrics()
default_metrics <- function() {
  core <- c(
    "auc", "deviance_explained", "rmse", "spearman",
    "calibration_slope", "prevalence", "n"
  )
  registered <- registered_names("metric")

  c(intersect(core, registered), sort(setdiff(registered, core)))
}

# 3. compute_metrics() ----

#' Score One Set of Predictions
#'
#' @param observed Numeric vector of observed values.
#' @param predicted Numeric vector of predictions, on the
#'   response scale.
#' @param metrics Character vector of metric names, or NULL for
#'   default_metrics().
#' @return A data frame of metric and value.
#'
#' @example # Example usage of the function
#' # compute_metrics(obs, pred, metrics = c("auc", "rmse"))
compute_metrics <- function(observed, predicted, metrics = NULL) {
  if (is.null(metrics)) {
    metrics <- default_metrics()
  }

  # Looked up first, so a misspelt metric stops the run here
  functions <- lapply(
    stats::setNames(metrics, metrics),
    function(name) get_method("metric", name)
  )

  # Step 1: Drop pairs where either side is missing, so every
  # metric sees the same rows
  keep <- is.finite(observed) & is.finite(predicted)
  observed <- observed[keep]
  predicted <- predicted[keep]

  # Step 2: Score, letting an uncomputable metric return NA. A
  # warning is muffled rather than caught, so the metric is
  # computed once.
  values <- vapply(
    metrics,
    function(name) {
      tryCatch(
        withCallingHandlers(
          as.numeric(functions[[name]](observed, predicted)),
          warning = function(w) invokeRestart("muffleWarning")
        ),
        error = function(e) NA_real_
      )
    },
    numeric(1)
  )

  data.frame(
    metric = metrics,
    value = unname(values),
    stringsAsFactors = FALSE
  )
}

# End of script ----
