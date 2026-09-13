# ---
# title: Soil Mite Taxon Spec
# author: Brendan Casey
# created: 2026-09-10
# inputs:
#   - 1_code/modules/_shared/plant_group.R
# outputs: none; returns objects in memory
# notes:
#   - Data slug: "mite", not "soil_mite". The directory is named
#     for the taxon; the slug is the key the response file, the
#     species catalogue and the covariate catalogue all use, and
#     renaming it would mean renaming harmonized data. Use "mite"
#     wherever a taxon is passed to the harness, including in
#     focal_species and run_taxa.
#   - Soil mites are animals. They sit with the plant group
#     because v2 fits them with the plant scripts, on the plant
#     survey design, and the harness follows v2.
#   - v2 does not fit Protocol for this taxon, passing the flag
#     as FALSE. Only bryophytes and lichens get it. The asymmetry
#     is v2's and is preserved here for parity, with
#     `use_protocol` exposed so an experiment can equalize it.
#   - The habitat model sets the shared builder uses are spliced
#     from this taxon's v2 script, which is why they carry no
#     Protocol term until one is inserted.
#   - Anything true of every plant-group taxon belongs in
#     _shared/plant_group.R, not here.
# ---

# 1. Setup ----

## 1.1 Load packages ----
# Base R only; the harness supplies everything else.

# 2. soil_mite_spec() ----

#' Build the v2 Spec for Soil Mites
#'
#' @param use_protocol Logical, or NULL to take the v2 value,
#'   which is FALSE for this taxon.
#' @return A spec list, as run_spec() consumes. Its `taxon` field
#'   is "mite".
#'
#' @example # Example usage of the function
#' # spec <- soil_mite_spec()
#' # spec$taxon # "mite"
soil_mite_spec <- function(use_protocol = NULL) {
  plant_group_spec(
    taxon = "mite",
    protocol_in_v2 = FALSE,
    use_protocol = use_protocol
  )
}

# End of script ----
