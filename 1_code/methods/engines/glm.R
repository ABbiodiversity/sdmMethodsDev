# ---
# title: Engine - Generalized Linear Model (glm)
# author: Brendan Casey
# created: 2026-09-09
# inputs: none
# outputs: registers the `glm` engine
# notes:
#   - stats::glm. The engine the v2 mammal and bird models fit
#     with.
#   - Shares its implementation with bayesglm; see
#     _glm_family.R.
# ---

# 1. Setup ----

## 1.1 Load packages ----
# Base R only.

# 2. engine_glm() ----

#' Plain Generalized Linear Model
#'
#' @return An engine definition.
#'
#' @example # Example usage of the function
#' # e <- engine_glm()
#' # fit <- e$fit(response ~ MAP, data, family = "binomial")
engine_glm <- function() {
  list(
    name = "glm",
    description = "Generalized linear model (stats::glm)",
    capabilities = c("coefficients", "ic", "se", "converged"),
    fit = function(formula, data, family, weights = NULL,
                   offset = NULL, control = list()) {
      fit_glm_family(
        stats::glm, formula, data, family, weights, offset,
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
register_engine(engine_glm())

# End of script ----
