# ---
# title: Resampling Scheme - Spatially Blocked Bootstrap
# author: Brendan Casey
# created: 2026-09-09
# inputs: none
# outputs: registers the `spatial_block` scheme
# notes:
#   - Reproduces the v2 plant bootstrap: resample survey units
#     with replacement within coarse latitude and longitude
#     blocks, so a draw keeps the geographic spread rather than
#     drifting toward whichever region is best surveyed.
#   - Iteration 1 is the complete data, matching v2, so the first
#     fit of every run is the full-data fit.
#   - Every draw comes from one stream under the species' seed, so
#     draws 1 to 5 of a 5-draw run are the same as draws 1 to 5 of
#     a 100-draw run.
# ---

# 1. Setup ----

## 1.1 Load packages ----
# Base R only.

# 2. resample_spatial_block() ----

#' Draw a Spatially Blocked Bootstrap
#'
#' Resamples survey units with replacement within each spatial
#' block, so every block keeps its original number of units.
#'
#' @param frame A data frame with `survey_unit_id` and the
#'   coordinate columns.
#' @param iterations Integer vector of bootstrap iterations.
#' @param long_column,lat_column Character. Coordinate columns.
#' @param min_detections Integer. Redraw a block set until at
#'   least this many detections are present, or 0 to skip the
#'   check.
#' @param response Numeric vector, one per row of `frame`, used
#'   only for the detection check.
#' @param max_attempts Integer. How many redraws before giving
#'   up, so a species that can never meet the threshold fails
#'   rather than looping forever.
#' @param seed Integer or NULL. NULL leaves the stream unseeded,
#'   which is what v2 did.
#' @return A list of character vectors, one per iteration.
#'
#' @example # Example usage of the function
#' # ids <- resample_spatial_block(frame, 1:5, seed = 42)
resample_spatial_block <- function(
  frame,
  iterations,
  long_column = "long",
  lat_column = "lat",
  min_detections = 0L,
  response = NULL,
  max_attempts = 100L,
  seed = harness_seed()
) {
  for (one in c(long_column, lat_column)) {
    if (!one %in% names(frame)) {
      stop(
        "Spatial blocking needs `", one, "` in the frame.",
        call. = FALSE
      )
    }
  }

  units <- as.character(frame$survey_unit_id)
  blocks <- spatial_blocks(
    frame[[long_column]], frame[[lat_column]]
  )
  by_block <- split(seq_along(units), blocks)

  draw_once <- function() {
    unlist(
      lapply(
        by_block,
        function(rows) sample(rows, length(rows), replace = TRUE)
      ),
      use.names = FALSE
    )
  }

  with_seed(seed, lapply(iterations, function(i) {
    # Step 1: Iteration 1 is the complete data, as in v2
    if (i == 1L) {
      return(units)
    }

    # Step 2: Redraw until the sample carries enough detections
    # for a model to be estimable
    for (attempt in seq_len(max_attempts)) {
      rows <- draw_once()

      if (min_detections <= 0L || is.null(response)) {
        return(units[rows])
      }

      if (sum(response[rows] > 0, na.rm = TRUE) >= min_detections) {
        return(units[rows])
      }
    }

    stop(
      "No spatially blocked draw reached ", min_detections,
      " detections in ", max_attempts, " attempts. The species ",
      "is probably too rare to bootstrap at this threshold.",
      call. = FALSE
    )
  }))
}

# 3. resampler_spatial_block() ----

#' The Registered Form of the Spatially Blocked Bootstrap
#'
#' Adds v2's redraw rule: a sample is redrawn for detections only
#' when the full data could meet the threshold in at least one
#' model region; otherwise the first draw is taken. Checked per
#' region, on the full data.
#'
#' @param frame The one-species frame.
#' @param iterations Integer vector.
#' @param seed Integer or NULL. This species' seed.
#' @param context List with `spec` and `response_name`.
#' @param min_detections,long_column,lat_column,max_attempts
#'   Settings from the spec's `resample` list.
#' @return A list of character vectors of survey unit ids.
#'
#' @example # Example usage of the function
#' # resampler_spatial_block(frame, 1:5, 42L, context,
#' #                         min_detections = 20L)
resampler_spatial_block <- function(
  frame, iterations, seed, context,
  min_detections = 0L, long_column = "long", lat_column = "lat",
  max_attempts = 100L
) {
  response <- frame[[context$response_name]]

  if (min_detections > 0) {
    viable <- any(vapply(context$spec$regions, function(region) {
      # A region whose filter names columns this frame lacks -
      # another region's, when the draw is not province-wide -
      # cannot be judged here, and does not count.
      if (!is.null(region$filter) &&
            !all(all.vars(region$filter) %in% names(frame))) {
        return(FALSE)
      }

      in_region <- if (is.null(region$filter)) {
        rep(TRUE, nrow(frame))
      } else {
        keep <- eval(rlang_f_rhs(region$filter), frame)
        !is.na(keep) & keep
      }

      sum(response[in_region] > 0, na.rm = TRUE) >= min_detections
    }, logical(1)))

    if (!viable) {
      min_detections <- 0L
    }
  }

  # `seed = NULL` is passed through deliberately: it means
  # unseeded, not the resampler's harness_seed() default.
  resample_spatial_block(
    frame = frame, iterations = iterations,
    long_column = long_column, lat_column = lat_column,
    min_detections = min_detections, response = response,
    max_attempts = max_attempts, seed = seed
  )
}

# 4. Register ----
register_resampler(
  "spatial_block", resampler_spatial_block,
  "Bootstrap within coarse spatial blocks (v2 plants, mammals)"
)

# End of script ----
