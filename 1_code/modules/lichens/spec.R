# ---
# title: Lichen Taxon Spec
# author: Brendan Casey
# created: 2026-09-10
# inputs:
#   - 1_code/modules/_shared/plant_group.R
# outputs: none; returns objects in memory
# notes:
#   - Data slug: "lichen". Response file lichen.csv.
#   - v2 fits Protocol for this taxon (bryophytes and lichens
#     only); `use_protocol` can equalize it across taxa.
#   - The v2 reference is the published file on ABMI-DATA2 and is
#     intact, unlike the bryophyte one.
# ---

# 1. Setup ----

## 1.1 Load packages ----
# Base R only; the harness supplies everything else.

# 2. lichen_spec() ----

#' Build the v2 Spec for Lichens
#'
#' @param use_protocol Logical, or NULL to take the v2 value,
#'   which is TRUE for this taxon.
#' @param bootstrap Character. "spatial_block" or "v2_ids"; see
#'   plant_group_spec().
#' @return A spec list, as run_spec() consumes.
#'
#' @example # Example usage of the function
#' # spec <- lichen_spec()
#' # spec$use_protocol # TRUE
lichen_spec <- function(use_protocol = NULL,
                        bootstrap = "spatial_block") {
  plant_group_spec(
    taxon = "lichen",
    protocol_in_v2 = TRUE,
    use_protocol = use_protocol,
    bootstrap = bootstrap
  )
}

# End of script ----
