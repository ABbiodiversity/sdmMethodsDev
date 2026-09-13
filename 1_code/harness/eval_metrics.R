# ---
# title: Evaluation Metrics
# author: Brendan Casey
# created: 2026-09-09
# inputs: none
# outputs: none; returns objects in memory
# notes:
#   - Metrics computed here are what experiments are compared on,
#     so a change affects every past and future experiment and
#     should be reviewed on that basis.
#   - Every metric takes observed and predicted vectors and
#     returns one number, so the set is extended by adding an
#     entry to metric_registry() rather than by touching the
#     loop.
#   - Metrics are computed from predictions, never from a fitted
#     object, so a GLM and a boosted tree are scored the same way.
#     That is the whole reason predictions rather than
#     coefficients are the comparison currency.
#   - AUC is computed directly rather than through pROC, so the
#     harness does not depend on a package for one number, and so
#     ties are handled explicitly. It is the Mann-Whitney form:
#     the probability a random detection scores above a random
#     non-detection, with ties counting a half.
#   - A metric that cannot be computed returns NA rather than
#     stopping. A bootstrap where a species was never detected
#     has no AUC, and that is a fact about the draw, not an error.
# ---

# 1. Setup ----

## 1.1 Load packages ----
# Base R only, deliberately; see the header.

# 2. metric_registry() ----

#' The Available Metrics
#'
#' @return A named list of functions taking `observed` and
#'   `predicted` and returning one number.
#'
#' @example # Example usage of the function
#' # names(metric_registry())
metric_registry <- function() {
  list(
    auc = metric_auc,
    deviance_explained = metric_deviance_explained,
    rmse = metric_rmse,
    spearman = metric_spearman,
    calibration_slope = metric_calibration_slope,
    prevalence = metric_prevalence,
    n = metric_n
  )
}

# 3. compute_metrics() ----

#' Score One Set of Predictions
#'
#' @param observed Numeric vector of observed values.
#' @param predicted Numeric vector of predictions, on the
#'   response scale.
#' @param metrics Character vector of metric names, or NULL for
#'   every registered metric.
#' @return A data frame of metric and value.
#'
#' @example # Example usage of the function
#' # compute_metrics(obs, pred, metrics = c("auc", "rmse"))
compute_metrics <- function(observed, predicted, metrics = NULL) {
  registry <- metric_registry()

  if (is.null(metrics)) {
    metrics <- names(registry)
  }

  unknown <- setdiff(metrics, names(registry))

  if (length(unknown) > 0) {
    stop(
      "Unknown metric(s): ", paste(unknown, collapse = ", "),
      ". Registered: ", paste(names(registry), collapse = ", "),
      call. = FALSE
    )
  }

  # Step 1: Drop pairs where either side is missing, so every
  # metric sees the same rows
  keep <- is.finite(observed) & is.finite(predicted)
  observed <- observed[keep]
  predicted <- predicted[keep]

  # Step 2: Score, letting an uncomputable metric return NA
  values <- vapply(
    metrics,
    function(name) {
      tryCatch(
        as.numeric(registry[[name]](observed, predicted)),
        error = function(e) NA_real_,
        warning = function(w) {
          suppressWarnings(
            as.numeric(registry[[name]](observed, predicted))
          )
        }
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

# 4. Metric implementations ----

## 4.1 metric_auc() ----

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

## 4.2 metric_deviance_explained() ----

#' Proportion of Null Deviance Explained
#'
#' Poisson deviance for counts, Bernoulli for detections, chosen
#' from whether the observations are all zero or one.
#'
#' @param observed,predicted Numeric vectors.
#' @return A number, or NA when the null deviance is zero.
#'
#' @example # Example usage of the function
#' # metric_deviance_explained(c(0, 1, 2), c(0.2, 0.9, 1.8))
metric_deviance_explained <- function(observed, predicted) {
  binary <- all(observed %in% c(0, 1))

  deviance <- function(y, mu) {
    mu <- pmax(mu, 1e-10)

    if (binary) {
      mu <- pmin(mu, 1 - 1e-10)
      -2 * sum(y * log(mu) + (1 - y) * log(1 - mu))
    } else {
      terms <- ifelse(y > 0, y * log(y / mu), 0)
      2 * sum(terms - (y - mu))
    }
  }

  null_deviance <- deviance(
    observed, rep(mean(observed), length(observed))
  )

  if (!is.finite(null_deviance) || null_deviance <= 0) {
    return(NA_real_)
  }

  1 - deviance(observed, predicted) / null_deviance
}

## 4.3 metric_rmse() ----

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

## 4.4 metric_spearman() ----

#' Rank Correlation of Observed and Predicted
#'
#' Scale-free, so it compares a density model against a count
#' model without either being rescaled.
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

## 4.5 metric_calibration_slope() ----

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

## 4.6 metric_prevalence() ----

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

## 4.7 metric_n() ----

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

# End of script ----
