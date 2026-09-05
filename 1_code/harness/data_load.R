# ---
# title: Load the Frozen Test Dataset
# author: Brendan Casey
# created: 2026-09-05
# inputs: none
# outputs: none
# notes:
#   - Placeholder. The frozen test dataset is not yet
#     assembled, so this stops rather than returning
#     a partial answer.
#   - 0_data/manifest.md is the source of truth for the
#     dataset version and paths.
# ---

# 1. load_test_data() ----

#' Load the Frozen Test Dataset
#'
#' Loads the frozen cross-taxa test dataset for one taxon.
#'
#' @param taxon Character. Taxon slug (e.g. "mite").
#' @param version Character. Dataset version from
#'   0_data/manifest.md.
#' @return A data frame of response records.
#'
#' @example
#' # Example usage of the function
#' # load_test_data()
load_test_data <- function(taxon, version = NULL) {
  # Step 1: Resolve the dataset path from the manifest
  # Step 2: Read the records and validate the columns

  stop(
    "load_test_data() is not implemented yet.",
    call. = FALSE
  )
}

# End of script ----
