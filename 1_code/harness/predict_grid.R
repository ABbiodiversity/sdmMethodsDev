# ---
# title: Project a Fitted Model onto a Prediction Grid
# author: Brendan Casey
# created: 2026-09-09
# inputs:
#   in 0_data/test_dataset/lookup/:
#     - <name>_prediction_matrix.csv
# outputs: none; returns objects in memory
# notes:
#   - A prediction grid has one row per habitat type and one
#     column per model term, holding the cover composition of a
#     stand made entirely of that type. Predicting onto it turns
#     a fitted model into an effect per habitat type, which is
#     the quantity v2 reports and the Biodiversity Browser shows.
#   - This is the comparison currency. Coefficients cannot compare
#     a GLM against a boosted tree, because a tree has none, but
#     every engine can predict onto these rows.
#   - Terms the grid does not carry are set to zero, not dropped.
#     A grid row describes a pure stand, so a human footprint term
#     is genuinely absent from it rather than unknown, and zero is
#     what "none of this here" means. Terms that carry a stage
#     forward are the exception and are set to their mean, because
#     a habitat effect is read at average climate, not at zero
#     climate.
#   - A grid whose VegType column is missing is an error rather
#     than a silent positional fallback, because the row order of
#     a prediction matrix is not something to guess at.
# ---

# 1. Setup ----

## 1.1 Load packages ----
library(data.table) # lookup table reading (version: 1.16.4)

# 2. load_prediction_grid() ----

#' Read a Prediction Grid
#'
#' @param data_dir Character. Path to 0_data/test_dataset.
#' @param name Character. Grid name, without the
#'   `_prediction_matrix.csv` suffix, or NULL for no grid.
#' @return A data frame with habitat types as rownames, or NULL.
#'
#' @example # Example usage of the function
#' # grid <- load_prediction_grid(data_dir, "veg")
load_prediction_grid <- function(data_dir, name) {
  if (is.null(name) || is.na(name)) {
    return(NULL)
  }

  path <- file.path(
    data_dir, "lookup", paste0(name, "_prediction_matrix.csv")
  )

  if (!file.exists(path)) {
    stop(
      "Prediction grid not found:\n  ", path,
      call. = FALSE
    )
  }

  grid <- as.data.frame(fread(path))

  if (!"VegType" %in% names(grid)) {
    stop(
      basename(path), " has no VegType column, so its rows ",
      "cannot be named.",
      call. = FALSE
    )
  }

  rownames(grid) <- grid$VegType
  grid$VegType <- NULL

  grid
}

# 3. predict_grid() ----

#' Predict a Fitted Model onto a Grid
#'
#' Builds a prediction frame carrying every term the model needs:
#' the grid's own columns where it has them, zero where it does
#' not, and the mean where a term carries a previous stage.
#'
#' @param selected A selection result, from selection_run().
#' @param engine An engine definition.
#' @param grid A prediction grid, from load_prediction_grid().
#' @param carried Named list of values for terms that carry a
#'   previous stage forward, or NULL to use zero.
#' @param type Character. "response" or "link".
#' @return A named numeric vector, one value per grid row, or
#'   NULL when the model cannot be predicted.
#'
#' @example # Example usage of the function
#' # predict_grid(selected, engine, grid,
#' #              carried = list(Climate = 0.4))
predict_grid <- function(
  selected,
  engine,
  grid,
  carried = NULL,
  type = "response"
) {
  if (is.null(grid) || is.null(selected$fit)) {
    return(NULL)
  }

  terms <- model_terms(selected)

  if (length(terms) == 0) {
    return(NULL)
  }

  # Step 1: Start from the grid, so every term it carries takes
  # the composition of a pure stand of that habitat type
  newdata <- grid

  # Step 2: Fill in the terms the grid has no column for. Zero is
  # what a grid row means by omission - none of that here - and a
  # carried stage is the exception, held at its supplied value.
  for (one in setdiff(terms, names(newdata))) {
    newdata[[one]] <- if (!is.null(carried[[one]])) {
      carried[[one]]
    } else {
      0
    }
  }

  # Step 3: An offset is a property of a survey, not of a habitat
  # type, so a grid prediction is made without one
  if ("offset" %in% names(newdata) == FALSE) {
    newdata$offset <- 0
  }

  predicted <- engine$predict(selected$fit, newdata, type)

  if (is.null(predicted)) {
    return(NULL)
  }

  stats::setNames(predicted, rownames(grid))
}

# 4. predict_from_coefficients() ----

#' Predict from a Coefficient Vector Rather Than a Fit
#'
#' A stage carried forward is not the best single candidate's
#' prediction: it is the averaged coefficient vector applied to
#' the data. v2 computes the climate term as
#' `plogis(X %*% averaged_coefficients)`, so the habitat models
#' see a probability between 0 and 1, and their coefficient on it
#' is correspondingly large.
#'
#' Carrying a single model's prediction instead would discard the
#' averaging the stage just did, and carrying it on the link
#' scale would change what the next stage's coefficient means.
#'
#' @param coefficients A data frame of term and estimate.
#' @param data A data frame carrying those terms.
#' @param scale Character. "response" applies the logistic, which
#'   is what v2 does; "link" leaves the linear predictor.
#' @return A numeric vector, one per row of `data`.
#'
#' @example # Example usage of the function
#' # predict_from_coefficients(selected$coefficients, frame)
predict_from_coefficients <- function(
  coefficients,
  data,
  scale = c("response", "link")
) {
  scale <- match.arg(scale)

  estimates <- stats::setNames(
    coefficients$estimate, coefficients$term
  )

  # Engines name the intercept "(Intercept)"; v2's coefficient
  # vectors call it "Intercept" and carry a column of ones.
  names(estimates) <- sub(
    "^\\(Intercept\\)$", "Intercept",
    names(estimates)
  )

  data$Intercept <- 1
  terms <- names(estimates)
  absent <- setdiff(terms, names(data))

  if (length(absent) > 0) {
    stop(
      "Cannot carry the stage forward: ", length(absent),
      " term(s) are not columns of the frame:\n  ",
      paste(utils::head(absent, 10), collapse = "\n  "),
      call. = FALSE
    )
  }

  linear <- drop(
    as.matrix(data[, terms, drop = FALSE]) %*% estimates
  )

  if (scale == "response") {
    return(stats::plogis(linear))
  }

  linear
}

# 5. model_terms() ----

#' Name the Terms a Selected Model Uses
#'
#' Taken from the coefficients where the engine has them, and
#' from the formula otherwise, so an engine without coefficients
#' still reaches a grid prediction.
#'
#' @param selected A selection result.
#' @return A character vector of term names, without the
#'   intercept.
#'
#' @example # Example usage of the function
#' # model_terms(selected)
model_terms <- function(selected) {
  if (!is.null(selected$coefficients)) {
    terms <- selected$coefficients$term

    return(setdiff(terms, c("(Intercept)", "Intercept")))
  }

  if (!is.na(selected$formula)) {
    return(setdiff(
      all.vars(stats::as.formula(selected$formula)),
      c("response", "offset", "weight")
    ))
  }

  character(0)
}

# End of script ----
