# ---
# title: Vascular Plant Taxon Spec
# author: Brendan Casey
# created: 2026-09-10
# inputs:
#   - 1_code/modules/_shared/plant_group.R
# outputs: none; returns objects in memory
# notes:
#   - Data slug: "vascular_plant". Response file
#     vascular_plant.csv. v2 names this taxon with a hyphen in
#     its file names, which the parity gate translates.
#   - The largest plant-group taxon by species count, so it is
#     usually the slowest of the four to run and the one worth
#     restricting with focal_species during a smoke test.
#   - v2 does not fit Protocol for this taxon, passing the flag
#     as FALSE. Only bryophytes and lichens get it. The asymmetry
#     is v2's and is preserved here for parity, with
#     `use_protocol` exposed so an experiment can equalize it.
#   - Anything true of every plant-group taxon belongs in
#     _shared/plant_group.R, not here.
# ---

# 1. Setup ----

## 1.1 Load packages ----
# Base R only; the harness supplies everything else.

# 2. vascular_plant_spec() ----

#' Build the v2 Spec for Vascular Plants
#'
#' @param use_protocol Logical, or NULL to take the v2 value,
#'   which is FALSE for this taxon.
#' @return A spec list, as run_spec() consumes.
#'
#' @example # Example usage of the function
#' # spec <- vascular_plant_spec()
#' # spec$use_protocol # FALSE
vascular_plant_spec <- function(use_protocol = NULL) {
  plant_group_spec(
    taxon = "vascular_plant",
    protocol_in_v2 = FALSE,
    use_protocol = use_protocol
  )
}

# End of script ----
