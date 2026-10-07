# ---
# title: Mammal Taxon Spec
# author: Brendan Casey
# created: 2026-09-09
# inputs: none
# outputs: none; returns objects in memory
# notes:
#   - v2 reads mammal climate from mammal_climate_predictions.csv
#     (ABbiodiversity/MammalModels, 1_code/2_habitat-modeling/
#     climate/: nine binomial GLMs over FFP, MAP, CMD, TD, AICc
#     averaged). `climate_source = "fitted"` instead fits that set
#     as a stage, on the climate from
#     abmi-camera-climate_2023.Rdata that v2 used.
#   - North and south are separate covariate keys: overlapping
#     deployments with disagreeing covariates.
#   - Weights are season days, so the weight column follows the
#     season in the species name.
# ---

# 1. Setup ----

## 1.1 Load packages ----
# Base R only; the harness supplies everything else.

# 2. mammal_pa_response() ----

#' Standardise Detections to the No-Lure Scale
#'
#' As v2: lured detections are divided by the lure ratio
#' estimated from the numbered ABMI grid sites (matched lured and
#' unlured pairs), then scaled to a maximum of one for a binomial
#' model. If the ratio cannot be estimated, detections are left
#' uncorrected.
#'
#' @param values Numeric vector of counts.
#' @param frame The assembled frame, carrying `lured` and
#'   `location`.
#' @return A numeric vector between 0 and 1.
#'
#' @example # Example usage of the function
#' # mammal_pa_response(d$Count, d)
mammal_pa_response <- function(values, frame) {
  detected <- sign(values)

  # Numbered locations are the ABMI grid
  grid_site <- grepl("^[[:digit:]]+", as.character(frame$location))
  lured <- as.character(frame$lured) == "Yes"

  usable <- grid_site & !is.na(lured)
  lure_ratio <- NA_real_

  if (any(usable & lured) && any(usable & !lured)) {
    lure_ratio <- mean(detected[usable & lured], na.rm = TRUE) /
      mean(detected[usable & !lured], na.rm = TRUE)
  }

  corrected <- if (is.finite(lure_ratio) && lure_ratio > 0) {
    detected / ifelse(lured %in% TRUE, lure_ratio, 1)
  } else {
    detected
  }

  peak <- max(corrected, na.rm = TRUE)

  if (!is.finite(peak) || peak <= 0) {
    return(corrected)
  }

  corrected / peak
}

# 3. mammal_agp_response() ----

#' Standardise Abundance to the No-Lure Scale
#'
#' Lure-corrected from the ratio of mean counts, then winsorized
#' at the 99th percentile of positive counts: a few enormous
#' densities would otherwise dominate the log-link Gamma fit.
#'
#' @param values Numeric vector of counts.
#' @param frame The assembled frame, carrying `lured` and
#'   `location`.
#' @return A numeric vector; zero where the species was absent,
#'   which the abundance stage then filters out.
#'
#' @example # Example usage of the function
#' # mammal_agp_response(d$Count, d)
mammal_agp_response <- function(values, frame) {
  present <- values > 0
  grid_site <- grepl("^[[:digit:]]+", as.character(frame$location))
  lured <- as.character(frame$lured) == "Yes"

  usable <- grid_site & present & !is.na(lured)
  lure_ratio <- NA_real_

  if (any(usable & lured) && any(usable & !lured)) {
    lure_ratio <- mean(values[usable & lured], na.rm = TRUE) /
      mean(values[usable & !lured], na.rm = TRUE)
  }

  corrected <- if (is.finite(lure_ratio) && lure_ratio > 0) {
    values / ifelse(lured %in% TRUE, lure_ratio, 1)
  } else {
    values
  }

  positive <- corrected[corrected > 0 & is.finite(corrected)]

  if (length(positive) == 0) {
    return(corrected)
  }

  cap <- stats::quantile(positive, 0.99, names = FALSE)

  pmin(corrected, cap)
}

# 4. mammal_spec() ----

#' Build the v2 Spec for Mammals
#'
#' The habitat stage is the generic `hurdle` rule with v2's GLMs
#' (best by AICc), turned into v2's tables by
#' mammal_v2_habitat_tables() (hurdle.R).
#'
#' @param climate_source Character. "precomputed", the v2
#'   default, reads each species' climate prediction from
#'   mammal_climate_predictions.csv and drops the deployments
#'   without one, as v2 does; "fitted" fits the adapted climate
#'   stage instead.
#' @param season Character. "summer" or "winter"; selects the
#'   weight column and the species queue.
#' @param tier Character. "modelled" is the full habitat model,
#'   fitted for species with at least 20 detections; "ua" is the
#'   use-availability model, at least 3.
#' @return A spec list, as run_spec() consumes.
#'
#' @example # Example usage of the function
#' # spec <- mammal_spec()
#' # spec <- mammal_spec(climate_source = "fitted")
mammal_spec <- function(
  climate_source = c("precomputed", "fitted"),
  season = c("summer", "winter"),
  tier = "modelled"
) {
  climate_source <- match.arg(climate_source)
  season <- match.arg(season)

  stages <- list()

  if (climate_source == "fitted") {
    stages <- list(
      list(
        name = "climate",
        # The full v2 set (CMD and TD from the camera climate file)
        models = "climate_bird_mammal_v2",
        engine = "glm",
        selection = "aic_average",
        ic = "AICc",
        carry_as = "Climate",
        # Fitted on presence; the abundance half reuses it
        response_transform = mammal_pa_response
      )
    )
  }

  list(
    taxon = "mammal",
    response_name = "response",
    # The stage a methods experiment replaces by default
    habitat_stage = "habitat",

    # Presence; the abundance half reads the raw count
    response_transform = mammal_pa_response,

    # v2 reads climate from a separate pipeline's prediction
    species_frame = if (climate_source == "precomputed") {
      mammal_precomputed_climate
    } else {
      NULL
    },
    supplied_columns = if (climate_source == "precomputed") {
      "Climate"
    } else {
      NULL
    },
    family = "binomial",
    weight_column = paste0("wt_", season),

    # `seas_days` is the season's days column
    aliases = list(seas_days = paste0(season, "_days")),
    tier = tier,
    season = season,

    regions = list(
      north = list(
        # v2 drops deployments with too little sampling effort
        # to estimate from, and in the north the wetland-margin
        # deployments (section 5.1).
        filter = if (season == "summer") {
          ~ summer_days > 10 & WetlandMargin != 1
        } else {
          ~ winter_days > 10 & WetlandMargin != 1
        },
        grid = "mammal_north",
        # v2's prediction matrix without WetlandMargin, and
        # without the Climate row (section 5.2)
        grid_drop_rows = c("WetlandMargin", "Climate"),
        grid_drop_cols = "WetlandMargin",
        term_block = "veg",
        habitat_models = "habitat_mammal_north_pa_v2",
        intercept_cats = "intercept_mammal_north_pa_v2",
        # The v2 stand-age splines read the aged cover columns
        extra_covariates = as.vector(t(outer(
          c("Spruce", "Pine", "Decid", "Mixedwood", "TreedBog"),
          c("R", 1:8), paste0
        )))
      ),
      south = list(
        # The south drops all-water deployments instead
        filter = if (season == "summer") {
          ~ summer_days > 10 & Water == 0
        } else {
          ~ winter_days > 10 & Water == 0
        },
        grid = "mammal_south",
        grid_drop_rows = "Climate",
        term_block = "soil",
        # v2's 30 south candidates, from south-models/00_models.R
        habitat_models = "habitat_mammal_south_pa_v2",
        intercept_cats = "intercept_mammal_south_pa_v2",
        # pAspen (in half the candidates) is held fixed on the
        # grid and is not cover
        constants = list(seas_days = 100, Climate = 0, pAspen = 0)
      )
    ),

    stages = c(stages, list(
      list(
        name = "habitat",
        models = NULL,
        engine = "glm",
        # Each half best by AICc; see methods/selection/hurdle.R
        selection = "hurdle",
        part_selection = "aic_best",
        ic = "AICc",
        carry_from = "climate",
        carry_from_as = "Climate",
        # The presence response, recomputed on each draw because
        # the lure ratio and scaling depend on which units are in
        response_transform = mammal_pa_response,
        # Abundance given presence: the lure-corrected count,
        # winsorized, on a log-link Gamma, unweighted, without
        # Climate, plus an effort-only null - all as v2
        abundance_response = mammal_agp_response,
        abundance_family = stats::Gamma(link = "log"),
        abundance_drop = "Climate",
        abundance_null = ". ~ . + seas_days",
        abundance_weighted = FALSE,
        # Each habitat type is read at v2's 100 sampling days and
        # zero climate
        grid_constants = list(seas_days = 100, Climate = 0),
        # v2's own tables from the two GLMs: the full habitat
        # set, calibration, stand-age splines, Mule Deer and
        # cutblock convergence. Removed by replace_stage_method().
        post_process = list(mammal_v2_habitat_tables)
      )
    )),

    resample = list(
      scheme = "spatial_block",
      min_detections = 20L
      # No seed here: the experiment's seed is used
    ),

    climate_source = climate_source,

    v2_coverage = list(
      climate = if (climate_source == "precomputed") {
        v2_status(
          "reproduced",
          paste(
            "v2's precomputed climate prediction, read per species;",
            "deployments without one are dropped, as in v2."
          )
        )
      } else {
        v2_status(
          "partial",
          paste(
            "The full v2 9-model set, fitted as a stage. v2 fits",
            "it once, in a separate pipeline, and reads back a",
            "prediction; use climate_source = \"precomputed\"."
          )
        )
      },
      habitat = v2_status(
        "reproduced",
        paste(
          "v2's hurdle: presence, abundance and total abundance",
          "on the full habitat set, with the stand-age splines,",
          "calibration and cutblock convergence. Matches v2's",
          "published tables to 2e-14, north and south."
        )
      ),
      resampling = v2_status(
        "partial",
        paste(
          "Spatial-block bootstrap. v2 fits the habitat stage",
          "once, so only iteration 1, the full data, is like for",
          "like."
        )
      ),
      season = v2_status(
        "reproduced",
        paste(
          "One season per spec; run.R runs both, and the gate",
          "averages them as v2's `.all` references do."
        )
      )
    ),

    notes = paste0(
      if (climate_source == "fitted") {
        "Climate fitted with the full 9-model v2 set."
      } else {
        "Climate read from v2's precomputed predictions."
      },
      " Season: ", season, ". Tier: ", tier, "."
    )
  )
}

# End of script ----
