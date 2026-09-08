# ---
# title: Pipeline Step Runner
# author: Brendan Casey
# created: 2026-09-05
# inputs: none
# outputs: none
# notes:
#   - Taxon-agnostic helper for running one numbered module
#     script, timing it, and mirroring its output to a log.
#     Sourced by the experiments in 1_code/experiments/.
#   - Was v2_script_runner.R, which also switched the working
#     directory to a v2 project root and restored the caller's
#     objects after each script's rm(list = ls()). The module
#     scripts do neither now: they take their paths as arguments
#     and clear nothing, so both are gone along with the input
#     checks, which each script does for itself against the paths
#     it was actually given.
#   - Scripts are sourced into the global environment on purpose.
#     They read their configuration from objects the experiment
#     has already set there, and their clusterExport() calls read
#     from .GlobalEnv.
# ---

# 1. run_step() ----

#' Run One Pipeline Step
#'
#' Sources a script, reporting its label and the time it took.
#' Mirrors console output to a timestamped log file so an
#' unattended run leaves a record.
#'
#' The script is sourced into the global environment, so it sees
#' the configuration the caller set there - `taxon`, `out_dir`
#' and the rest - and its parallel workers can export from it.
#'
#' @param label Character. A descriptive label for the step, used
#'   in the console output and in the log file name
#'   (e.g. "02: Hierarchical models (mites)").
#' @param script Character. Path to the script to run.
#' @param log_dir Character. Directory for log files, or NULL to
#'   print to the console only.
#' @return NULL, invisibly. Output is printed to the console and,
#'   when `log_dir` is set, copied to a log file.
#'
#' @example
#' # Example usage of the function
#' run_step(
#'   label = "02: Hierarchical models (mites)",
#'   script = "1_code/modules/plants/02_hierarchical_models.R",
#'   log_dir = log_path
#' )
#'
#' # Run without writing a log file
#' run_step(
#'   label = "02: Hierarchical models (mites)",
#'   script = "1_code/modules/plants/02_hierarchical_models.R",
#'   log_dir = NULL
#' )
run_step <- function(label, script, log_dir = NULL) {
  # Step 1: Fail on a missing script before anything is logged
  if (!file.exists(script)) {
    stop("Script not found: ", script, call. = FALSE)
  }

  # Step 2: Announce the step and record the start time
  cat("\n--- Running ", label, " ---\n", sep = "")
  start <- Sys.time()

  # Step 3: Mirror output to a timestamped log. split = TRUE keeps
  # it on the console too, and on.exit() closes the connection
  # even if the script errors.
  if (!is.null(log_dir)) {
    if (!dir.exists(log_dir)) {
      dir.create(log_dir, recursive = TRUE)
    }

    stamp <- format(Sys.time(), "%Y-%m-%d_%H-%M-%S")
    safe_label <- gsub("[^A-Za-z0-9_]+", "_", label)
    log_file <- file.path(
      log_dir,
      paste0(stamp, "_", safe_label, ".log")
    )

    log_con <- file(log_file, open = "wt")
    sink(log_con, split = TRUE)
    on.exit(
      {
        sink()
        close(log_con)
      },
      add = TRUE
    )

    cat("Logging to ", log_file, "\n", sep = "")
  }

  # Step 4: Source into the global environment, which is where the
  # module scripts read their configuration and where their
  # clusterExport() calls look for objects
  source(script)

  # Step 5: Report how long the step took
  elapsed <- format(round(Sys.time() - start, 1))
  cat("Completed ", label, " in ", elapsed, "\n", sep = "")

  invisible(NULL)
}

# End of script ----
