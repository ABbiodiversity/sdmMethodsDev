# ---
# title: The v2 Spec of Every Run
# author: Brendan Casey
# created: 2026-10-03
# inputs: none
# outputs: none; returns objects in memory
# notes:
#   - One place that lists the runs an experiment can choose
#     between, each a taxon spec in its v2 configuration. An
#     experiment names runs (`taxa = c("lichen", "bird")`) rather
#     than building specs, so its run.R stays short and every
#     experiment starts from the same v2 configuration.
#   - Run names are the folder names results are written under.
#     Mammals run once per season, because v2's mammal references
#     average the summer and winter fits; the two runs share the
#     data slug "mammal". Soil mites run as "mite", their slug.
#   - A new taxon module adds its run here.
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
#'   _setup/07_harmonize_v2_plant_bootstrap_ids.R run for every
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
