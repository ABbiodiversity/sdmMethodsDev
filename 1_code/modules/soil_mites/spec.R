# ---
# title: Soil Mite Taxon Spec
# author: Brendan Casey
# created: 2026-09-10
# inputs:
#   - 1_code/modules/_shared/plant_group.R
# outputs: none; returns objects in memory
# notes:
#   - Data slug: "mite", not "soil_mite"; it keys the harmonized
#     data, so pass "mite" wherever a taxon is named.
#   - Animals, but fitted with the plant scripts on the plant
#     survey design, as in v2.
#   - v2 does not fit Protocol for this taxon (bryophytes and
#     lichens only); `use_protocol` can equalize it across taxa.
# ---

# 1. Setup ----

## 1.1 Load packages ----
# Base R only; the harness supplies everything else.

# 2. soil_mite_spec() ----

#' Build the v2 Spec for Soil Mites
#'
#' @param use_protocol Logical, or NULL to take the v2 value,
#'   which is FALSE for this taxon.
#' @param bootstrap Character. "spatial_block" or "v2_ids"; see
#'   plant_group_spec().
#' @return A spec list, as run_spec() consumes. Its `taxon` field
#'   is "mite".
#'
#' @example # Example usage of the function
#' # spec <- soil_mite_spec()
#' # spec$taxon # "mite"
soil_mite_spec <- function(use_protocol = NULL,
                           bootstrap = "spatial_block") {
  plant_group_spec(
    taxon = "mite",
    protocol_in_v2 = FALSE,
    use_protocol = use_protocol,
    bootstrap = bootstrap
  )
}

# End of script ----
