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
#   - Two stages. Climate is model-averaged by AICc. Landcover is
#     staged forward selection: groups of formulas, each fitted
#     as an update to the previous group's winner, keeping the
#     smallest model within 2 BIC of the best.
#   - The climate set here is v2's eight climate combinations
#     plus the null. v2 also fits each with linear and with
#     quadratic spatial terms, 25 candidates in all
#     (06.ModelClimate.R). Birds carry no Easting or Northing in
#     the test dataset, so those cannot be fitted until the
#     harmonizer adds them.
#   - Bootstrap ids are precomputed and stored against surveyid
#     rather than survey_unit_id, so the draw is translated
#     through the design block.
#   - What this spec reproduces of v2 is stated once, in
#     `v2_coverage`. The report is generated from it.
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

    # What this spec reproduces of v2, per stage. The single
    # source of truth for coverage: the report reads it.
    v2_coverage = list(
      climate = v2_status(
        "partial",
        paste(
          "AICc averaging as v2, but over 9 candidates where v2",
          "fits 25; the spatial ones need Easting and Northing,",
          "which the test dataset lacks for birds. Carried on the",
          "link scale; v2 carries exp(link). Fitted per region;",
          "v2 fits it province-wide."
        )
      ),
      landcover = v2_status(
        "partial",
        paste(
          "Staged BIC over v2's groups. v2 weights the fits by",
          "vegw or soilw, not applied here, and always advances",
          "to a group's winner, where this advances only on an",
          "improvement. Coefficients keep raw glm names; v2's",
          "packaged ones use the standardized template."
        )
      ),
      resampling = v2_status(
        "reproduced",
        "v2's 100 stored draws, keyed on surveyid."
      )
    ),

    # Facts about this taxon's configuration. Coverage is in
    # v2_coverage, not here.
    notes = paste0(
      "QPAD offset inside the formula. The landcover groups' ",
      "derived terms (wtAge, isCon, fcc2) are all present; ",
      "columns in both the north and south blocks are ",
      "suffixed by the harmonizer and resolved by term_map()."
    )
  )
}

# End of script ----
