# ---
# title: Resampling Scheme - Precomputed Draws
# author: Brendan Casey
# created: 2026-09-09
# inputs:
#   in the test dataset (see harness/data_source.R), where
#   lookup/dataset_manifest.csv says (`bootstrap_ids`,
#   `bootstrap_layout`):
#     - per_taxon_csv: one table, one column per draw (birds)
#     - per_species_rds: one file per species (plant groups)
# outputs: registers the `precomputed` scheme
# notes:
#   - Replays v2's stored draws, so parity can be numerical rather
#     than distributional. Birds: one table keyed on `surveyid`.
#     Plant groups: per species, as v2 drew them (written by
#     _setup/07_harmonize_v2_plant_bootstrap_ids.R).
#   - The seed is ignored.
# ---

# 1. Setup ----

## 1.1 Load packages ----
library(data.table) # lookup table reading (version: 1.16.4)

# 2. resample_precomputed() ----

#' Read Bootstrap Ids the Source Pipeline Generated
#'
#' @param data_dir Character. The test dataset folder.
#' @param taxon Character. Taxon slug.
#' @param iterations Integer vector of bootstrap iterations.
#' @param id_column Character. The column in the covariate frame
#'   the stored ids refer to, when they are not survey unit ids.
#' @param frame A data frame carrying `survey_unit_id` and
#'   `id_column`, used to translate stored ids into survey unit
#'   ids. NULL when the stored ids are already unit ids.
#' @param species Character. The species, for per-species ids.
#' @param per_species Logical. Read the per-species layout.
#' @param unique_ids Logical. Keep each unit once per draw. v2's
#'   bird scripts select a draw with `%in%`, so a unit drawn twice
#'   is fitted once; the plant scripts index rows, so repeats
#'   count.
#' @return A list of character vectors, one per iteration.
#'
#' @example # Example usage of the function
#' # ids <- resample_precomputed(data_dir, "bird", 1:3,
#' #                             id_column = "surveyid",
#' #                             frame = frame, unique_ids = TRUE)
resample_precomputed <- function(
  data_dir,
  taxon,
  iterations,
  id_column = NULL,
  frame = NULL,
  species = NULL,
  per_species = FALSE,
  unique_ids = FALSE
) {
  # Step 1: Read the stored draws, as a list of id vectors
  stored <- read_stored_draws(data_dir, taxon, species, per_species)

  if (max(iterations) > length(stored)) {
    stop(
      taxon, " has ", length(stored), " precomputed bootstrap ",
      "iterations; ", max(iterations), " were requested.",
      call. = FALSE
    )
  }

  lapply(iterations, function(i) {
    ids <- stored[[i]]
    ids <- ids[!is.na(ids)]

    if (unique_ids) {
      ids <- unique(ids)
    }

    # Step 2: Translate other keys (birds) to survey unit ids
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

## 2.1 read_stored_draws() ----

#' Read One Taxon's or Species' Stored Draws
#'
#' Cached: the bird draw table (~38 MB) is otherwise re-read per
#' species.
#'
#' @param data_dir,taxon,species,per_species As in
#'   resample_precomputed().
#' @return A list of id vectors, one per stored draw.
#'
#' @example # Example usage of the function
#' # length(read_stored_draws(data_dir, "bird", NULL, FALSE))
read_stored_draws <- function(data_dir, taxon, species, per_species) {
  location <- manifest_entry(data_dir, taxon)$bootstrap_ids

  if (is.na(location)) {
    stop(
      "The dataset manifest records no stored bootstrap draws ",
      "for ", taxon, ". Use a scheme that draws them, such as ",
      "spatial_block.",
      call. = FALSE
    )
  }

  if (per_species) {
    path <- file.path(data_dir, location, paste0(species, ".rds"))

    if (is.null(species) || !file.exists(path)) {
      stop(
        "No stored v2 bootstrap ids for ", taxon, " ",
        species, ":\n  ", path,
        "\nRun 1_code/_setup/07_harmonize_v2_plant_bootstrap_ids.R",
        " for this species, or use the spatial_block scheme.",
        call. = FALSE
      )
    }

    stored <- readRDS(path)

    # v2 stores a species' draws as a matrix, units by draws
    if (is.matrix(stored)) {
      stored <- lapply(seq_len(ncol(stored)), function(j) stored[, j])
    }

    return(stored)
  }

  path <- file.path(data_dir, location)

  if (!file.exists(path)) {
    stop(
      "No precomputed bootstrap ids for ", taxon, ":\n  ", path,
      "\nUse a different resampling scheme, or generate them.",
      call. = FALSE
    )
  }

  cached_read(path, function(p) as.list(fread(p)))
}

# 3. resampler_precomputed() ----

#' The Registered Form of the Precomputed Scheme
#'
#' @param frame The one-species frame.
#' @param iterations Integer vector.
#' @param seed Ignored; the draws are stored.
#' @param context List with `data_dir`, `taxon` and `species`.
#' @param id_column,per_species,unique_ids Settings from the
#'   spec's `resample` list; see resample_precomputed().
#' @return A list of character vectors of survey unit ids.
#'
#' @example # Example usage of the function
#' # resampler_precomputed(frame, 1:5, NULL, context,
#' #                       id_column = "surveyid")
resampler_precomputed <- function(
  frame, iterations, seed, context,
  id_column = NULL, per_species = FALSE, unique_ids = FALSE
) {
  resample_precomputed(
    data_dir = context$data_dir, taxon = context$taxon,
    iterations = iterations, id_column = id_column, frame = frame,
    species = context$species, per_species = per_species,
    unique_ids = unique_ids
  )
}

# 4. Register ----
register_resampler(
  "precomputed", resampler_precomputed,
  "Replay draws stored with the dataset (v2 birds; plant v2_ids)"
)

# End of script ----
