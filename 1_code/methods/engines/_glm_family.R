# ---
# title: Shared Implementation for GLM-Family Engines
# author: Brendan Casey
# created: 2026-09-09
# inputs: none
# outputs: none; defines functions in memory
# notes:
#   - Shared by glm and bayesglm, which take and return the same
#     shapes. The leading underscore makes it load first.
#   - Fitting failures are returned, not raised, so selection
#     rules can see which candidates failed.
# ---

# 1. Setup ----

## 1.1 Load packages ----
# Base R only.

# 2. fit_glm_family() ----

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

  # Passed as values so one formula serves taxa with and without
  # weights. The harness passes offset = NULL and puts offsets in
  # the formula instead (see run_stage()).
  if (!is.null(weights)) {
    args$weights <- weights
  }

  if (!is.null(offset)) {
    args$offset <- offset
  }

  # Gamma fits start at the mean response, as v2's mammal
  # abundance models do: starting at y diverges for skewed
  # densities
  family_name <- if (is.character(family)) family else family$family
  starts <- c("mustart", "start", "etastart")

  if (identical(family_name, "Gamma") &&
        !any(starts %in% names(control))) {
    y <- data[[all.vars(formula[[2]])[1]]]
    args$mustart <- rep(mean(y, na.rm = TRUE), nrow(data))
  }

  # Warnings (e.g. non-convergence) are recorded, not failures;
  # muffled rather than caught so the model is fitted once
  warnings_seen <- character(0)

  tryCatch(
    {
      fit <- withCallingHandlers(
        do.call(fitter, args),
        warning = function(w) {
          warnings_seen <<- c(warnings_seen, conditionMessage(w))
          invokeRestart("muffleWarning")
        }
      )

      list(
        fit = fit,
        ok = TRUE,
        message = if (length(warnings_seen) == 0) {
          NA_character_
        } else {
          paste(unique(warnings_seen), collapse = "; ")
        }
      )
    },
    error = function(e) {
      list(fit = NULL, ok = FALSE, message = conditionMessage(e))
    }
  )
}

# 3. fit_coefficients() ----

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

# 4. fit_predict() ----

#' Predict from a Fit
#'
#' @param fit A list from fit_glm_family().
#' @param newdata A data frame to predict onto.
#' @param type Character. "link" or "response".
#' @param se Logical. Return standard errors alongside the fit.
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

# 5. information_criterion() ----

#' Score a Fit for Model Selection
#'
#' AICc by default: candidate sets are large relative to a rare
#' species' detections.
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
        # k from logLik df, as MuMIn, so aliased (NA) terms are
        # not counted
        k <- attr(stats::logLik(fit$fit), "df")
        n <- stats::nobs(fit$fit)
        # Undefined once k + 1 >= n; Inf excludes the model
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

# 6. fit_converged() ----

#' Did a Fit Converge
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

# 7. fit_nobs() ----

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
