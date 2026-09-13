# ---
# title: Fitting Engines
# author: Brendan Casey
# created: 2026-09-09
# inputs: none
# outputs: none; returns objects in memory
# notes:
#   - A engine is a fitting method behind one interface, so that
#     swapping GLM for a boosted tree is a one-word change in an
#     experiment rather than a rewrite. Every engine supplies
#     fit, coef, predict and ic; an engine that has no
#     coefficients returns NULL from coef, and the result writer
#     records that rather than failing.
#   - Registered here: `glm` and `bayesglm`. `gbm` and `brms`
#     come later; the registry is what they slot into.
#   - bayesglm and glm sit on different axes and should not be
#     read as "frequentist versus Bayesian". bayesglm is
#     penalized maximum likelihood - augmented IRLS under weakly
#     informative Cauchy priors - giving a point estimate and a
#     standard error, with no posterior. It belongs on a
#     regularization axis. A Bayesian framework comparison needs
#     brms or rstanarm.
#   - The plant v2 models use bayesglm because rare species fitted
#     against 30-term habitat formulas separate completely, and
#     plain glm then returns infinite coefficients. The
#     regularization is load-bearing there, not incidental, so
#     swapping plants to glm as a control will fail outright for
#     the rare end of the species list rather than give a clean
#     comparison.
#   - predict() takes an `se` flag. Inverse-variance averaging
#     weights each candidate by the precision of its prediction,
#     so an engine that cannot return a standard error cannot
#     use that selection rule. Tree and boosting engines will
#     need a different weighting when they arrive.
#   - Fitting failures are caught and returned, not raised. A
#     candidate model set is expected to contain models that
#     cannot be estimated for a given species and bootstrap, and
#     the selection rule needs to see which ones failed.
# ---

# 1. Setup ----

## 1.1 Load packages ----
# arm is loaded lazily by the bayesglm engine rather than here,
# so a run that never uses it does not need it installed.

# 2. Engine registry ----

## 2.1 engine_registry() ----

#' The Available Fitting Engines
#'
#' Each entry supplies four functions: `fit`, `coef`, `predict`
#' and `ic`. Adding an engine means adding an entry, not
#' touching the fitting loop.
#'
#' @return A named list of engine definitions.
#'
#' @example # Example usage of the function
#' # names(engine_registry())
engine_registry <- function() {
  list(
    glm = engine_glm(),
    bayesglm = engine_bayesglm()
  )
}

## 2.2 get_engine() ----

#' Look Up One Engine
#'
#' @param name Character. Engine name.
#' @param registry Named list of engine definitions.
#' @return The engine definition.
#'
#' @example # Example usage of the function
#' # get_engine("glm")
get_engine <- function(name, registry = engine_registry()) {
  if (!name %in% names(registry)) {
    stop(
      "Unknown engine `", name, "`. Registered: ",
      paste(names(registry), collapse = ", "),
      call. = FALSE
    )
  }

  registry[[name]]
}

# 3. engine_glm() ----

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
    has_coefficients = TRUE,
    fit = function(formula, data, family, weights = NULL,
                   offset = NULL, control = list()) {
      fit_glm_family(
        stats::glm, formula, data, family, weights, offset,
        control
      )
    },
    coef = function(fit) fit_coefficients(fit),
    predict = function(fit, newdata, type = "link", se = FALSE) {
      fit_predict(fit, newdata, type, se)
    },
    ic = function(fit, type = "AICc") information_criterion(fit, type)
  )
}

# 4. engine_bayesglm() ----

#' Penalized GLM with Weakly Informative Priors
#'
#' `arm::bayesglm` with its default Cauchy priors, which is what
#' the v2 plant models use. See the header on why this is not a
#' Bayesian framework in the sense a framework comparison means.
#'
#' @return An engine definition.
#'
#' @example # Example usage of the function
#' # e <- engine_bayesglm()
engine_bayesglm <- function() {
  list(
    name = "bayesglm",
    has_coefficients = TRUE,
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
    coef = function(fit) fit_coefficients(fit),
    predict = function(fit, newdata, type = "link", se = FALSE) {
      fit_predict(fit, newdata, type, se)
    },
    ic = function(fit, type = "AICc") information_criterion(fit, type)
  )
}

# 5. Shared implementations ----
# glm and bayesglm take the same arguments and return objects of
# the same shape, so the four operations are written once.

## 5.1 fit_glm_family() ----

#' Fit a GLM-Family Model, Catching Failure
#'
#' @param fitter Function. stats::glm or arm::bayesglm.
#' @param formula A model formula.
#' @param data A data frame.
#' @param family Character or family object.
#' @param weights Numeric vector or NULL.
#' @param offset Numeric vector or NULL.
#' @param control Named list of extra arguments to the fitter.
#' @return A list with `fit` (or NULL), `ok`, and `message`.
#'
#' @example # Example usage of the function
#' # fit_glm_family(stats::glm, y ~ x, d, "binomial")
fit_glm_family <- function(
  fitter,
  formula,
  data,
  family,
  weights = NULL,
  offset = NULL,
  control = list()
) {
  args <- c(
    list(formula = formula, data = data, family = family),
    control
  )

  # Weights and offsets are passed as values rather than named in
  # the formula, so the same formula serves a taxon that has them
  # and one that does not.
  if (!is.null(weights)) {
    args$weights <- weights
  }

  if (!is.null(offset)) {
    args$offset <- offset
  }

  # A candidate set is expected to hold models that cannot be
  # estimated for a given species and draw. The selection rule
  # needs to see which failed, so failure is returned, not raised.
  out <- tryCatch(
    list(
      fit = do.call(fitter, args),
      ok = TRUE,
      message = NA_character_
    ),
    error = function(e) {
      list(fit = NULL, ok = FALSE, message = conditionMessage(e))
    },
    warning = function(w) {
      # A convergence warning still leaves a usable fit, so it is
      # recorded rather than treated as a failure
      suppressWarnings(
        list(
          fit = do.call(fitter, args),
          ok = TRUE,
          message = conditionMessage(w)
        )
      )
    }
  )

  out
}

## 5.2 fit_coefficients() ----

#' Take Coefficients and Standard Errors from a Fit
#'
#' @param fit A list from fit_glm_family().
#' @return A data frame of term, estimate and se, or NULL when
#'   the fit failed.
#'
#' @example # Example usage of the function
#' # fit_coefficients(fit)
fit_coefficients <- function(fit) {
  if (is.null(fit) || !isTRUE(fit$ok) || is.null(fit$fit)) {
    return(NULL)
  }

  estimates <- stats::coef(fit$fit)
  errors <- tryCatch(
    stats::coef(summary(fit$fit))[, "Std. Error"],
    error = function(e) rep(NA_real_, length(estimates))
  )

  data.frame(
    term = names(estimates),
    estimate = as.numeric(estimates),
    se = as.numeric(errors[match(names(estimates), names(errors))]),
    stringsAsFactors = FALSE
  )
}

## 5.3 fit_predict() ----

#' Predict from a Fit
#'
#' @param fit A list from fit_glm_family().
#' @param newdata A data frame to predict onto.
#' @param type Character. "link" or "response".
#' @param se Logical. Return standard errors alongside the fit.
#'   Inverse-variance averaging needs them, and an engine that
#'   cannot supply them cannot use that selection rule.
#' @return A numeric vector, or when `se` is TRUE a list of `fit`
#'   and `se.fit`. NULL when the fit failed.
#'
#' @example # Example usage of the function
#' # fit_predict(fit, prediction_grid, type = "response")
#' # fit_predict(fit, grid, "link", se = TRUE)$se.fit
fit_predict <- function(fit, newdata, type = "link", se = FALSE) {
  if (is.null(fit) || !isTRUE(fit$ok) || is.null(fit$fit)) {
    return(NULL)
  }

  tryCatch(
    {
      predicted <- stats::predict(
        fit$fit, newdata = newdata, type = type, se.fit = se
      )

      if (!se) {
        return(as.numeric(predicted))
      }

      list(
        fit = as.numeric(predicted$fit),
        se.fit = as.numeric(predicted$se.fit)
      )
    },
    error = function(e) NULL
  )
}

## 5.4 information_criterion() ----

#' Score a Fit for Model Selection
#'
#' AICc rather than AIC, because the candidate sets are large
#' relative to the number of survey units a rare species is
#' detected at.
#'
#' @param fit A list from fit_glm_family().
#' @param type Character. "AIC", "AICc" or "BIC".
#' @return A numeric value; Inf when the fit failed, so a failed
#'   model never wins a selection.
#'
#' @example # Example usage of the function
#' # information_criterion(fit, "BIC")
information_criterion <- function(fit, type = "AICc") {
  if (is.null(fit) || !isTRUE(fit$ok) || is.null(fit$fit)) {
    return(Inf)
  }

  value <- tryCatch(
    switch(
      type,
      AIC = stats::AIC(fit$fit),
      BIC = stats::BIC(fit$fit),
      AICc = {
        k <- length(stats::coef(fit$fit))
        n <- stats::nobs(fit$fit)
        # The correction is undefined once the parameter count
        # reaches the sample size; Inf keeps such a model out of
        # the selection rather than returning a negative score.
        if (is.na(n) || n - k - 1 <= 0) {
          Inf
        } else {
          stats::AIC(fit$fit) + (2 * k * (k + 1)) / (n - k - 1)
        }
      },
      stop(
        "Unknown information criterion `", type, "`.",
        call. = FALSE
      )
    ),
    error = function(e) Inf
  )

  if (is.na(value)) Inf else value
}

## 5.5 fit_converged() ----

#' Did a Fit Converge
#'
#' Inverse-variance averaging drops non-converged candidates
#' rather than down-weighting them, which is what the v2 plant
#' code does.
#'
#' @param fit A list from fit_glm_family().
#' @return Logical. FALSE when the fit failed or did not
#'   converge.
#'
#' @example # Example usage of the function
#' # fit_converged(fit)
fit_converged <- function(fit) {
  if (is.null(fit) || !isTRUE(fit$ok) || is.null(fit$fit)) {
    return(FALSE)
  }

  converged <- fit$fit$converged

  if (is.null(converged)) {
    return(TRUE)
  }

  isTRUE(converged)
}

## 5.6 fit_nobs() ----

#' Number of Observations a Fit Used
#'
#' @param fit A list from fit_glm_family().
#' @return An integer, or NA when the fit failed.
#'
#' @example # Example usage of the function
#' # fit_nobs(fit)
fit_nobs <- function(fit) {
  if (is.null(fit) || !isTRUE(fit$ok) || is.null(fit$fit)) {
    return(NA_integer_)
  }

  as.integer(stats::nobs(fit$fit))
}

# End of script ----
