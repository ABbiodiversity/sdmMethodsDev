# ---
# title: Resampling - Seeds, Blocks and Dispatch
# author: Brendan Casey
# created: 2026-09-09
# inputs: none
# outputs: none; returns objects in memory
# notes:
#   - Produces the survey units one model fit sees. Every scheme
#     returns the same thing - a list of character vectors of
#     survey unit ids, one per draw, with replacement where the
#     scheme resamples - so the fitting loop does not know which
#     scheme it is running.
#   - The schemes themselves live in 1_code/methods/resampling/:
#     `precomputed`, `spatial_block` and `spatial_cv`. This file
#     holds what they share - seeding and spatial blocks - and
#     resample_for_species(), which looks a scheme up by name.
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
#   - An experiment sets one base seed. Each species draws from
#     its own seed, derived from that base and the species name
#     by species_seed(), so species are resampled independently
#     as in v2, and a species' draws do not change when others
#     are added to or removed from a run.
#   - Seeding never leaks. with_seed() restores the caller's
#     random state on exit, so resampling does not change what
#     any later random call in the session produces.
# ---

# 1. Setup ----

## 1.1 Load packages ----
library(data.table) # lookup table reading (version: 1.16.4)

# 2. Seeding ----

## 2.1 harness_seed() ----

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

## 2.2 species_seed() ----

#' Derive One Species' Seed from the Experiment's Base Seed
#'
#' Resetting every species to the same seed would give every
#' species the same draws, which v2 did not do and which
#' correlates results across species. Deriving a seed per species
#' keeps one number in charge of the run while giving each
#' species its own stream.
#'
#' The species key is hashed with a polynomial rolling hash, taken
#' modulo a prime below the integer maximum, and added to the
#' base. Every intermediate value stays below 2^53, so the
#' arithmetic is exact in double precision and the result is the
#' same on every platform.
#'
#' Region is deliberately not part of the key. v2 draws once per
#' species across the province, and a species should keep the
#' same draws whichever regions a run includes.
#'
#' @param base Integer or NULL. The experiment's base seed. NULL
#'   leaves the draw unseeded, which is what v2 did.
#' @param taxon Character. Taxon slug.
#' @param species Character. Species name.
#' @return An integer seed, or NULL when `base` is NULL.
#'
#' @example # Example usage of the function
#' # species_seed(20260909L, "lichen", "Physcia.adscendens")
#' # species_seed(NULL, "lichen", "Physcia.adscendens") # NULL
species_seed <- function(base, taxon, species) {
  if (is.null(base)) {
    return(NULL)
  }

  if (!is.numeric(base) || length(base) != 1L || is.na(base)) {
    stop("A base seed must be a single number.", call. = FALSE)
  }

  modulus <- 2147483629 # largest prime below .Machine$integer.max
  hash <- 0

  for (code in utf8ToInt(paste(taxon, species, sep = "::"))) {
    hash <- (hash * 31 + code) %% modulus
  }

  as.integer((base + hash) %% modulus)
}

## 2.3 with_seed() ----

#' Evaluate Code Under a Seed, Then Restore the Random State
#'
#' set.seed() changes the session's random state for everything
#' that follows. Restoring it on exit keeps resampling from
#' changing any later random call, and makes the result depend
#' only on the seed given here - not on the session's generator,
#' which is set explicitly to R's default.
#'
#' @param seed Integer or NULL. NULL evaluates the code without
#'   seeding.
#' @param code An expression. Evaluated lazily, after the seed is
#'   set.
#' @return The value of `code`.
#'
#' @example # Example usage of the function
#' # with_seed(42, sample(10))
with_seed <- function(seed, code) {
  if (is.null(seed)) {
    return(code)
  }

  env <- globalenv()
  had_state <- exists(".Random.seed", envir = env, inherits = FALSE)
  old_state <- if (had_state) get(".Random.seed", envir = env)
  old_kind <- RNGkind()

  on.exit({
    # The generator first, because setting it reseeds; then the
    # caller's exact state on top
    suppressWarnings(do.call(RNGkind, as.list(old_kind)))

    if (had_state) {
      assign(".Random.seed", old_state, envir = env)
    } else if (exists(".Random.seed", envir = env,
                      inherits = FALSE)) {
      rm(".Random.seed", envir = env)
    }
  }, add = TRUE)

  # R's default generator, named rather than assumed, so the draws
  # are the same whatever generator the session or a package (a
  # parallel backend, say) has switched to
  set.seed(
    seed, kind = "Mersenne-Twister", normal.kind = "Inversion",
    sample.kind = "Rejection"
  )

  code
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


# 4. resample_for_species() ----

#' Draw the Resampling Sets for One Species
#'
#' Looks the spec's scheme up in the registry and passes it the
#' spec's `resample` settings. `scheme`, `seed` and `scope` are
#' read here and by run_spec(), not by a scheme.
#'
#' @param spec A taxon spec.
#' @param frame The one-species frame, one row per unit that can
#'   be drawn.
#' @param iterations Integer vector.
#' @param data_dir Character.
#' @param seed Integer or NULL. This species' seed, from
#'   species_seed(). NULL leaves the draw unseeded.
#' @param species Character. Names the stored draws where they
#'   are kept per species.
#' @return A list of character vectors of survey unit ids.
#'
#' @example # Example usage of the function
#' # resample_for_species(spec, frame, 1:10, data_dir,
#' #                      seed = 123L, species = "Physcia.adscendens")
resample_for_species <- function(
  spec, frame, iterations, data_dir, seed = NULL, species = NULL
) {
  scheme <- get_method("resampler", spec$resample$scheme)
  settings <- spec$resample[
    setdiff(names(spec$resample), c("scheme", "seed", "scope"))
  ]

  context <- list(
    data_dir = data_dir,
    taxon = spec$taxon,
    species = species,
    spec = spec,
    response_name = spec$response_name %||% "response"
  )

  do.call(scheme, c(
    list(
      frame = frame, iterations = iterations, seed = seed,
      context = context
    ),
    settings
  ))
}

# End of script ----
