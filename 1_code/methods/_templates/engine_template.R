# ---
# title: Engine - [Name]
# author: [Your Name]
# created: [YYYY-MM-DD]
# inputs: none
# outputs: registers the `[name]` engine
# notes:
#   - A template. Copy to 1_code/methods/engines/[name].R, fill in
#     the four functions, and run check_engine(engine_[name]())
#     until every check passes. Then name it in a spec stage:
#     `engine = "[name]"`.
#   - The contract, in full, is in 1_code/methods/README.md. In
#     short:
#     - fit() never raises. It returns list(fit, ok, message),
#       with ok = FALSE and the error message when fitting fails,
#       because a candidate set is expected to hold models that
#       cannot be fitted for every species and draw.
#     - predict() returns one number per row of newdata, or NULL
#       when it cannot. An offset in the formula
#       (`+ offset(offset)`) must be applied to new data.
#     - Declare only the capabilities the engine really has.
#       Selection rules check them: a rule that ranks candidates
#       needs `ic`; one that averages coefficients needs
#       `coefficients`; inverse-variance averaging needs `se`.
#       With none of them, use the `single` rule.
#   - Load any package lazily with requireNamespace(), so a run
#     that does not use this engine does not need the package.
# ---

# 1. Setup ----

## 1.1 Load packages ----
# [package], lazily; see the header.

# 2. engine_[name]() ----

#' [One-line title of the method]
#'
#' [What it fits, and any setting it takes through `control`.]
#'
#' @return An engine definition.
#'
#' @example # Example usage of the function
#' # check_engine(engine_[name]())
engine_template <- function() {
  list(
    name = "[name]",
    description = "[One line for list_methods()]",

    # A subset of engine_capabilities(): "coefficients", "ic",
    # "se", "converged"
    capabilities = character(0),

    # Step 1: Fit. Never raise; return the failure instead.
    fit = function(formula, data, family, weights = NULL,
                   offset = NULL, control = list()) {
      tryCatch(
        {
          fit <- NULL # [fit the model with formula and data]
          list(fit = fit, ok = TRUE, message = NA_character_)
        },
        error = function(e) {
          list(fit = NULL, ok = FALSE, message = conditionMessage(e))
        }
      )
    },

    # Step 2: Predict. `type` is "link" or "response"; with
    # se = TRUE (only when declared), list(fit, se.fit).
    predict = function(fit, newdata, type = "link", se = FALSE) {
      if (is.null(fit) || !isTRUE(fit$ok)) {
        return(NULL)
      }

      tryCatch(
        NULL, # [predict fit$fit onto newdata, one value per row]
        error = function(e) NULL
      )
    },

    # Step 3, when declared: a data frame of term, estimate, se
    coef = NULL,

    # Step 4, when declared: a number for type "AIC", "AICc" or
    # "BIC"; Inf for a failed fit, so it never wins
    ic = NULL
  )
}

# 3. Register ----
# Uncomment once check_engine() passes:
# register_engine(engine_template())

# End of script ----
