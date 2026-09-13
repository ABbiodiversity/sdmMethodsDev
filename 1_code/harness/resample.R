# ---
# title: Resampling Schemes
# author: Brendan Casey
# created: 2026-09-09
# inputs:
#   in 0_data/test_dataset/lookup/:
#     - <taxon>_bootstrap_ids.csv (where one is precomputed)
# outputs: none; returns objects in memory
# notes:
#   - Produces the survey units one model fit sees. Every scheme
#     returns the same thing - a character vector of survey unit
#     ids, with replacement where the scheme resamples - so the
#     fitting loop does not know which scheme it is running.
#   - Three schemes. `precomputed` reads ids the source pipeline
#     already generated, which is how birds reach parity.
#     `spatial_block` reproduces the plant bootstrap: resample
#     sites with replacement within coarse latitude and longitude
#     blocks, so a draw keeps the geographic spread rather than
#     drifting toward whichever region is best surveyed.
#     `spatial_cv` holds out whole blocks, which is the scheme a
#     spatial autocorrelation experiment needs and which v2 has
#     no equivalent of.
#   - Iteration 1 of a bootstrap is the complete data by
#     convention, matching v2, so the first fit of every run is
#     the full-data fit.
#   - v2 sets no seed, so v2 is not reproducible against itself:
#     two v2 runs give different coefficients. Strict numerical
#     parity is impossible by construction, and a parity check
#     can only ever show distributional agreement.
#   - `seed` therefore defaults to harness_seed() rather than to
#     NULL. Reproducibility is worth more than bit-matching a
#     behaviour that does not reproduce itself. Pass NULL to
#     restore the v2 behaviour explicitly. See the parity ledger
#     in docs/framework_design.md.
# ---

# 1. Setup ----

## 1.1 Load packages ----
library(data.table) # lookup table reading (version: 1.16.4)

# 2. harness_seed() ----

#' The Default Random Seed
#'
#' Every scheme that draws at random seeds from this unless told
#' otherwise, so two runs of the same configuration produce the
#' same result. v2 seeded nothing, so its runs do not reproduce
#' even against themselves; that is the behaviour this default
#' deliberately departs from.
#'
#' The value is recorded in each run's meta.json, so a result can
#' be traced back to the draw that produced it.
#'
#' @return An integer.
#'
#' @example # Example usage of the function
#' # harness_seed()
harness_seed <- function() {
  20260909L
}

# 3. spatial_blocks() ----

#' Cut Survey Units into Coarse Spatial Blocks
#'
#' Both the bootstrap and the spatial cross-validation scheme
#' need a block label per survey unit. The default cut points are
#' the v2 plant grid.
#'
#' @param long,lat Numeric vectors of coordinates.
#' @param long_breaks,lat_breaks Numeric vectors of cut points.
#' @return A character vector of block labels, one per unit.
#'   Labels are plain letters rather than interval notation,
#'   because a label carrying brackets and commas cannot be used
#'   in a regular expression or a file name.
#'
#' @example # Example usage of the function
#' # blocks <- spatial_blocks(frame$long, frame$lat)
#' # table(blocks)
spatial_blocks <- function(
  long,
  lat,
  long_breaks = c(-121, -116, -112, -109),
  lat_breaks = c(48, 51, 54, 57, 61)
) {
  cells <- interaction(
    droplevels(cut(long, long_breaks)),
    droplevels(cut(lat, lat_breaks)),
    sep = "::",
    drop = TRUE
  )

  present <- unique(cells[!is.na(cells)])

  if (length(present) > length(letters)) {
    labels <- paste0("b", seq_along(present))
  } else {
    labels <- letters[seq_along(present)]
  }

  labels[match(cells, present)]
}

# 4. resample_precomputed() ----

#' Read Bootstrap Ids the Source Pipeline Generated
#'
#' @param data_dir Character. Path to 0_data/test_dataset.
#' @param taxon Character. Taxon slug.
#' @param iterations Integer vector of bootstrap iterations.
#' @param id_column Character. The column in the covariate frame
#'   the stored ids refer to, when they are not survey unit ids.
#' @param frame A data frame carrying `survey_unit_id` and
#'   `id_column`, used to translate stored ids into survey unit
#'   ids. NULL when the stored ids are already unit ids.
#' @return A list of character vectors, one per iteration.
#'
#' @example # Example usage of the function
#' # ids <- resample_precomputed(data_dir, "bird", 1:3,
#' #                             id_column = "surveyid",
#' #                             frame = md$covariates)
resample_precomputed <- function(
  data_dir,
  taxon,
  iterations,
  id_column = NULL,
  frame = NULL
) {
  path <- file.path(
    data_dir, "lookup", paste0(taxon, "_bootstrap_ids.csv")
  )

  if (!file.exists(path)) {
    stop(
      "No precomputed bootstrap ids for ", taxon, ":\n  ", path,
      "\nUse a different resampling scheme, or generate them.",
      call. = FALSE
    )
  }

  stored <- fread(path)
  columns <- names(stored)

  if (max(iterations) > length(columns)) {
    stop(
      taxon, " has ", length(columns), " precomputed bootstrap ",
      "iterations; ", max(iterations), " were requested.",
      call. = FALSE
    )
  }

  lapply(iterations, function(i) {
    ids <- stored[[columns[i]]]
    ids <- ids[!is.na(ids)]

    # Step 1: Translate to survey unit ids when the stored ids
    # are a different key, which is how the bird ids are stored
    if (is.null(id_column)) {
      return(as.character(ids))
    }

    if (is.null(frame) || !id_column %in% names(frame)) {
      stop(
        "Translating precomputed ids needs a frame carrying `",
        id_column, "`.",
        call. = FALSE
      )
    }

    matched <- match(ids, frame[[id_column]])
    as.character(frame$survey_unit_id[matched[!is.na(matched)]])
  })
}

# 5. resample_spatial_block() ----

#' Draw a Spatially Blocked Bootstrap
#'
#' Resamples survey units with replacement within each spatial
#' block, so every block keeps its original number of units and
#' the draw keeps the geographic spread of the survey.
#'
#' Iteration 1 is the complete data, matching v2.
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
#' @param seed Integer or NULL. Defaults to harness_seed(), so a
#'   run reproduces. NULL leaves the stream unseeded, which is
#'   what v2 did.
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

  if (!is.null(seed)) {
    set.seed(seed)
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

  lapply(iterations, function(i) {
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
  })
}

# 6. resample_spatial_cv() ----

#' Split Survey Units into Spatial Cross-Validation Folds
#'
#' Holds out whole spatial blocks rather than random units, so a
#' held-out score is not inflated by a training unit sitting
#' beside its own test unit. This is the scheme a spatial
#' autocorrelation experiment needs; v2 has no equivalent.
#'
#' @param frame A data frame with `survey_unit_id` and the
#'   coordinate columns.
#' @param folds Integer. Number of folds.
#' @param long_column,lat_column Character. Coordinate columns.
#' @param seed Integer or NULL. Defaults to harness_seed().
#' @return A list of lists, each with `train` and `test`
#'   character vectors of survey unit ids.
#'
#' @example # Example usage of the function
#' # cv <- resample_spatial_cv(frame, folds = 5, seed = 42)
#' # length(cv[[1]]$train)
resample_spatial_cv <- function(
  frame,
  folds = 5L,
  long_column = "long",
  lat_column = "lat",
  seed = harness_seed()
) {
  if (!is.null(seed)) {
    set.seed(seed)
  }

  units <- as.character(frame$survey_unit_id)
  blocks <- spatial_blocks(
    frame[[long_column]], frame[[lat_column]]
  )
  present <- unique(blocks[!is.na(blocks)])

  if (length(present) < folds) {
    stop(
      "Only ", length(present), " spatial block(s) present; ",
      folds, " folds were asked for. Use finer block breaks or ",
      "fewer folds.",
      call. = FALSE
    )
  }

  # Step 1: Deal whole blocks into folds, so no fold shares a
  # block with another
  assignment <- sample(rep_len(seq_len(folds), length(present)))
  fold_of_block <- assignment[match(blocks, present)]

  lapply(seq_len(folds), function(k) {
    list(
      train = units[!is.na(fold_of_block) & fold_of_block != k],
      test = units[!is.na(fold_of_block) & fold_of_block == k]
    )
  })
}

# 7. resample_units() ----

#' Produce the Survey Units for Each Model Fit
#'
#' The single entry point the fitting loop calls. Dispatches on
#' the scheme name so a spec names a scheme rather than calling
#' one.
#'
#' @param scheme Character. "precomputed", "spatial_block" or
#'   "spatial_cv".
#' @param frame A data frame with `survey_unit_id`.
#' @param iterations Integer vector of iterations, or the number
#'   of folds for spatial_cv.
#' @param ... Passed to the scheme's own function.
#' @return For the bootstrap schemes, a list of character vectors
#'   of survey unit ids. For spatial_cv, a list of train and test
#'   splits.
#'
#' @example # Example usage of the function
#' # resample_units("spatial_block", frame, 1:10, seed = 42)
resample_units <- function(scheme, frame, iterations, ...) {
  switch(
    scheme,
    precomputed = resample_precomputed(
      iterations = iterations, frame = frame, ...
    ),
    spatial_block = resample_spatial_block(
      frame = frame, iterations = iterations, ...
    ),
    spatial_cv = resample_spatial_cv(
      frame = frame, folds = length(iterations), ...
    ),
    stop(
      "Unknown resampling scheme `", scheme, "`. Use ",
      "\"precomputed\", \"spatial_block\" or \"spatial_cv\".",
      call. = FALSE
    )
  )
}

# End of script ----
