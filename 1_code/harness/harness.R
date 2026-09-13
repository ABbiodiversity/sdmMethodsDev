# ---
# title: Load the Harness
# author: Brendan Casey
# created: 2026-09-09
# inputs:
#   the other files in 1_code/harness/
# outputs: none; defines the harness in the calling environment
# notes:
#   - One entry point, so an experiment sources this rather than
#     nine files in the right order.
#   - The order matters. covariate_sets.R calls covariate_key()
#     from data_load.R, data_load.R calls the derivation helpers
#     from covariate_sets.R, and run_model.R calls most of the
#     rest. They are sourced into one environment, so the mutual
#     reference between the first two resolves once all are
#     loaded; only run_model.R has to come last.
# ---

# 1. Setup ----

## 1.1 Load packages ----
library(data.table) # used throughout (version: 1.16.4)

# 2. load_harness() ----

#' Source Every Harness File
#'
#' @param harness_dir Character. Path to 1_code/harness.
#' @param envir Environment to source into.
#' @return Character vector of the files sourced, invisibly.
#'
#' @example # Example usage of the function
#' # load_harness("1_code/harness")
load_harness <- function(
  harness_dir = "1_code/harness",
  envir = parent.frame()
) {
  files <- c(
    "data_load.R",
    "covariate_sets.R",
    "species.R",
    "model_sets.R",
    "resample.R",
    "engines.R",
    "selection.R",
    "eval_metrics.R",
    "predict_grid.R",
    "result.R",
    "run_model.R",
    file.path("utils", "step_runner.R")
  )

  paths <- file.path(harness_dir, files)
  absent <- paths[!file.exists(paths)]

  if (length(absent) > 0) {
    stop(
      "Harness files not found:\n  ",
      paste(absent, collapse = "\n  "),
      call. = FALSE
    )
  }

  for (path in paths) {
    source(path, local = envir)
  }

  invisible(paths)
}

# End of script ----
