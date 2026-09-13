# ---
# title: Apply the Evaluation Split
# author: Brendan Casey
# created: 2026-09-05
# inputs: none
# outputs: none
# notes:
#   - Placeholder. The split is part of the frozen dataset,
#     so it is read, never recomputed - recomputing it would
#     break comparability across experiments.
#   - The v2 pipeline does not use this; the v2 scripts carry
#     their own bootstrap design in bootstrap.ids.
# ---

# 1. apply_split() ----

#' Apply the Evaluation Split
#'
#' Applies the frozen evaluation split to a set of records.
#'
#' @param data Data frame of response records.
#' @param split Character. Which split to return, one of
#'   "train", "test", or "all".
#' @return A data frame holding the requested split.
#'
#' @example
#' # Example usage of the function
#' # apply_split()
apply_split <- function(data, split = c("train", "test", "all")) {
  # Step 1: Match the requested split
  # Step 2: Join the frozen split assignment and subset

  stop(
    "apply_split() is not implemented yet.",
    call. = FALSE
  )
}

# End of script ----
