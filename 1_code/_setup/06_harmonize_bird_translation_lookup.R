# ---
# title: Harmonize the v2 Bird Coefficient Translation Lookup
# author: Brendan Casey
# created: 2026-09-29
# inputs:
#   Read via setup_input() (utils/input_paths.R); the original
#   locations are listed, and SDM_* variables can point back.
#   in the BirdModels project (SDM_V2_BIRD_ROOT):
#     - Data/lookups/Xn-veg-v2024.Rdata
# outputs:
#   in 0_data/test_dataset/lookup/:
#     - bird_veg_age_matrix.csv
# notes:
#   - v2's 08.PackageCoefficients.R translates raw bird landcover
#     coefficients onto the standardized habitat types by the
#     `age` matrix (one row per type, one column per raw term:
#     a pure stand's design values, age terms integrated over each
#     class). modules/birds/standardize.R needs it.
#   - Separate from 01 (hours to re-run), but re-run it whenever
#     01 rebuilds lookup/.
#   - Written as read: raw glm column names, interactions sorted
#     (isCon:wtAge), as v2 matches them.
# ---

# 1. Setup ----

## 1.1 Load packages ----
library(data.table) # CSV writing (version: 1.16.4)

## 1.2 Resolve paths ----
project_root <- normalizePath(getwd(), winslash = "/")

# The _setup inputs mirrored on ABMI-DATA2 (setup_input())
source(file.path(project_root, "1_code/_setup/utils/input_paths.R"))

v2_bird_root <- Sys.getenv(
  "SDM_V2_BIRD_ROOT",
  unset = setup_input("bird_models")
)

source_path <- file.path(
  v2_bird_root, "Data", "lookups", "Xn-veg-v2024.Rdata"
)

out_path <- file.path(
  project_root, "0_data", "test_dataset", "lookup",
  "bird_veg_age_matrix.csv"
)

if (!file.exists(source_path)) {
  stop(
    "Bird age lookup not found:\n  ", source_path,
    "\nSet SDM_V2_BIRD_ROOT to the BirdModels project.",
    call. = FALSE
  )
}

# 2. Read and check ----
source_env <- new.env()
load(source_path, envir = source_env)

if (!exists("age", envir = source_env, inherits = FALSE)) {
  stop("Xn-veg-v2024.Rdata holds no `age` object.", call. = FALSE)
}

age <- source_env$age

if (!is.matrix(age) || is.null(rownames(age)) ||
      is.null(colnames(age))) {
  stop("`age` must be a matrix with row and column names.",
       call. = FALSE)
}

if (anyNA(age)) {
  stop("`age` holds missing values.", call. = FALSE)
}

# 3. Write ----
# One row per standardized habitat type, in v2's order.
out <- data.table(type = rownames(age), as.data.table(age))

fwrite(out, out_path)

cat(
  "Wrote ", out_path, ": ", nrow(age), " habitat types by ",
  ncol(age), " raw terms\n",
  sep = ""
)

# End of script ----
