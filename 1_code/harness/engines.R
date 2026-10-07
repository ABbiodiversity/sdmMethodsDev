# ---
# title: Engine Interface
# author: Brendan Casey
# created: 2026-09-09
# inputs: none
# outputs: none; defines functions in memory
# notes:
#   - The harness's interface to the engines in
#     1_code/methods/engines/, so swapping engines is a one-word
#     spec change. The contract is in 1_code/methods/README.md;
#     check_engine() tests an engine against it on synthetic data.
# ---

# 1. Setup ----

## 1.1 Load packages ----
# Base R only.

# 2. get_engine() ----

#' Look Up One Engine
#'
#' @param name Character. A registered engine name.
#' @return The engine definition.
#'
#' @example # Example usage of the function
#' # get_engine("glm")
get_engine <- function(name) {
  get_method("engine", name)
}

# 3. Capabilities ----

## 3.1 engine_has() ----

#' Does an Engine Declare a Capability
#'
#' @param engine An engine definition.
#' @param capability Character. One of engine_capabilities().
#' @return Logical.
#'
#' @example # Example usage of the function
#' # engine_has(get_engine("glm"), "se")
engine_has <- function(engine, capability) {
  capability %in% engine$capabilities
}

## 3.2 engine_coef() ----

#' Coefficients from a Fit, Where the Engine Has Them
#'
#' Reuses coefficients cached on the fit by fit_with().
#'
#' @param engine An engine definition.
#' @param fit A fit from engine$fit().
#' @return A data frame of term, estimate and se, or NULL.
#'
#' @example # Example usage of the function
#' # engine_coef(engine, fit)
engine_coef <- function(engine, fit) {
  if (is.null(fit) || !isTRUE(fit$ok)) {
    return(NULL)
  }

  if (!is.null(fit$coefficients)) {
    return(fit$coefficients)
  }

  if (!engine_has(engine, "coefficients")) {
    return(NULL)
  }

  engine$coef(fit)
}

## 3.3 engine_converged() ----

#' Did a Fit Converge, as Far as the Engine Can Say
#'
#' @param engine An engine definition.
#' @param fit A fit from engine$fit().
#' @return Logical. FALSE for a failed fit; TRUE for a fit whose
#'   engine cannot report convergence.
#'
#' @example # Example usage of the function
#' # engine_converged(engine, fit)
engine_converged <- function(engine, fit) {
  if (is.null(fit) || !isTRUE(fit$ok)) {
    return(FALSE)
  }

  if (!is.function(engine$converged)) {
    return(TRUE)
  }

  isTRUE(engine$converged(fit))
}

## 3.4 engine_nobs() ----

#' Number of Observations a Fit Used
#'
#' @param engine An engine definition, or NULL.
#' @param fit A fit from engine$fit().
#' @return An integer, or NA when it cannot be said.
#'
#' @example # Example usage of the function
#' # engine_nobs(engine, fit)
engine_nobs <- function(engine, fit) {
  if (is.null(fit) || !isTRUE(fit$ok)) {
    return(NA_integer_)
  }

  if (!is.null(engine) && is.function(engine$nobs)) {
    return(tryCatch(
      as.integer(engine$nobs(fit)),
      error = function(e) NA_integer_
    ))
  }

  tryCatch(
    as.integer(stats::nobs(fit$fit)),
    error = function(e) NA_integer_
  )
}

## 3.5 fit_with() ----

#' Fit One Formula Through an Engine
#'
#' The one place a candidate is fitted. Coefficients are computed
#' once and cached on the fit (bayesglm's summary() is slow).
#'
#' @param engine An engine definition.
#' @param formula A model formula.
#' @param data,family,weights,offset,control As engine$fit takes.
#' @return The engine's fit list, with `coefficients` added when
#'   the engine has them.
#'
#' @example # Example usage of the function
#' # fit_with(get_engine("glm"), response ~ MAP, d, "binomial")
fit_with <- function(
  engine, formula, data, family, weights = NULL, offset = NULL,
  control = list()
) {
  fit <- engine$fit(
    formula = formula, data = data, family = family,
    weights = weights, offset = offset, control = control
  )

  if (isTRUE(fit$ok) && engine_has(engine, "coefficients")) {
    fit$coefficients <- engine$coef(fit)
  }

  fit
}

# 4. check_engine() ----

#' Test an Engine Against the Contract
#'
#' Fits synthetic binomial and Poisson data (weights, a formula
#' offset, a factor) and checks each part of the contract the
#' engine declares.
#'
#' @param engine An engine definition, or a registered name.
#' @param n Integer. Rows of synthetic data.
#' @param seed Integer. Seed for the synthetic data.
#' @param quiet Logical. Suppress the printed table.
#' @return A data frame of check, family, pass and note,
#'   invisibly. Every `pass` should be TRUE.
#'
#' @example # Example usage of the function
#' # check_engine("glm")
#' # check_engine(my_new_engine())
check_engine <- function(engine, n = 400L, seed = 1L, quiet = FALSE) {
  if (is.character(engine)) {
    engine <- get_engine(engine)
  }

  # Step 1: Synthetic data with a known signal
  data <- with_seed(seed, {
    x1 <- stats::rnorm(n)
    x2 <- stats::runif(n)
    habitat <- factor(sample(c("A", "B", "C"), n, replace = TRUE))
    effort <- stats::runif(n, 0.5, 2)
    eta <- -0.5 + 0.8 * x1 - 0.6 * x2 + (habitat == "B") * 0.7

    data.frame(
      x1 = x1, x2 = x2, habitat = habitat,
      offset = log(effort),
      weight = stats::runif(n, 0.5, 1.5),
      presence = stats::rbinom(n, 1, stats::plogis(eta)),
      count = stats::rpois(n, exp(eta + log(effort)))
    )
  })

  checks <- list()

  record <- function(check, family, pass, note = "") {
    checks[[length(checks) + 1]] <<- data.frame(
      check = check, family = family, pass = isTRUE(pass),
      note = note, stringsAsFactors = FALSE
    )
  }

  newdata <- data[1:20, ]

  for (family in c("binomial", "poisson")) {
    formula <- if (family == "binomial") {
      presence ~ x1 + x2 + habitat
    } else {
      count ~ x1 + x2 + habitat + offset(offset)
    }

    # Step 2: Fitting succeeds, weighted, and reports itself
    fit <- tryCatch(
      engine$fit(
        formula = formula, data = data, family = family,
        weights = data$weight, offset = NULL, control = list()
      ),
      error = function(e) {
        list(ok = FALSE, message = conditionMessage(e))
      }
    )
    record(
      "fit returns list(fit, ok, message) with ok = TRUE", family,
      is.list(fit) && isTRUE(fit$ok) &&
        all(c("fit", "ok", "message") %in% names(fit)),
      if (!isTRUE(fit$ok)) format(fit$message) else ""
    )

    if (!isTRUE(fit$ok)) {
      next
    }

    # Step 3: Predictions on both scales
    link <- tryCatch(
      engine$predict(fit, newdata, "link"),
      error = function(e) NULL
    )
    response <- tryCatch(
      engine$predict(fit, newdata, "response"),
      error = function(e) NULL
    )
    record(
      "predict returns one finite value per row", family,
      is.numeric(link) && length(link) == nrow(newdata) &&
        all(is.finite(link))
    )
    record(
      "response-scale prediction is in range", family,
      is.numeric(response) && length(response) == nrow(newdata) &&
        if (family == "binomial") {
          all(response >= 0 & response <= 1)
        } else {
          all(response >= 0)
        }
    )

    # Doubling effort on new data must double a Poisson prediction
    if (family == "poisson") {
      shifted <- newdata
      shifted$offset <- shifted$offset + log(2)
      doubled <- tryCatch(
        engine$predict(fit, shifted, "response"),
        error = function(e) NULL
      )
      record(
        "an offset in the formula is applied to new data", family,
        is.numeric(doubled) &&
          isTRUE(all.equal(doubled, 2 * response, tolerance = 1e-6))
      )
    }

    # Step 4: The optional capabilities the engine declares
    if (engine_has(engine, "coefficients")) {
      cf <- tryCatch(engine$coef(fit), error = function(e) NULL)
      record(
        "coef returns term, estimate and se", family,
        is.data.frame(cf) &&
          all(c("term", "estimate", "se") %in% names(cf)) &&
          nrow(cf) > 0
      )
    }

    if (engine_has(engine, "ic")) {
      scores <- vapply(
        c("AIC", "AICc", "BIC"),
        function(type) {
          tryCatch(engine$ic(fit, type), error = function(e) NA_real_)
        },
        numeric(1)
      )
      record(
        "ic returns a finite AIC, AICc and BIC", family,
        all(is.finite(scores))
      )
    }

    if (engine_has(engine, "se")) {
      with_se <- tryCatch(
        engine$predict(fit, newdata, "link", se = TRUE),
        error = function(e) NULL
      )
      record(
        "predict(se = TRUE) returns fit and se.fit", family,
        is.list(with_se) &&
          length(with_se$fit) == nrow(newdata) &&
          length(with_se$se.fit) == nrow(newdata) &&
          all(with_se$se.fit >= 0)
      )
    }
  }

  # Step 5: Failure is returned, not raised, so a selection rule
  # can see which candidates failed
  failed <- tryCatch(
    engine$fit(
      formula = presence ~ no_such_column, data = data,
      family = "binomial", weights = NULL, offset = NULL,
      control = list()
    ),
    error = function(e) "raised"
  )
  record(
    "a failed fit returns ok = FALSE rather than raising", "-",
    is.list(failed) && identical(failed$ok, FALSE)
  )

  if (is.list(failed)) {
    record(
      "predict on a failed fit returns NULL", "-",
      is.null(tryCatch(
        engine$predict(failed, newdata, "response"),
        error = function(e) "raised"
      ))
    )
  }

  result <- do.call(rbind, checks)

  if (!quiet) {
    cat("Engine `", engine$name, "`: ", sum(result$pass), " of ",
        nrow(result), " checks pass\n", sep = "")
    print(result, row.names = FALSE, right = FALSE)
  }

  invisible(result)
}

# End of script ----
