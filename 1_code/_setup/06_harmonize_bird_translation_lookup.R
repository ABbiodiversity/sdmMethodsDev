# ---
# title: Harmonize the v2 Bird Coefficient Translation Lookup
# author: Brendan Casey
# created: 2026-09-29
# inputs:
#   in the BirdModels project (SDM_V2_BIRD_ROOT):
#     - Data/lookups/Xn-veg-v2024.Rdata
# outputs:
#   in 0_data/test_dataset/lookup/:
#     - bird_veg_age_matrix.csv
# notes:
#   - v2 does not report raw bird landcover coefficients. Its
#     08.PackageCoefficients.R translates them onto the
#     standardized cross-taxa habitat types - WhiteSpruceR to
#     WhiteSpruce8 and the rest - by multiplying them by the
#     `age` matrix in Xn-veg-v2024.Rdata: one row per standardized
#     type, one column per raw model term, holding the design
#     values of a pure stand of that type, with the age terms
#     integrated over each age class.
#   - The harness translates bird coefficients the same way, in
#     1_code/modules/birds/standardize.R, so it needs this matrix.
#     Copying it here keeps experiments runnable from
#     0_data/test_dataset/ alone.
#   - A separate script rather than a section of
#     01_harmonize_model_ready_v2.R, because it reads one small
#     file from a different source and 01 takes hours to re-run.
#     It writes into test_dataset/lookup/ all the same; re-run it
#     whenever 01 rebuilds that folder.
#   - The matrix is written as read. Column names are the raw
#     glm names v2 used, with interaction terms sorted
#     (isCon:wtAge, not wtAge:isCon), which is how v2 matches
#     them.
# ---

# 1. Setup ----

## 1.1 Load packages ----
library(data.table) # CSV writing (version: 1.16.4)

## 1.2 Resolve paths ----
project_root <- normalizePath(getwd(), winslash = "/")

v2_bird_root <- Sys.getenv(
  "SDM_V2_BIRD_ROOT",
  unset = paste0(
    "G:/.shortcut-targets-by-id/",
    "17Ymt13eHfKvIiuoMl6x-Kn74Z2uVbbzS/BirdModels"
  )
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
