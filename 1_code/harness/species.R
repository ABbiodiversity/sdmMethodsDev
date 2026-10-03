# ---
# title: List and Select Focal Species
# author: Brendan Casey
# created: 2026-09-09
# inputs:
#   in 0_data/test_dataset/lookup/:
#     - species_queue.csv, from _setup/09_harmonize_lookups.R
# outputs: none; returns objects in memory
# notes:
#   - One species queue for every taxon, in one schema: taxon,
#     region, season, tier, species, order and source_name. The
#     three taxon leads' lookups are flattened into it once, by
#     _setup/09, so an experiment asks for species the same way
#     whatever the taxon.
#   - `tier` separates a taxon's model classes where it has them -
#     mammals fit a full habitat model for species with at least
#     20 detections and a use-availability model for those with
#     at least 3 - and is "modelled" elsewhere. `season` is empty
#     for everything but mammals.
#   - `order` preserves each source list's own ordering, so a
#     narrowed run visits species in the order v2 would have.
#   - resolve_species() is the entry point an experiment uses to
#     pick focal species. Passing NULL takes every modelled
#     species; passing a vector takes those, and an unknown name
#     stops the run before any fitting rather than after.
# ---

# 1. Setup ----

## 1.1 Load packages ----
library(data.table) # lookup table reading (version: 1.16.4)

# 2. species_catalogue() ----

#' Read the Species Queue
#'
#' @param data_dir Character. Path to 0_data/test_dataset.
#' @param taxon Character. Keep one taxon, or NULL for all.
#' @return A data frame of taxon, region, season, tier, species,
#'   order and source_name.
#'
#' @example # Example usage of the function
#' # species_catalogue(data_dir, taxon = "bryophyte")
species_catalogue <- function(data_dir, taxon = NULL) {
  path <- file.path(data_dir, "lookup", "species_queue.csv")

  if (!file.exists(path)) {
    stop(
      "Species queue not found:\n  ", path,
      "\nRun 1_code/_setup/09_harmonize_lookups.R first.",
      call. = FALSE
    )
  }

  catalogue <- cached_read(path, function(p) {
    queue <- as.data.frame(fread(p, na.strings = ""))
    queue$season <- as.character(queue$season)
    queue
  })

  if (!is.null(taxon)) {
    known <- unique(catalogue$taxon)

    if (!taxon %in% known) {
      stop(
        "Unknown taxon `", taxon, "`. Taxa in the catalogue: ",
        paste(known, collapse = ", "),
        call. = FALSE
      )
    }

    catalogue <- catalogue[catalogue$taxon == taxon, ]
    rownames(catalogue) <- NULL
  }

  catalogue
}

# 3. list_species() ----

#' List the Species Available for a Taxon
#'
#' What an experiment reads to decide which focal species to run.
#'
#' @param data_dir Character. Path to 0_data/test_dataset.
#' @param taxon Character. Taxon slug.
#' @param region Character. Restrict to one region, or NULL.
#' @param tier Character. Restrict to one model tier, or NULL.
#' @param season Character. Restrict to one season, or NULL.
#'   Only mammals have seasons, and a mammal spec is fitted for
#'   one; without this, a summer spec would also queue the
#'   `_Winter` species and fit them with summer weights.
#' @return A character vector of species names, in source order.
#'
#' @example # Example usage of the function
#' # head(list_species(data_dir, "bryophyte", "north"), 3)
#' # list_species(data_dir, "mammal", "north", season = "winter")
list_species <- function(
  data_dir,
  taxon,
  region = NULL,
  tier = NULL,
  season = NULL
) {
  catalogue <- species_catalogue(data_dir, taxon)

  if (!is.null(region)) {
    catalogue <- catalogue[catalogue$region == region, ]
  }

  if (!is.null(tier)) {
    catalogue <- catalogue[catalogue$tier == tier, ]
  }

  if (!is.null(season)) {
    catalogue <- catalogue[
      !is.na(catalogue$season) & catalogue$season == season,
    ]
  }

  catalogue <- catalogue[order(catalogue$order), ]

  unique(catalogue$species)
}

# 4. species_source_name() ----

#' The Name a Source Pipeline Used for a Species
#'
#' v2's files sometimes name a species differently from the
#' dataset's column: mammals are "Black BearSummer" there and
#' "BlackBear_Summer" here.
#'
#' @param data_dir Character. Path to 0_data/test_dataset.
#' @param taxon,species Character.
#' @return Character, the source name.
#'
#' @example # Example usage of the function
#' # species_source_name(data_dir, "mammal", "BlackBear_Summer")
species_source_name <- function(data_dir, taxon, species) {
  catalogue <- species_catalogue(data_dir, taxon)
  name <- unique(catalogue$source_name[catalogue$species == species])

  if (length(name) == 0) {
    stop(
      "`", species, "` is not in the ", taxon, " species queue.",
      call. = FALSE
    )
  }

  name[1]
}

# 5. resolve_species() ----

#' Choose the Focal Species for a Run
#'
#' NULL means every species the queue declares as modelled. A
#' character vector means those species, and an unknown name
#' stops the run here rather than failing inside a bootstrap
#' hours later.
#'
#' @param species Character vector of species, or NULL for all.
#' @param data_dir Character. Path to 0_data/test_dataset.
#' @param taxon Character. Taxon slug.
#' @param region Character. Restrict to one region, or NULL.
#' @param tier Character. Restrict to one model tier, or NULL.
#' @return A character vector of species, in source order.
#'
#' @example # Example usage of the function
#' # resolve_species(NULL, data_dir, "mite", region = "north")
#' # resolve_species(c("Oppiella.nova"), data_dir, "mite")
resolve_species <- function(
  species,
  data_dir,
  taxon,
  region = NULL,
  tier = NULL
) {
  available <- list_species(data_dir, taxon, region, tier)

  if (is.null(species)) {
    return(available)
  }

  if (!is.character(species) || length(species) == 0) {
    stop(
      "`species` must be a character vector or NULL.",
      call. = FALSE
    )
  }

  unknown <- setdiff(species, available)

  if (length(unknown) > 0) {
    stop(
      length(unknown), " species not modelled for ", taxon,
      if (is.null(region)) "" else paste0(" (", region, ")"),
      ":\n  ",
      paste(utils::head(unknown, 10), collapse = "\n  "),
      "\nSee list_species() for what is available.",
      call. = FALSE
    )
  }

  # Intersecting rather than reordering keeps the source order,
  # so a narrowed run visits species in the sequence v2 would.
  intersect(available, species)
}

# 6. taxon_values() ----

#' Read a Named Vector's Entries for One Taxon
#'
#' The convention an experiment uses to select species and
#' covariates: a named character vector whose names are taxa.
#' Names may repeat, so several entries can apply to the same
#' taxon, and an unnamed entry applies to every taxon.
#'
#' \preformatted{
#' species <- c(
#'   lichen = "Alectoria.sarmentosa",
#'   lichen = "Bryoria.fremontii",
#'   mite   = "Oppiella.nova"
#' )
#' }
#'
#' @param x A named character vector, or NULL.
#' @param taxon Character. The taxon to read.
#' @return A character vector of the entries that apply, or NULL
#'   when none do. NULL means "no selection", which callers read
#'   as "everything", so an empty result is never an empty
#'   selection.
#'
#' @example # Example usage of the function
#' # taxon_values(c(lichen = "a", mite = "b"), "lichen")
#' # taxon_values(c("shared", lichen = "a"), "mite")
taxon_values <- function(x, taxon) {
  if (is.null(x) || length(x) == 0) {
    return(NULL)
  }

  labels <- names(x)

  # A wholly unnamed vector applies to every taxon
  if (is.null(labels)) {
    return(unname(x))
  }

  keep <- is.na(labels) | labels == "" | labels == taxon
  out <- unname(x[keep])

  if (length(out) == 0) {
    return(NULL)
  }

  out
}

# End of script ----
