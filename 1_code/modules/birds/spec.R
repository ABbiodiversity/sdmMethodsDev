# ---
# title: Bird Taxon Spec
# author: Brendan Casey
# created: 2026-09-09
# inputs: none
# outputs: none; returns objects in memory
# notes:
#   - The v2 configuration for birds, as data.
#   - Counts with a QPAD log-offset, which is what makes a count
#     comparable across survey protocol and detectability. The
#     offset is not optional: without it a bird model is fitting
#     effort as much as abundance.
#   - Two stages. Climate is eight candidate formulas over FFP,
#     MAP, CMD and TD - the same set the mammal pipeline arrived
#     at independently. Landcover is staged forward selection:
#     groups of formulas, each fitted as an update to the
#     previous group's winner, keeping the smallest model within
#     2 BIC of the best.
#   - Bootstrap ids are precomputed and stored against surveyid
#     rather than survey_unit_id, so the draw is translated
#     through the design block.
#   - Parity coverage is the climate stage. The landcover model
#     groups in 00.NorthModels.R and 00.SouthModels.R are large
#     and reference derived terms - wtAge, isCon, fcc2 - that the
#     harmonized covariates do not carry, so the landcover stage
#     is not yet reproducible.
# ---

# 1. Setup ----

## 1.1 Load packages ----
# Base R only; the harness supplies everything else.

# 2. bird_spec() ----

#' Build the v2 Spec for Birds
#'
#' @return A spec list, as run_spec() consumes.
#'
#' @example # Example usage of the function
#' # spec <- bird_spec()
#' # spec$stages[[1]]$selection
bird_spec <- function() {
  list(
    taxon = "bird",
    response_name = "response",

    # Counts are modelled as given; the offset carries effort.
    response_transform = "identity",
    family = "poisson",
    weight_column = NULL,
    tier = NULL,

    regions = list(
      north = list(
        filter = ~ useNorth == 1,
        grid = NULL,
        term_block = "veg",
        habitat_models = "landcover_bird_north_v2"
      ),
      south = list(
        filter = ~ useSouth == 1,
        grid = NULL,
        term_block = "soil",
        habitat_models = "landcover_bird_south_v2"
      )
    ),

    stages = list(
      list(
        name = "climate",
        models = "climate_bird_mammal_v2",
        engine = "glm",
        # Averaged by AICc weight, not staged. 06.ModelClimate.R
        # calls model.avg() over the whole candidate list; only
        # the landcover stage walks groups.
        selection = "aic_average",
        ic = "AICc",
        # v2 carries the fitted climate through as a term on the
        # link scale here, unlike the plant pipeline, because the
        # landcover model is Poisson with an offset rather than
        # binomial.
        carry_as = "Climate",
        carry_scale = "link"
      ),
      list(
        name = "landcover",
        # Set per region: vegetation classes in the north, soil
        # classes in the south.
        models = NULL,
        engine = "glm",
        selection = "staged_bic",
        ic = "BIC",
        carry_from = "climate",
        carry_from_as = "Climate"
      )
    ),

    resample = list(
      scheme = "precomputed",
      id_column = "surveyid"
    ),

    habitat_v2_ready = TRUE,

    notes = paste0(
      "v2 climate and landcover stages. An earlier note here ",
      "said the landcover groups referenced terms the dataset ",
      "did not carry; that was wrong. wtAge, isCon and fcc2 are ",
      "all present. The columns appearing in both the north and ",
      "south blocks were suffixed by the harmonizer, and the ",
      "term map resolves them. No bird reference output is ",
      "reachable, so birds can be run but not compared."
    )
  )
}

# End of script ----
