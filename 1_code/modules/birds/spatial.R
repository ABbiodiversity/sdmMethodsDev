# ---
# title: Bird Spatial Prediction Settings
# author: Brendan Casey; settings from Elly Knight's v2 scripts
# created: 2026-10-27
# inputs: none
# outputs: none; returns objects in memory
# notes:
#   - The bird part of v2's map rule (09.Predict.R), read by the
#     harness predict step (harness/predict_spatial.R). The class
#     renames and means of 09.Predict.R:76-115 are in
#     spatial_classes.csv beside this file.
#   - v2 caps each bird map at its own quantile, `PlotQuantile`
#     (08.PackageCoefficients.R:735-755): 0.995 by default, 0.990
#     or 0.999 for the species listed there. Ported as written.
#     TODO: confirm with bird lead.
# ---

# 1. Setup ----

## 1.1 Load packages ----
# Base R only; the harness supplies everything else.

# 2. bird_plot_quantiles() ----

#' v2's Per-Species Final Cap Quantiles for Bird Maps
#'
#' @return A named numeric vector: the listed species, and
#'   `default` for every other species.
#'
#' @example # Example usage of the function
#' # bird_plot_quantiles()[["NOFL"]] # 0.99
bird_plot_quantiles <- function() {
  # 08.PackageCoefficients.R:735-736
  q990 <- c(
    "NOFL", "BTNW", "BLPW", "CEDW", "CMWA", "COGR", "EAPH", "HOSP",
    "PUFI", "SOSP", "WBNU", "YHBL", "YRWA"
  )
  q999 <- c("BLBW", "MOCH", "WCSP")

  c(
    default = 0.995,
    stats::setNames(rep(0.990, length(q990)), q990),
    stats::setNames(rep(0.999, length(q999)), q999)
  )
}

# 3. bird_spatial() ----

#' The Bird Spec's `spatial` Settings
#'
#' @return A list, as harness/predict_spatial.R reads it.
#'
#' @example # Example usage of the function
#' # bird_spatial()$final_cap[["default"]]
bird_spatial <- function() {
  list(
    # log link, with v2's bounded inv.link (09.Predict.R:30)
    link = "log",
    climate_stage = "climate",
    # 09.Predict.R:156-157
    climate_cap = 0.99,
    combine = "mixture",
    # The landcover stage on v2's standardized template, as the
    # parity gate reads it (standardize.R)
    habitat_stages = "habitat",
    habitat_coefficients = bird_habitat_translation,
    climate_term = "Climate",
    # South only (09.Predict.R:198-210)
    aspen = list(south = "pAspen"),
    class_map = "1_code/modules/birds/spatial_classes.csv",
    # A region the species is not modelled in is zero
    # (09.Predict.R:182, 218)
    single_region = "zero",
    # 09.Predict.R:230-231
    infinite_to_median = TRUE,
    final_cap = bird_plot_quantiles()
  )
}

# End of script ----
