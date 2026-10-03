# ---
# title: Engine - Penalized GLM with Weakly Informative Priors
# author: Brendan Casey
# created: 2026-09-09
# inputs: none
# outputs: registers the `bayesglm` engine
# notes:
#   - arm::bayesglm with its default Cauchy priors, which is what
#     the v2 plant models use.
#   - bayesglm and glm sit on different axes and should not be
#     read as "frequentist versus Bayesian". bayesglm is
#     penalized maximum likelihood - augmented IRLS under weakly
#     informative Cauchy priors - giving a point estimate and a
#     standard error, with no posterior. It belongs on a
#     regularization axis. A Bayesian framework comparison needs
#     brms or rstanarm.
#   - The plant v2 models use it because rare species fitted
#     against 30-term habitat formulas separate completely, and
#     plain glm then returns infinite coefficients. The
#     regularization is load-bearing, so swapping plants to glm as
#     a control will fail outright for the rare end of the species
#     list rather than give a clean comparison.
#   - arm is loaded lazily, so a run that never uses this engine
#     does not need it installed.
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
