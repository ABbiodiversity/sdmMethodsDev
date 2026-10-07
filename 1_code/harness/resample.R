# ---
# title: Resampling - Seeds, Blocks and Dispatch
# author: Brendan Casey
# created: 2026-09-09
# inputs: none
# outputs: none; returns objects in memory
# notes:
#   - Shared resampling plumbing: seeding, spatial blocks, and
#     resample_for_species(), which dispatches to a scheme in
#     1_code/methods/resampling/. Every scheme returns a list of
#     survey unit id vectors, one per draw.
#   - Seeds default to harness_seed(), not NULL. v2 set no seed,
#     so parity with v2 can only be distributional (see the
#     parity ledger in docs/framework_design.md).
# ---

# 1. Setup ----

## 1.1 Load packages ----
library(data.table) # lookup table reading (version: 1.16.4)

# 2. Seeding ----

## 2.1 harness_seed() ----

#' The Default Random Seed
#'
#' Used unless a run sets its own seed. Deliberately departs from
#' v2, which seeded nothing and so does not reproduce itself.
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
#' A shared seed would give every species identical draws. A
#' per-species seed keeps them independent, as in v2, and stable
#' when other species are added to or dropped from a run. The
#' rolling hash stays below 2^53, so it is exact in double
#' precision on every platform. Region is left out of the key
#' because v2 draws once per species across the province.
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
#' Restoring the caller's state keeps resampling from changing
#' any later random call in the session.
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
    # Restore the generator first: setting it reseeds
    suppressWarnings(do.call(RNGkind, as.list(old_kind)))

    if (had_state) {
      assign(".Random.seed", old_state, envir = env)
    } else if (exists(".Random.seed", envir = env,
                      inherits = FALSE)) {
      rm(".Random.seed", envir = env)
    }
  }, add = TRUE)

  # Name R's default generator explicitly; a package (e.g. a
  # parallel backend) may have switched the session's
  set.seed(
    seed, kind = "Mersenne-Twister", normal.kind = "Inversion",
    sample.kind = "Rejection"
  )

  code
}

# 3. spatial_blocks() ----

#' Cut Survey Units into Coarse Spatial Blocks
#'
#' Default cut points are the v2 plant grid.
#'
#' @param long,lat Numeric vectors of coordinates.
#' @param long_breaks,lat_breaks Numeric vectors of cut points.
#' @return A character vector of block labels, one per unit.
#'   Plain letters (or `b1`, `b2`, ... beyond 26), not interval
#'   notation, so labels are safe in regexes and file names.
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
#' Passes the scheme every `spec$resample` setting except
#' `scheme`, `seed` and `scope`, which the harness consumes.
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
