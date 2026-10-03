# ---
# title: Selection Rule - Staged Forward Selection by BIC
# author: Brendan Casey
# created: 2026-09-09
# inputs: none
# outputs: registers the `staged_bic` rule
# notes:
#   - The v2 bird landcover rule. `models` is a list of named
#     groups. Each group is fitted as an update to the previous
#     group's winner, and the winner is the smallest model within
#     `threshold` of the best score - a parsimony tie-break, not
#     simply the minimum.
# ---

# 1. Setup ----

## 1.1 Load packages ----
# Base R only.

# 2. select_staged_bic() ----

#' Walk Groups of Candidates, Carrying the Winner Forward
#'
#' @inheritParams select_single
#' @param threshold Numeric. How far above the best score a
#'   candidate may sit and still be eligible.
#' @param always_advance Logical. TRUE, v2's rule, takes each
#'   group's winner as the next base whatever its score; FALSE
#'   takes it only when it improves on the running model.
#' @return A selection result, with `ic_table` carrying a `stage`
#'   column.
#'
#' @example # Example usage of the function
#' # select_staged_bic(model_groups, response ~ 1, d, engine,
#' #                   "poisson", ic = "BIC")
select_staged_bic <- function(
  models, base, data, engine, family,
  weights = NULL, offset = NULL, ic = "BIC", control = list(),
  threshold = 2, always_advance = TRUE
) {
  # Step 1: Fit the base model. It is the starting point every
  # group updates, and the fallback if no group improves on it.
  current <- fit_with(
    engine, base, data, family, weights, offset, control
  )
  current_formula <- base
  current_score <- engine$ic(current, ic)
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

    # Step 4: Carry the group's winner forward. v2 always does,
    # even when it scores worse than the model it updated
    # (07.ModelLandcover.R, section 14); `always_advance = FALSE`
    # keeps the running model instead unless the group improves
    # on it.
    if (always_advance || fitted$scores[winner] < current_score) {
      current <- fitted$fits[[winner]]
      current_formula <- fitted$formulas[[winner]]
      current_score <- fitted$scores[winner]
    }
  }

  selection_result(
    fit = current,
    coefficients = engine_coef(engine, current),
    ic_table = do.call(rbind, tables),
    fitted = NULL,
    formula = current_formula,
    engine = engine
  )
}

# 3. Register ----
register_selection(
  "staged_bic", select_staged_bic,
  paste(
    "Forward selection through groups of candidates, fewest",
    "parameters within `threshold` (v2 birds)"
  ),
  requires = c("ic", "coefficients")
)

# End of script ----
