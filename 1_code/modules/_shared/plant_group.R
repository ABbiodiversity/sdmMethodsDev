# ---
# title: Shared Builder for the Plant-Group Taxon Specs
# author: Brendan Casey
# created: 2026-09-10
# inputs: none
# outputs: none; returns objects in memory
# notes:
#   - Bryophytes, lichens, soil mites and vascular plants each
#     have their own module directory, because each is free to
#     diverge and a taxon-specific quirk should have one obvious
#     home. What they still share is the v2 pipeline shape, and
#     that lives here so four copies cannot drift apart.
#   - "Plant group" names a survey design rather than a taxonomy.
#     Soil mites are animals; they are here because v2 fits them
#     with the plant scripts, on the plant survey design.
#   - Each taxon module states its own facts and calls this
#     builder. Nothing in here looks a taxon up in a table, so
#     adding a quirk means editing that taxon's file rather than
#     adding a branch to a shared one.
#   - The underscore prefix marks this as shared machinery rather
#     than a taxon, matching _setup/ and _deprecated/.
#   - Parity coverage is the climate stage plus the habitat stage
#     less its age splines. See docs/taxon_quirks.md.
# ---

# 1. Setup ----

## 1.1 Load packages ----
# Base R only; the harness supplies everything else.

# 2. plant_group_spec() ----

#' Build a v2 Spec for One Plant-Group Taxon
#'
#' The v2 pipeline shape shared by bryophytes, lichens, soil
#' mites and vascular plants. Called by each taxon module rather
#' than directly.
#'
#' @param taxon Character. The data slug, which keys the response
#'   file, the species catalogue and the covariate catalogue.
#'   Note that soil mites carry the slug "mite".
#' @param protocol_in_v2 Logical. Whether v2 fits Protocol for
#'   this taxon. Recorded so a run can say whether it followed v2
#'   or overrode it.
#' @param use_protocol Logical, or NULL to take the v2 value.
#'   Setting it equalizes a term v2 applies inconsistently, which
#'   is what a cross-taxa experiment wants.
#' @param reference_note Character, or NULL. One clause on where
#'   this taxon's v2 reference comes from, appended to the spec
#'   notes. Bryophytes differ from the other three.
#' @return A spec list, as run_spec() consumes.
#'
#' @example # Example usage of the function
#' # spec <- plant_group_spec("lichen", protocol_in_v2 = TRUE)
#' # spec$stages[[1]]$engine
plant_group_spec <- function(
  taxon,
  protocol_in_v2,
  use_protocol = NULL,
  reference_note = NULL
) {
  if (!is.character(taxon) || length(taxon) != 1L) {
    stop("`taxon` must be a single character slug.", call. = FALSE)
  }

  if (!is.logical(protocol_in_v2) ||
        length(protocol_in_v2) != 1L ||
        is.na(protocol_in_v2)) {
    stop(
      "`protocol_in_v2` must be TRUE or FALSE.",
      call. = FALSE
    )
  }

  if (is.null(use_protocol)) {
    use_protocol <- protocol_in_v2
  }

  # The habitat sets are spliced from the mite script, which
  # fits no Protocol. In the bryophyte and lichen scripts the
  # same formulas carry the term directly after Climate and
  # nowhere else, so inserting it there reproduces them. The
  # climate set carries no Protocol in any variant.
  with_protocol <- function(set) {
    models <- get_model_set(set)

    if (!use_protocol) {
      return(models)
    }

    sub(
      ". ~ . + Climate", ". ~ . + Climate + Protocol",
      models, fixed = TRUE
    )
  }

  list(
    taxon = taxon,
    response_name = "response",

    # Plant-group responses are cover or abundance values; v2
    # models presence, so anything above zero is a detection.
    response_transform = "detection",
    family = "binomial",
    weight_column = NULL,
    tier = NULL,

    regions = list(
      north = list(
        filter = ~ nr != "Grassland",
        grid = "veg",
        term_block = "veg",
        habitat_models = with_protocol("habitat_veg_plant_v2")
      ),
      south = list(
        filter = ~ nr %in% c("Grassland", "Parkland"),
        grid = "soil",
        term_block = "soil",
        habitat_models = with_protocol("habitat_soil_plant_v2")
      )
    ),

    stages = list(
      list(
        name = "climate",
        models = "climate_plant_v2_full",
        engine = "bayesglm",
        selection = "aic_average",
        ic = "AICc",
        control = list(maxit = 250),
        # The habitat stage takes this stage's prediction as a
        # term called Climate, which is how v2 composes them.
        carry_as = "Climate"
      ),
      list(
        name = "habitat",
        # Set per region below, because north fits vegetation
        # types and south fits soil types.
        models = NULL,
        engine = "bayesglm",
        selection = "ivw_grid",
        ic = "AICc",
        control = list(maxit = 250),
        carry_from = "climate",
        carry_from_as = "Climate",
        # v2 predicts each candidate onto the grid holding
        # Climate at zero, and at the new protocol where Protocol
        # is fitted, so the habitat effects are read at an
        # average climate under one protocol.
        grid_constants = if (use_protocol) {
          list(
            Climate = 0,
            Protocol = factor("New", levels = c("New", "Old"))
          )
        } else {
          list(Climate = 0)
        },
        head_terms = if (use_protocol) {
          c("Intercept", "Climate", "Protocol")
        } else {
          c("Intercept", "Climate")
        },
        coef_adjust = TRUE
      )
    ),

    resample = list(
      scheme = "spatial_block",
      min_detections = 20L,
      seed = NULL
    ),

    # The habitat stage runs, but not all of it: v2 overwrites 45
    # of the 87 vegetation effects with GAM age splines over
    # stand age, which the harness does not fit. See the notes.
    habitat_v2_ready = "partial",
    use_protocol = use_protocol,
    protocol_is_v2 = identical(use_protocol, protocol_in_v2),

    notes = paste0(
      "v2 climate stage, and the habitat stage less its age ",
      "splines. v2 refits the five aged stand types - white ",
      "spruce, pine, deciduous, mixedwood and black spruce, nine ",
      "age classes each - with GAM splines over stand age and ",
      "overwrites 45 of the 87 vegetation effects with them, so ",
      "those 45 will not match. The other 42, the intercept, ",
      "climate and the soil effects are reproduced. ",
      "Protocol ", if (use_protocol) "fitted" else "not fitted",
      if (identical(use_protocol, protocol_in_v2)) {
        " (the v2 setting for this taxon)."
      } else {
        " (overridden; v2 does the opposite for this taxon)."
      },
      if (is.null(reference_note)) "" else paste0(" ", reference_note)
    )
  )
}

# 3. plant_group_specs() ----

#' Every Plant-Group Spec
#'
#' A convenience for running all four at once. Each taxon module
#' must already be sourced.
#'
#' @param use_protocol Logical, or NULL for the v2 setting per
#'   taxon.
#' @return A named list of specs, keyed on the data slug.
#'
#' @example # Example usage of the function
#' # names(plant_group_specs())
plant_group_specs <- function(use_protocol = NULL) {
  list(
    bryophyte = bryophyte_spec(use_protocol = use_protocol),
    lichen = lichen_spec(use_protocol = use_protocol),
    mite = soil_mite_spec(use_protocol = use_protocol),
    vascular_plant = vascular_plant_spec(
      use_protocol = use_protocol
    )
  )
}

# End of script ----
