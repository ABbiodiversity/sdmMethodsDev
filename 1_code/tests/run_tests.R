# ---
# title: Run the Framework's Tests
# author: Brendan Casey
# created: 2026-10-03
# inputs:
#   - 1_code/tests/testthat/test-*.R
#   - the published test dataset (see harness/data_source.R),
#     for the dataset checks; skipped when it cannot be reached
# outputs: none; prints a pass / fail summary
# notes:
#   - Fast checks of the contracts the framework relies on: every
#     engine meets the engine contract, every v2 spec validates,
#     the harmonized lookups are consistent, shards merge in
#     order, and seeds reproduce. They take seconds, so run them
#     after any change to harness/, methods/ or modules/.
#   - They do not replace the parity check. A change meant to
#     leave results alone is confirmed by running the parity
#     species at 5 draws and comparing the stores with
#     1_code/tests/compare_stores.R; see docs/getting_started.md.
#   - Run from the repository root:
#       Rscript 1_code/tests/run_tests.R
# ---

# 1. Setup ----

## 1.1 Load packages ----
library(testthat) # test runner (version: 3.3.2)

## 1.2 Load the framework ----
source("1_code/harness/harness.R")
load_framework()

# Unchecked, so an unreachable share skips the dataset checks
# rather than stopping the rest
data_dir <- test_dataset_dir(check = FALSE)

# 2. Run ----
results <- testthat::test_dir(
  "1_code/tests/testthat",
  env = environment(),
  reporter = "summary",
  stop_on_failure = TRUE
)

# End of script ----
