# ---
# title: Engine - Boosted Regression Trees (xgboost)
# author: Brendan Casey
# created: 2026-10-05
# inputs: none
# outputs: registers the `xgboost` engine
# notes:
#   - Use via replace_stage_method() (one models_union() formula,
#     `single` rule): it declares no coefficients, IC or SE.
#   - Replaces gbm, which cannot fit the mammal hurdle (no 0-1
#     proportion response, no Gamma); xgboost has
#     `binary:logistic` with proportions and log-link `reg:gamma`.
#   - Only formula variables are used (`I(x^2)`, `a:b` give x, a,
#     b). Categoricals are one-hot coded with the fitted levels;
#     NAs stay NA. The offset is the `base_margin`, in fitting and
#     prediction.
#   - Rounds are chosen by early stopping on a seeded holdout
#     (`valid_fraction`), then refitted on all rows. Noisy on
#     small draws.
#   - `control` settings: nrounds, eta, max_depth, subsample,
#     colsample_bytree, min_child_weight, early_stopping_rounds,
#     valid_fraction, seed. Defaults are untuned and quick (eta
#     0.05 is higher than Elith, Leathwick and Hastie 2008
#     advise); tune before judging the method.
#   - One thread per fit; the harness parallelizes over species.
# ---

# 1. Setup ----

## 1.1 Load packages ----
# xgboost (version: 3.2.1), loaded lazily

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

      # Step 1: Drop rows missing response, weight or offset (as a
      # GLM does); missing predictors are kept
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

      # Step 2: Rounds by early stopping, then refit on every row
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

      # Without base_margin xgboost uses its own fitted intercept
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
#' Text, logical and factor columns become one indicator per
#' fitted level; a missing category is NA in every indicator.
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
