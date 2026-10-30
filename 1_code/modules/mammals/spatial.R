# ---
# title: Mammal Spatial Prediction Settings
# author: Brendan Casey; settings from Marcus Becker's v2 script
# created: 2026-10-27
# inputs: none
# outputs: none; returns objects in memory
# notes:
#   - The mammal part of v2's map rule
#     (make-species-predictions.R), read by the harness predict
#     step (harness/predict_spatial.R). The class renames of
#     make-species-predictions.R:184-218 are in
#     spatial_classes.csv beside this file.
#   - v2 maps total abundance: TA_v x Pr(present | climate,
#     pAspen, v) / PA_v, with the south's pAspen effect on
#     abundance too. The harness's "mammal_hurdle" combine.
#   - Seasons are averaged draw by draw, as v2 averages its
#     `.all` tables, so the two season runs make one map per
#     species.
# ---

# 1. Setup ----

## 1.1 Load packages ----
# Base R only; the harness supplies everything else.

# 2. mammal_spatial() ----

#' The Mammal Spec's `spatial` Settings
#'
#' @return A list, as harness/predict_spatial.R reads it.
#'
#' @example # Example usage of the function
#' # mammal_spatial()$combine
mammal_spatial <- function() {
  list(
    # The climate stage is a binomial GLM
    link = "logit",
    climate_stage = "climate",
    # make-species-predictions.R:509-512
    climate_cap = 0.99,
    combine = "mammal_hurdle",
    # The hurdle's three tables (hurdle.R)
    habitat_stages = c(
      presence = "habitat_presence",
      total = "habitat_total",
      abundance = "habitat_abundance"
    ),
    climate_term = "Climate",
    # South only (make-species-predictions.R:581-583)
    aspen = list(south = "pAspen"),
    class_map = "1_code/modules/mammals/spatial_classes.csv",
    # A species in one region keeps that region's prediction,
    # NA where its weight is zero (628-637)
    single_region = "na",
    # 644-647
    final_cap = 0.999,
    season_average = TRUE
  )
}

# End of script ----
