# ---
# title: The v2 Mammal Climate Stage
# author: Brendan Casey; model logic by Marcus Becker (v2)
# created: 2026-10-14
# inputs:
#   in the test dataset (see harness/data_source.R), the
#   mammal_province rows of mammal.csv, sites.csv and
#   covariates.csv: v2's combined 2022 table, which v2's climate
#   stage fits on (_setup/01 section 1.7b)
# outputs: none; returns objects in memory
# notes:
#   - Ports ABbiodiversity/MammalModels (2874dec),
#     1_code/2_habitat-modeling/climate/: the response built by
#     01_prepare-data.R, and the regional 03_basic-models.R join
#     that keeps deployments with a climate prediction. The nine
#     GLMs of 02_run-models.R are the spec's climate stage.
#   - Seasons are pooled: one presence per deployment from the
#     days-weighted mean density, with base weighted.mean(), which
#     drops zero-day seasons. data.table's grouped weighted.mean
#     does not, and would lose 97 of v2's Moose sites.
#   - v2 keeps deployments by `FFP`: rows the camera climate does
#     not reach are dropped from every candidate, the null
#     included.
#   - The data carry the archived v2 prep script's bug (summer
#     densities blanked when WinterDays < 10). Kept for parity.
# ---

# 1. Setup ----

## 1.1 Load packages ----
# Base R only; the harness supplies everything else.

# 2. mammal_season_pair() ----

#' Name Both Seasons' Response Columns for a Species
#'
#' The spec's `response_companions`: the climate stage pools the
#' two seasons whichever season the run models.
#'
#' @param species Character. A harness species name, e.g.
#'   "Moose_Summer".
#' @return A named character vector, `summer` and `winter`.
#'
#' @example # Example usage of the function
#' # mammal_season_pair("Moose_Winter")
#' # #       summer         winter
#' # # "Moose_Summer" "Moose_Winter"
mammal_season_pair <- function(species) {
  base <- sub("_(Summer|Winter)$", "", species)

  c(
    summer = paste0(base, "_Summer"),
    winter = paste0(base, "_Winter")
  )
}

# 3. mammal_pooled_density() ----

#' Pool Both Seasons' Density per Deployment, as v2
#'
#' v2 groups by `location_project`, so a deployment listed twice
#' is pooled over both rows' seasons. Bootstrap repeats of one
#' unit are not separate rows of the source, so units are pooled
#' once each.
#'
#' @param frame A province frame carrying `response_summer`,
#'   `response_winter`, `summer_days`, `winter_days`,
#'   `location_project` and `survey_unit_id`.
#' @return A list of `density`, the pooled density for each row
#'   (NA where base weighted.mean gives NA or NaN), and `lead`,
#'   TRUE on rows of the first unit of each deployment.
#'
#' @example # Example usage of the function
#' # pooled <- mammal_pooled_density(frame)
mammal_pooled_density <- function(frame) {
  needed <- c(
    "response_summer", "response_winter", "summer_days",
    "winter_days", "location_project", "survey_unit_id"
  )
  absent <- setdiff(needed, names(frame))

  if (length(absent) > 0) {
    stop(
      "The mammal climate response needs ",
      paste(absent, collapse = ", "), " in the frame. Is the ",
      "spec's `response_companions` set?",
      call. = FALSE
    )
  }

  units <- as.character(frame$survey_unit_id)
  key <- as.character(frame$location_project)

  # Step 1: One pooled value per deployment, over its distinct
  # units (01_prepare-data.R:156-166)
  distinct <- which(!duplicated(units))
  groups <- split(distinct, key[distinct])

  pooled <- vapply(groups, function(rows) {
    stats::weighted.mean(
      c(frame$response_summer[rows], frame$response_winter[rows]),
      c(frame$summer_days[rows], frame$winter_days[rows])
    )
  }, numeric(1))

  lead_units <- vapply(groups, function(rows) units[rows[1]],
                       character(1))

  list(
    density = unname(pooled[key]),
    lead = units %in% lead_units
  )
}

# 4. mammal_climate_response() ----

#' Presence for the Climate Stage, as v2 Builds It
#'
#' The climate stage's `response_transform`. Present where the
#' pooled density is above zero (01_prepare-data.R:167-175). NA,
#' so `glm` drops the row, on other units of a deployment already
#' counted, where the pooled density is NA, and where the camera
#' climate is missing (`FFP` NA).
#'
#' @param values Numeric. The run's own season, unused: the
#'   pooled response reads both seasons from the frame.
#' @param frame The province frame (see mammal_pooled_density()),
#'   with `FFP`.
#' @return An integer vector of 0, 1 and NA, one per row.
#'
#' @example # Example usage of the function
#' # mammal_climate_response(d$response_raw, d)
mammal_climate_response <- function(values, frame) {
  pooled <- mammal_pooled_density(frame)

  present <- as.integer(pooled$density > 0)
  present[!pooled$lead | is.na(pooled$density) |
            is.na(frame$FFP)] <- NA_integer_

  present
}

# 5. mammal_climate_available() ----

#' Keep Regional Rows Whose Deployment Has a Climate Response
#'
#' The spec's `species_frame` when climate is fitted. v2 joins its
#' climate prediction to each region with `inner_join` and drops
#' rows without one (north 03_basic-models.R:359-362, south
#' 329-332), so the habitat models see only deployments the
#' climate stage could fit. As mammal_precomputed_climate(), the
#' response is then recomputed, since lure correction and scaling
#' depend on the rows kept.
#'
#' @param frame A one-species region frame, with
#'   `location_project`.
#' @param species Character. The harness species name.
#' @param data_dir Character.
#' @param spec The mammal spec.
#' @return The frame, without rows lacking a climate response.
#'
#' @example # Example usage of the function
#' # frame <- mammal_climate_available(frame, sp, data_dir, spec)
mammal_climate_available <- function(frame, species, data_dir,
                                     spec) {
  pair <- mammal_season_pair(species)

  # Step 1: The province rows, read as the harness reads them
  province <- build_model_data(
    taxon = spec$taxon,
    data_dir = data_dir,
    species = unname(pair),
    covariates = c("FFP", "location_project"),
    region = province_region(data_dir, spec$taxon)
  )
  province_frame <- model_frame(
    province, species = species, companions = pair
  )

  # Step 2: Deployments with a climate response
  response <- mammal_climate_response(NULL, province_frame)
  available <- unique(
    province_frame$location_project[!is.na(response)]
  )

  # Step 3: Keep those regional rows, with a count, and recompute
  frame <- frame[
    frame$location_project %in% available &
      !is.na(frame$response_raw), ,
    drop = FALSE
  ]

  frame$response <- apply_response_transform(
    frame$response_raw, spec$response_transform, frame
  )

  frame
}

# End of script ----
