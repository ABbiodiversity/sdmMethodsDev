# ---
# title: Rebuild the Test Dataset and v2 Reference
# author: Brendan Casey
# created: 2026-10-05
# inputs:
#   - the _setup/ scripts in this folder, and whatever each reads
#     (see their headers); most read the input mirror on
#     ABMI-DATA2 through utils/input_paths.R
# outputs:
#   - 0_data/test_dataset/, from 01, 06 and 09
#   - 0_data/test_dataset/lookup/v2_bootstrap_ids/, from 07
#   - 0_data/v2_results/abmiexplorer/, from 08
#   - 2_pipeline/v2_reference/, from 03
#   - a new published version on ABMI-DATA2, from 10, only if
#     switched on
#   - 2_pipeline/_setup/run_log.csv: per step, start, end,
#     minutes and whether it finished
# notes:
#   - Runs the _setup/ scripts in their dependency order, for a
#     manual rebuild. Switch steps on or off in section 1.2; the
#     defaults rebuild everything local and publish nothing.
#   - Off by default:
#     - 00 mirrors the inputs onto ABMI-DATA2. Run once, by
#       someone who can reach the original drives.
#     - 03 re-runs the v2 bryophyte models: hours, and its
#       output only changes if its sources do.
#     - 10 publishes a new version. Run it deliberately, after
#       checking 02's tally, then move the pin in
#       1_code/harness/data_source.R.
#   - Each script runs in its own environment; an error stops
#     the rebuild and is logged.
#   - 02 prints a pass / fail tally rather than stopping; read it
#     before using or publishing.
#   - Section 3 prints how to point experiments at this rebuild.
#   - Run from the repository root.
# ---

# 1. Setup ----

## 1.1 Load packages ----
# Base R only; each script loads its own.

## 1.2 Choose the steps ----
# In run order: 09 reads 01's and 06's lookups, 02 checks the
# finished dataset, 07 reads 03's bryophyte draws.
steps <- c(
  "00_mirror_setup_inputs.R" = FALSE,
  "01_harmonize_model_ready_v2.R" = TRUE,
  "06_harmonize_bird_translation_lookup.R" = TRUE,
  "09_harmonize_lookups.R" = TRUE,
  "02_validate_test_dataset.R" = TRUE,
  "03_rerun_bryophyte_v2_reference.R" = FALSE,
  "07_harmonize_v2_plant_bootstrap_ids.R" = TRUE,
  "08_harmonize_abmiexplorer_results.R" = TRUE,
  "10_publish_datasets.R" = FALSE
)

## 1.3 Check the paths ----
setup_dir <- "1_code/_setup"

if (!dir.exists(setup_dir)) {
  stop(
    "Run from the repository root; ",
    setup_dir,
    " not found.",
    call. = FALSE
  )
}

found <- file.exists(file.path(setup_dir, names(steps)))
missing <- names(steps)[!found]

if (length(missing) > 0) {
  stop(
    "Not found in ",
    setup_dir,
    ":\n  ",
    paste(missing, collapse = "\n  "),
    call. = FALSE
  )
}

log_dir <- "2_pipeline/_setup"
dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)
log_path <- file.path(log_dir, "run_log.csv")

# 2. Run the steps ----

## 2.1 run_step() ----

#' Source One _setup Script in an Environment of Its Own
#'
#' @param script Character. File name inside `setup_dir`.
#' @param setup_dir Character. The _setup folder.
#' @param log_path Character. The run log to append to.
#' @return TRUE, invisibly; stops if the script errors.
#'
#' @example # Example usage of the function
#' # run_step("09_harmonize_lookups.R", setup_dir, log_path)
run_step <- function(script, setup_dir, log_path) {
  # Step 1: Announce and time the step
  message("\n== ", script, " (", format(Sys.time(), "%H:%M"), ")")
  started <- Sys.time()

  # Step 2: Source it in isolation, keeping any error
  error <- tryCatch(
    {
      source(
        file.path(setup_dir, script),
        local = new.env(parent = globalenv())
      )
      NULL
    },
    error = function(e) e
  )

  # Step 3: Log the outcome before stopping on an error
  ended <- Sys.time()
  row <- data.frame(
    script = script,
    started = format(started, "%Y-%m-%d %H:%M:%S"),
    ended = format(ended, "%Y-%m-%d %H:%M:%S"),
    minutes = round(
      as.numeric(difftime(ended, started, units = "mins")),
      1
    ),
    status = if (is.null(error)) "done" else "failed"
  )

  write.table(
    row,
    log_path,
    sep = ",",
    row.names = FALSE,
    col.names = !file.exists(log_path),
    append = file.exists(log_path)
  )

  if (!is.null(error)) {
    stop(script, " failed: ", conditionMessage(error), call. = FALSE)
  }

  message("   done in ", row$minutes, " min")
  invisible(TRUE)
}

## 2.2 Run the chosen steps in order ----
to_run <- names(steps)[steps]
message("Rebuilding: ", paste(to_run, collapse = ", "))

for (script in to_run) {
  run_step(script, setup_dir, log_path)
}

# 3. Point experiments at the rebuild ----
# The published copies are what experiments read by default.
message(
  "\nRebuild finished. To run an experiment against it:\n",
  "  Sys.setenv(SDM_TEST_DATASET = \"0_data/test_dataset\")\n",
  "  Sys.setenv(SDM_V2_RESULTS = \"0_data/v2_results\")\n",
  "Run log: ",
  log_path
)

# End of script ----
