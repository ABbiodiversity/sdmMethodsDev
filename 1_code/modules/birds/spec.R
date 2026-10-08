# ---
# title: Bird Taxon Spec
# author: Brendan Casey
# created: 2026-09-09
# inputs: none
# outputs: none; returns objects in memory
# notes:
#   - Counts with a QPAD log-offset (required: it separates
#     effort and detectability from abundance).
#   - Climate: v2's 25 candidates averaged by AICc, province-wide
#     per draw. Landcover: staged_bic, smallest model within 2
#     BIC of the best.
#   - v2's stored draws are keyed on surveyid and translated to
#     survey units.
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
    # The stage a methods experiment replaces by default
    habitat_stage = "landcover",
    response_name = "response",

    # Counts are modelled as given; the offset carries effort.
    response_transform = "identity",
    family = "poisson",
    weight_column = NULL,
    tier = NULL,

    # v2's spatial terms: UTM easting and northing, in metres
    aliases = list(Easting = "easting", Northing = "northing"),

    regions = list(
      north = list(
        filter = ~ useNorth == 1,
        # One row per habitat type, rebuilt by _setup/07 from
        # v2's coefficient translation matrix
        grid = "bird_north",
        term_block = "veg",
        habitat_models = "landcover_bird_north_v2",
        # v2 weights the landcover models by region
        weight_column = "vegw"
      ),
      south = list(
        filter = ~ useSouth == 1,
        # One row per habitat type, rebuilt by _setup/07 from
        # v2's coefficient translation matrix
        grid = "bird_south",
        term_block = "soil",
        habitat_models = "landcover_bird_south_v2",
        weight_column = "soilw"
      )
    ),

    stages = list(
      list(
        name = "climate",
        # 06.ModelClimate.R
        models = "climate_bird_v2",
        engine = "glm",
        selection = "aic_average",
        ic = "AICc",
        # Province-wide and unweighted, as in v2
        scope = "province",
        weighted = FALSE,
        # v2 carries exp(link) WITHOUT the QPAD offset: MuMIn's
        # averaged predict(type = "link") drops it. Evidence (AMRO
        # draw 1): v2's stored prediction mean 0.118 = exp(link);
        # exp(link + offset) = 0.315, and carrying the offset cut
        # the landcover Climate coefficient from 4.91 (v2) to
        # 1.60.
        carry_as = "Climate",
        carry_scale = "exp",
        carry_offset = FALSE
      ),
      list(
        name = "landcover",
        # Per region: veg in the north, soil in the south
        models = NULL,
        engine = "glm",
        selection = "staged_bic",
        ic = "BIC",
        # v2 always moves on to each group's winner
        always_advance = TRUE,
        # Every candidate starts from v2's `count ~ climate`
        base_terms = "Climate",
        carry_from = "climate",
        carry_from_as = "Climate"
      )
    ),

    resample = list(
      scheme = "precomputed",
      id_column = "surveyid",
      # v2 selects a draw with %in%: repeats are fitted once
      unique_ids = TRUE,
      # One draw for the whole province, filtered per region.
      scope = "province"
    ),

    v2_coverage = list(
      climate = v2_status(
        "reproduced",
        paste(
          "v2's 25 candidates, AICc averaged, fitted once on the",
          "province-wide draw, unweighted, and carried as",
          "exp(link) without the offset, as MuMIn predicts it."
        )
      ),
      landcover = v2_status(
        "reproduced",
        paste(
          "Staged BIC over v2's groups, weighted by vegw or",
          "soilw, always advancing to each group's winner.",
          "Raw coefficients are translated onto v2's",
          "standardized template by standardize.R, a port",
          "checked exact against v2's packaged output."
        )
      ),
      resampling = v2_status(
        "reproduced",
        paste(
          "v2's 100 stored draws, keyed on surveyid, each survey",
          "once per draw as v2's %in% selects them. Only when",
          "harmonized from the Stratified.Rdata v2 was fitted on",
          "(58,210 surveys per draw); the BirdModels",
          "Data/Archive/2025 copy was rewritten on 2026-08-19 with",
          "different draws."
        )
      )
    ),

    notes = paste0(
      "QPAD offset inside the formula. The landcover groups' ",
      "derived terms (wtAge, isCon, fcc2) are all present; ",
      "columns in both the north and south blocks are ",
      "suffixed by the harmonizer and resolved by term_map()."
    )
  )
}

# End of script ----
