# ---
# title: Engine - Penalized GLM with Weakly Informative Priors
# author: Brendan Casey
# created: 2026-09-09
# inputs: none
# outputs: registers the `bayesglm` engine
# notes:
#   - arm::bayesglm with default Cauchy priors, as the v2 plant
#     models use. It is penalized maximum likelihood (point
#     estimate and SE, no posterior), so glm vs bayesglm is a
#     regularization contrast, not frequentist vs Bayesian.
#   - Rare plant species separate completely under 30-term habitat
#     formulas, so plain glm fails for them; the penalty is
#     load-bearing.
#   - arm is loaded lazily, only when this engine is used.
# ---

# 1. Setup ----

## 1.1 Load packages ----
# arm, lazily; see the header.

# 2. engine_bayesglm() ----

#' Penalized GLM with Weakly Informative Priors
#'
#' @return An engine definition.
#'
#' @example # Example usage of the function
#' # e <- engine_bayesglm()
engine_bayesglm <- function() {
  list(
    name = "bayesglm",
    description = paste(
      "Penalized GLM, weakly informative Cauchy priors",
      "(arm::bayesglm)"
    ),
    capabilities = c("coefficients", "ic", "se", "converged"),
    fit = function(formula, data, family, weights = NULL,
                   offset = NULL, control = list()) {
      if (!requireNamespace("arm", quietly = TRUE)) {
        stop(
          "The bayesglm engine needs the arm package.",
          call. = FALSE
        )
      }

      # maxit defaults to the v2 value, which was raised from the
      # arm default because rare species converge slowly
      if (is.null(control$maxit)) {
        control$maxit <- 250
      }

      fit_glm_family(
        arm::bayesglm, formula, data, family, weights, offset,
        control
      )
    },
    coef = fit_coefficients,
    predict = function(fit, newdata, type = "link", se = FALSE) {
      fit_predict(fit, newdata, type, se)
    },
    ic = function(fit, type = "AICc") {
      information_criterion(fit, type)
    },
    converged = fit_converged,
    nobs = fit_nobs
  )
}

# 3. Register ----
register_engine(engine_bayesglm())

# End of script ----
