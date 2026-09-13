# ---
# title: Lichen Taxon Spec
# author: Brendan Casey
# created: 2026-09-10
# inputs:
#   - 1_code/modules/_shared/plant_group.R
# outputs: none; returns objects in memory
# notes:
#   - Data slug: "lichen". Response file lichen.csv.
#   - v2 fits Protocol for this taxon. Only bryophytes and
#     lichens get it; soil mites and vascular plants do not. The
#     asymmetry is v2's and is preserved here for parity, with
#     `use_protocol` exposed so an experiment can equalize it.
#   - The v2 reference is the published file on ABMI-DATA2 and is
#     intact, unlike the bryophyte one.
#   - Anything true of every plant-group taxon belongs in
#     _shared/plant_group.R, not here.
# ---

# 1. Setup ----

## 1.1 Load packages ----
# Base R only; the harness supplies everything else.

# 2. lichen_spec() ----

#' Build the v2 Spec for Lichens
#'
#' @param use_protocol Logical, or NULL to take the v2 value,
#'   which is TRUE for this taxon.
#' @return A spec list, as run_spec() consumes.
#'
#' @example # Example usage of the function
#' # spec <- lichen_spec()
#' # spec$use_protocol # TRUE
lichen_spec <- function(use_protocol = NULL) {
  plant_group_spec(
    taxon = "lichen",
    protocol_in_v2 = TRUE,
    use_protocol = use_protocol
  )
}

# End of script ----
