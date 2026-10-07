# ---
# title: Metric - Deviance Explained
# author: Brendan Casey
# created: 2026-09-09
# inputs: none
# outputs: registers the `deviance_explained` metric
# notes:
#   - Metric contract: see register_metric() (harness/registry.R).
# ---

# 1. Setup ----

## 1.1 Load packages ----
# Base R only.

# 2. metric_deviance_explained() ----

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

# 3. Register ----
register_metric(
  "deviance_explained", metric_deviance_explained,
  "Share of null deviance explained (Bernoulli or Poisson)"
)

# End of script ----
