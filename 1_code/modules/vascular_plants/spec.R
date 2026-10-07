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
#   - The most species of the four, so the slowest to run.
#   - v2 does not fit Protocol for this taxon (bryophytes and
#     lichens only); `use_protocol` can equalize it across taxa.
# ---

# 1. Setup ----

## 1.1 Load packages ----
# Base R only; the harness supplies everything else.

# 2. vascular_plant_spec() ----

#' Build the v2 Spec for Vascular Plants
#'
#' @param use_protocol Logical, or NULL to take the v2 value,
#'   which is FALSE for this taxon.
#' @param bootstrap Character. "spatial_block" or "v2_ids"; see
#'   plant_group_spec().
#' @return A spec list, as run_spec() consumes.
#'
#' @example # Example usage of the function
#' # spec <- vascular_plant_spec()
#' # spec$use_protocol # FALSE
vascular_plant_spec <- function(use_protocol = NULL,
                                bootstrap = "spatial_block") {
  plant_group_spec(
    taxon = "vascular_plant",
    protocol_in_v2 = FALSE,
    use_protocol = use_protocol,
    bootstrap = bootstrap
  )
}

# End of script ----
