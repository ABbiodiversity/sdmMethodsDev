# ---
# title: Engine - Boosted Regression Trees (gbm)
# author: Brendan Casey
# created: 2026-10-03
# inputs: none
# outputs: registers the `gbm` engine
# notes:
#   - gbm::gbm.fit. Trees choose their own variables, split points
#     and interactions, so a stage fitted with this engine is given
#     one formula holding every candidate covariate
#     (models_union()) and the `single` rule.
#   - It has no coefficients, no information criterion and no
#     standard errors, and declares none. validate_spec() therefore
#     refuses it with a rule that needs them (aic_average,
#     ivw_grid, staged_bic); use `single`.
#   - Only the formula's variables are used: `I(x^2)` and `a:b`
#     contribute x, a and b, because a tree finds curvature and
#     interactions itself.
#   - The offset is honoured, on the link scale, in fitting and in
#     prediction. predict.gbm() leaves it out, so it is added back
#     here; without that, a bird prediction would be a rate, not a
#     count.
#   - The number of trees is chosen per fit by gbm.perf()'s
#     out-of-bag estimate. It is fast but known to pick too few
#     trees; cross-validation would be better and several times
#     slower, and is not offered here.
#   - Bagging draws at random, so each fit runs under a fixed seed
#     (`seed` in control) and a run reproduces exactly.
#   - Settings, through the stage's `control`: n.trees (the
#     maximum), interaction.depth, shrinkage, bag.fraction,
#     n.minobsinnode, seed. The defaults are starting points, not
#     tuned values: tree depth and bag fraction are in the ranges
#     Elith, Leathwick and Hastie (2008, J. Anim. Ecol.) discuss,
#     but the learning rate (0.05) is higher than they generally
#     advise, chosen to keep a test run quick. Tune before reading
#     a GBM result as the method's best.
# ---

# 1. Setup ----

## 1.1 Load packages ----
# gbm, lazily, so a run that never uses this engine does not need
# it installed.

# 2. engine_gbm() ----

#' Boosted Regression Trees
#'
#' @return An engine definition.
#'
#' @example # Example usage of the function
#' # check_engine(engine_gbm())
engine_gbm <- function() {
  list(
    name = "gbm",
    description = "Boosted regression trees (gbm::gbm.fit)",
    capabilities = character(0),
    fit = gbm_fit,
    predict = gbm_predict
  )
}

# 3. gbm_fit() ----

#' Fit Boosted Regression Trees, Catching Failure
#'
#' @param formula A model formula. Only its variables and any
#'   `offset(offset)` term are used.
#' @param data A data frame.
#' @param family Character ("binomial", "poisson", "gaussian") or
#'   a family object.
#' @param weights Numeric vector or NULL.
#' @param offset Unused; the offset comes from the formula.
#' @param control Named list of settings; see the header.
#' @return A list with `fit` (or NULL), `ok` and `message`.
#'
#' @example # Example usage of the function
#' # gbm_fit(response ~ MAP + FFP, d, "binomial")
gbm_fit <- function(formula, data, family, weights = NULL,
                    offset = NULL, control = list()) {
  tryCatch(
    {
      if (!requireNamespace("gbm", quietly = TRUE)) {
        stop("The gbm engine needs the gbm package.", call. = FALSE)
      }

      settings <- utils::modifyList(
        list(
          n.trees = 1000, interaction.depth = 3, shrinkage = 0.05,
          bag.fraction = 0.5, n.minobsinnode = 10,
          seed = 20260909L
        ),
        control
      )

      # Step 1: The response, the predictors and any offset. A row
      # missing its response, weight or offset is dropped, as a GLM
      # drops it; a missing predictor is kept, because trees route
      # missing values down a branch of their own.
      terms <- gbm_terms(formula)
      w_all <- if (is.null(weights)) rep(1, nrow(data)) else weights
      keep <- !is.na(data[[terms$response]]) & !is.na(w_all)

      if (terms$offset) {
        keep <- keep & !is.na(data$offset)
      }

      x <- gbm_predictors(data[keep, , drop = FALSE], terms$variables)
      y <- data[[terms$response]][keep]
      w <- w_all[keep]
      link_offset <- if (terms$offset) data$offset[keep] else NULL

      # Step 2: Fit, under a fixed seed, as many trees as allowed
      model <- with_seed(settings$seed, gbm::gbm.fit(
        x = x, y = y, offset = link_offset, w = w,
        distribution = gbm_distribution(family),
        n.trees = settings$n.trees,
        interaction.depth = settings$interaction.depth,
        shrinkage = settings$shrinkage,
        bag.fraction = settings$bag.fraction,
        n.minobsinnode = settings$n.minobsinnode,
        keep.data = FALSE,
        verbose = FALSE
      ))

      # Step 3: Keep the number of trees the out-of-bag estimate
      # prefers
      best <- suppressWarnings(suppressMessages(
        gbm::gbm.perf(model, method = "OOB", plot.it = FALSE)
      ))

      list(
        fit = list(
          model = model,
          n_trees = as.integer(best),
          variables = terms$variables,
          levels = lapply(x, levels),
          offset = terms$offset,
          linkinv = family_linkinv(family)
        ),
        ok = TRUE,
        message = NA_character_
      )
    },
    error = function(e) {
      list(fit = NULL, ok = FALSE, message = conditionMessage(e))
    }
  )
}

# 4. gbm_predict() ----

#' Predict from a gbm Fit
#'
#' @param fit A list from gbm_fit().
#' @param newdata A data frame to predict onto.
#' @param type Character. "link" or "response".
#' @param se Logical. Not supported; NULL is returned when TRUE.
#' @return A numeric vector, or NULL when the fit failed.
#'
#' @example # Example usage of the function
#' # gbm_predict(fit, newdata, "response")
gbm_predict <- function(fit, newdata, type = "link", se = FALSE) {
  if (is.null(fit) || !isTRUE(fit$ok) || is.null(fit$fit) || se) {
    return(NULL)
  }

  tryCatch(
    {
      tree <- fit$fit
      x <- gbm_predictors(newdata, tree$variables, tree$levels)
      link <- gbm::predict.gbm(
        tree$model, newdata = x, n.trees = tree$n_trees,
        type = "link"
      )

      # predict.gbm() leaves the offset out
      if (tree$offset) {
        link <- link + newdata$offset
      }

      if (type == "link") {
        as.numeric(link)
      } else {
        as.numeric(tree$linkinv(link))
      }
    },
    error = function(e) NULL
  )
}

# 5. Helpers ----

## 5.1 gbm_terms() ----

#' Read a Formula as gbm Uses It
#'
#' @param formula A model formula.
#' @return A list of `response`, `variables` and `offset` (TRUE
#'   when the formula has an `offset(offset)` term).
#'
#' @example # Example usage of the function
#' # gbm_terms(count ~ MAP + I(MAP^2) + offset(offset))
gbm_terms <- function(formula) {
  text <- paste(deparse(formula), collapse = " ")

  list(
    response = all.vars(formula[[2]]),
    variables = setdiff(
      all.vars(formula[[3]]), c("offset", "weight")
    ),
    offset = grepl("offset(offset)", text, fixed = TRUE)
  )
}

## 5.2 gbm_predictors() ----

#' The Predictor Frame gbm Takes
#'
#' Text columns become factors, with the fitted levels when
#' predicting, so a category on new data is read the way it was in
#' fitting.
#'
#' @param data A data frame.
#' @param variables Character vector of column names.
#' @param levels Named list of factor levels from the fit, or
#'   NULL when fitting.
#' @return A data frame of the predictors.
#'
#' @example # Example usage of the function
#' # gbm_predictors(d, c("MAP", "vegc"))
gbm_predictors <- function(data, variables, levels = NULL) {
  absent <- setdiff(variables, names(data))

  if (length(absent) > 0) {
    stop("Columns not in the data: ", paste(absent, collapse = ", "),
         call. = FALSE)
  }

  x <- as.data.frame(data)[, variables, drop = FALSE]

  for (column in variables) {
    value <- x[[column]]
    known <- levels[[column]]

    if (!is.null(known)) {
      x[[column]] <- factor(as.character(value), levels = known)
    } else if (is.character(value) || is.logical(value)) {
      x[[column]] <- factor(value)
    }
  }

  x
}

## 5.3 gbm_distribution() ----

#' The gbm Distribution for a GLM Family
#'
#' @param family Character or family object.
#' @return Character, a gbm distribution name.
#'
#' @example # Example usage of the function
#' # gbm_distribution("binomial") # "bernoulli"
gbm_distribution <- function(family) {
  name <- if (is.character(family)) family else family$family

  switch(
    name,
    binomial = "bernoulli",
    poisson = "poisson",
    gaussian = "gaussian",
    stop(
      "The gbm engine has no distribution for family `", name,
      "`. It supports binomial, poisson and gaussian.",
      call. = FALSE
    )
  )
}

# 6. Register ----
register_engine(engine_gbm())

# End of script ----
