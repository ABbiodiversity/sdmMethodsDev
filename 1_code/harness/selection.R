# ---
# title: Selection Plumbing
# author: Brendan Casey
# created: 2026-09-09
# inputs: none
# outputs: none; defines functions in memory
# notes:
#   - Shared plumbing for the rules in 1_code/methods/selection/.
#     Every rule returns selection_result(), so callers need not
#     know which rule ran.
#   - Rules fit their own candidates rather than receiving fits,
#     because staged selection refits each stage on the previous
#     stage's winner.
# ---

# 1. Setup ----

## 1.1 Load packages ----
# Base R only.

# 2. selection_run() ----

#' Run One Selection Rule
#'
#' @param rule Character, a registered rule name, or a function a
#'   spec supplies with the same arguments.
#' @param models A list of formulas, or for staged rules a list
#'   of named groups of formulas.
#' @param base A formula the candidates update, e.g.
#'   response ~ 1. Candidates given as `. ~ . + x` are applied to
#'   it with update().
#' @param data A data frame.
#' @param engine An engine definition from get_engine().
#' @param family Character or family object.
#' @param weights,offset Numeric vectors or NULL.
#' @param ic Character. "AIC", "AICc" or "BIC".
#' @param control Named list passed to the engine.
#' @param ... Further arguments; only those the rule declares are
#'   passed on.
#' @return A selection result; see selection_result(). `rule` is
#'   set to the rule's name, and `predict` to a predictor for the
#'   final model when the rule did not supply one.
#'
#' @example # Example usage of the function
#' # selection_run("aic_average", models, response ~ 1, d,
#' #               get_engine("bayesglm"), "binomial")
selection_run <- function(
  rule,
  models,
  base,
  data,
  engine,
  family,
  weights = NULL,
  offset = NULL,
  ic = "AICc",
  control = list(),
  ...
) {
  # A function rule covers shapes the registry lacks (e.g. the v2
  # mammal hurdle)
  if (is.function(rule)) {
    rule_fn <- rule
    rule_name <- "custom"
  } else {
    rule_fn <- get_method("selection", rule)
    rule_name <- rule
  }

  extra <- list(...)
  extra <- extra[names(extra) %in% names(formals(rule_fn))]

  out <- do.call(rule_fn, c(
    list(
      models = models, base = base, data = data, engine = engine,
      family = family, weights = weights, offset = offset,
      ic = ic, control = control
    ),
    extra
  ))

  out$rule <- rule_name

  # A rule that combines candidates supplies its own predictor;
  # otherwise the final model is the chosen fit.
  if (is.null(out$predict) && !is.null(out$fit)) {
    chosen <- out$fit

    out$predict <- function(newdata, type = "response") {
      engine$predict(chosen, newdata, type)
    }
  }

  out
}

# 3. Candidate fitting ----

## 3.1 fit_candidates() ----

#' Fit Every Candidate in a Model Set
#'
#' @param models A list of formulas.
#' @param base A formula the candidates update.
#' @param data A data frame.
#' @param engine An engine definition.
#' @param family,weights,offset,ic,control As in selection_run().
#' @return A list with `fits`, `formulas` and `scores`. Scores are
#'   Inf where the engine has no information criterion.
#'
#' @example # Example usage of the function
#' # fit_candidates(models, response ~ 1, d, engine, "binomial")
fit_candidates <- function(
  models,
  base,
  data,
  engine,
  family,
  weights = NULL,
  offset = NULL,
  ic = "AICc",
  control = list()
) {
  formulas <- lapply(models, function(one) resolve_formula(one, base))

  fits <- lapply(formulas, function(f) {
    fit_with(engine, f, data, family, weights, offset, control)
  })

  scores <- vapply(
    fits,
    function(f) {
      if (engine_has(engine, "ic")) engine$ic(f, ic) else Inf
    },
    numeric(1)
  )

  list(fits = fits, formulas = formulas, scores = scores)
}

## 3.2 resolve_formula() ----

#' Apply a Candidate to a Base Formula
#'
#' v2 model sets mix complete formulas and updates such as
#' `. ~ . + MAP`.
#'
#' @param model A formula.
#' @param base A formula to update.
#' @return A formula.
#'
#' @example # Example usage of the function
#' # resolve_formula(. ~ . + MAP, response ~ 1)
resolve_formula <- function(model, base) {
  # One-sided or dot-left candidates are updates
  left <- if (length(model) == 3) deparse(model[[2]]) else "."

  if (left == ".") {
    return(stats::update(base, model))
  }

  model
}

## 3.3 formula_variables() ----

#' The Data Columns a Formula Reads
#'
#' Read from the formula, not a fit, so it works for any engine.
#' Excludes response, offset and weight, which a prediction frame
#' never supplies as data.
#'
#' @param formula A formula, or formula text.
#' @return A character vector of column names.
#'
#' @example # Example usage of the function
#' # formula_variables(response ~ MAP + offset(offset))
formula_variables <- function(formula) {
  if (is.character(formula)) {
    formula <- stats::as.formula(formula)
  }

  setdiff(all.vars(formula), c("response", "offset", "weight"))
}

## 3.4 candidate_table() ----

#' Summarize a Candidate Set
#'
#' @param fitted A list from fit_candidates().
#' @param names_in Character vector of candidate names, or NULL.
#' @return A data frame of model, formula, ic, delta, weight, k
#'   and ok. `k` counts coefficients, NA where the engine has
#'   none.
#'
#' @example # Example usage of the function
#' # candidate_table(fitted)
candidate_table <- function(fitted, names_in = NULL) {
  n <- length(fitted$fits)

  if (is.null(names_in)) {
    names_in <- if (!is.null(names(fitted$fits))) {
      names(fitted$fits)
    } else {
      paste0("model_", seq_len(n))
    }
  }

  ok <- vapply(fitted$fits, function(f) isTRUE(f$ok), logical(1))
  k <- vapply(
    fitted$fits,
    function(f) {
      cf <- if (isTRUE(f$ok)) f$coefficients else NULL
      if (is.null(cf)) NA_integer_ else nrow(cf)
    },
    integer(1)
  )

  scores <- fitted$scores
  best <- suppressWarnings(min(scores, na.rm = TRUE))
  delta <- scores - best

  # Akaike weights; a failed model scores Inf and gets weight 0
  raw <- exp(-delta / 2)
  raw[!is.finite(raw)] <- 0
  total <- sum(raw)

  data.frame(
    model = names_in,
    formula = vapply(
      fitted$formulas, function(f) paste(deparse(f), collapse = " "),
      character(1)
    ),
    ic = scores,
    delta = delta,
    weight = if (total > 0) raw / total else rep(0, n),
    k = k,
    ok = ok,
    stringsAsFactors = FALSE
  )
}

# 4. Combining predictions ----

## 4.1 family_linkinv() ----

#' The Inverse Link of a Family
#'
#' @param family Character (e.g. "binomial") or a family object.
#' @return A function from the link scale to the response scale.
#'
#' @example # Example usage of the function
#' # family_linkinv("poisson")(0)
family_linkinv <- function(family) {
  if (is.character(family)) {
    family <- get(family, mode = "function")()
  }

  family$linkinv
}

## 4.2 combined_predictor() ----

#' A Predictor That Averages Several Fits on the Link Scale
#'
#' Returned as `predict` by combining rules, so scoring and grid
#' projection use the combined model, not the best candidate.
#'
#' @param fits List of engine fits.
#' @param engine An engine definition.
#' @param family Character or family object.
#' @param weights Numeric vector of fixed weights, one per fit, or
#'   NULL to weight each prediction by its own precision
#'   (inverse-variance), which needs the `se` capability.
#' @return A function(newdata, type = "response") returning a
#'   numeric vector. NULL when nothing can predict, or, under
#'   fixed weights, when any weighted fit cannot.
#'
#' @example # Example usage of the function
#' # predict <- combined_predictor(fits, engine, "binomial", w)
#' # predict(newdata)
combined_predictor <- function(fits, engine, family, weights = NULL) {
  linkinv <- family_linkinv(family)

  if (!is.null(weights)) {
    keep <- weights > 0
    fits <- fits[keep]
    weights <- weights[keep] / sum(weights[keep])
  }

  function(newdata, type = "response") {
    if (length(fits) == 0) {
      return(NULL)
    }

    if (is.null(weights)) {
      predictions <- lapply(fits, function(f) {
        engine$predict(f, newdata, "link", se = TRUE)
      })

      # Precision weights renormalize, so a candidate that cannot
      # predict is dropped, as v2 drops a failed fit
      predictions <- predictions[
        !vapply(predictions, is.null, logical(1))
      ]

      if (length(predictions) == 0) {
        return(NULL)
      }

      estimate <- do.call(rbind, lapply(predictions, `[[`, "fit"))
      error <- do.call(rbind, lapply(predictions, `[[`, "se.fit"))
      link <- colSums(estimate / error^2) / colSums(1 / error^2)
    } else {
      predictions <- lapply(fits, function(f) {
        engine$predict(f, newdata, "link")
      })

      if (any(vapply(predictions, is.null, logical(1)))) {
        return(NULL)
      }

      link <- drop(weights %*% do.call(rbind, predictions))
    }

    if (type == "link") link else linkinv(link)
  }
}

# 5. selection_result() ----

#' Build the Structure Every Rule Returns
#'
#' @param fit A fit from an engine, or NULL.
#' @param coefficients A data frame of term, estimate, se, or
#'   NULL.
#' @param ic_table A data frame summarizing the candidates.
#' @param fitted The full candidate set, or NULL.
#' @param formula The chosen formula, or NULL to read it from
#'   `fit`.
#' @param engine The engine, or NULL. Used to count observations.
#' @param predict A function(newdata, type) for the final model,
#'   or NULL to predict from `fit` (set by selection_run()).
#' @return A list.
#'
#' @example # Example usage of the function
#' # selection_result(fit, coefs, table, fitted)
selection_result <- function(
  fit,
  coefficients,
  ic_table,
  fitted = NULL,
  formula = NULL,
  engine = NULL,
  predict = NULL
) {
  list(
    fit = fit,
    coefficients = coefficients,
    ic_table = ic_table,
    formula = if (!is.null(formula)) {
      paste(deparse(formula), collapse = " ")
    } else if (!is.null(fit) && isTRUE(fit$ok)) {
      tryCatch(
        paste(deparse(stats::formula(fit$fit)), collapse = " "),
        error = function(e) NA_character_
      )
    } else {
      NA_character_
    },
    # Every formula any candidate fitted, so a grid prediction can
    # supply each term a combined predictor reads
    formulas = if (is.null(fitted)) NULL else fitted$formulas,
    n_fitted = if (is.null(ic_table)) 0L else sum(ic_table$ok),
    n_failed = if (is.null(ic_table)) 0L else sum(!ic_table$ok),
    nobs = engine_nobs(engine, fit),
    predict = predict
  )
}

# End of script ----
