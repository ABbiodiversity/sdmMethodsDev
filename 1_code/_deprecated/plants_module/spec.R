# ---
# title: Plant-Group Taxon Specs
# author: Brendan Casey
# created: 2026-09-09
# inputs: none
# outputs: none; returns objects in memory
# notes:
#   - The v2 configuration for the four plant-group taxa, as data.
#     "Plant group" names a survey design rather than a taxonomy:
#     vascular plants, bryophytes, lichens and soil mites share
#     one design and one set of scripts, soil mites included.
#   - Parity coverage is the climate stage. The v2 habitat stage
#     uses inverse-variance model averaging with a coefficient
#     adjustment and post-hoc GAM age splines, none of which the
#     harness implements yet; `habitat_v2_ready` records that per
#     taxon so a run cannot quietly claim more than it did.
#   - Protocol is fitted for bryophytes and lichens and not for
#     mites or vascular plants. That asymmetry is v2's, preserved
#     here for parity, and `use_protocol` exposes it so an
#     experiment can equalize across taxa. See the parity ledger
#     in docs/framework_design.md.
#   - The engine is bayesglm, which the v2 plant scripts use
#     because rare species fitted against 30-term habitat
#     formulas separate completely and plain glm then returns
#     infinite coefficients. The regularization is load-bearing.
#   - Regions are the two model sets: north is fitted off the
#     grassland, south on grassland and parkland. v2 applies
#     those filters inside its model functions; they are stated
#     here instead, which is numerically the same.
# ---

# 1. Setup ----

## 1.1 Load packages ----
# Base R only; the harness supplies everything else.

# 2. plant_spec() ----

#' Build the v2 Spec for One Plant-Group Taxon
#'
#' @param taxon Character. One of "bryophyte", "lichen", "mite"
#'   or "vascular_plant".
#' @param use_protocol Logical, or NULL to take the v2 value for
#'   that taxon. Setting it equalizes a term v2 applies
#'   inconsistently, which is what a cross-taxa experiment wants.
#' @return A spec list, as run_spec() consumes.
#'
#' @example # Example usage of the function
#' # spec <- plant_spec("bryophyte")
#' # spec$stages[[1]]$engine
plant_spec <- function(taxon, use_protocol = NULL) {
  known <- c("bryophyte", "lichen", "mite", "vascular_plant")

  if (!taxon %in% known) {
    stop(
      "Unknown plant-group taxon `", taxon, "`. Known: ",
      paste(known, collapse = ", "),
      call. = FALSE
    )
  }

  # v2 fits Protocol for bryophytes and lichens only.
  v2_protocol <- taxon %in% c("bryophyte", "lichen")

  if (is.null(use_protocol)) {
    use_protocol <- v2_protocol
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

    # Plant responses are cover or abundance values; v2 models
    # presence, so anything above zero is a detection.
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
    protocol_is_v2 = identical(use_protocol, v2_protocol),

    notes = paste0(
      "v2 climate stage, and the habitat stage less its age ",
      "splines. v2 refits the five aged stand types - white ",
      "spruce, pine, deciduous, mixedwood and black spruce, nine ",
      "age classes each - with GAM splines over stand age and ",
      "overwrites 45 of the 87 vegetation effects with them, so ",
      "those 45 will not match. The other 42, the intercept, ",
      "climate and the soil effects are reproduced. ",
      "Protocol ", if (use_protocol) "fitted" else "not fitted",
      if (identical(use_protocol, v2_protocol)) {
        " (the v2 setting for this taxon)."
      } else {
        " (overridden; v2 does the opposite for this taxon)."
      }
    )
  )
}

# 3. plant_specs() ----

#' Every Plant-Group Spec
#'
#' @param use_protocol Logical, or NULL for the v2 setting per
#'   taxon.
#' @return A named list of specs.
#'
#' @example # Example usage of the function
#' # names(plant_specs())
plant_specs <- function(use_protocol = NULL) {
  taxa <- c("bryophyte", "lichen", "mite", "vascular_plant")

  stats::setNames(
    lapply(taxa, plant_spec, use_protocol = use_protocol),
    taxa
  )
}

# End of script ----
