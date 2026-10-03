# ---
# title: Resampling Scheme - Spatial Cross-Validation
# author: Brendan Casey
# created: 2026-09-09
# inputs: none
# outputs: registers the `spatial_cv` scheme
# notes:
#   - Holds out whole spatial blocks rather than random units, so
#     a held-out score is not inflated by a training unit sitting
#     beside its own test unit. This is the scheme a spatial
#     autocorrelation experiment needs; v2 has no equivalent.
#   - One "iteration" per fold. Each draw is that fold's training
#     units, so the fold's test units are exactly what the harness
#     scores as out-of-bag (`oob_` metrics). Set `n_bootstraps` to
#     the number of folds wanted.
# ---

# 1. Setup ----

## 1.1 Load packages ----
# Base R only.

# 2. resample_spatial_cv() ----

#' Split Survey Units into Spatial Cross-Validation Folds
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
  assignment <- with_seed(
    seed, sample(rep_len(seq_len(folds), length(present)))
  )
  fold_of_block <- assignment[match(blocks, present)]

  lapply(seq_len(folds), function(k) {
    list(
      train = units[!is.na(fold_of_block) & fold_of_block != k],
      test = units[!is.na(fold_of_block) & fold_of_block == k]
    )
  })
}

# 3. resampler_spatial_cv() ----

#' The Registered Form of Spatial Cross-Validation
#'
#' @param frame The one-species frame.
#' @param iterations Integer vector; its length is the number of
#'   folds.
#' @param seed Integer or NULL.
#' @param context Unused.
#' @param long_column,lat_column Settings from the spec's
#'   `resample` list.
#' @return A list of character vectors: each fold's training
#'   units.
#'
#' @example # Example usage of the function
#' # resampler_spatial_cv(frame, 1:5, 42L, list())
resampler_spatial_cv <- function(
  frame, iterations, seed, context,
  long_column = "long", lat_column = "lat"
) {
  splits <- resample_spatial_cv(
    frame, folds = length(iterations), long_column = long_column,
    lat_column = lat_column, seed = seed
  )

  lapply(splits, `[[`, "train")
}

# 4. Register ----
register_resampler(
  "spatial_cv", resampler_spatial_cv,
  "Spatial block cross-validation; each draw holds out one fold"
)

# End of script ----
