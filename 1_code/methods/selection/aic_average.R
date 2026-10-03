# ---
# title: Selection Rule - Information-Criterion Model Averaging
# author: Brendan Casey
# created: 2026-09-09
# inputs: none
# outputs: registers the `aic_average` rule
# notes:
#   - The v2 climate rule for plants and birds. Coefficients are
#     averaged across candidates with Akaike weights, treating a
#     term absent from a candidate as zero - that model's statement
#     that the effect is nil, and MuMIn's "full" average.
#   - The final model's predictor is the weighted average of the
#     candidates' link predictions, which for a linear predictor is
#     the averaged coefficients applied to the data.
# ---

# 1. Setup ----

## 1.1 Load packages ----
# Base R only.

# 2. select_aic_average() ----

#' Average Candidates by Information-Criterion Weight
#'
#' @inheritParams select_single
#' @return A selection result. `fit` is the best single candidate;
#'   `coefficients` are the averaged ones; `predict` is the
#'   weighted average of the candidates.
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
  per_model <- lapply(fitted$fits, function(f) engine_coef(engine, f))
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

      # A term the candidate lacks, or estimated as NA because it
      # is aliased, counts as zero, as in MuMIn's full average.
      row <- match(term, cf$term)
      absent <- is.na(row) || is.na(cf$estimate[row])
      value <- if (absent) 0 else cf$estimate[row]
      se <- if (absent) 0 else cf$se[row]

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
    fitted = fitted,
    engine = engine,
    predict = combined_predictor(
      fitted$fits, engine, family, weights = table$weight
    )
  )
}

# 3. Register ----
register_selection(
  "aic_average", select_aic_average,
  paste(
    "Average coefficients over candidates by Akaike weight",
    "(v2 climate)"
  ),
  requires = c("ic", "coefficients")
)

# End of script ----
