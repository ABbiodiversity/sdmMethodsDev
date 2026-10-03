# ---
# title: Harmonize the Test Dataset Lookups Across Taxa
# author: Brendan Casey
# created: 2026-10-03
# inputs:
#   in 0_data/test_dataset/lookup/ (all written by 01 and 06):
#     - modelled_species.csv, mammal_modelled_species.csv,
#       bird_modelled_species.csv
#     - bird_factor_levels.csv
#     - bird_veg_age_matrix.csv
#     - veg_, soil_, mammal_north_ and mammal_south_
#       prediction_matrix.csv
# outputs:
#   in 0_data/test_dataset/lookup/:
#     - species_queue.csv
#     - factor_levels.csv
#     - dataset_manifest.csv
#     - bird_north_prediction_matrix.csv
#     - bird_south_prediction_matrix.csv
# notes:
#   - The response tables were harmonized to one shape by 01; the
#     lookups were not. Each taxon lead's species queue arrived in
#     its own schema, factor levels were per taxon, and which file
#     belongs to which taxon was known only to the harness code.
#     This writes one form of each, so a method or a new taxon
#     never needs taxon-specific file logic.
#   - Offline. It reads only 0_data/test_dataset/, so it can be
#     re-run at any time. Run it after 01 and 06, whenever either
#     rebuilds lookup/. The source files are left in place.
#   - species_queue.csv: one row per taxon, region, season, tier
#     and species, with `order` the source list's own order, so a
#     narrowed run visits species in the order v2 would, and
#     `source_name` the name the source pipeline used. `tier`
#     separates mammals' full habitat models (20+ detections) from
#     their use-availability models (3+); it is "modelled"
#     elsewhere. `season` is empty for all but mammals.
#   - dataset_manifest.csv: one row per taxon and region, naming
#     the response file, the offset file, the key the taxon's rows
#     carry in covariates.csv, the habitat prediction grid, and
#     where any stored bootstrap draws are. The harness reads file
#     locations from here and nowhere else.
#   - The bird prediction grids. Every other taxon predicts onto a
#     grid with one row per habitat type; birds had none, because
#     v2 translates bird coefficients onto habitat types with a
#     model matrix (bird_veg_age_matrix.csv) rather than predicting
#     a grid. The north grid is that matrix rebuilt in covariate
#     space - each row's vegetation class from its dummy column,
#     its stand age and type flags from the age terms - and is
#     checked to reproduce the matrix exactly before it is
#     written. The south grid is one row per soil class. Terms the
#     matrix does not carry - roads, wells, water, survey method -
#     are at zero, or at the reference level for a factor, which
#     is what v2's translation assumes.
#   - The stored bootstrap draws keep their two layouts (one
#     table per taxon for birds, one file per species for the
#     plant-group taxa), because v2 drew them that way. The
#     manifest records which layout each taxon has.
# ---

# 1. Setup ----

## 1.1 Load packages ----
library(data.table) # CSV reading and writing (version: 1.16.4)

## 1.2 Resolve paths ----
project_root <- normalizePath(getwd(), winslash = "/")
lookup_dir <- file.path(
  project_root, "0_data", "test_dataset", "lookup"
)

if (!dir.exists(lookup_dir)) {
  stop(
    "Run this from the repository root; no ", lookup_dir,
    call. = FALSE
  )
}

read_lookup <- function(name) {
  path <- file.path(lookup_dir, name)

  if (!file.exists(path)) {
    stop(
      "Missing ", path, ". Run 01_harmonize_model_ready_v2.R ",
      "(and 06 for the bird matrix) first.",
      call. = FALSE
    )
  }

  as.data.frame(fread(path))
}

write_lookup <- function(frame, name) {
  fwrite(frame, file.path(lookup_dir, name), na = "")
  cat("Wrote ", name, " (", nrow(frame), " rows)\n", sep = "")
}

# 2. Species queue ----
# Three schemas become one. The logic is the one species.R used to
# apply on every read; it now runs once, here.

## 2.1 queue_rows() ----

#' Rows of the Unified Species Queue
#'
#' @param species Character vector.
#' @param taxon,region,order,tier,season Values recycled to the
#'   number of species.
#' @param source_name Character vector. The name the source
#'   pipeline uses, where it differs from the dataset's column
#'   name: mammals are "Black BearSummer" in v2's files and
#'   "BlackBear_Summer" here.
#' @return A data frame in the queue schema.
#'
#' @example # Example usage of the function
#' # queue_rows(c("ALFL", "AMRO"), "bird", "north", 1:2)
queue_rows <- function(
  species, taxon, region, order, tier = "modelled",
  season = NA_character_, source_name = species
) {
  if (length(species) == 0) {
    return(NULL)
  }

  data.frame(
    taxon = as.character(taxon),
    region = as.character(region),
    season = as.character(season),
    tier = as.character(tier),
    species = as.character(species),
    order = as.integer(order),
    source_name = as.character(source_name),
    stringsAsFactors = FALSE
  )
}

## 2.2 Plant groups ----
# One row per species, with membership of the north (veg) and
# south (soil) model sets as flags; each flag becomes a region.
plants <- read_lookup("modelled_species.csv")
north_plants <- plants[plants$in_veg_models, ]
south_plants <- plants[plants$in_soil_models, ]

## 2.3 Mammals ----
# Region and season are already columns; the two occurrence
# thresholds become tiers.
mammals <- read_lookup("mammal_modelled_species.csv")
full_mammals <- mammals[mammals$in_models, ]
ua_mammals <- mammals[mammals$in_ua_models, ]

## 2.4 Birds ----
# One row per species and region; the source order is the order
# within each region.
birds <- read_lookup("bird_modelled_species.csv")

species_queue <- rbind(
  queue_rows(
    north_plants$species, north_plants$taxon, "north",
    north_plants$veg_order
  ),
  queue_rows(
    south_plants$species, south_plants$taxon, "south",
    south_plants$soil_order
  ),
  queue_rows(
    full_mammals$species, "mammal", full_mammals$region,
    full_mammals$model_order, tier = "modelled",
    season = full_mammals$season,
    source_name = full_mammals$species_season
  ),
  queue_rows(
    ua_mammals$species, "mammal", ua_mammals$region,
    ua_mammals$ua_order, tier = "ua", season = ua_mammals$season,
    source_name = ua_mammals$species_season
  ),
  queue_rows(
    birds$species, "bird", birds$region,
    stats::ave(seq_len(nrow(birds)), birds$region, FUN = seq_along)
  )
)

## 2.5 Check and write ----
duplicated_rows <- duplicated(
  species_queue[, c("taxon", "region", "season", "tier", "species")]
)

if (any(duplicated_rows)) {
  stop(
    sum(duplicated_rows), " species appear twice in one queue.",
    call. = FALSE
  )
}

write_lookup(species_queue, "species_queue.csv")

# 3. Factor levels ----
# One table with a taxon column, so any taxon can record the
# level order of its categorical covariates the same way.
factor_files <- list.files(
  lookup_dir, pattern = "_factor_levels\\.csv$"
)

factor_levels <- do.call(rbind, lapply(factor_files, function(file) {
  levels_table <- read_lookup(file)
  data.frame(
    taxon = sub("_factor_levels\\.csv$", "", file),
    levels_table[, c("column", "level_order", "level")],
    stringsAsFactors = FALSE
  )
}))

write_lookup(factor_levels, "factor_levels.csv")

reference_level <- function(taxon, column) {
  rows <- factor_levels[
    factor_levels$taxon == taxon & factor_levels$column == column,
  ]
  rows$level[which.min(rows$level_order)]
}

levels_of <- function(taxon, column) {
  rows <- factor_levels[
    factor_levels$taxon == taxon & factor_levels$column == column,
  ]
  rows$level[order(rows$level_order)]
}

# 4. Bird prediction grids ----

## 4.1 North, rebuilt from v2's translation matrix ----
age_table <- read_lookup("bird_veg_age_matrix.csv")
age <- as.matrix(age_table[, -1])
rownames(age) <- age_table$type

vegc_levels <- levels_of("bird", "vegc")
dummies <- grep("^vegc", colnames(age), value = TRUE)

# Each row's class is the dummy set to 1, or the reference level
# where none is
vegc <- vapply(seq_len(nrow(age)), function(i) {
  hit <- dummies[age[i, dummies] == 1]

  if (length(hit) > 1) {
    stop("Matrix row ", rownames(age)[i], " sets two classes.",
         call. = FALSE)
  }

  if (length(hit) == 0) vegc_levels[1] else sub("^vegc", "", hit)
}, character(1))

# A type flag enters only through its interactions with age, so
# it is read back from them: the interaction divided by the age
# term, wherever age is non-zero. Where every age term is zero the
# flag cannot affect a prediction and is left at zero.
flags <- c("isCon", "isUpCon", "isBogFen", "isMix", "isPine",
           "isWSpruce")
age_terms <- c("wtAge", "wtAge2", "wtAge05")

flag_values <- sapply(flags, function(flag) {
  vapply(seq_len(nrow(age)), function(i) {
    for (term in age_terms) {
      if (age[i, term] != 0) {
        return(age[i, paste0(flag, ":", term)] / age[i, term])
      }
    }
    0
  }, numeric(1))
})

bird_north <- data.frame(
  VegType = rownames(age),
  vegc = vegc,
  age[, c("wtAge", "wtAge2", "wtAge05", "fcc2"), drop = FALSE],
  flag_values,
  # Absent from a pure stand of a habitat type
  road = 0, mWell = 0, mSoft = 0, mEnSft = 0, mTrSft = 0,
  mSeism = 0, pWater_KM = 0, pWater2_KM = 0,
  method = reference_level("bird", "method"),
  stringsAsFactors = FALSE,
  check.names = FALSE,
  row.names = NULL
)

### 4.1.1 Check the rebuild ----
# The grid must reproduce v2's matrix column for column, or the
# grid predictions would not be the quantity v2 translates to.
rebuilt <- stats::model.matrix(
  ~ vegc + wtAge + wtAge2 + wtAge05 + fcc2 +
    (wtAge + wtAge2 + wtAge05):(isCon + isUpCon + isBogFen +
                                  isMix + isPine + isWSpruce),
  transform(
    bird_north, vegc = factor(vegc, levels = vegc_levels)
  )
)
colnames(rebuilt) <- vapply(
  strsplit(sub("^\\(Intercept\\)$", "Intercept", colnames(rebuilt)),
           ":", fixed = TRUE),
  function(pieces) paste(sort(pieces), collapse = ":"),
  character(1)
)

difference <- max(abs(
  rebuilt[, colnames(age), drop = FALSE] - age
))

if (difference > 1e-12) {
  stop(
    "The rebuilt bird north grid does not reproduce ",
    "bird_veg_age_matrix.csv (largest difference ", difference,
    "). Not written.",
    call. = FALSE
  )
}

cat("Bird north grid reproduces v2's matrix (max diff ",
    format(difference), ")\n", sep = "")

write_lookup(bird_north, "bird_north_prediction_matrix.csv")

## 4.2 South, one row per soil class ----
soil_levels <- levels_of("bird", "soilc")

bird_south <- data.frame(
  VegType = soil_levels,
  soilc = soil_levels,
  paspen = 0,
  road = 0, mWell = 0, mSoft = 0, pWater_KM = 0, pWater2_KM = 0,
  method = reference_level("bird", "method"),
  stringsAsFactors = FALSE
)

write_lookup(bird_south, "bird_south_prediction_matrix.csv")

# 5. Dataset manifest ----
# Where each taxon's files are. A new taxon is added here, with
# its files, and needs no harness change.
plant_taxa <- c("vascular_plant", "bryophyte", "lichen", "mite")

manifest <- rbind(
  do.call(rbind, lapply(plant_taxa, function(taxon) {
    data.frame(
      taxon = taxon,
      region = c("north", "south"),
      response_file = paste0(taxon, ".csv"),
      offset_file = NA_character_,
      covariate_key = taxon,
      grid = c("veg", "soil"),
      bootstrap_ids = file.path("lookup", "v2_bootstrap_ids", taxon),
      bootstrap_layout = "per_species_rds",
      stringsAsFactors = FALSE
    )
  })),
  data.frame(
    taxon = "mammal",
    region = c("north", "south"),
    response_file = "mammal.csv",
    offset_file = NA_character_,
    covariate_key = c("mammal_north", "mammal_south"),
    grid = c("mammal_north", "mammal_south"),
    bootstrap_ids = NA_character_,
    bootstrap_layout = NA_character_,
    stringsAsFactors = FALSE
  ),
  data.frame(
    taxon = "bird",
    region = c("north", "south"),
    response_file = "bird.csv",
    offset_file = "bird_offsets.csv",
    covariate_key = "bird",
    grid = c("bird_north", "bird_south"),
    bootstrap_ids = file.path("lookup", "bird_bootstrap_ids.csv"),
    bootstrap_layout = "per_taxon_csv",
    stringsAsFactors = FALSE
  )
)

## 5.1 Check every named file exists ----
dataset_dir <- dirname(lookup_dir)
named <- c(
  file.path(dataset_dir, manifest$response_file),
  file.path(dataset_dir, stats::na.omit(manifest$offset_file)),
  file.path(lookup_dir,
            paste0(manifest$grid, "_prediction_matrix.csv"))
)
absent <- unique(named[!file.exists(named)])

if (length(absent) > 0) {
  stop(
    "The manifest names files that do not exist:\n  ",
    paste(absent, collapse = "\n  "),
    call. = FALSE
  )
}

write_lookup(manifest, "dataset_manifest.csv")

cat("\nLookups harmonized.\n")

# End of script ----
