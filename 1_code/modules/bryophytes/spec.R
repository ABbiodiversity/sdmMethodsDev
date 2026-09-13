# ---
# title: Bryophyte Taxon Spec
# author: Brendan Casey
# created: 2026-09-10
# inputs:
#   - 1_code/modules/_shared/plant_group.R
# outputs: none; returns objects in memory
# notes:
#   - Data slug: "bryophyte". Response file bryophyte.csv.
#   - v2 fits Protocol for this taxon. Only bryophytes and
#     lichens get it; soil mites and vascular plants do not. The
#     asymmetry is v2's and is preserved here for parity, with
#     `use_protocol` exposed so an experiment can equalize it.
#   - Bryophytes are the one plant-group taxon whose v2 reference
#     had to be regenerated. The published file is unusable twice
#     over: every species and draw in it is an error object
#     reading `could not find function "model.avg"`, and the
#     bootstrap-id file held 3 draws where the other three taxa
#     hold 100. 03_rerun_bryophyte_v2_reference.R rebuilt both,
#     writing to 2_pipeline/v2_reference/ rather than over the
#     network copy. The gate searches there first.
#   - The regenerated reference covers the climate stage only, so
#     bryophyte habitat terms are still uncompared.
#   - Anything true of every plant-group taxon belongs in
#     _shared/plant_group.R, not here.
# ---

# 1. Setup ----

## 1.1 Load packages ----
# Base R only; the harness supplies everything else.

# 2. bryophyte_spec() ----

#' Build the v2 Spec for Bryophytes
#'
#' @param use_protocol Logical, or NULL to take the v2 value,
#'   which is TRUE for this taxon.
#' @return A spec list, as run_spec() consumes.
#'
#' @example # Example usage of the function
#' # spec <- bryophyte_spec()
#' # spec$use_protocol # TRUE
bryophyte_spec <- function(use_protocol = NULL) {
  plant_group_spec(
    taxon = "bryophyte",
    protocol_in_v2 = TRUE,
    use_protocol = use_protocol,
    reference_note = paste0(
      "The v2 reference for this taxon is regenerated, not ",
      "published, and covers the climate stage only."
    )
  )
}

# End of script ----
