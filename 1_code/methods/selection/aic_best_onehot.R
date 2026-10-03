# ---
# title: Selection Rule - Best Model, Read One Habitat at a Time
# author: Brendan Casey
# created: 2026-09-09
# inputs: none
# outputs: registers the `aic_best_onehot` rule
# notes:
#   - The v2 mammal presence rule. Unlike the plant habitat stage
#     there is no fixed prediction matrix: v2 reads each effect by
#     setting that one term to 1 and every other to 0, so the grid
#     is an identity over whichever terms the winning model
#     happens to carry.
#   - Three things make the result a probability rather than a
#     coefficient:
#     - Each prediction is passed through the logistic, so an
#       effect is the modelled probability of presence in a pure
#       stand of that type.
#     - `Climate` is a slope, not a habitat type, so it is taken
#       from the fitted coefficient rather than from a one-hot
#       prediction, and is left out of the calibration below.
#     - The whole set is shifted on the logit scale so that mean
#       fitted presence matches mean observed presence.
#   - The reference category - the land cover the winning formula
#     omits - is reported alongside the fitted terms, because a
#     coefficient here means "relative to that type".
# ---

# 1. Setup ----

## 1.1 Load packages ----
# Base R only.

# 2. select_aic_best_onehot() ----

#' Best Model, Read One Habitat Type at a Time
#'
#' @inheritParams select_single
#' @param intercept_cats Character vector, parallel to `models`,
#'   naming each candidate's reference category.
#' @param constants Named list of values every one-hot
#'   prediction holds fixed. The mammal specs set v2's 100
#'   sampling days at zero climate per region.
#' @param calibrate_against Numeric vector of observed responses
#'   to calibrate the level against, or NULL to skip. Filled by
#'   the harness when the stage sets `calibrate = TRUE`.
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
  constants = list(),
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
  terms <- attr(
    stats::terms(fitted$formulas[[winner]]), "term.labels"
  )
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
      best, engine_coef(engine, best), table, fitted,
      engine = engine
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
  best_coefficients <- engine_coef(engine, best)
  coefficients <- stats::setNames(
    best_coefficients$estimate, best_coefficients$term
  )

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
    fitted = fitted,
    engine = engine
  )

  result$reference_category <- reference

  result
}

# 3. Register ----
register_selection(
  "aic_best_onehot", select_aic_best_onehot,
  paste(
    "Best candidate by AICc, read one habitat type at a time",
    "and calibrated (v2 mammal presence)"
  ),
  requires = c("ic", "coefficients", "se")
)

# End of script ----
