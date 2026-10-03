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
#   - The climate set is v2's 25 candidates (06.ModelClimate.R):
#     the null, eight climate combinations, and each of the eight
#     with linear and with quadratic spatial terms. The spatial
#     terms are the UTM easting and northing sites.csv carries
#     for birds, aliased to v2's names.
#   - Climate is fitted once per draw on every survey, as v2
#     does, and shared by both regions (`scope = "province"`).
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

    # v2's spatial terms are the survey's UTM easting and northing
    # in metres, which sites.csv carries for birds.
    aliases = list(Easting = "easting", Northing = "northing"),

    regions = list(
      north = list(
        filter = ~ useNorth == 1,
        grid = NULL,
        term_block = "veg",
        habitat_models = "landcover_bird_north_v2",
        # v2 weights the landcover models by region
        weight_column = "vegw"
      ),
      south = list(
        filter = ~ useSouth == 1,
        grid = NULL,
        term_block = "soil",
        habitat_models = "landcover_bird_south_v2",
        weight_column = "soilw"
      )
    ),

    stages = list(
      list(
        name = "climate",
        # v2's 25 candidates, averaged at once by AICc
        # (06.ModelClimate.R); only the landcover stage walks
        # groups.
        models = "climate_bird_v2",
        engine = "glm",
        selection = "aic_average",
        ic = "AICc",
        # Fitted once on every survey in the draw, as v2 fits it,
        # and shared by both regions. Unweighted, as in v2.
        scope = "province",
        weighted = FALSE,
        # v2 carries the averaged prediction on the response
        # scale WITHOUT the QPAD offset: exp(link), the rate.
        # 06.ModelClimate.R asks for predict(type = "link") on a
        # MuMIn average, which is built from the averaged
        # coefficients and drops the offset. Checked 2026-10-02:
        # v2's stored AMRO draw-1 prediction averages 0.118;
        # exp(link) on the same surveys gives 0.118, and
        # exp(link + offset) gives 0.315. Carrying the offset cut
        # the landcover Climate coefficient about threefold
        # (AMRO draw 1: 1.60 against v2's 4.91; 4.76 without).
        carry_as = "Climate",
        carry_scale = "exp",
        carry_offset = FALSE
      ),
      list(
        name = "landcover",
        # Set per region: vegetation classes in the north, soil
        # classes in the south.
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
      # v2 selects a draw with %in%, so a survey drawn twice is
      # fitted once.
      unique_ids = TRUE,
      # One draw for the whole province, filtered per region.
      scope = "province"
    ),

    # What this spec reproduces of v2, per stage. The single
    # source of truth for coverage: the report reads it.
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
