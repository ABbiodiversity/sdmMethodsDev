# ---
# title: Bryophyte Taxon Spec
# author: Brendan Casey
# created: 2026-09-10
# inputs:
#   - 1_code/modules/_shared/plant_group.R
# outputs: none; returns objects in memory
# notes:
#   - Data slug: "bryophyte". Response file bryophyte.csv.
#   - v2 fits Protocol for this taxon (bryophytes and lichens
#     only); `use_protocol` can equalize it across taxa.
#   - The published bryophyte model file is unusable (every entry
#     is a `could not find function "model.avg"` error; 3 stored
#     draws, not 100). The parity reference is ABMIexploreR's
#     arrays (_setup/06), matching v2's COEFS.RData to ~1e-15.
#     _setup/03 regenerated the climate stage into
#     2_pipeline/v2_reference/ for v2_self_agreement.R.
# ---

# 1. Setup ----

## 1.1 Load packages ----
# Base R only; the harness supplies everything else.

# 2. bryophyte_spec() ----

#' Build the v2 Spec for Bryophytes
#'
#' @param use_protocol Logical, or NULL to take the v2 value,
#'   which is TRUE for this taxon.
#' @param bootstrap Character. "spatial_block" or "v2_ids"; see
#'   plant_group_spec().
#' @return A spec list, as run_spec() consumes.
#'
#' @example # Example usage of the function
#' # spec <- bryophyte_spec()
#' # spec$use_protocol # TRUE
bryophyte_spec <- function(use_protocol = NULL,
                           bootstrap = "spatial_block") {
  plant_group_spec(
    taxon = "bryophyte",
    protocol_in_v2 = TRUE,
    use_protocol = use_protocol,
    bootstrap = bootstrap,
    reference_note = paste0(
      "The published v2 model file is unusable; the v2 ",
      "reference is ABMIexploreR's, via v2_results.csv."
    )
  )
}

# End of script ----
