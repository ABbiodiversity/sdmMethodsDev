# ---
# title: Model Selection Rules
# author: Brendan Casey
# created: 2026-09-09
# inputs: none
# outputs: none; returns objects in memory
# notes:
#   - A selection rule turns a candidate model set into one set of
#     coefficients. The three taxa use three different rules, and
#     each is registered here so a spec names one rather than
#     implementing it.
#   - `single` fits one formula. `aic_best` keeps the lowest AICc,
#     which is what the mammal models do. `aic_average` weights
#     candidates by AICc and averages their coefficients, which is
#     what the plant models do. `staged_bic` walks groups of
#     formulas, keeping the best of each group as the base for the
#     next, which is what the bird models do.
#   - A rule fits its own candidates rather than being handed
#     fitted objects, because staged selection has to refit as it
#     goes: each stage updates the previous stage's winner. One
#     interface then covers both shapes.
#   - Every rule returns the same structure, so the fitting loop
#     and the result writer do not know which rule ran.
#   - Coefficient averaging is over the terms present, treating a
#     term absent from a candidate as zero. That is what "this
#     model says the effect is nil" means, and it is how the v2
#     plant code assembles its coefficient template.
# ---

# 1. Setup ----

## 1.1 Load packages ----
# Base R only; engines.R supplies the fitting and scoring.

# 2. Selection registry ----

## 2.1 selection_registry() ----

#' The Available Selection Rules
#'
#' @return A named list of functions, each taking the arguments
#'   selection_run() passes.
#'
#' @example # Example usage of the function
#' # names(selection_registry())
selection_registry <- function() {
  list(
    single = select_single,
    aic_best = select_aic_best,
    aic_average = select_aic_average,
    staged_bic = select_staged_bic,
    ivw_grid = select_ivw_grid,
    aic_best_grid = select_aic_best_grid,
    aic_best_onehot = select_aic_best_onehot
  )
}

## 2.2 selection_run() ----

#' Run One Selection Rule
#'
#' The single entry point the fitting loop calls.
#'
#' @param rule Character. A name in selection_registry().
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
#' @param ... Passed to the rule, for arguments only some rules
#'   take - the prediction grid the ivw_grid rule needs, say.
#' @return A list with `fit`, `coefficients`, `ic_table`,
#'   `n_fitted`, `n_failed` and `rule`.
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
  registry <- selection_registry()

  if (!rule %in% names(registry)) {
    stop(
      "Unknown selection rule `", rule, "`. Registered: ",
      paste(names(registry), collapse = ", "),
      call. = FALSE
    )
  }

  # Only pass the extra arguments a rule actually declares, so a
  # spec can set a grid for every stage without the rules that
  # do not use one failing on it.
  extra <- list(...)
  accepted <- names(formals(registry[[rule]]))
  extra <- extra[names(extra) %in% accepted]

  out <- do.call(registry[[rule]], c(
    list(
      models = models, base = base, data = data, engine = engine,
      family = family, weights = weights, offset = offset,
      ic = ic, control = control
    ),
    extra
  ))

  out$rule <- rule

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
#' @return A list with `fits`, `formulas` and `scores`.
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
    engine$fit(
      formula = f, data = data, family = family,
      weights = weights, offset = offset, control = control
    )
  })

  scores <- vapply(
    fits, function(f) engine$ic(f, ic), numeric(1)
  )

  list(fits = fits, formulas = formulas, scores = scores)
}

## 3.2 resolve_formula() ----

#' Apply a Candidate to a Base Formula
#'
#' A candidate may be a complete formula or an update such as
#' `. ~ . + MAP`. Both forms appear in the v2 model sets.
#'
#' @param model A formula.
#' @param base A formula to update.
#' @return A formula.
#'
#' @example # Example usage of the function
#' # resolve_formula(. ~ . + MAP, response ~ 1)
resolve_formula <- function(model, base) {
  # A one-sided candidate, or one whose left side is a dot, is an
  # update; anything else is complete in itself.
  left <- if (length(model) == 3) deparse(model[[2]]) else "."

  if (left == ".") {
    return(stats::update(base, model))
  }

  model
}

## 3.3 candidate_table() ----

#' Summarize a Candidate Set
#'
#' @param fitted A list from fit_candidates().
#' @param names_in Character vector of candidate names, or NULL.
#' @return A data frame of model, ic, delta, weight, k and ok.
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
      cf <- fit_coefficients(f)
      if (is.null(cf)) NA_integer_ else nrow(cf)
    },
    integer(1)
  )

  scores <- fitted$scores
  best <- suppressWarnings(min(scores, na.rm = TRUE))
  delta <- scores - best

  # Akaike weights. A failed model scores Inf, so exp(-Inf/2) is
  # zero and it carries no weight.
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

# 4. Selection rules ----

## 4.1 select_single() ----

#' Fit One Model, No Selection
#'
#' @param models A list holding one formula, or a single formula.
#' @param base,data,engine,family,weights,offset,ic,control As in
#'   selection_run().
#' @return A selection result.
#'
#' @example # Example usage of the function
#' # select_single(list(. ~ . + MAP), response ~ 1, d, engine,
#' #               "binomial")
select_single <- function(
  models, base, data, engine, family,
  weights = NULL, offset = NULL, ic = "AICc", control = list()
) {
  if (inherits(models, "formula")) {
    models <- list(models)
  }

  fitted <- fit_candidates(
    models[1], base, data, engine, family, weights, offset, ic,
    control
  )

  selection_result(
    fit = fitted$fits[[1]],
    coefficients = fit_coefficients(fitted$fits[[1]]),
    ic_table = candidate_table(fitted),
    fitted = fitted
  )
}

## 4.2 select_aic_best() ----

#' Keep the Single Best-Scoring Candidate
#'
#' The mammal rule.
#'
#' @inheritParams select_single
#' @return A selection result.
#'
#' @example # Example usage of the function
#' # select_aic_best(models, response ~ 1, d, engine, "binomial")
select_aic_best <- function(
  models, base, data, engine, family,
  weights = NULL, offset = NULL, ic = "AICc", control = list()
) {
  fitted <- fit_candidates(
    models, base, data, engine, family, weights, offset, ic,
    control
  )

  table <- candidate_table(fitted)

  if (!any(table$ok)) {
    return(selection_result(NULL, NULL, table, fitted))
  }

  winner <- which.min(fitted$scores)

  selection_result(
    fit = fitted$fits[[winner]],
    coefficients = fit_coefficients(fitted$fits[[winner]]),
    ic_table = table,
    fitted = fitted
  )
}

## 4.3 select_aic_average() ----

#' Average Candidates by Information-Criterion Weight
#'
#' The plant rule. Coefficients are averaged across candidates
#' with Akaike weights, treating a term absent from a candidate
#' as zero - that model's statement that the effect is nil.
#'
#' @inheritParams select_single
#' @return A selection result. `fit` is the best single candidate,
#'   kept so that predictions onto new data remain possible;
#'   `coefficients` are the averaged ones.
#'
#' @example # Example usage of the function
#' # select_aic_average(models, response ~ 1, d, engine,
#' #                    "binomial")
select_aic_average <- function(
  models, base, data, engine, family,
  weights = NULL, offset = NULL, ic = "AICc", control = list()
) {
  fitted <- fit_candidates(
    models, base, data, engine, family, weights, offset, ic,
    control
  )

  table <- candidate_table(fitted)

  if (!any(table$ok) || sum(table$weight) == 0) {
    return(selection_result(NULL, NULL, table, fitted))
  }

  # Step 1: Collect every term any candidate estimated
  per_model <- lapply(fitted$fits, fit_coefficients)
  terms <- unique(unlist(lapply(per_model, function(x) x$term)))

  # Step 2: Weighted mean per term, absent terms counting as zero
  averaged <- do.call(rbind, lapply(terms, function(term) {
    estimate <- 0
    variance <- 0

    for (i in seq_along(per_model)) {
      cf <- per_model[[i]]
      w <- table$weight[i]

      if (is.null(cf) || w == 0) {
        next
      }

      row <- match(term, cf$term)
      value <- if (is.na(row)) 0 else cf$estimate[row]
      se <- if (is.na(row)) 0 else cf$se[row]

      estimate <- estimate + w * value
      variance <- variance + w * ifelse(is.na(se), 0, se^2)
    }

    data.frame(
      term = term,
      estimate = estimate,
      se = sqrt(variance),
      stringsAsFactors = FALSE
    )
  }))

  selection_result(
    fit = fitted$fits[[which.min(fitted$scores)]],
    coefficients = averaged,
    ic_table = table,
    fitted = fitted
  )
}

## 4.4 select_staged_bic() ----

#' Walk Groups of Candidates, Carrying the Winner Forward
#'
#' The bird rule. `models` is a list of named groups. Each group
#' is fitted as an update to the previous group's winner, and the
#' winner is the smallest model within `threshold` of the best
#' score - a parsimony tie-break, not simply the minimum.
#'
#' @inheritParams select_single
#' @param threshold Numeric. How far above the best score a
#'   candidate may sit and still be eligible.
#' @return A selection result, with `ic_table` carrying a `stage`
#'   column.
#'
#' @example # Example usage of the function
#' # select_staged_bic(model_groups, response ~ 1, d, engine,
#' #                   "poisson", ic = "BIC")
select_staged_bic <- function(
  models, base, data, engine, family,
  weights = NULL, offset = NULL, ic = "BIC", control = list(),
  threshold = 2
) {
  # Step 1: Fit the base model. It is the starting point every
  # group updates, and the fallback if no group improves on it.
  current <- engine$fit(
    formula = base, data = data, family = family,
    weights = weights, offset = offset, control = control
  )
  current_formula <- base
  tables <- list()

  if (!isTRUE(current$ok)) {
    return(selection_result(
      NULL, NULL,
      data.frame(
        stage = "base", model = "base", formula = deparse(base),
        ic = Inf, delta = NA_real_, weight = 0, k = NA_integer_,
        ok = FALSE, stringsAsFactors = FALSE
      ),
      NULL
    ))
  }

  group_names <- names(models)

  if (is.null(group_names)) {
    group_names <- paste0("stage_", seq_along(models))
  }

  # Step 2: Each group updates the running winner
  for (i in seq_along(models)) {
    fitted <- fit_candidates(
      models[[i]], current_formula, data, engine, family,
      weights, offset, ic, control
    )

    table <- candidate_table(fitted)
    table$stage <- group_names[i]
    tables[[i]] <- table

    eligible <- which(table$ok & is.finite(fitted$scores))

    if (length(eligible) == 0) {
      next
    }

    # Step 3: Among candidates within `threshold` of the best,
    # take the one with fewest parameters. This is a parsimony
    # rule, and it is why the winner is not simply which.min().
    best <- min(fitted$scores[eligible])
    close <- eligible[fitted$scores[eligible] <= best + threshold]
    winner <- close[which.min(table$k[close])]

    # Step 4: Only carry forward a group that improved on the
    # model it was updating, so a group with nothing to add
    # leaves the running model untouched
    if (fitted$scores[winner] < engine$ic(current, ic)) {
      current <- fitted$fits[[winner]]
      current_formula <- fitted$formulas[[winner]]
    }
  }

  selection_result(
    fit = current,
    coefficients = fit_coefficients(current),
    ic_table = do.call(rbind, tables),
    fitted = NULL,
    formula = current_formula
  )
}

## 4.5 select_ivw_grid() ----

#' Inverse-Variance Average Predictions onto a Grid
#'
#' The plant habitat rule, and the one place where a "coefficient"
#' is not a regression coefficient. v2 fits each candidate, then
#' predicts it onto the prediction matrix - one row per habitat
#' type - and combines those predictions across candidates
#' weighting each by the precision of its own prediction. The
#' result is an effect per habitat type on the link scale, which
#' is what the v2 coefficient tables hold.
#'
#' Weighting by precision rather than by AICc is a different
#' claim: a candidate that is confident about a habitat type
#' dominates there even if it is a poor model overall, and the
#' weighting is per habitat type rather than per model.
#'
#' Non-converged candidates are dropped, not down-weighted,
#' matching v2. A zero standard error is floored at 1e-4, because
#' a precision weight of 1/0 would take the whole average.
#'
#' @inheritParams select_single
#' @param grid A prediction grid, one row per habitat type.
#' @param grid_constants Named list of values for terms the grid
#'   has no column for - v2 predicts at `Climate = 0` and, where
#'   Protocol is fitted, at the new protocol.
#' @param head_terms Character vector of leading model
#'   coefficients to average separately and prepend, which is how
#'   v2 carries Intercept, Climate and Protocol.
#' @return A selection result whose `coefficients` are the
#'   averaged per-habitat-type effects.
#'
#' @example # Example usage of the function
#' # select_ivw_grid(models, response ~ 1, d, engine, "binomial",
#' #                 grid = veg_grid,
#' #                 grid_constants = list(Climate = 0))
select_ivw_grid <- function(
  models, base, data, engine, family,
  weights = NULL, offset = NULL, ic = "AICc", control = list(),
  grid = NULL, grid_constants = list(),
  head_terms = c("Intercept", "Climate")
) {
  if (is.null(grid)) {
    stop(
      "The ivw_grid rule needs a prediction grid; the spec's ",
      "region defines one with `grid`.",
      call. = FALSE
    )
  }

  fitted <- fit_candidates(
    models, base, data, engine, family, weights, offset, ic,
    control
  )

  table <- candidate_table(fitted)
  converged <- vapply(fitted$fits, fit_converged, logical(1))

  if (!any(converged)) {
    return(selection_result(NULL, NULL, table, fitted))
  }

  # Step 1: Predict every converged candidate onto the grid, at
  # the constants v2 holds the non-habitat terms at
  newdata <- grid

  for (one in names(grid_constants)) {
    newdata[[one]] <- grid_constants[[one]]
  }

  predictions <- lapply(seq_along(fitted$fits), function(i) {
    if (!converged[i]) {
      return(NULL)
    }

    engine$predict(fitted$fits[[i]], newdata, "link", se = TRUE)
  })

  usable <- !vapply(predictions, is.null, logical(1))

  if (!any(usable)) {
    return(selection_result(NULL, NULL, table, fitted))
  }

  estimate <- do.call(
    rbind, lapply(predictions[usable], function(x) x$fit)
  )
  error <- do.call(
    rbind, lapply(predictions[usable], function(x) x$se.fit)
  )

  # A zero standard error would carry infinite weight
  error[error == 0] <- 1e-4

  grid_coefficients <- ivw_combine(estimate, error)
  rownames_out <- rownames(grid)

  # Step 2: The leading coefficients are averaged the same way,
  # from the model's own coefficient table rather than from a
  # prediction
  head_estimate <- do.call(rbind, lapply(
    which(converged), function(i) {
      cf <- fit_coefficients(fitted$fits[[i]])
      cf$estimate[seq_along(head_terms)]
    }
  ))
  head_error <- do.call(rbind, lapply(
    which(converged), function(i) {
      cf <- fit_coefficients(fitted$fits[[i]])
      cf$se[seq_along(head_terms)]
    }
  ))
  head_error[head_error == 0 | is.na(head_error)] <- 1e-4

  head_coefficients <- ivw_combine(head_estimate, head_error)

  coefficients <- data.frame(
    term = c(head_terms, rownames_out),
    estimate = c(head_coefficients$estimate,
                 grid_coefficients$estimate),
    se = c(head_coefficients$se, grid_coefficients$se),
    stringsAsFactors = FALSE
  )

  selection_result(
    fit = fitted$fits[[which.min(fitted$scores)]],
    coefficients = coefficients,
    ic_table = table,
    fitted = fitted
  )
}

## 4.6 ivw_combine() ----

#' Combine Estimates by Inverse-Variance Weight
#'
#' @param estimate Matrix of candidates by columns.
#' @param error Matrix of standard errors, the same shape.
#' @return A list of `estimate` and `se`, one per column.
#'
#' @example # Example usage of the function
#' # ivw_combine(rbind(c(1, 2), c(1.2, 2.1)),
#' #             rbind(c(0.1, 0.2), c(0.3, 0.1)))
ivw_combine <- function(estimate, error) {
  precision <- 1 / error^2

  # The variance of the combined estimate is the reciprocal of
  # the summed precision, not its mean, so adding candidates
  # sharpens rather than dilutes it.
  list(
    estimate = colSums(estimate * precision) / colSums(precision),
    se = sqrt(1 / colSums(precision))
  )
}

## 4.7 coef_adjust_plant_veg() ----

#' Borrow Strength for Poorly Sampled Footprint Types
#'
#' v2's `coef.adjust`. Some human footprint types are rarely the
#' dominant cover at a survey unit, so their effect is estimated
#' from little data. v2 pools each with a type it is assumed to
#' resemble, by inverse-variance weight:
#'
#' - `HardLin` borrows from `UrbInd`.
#' - The three soft linear types - `EnSoftLin`, `EnSeismic` and
#'   `TrSoftLin` - each borrow from a composite of young
#'   regenerating stands, weighted by how much those stand types
#'   overlap soft linear features in the provincial summary.
#'
#' The weights are v2's, measured from a 1 km summary and fixed
#' since 2020-11-17. They are an assumption about which habitats
#' resemble which, not an estimate, so they are stated here
#' rather than derived.
#'
#' @param coefficients A data frame of term, estimate and se.
#' @param overlap Numeric vector of four proportions, for
#'   white spruce, pine, deciduous and black spruce regeneration.
#' @return The coefficients, with the four terms adjusted.
#'
#' @example # Example usage of the function
#' # coef_adjust_plant_veg(selected$coefficients)
coef_adjust_plant_veg <- function(
  coefficients,
  overlap = c(0.049, 0.0893, 0.434, 0.396)
) {
  if (is.null(coefficients)) {
    return(NULL)
  }

  value <- stats::setNames(
    coefficients$estimate, coefficients$term
  )
  error <- stats::setNames(coefficients$se, coefficients$term)

  # Pool two estimates by precision.
  pool <- function(a, a_se, b, b_se) {
    precision <- 1 / a_se^2 + 1 / b_se^2

    list(
      estimate = (a / a_se^2 + b / b_se^2) / precision,
      se = sqrt(1 / precision)
    )
  }

  present <- function(...) {
    all(c(...) %in% names(value)) &&
      all(is.finite(value[c(...)])) &&
      all(is.finite(error[c(...)]))
  }

  # Step 1: Hard linear features borrow from urban and industrial
  if (present("HardLin", "UrbInd")) {
    pooled <- pool(
      value["HardLin"], error["HardLin"],
      value["UrbInd"], error["UrbInd"]
    )
    value["HardLin"] <- pooled$estimate
    error["HardLin"] <- pooled$se
  }

  # Step 2: Soft linear features borrow from young regeneration
  young_types <- c(
    "CCWhiteSpruceR", "CCPineR", "CCDeciduousR", "BlackSpruce1"
  )

  if (present(young_types)) {
    weights <- overlap / sum(overlap)

    young <- sum(weights * value[young_types])
    # The weighted variance carries no between-type component,
    # because the weights are fixed rather than estimated.
    young_se <- sqrt(sum(weights * error[young_types]^2))

    for (one in c("EnSoftLin", "EnSeismic", "TrSoftLin")) {
      if (!present(one)) {
        next
      }

      pooled <- pool(value[one], error[one], young, young_se)
      value[one] <- pooled$estimate
      error[one] <- pooled$se
    }
  }

  coefficients$estimate <- unname(value[coefficients$term])
  coefficients$se <- unname(error[coefficients$term])

  coefficients
}

## 4.8 select_aic_best_grid() ----

#' Best Model, Predicted onto a Prediction Grid
#'
#' The mammal abundance-given-presence rule. Where the presence
#' half reads one habitat type at a time from an identity grid,
#' this one predicts the winning model onto the shared prediction
#' matrix, and reports the result on the link scale.
#'
#' No calibration is applied. v2 calibrates the product of the
#' two halves multiplicatively rather than each half separately,
#' because an additive shift on a log-scale abundance can send a
#' small prediction negative and `log` of that is not a number.
#'
#' @inheritParams select_single
#' @param grid A prediction grid.
#' @param constants Named list of values held fixed across the
#'   grid - sampling effort and climate.
#' @param scale Character. "link" reports the linear predictor,
#'   which for a log-link Gamma is log abundance; "response"
#'   exponentiates it.
#' @return A selection result, one effect per grid row.
#'
#' @example # Example usage of the function
#' # select_aic_best_grid(models, response ~ 1, d, engine,
#' #                      Gamma(link = "log"), grid = grid)
select_aic_best_grid <- function(
  models, base, data, engine, family,
  weights = NULL, offset = NULL, ic = "AICc", control = list(),
  grid = NULL, constants = list(), scale = "link"
) {
  if (is.null(grid)) {
    stop(
      "The aic_best_grid rule needs a prediction grid.",
      call. = FALSE
    )
  }

  fitted <- fit_candidates(
    models, base, data, engine, family, weights, offset, ic,
    control
  )

  table <- candidate_table(fitted)

  if (!any(table$ok)) {
    return(selection_result(NULL, NULL, table, fitted))
  }

  best <- fitted$fits[[which.min(fitted$scores)]]

  newdata <- grid

  for (one in names(constants)) {
    newdata[[one]] <- constants[[one]]
  }

  # A grid row describes a pure stand, so a term the grid has no
  # column for is genuinely absent rather than unknown.
  terms <- attr(stats::terms(best$fit), "term.labels")

  for (one in setdiff(terms, names(newdata))) {
    newdata[[one]] <- 0
  }

  predicted <- engine$predict(best, newdata, scale, se = TRUE)

  if (is.null(predicted)) {
    return(selection_result(NULL, NULL, table, fitted))
  }

  selection_result(
    fit = best,
    coefficients = data.frame(
      term = rownames(grid),
      estimate = predicted$fit,
      se = predicted$se.fit,
      stringsAsFactors = FALSE
    ),
    ic_table = table,
    fitted = fitted
  )
}

## 4.9 select_aic_best_onehot() ----

#' Best Model, Read One Habitat Type at a Time
#'
#' The mammal presence rule. Unlike the plant habitat stage there
#' is no fixed prediction matrix: v2 reads each effect by setting
#' that one term to 1 and every other to 0, so the grid is an
#' identity over whichever terms the winning model happens to
#' carry.
#'
#' Three things make the result a probability rather than a
#' coefficient:
#'
#' - Each prediction is passed through the logistic, so an effect
#'   is the modelled probability of presence in a pure stand of
#'   that type.
#' - `Climate` is a slope, not a habitat type, so it is taken
#'   from the fitted coefficient rather than from a one-hot
#'   prediction, and is left out of the calibration below.
#' - The whole set is shifted on the logit scale so that mean
#'   fitted presence matches mean observed presence. Without it
#'   the effects are internally consistent but sit at the wrong
#'   level.
#'
#' The reference category - the land cover the winning formula
#' omits - is reported alongside the fitted terms, because a
#' coefficient here means "relative to that type" and the table
#' is unreadable without it.
#'
#' @inheritParams select_single
#' @param intercept_cats Character vector, parallel to `models`,
#'   naming each candidate's reference category.
#' @param constants Named list of values every one-hot
#'   prediction holds fixed - v2 uses 100 sampling days at zero
#'   climate.
#' @param calibrate_against Numeric vector of observed responses
#'   to calibrate the level against, or NULL to skip.
#' @param slope_terms Character vector of terms that are slopes
#'   rather than habitat types.
#' @return A selection result whose `coefficients` are
#'   probabilities of presence per habitat type.
#'
#' @example # Example usage of the function
#' # select_aic_best_onehot(models, response ~ 1, d, engine,
#' #                        "binomial", intercept_cats = cats)
select_aic_best_onehot <- function(
  models, base, data, engine, family,
  weights = NULL, offset = NULL, ic = "AICc", control = list(),
  intercept_cats = NULL,
  constants = list(seas_days = 100, Climate = 0),
  calibrate_against = NULL,
  slope_terms = "Climate"
) {
  fitted <- fit_candidates(
    models, base, data, engine, family, weights, offset, ic,
    control
  )

  table <- candidate_table(fitted)

  if (!any(table$ok)) {
    return(selection_result(NULL, NULL, table, fitted))
  }

  winner <- which.min(fitted$scores)
  best <- fitted$fits[[winner]]

  # Step 1: The terms to read are the winning model's own, plus
  # the category it leaves out.
  terms <- attr(stats::terms(best$fit), "term.labels")
  reference <- if (is.null(intercept_cats)) {
    NULL
  } else {
    intercept_cats[winner]
  }

  # A slope stays in the reported set even though it is held at
  # a constant for the one-hot predictions: its value is taken
  # from the fitted coefficient below, and dropping it here would
  # make that an append rather than a replacement. Pure design
  # constants - sampling effort - are not reported at all.
  terms <- setdiff(
    c(terms, reference),
    setdiff(names(constants), slope_terms)
  )

  if (length(terms) == 0) {
    return(selection_result(
      best, fit_coefficients(best), table, fitted
    ))
  }

  # Step 2: One prediction per term, at 100 per cent of that type
  onehot <- as.data.frame(diag(length(terms)))
  names(onehot) <- terms

  for (one in names(constants)) {
    onehot[[one]] <- constants[[one]]
  }

  predicted <- engine$predict(best, onehot, "link", se = TRUE)

  if (is.null(predicted)) {
    return(selection_result(NULL, NULL, table, fitted))
  }

  estimate <- stats::plogis(predicted$fit)
  error <- predicted$se.fit
  names(estimate) <- names(error) <- terms

  # Step 3: Shift the level so mean fitted presence matches mean
  # observed. Slopes are exempt: the shift is an intercept
  # change, and applying it to a slope would be meaningless.
  if (!is.null(calibrate_against)) {
    on_scale <- engine$predict(best, data, "link")

    if (!is.null(on_scale)) {
      shift <- stats::qlogis(mean(calibrate_against)) -
        stats::qlogis(mean(stats::plogis(on_scale)))

      if (is.finite(shift)) {
        habitat <- setdiff(names(estimate), slope_terms)
        estimate[habitat] <- stats::plogis(
          stats::qlogis(estimate[habitat]) + shift
        )
      }
    }
  }

  # Step 4: A slope is reported from its own coefficient, not
  # from a one-hot prediction of a type that does not exist.
  coefficients <- stats::coef(best$fit)

  for (one in intersect(slope_terms, names(coefficients))) {
    if (!one %in% names(estimate)) {
      next
    }

    estimate[one] <- stats::plogis(coefficients[[one]])
  }

  result <- selection_result(
    fit = best,
    coefficients = data.frame(
      term = names(estimate),
      estimate = unname(estimate),
      se = unname(error),
      stringsAsFactors = FALSE
    ),
    ic_table = table,
    fitted = fitted
  )

  result$reference_category <- reference

  result
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
#' @return A list.
#'
#' @example # Example usage of the function
#' # selection_result(fit, coefs, table, fitted)
selection_result <- function(
  fit,
  coefficients,
  ic_table,
  fitted = NULL,
  formula = NULL
) {
  list(
    fit = fit,
    coefficients = coefficients,
    ic_table = ic_table,
    formula = if (!is.null(formula)) {
      paste(deparse(formula), collapse = " ")
    } else if (!is.null(fit) && isTRUE(fit$ok)) {
      paste(deparse(stats::formula(fit$fit)), collapse = " ")
    } else {
      NA_character_
    },
    n_fitted = if (is.null(ic_table)) 0L else sum(ic_table$ok),
    n_failed = if (is.null(ic_table)) 0L else sum(!ic_table$ok),
    nobs = fit_nobs(fit)
  )
}

# End of script ----
