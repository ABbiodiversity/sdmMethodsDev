# ---
# title: The v2 Spec of Every Run
# author: Brendan Casey
# created: 2026-10-03
# inputs: none
# outputs: none; returns objects in memory
# notes:
#   - The runs an experiment can name (`taxa = c("lichen",
#     "bird")`), each in its v2 configuration. Run names are the
#     result folder names. Mammals run once per season (v2's
#     references average summer and winter), both with slug
#     "mammal". A new taxon module adds its run here.
# ---

# 1. Setup ----

## 1.1 Load packages ----
# Base R only.

# 2. standard_specs() ----

#' Every Run's Spec, in Its v2 Configuration
#'
#' @param plant_bootstrap Character. "spatial_block" draws v2's
#'   plant bootstrap afresh, so parity is distributional;
#'   "v2_ids" replays the draws v2 stored (needs
#'   _setup/05_harmonize_v2_plant_bootstrap_ids.R run for every
#'   species in the run).
#' @return A named list of specs, one per run.
#'
#' @example # Example usage of the function
#' # names(standard_specs())
standard_specs <- function(plant_bootstrap = "spatial_block") {
  list(
    bryophyte = bryophyte_spec(bootstrap = plant_bootstrap),
    lichen = lichen_spec(bootstrap = plant_bootstrap),
    mite = soil_mite_spec(bootstrap = plant_bootstrap),
    vascular_plant = vascular_plant_spec(bootstrap = plant_bootstrap),
    mammal_summer = mammal_spec(season = "summer"),
    mammal_winter = mammal_spec(season = "winter"),
    bird = bird_spec()
  )
}

# End of script ----
