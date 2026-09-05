# ---
# title: v2 Script Runner Utilities
# author: Brendan Casey
# created: 2026-09-05
# inputs: none
# outputs: none
# notes:
#   - Taxon-agnostic helpers for running the unmodified v2
#     scripts in 0_data/v2_scripts/ from this repository.
#     Sourced by the runners in 1_code/modules/<taxon>/.
#   - The v2 scripts' paths are relative to the v2 project root,
#     so run_step() switches the working directory to run_dir for
#     the length of a step and restores it afterwards.
#   - The v2 scripts open with rm(list = ls()), so run_step()
#     snapshots the names in `protect` and restores them on exit.
#     Objects a script leaves behind are not kept, so the next
#     script's cleanup still frees them.
#   - Scripts are sourced into the global environment on purpose;
#     their clusterExport() calls read from .GlobalEnv.
#   - Assumes the v2 layout - inputs under 0_data/, functions
#     under 1_code/r-scripts/, outputs under 3_output/.
# ---

# 1. resolve_v2_root() ----

#' Resolve and Validate a v2 Project Root
#'
#' Confirms the configured v2 project root exists and returns it
#' as an absolute path, so a run stops with a readable message
#' rather than failing on the first relative path inside a v2
#' script.
#'
#' @param root Character. Path to the v2 project root, or NA when
#'   it has not been configured.
#' @return Character. The normalized absolute path. Stops when
#'   `root` is unset, empty, or not a directory.
#'
#' @example
#' # Example usage of the function
#' v2_root <- Sys.getenv("SDM_V2_ROOT", unset = NA_character_)
#' v2_root <- resolve_v2_root(v2_root)
resolve_v2_root <- function(root) {
  # Step 1: Reject an unset, empty, or absent path. The tests are
  # ordered so || short-circuits before dir.exists() sees an NA.
  if (length(root) != 1 || is.na(root) || !nzchar(root) ||
        !dir.exists(root)) {
    stop(
      "The v2 project root is not a directory: ", root, "\n",
      "Set SDM_V2_ROOT, or assign v2_root in the runner's ",
      "section 1.2.",
      call. = FALSE
    )
  }

  # Step 2: Return an absolute path, since run_step() changes the
  # working directory while a step runs
  normalizePath(root, winslash = "/")
}

# 2. check_inputs() ----

#' Check That Required Files Exist
#'
#' Confirms every file a pipeline step reads is present before the
#' step runs, so a missing input fails with a readable message
#' rather than partway through a long model fit.
#'
#' @param paths Character vector. File paths to check, relative to
#'   `root`.
#' @param root Character. Directory the paths are relative to.
#' @param what Character. Label for the group of files, used in
#'   the error message (e.g. "inputs for 02d").
#' @return NULL, invisibly. Stops with the missing paths listed
#'   when any file is absent.
#'
#' @example
#' # Example usage of the function
#' check_inputs(
#'   c("0_data/bootstrap/mite-bootstrap-ids.Rdata"),
#'   root = v2_root,
#'   what = "inputs for 02c"
#' )
check_inputs <- function(paths, root, what) {
  # Step 1: Test each path against the given root
  missing <- paths[!file.exists(file.path(root, paths))]

  # Step 2: Report every missing file at once, not just the first
  if (length(missing) > 0) {
    stop(
      "Missing ", what, " under ", root, ":\n  ",
      paste(missing, collapse = "\n  "),
      call. = FALSE
    )
  }

  invisible(NULL)
}

# 3. create_v2_output_dirs() ----

#' Create the Output Folders a v2 Script Writes To
#'
#' The v2 scripts end in save(), which fails when the destination
#' folder does not exist. Creating the folders up front keeps a
#' finished model run from being lost on its last line.
#'
#' @param root Character. Path to the v2 project root.
#' @param dirs Character vector. Output folders to create,
#'   relative to `root`. Defaults to the model and validation
#'   folders the v2 modelling scripts write to.
#' @return NULL, invisibly.
#'
#' @example
#' # Example usage of the function
#' create_v2_output_dirs(v2_root)
create_v2_output_dirs <- function(
  root,
  dirs = c("3_output/models", "3_output/validation")
) {
  # Step 1: Create each folder, leaving existing ones untouched
  for (out_dir in dirs) {
    out_path <- file.path(root, out_dir)
    if (!dir.exists(out_path)) {
      dir.create(out_path, recursive = TRUE)
    }
  }

  invisible(NULL)
}

# 4. check_function_files() ----

#' Compare v2 Function Files With This Repository's Copies
#'
#' The v2 scripts are sourced from this repository but the
#' function files they source are read from the v2 project root,
#' so the two copies can drift. A mismatch means the run is not
#' reproducing the code held here, which matters for parity work.
#'
#' @param repo_dir Character. Directory holding this repository's
#'   copies of the v2 scripts (e.g.
#'   "0_data/v2_scripts/plants").
#' @param root Character. Path to the v2 project root.
#' @param files Character vector. Function file names to compare.
#'   Defaults to the two files the v2 modelling and validation
#'   scripts source.
#' @param v2_dir Character. Directory holding the function files
#'   inside the v2 project, relative to `root`.
#' @return Character vector of the file names that differ,
#'   invisibly. Warns when the vector is non-empty.
#'
#' @example
#' # Example usage of the function
#' check_function_files(
#'   repo_dir = v2_code_dir,
#'   root = v2_root
#' )
check_function_files <- function(
  repo_dir,
  root,
  files = c(
    "hierarchical-model_functions.R",
    "model-validation_functions.R"
  ),
  v2_dir = "1_code/r-scripts"
) {
  # Step 1: Checksum both copies of each file. md5sum() returns NA
  # for a missing file, and NA != x is NA, so guard the comparison
  # rather than letting it drop the file silently.
  repo_sums <- tools::md5sum(file.path(repo_dir, files))
  v2_sums <- tools::md5sum(file.path(root, v2_dir, files))

  # Step 2: Flag every file that differs or could not be read
  differs <- is.na(repo_sums) | is.na(v2_sums) |
    repo_sums != v2_sums
  drifted <- files[differs]

  # Step 3: Warn rather than stop, since a deliberate v2 patch is
  # a legitimate reason to run with different function files
  if (length(drifted) > 0) {
    warning(
      "Function files under ", root, " differ from the copies ",
      "in ", repo_dir, ":\n  ",
      paste(drifted, collapse = "\n  "),
      call. = FALSE
    )
  }

  invisible(drifted)
}

# 5. run_step() ----

#' Run a Pipeline Step
#'
#' Sources a v2 script from `code_dir` with the working directory
#' set to `run_dir`, reporting its label and the time it took to
#' run. Mirrors console output to a timestamped log file so an
#' unattended run leaves a record, and restores the objects named
#' in `protect` after the script clears the global environment.
#'
#' @param label Character. A descriptive label for the step, used
#'   in the console output and in the log file name
#'   (e.g. "02c: Hierarchical models (mites)").
#' @param script Character. The filename of the script to run,
#'   relative to `code_dir`.
#' @param code_dir Character. Absolute path to the directory
#'   holding the v2 scripts.
#' @param run_dir Character. Absolute path to the working
#'   directory the sourced script's own relative paths resolve
#'   against, normally the v2 project root.
#' @param log_dir Character. Directory for log files, or NULL to
#'   print to the console only.
#' @param protect Character vector. Names of global objects to
#'   restore after the script runs, since the v2 scripts open with
#'   rm(list = ls()). Names that do not exist are skipped.
#' @return NULL, invisibly. Output is printed to the console and,
#'   when `log_dir` is set, copied to a log file.
#'
#' @example
#' # Example usage of the function
#' run_step(
#'   label = "02c: Hierarchical models (mites)",
#'   script = "02c_hierarchical-models-mites.R",
#'   code_dir = v2_code_dir,
#'   run_dir = v2_root,
#'   log_dir = log_path,
#'   protect = runner_objects
#' )
#'
#' # Run without writing a log file
#' run_step(
#'   label = "02c: Hierarchical models (mites)",
#'   script = "02c_hierarchical-models-mites.R",
#'   code_dir = v2_code_dir,
#'   run_dir = v2_root,
#'   log_dir = NULL,
#'   protect = runner_objects
#' )
run_step <- function(
  label,
  script,
  code_dir,
  run_dir,
  log_dir = NULL,
  protect = character(0)
) {
  # Step 1: Announce the step and record the start time
  cat("\n--- Running ", label, " ---\n", sep = "")
  start <- Sys.time()

  # Step 2: Snapshot the caller's own objects. The v2 scripts open
  # with rm(list = ls()), which would otherwise delete the flags
  # and helpers partway through the run. Only the named objects
  # are kept, so whatever a script leaves behind is still freed by
  # the next script's cleanup.
  present <- protect[
    vapply(
      protect, exists, logical(1),
      envir = globalenv(), inherits = FALSE
    )
  ]
  keep <- mget(present, envir = globalenv())
  on.exit(list2env(keep, envir = globalenv()), add = TRUE)

  # Step 3: Run from the v2 project root, since the script's paths
  # are relative to that root rather than to this repository
  old_wd <- getwd()
  setwd(run_dir)
  on.exit(setwd(old_wd), add = TRUE)

  # Step 4: Mirror output to a timestamped log. split = TRUE keeps
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

  # Step 5: Source into the global environment, which is where the
  # v2 scripts' clusterExport() calls look for their objects
  source(file.path(code_dir, script))

  # Step 6: Report how long the step took
  elapsed <- format(round(Sys.time() - start, 1))
  cat("Completed ", label, " in ", elapsed, "\n", sep = "")

  invisible(NULL)
}

# End of script ----
