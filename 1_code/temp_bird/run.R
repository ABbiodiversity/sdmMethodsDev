# ---
# title: Run the Old vs New Bird Comparison
# author: Brendan Casey
# created: 2026-10-15
# inputs: see 01_build_old_dataset.R, 02_fit_old_new.R,
#   03_read_v2_landcover.R, 04_plot_old_new_target.R,
#   05_correlate.R and 06_compare_draws.R
# outputs:
#   - 2_pipeline/temp_bird/, the old dataset copy and both fits
#   - 3_output/temp_bird/figures/ and tables/
# notes:
#   - Runs the six scripts in order, from the repository root.
#   - Each script is sourced into the global environment, as if
#     run by hand: 02 loads the framework there, where its
#     parallel workers and registries expect it. The scripts
#     share nothing but files.
#   - Set a step to FALSE to skip it: the old dataset copy and
#     v2's landcover draws only need reading once, and the plot
#     can be redrawn without refitting.
# ---

# 1. Setup ----

## 1.1 Set the working directory ----
# Every path is relative to the repository root. In RStudio or
# Positron, uncomment to set it from this script's location.
# setwd(dirname(rstudioapi::getActiveDocumentContext()$path))
# setwd("../..")

if (!dir.exists("1_code/temp_bird")) {
  stop("Run from the repository root.", call. = FALSE)
}

## 1.2 Choose the steps ----
steps <- c(
  "01_build_old_dataset.R" = TRUE,
  "02_fit_old_new.R" = TRUE,
  "03_read_v2_landcover.R" = TRUE,
  "04_plot_old_new_target.R" = TRUE,
  "05_correlate.R" = TRUE,
  "06_compare_draws.R" = TRUE
)

# 2. Run ----
started <- Sys.time()

for (script in names(steps)[steps]) {
  cat("\n==== ", script, " ====\n", sep = "")
  step_started <- Sys.time()

  source(file.path("1_code/temp_bird", script), local = FALSE)

  cat("---- ", script, " done in ",
      format(round(Sys.time() - step_started, 1)), "\n", sep = "")
}

cat("\nAll steps done in ", format(round(Sys.time() - started, 1)),
    "\nFigures: 3_output/temp_bird/figures/\n", sep = "")

# End of script ----
