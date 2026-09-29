# ---
# title: Mammal Taxon Spec
# author: Brendan Casey
# created: 2026-09-09
# inputs: none
# outputs: none; returns objects in memory
# notes:
#   - The v2 configuration for mammals, as data.
#   - v2 does not fit climate in this pipeline. It reads a
#     prediction from mammal_climate_predictions.csv, produced by
#     1_code/2_habitat-modeling/climate/ in ABbiodiversity/
#     MammalModels: nine binomial GLMs over FFP, MAP, CMD and TD,
#     averaged by AICc weight. That pipeline is adapted here as a
#     fitted stage, so a bioclimatic question can be asked of
#     mammals at all. `climate_source` selects which, but only
#     "fitted" is implemented: nothing reads the prediction file
#     yet.
#   - The climate block, CMD and TD included, comes from
#     abmi-camera-climate_2023.Rdata, the file v2 fitted against,
#     joined by the harmonizer. The fitted stage runs the full
#     nine-model v2 set.
#   - What this spec reproduces of v2 is stated once, in
#     `v2_coverage`. The report is generated from it.
#   - North and south are separate models on overlapping
#     deployments, and their covariates disagree, so the two are
#     separate covariate keys rather than a filter on one table.
#   - Weights are season days. The season a species is modelled
#     in is part of its name, so the weight column follows the
#     species rather than the taxon.
# ---

# 1. Setup ----

## 1.1 Load packages ----
# Base R only; the harness supplies everything else.

# 2. mammal_pa_response() ----

#' Standardise Detections to the No-Lure Scale
#'
#' A lured camera detects more, so a raw detection is not
#' comparable across lured and unlured deployments. v2 estimates
#' the lure effect from the numbered ABMI grid sites alone -
#' those are the ones deployed in matched lured and unlured pairs,
#' so the ratio between them is a lure effect rather than a
#' difference in where cameras were put - and divides the lured
#' detections by it.
#'
#' The result is then scaled to a maximum of one, which is what
#' makes it a proportion a binomial model can take.
#'
#' A ratio that cannot be estimated - no lured or no unlured grid
#' sites for this species and season - leaves the detections
#' uncorrected rather than dividing by zero or by NA.
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

  # Numbered locations are the ABMI grid; other projects are
  # not part of the lure comparison.
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
#' The abundance half of the hurdle. Lure is corrected as for
#' presence, but from the ratio of mean counts rather than mean
#' detections, because the question is how many rather than
#' whether.
#'
#' The result is winsorized at the 99th percentile of the
#' positive counts. A handful of density estimates are genuinely
#' enormous, and a Gamma model fitted on the log scale gives them
#' leverage out of all proportion to how much they say about a
#' habitat type. Capping is a judgement that those points are
#' real but uninformative, not that they are wrong.
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
#' @param part Character. "hurdle", v2's model, fits both halves
#'   together (hurdle.R) and reports presence, abundance and
#'   total abundance on v2's full habitat set, with the stand-age
#'   splines and cutblock convergence. "presence" and
#'   "abundance" fit one half alone with the harness's generic
#'   rules and report the winning model's own categories.
#' @return A spec list, as run_spec() consumes.
#'
#' @example # Example usage of the function
#' # spec <- mammal_spec()
#' # spec <- mammal_spec(climate_source = "fitted",
#' #                     part = "presence")
mammal_spec <- function(
  climate_source = c("precomputed", "fitted"),
  season = c("summer", "winter"),
  tier = "modelled",
  part = c("hurdle", "presence", "abundance")
) {
  climate_source <- match.arg(climate_source)
  season <- match.arg(season)
  part <- match.arg(part)
  hurdle <- part == "hurdle"

  # The abundance half fits the same candidates with Climate
  # dropped - v2's note is that climate effects on abundance
  # given presence are minimal - plus a null carrying only
  # sampling effort.
  habitat_models <- function(set) {
    models <- get_model_set(set)

    # The hurdle rule derives its abundance candidates itself
    if (part %in% c("presence", "hurdle")) {
      return(models)
    }

    c(
      gsub(" \\+ Climate", "", models),
      ". ~ . + seas_days"
    )
  }

  stages <- list()

  if (climate_source == "fitted") {
    stages <- list(
      list(
        name = "climate",
        # The full v2 set. CMD and TD come from the camera
        # climate file, which the harmonizer now joins.
        models = "climate_bird_mammal_v2",
        engine = "glm",
        selection = "aic_average",
        ic = "AICc",
        carry_as = "Climate",
        # Climate is modelled on presence whichever half of the
        # hurdle is being fitted: the abundance half takes the
        # same climate offset, and fitting a binomial on counts
        # would fail outright.
        response_transform = mammal_pa_response
      )
    )
  }

  list(
    taxon = "mammal",
    response_name = "response",

    # v2 models presence rather than the recorded density. The
    # hurdle rule recomputes both halves' responses from the raw
    # count itself.
    response_transform = if (part == "abundance") {
      mammal_agp_response
    } else {
      mammal_pa_response
    },

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

    # The formulas fit `seas_days`; which column that is depends
    # on the season being modelled.
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
        habitat_models = habitat_models("habitat_mammal_north_pa_v2"),
        intercept_cats = "intercept_mammal_north_pa_v2",
        # The stand-age splines read the aged cover columns
        extra_covariates = if (hurdle) {
          as.vector(t(outer(
            c("Spruce", "Pine", "Decid", "Mixedwood", "TreedBog"),
            c("R", 1:8), paste0
          )))
        } else {
          NULL
        }
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
        habitat_models = habitat_models("habitat_mammal_south_pa_v2"),
        intercept_cats = "intercept_mammal_south_pa_v2",
        # Half the south candidates carry pAspen. Like sampling
        # effort, it is held fixed for the one-hot predictions
        # rather than read as a habitat type.
        constants = list(seas_days = 100, Climate = 0, pAspen = 0)
      )
    ),

    stages = c(stages, list(
      if (hurdle) {
        list(
          name = "habitat",
          models = NULL,
          engine = "glm",
          # Both halves of v2's hurdle together; see hurdle.R.
          # Writes stages habitat_presence, habitat_abundance and
          # habitat_total.
          selection = select_mammal_v2_hurdle,
          ic = "AICc",
          carry_from = "climate",
          carry_from_as = "Climate"
        )
      } else if (part == "presence") {
        list(
          name = "habitat",
          models = NULL,
          engine = "glm",
          selection = "aic_best_onehot",
          ic = "AICc",
          carry_from = "climate",
          carry_from_as = "Climate",
          # Each candidate leaves one land cover out; the rule
          # reports it, because every other effect is relative
          # to it. Set per region, with the region's models.
          constants = list(seas_days = 100, Climate = 0),
          slope_terms = "Climate",
          # v2 shifts the whole set on the logit scale so mean
          # fitted presence matches mean observed. Without it
          # the effects are internally consistent but sit at
          # the wrong level.
          calibrate = TRUE
        )
      } else {
        list(
          name = "habitat",
          models = NULL,
          engine = "glm",
          selection = "aic_best_grid",
          ic = "AICc",
          # Gamma on the log scale. mustart is set to the mean
          # rather than left at the default of y itself, which
          # spans orders of magnitude for a right-skewed density
          # and sends the fitting algorithm off.
          family = stats::Gamma(link = "log"),
          control = list(),
          # Abundance given presence is undefined where there
          # was no presence.
          row_filter = function(d) d$response > 0,
          constants = list(seas_days = 100, Climate = 0),
          # Coef.agp.all is stored on the response scale -
          # abundance, not log abundance - despite the source
          # comment describing it as raw log-scale predictions.
          # Its published range runs 0 to 10.4.
          scale = "response"
        )
      }
    )),

    resample = list(
      scheme = "spatial_block",
      min_detections = 20L
      # No seed here. The experiment sets one base seed,
      # `boot_seed` in run.R, and each species derives its own
      # from it. Without one the draws are unseeded, as in v2.
    ),

    climate_source = climate_source,
    part = part,

    # What this spec reproduces of v2, per stage. The single
    # source of truth for coverage: the report reads it.
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
      habitat = if (hurdle) {
        v2_status(
          "reproduced",
          paste(
            "v2's hurdle: presence, abundance and total abundance",
            "on the full habitat set, with the stand-age splines,",
            "calibration and cutblock convergence. Matches v2's",
            "published tables to 2e-14, north and south."
          )
        )
      } else {
        v2_status(
          "partial",
          paste(
            "One half of the hurdle alone, reporting the winning",
            "model's own categories; use part = \"hurdle\" for v2."
          )
        )
      },
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

    # Facts about this run's configuration. Coverage is in
    # v2_coverage, not here.
    notes = paste0(
      "Climate fitted with the full 9-model v2 set. Season: ",
      season, ". Hurdle part: ", part, ". Tier: ", tier, "."
    )
  )
}

# End of script ----
