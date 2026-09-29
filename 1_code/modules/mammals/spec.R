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
#' @param climate_source Character. "fitted" runs the adapted
#'   climate stage; "precomputed" is the v2 default, which takes
#'   the offset from the lookup instead of fitting it.
#' @param season Character. "summer" or "winter"; selects the
#'   weight column and the species queue.
#' @param tier Character. "modelled" is the full habitat model,
#'   fitted for species with at least 20 detections; "ua" is the
#'   use-availability model, at least 3.
#' @param part Character. Which half of the hurdle to fit.
#'   "presence" is the binomial model, compared against
#'   Coef.pa.all; "abundance" is the Gamma model on the units
#'   where the species was seen, compared against Coef.agp.all.
#'   v2 multiplies the two for total abundance; they are run
#'   separately here because each has its own reference.
#' @return A spec list, as run_spec() consumes.
#'
#' @example # Example usage of the function
#' # spec <- mammal_spec(climate_source = "fitted")
mammal_spec <- function(
  climate_source = c("fitted", "precomputed"),
  season = c("summer", "winter"),
  tier = "modelled",
  part = c("presence", "abundance")
) {
  climate_source <- match.arg(climate_source)
  season <- match.arg(season)
  part <- match.arg(part)

  # Said here rather than discovered as a missing `Climate`
  # column once the run is loading data.
  if (climate_source == "precomputed") {
    stop(
      "climate_source = \"precomputed\" is not implemented: ",
      "nothing reads mammal_climate_predictions.csv yet. Use ",
      "\"fitted\".",
      call. = FALSE
    )
  }

  # The abundance half fits the same candidates with Climate
  # dropped - v2's note is that climate effects on abundance
  # given presence are minimal - plus a null carrying only
  # sampling effort.
  habitat_models <- function() {
    models <- get_model_set("habitat_mammal_north_pa_v2")

    if (part == "presence") {
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

    # v2 models presence rather than the recorded density.
    response_transform = if (part == "presence") {
      mammal_pa_response
    } else {
      mammal_agp_response
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
        # to estimate from.
        filter = if (season == "summer") {
          ~ summer_days > 10
        } else {
          ~ winter_days > 10
        },
        grid = "mammal_north",
        term_block = "veg",
        habitat_models = habitat_models()
      ),
      south = list(
        filter = if (season == "summer") {
          ~ summer_days > 10
        } else {
          ~ winter_days > 10
        },
        grid = "mammal_south",
        term_block = "soil",
        habitat_models = NULL
      )
    ),

    stages = c(stages, list(
      if (part == "presence") {
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
          # to it.
          intercept_cats = "intercept_mammal_north_pa_v2",
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
      climate = v2_status(
        "partial",
        paste(
          "The full v2 9-model set, glm, AICc averaged, fitted",
          "as a stage and bootstrapped. v2 fits it once, in a",
          "separate pipeline, and reads back a prediction."
        )
      ),
      habitat = v2_status(
        "partial",
        paste(
          "North only, one half of the hurdle per run (presence",
          "or abundance). Not implemented: age splines, cutblock",
          "convergence, the assembled total abundance, and the",
          "south candidate sets."
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
        "partial",
        paste(
          "One season per run. v2's `.all` references average",
          "summer and winter, so both must be run and averaged",
          "before comparing."
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
