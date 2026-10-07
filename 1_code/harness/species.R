# ---
# title: List and Select Focal Species
# author: Brendan Casey
# created: 2026-09-09
# inputs:
#   in the test dataset's lookup/ (see data_source.R):
#     - species_queue.csv, from _setup/09_harmonize_lookups.R
# outputs: none; returns objects in memory
# notes:
#   - One queue for every taxon, flattened from the taxon leads'
#     lookups by _setup/09. `tier` separates model classes where a
#     taxon has them (mammals) and is "modelled" elsewhere;
#     `season` is empty except for mammals; `order` keeps v2's
#     species order.
# ---

# 1. Setup ----

## 1.1 Load packages ----
library(data.table) # lookup table reading (version: 1.16.4)

# 2. species_catalogue() ----

#' Read the Species Queue
#'
#' @param data_dir Character. The test dataset folder.
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
#' @param data_dir Character. The test dataset folder.
#' @param taxon Character. Taxon slug.
#' @param region Character. Restrict to one region, or NULL.
#' @param tier Character. Restrict to one model tier, or NULL.
#' @param season Character. Restrict to one season, or NULL.
#'   Mammal specs must pass it, or a summer spec would also queue
#'   the `_Winter` species and fit them with summer weights.
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
#' @param data_dir Character. The test dataset folder.
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
#' NULL means every modelled species. An unknown name stops the
#' run here rather than hours later inside a bootstrap.
#'
#' @param species Character vector of species, or NULL for all.
#' @param data_dir Character. The test dataset folder.
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

  # Keeps source (v2) order rather than the caller's
  intersect(available, species)
}

# 6. taxon_values() ----

#' Read a Named Vector's Entries for One Taxon
#'
#' Experiments select species and covariates with a character
#' vector named by taxon. Names may repeat; unnamed entries apply
#' to every taxon.
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
#'   when none do. Callers read NULL as "everything".
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
