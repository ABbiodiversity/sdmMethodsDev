# ---
# title: Engine - Boosted Regression Trees (xgboost)
# author: Brendan Casey
# created: 2026-10-05
# inputs: none
# outputs: registers the `xgboost` engine
# notes:
#   - xgboost::xgb.train. Trees choose their own variables, split
#     points and interactions, so a stage fitted with this engine
#     is given one formula holding every candidate covariate
#     (models_union()) and the `single` rule, through
#     replace_stage_method().
#   - It replaces the earlier gbm engine, which could not fit the
#     mammal hurdle: gbm's bernoulli refuses a response between 0
#     and 1 (v2's lure-scaled presence), and gbm has no Gamma.
#     xgboost's `binary:logistic` takes a proportion as the label,
#     and `reg:gamma` is a log-link Gamma.
#   - It has no coefficients, no information criterion and no
#     standard errors, and declares none. validate_spec() therefore
#     refuses it with a rule that needs them; use `single`.
#   - Only the formula's variables are used: `I(x^2)` and `a:b`
#     contribute x, a and b, because a tree finds curvature and
#     interactions itself. Text and factor columns are one-hot
#     coded with the fitted levels. A missing value stays missing:
#     xgboost routes it down a branch of its own.
#   - The offset is honoured on the link scale, in fitting and in
#     prediction, as xgboost's `base_margin`. Without it on new
#     data xgboost would substitute its own fitted intercept, so a
#     bird prediction would be neither a rate nor a count.
#   - The number of rounds is chosen per fit by early stopping on
#     a held-out share of the rows (`valid_fraction`, 20%), then
#     the model is refitted on every row at that number. The
#     holdout is drawn under the fit's seed, so a run reproduces
#     exactly. Pitfall: on a small draw the holdout is small and
#     the chosen number of rounds noisy.
#   - Settings, through the stage's `control`: nrounds (the most),
#     eta, max_depth, subsample, colsample_bytree,
#     min_child_weight, early_stopping_rounds, valid_fraction,
#     seed. The defaults are untuned starting points chosen to
#     keep a test run quick (eta 0.05 is higher than Elith,
#     Leathwick and Hastie 2008 generally advise for boosted
#     trees). Tune before reading a result as the method's best.
#   - One thread per fit, because the harness already runs one
#     species per worker.
# ---

# 1. Setup ----

## 1.1 Load packages ----
# xgboost (version: 3.2.1), lazily, so a run that never uses this
# engine does not need it installed.

# 2. engine_xgboost() ----

#' Boosted Regression Trees with xgboost
#'
#' @return An engine definition.
#'
#' @example # Example usage of the function
#' # check_engine(engine_xgboost())
engine_xgboost <- function() {
  list(
    name = "xgboost",
    description = "Boosted regression trees (xgboost::xgb.train)",
    capabilities = character(0),
    fit = xgboost_fit,
    predict = xgboost_predict
  )
}

# 3. xgboost_fit() ----

#' Fit Boosted Regression Trees, Catching Failure
#'
#' @param formula A model formula. Only its variables and any
#'   `offset(offset)` term are used.
#' @param data A data frame.
#' @param family Character ("binomial", "poisson", "gaussian") or
#'   a family object (Gamma with a log link).
#' @param weights Numeric vector or NULL.
#' @param offset Unused; the offset comes from the formula.
#' @param control Named list of settings; see the header.
#' @return A list with `fit` (or NULL), `ok` and `message`.
#'
#' @example # Example usage of the function
#' # xgboost_fit(response ~ MAP + FFP, d, "binomial")
xgboost_fit <- function(formula, data, family, weights = NULL,
                        offset = NULL, control = list()) {
  tryCatch(
    {
      if (!requireNamespace("xgboost", quietly = TRUE)) {
        stop("The xgboost engine needs the xgboost package.",
             call. = FALSE)
      }

      settings <- utils::modifyList(
        list(
          nrounds = 1000, eta = 0.05, max_depth = 3,
          subsample = 0.5, colsample_bytree = 1,
          min_child_weight = 1, early_stopping_rounds = 50,
          valid_fraction = 0.2, seed = 20260909L
        ),
        control
      )

      # Step 1: The response, the predictors and any offset. A row
      # missing its response, weight or offset is dropped, as a GLM
      # drops it; a missing predictor is kept.
      terms <- xgboost_terms(formula)
      w_all <- if (is.null(weights)) rep(1, nrow(data)) else weights
      keep <- !is.na(data[[terms$response]]) & !is.na(w_all)

      if (terms$offset) {
        keep <- keep & !is.na(data$offset)
      }

      rows <- data[keep, , drop = FALSE]
      design <- xgboost_design(rows, terms$variables)
      y <- rows[[terms$response]]
      w <- w_all[keep]
      margin <- if (terms$offset) rows$offset else NULL

      params <- list(
        objective = xgboost_objective(family),
        eta = settings$eta,
        max_depth = settings$max_depth,
        subsample = settings$subsample,
        colsample_bytree = settings$colsample_bytree,
        min_child_weight = settings$min_child_weight,
        nthread = 1
      )

      matrix_of <- function(index) {
        xgboost::xgb.DMatrix(
          design$x[index, , drop = FALSE], label = y[index],
          weight = w[index],
          base_margin = if (is.null(margin)) NULL else margin[index]
        )
      }

      # Step 2: The number of rounds, by early stopping on a
      # held-out share, then a refit on every row at that number
      model <- with_seed(settings$seed, {
        n <- length(y)
        held <- sample.int(
          n, max(1L, floor(n * settings$valid_fraction))
        )
        trial <- xgboost::xgb.train(
          params = params, data = matrix_of(-held),
          nrounds = settings$nrounds,
          evals = list(valid = matrix_of(held)),
          early_stopping_rounds = settings$early_stopping_rounds,
          verbose = 0
        )
        rounds <- xgboost_best_rounds(trial, settings$nrounds)

        xgboost::xgb.train(
          params = params, data = matrix_of(seq_len(n)),
          nrounds = rounds, verbose = 0
        )
      })

      list(
        fit = list(
          model = model,
          variables = terms$variables,
          columns = colnames(design$x),
          levels = design$levels,
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

# 4. xgboost_predict() ----

#' Predict from an xgboost Fit
#'
#' @param fit A list from xgboost_fit().
#' @param newdata A data frame to predict onto.
#' @param type Character. "link" or "response".
#' @param se Logical. Not supported; NULL is returned when TRUE.
#' @return A numeric vector, or NULL when the fit failed.
#'
#' @example # Example usage of the function
#' # xgboost_predict(fit, newdata, "response")
xgboost_predict <- function(fit, newdata, type = "link", se = FALSE) {
  if (is.null(fit) || !isTRUE(fit$ok) || is.null(fit$fit) || se) {
    return(NULL)
  }

  tryCatch(
    {
      tree <- fit$fit
      design <- xgboost_design(newdata, tree$variables, tree$levels)

      # A model fitted with an offset reads it as the base margin;
      # a model fitted without one uses its own fitted intercept
      matrix <- xgboost::xgb.DMatrix(
        design$x[, tree$columns, drop = FALSE],
        base_margin = if (tree$offset) newdata$offset else NULL
      )

      link <- stats::predict(tree$model, matrix, outputmargin = TRUE)

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

## 5.1 xgboost_terms() ----

#' Read a Formula as the Engine Uses It
#'
#' @param formula A model formula.
#' @return A list of `response`, `variables` and `offset` (TRUE
#'   when the formula has an `offset(offset)` term).
#'
#' @example # Example usage of the function
#' # xgboost_terms(count ~ MAP + I(MAP^2) + offset(offset))
xgboost_terms <- function(formula) {
  text <- paste(deparse(formula), collapse = " ")

  list(
    response = all.vars(formula[[2]]),
    variables = setdiff(
      all.vars(formula[[3]]), c("offset", "weight")
    ),
    offset = grepl("offset(offset)", text, fixed = TRUE)
  )
}

## 5.2 xgboost_design() ----

#' The Numeric Matrix xgboost Takes
#'
#' Numeric columns pass through, missing values included. Text,
#' logical and factor columns become one indicator column per
#' level, with the fitted levels when predicting, so a category is
#' read on new data as it was in fitting. A missing category is
#' missing in every indicator rather than a level of its own.
#'
#' @param data A data frame.
#' @param variables Character vector of column names.
#' @param levels Named list of factor levels from the fit, or
#'   NULL when fitting.
#' @return A list of `x` (a numeric matrix) and `levels`.
#'
#' @example # Example usage of the function
#' # xgboost_design(d, c("MAP", "Protocol"))$x
xgboost_design <- function(data, variables, levels = NULL) {
  absent <- setdiff(variables, names(data))

  if (length(absent) > 0) {
    stop("Columns not in the data: ", paste(absent, collapse = ", "),
         call. = FALSE)
  }

  fitting <- is.null(levels)
  levels <- levels %||% list()
  columns <- list()

  for (column in variables) {
    value <- data[[column]]
    categorical <- column %in% names(levels) ||
      (fitting && (is.character(value) || is.logical(value) ||
                     is.factor(value)))

    if (!categorical) {
      columns[[column]] <- as.numeric(value)
      next
    }

    if (fitting) {
      levels[[column]] <- sort(unique(as.character(
        value[!is.na(value)]
      )))
    }

    text <- as.character(value)

    for (level in levels[[column]]) {
      columns[[paste0(column, "_", level)]] <- ifelse(
        is.na(text), NA_real_, as.numeric(text == level)
      )
    }
  }

  x <- do.call(cbind, columns)

  if (is.null(dim(x))) {
    x <- matrix(x, ncol = length(columns))
  }

  colnames(x) <- names(columns)

  list(x = x, levels = levels)
}

## 5.3 xgboost_objective() ----

#' The xgboost Objective for a GLM Family
#'
#' @param family Character or family object.
#' @return Character, an xgboost objective.
#'
#' @example # Example usage of the function
#' # xgboost_objective("binomial") # "binary:logistic"
xgboost_objective <- function(family) {
  name <- if (is.character(family)) family else family$family
  link <- if (is.character(family)) NA_character_ else family$link

  if (name == "Gamma" && !identical(link, "log")) {
    stop("The xgboost engine fits Gamma on the log link only.",
         call. = FALSE)
  }

  switch(
    name,
    binomial = "binary:logistic",
    poisson = "count:poisson",
    Gamma = "reg:gamma",
    gaussian = "reg:squarederror",
    stop(
      "The xgboost engine has no objective for family `", name,
      "`. It supports binomial, poisson, Gamma and gaussian.",
      call. = FALSE
    )
  )
}

## 5.4 xgboost_best_rounds() ----

#' The Number of Rounds Early Stopping Chose
#'
#' @param model An xgb.Booster trained with early stopping.
#' @param most Integer. The ceiling, used when none was recorded.
#' @return An integer of at least 1.
#'
#' @example # Example usage of the function
#' # xgboost_best_rounds(trial, 1000)
xgboost_best_rounds <- function(model, most) {
  best <- suppressWarnings(as.integer(
    xgboost::xgb.attr(model, "best_iteration")
  ))

  if (length(best) != 1L || is.na(best)) {
    best <- most
  }

  max(1L, best)
}

# 6. Register ----
register_engine(engine_xgboost())

# End of script ----
