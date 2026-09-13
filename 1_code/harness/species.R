# ---
# title: List and Select Focal Species
# author: Brendan Casey
# created: 2026-09-09
# inputs:
#   in 0_data/test_dataset/lookup/:
#     - modelled_species.csv         (plant groups)
#     - mammal_modelled_species.csv
#     - bird_modelled_species.csv
# outputs: none; returns objects in memory
# notes:
#   - The three source lookups have three different schemas, one
#     per taxon lead. This flattens them to one, so an experiment
#     asks for species the same way whatever the taxon.
#   - The unified schema is taxon, species, region, tier, order
#     and season. `tier` separates a taxon's model classes where
#     it has them - mammals fit a full habitat model for species
#     with at least 20 detections and a use-availability model
#     for those with at least 3 - and is "modelled" elsewhere.
#     `season` is NA for everything but mammals.
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

# 2. Source lookup declarations ----

## 2.1 species_lookup_files() ----

#' Name Each Taxon's Species Lookup
#'
#' @return A named character vector of file names within
#'   0_data/test_dataset/lookup/.
#'
#' @example # Example usage of the function
#' # species_lookup_files()[["mammal"]]
species_lookup_files <- function() {
  c(
    plants = "modelled_species.csv",
    mammal = "mammal_modelled_species.csv",
    bird = "bird_modelled_species.csv"
  )
}

## 2.2 plant_taxa() ----

#' Name the Taxa Held in the Plant-Group Lookup
#'
#' "Plant group" names a file layout rather than a taxonomy: the
#' four share one survey design and one lookup, soil mites
#' included.
#'
#' @return A character vector of taxon slugs.
#'
#' @example # Example usage of the function
#' # plant_taxa()
plant_taxa <- function() {
  c("vascular_plant", "bryophyte", "lichen", "mite")
}

# 3. species_catalogue() ----

#' Flatten Every Species Lookup into One Table
#'
#' @param data_dir Character. Path to 0_data/test_dataset.
#' @param taxon Character. Keep one taxon, or NULL for all.
#' @return A data frame of taxon, species, region, tier, order
#'   and season.
#'
#' @example # Example usage of the function
#' # species_catalogue(data_dir, taxon = "bryophyte")
species_catalogue <- function(data_dir, taxon = NULL) {
  lookup_dir <- file.path(data_dir, "lookup")
  files <- species_lookup_files()

  read_lookup <- function(name) {
    path <- file.path(lookup_dir, files[[name]])

    if (!file.exists(path)) {
      stop(
        "Species lookup not found:\n  ", path,
        "\nRun 1_code/_setup/01_harmonize_model_ready_v2.R first.",
        call. = FALSE
      )
    }

    as.data.frame(fread(path))
  }

  parts <- list()

  # Step 1: Plant groups. One row per species, with membership
  # of the north (veg) and south (soil) model sets as flags, so
  # each flag becomes a region row.
  plants <- read_lookup("plants")

  parts$plants <- rbind(
    unified_rows(
      plants[plants$in_veg_models, ],
      taxon = plants$taxon[plants$in_veg_models],
      region = "north",
      order = plants$veg_order[plants$in_veg_models]
    ),
    unified_rows(
      plants[plants$in_soil_models, ],
      taxon = plants$taxon[plants$in_soil_models],
      region = "south",
      order = plants$soil_order[plants$in_soil_models]
    )
  )

  # Step 2: Mammals. Region and season are already columns, and
  # the two occurrence thresholds become tiers.
  mammals <- read_lookup("mammal")

  parts$mammal <- rbind(
    unified_rows(
      mammals[mammals$in_models, ],
      taxon = "mammal",
      region = mammals$region[mammals$in_models],
      order = mammals$model_order[mammals$in_models],
      tier = "modelled",
      season = mammals$season[mammals$in_models]
    ),
    unified_rows(
      mammals[mammals$in_ua_models, ],
      taxon = "mammal",
      region = mammals$region[mammals$in_ua_models],
      order = mammals$ua_order[mammals$in_ua_models],
      tier = "ua",
      season = mammals$season[mammals$in_ua_models]
    )
  )

  # Step 3: Birds. One row per species and region already.
  birds <- read_lookup("bird")

  parts$bird <- unified_rows(
    birds,
    taxon = "bird",
    region = birds$region,
    order = stats::ave(
      seq_len(nrow(birds)), birds$region, FUN = seq_along
    )
  )

  catalogue <- do.call(rbind, parts)
  rownames(catalogue) <- NULL

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

# 4. list_species() ----

#' List the Species Available for a Taxon
#'
#' What an experiment reads to decide which focal species to run.
#'
#' @param data_dir Character. Path to 0_data/test_dataset.
#' @param taxon Character. Taxon slug.
#' @param region Character. Restrict to one region, or NULL.
#' @param tier Character. Restrict to one model tier, or NULL.
#' @return A character vector of species names, in source order.
#'
#' @example # Example usage of the function
#' # head(list_species(data_dir, "bryophyte", "north"), 3)
list_species <- function(
  data_dir,
  taxon,
  region = NULL,
  tier = NULL
) {
  catalogue <- species_catalogue(data_dir, taxon)

  if (!is.null(region)) {
    catalogue <- catalogue[catalogue$region == region, ]
  }

  if (!is.null(tier)) {
    catalogue <- catalogue[catalogue$tier == tier, ]
  }

  catalogue <- catalogue[order(catalogue$order), ]

  unique(catalogue$species)
}

# 5. resolve_species() ----

#' Choose the Focal Species for a Run
#'
#' NULL means every species the source lookup declares as
#' modelled. A character vector means those species, and an
#' unknown name stops the run here rather than failing inside a
#' bootstrap hours later.
#'
#' Selection is how a trial run is shortened. Three species is a
#' smoke test; the full list is the parity run.
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
#'
#' covariates <- c(
#'   "climate_common",          # every taxon
#'   lichen = "topography"      # lichens as well
#' )
#' }
#'
#' One convention for both keeps the two selections symmetrical,
#' and lets a single vector configure a run across taxa without a
#' nested list.
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

# 7. Helpers ----

## 6.1 unified_rows() ----

#' Build Rows in the Unified Schema
#'
#' @param frame A data frame with a `species` column.
#' @param taxon,region,order,tier,season Values recycled to the
#'   number of rows in `frame`.
#' @return A data frame in the unified schema, or an empty one
#'   when `frame` has no rows.
#'
#' @example # Example usage of the function
#' # unified_rows(birds, "bird", birds$region, seq_len(nrow(birds)))
unified_rows <- function(
  frame,
  taxon,
  region,
  order,
  tier = "modelled",
  season = NA_character_
) {
  if (nrow(frame) == 0) {
    return(data.frame(
      taxon = character(0),
      species = character(0),
      region = character(0),
      tier = character(0),
      order = integer(0),
      season = character(0),
      stringsAsFactors = FALSE
    ))
  }

  data.frame(
    taxon = as.character(taxon),
    species = as.character(frame$species),
    region = as.character(region),
    tier = as.character(tier),
    order = as.integer(order),
    season = as.character(season),
    stringsAsFactors = FALSE
  )
}

# End of script ----
