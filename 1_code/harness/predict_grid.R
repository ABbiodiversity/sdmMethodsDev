# ---
# title: Project a Fitted Model onto a Prediction Grid
# author: Brendan Casey
# created: 2026-09-09
# inputs:
#   in the test dataset's lookup/ (see data_source.R):
#     - <name>_prediction_matrix.csv
# outputs: none; returns objects in memory
# notes:
#   - A grid row is a pure stand of one habitat type, so
#     predicting onto it gives the per-habitat effect v2 reports.
#     Every engine can predict (a tree has no coefficients), so
#     grids are how engines are compared. Bird grids are rebuilt
#     by _setup/09 from v2's coefficient translation matrix.
#   - v2's later coefficient adjustments (e.g. plant stand-age
#     splines) are in the coefficients, not the grid.
# ---

# 1. Setup ----

## 1.1 Load packages ----
library(data.table) # lookup table reading (version: 1.16.4)

# 2. load_prediction_grid() ----

#' Read a Prediction Grid
#'
#' @param data_dir Character. The test dataset folder.
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

#' Predict a Selection's Final Model onto a Grid
#'
#' Columns come from the grid, then the stage's constants (v2
#' holds Climate at zero and Protocol at the new protocol), then
#' zero. Uses the selection's own predictor, so an averaged or
#' combined model is projected as a whole.
#'
#' @param selected A selection result, carrying `predict`.
#' @param grid A prediction grid, from load_prediction_grid().
#' @param constants Named list of values for columns held fixed
#'   across the grid.
#' @param type Character. "response" or "link".
#' @return A named numeric vector, one value per grid row, or
#'   NULL when the model cannot be predicted.
#'
#' @example # Example usage of the function
#' # predict_grid(selected, grid, constants = list(Climate = 0))
predict_grid <- function(
  selected,
  grid,
  constants = list(),
  type = "response"
) {
  if (is.null(grid) || !is.function(selected$predict)) {
    return(NULL)
  }

  newdata <- grid

  # Step 1: Hold the stage's constants
  for (one in names(constants)) {
    newdata[[one]] <- constants[[one]]
  }

  # Step 2: Every column any candidate formula reads, at zero
  # where the grid and the constants have none. A grid row is a
  # pure stand, so a term it omits is absent rather than unknown.
  formulas <- selected$formulas %||% list(selected$formula)
  needed <- unique(unlist(lapply(
    Filter(function(f) !is.null(f) && !identical(f, NA_character_),
           formulas),
    formula_variables
  )))

  for (one in setdiff(needed, names(newdata))) {
    newdata[[one]] <- 0
  }

  # Step 3: An offset is a property of a survey, not of a habitat
  # type, so a grid prediction is made without one
  newdata$offset <- 0

  predicted <- tryCatch(
    selected$predict(newdata, type),
    error = function(e) NULL
  )

  if (is.null(predicted) || length(predicted) != nrow(grid)) {
    return(NULL)
  }

  stats::setNames(as.numeric(predicted), rownames(grid))
}

# 4. predict_from_coefficients() ----

#' Predict from a Coefficient Vector Rather Than a Fit
#'
#' Carries a stage forward as v2 does: the averaged coefficients
#' applied to the data, `plogis(X %*% b)`, so the next stage sees
#' a probability. A single candidate's prediction would discard
#' the averaging; the link scale would change what the next
#' stage's coefficient means.
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

  # A term is a column, an interaction of columns (a:b), or an
  # expression such as I(Easting^2), which v2's bird climate
  # formulas use. Each is evaluated against the frame.
  term_value <- function(term) {
    if (term %in% names(data)) {
      return(as.numeric(data[[term]]))
    }

    if (grepl(":", term, fixed = TRUE)) {
      pieces <- strsplit(term, ":", fixed = TRUE)[[1]]
      return(Reduce(`*`, lapply(pieces, term_value)))
    }

    if (startsWith(term, "I(")) {
      return(as.numeric(eval(parse(text = term)[[1]], data)))
    }

    NULL
  }

  columns <- lapply(terms, term_value)
  absent <- terms[vapply(columns, is.null, logical(1))]

  if (length(absent) > 0) {
    stop(
      "Cannot carry the stage forward: ", length(absent),
      " term(s) are not columns of the frame:\n  ",
      paste(utils::head(absent, 10), collapse = "\n  "),
      call. = FALSE
    )
  }

  linear <- drop(do.call(cbind, columns) %*% estimates)

  if (scale == "response") {
    return(stats::plogis(linear))
  }

  linear
}

# End of script ----
