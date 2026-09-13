# ---
# title: Harmonize the model_ready_v2 Snapshot into CSVs
# author: Brendan Casey
# created: 2026-09-05
# inputs:
#   from 0_data/data_snapshots/model_ready_v2/ on ABMI-DATA2:
#     - vascular-plant-model-data.Rdata
#     - bryophyte-model-data.Rdata
#     - lichen-model-data.Rdata
#     - mite-model-data.Rdata
#     - R Dataset SpTable for ABMI North mammal
#       coefficients 2024.RData
#     - R Dataset SpTable for ABMI South mammal
#       coefficients 2024.RData
#   from the ABMI Mammals shared drive:
#     - Lookup Tables/WildTrax Species Strings.RData
#   from the BirdModels shared drive, read-only:
#     - Data/Archive/2025/Stratified.Rdata
# outputs:
#   in 0_data/test_dataset/:
#     - sites.csv           one row per survey unit, all sources
#     - vascular_plant.csv  survey_unit_id + species columns
#     - bryophyte.csv       survey_unit_id + species columns
#     - lichen.csv          survey_unit_id + species columns
#     - mite.csv            survey_unit_id + species columns
#     - mammal.csv          survey_unit_id + species columns
#     - bird.csv            survey_unit_id + species counts
#     - bird_offsets.csv    survey_unit_id + QPAD log offsets
#     - covariates.csv      survey_unit_id + taxon + every
#                           covariate, all taxa in one table
#   in 0_data/test_dataset/lookup/:
#     - veg_prediction_matrix.csv   north habitat prediction grid
#     - soil_prediction_matrix.csv  south habitat prediction grid
#     - modelled_species.csv        which species each model set
#                                   is fitted for, per plant taxon
#     - mammal_<region>_prediction_matrix.csv
#     - mammal_modelled_species.csv
#     - mammal_climate_predictions.csv
#     - bird_modelled_species.csv   species x region work queue
#     - bird_bootstrap_ids.csv      the 100 bootstrap draws
#     - bird_factor_levels.csv      factor levels, source order
#     - covariate_columns.csv       which block each covariates
#                                   column came from, per taxon
# notes:
#   Source files use two incompatible survey designs, so
#   they are harmonized into one shared convention rather than
#   one table: every taxon CSV is `survey_unit_id` followed by
#   that taxon's species columns, and every identity, design and
#   location field is factored out into sites.csv. Join any taxon
#   CSV to sites.csv on survey_unit_id.
#
#   The response tables above carry detections only. The
#   covariate and lookup tables carry everything else the v2
#   hierarchical models regress against, so the modelling code in
#   the plant-group modules can run from 0_data/test_dataset/
#   alone rather than reaching back to the snapshot.
#
#   covariates.csv is keyed on survey_unit_id AND taxon, where
#   sites.csv is keyed on survey_unit_id alone. That is forced by
#   the source: on the 7001 quadrats vascular plant and mite
#   share, 154 of 162 vegetation columns and 58 of 59 soil
#   columns hold different values, while climate agrees to the
#   last digit. Bryophyte and lichen match vascular plant
#   exactly.
#
#   The covariates were never shared to begin with:
#   01a_data-standardization.R lifts each taxon's veg and soil
#   blocks wholesale from its own raw SpTable *_Quad.RData file,
#   so the four are four separate extractions. The quadrats
#   themselves are the same places - Lat, Long, Easting,
#   Northing and NSR are identical on every shared unit.
#
#   Where mite differs is concentrated in the Surr* surrounding
#   buffer terms: 20 columns carry 67 per cent of the differing
#   veg cells and 80 per cent of the soil ones. It is not a
#   footprint vintage, since every year from 2007 to 2022
#   disagrees. That points at a different spatial extraction
#   upstream, but the raw files are in neither this repository
#   nor the snapshot, so it cannot be confirmed here.
#
#   Either way they are two descriptions of one quadrat, and
#   choosing between them is not this script's call. Filter on
#   taxon before joining.
#
#   Its columns are the union across taxa, so each taxon fills
#   its own blocks and leaves the rest empty - about 16 per cent
#   of cells are populated. Drop the empty columns after
#   filtering to a taxon.
#
#   A name that more than one block carries is suffixed with its
#   block: the plant files spell 42 footprint terms the same way
#   in the veg and soil blocks, and 14 of those hold different
#   values because each is computed under its own landcover
#   framework. So `Crop_veg` and `Crop_soil` are both kept.
#   lookup/covariate_columns.csv maps every column back to the
#   block and the v2 spelling it came from.
#
#   Mammal covariates come from the same two SpTable files as
#   the mammal response, because those files are themselves the
#   output of the v2 scripts in 0_data/v2_scripts/mammals/. Their
#   embedded pred_matrix objects were checked against
#   prediction-matrix_north.csv and Prediction matrix for ABMI
#   South coefficients 2020.csv on the ABMI Mammals drive and are
#   identical, so no separate lookup is needed for them.
#
#   Mammals contribute two taxon values, mammal_north and
#   mammal_south, rather than one. They are separate models on
#   overlapping deployments - 512 location_project values appear
#   in both files - so their covariates cannot be pooled the way
#   the response is.
#
#   Birds come from one file, Stratified.Rdata, rather than from
#   the snapshot. It is the output of a stratification stage that
#   is not in 0_data/v2_scripts/birds/ - those scripts start at
#   06 and take it as given - so this script reads it where it
#   sits on the BirdModels drive and never writes there.
#
#   Birds need two things no other taxon does. Every survey has a
#   QPAD offset per species, written as bird_offsets.csv, which
#   is response-shaped rather than a covariate and is by far the
#   largest table here. And every survey is separately eligible
#   for the north and south models, so eligibility is two flags
#   in covariates.csv rather than one region in sites.csv; a
#   survey can feed both models, or neither.
#
#   Bird counts are integer point counts. Plants are 0/1 and
#   mammals are densities, so the three responses are on three
#   different scales and are not comparable across taxa without
#   the offsets and weights their own models apply.
#
#   Set SDM_BIRD_DATA to read Stratified.Rdata from elsewhere.
#
#   The prediction matrices come from the vegetation models
#   project on ABMI-DATA2, not from the snapshot, because the
#   snapshot's veg.pm lacks the four aggregate columns four of
#   the twelve vegetation models are predicted onto. Set
#   SDM_V2_LOOKUP to read them from elsewhere. If the folder is
#   unreachable the snapshot objects are used instead and
#   section 7.4 says so, because such a run cannot fit the
#   vegetation models.
#
#   Future improvement - the plant-group files are read twice,
#   once for the response and once for the covariates. That is
#   simpler to follow than threading one environment through both
#   readers, and this script runs once per snapshot.
# ---

# 1. Setup ----

## 1.1 Load packages ----
library(data.table)

## 1.2 Configure paths ----
project_root <- normalizePath(getwd(), winslash = "/")

# Directory containing the v2 model ready snapshot files on ABMI-DATA2
snapshot_dir <- Sys.getenv(
  "SDM_SNAPSHOT_V2",
  unset = paste0(
    "//ABMI-DATA2/science/sc/sdmMethodsDev/0_data/",
    "data_snapshots/model_ready_v2"
  )
)

# Output is the frozen test dataset itself, so it lands in
# 0_data/test_dataset/. That folder is otherwise read-only: this
# script is what writes it, by hand and once per snapshot, and
# every experiment then treats the result as fixed. The CSVs are
# gitignored along with the rest of 0_data/.
output_dir <- file.path(project_root, "0_data/test_dataset")

# Lookups sit in their own folder so the response and covariate
# tables stay the obvious contents of test_dataset/.
lookup_dir <- file.path(output_dir, "lookup")

## 1.3 Name the source files ----
# Plant-group files share one schema, mammal files another.
#
# "Plant group" names a file layout, not a taxonomy. It covers
# vascular plants, bryophytes, lichens and soil mites, because
# all four are surveyed on the same site-year-quadrant design
# and arrive in the same three-frame layout.
plant_files <- c(
  vascular_plant = "vascular-plant-model-data.Rdata",
  bryophyte = "bryophyte-model-data.Rdata",
  lichen = "lichen-model-data.Rdata",
  mite = "mite-model-data.Rdata"
)

mammal_files <- c(
  north = paste0(
    "R Dataset SpTable for ABMI North mammal ",
    "coefficients 2024.RData"
  ),
  south = paste0(
    "R Dataset SpTable for ABMI South mammal ",
    "coefficients 2024.RData"
  )
)

## 1.4 Name the plant-group non-species columns ----
# Plant-group frames are identity + species + site and climate.
# Species are whatever is left once the other two are named, so
# both are listed here rather than found by position: column
# order is an accident of how the files were built, and `Protocol`
# already sits last in two of the four files rather than with the
# site block it belongs to.

# The six identity columns every plant-group frame opens with.
plant_id_cols <- c(
  "SiteYearQu",
  "SiteYear",
  "Site",
  "Year",
  "QUAD",
  "OnOffGrid"
)

# Site, spatial and climate columns. The first 49 appear in all
# four files; `sampled` and `Protocol` are present in some only,
# and are listed so they cannot be mistaken for species.
plant_site_cols <- c(
  "Lat",
  "Long",
  "Elevation",
  "NR",
  "NSR",
  "LufName",
  "Easting",
  "Northing",
  "pAspen",
  "pAspen_NA",
  "MAT",
  "MWMT",
  "MCMT",
  "TD",
  "MAP",
  "MSP",
  "AHM",
  "SHM",
  "DD_0",
  "DD5",
  "DD_18",
  "DD18",
  "NFFD",
  "bFFP",
  "eFFP",
  "FFP",
  "PAS",
  "EMT",
  "EXT",
  "Eref",
  "CMD",
  "RH",
  "CMI",
  "DD1040",
  "bio9",
  "bio15",
  "HTV",
  "PET",
  "UTMX",
  "UTMY",
  "PS",
  "MTD",
  "Easting2",
  "Northing2",
  "EastingNorthing",
  "MAPPET",
  "MAT2",
  "CMDMAT",
  "MWMT2",
  "sampled",
  "Protocol"
)

# Of those, the fields sites.csv already carries. They are
# dropped from the climate covariate table so each value has one
# home, and the model-data loader joins them back from sites.csv
# under their v2 names.
plant_site_cols_in_sites <- c(
  "Lat",
  "Long",
  "Elevation",
  "NR",
  "NSR",
  "LufName",
  "Easting",
  "Northing"
)

# And the ones that are products of other stored columns. They
# are not written: the model-data loader recomputes them with the
# same expressions 01a_data-standardization.R used.
#
# Storing them would be worse than redundant. A CSV holds about
# 15 significant digits, so Northing lands within ~2e-9 of the
# source value; squaring it lifts that to ~0.05 in absolute
# terms. Written and read back independently, Northing2 would no
# longer be exactly Northing * Northing, and a model fitting both
# would see an inconsistent pair. Deriving keeps them consistent
# with whatever precision the stored columns carry.
plant_site_cols_derived <- c(
  "Easting2",
  "Northing2",
  "EastingNorthing",
  "MAPPET",
  "MAT2",
  "CMDMAT",
  "MWMT2"
)

## 1.5 Name the mammal column blocks ----
# The mammal files are one frame, `d`, holding design fields,
# species-season columns and covariates. The species span is
# given by the file's own first_sp_col/last_sp_col indices, and
# the rest is split by naming the two non-habitat blocks; what
# is left over is habitat. That is the same split-by-elimination
# the plant-group reader uses, and section 6.6 checks that the
# three blocks account for every column.

# Design and identity fields. sites.csv already carries these,
# so they are dropped from the covariate tables.
mammal_site_cols <- c(
  "project",
  "location",
  "SummerDays",
  "WinterDays",
  "Lat",
  "Long",
  "NearestSite",
  "NR",
  "NSR",
  "LUF",
  "Lured"
)

# Model covariates that are not habitat: climate, the aspen and
# Peace River terms, the subregion factor, the deployment key the
# climate predictions join on, and the seasonal model weights.
# Not every column is in both files - pAspen and PeaceRiver are
# south only, NSR1 north only.
mammal_climate_cols <- c(
  "AHM",
  "PET",
  "FFP",
  "MAP",
  "MAT",
  "MCMT",
  "MWMT",
  "TrueLat",
  "pAspen",
  "NSR1",
  "PeaceRiver",
  "location_project",
  "wt_summer",
  "wt_winter"
)

## 1.6 Name the mammal camera climate ----
# The SpTable files carry a climate block, but it is not the one
# the mammal models were fitted against. The v2 climate pipeline
# joins this file instead, and at matched deployments the two
# disagree by up to 531 mm of MAP - they are different
# extractions. This file is therefore the authority for the
# mammal climate block, and its columns replace the SpTable's
# rather than sitting beside them.
#
# It is also the only source of CMD and TD for mammals, which
# four of the nine v2 climate models need.
mammal_camera_climate_file <- Sys.getenv(
  "SDM_MAMMAL_CAMERA_CLIMATE",
  unset = paste0(
    "//ABMI-DATA2/science/sc/AB_data_v2023/sites/processed/",
    "climate/abmi-camera-climate_2023.Rdata"
  )
)

# What it supplies. Everything else in the file - coordinates,
# natural region, elevation - is already in sites.csv.
mammal_camera_climate_cols <- c(
  "pAspen", "MAT", "MWMT", "MCMT", "TD", "MAP", "MSP", "AHM",
  "SHM", "DD_0", "DD5", "DD_18", "DD18", "NFFD", "bFFP", "eFFP",
  "FFP", "PAS", "EMT", "EXT", "Eref", "CMD", "RH", "CMI",
  "DD1040", "bio9", "bio15", "HTV"
)

## 1.7 Name the mammal climate predictions ----
# The mammal habitat models take a climate offset rather than
# fitting climate themselves: 03_basic-models.R reads this file
# for both regions. It is produced by a separate climate
# pipeline, so it is copied in rather than derived here.
mammal_climate_pred_file <- Sys.getenv(
  "SDM_MAMMAL_CLIMATE_PRED",
  unset = paste0(
    "G:/Shared drives/ABMI Mammals/Results/Habitat Modeling/",
    "2024/Climate/Predictions/",
    "All Species Climate Predictions.csv"
  )
)

## 1.8 Name the v2 prediction-matrix lookups ----
# The v2 modelling scripts do not use the veg.pm and soil.pm
# objects carried in the snapshot. They read these two CSVs from
# the vegetation models project instead, and for veg the two are
# not the same grid. Over the same 43 habitat rows, the CSV adds
# Peatland, Mineral, Upland and CCR1234 - the aggregates that
# four of the twelve vegetation models are predicted onto - and
# drops MarshSwamp, CCPineR1, CCPine234, CCWhiteSpruceR1 and
# CCDecidMixedR1. The 51 columns they share hold identical
# values. The soil matrices are identical either way.
#
# So the CSVs are preferred, with the snapshot objects as the
# fallback if the drive is unreachable. Section 7.4 says which
# was used, because a fallback run cannot fit the vegetation
# models.
v2_lookup_dir <- Sys.getenv(
  "SDM_V2_LOOKUP",
  unset = paste0(
    "//ABMI-DATA2/science/sc/ToEmily/VegetationModels/",
    "0_data/lookup/prediction-matrix"
  )
)

v2_lookup_files <- c(
  veg_prediction_matrix = "veg-prediction-matrix-CC_2024.csv",
  soil_prediction_matrix = "soil-prediction-matrix_2024.csv"
)

## 1.9 Name the WildTrax species lookup ----
# The naming authority for mammal species.
wt_species_file <- Sys.getenv(
  "SDM_WT_SPECIES",
  unset = paste0(
    "G:/Shared drives/ABMI Mammals/Data/Lookup Tables/",
    "WildTrax Species Strings.RData"
  )
)

## 1.10 Name the bird data package ----
# One .Rdata holding every frame the bird models read: `covs`,
# `bird`, `off`, `boot` and `birdlist`. It is the output of the
# stratification stage, which is not in 0_data/v2_scripts/birds/
# - those start at 06 and take this file as given.
#
# It currently lives under Data/Archive/2025/ rather than at
# Data/, which is where 06, 07, 08 and 10 all look for it. That
# is a property of the shared drive, not of this script, so the
# path is set here rather than assumed.
#
# The BirdModels drive is read-only for this repository. Nothing
# below writes to it.
bird_data_file <- Sys.getenv(
  "SDM_BIRD_DATA",
  unset = paste0(
    "G:/.shortcut-targets-by-id/",
    "17Ymt13eHfKvIiuoMl6x-Kn74Z2uVbbzS/BirdModels/Data/",
    "Archive/2025/Stratified.Rdata"
  )
)

## 1.11 Name the bird covariate blocks ----
# Taken from the model definitions rather than guessed: every
# name below appears in a formula in 00.ClimateModels.R,
# 00.NorthModels.R or 00.SouthModels.R. Section 6.8 checks that
# the four blocks account for every column of `covs`.

# The climate stage. EMT is carried because it sits with the
# other climate normals in the source, but no formula uses it.
bird_climate_cols <- c(
  "MAP",
  "TD",
  "CMD",
  "FFP",
  "EMT"
)

# The north landcover stage. The human-footprint, method and
# water terms are shared with the south, so they appear in both
# blocks; each file is then the whole right-hand side of the
# models it feeds.
bird_veg_cols <- c(
  "vegc",
  "wtAge",
  "wtAge2",
  "wtAge05",
  "isCon",
  "isUpCon",
  "isBogFen",
  "isMix",
  "isPine",
  "isWSpruce",
  "fcc2",
  "road",
  "mWell",
  "mSoft",
  "mEnSft",
  "mTrSft",
  "mSeism",
  "method",
  "pWater_KM",
  "pWater2_KM"
)

# The south soil stage. A narrower footprint set than the north.
bird_soil_cols <- c(
  "soilc",
  "paspen",
  "road",
  "mWell",
  "mSoft",
  "method",
  "pWater_KM",
  "pWater2_KM"
)

# Design fields rather than covariates: which region each survey
# is eligible for, the model weights, the train/test split, the
# spatial block, and the keys. `year` here is the recoded model
# term, calendar year minus 1992; sites.csv carries the calendar
# year derived from date_time.
bird_design_cols <- c(
  "surveyid",
  "useNorth",
  "useSouth",
  "vegw",
  "soilw",
  "use",
  "block",
  "year",
  "method",
  "locationid",
  "gisid",
  "organization",
  "project_id",
  "date_time"
)

# Carried by sites.csv, so dropped from the covariate tables.
bird_cols_in_sites <- c(
  "Easting",
  "Northing"
)

## 1.12 Check the inputs are reachable ----
# Fail before any reading, so a disconnected drive is obvious.
all_files <- c(
  file.path(snapshot_dir, c(plant_files, mammal_files)),
  wt_species_file,
  bird_data_file
)
missing_files <- all_files[!file.exists(all_files)]

if (length(missing_files) > 0) {
  stop(
    "Source files not found:\n  ",
    paste(missing_files, collapse = "\n  "),
    "\nAre ",
    snapshot_dir,
    " and the WildTrax lookup reachable?",
    call. = FALSE
  )
}

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# 2. Helper functions ----
# One reader per source family, plus a name normalizer for the
# mammal crosswalk and a duplicate-key guard shared by both.

## 2.1 load_rdata() ----

#' Load an .RData File into an Isolated Environment
#'
#' Reads a saved workspace without touching the global
#' environment, so the six files cannot overwrite each other's
#' objects.
#'
#' @param path Character. Path to an .RData file.
#' @return An environment holding the file's objects.
#'
#' @example # Example usage of the function
#' # e <- load_rdata("mite-model-data.Rdata")
#' # ls(e)
load_rdata <- function(path) {
  # Step 1: Read into a fresh environment
  env <- new.env(parent = emptyenv())
  load(path, envir = env)

  return(env)
}

## 2.2 make_unique_ids() ----

#' Make Survey Unit Ids Unique
#'
#' Appends numbered suffixes to repeated ids and reports what it
#' changed.
#'
#' @param ids Character. Survey unit ids, possibly repeated.
#' @param label Character. Source name used in the message.
#' @return Character. Ids of the same length, all unique.
#'
#' @example # Example usage of the function
#' # make_unique_ids(c("a", "a", "b"), "example")
#' # [1] "a__1" "a__2" "b"
make_unique_ids <- function(ids, label) {
  # Step 1: Find ids used by more than one row
  repeated <- unique(ids[duplicated(ids)])

  if (length(repeated) == 0) {
    return(ids)
  }

  # Step 2: Number every row sharing a repeated id
  message(
    "  note: ",
    length(repeated),
    " duplicated id(s) in ",
    label,
    " given numbered suffixes:\n    ",
    paste(repeated, collapse = "\n    ")
  )

  for (id in repeated) {
    hit <- which(ids == id)
    ids[hit] <- paste0(id, "__", seq_along(hit))
  }

  return(ids)
}

## 2.3 squash_name() ----

#' Reduce a Species String to a Column-Safe Token
#'
#' Collapses a common-name string to CamelCase with no
#' punctuation.
#' Apostrophes are deleted before splitting, so "Richardson's"
#' becomes "Richardsons" and not "Richardson" + "S"; the
#' remaining punctuation and spaces are split points.
#'
#' @param x Character. Species strings.
#' @return Character. One token per input.
#'
#' @example # Example usage of the function
#' # squash_name("Voles, Mice and Allies")
#' # [1] "VolesMiceAndAllies"
squash_name <- function(x) {
  # Step 1: Delete apostrophes so they are not split points
  x <- gsub("'", "", x, fixed = TRUE)

  # Step 2: Split on the remaining punctuation and capitalize
  return(vapply(
    strsplit(x, "[^A-Za-z0-9]+"),
    function(parts) {
      parts <- parts[nzchar(parts)]
      paste0(
        toupper(substring(parts, 1, 1)),
        substring(parts, 2),
        collapse = ""
      )
    },
    character(1)
  ))
}

## 2.4 canonicalize_species() ----

#' Resolve Source Species Names against the WildTrax Strings
#'
#' Maps each source species name to its WildTrax common-name
#' string, which is the naming authority for mammals. An exact
#' match is tried first, then a punctuation-insensitive one: the
#' North file already uses the WildTrax strings verbatim, while
#' the South file uses their camel-cased form.
#'
#' @param base Character. Source species names, no season suffix.
#' @param native_sp Character. WildTrax common-name strings.
#' @param label Character. Source name used in the message.
#' @return Character. Canonical name per input, source spelling
#'   kept where the lookup has no entry.
#'
#' @example # Example usage of the function
#' # canonicalize_species("BlackBear", native_sp, "south")
#' # [1] "Black Bear"
canonicalize_species <- function(base, native_sp, label) {
  # Step 1: Take an exact match where the lookup has one
  canonical <- ifelse(base %in% native_sp, base, NA_character_)

  # Step 2: Fall back to a punctuation-insensitive match
  unresolved <- is.na(canonical)

  if (any(unresolved)) {
    hit <- match(
      squash_name(base[unresolved]),
      squash_name(native_sp)
    )
    canonical[unresolved] <- native_sp[hit]
  }

  # Step 3: Report and keep anything the lookup does not carry
  unknown <- is.na(canonical)

  if (any(unknown)) {
    message(
      "  note: ",
      sum(unknown),
      " ",
      label,
      " species not in the ",
      "WildTrax strings; source spelling kept:\n    ",
      paste(base[unknown], collapse = "\n    ")
    )
    canonical[unknown] <- base[unknown]
  }

  return(canonical)
}

## 2.5 normalize_mammal_column() ----

#' Harmonize a Mammal Species-Season Column Name
#'
#' Splits the season off each source column, resolves the species
#' against the WildTrax strings, and rebuilds the name as a
#' column-safe token plus a season suffix.
#'
#' @param x Character. Source column names, each ending in
#'   "Summer" or "Winter" (e.g. "Black BearSummer").
#' @param native_sp Character. WildTrax common-name strings.
#' @param label Character. Source name used in messages.
#' @return Character. Harmonized names (e.g. "BlackBear_Summer").
#'
#' @example # Example usage of the function
#' # normalize_mammal_column(
#' #   "Voles, Mice and AlliesSummer", native_sp, "north"
#' # )
#' # [1] "VolesMiceAndAllies_Summer"
normalize_mammal_column <- function(x, native_sp, label) {
  # Step 1: Split the trailing season off the species name
  season <- ifelse(
    grepl("Summer$", x),
    "Summer",
    ifelse(grepl("Winter$", x), "Winter", NA_character_)
  )

  if (anyNA(season)) {
    stop(
      "Mammal column(s) end in neither Summer nor Winter: ",
      paste(x[is.na(season)], collapse = ", "),
      call. = FALSE
    )
  }

  base <- sub("(Summer|Winter)$", "", x)

  # Step 2: Resolve the species against the WildTrax strings.
  distinct <- unique(base)
  canonical <- canonicalize_species(distinct, native_sp, label)

  # Step 3: Rebuild as a column-safe token plus its season
  token <- squash_name(canonical)[match(base, distinct)]

  return(paste0(token, "_", season))
}

## 2.6 read_plant_taxon() ----

#' Read One Plant-Group Snapshot File
#'
#' Despite the name, "plant group" is a file layout rather than a
#' taxon: this reads the vascular plant, bryophyte, lichen and
#' mite files, which share one site-year-quadrant schema.
#'
#' Splits a plant-group file into its species block and its site
#' block. Species are identified by elimination: every column
#' that is neither an identity column (`plant_id_cols`) nor a
#' site or climate column (`plant_site_cols`) is a species.
#'
#' Two checks keep the rule honest in both directions. Anything
#' wrongly counted as a species fails the 0/1 test, and anything
#' wrongly excluded is caught against the file's own
#' `veg.species.list` and `soil.species.list`.
#'
#' @param path Character. Path to a plant-group .Rdata file.
#' @param taxon Character. Taxon slug, used in messages and in
#'   the site table.
#' @return A list with `species` (survey_unit_id + species
#'   columns), `sites` (one row per survey unit), `climate` and
#'   `habitat` (the two covariate blocks), `pred_matrix`, and
#'   `species_lists` (the four sp_table vectors as one frame).
#'
#' @example # Example usage of the function
#' # out <- read_plant_taxon("mite-model-data.Rdata", "mite")
#' # dim(out$species)
read_plant_taxon <- function(path, taxon) {
  env <- load_rdata(path)
  clim <- env$climate.data
  cols <- names(clim)

  # Step 1: Require the identity columns the key is built from
  absent_id <- setdiff(plant_id_cols, cols)

  if (length(absent_id) > 0) {
    stop(
      "Identity column(s) missing from ",
      basename(path),
      ": ",
      paste(absent_id, collapse = ", "),
      call. = FALSE
    )
  }

  # Step 2: Species are what remains once identity and site
  # columns are removed, so column order does not matter.
  species_cols <- setdiff(cols, c(plant_id_cols, plant_site_cols))

  # Step 3: Confirm the block really is presence/absence data.
  values <- as.matrix(clim[, species_cols])

  clean <- is.numeric(values) &&
    !anyNA(values) &&
    all(values %in% c(0, 1))

  if (!clean) {
    offenders <- species_cols[
      apply(values, 2, function(v) {
        !is.numeric(v) || anyNA(v) || !all(v %in% c(0, 1))
      })
    ]

    stop(
      "Column(s) treated as species in ",
      basename(path),
      " are not 0/1 data: ",
      paste(utils::head(offenders, 10), collapse = ", "),
      ".\nIf these are new site or climate columns, add them to ",
      "plant_site_cols.",
      call. = FALSE
    )
  }

  # Step 4: Confirm nothing the file itself calls a species was
  # excluded.
  declared <- unique(c(env$veg.species.list, env$soil.species.list))
  dropped <- setdiff(declared, species_cols)

  if (length(dropped) > 0) {
    stop(
      length(dropped),
      " modelled species in ",
      basename(path),
      " were excluded from the species block: ",
      paste(utils::head(dropped, 10), collapse = ", "),
      call. = FALSE
    )
  }

  # Step 5: Build the species table on a unique key
  unit_id <- make_unique_ids(
    as.character(clim$SiteYearQu),
    taxon
  )

  species <- data.frame(
    survey_unit_id = unit_id,
    values,
    check.names = FALSE,
    stringsAsFactors = FALSE
  )

  # Step 6: Build the matching site rows.
  sites <- data.frame(
    survey_unit_id = unit_id,
    survey_design = "plant_quadrant",
    region = NA_character_,
    site = as.character(clim$Site),
    site_year = as.character(clim$SiteYear),
    year = as.integer(clim$Year),
    quadrant = as.character(clim$QUAD),
    on_off_grid = as.character(clim$OnOffGrid),
    location = NA_character_,
    project = NA_character_,
    nearest_site = NA_character_,
    lured = NA,
    summer_days = NA_real_,
    winter_days = NA_real_,
    lat = as.numeric(clim$Lat),
    long = as.numeric(clim$Long),
    elevation = as.numeric(clim$Elevation),
    easting = as.numeric(clim$Easting),
    northing = as.numeric(clim$Northing),
    nr = as.character(clim$NR),
    nsr = as.character(clim$NSR),
    luf = as.character(clim$LufName),
    stringsAsFactors = FALSE
  )

  message(
    "  ",
    taxon,
    ": ",
    nrow(species),
    " units x ",
    length(species_cols),
    " species"
  )

  return(list(species = species, sites = sites))
}

## 2.7 read_plant_covariates() ----

#' Read One Plant-Group File's Covariate and Lookup Blocks
#'
#' Companion to `read_plant_taxon()`, which takes the response.
#' This takes what the v2 hierarchical models regress against:
#' the climate block, the north vegetation and HF block, the
#' south soil and HF block, the two habitat prediction matrices,
#' and the lists naming which species each model set is fitted
#' for.
#'
#' The habitat blocks are found by difference rather than by
#' position. `climate.data` is identity + species + climate, so
#' whatever `veg.data` holds that `climate.data` does not is the
#' vegetation block, and likewise for soil. That reproduces the
#' positional spans the v2 scripts hard-code - `[403:489]` for
#' bryophytes, `[448:534]`, `[328:414]` and `[1408:1494]` for the
#' other three - without depending on column order staying put.
#'
#' @param path Character. Path to a plant-group .Rdata file.
#' @param taxon Character. Taxon slug, used in messages.
#' @return A list with `climate`, `veg` and `soil` (each
#'   survey_unit_id + that block's columns), `veg_pm` and
#'   `soil_pm` (the prediction matrices), and `species_lists`
#'   (taxon, species, in_veg_models, in_soil_models).
#'
#' @example # Example usage of the function
#' # out <- read_plant_covariates("mite-model-data.Rdata", "mite")
#' # dim(out$veg)
read_plant_covariates <- function(path, taxon) {
  env <- load_rdata(path)
  clim <- env$climate.data
  clim_cols <- names(clim)

  # Step 1: Take the climate block, minus the fields sites.csv
  # already carries, in the order plant_site_cols declares.
  climate_cols <- setdiff(
    intersect(plant_site_cols, clim_cols),
    c(plant_site_cols_in_sites, plant_site_cols_derived)
  )

  climate <- data.frame(
    survey_unit_id = as.character(clim$SiteYearQu),
    clim[, climate_cols, drop = FALSE],
    stringsAsFactors = FALSE
  )

  # Step 2: Take each habitat block by difference from
  # climate.data, which leaves the covariates behind and drops
  # the identity, species and climate columns both frames share.
  take_block <- function(frame) {
    block_cols <- setdiff(names(frame), clim_cols)

    data.frame(
      survey_unit_id = as.character(frame$SiteYearQu),
      frame[, block_cols, drop = FALSE],
      stringsAsFactors = FALSE
    )
  }

  veg <- take_block(env$veg.data)
  soil <- take_block(env$soil.data)

  # Step 3: The v2 coefficient template is the first 87 columns
  # of this block, taken positionally. A snapshot that reordered
  # or shortened it would silently rename every vegetation
  # coefficient, so the width is checked rather than assumed.
  if (ncol(veg) - 1 < 87) {
    stop(
      taxon,
      ": vegetation block has ",
      ncol(veg) - 1,
      " columns; the coefficient template needs at least 87.",
      call. = FALSE
    )
  }

  # Step 4: All three frames must describe the same survey units
  # in the same order, or the tables cannot be recombined on
  # survey_unit_id downstream.
  if (
    !identical(climate$survey_unit_id, veg$survey_unit_id) ||
      !identical(climate$survey_unit_id, soil$survey_unit_id)
  ) {
    stop(
      taxon,
      ": climate, veg and soil frames do not share one survey ",
      "unit ordering.",
      call. = FALSE
    )
  }

  # Step 5: Record which species each model set is fitted for.
  # These are subsets of the response columns, and the v2 scripts
  # read them straight out of the .Rdata, so they have to travel
  # with the dataset or the work queue cannot be rebuilt.
  modelled <- union(env$veg.species.list, env$soil.species.list)

  # The two lists are separately ordered, and the v2 scripts walk
  # each in its own order. A single stacked table would lose that,
  # so each species carries its position in whichever lists hold
  # it, and the loader sorts on those rather than on the row
  # order of this file.
  species_lists <- data.frame(
    taxon = taxon,
    species = modelled,
    in_veg_models = modelled %in% env$veg.species.list,
    in_soil_models = modelled %in% env$soil.species.list,
    veg_order = match(modelled, env$veg.species.list),
    soil_order = match(modelled, env$soil.species.list),
    stringsAsFactors = FALSE
  )

  message(
    "  ",
    taxon,
    ": ",
    ncol(climate) - 1,
    " climate, ",
    ncol(veg) - 1,
    " veg, ",
    ncol(soil) - 1,
    " soil covariates; ",
    nrow(species_lists),
    " modelled species"
  )

  return(list(
    climate = climate,
    veg = veg,
    soil = soil,
    veg_pm = env$veg.pm,
    soil_pm = env$soil.pm,
    species_lists = species_lists
  ))
}

## 2.8 read_camera_climate() ----

#' Read the Mammal Camera Climate
#'
#' Climate normals interpolated to each camera deployment. The
#' file is keyed on site and year, but the normals are 30-year
#' averages and so identical across years at one location; v2
#' strips the year and keeps one row per location, which is
#' reproduced here.
#'
#' The CMU and NWSAR prefixes are project tags on the site name
#' rather than part of the location, and are stripped for the
#' same reason.
#'
#' @param path Character. Path to abmi-camera-climate_*.Rdata.
#' @param columns Character vector of climate columns to keep.
#' @return A data frame of `location` plus those columns, one row
#'   per location, or NULL when the file is absent.
#'
#' @example # Example usage of the function
#' # read_camera_climate(mammal_camera_climate_file,
#' #                     mammal_camera_climate_cols)
read_camera_climate <- function(path, columns) {
  if (!file.exists(path)) {
    return(NULL)
  }

  env <- load_rdata(path)
  climate <- env$camera.climate

  if (is.null(climate)) {
    stop(
      basename(path), " holds no `camera.climate` object.",
      call. = FALSE
    )
  }

  absent <- setdiff(columns, names(climate))

  if (length(absent) > 0) {
    stop(
      basename(path), " is missing ", length(absent),
      " expected column(s): ",
      paste(utils::head(absent, 10), collapse = ", "),
      call. = FALSE
    )
  }

  location <- sub("_[0-9]{4}$", "", rownames(climate))
  location <- sub("^CMU-|^NWSAR-", "", location)

  out <- data.frame(
    location = location,
    climate[, columns, drop = FALSE],
    stringsAsFactors = FALSE
  )

  out[!duplicated(out$location), ]
}

## 2.9 read_mammal_region() ----

#' Read One Mammal Snapshot File
#'
#' Reads the camera tibble `d` and harmonizes its species-season
#' column names. The values are densities.
#'
#' The v2 script 02_process-data-files.R sets a season's
#' densities to NA when that season has fewer than 10
#' camera-days, so an NA records too little effort to estimate
#' from.
#'
#' @param path Character. Path to a mammal .RData file.
#' @param region Character. "north" or "south".
#' @param native_sp Character. WildTrax common-name strings.
#' @return A list with `species` (survey_unit_id + harmonized
#'   species columns) and `sites` (one row per survey unit).
#'
#' @example # Example usage of the function
#' # out <- read_mammal_region(path, "south", native_sp)
#' # names(out$species)[1:3]
read_mammal_region <- function(path, region, native_sp) {
  env <- load_rdata(path)
  d <- as.data.frame(env$d, stringsAsFactors = FALSE)

  # Step 1: Take the species block from the file's own indices
  span <- env$first_sp_col_summer:env$last_sp_col_winter

  if (anyNA(span) || max(span) > ncol(d)) {
    stop(
      "Species column indices in ",
      basename(path),
      " fall outside the data.",
      call. = FALSE
    )
  }

  species_cols <- names(d)[span]

  # Step 2: Harmonize the names
  harmonized <- normalize_mammal_column(
    species_cols,
    native_sp,
    paste0("mammal ", region)
  )

  if (anyDuplicated(harmonized) > 0) {
    stop(
      "Normalizing mammal ",
      region,
      " names merged distinct ",
      "columns: ",
      paste(
        unique(harmonized[duplicated(harmonized)]),
        collapse = ", "
      ),
      call. = FALSE
    )
  }

  # Step 3: Build the species table
  unit_id <- make_unique_ids(
    paste0("mammal_", region, "|", d$location_project),
    paste0("mammal ", region)
  )

  values <- d[, species_cols, drop = FALSE]
  names(values) <- harmonized

  species <- data.frame(
    survey_unit_id = unit_id,
    values,
    check.names = FALSE,
    stringsAsFactors = FALSE
  )

  # Step 4: Build the matching site rows.
  sites <- data.frame(
    survey_unit_id = unit_id,
    survey_design = "mammal_camera",
    region = region,
    site = NA_character_,
    site_year = NA_character_,
    year = NA_integer_,
    quadrant = NA_character_,
    on_off_grid = NA_character_,
    location = as.character(d$location),
    project = as.character(d$project),
    nearest_site = as.character(d$NearestSite),
    lured = d$Lured,
    summer_days = as.numeric(d$SummerDays),
    winter_days = as.numeric(d$WinterDays),
    lat = as.numeric(d$Lat),
    long = as.numeric(d$Long),
    elevation = NA_real_,
    easting = NA_real_,
    northing = NA_real_,
    nr = as.character(d$NR),
    nsr = as.character(d$NSR),
    luf = as.character(d$LUF),
    stringsAsFactors = FALSE
  )

  # Step 5: Split the covariates off the same frame. The species
  # span is already known, and the two non-habitat blocks are
  # named in section 1.5, so habitat is what is left. The unit
  # ids are reused rather than rebuilt: make_unique_ids() numbers
  # duplicate deployments, and a second call would have to
  # reproduce that numbering exactly.
  take_block <- function(wanted) {
    present <- intersect(wanted, names(d))

    data.frame(
      survey_unit_id = unit_id,
      d[, present, drop = FALSE],
      check.names = FALSE,
      stringsAsFactors = FALSE
    )
  }

  climate <- take_block(mammal_climate_cols)

  # Step 5b: Replace the SpTable's climate columns with the
  # camera climate, which is what the v2 climate pipeline
  # actually fitted against. The two are different extractions -
  # they disagree by up to 531 mm of MAP at matched deployments -
  # so taking some columns from one and some from the other would
  # leave the block internally inconsistent. It is also the only
  # source of CMD and TD, which four of the nine v2 climate
  # models need.
  #
  # A deployment the climate file does not reach keeps NA rather
  # than a substitute. v2 excludes those sites; a nearest-site
  # value would be a different extraction again.
  camera_climate <- read_camera_climate(
    mammal_camera_climate_file, mammal_camera_climate_cols
  )

  if (is.null(camera_climate)) {
    warning(
      "Camera climate not found at ", mammal_camera_climate_file,
      "; mammal ", region, " keeps the SpTable climate block, ",
      "which has no CMD or TD. Set SDM_MAMMAL_CAMERA_CLIMATE.",
      call. = FALSE
    )
  } else {
    matched <- match(
      as.character(d$location), camera_climate$location
    )

    replaced <- intersect(
      mammal_camera_climate_cols, names(climate)
    )
    added <- setdiff(mammal_camera_climate_cols, names(climate))

    for (column in mammal_camera_climate_cols) {
      climate[[column]] <- camera_climate[[column]][matched]
    }

    message(
      "  mammal ", region, ": camera climate matched ",
      sum(!is.na(matched)), " of ", nrow(d), " deployments (",
      round(100 * mean(!is.na(matched)), 1), "%); ",
      length(replaced), " column(s) replaced, ",
      length(added), " added"
    )
  }

  habitat_cols <- setdiff(
    names(d),
    c(mammal_site_cols, mammal_climate_cols, species_cols)
  )
  habitat <- take_block(habitat_cols)

  # The four blocks must partition `d` exactly. They are built by
  # difference, so an overlap or a gap would quietly move a
  # column into the wrong table.
  accounted <- length(species_cols) + length(habitat_cols) +
    length(intersect(mammal_site_cols, names(d))) +
    length(intersect(mammal_climate_cols, names(d)))

  if (accounted != ncol(d)) {
    stop(
      "mammal ",
      region,
      ": the design, climate, species and habitat blocks cover ",
      accounted,
      " of ",
      ncol(d),
      " columns.",
      call. = FALSE
    )
  }

  # Step 6: Record the work queue. Mammals model each season
  # separately and at two occurrence thresholds - sp_table_* are
  # the species with at least 20 detections, which get the full
  # habitat model, and sp_table_*_ua those with at least 3, which
  # get the use-availability model. One row per species-season,
  # with its position in each list it belongs to.
  season_lists <- list(
    summer = list(
      modelled = env$sp_table_summer,
      ua = env$sp_table_summer_ua
    ),
    winter = list(
      modelled = env$sp_table_winter,
      ua = env$sp_table_winter_ua
    )
  )

  species_lists <- do.call(rbind, lapply(
    names(season_lists),
    function(season) {
      lists <- season_lists[[season]]
      all_species <- union(lists$modelled, lists$ua)

      data.frame(
        region = region,
        season = season,
        species_season = all_species,
        species = normalize_mammal_column(
          all_species, native_sp, paste0("mammal ", region)
        ),
        in_models = all_species %in% lists$modelled,
        in_ua_models = all_species %in% lists$ua,
        model_order = match(all_species, lists$modelled),
        ua_order = match(all_species, lists$ua),
        stringsAsFactors = FALSE
      )
    }
  ))

  message(
    "  mammal ",
    region,
    ": ",
    nrow(species),
    " units x ",
    length(species_cols),
    " species-season columns; ",
    ncol(climate) - 1,
    " climate, ",
    ncol(habitat) - 1,
    " habitat covariates"
  )

  return(list(
    species = species,
    sites = sites,
    climate = climate,
    habitat = habitat,
    pred_matrix = as.data.frame(env$pred_matrix),
    species_lists = species_lists
  ))
}

## 2.10 read_bird_data() ----

#' Read the Bird Data Package
#'
#' Splits Stratified.Rdata into the same shape the other taxa
#' use: a response table, covariate blocks, site rows, and the
#' lookups that say what to model.
#'
#' Birds differ from the other taxa in three ways that the output
#' has to carry. Each survey has a QPAD offset per species, so
#' the offsets are a second response-shaped table rather than a
#' covariate. Each survey is separately eligible for the north
#' and south models, so eligibility is two flags rather than one
#' region. And the counts are integer point counts, not the
#' plants' 0/1 or the mammals' densities.
#'
#' @param path Character. Path to Stratified.Rdata.
#' @return A list with `species`, `offsets`, `sites`, `climate`,
#'   `veg`, `soil`, `design`, `species_lists`, `bootstrap`,
#'   `factor_levels`, and `covs_cols` for the block check.
#'
#' @example # Example usage of the function
#' # out <- read_bird_data(bird_data_file)
#' # dim(out$species)
read_bird_data <- function(path) {
  env <- load_rdata(path)

  expected <- c("covs", "bird", "off", "boot", "birdlist")
  absent <- setdiff(expected, ls(env))

  if (length(absent) > 0) {
    stop(
      "Object(s) missing from ",
      basename(path),
      ": ",
      paste(absent, collapse = ", "),
      call. = FALSE
    )
  }

  covs <- as.data.frame(env$covs, stringsAsFactors = FALSE)
  counts <- as.data.frame(env$bird, stringsAsFactors = FALSE)
  offsets <- as.data.frame(env$off, stringsAsFactors = FALSE)

  # Step 1: The three frames are stored row-aligned, but `covs`
  # holds surveyid as double and the other two as integer, so
  # identical() on them is FALSE for a reason that does not
  # matter. Compare on a common type, and refuse to continue if
  # the rows ever stop lining up: every table below is built by
  # position, not by joining.
  key <- as.integer(covs$surveyid)

  if (
    !identical(key, counts$surveyid) ||
      !identical(key, offsets$surveyid)
  ) {
    stop(
      "bird: covs, bird and off are no longer row-aligned on ",
      "surveyid; this reader assumes they are.",
      call. = FALSE
    )
  }

  if (anyDuplicated(key) > 0) {
    stop("bird: surveyid is not unique in covs.", call. = FALSE)
  }

  unit_id <- paste0("bird|", key)

  # Step 2: Counts are the response. Offsets are the same shape,
  # restricted to the species that have counts: `off` carries 219
  # species and `bird` 127, and an offset with no count column
  # cannot be modelled.
  species_cols <- setdiff(names(counts), "surveyid")

  absent_offsets <- setdiff(species_cols, names(offsets))

  if (length(absent_offsets) > 0) {
    stop(
      "bird: ",
      length(absent_offsets),
      " species have counts but no QPAD offset: ",
      paste(utils::head(absent_offsets, 10), collapse = ", "),
      call. = FALSE
    )
  }

  species <- data.frame(
    survey_unit_id = unit_id,
    counts[, species_cols, drop = FALSE],
    check.names = FALSE,
    stringsAsFactors = FALSE
  )

  offset_table <- data.frame(
    survey_unit_id = unit_id,
    offsets[, species_cols, drop = FALSE],
    check.names = FALSE,
    stringsAsFactors = FALSE
  )

  # Step 3: Take each covariate block by name. Shared footprint,
  # method and water terms appear in both habitat blocks, so the
  # blocks are not a partition of the covariate columns and are
  # built by intersection rather than by difference.
  take_block <- function(wanted) {
    present <- setdiff(
      intersect(wanted, names(covs)),
      bird_cols_in_sites
    )

    data.frame(
      survey_unit_id = unit_id,
      covs[, present, drop = FALSE],
      check.names = FALSE,
      stringsAsFactors = FALSE
    )
  }

  climate <- take_block(bird_climate_cols)
  veg <- take_block(bird_veg_cols)
  soil <- take_block(bird_soil_cols)
  design <- take_block(bird_design_cols)

  # date_time is POSIXct in local time. fwrite would render it as
  # UTC, so a 07:07 Mountain survey would be read back as 13:07
  # and every survey would silently move six hours. Formatting it
  # here stores exactly what the source displays.
  design$date_time <- format(design$date_time)

  # Step 4: Build the site rows. Birds carry UTM coordinates but
  # no latitude, longitude or natural region, so those stay NA
  # rather than being reprojected here. `year` is the calendar
  # year taken from date_time; the model's recoded year travels
  # in the design table.
  calendar_year <- as.integer(format(covs$date_time, "%Y"))

  if (!all(covs$year == calendar_year - 1992)) {
    stop(
      "bird: the recoded `year` column is no longer calendar ",
      "year minus 1992, so the calendar year cannot be trusted.",
      call. = FALSE
    )
  }

  sites <- data.frame(
    survey_unit_id = unit_id,
    survey_design = "bird_point_count",
    region = NA_character_,
    site = as.character(covs$locationid),
    site_year = as.character(covs$gisid),
    year = calendar_year,
    quadrant = NA_character_,
    on_off_grid = NA_character_,
    location = as.character(covs$gisid),
    project = as.character(covs$organization),
    nearest_site = NA_character_,
    lured = NA,
    summer_days = NA_real_,
    winter_days = NA_real_,
    lat = NA_real_,
    long = NA_real_,
    elevation = NA_real_,
    easting = as.numeric(covs$Easting),
    northing = as.numeric(covs$Northing),
    nr = NA_character_,
    nsr = NA_character_,
    luf = NA_character_,
    stringsAsFactors = FALSE
  )

  # Step 5: The work queue. birdlist is one row per species and
  # region, with the detection counts that decided inclusion.
  species_lists <- data.frame(
    as.data.frame(env$birdlist, stringsAsFactors = FALSE),
    stringsAsFactors = FALSE
  )

  # Step 6: Name the bootstrap columns. The source calls them
  # "1" to "100", which a CSV header cannot distinguish from a
  # row of data: read back, the header becomes a 58036th row and
  # the columns are renamed V1 to V100. A word prefix makes the
  # header unmistakable and keeps the draw number.
  bootstrap <- as.data.frame(env$boot)
  names(bootstrap) <- sprintf(
    "boot_%03d", seq_len(ncol(bootstrap))
  )

  # Step 7: Record every factor's levels in source order. A CSV
  # stores labels, and re-reading gives alphabetical levels; that
  # would move the reference level and silently change which
  # coefficient a model reports as the intercept.
  factor_cols <- names(covs)[vapply(covs, is.factor, logical(1))]

  factor_levels <- do.call(rbind, lapply(
    factor_cols,
    function(col) {
      data.frame(
        column = col,
        level_order = seq_along(levels(covs[[col]])),
        level = levels(covs[[col]]),
        stringsAsFactors = FALSE
      )
    }
  ))

  message(
    "  bird: ",
    nrow(species),
    " surveys x ",
    length(species_cols),
    " species; ",
    ncol(climate) - 1,
    " climate, ",
    ncol(veg) - 1,
    " veg, ",
    ncol(soil) - 1,
    " soil covariates; ",
    nrow(species_lists),
    " species-region models"
  )

  return(list(
    species = species,
    offsets = offset_table,
    sites = sites,
    climate = climate,
    veg = veg,
    soil = soil,
    design = design,
    species_lists = species_lists,
    bootstrap = bootstrap,
    factor_levels = factor_levels,
    covs_cols = names(covs)
  ))
}

# 3. Read the sources ----

## 3.1 Read the plant-group files ----
message("Reading plant-group files ...")

plant_parts <- lapply(
  names(plant_files),
  function(taxon) {
    read_plant_taxon(
      file.path(snapshot_dir, plant_files[[taxon]]),
      taxon
    )
  }
)
names(plant_parts) <- names(plant_files)

## 3.2 Read the plant-group covariates and lookups ----
# A second pass over the same four files. The response and the
# covariates are kept in separate readers because they answer
# separate questions, and this script runs once per snapshot.
message("Reading plant-group covariates ...")

covariate_parts <- lapply(
  names(plant_files),
  function(taxon) {
    read_plant_covariates(
      file.path(snapshot_dir, plant_files[[taxon]]),
      taxon
    )
  }
)
names(covariate_parts) <- names(plant_files)

## 3.3 Read the mammal files ----
# The WildTrax strings are loaded once and passed to both
# regions, so each resolves its names against the same authority.
message("Reading mammal files ...")

native_sp <- load_rdata(wt_species_file)$native_sp

if (!is.character(native_sp) || length(native_sp) == 0) {
  stop(
    "Expected a non-empty character vector `native_sp` in ",
    wt_species_file,
    call. = FALSE
  )
}

mammal_parts <- lapply(
  names(mammal_files),
  function(region) {
    read_mammal_region(
      file.path(snapshot_dir, mammal_files[[region]]),
      region,
      native_sp
    )
  }
)
names(mammal_parts) <- names(mammal_files)

## 3.4 Read the bird data package ----
message("Reading bird data ...")

bird_parts <- read_bird_data(bird_data_file)

# 4. Harmonize the mammal regions into one taxon table ----
# North and South are one taxon split across two models, so they
# are stacked.

## 4.1 Confirm the North names reconcile with the South ----
# A North name that no longer matches means the crosswalk has
# drifted and would split one species across two columns.
north_species <- setdiff(
  names(mammal_parts$north$species),
  "survey_unit_id"
)
south_species <- setdiff(
  names(mammal_parts$south$species),
  "survey_unit_id"
)

unmatched <- setdiff(north_species, south_species)

if (length(unmatched) > 0) {
  stop(
    "Mammal North columns did not reconcile with South after ",
    "normalizing:\n  ",
    paste(unmatched, collapse = "\n  "),
    "\nUpdate normalize_mammal_column() before rerunning.",
    call. = FALSE
  )
}

## 4.2 Align both regions to the union and stack ----
mammal_species_cols <- union(south_species, north_species)

#' Add a Region's Missing Species Columns as NA
#'
#' @param df Data frame. One region's species table.
#' @param wanted Character. The full set of species columns.
#' @return The data frame with `wanted` present and in order.
#'
#' @example # Example usage of the function
#' # align_columns(north_tbl, mammal_species_cols)
align_columns <- function(df, wanted) {
  # Step 1: Add the columns this region lacks
  for (col in setdiff(wanted, names(df))) {
    df[[col]] <- NA_real_
  }

  # Step 2: Put the key first and the species in a fixed order
  return(df[, c("survey_unit_id", wanted), drop = FALSE])
}

mammal_species <- rbind(
  align_columns(mammal_parts$north$species, mammal_species_cols),
  align_columns(mammal_parts$south$species, mammal_species_cols)
)

message(
  "  mammal combined: ",
  nrow(mammal_species),
  " units x ",
  length(mammal_species_cols),
  " species-season columns"
)

# 5. Build the master site table ----
# One row per survey unit across all six sources, plus a flag per
# taxon recording which taxon files cover that unit.

## 5.1 Stack every source's site rows ----
all_sites <- do.call(
  rbind,
  c(
    lapply(plant_parts, function(x) x$sites),
    lapply(mammal_parts, function(x) x$sites),
    list(bird = bird_parts$sites)
  )
)
rownames(all_sites) <- NULL

## 5.2 Record which taxon files cover each unit ----
# The four plant taxa share the SiteYearQu key but sample
# different unit sets. The flags make that coverage explicit.
taxon_units <- c(
  lapply(plant_parts, function(x) x$species$survey_unit_id),
  list(
    mammal = mammal_species$survey_unit_id,
    bird = bird_parts$species$survey_unit_id
  )
)

for (taxon in names(taxon_units)) {
  all_sites[[paste0("in_", taxon)]] <-
    all_sites$survey_unit_id %in% taxon_units[[taxon]]
}

## 5.3 Collapse to one row per survey unit ----
# A plant unit contributes an identical site row from each taxon
# file that sampled it.
flag_cols <- grep("^in_", names(all_sites), value = TRUE)
attribute_cols <- setdiff(
  names(all_sites),
  c("survey_unit_id", flag_cols)
)

conflicting <- unique(all_sites$survey_unit_id[
  duplicated(all_sites$survey_unit_id) &
    !duplicated(all_sites[, c("survey_unit_id", attribute_cols)])
])

if (length(conflicting) > 0) {
  warning(
    length(conflicting),
    " survey unit(s) carry conflicting ",
    "site attributes across taxon files; the first row was ",
    "kept. First few: ",
    paste(utils::head(conflicting, 5), collapse = ", "),
    call. = FALSE
  )
}

sites <- all_sites[!duplicated(all_sites$survey_unit_id), ]
rownames(sites) <- NULL

## 5.4 Build the master covariate table ----
# One table for every taxon, keyed on survey_unit_id and taxon
# the way sites.csv is keyed on survey_unit_id alone.
#
# Taxon has to be part of the key, because the four plant files
# disagree. On the 7001 quadrats vascular plant and mite share,
# 154 of 162 vegetation columns and 58 of 59 soil columns hold
# different values, while climate agrees to the last digit.
# Bryophyte and lichen match vascular plant exactly. Two
# descriptions of the same quadrat cannot share one row, and
# choosing between them is not this script's call to make.
#
# Columns are the union across taxa. Each taxon fills only the
# blocks it has and leaves the rest empty, so the table is about
# 16 per cent populated - the price of one file instead of
# twenty, paid mostly by the bird rows, which are 86 per cent of
# the rows and share almost no column names with the others.

#' Join One Taxon's Covariate Blocks Side by Side
#'
#' Blocks come from one source frame in one row order, so they
#' are combined by position rather than by key.
#'
#' A name carried by more than one block is suffixed with the
#' block it came from. That is not tidiness: in the plant files
#' 42 names sit in both the veg and soil blocks, and 14 of them
#' hold different values, because the footprint terms are
#' computed once under the north vegetation framework and again
#' under the south soil one. Keeping a single `Crop` would feed
#' the south models north numbers.
#'
#' @param blocks Named list of data frames, each keyed on
#'   survey_unit_id. The names become the block suffixes.
#' @param taxon Character. Value for the taxon column.
#' @return A list with `table` (survey_unit_id, taxon, then the
#'   blocks' columns) and `map` (taxon, block, source_column,
#'   master_column) recording where each column came from.
#'
#' @example # Example usage of the function
#' # merge_blocks(list(climate = a, veg = b), "bryophyte")
merge_blocks <- function(blocks, taxon) {
  # Step 1: Find the names more than one block carries
  every_name <- unlist(lapply(blocks, function(block) {
    setdiff(names(block), "survey_unit_id")
  }))
  collide <- unique(every_name[duplicated(every_name)])

  key <- blocks[[1]]$survey_unit_id
  out <- data.frame(
    survey_unit_id = key,
    stringsAsFactors = FALSE
  )
  map <- list()

  for (block_name in names(blocks)) {
    block <- blocks[[block_name]]

    # Step 2: Refuse to combine blocks that have drifted apart,
    # since they are joined by position and not by key
    if (!identical(key, block$survey_unit_id)) {
      stop(
        taxon,
        ": covariate blocks are not in one row order.",
        call. = FALSE
      )
    }

    # Step 3: Suffix the colliding names, keep the rest as the
    # v2 scripts spell them
    cols <- setdiff(names(block), "survey_unit_id")
    renamed <- ifelse(
      cols %in% collide,
      paste0(cols, "_", block_name),
      cols
    )

    piece <- block[, cols, drop = FALSE]
    names(piece) <- renamed
    out <- cbind(out, piece)

    map[[length(map) + 1]] <- data.frame(
      taxon = taxon,
      block = block_name,
      source_column = cols,
      master_column = renamed,
      stringsAsFactors = FALSE
    )
  }

  out$taxon <- taxon

  return(list(table = out, map = do.call(rbind, map)))
}

# The blocks each taxon owns. Mammals are split by region
# because north and south are separate models on overlapping
# deployments; birds add a design block that is neither a
# covariate nor a field sites.csv carries.
covariate_blocks <- c(
  lapply(covariate_parts, function(x) {
    list(climate = x$climate, veg = x$veg, soil = x$soil)
  }),
  list(
    mammal_north = list(
      climate = mammal_parts$north$climate,
      veg = mammal_parts$north$habitat
    ),
    mammal_south = list(
      climate = mammal_parts$south$climate,
      soil = mammal_parts$south$habitat
    ),
    bird = list(
      climate = bird_parts$climate,
      veg = bird_parts$veg,
      soil = bird_parts$soil,
      design = bird_parts$design
    )
  )
)

merged_covariates <- lapply(
  names(covariate_blocks),
  function(taxon) {
    merge_blocks(covariate_blocks[[taxon]], taxon)
  }
)

covariates <- as.data.frame(rbindlist(
  lapply(merged_covariates, function(x) x$table),
  fill = TRUE,
  use.names = TRUE
))

# Where every column came from, so a block can be reconstructed
# exactly and a suffixed name traced back to its v2 spelling.
covariate_columns <- do.call(
  rbind,
  lapply(merged_covariates, function(x) x$map)
)
rownames(covariate_columns) <- NULL

covariates <- covariates[
  , c(
    "survey_unit_id",
    "taxon",
    setdiff(names(covariates), c("survey_unit_id", "taxon"))
  )
]

message(
  "  covariates: ",
  nrow(covariates),
  " unit-taxon rows x ",
  ncol(covariates) - 2,
  " covariates"
)

# 6. Validate the assembled tables ----
# Cheap checks that would catch a layout change in a future
# snapshot before the CSVs are trusted downstream.

species_tables <- c(
  lapply(plant_parts, function(x) x$species),
  list(
    mammal = mammal_species,
    bird = bird_parts$species
  )
)

## 6.1 Every taxon key must resolve in the site table ----
for (taxon in names(species_tables)) {
  orphans <- setdiff(
    species_tables[[taxon]]$survey_unit_id,
    sites$survey_unit_id
  )

  if (length(orphans) > 0) {
    stop(
      length(orphans),
      " ",
      taxon,
      " survey unit(s) are missing from the site table.",
      call. = FALSE
    )
  }
}

## 6.2 Survey unit ids must be unique everywhere ----
if (anyDuplicated(sites$survey_unit_id) > 0) {
  stop("Site table has duplicated survey_unit_id.", call. = FALSE)
}

for (taxon in names(species_tables)) {
  if (anyDuplicated(species_tables[[taxon]]$survey_unit_id) > 0) {
    stop(
      "Duplicated survey_unit_id in ",
      taxon,
      ".",
      call. = FALSE
    )
  }
}

## 6.3 Covariates must cover the response, unit for unit ----
# A survey unit with a detection but no covariates would be
# dropped silently at model time, so the two are required to
# describe exactly the same set. Mammals contribute two taxon
# values to the covariate table and one response table, so the
# two regions are pooled before comparing.
covariate_taxa <- list(
  vascular_plant = "vascular_plant",
  bryophyte = "bryophyte",
  lichen = "lichen",
  mite = "mite",
  mammal = c("mammal_north", "mammal_south"),
  bird = "bird"
)

for (taxon in names(covariate_taxa)) {
  response_ids <- species_tables[[taxon]]$survey_unit_id
  block_ids <- covariates$survey_unit_id[
    covariates$taxon %in% covariate_taxa[[taxon]]
  ]

  if (!setequal(response_ids, block_ids)) {
    stop(
      taxon,
      ": the covariates and the response cover different survey ",
      "units (",
      length(setdiff(response_ids, block_ids)),
      " missing, ",
      length(setdiff(block_ids, response_ids)),
      " extra).",
      call. = FALSE
    )
  }
}

## 6.3b Every covariate row must resolve in the site table ----
orphan_covariates <- setdiff(
  covariates$survey_unit_id,
  sites$survey_unit_id
)

if (length(orphan_covariates) > 0) {
  stop(
    length(orphan_covariates),
    " covariate row(s) name a survey unit that sites.csv does ",
    "not carry.",
    call. = FALSE
  )
}

## 6.4 Modelled species must exist as response columns ----
# veg.species.list and soil.species.list are the work queue. A
# name that is not a column would fail per bootstrap inside a
# tryCatch, so it is caught here instead.
for (taxon in names(covariate_parts)) {
  declared <- covariate_parts[[taxon]]$species_lists$species
  available <- setdiff(
    names(species_tables[[taxon]]),
    "survey_unit_id"
  )
  unknown <- setdiff(declared, available)

  if (length(unknown) > 0) {
    stop(
      taxon,
      ": ",
      length(unknown),
      " modelled species are not response columns:\n  ",
      paste(utils::head(unknown, 10), collapse = "\n  "),
      call. = FALSE
    )
  }
}

## 6.5 The prediction matrices must agree across taxa ----
# They are written once rather than per taxon, which is only
# sound while all four files carry the same grid.
for (matrix_name in c("veg_pm", "soil_pm")) {
  reference <- covariate_parts[[1]][[matrix_name]]

  for (taxon in names(covariate_parts)) {
    written <- covariate_parts[[taxon]][[matrix_name]]

    if (!identical(written, reference)) {
      stop(
        "The ",
        matrix_name,
        " prediction matrix in ",
        taxon,
        " differs from ",
        names(covariate_parts)[1],
        "; it can no longer be written once for all taxa.",
        call. = FALSE
      )
    }
  }
}

## 6.6 Mammal habitat must be cover proportions ----
# The habitat block is what is left once the design, climate and
# species columns are named, so a new unnamed column would land
# in it silently. The reader has already checked that the blocks
# partition the frame; this checks that nothing non-numeric
# arrived, which is the shape a stray design field would have.
for (region in names(mammal_parts)) {
  part <- mammal_parts[[region]]

  habitat_values <- part$habitat[
    , setdiff(names(part$habitat), "survey_unit_id"),
    drop = FALSE
  ]

  non_numeric <- names(habitat_values)[
    !vapply(habitat_values, is.numeric, logical(1))
  ]

  if (length(non_numeric) > 0) {
    stop(
      "mammal ",
      region,
      ": non-numeric column(s) fell into the habitat block: ",
      paste(non_numeric, collapse = ", "),
      "\nName them in mammal_site_cols or mammal_climate_cols.",
      call. = FALSE
    )
  }
}

## 6.7 Mammal species lists must be response columns ----
for (region in names(mammal_parts)) {
  declared <- mammal_parts[[region]]$species_lists$species
  unknown <- setdiff(declared, names(mammal_species))

  if (length(unknown) > 0) {
    stop(
      "mammal ",
      region,
      ": ",
      length(unknown),
      " modelled species are not response columns:\n  ",
      paste(utils::head(unknown, 10), collapse = "\n  "),
      call. = FALSE
    )
  }
}

## 6.8 Bird blocks must account for every covariate column ----
# The four blocks are taken by name, so a column the source adds
# would be dropped silently rather than landing somewhere wrong.
# Easting and Northing are deliberately excluded: sites.csv
# carries them.
bird_named <- unique(c(
  bird_climate_cols,
  bird_veg_cols,
  bird_soil_cols,
  bird_design_cols,
  bird_cols_in_sites
))

bird_unnamed <- setdiff(bird_parts$covs_cols, bird_named)

if (length(bird_unnamed) > 0) {
  stop(
    "bird: ",
    length(bird_unnamed),
    " covariate column(s) belong to no block: ",
    paste(bird_unnamed, collapse = ", "),
    "\nAdd them to one of the bird_*_cols vectors.",
    call. = FALSE
  )
}

## 6.9 Bird counts and offsets must be model ready ----
# The models are Poisson with a log offset, so counts must be
# non-negative whole numbers and every count needs an offset.
bird_counts <- as.matrix(
  bird_parts$species[, -1, drop = FALSE]
)

if (
  anyNA(bird_counts) ||
    any(bird_counts < 0) ||
    !all(bird_counts %% 1 == 0)
) {
  stop(
    "bird: the count block is not non-negative whole numbers.",
    call. = FALSE
  )
}

bird_offsets <- as.matrix(
  bird_parts$offsets[, -1, drop = FALSE]
)

if (anyNA(bird_offsets)) {
  stop(
    "bird: ",
    sum(is.na(bird_offsets)),
    " QPAD offset(s) are NA; every count needs one.",
    call. = FALSE
  )
}

if (
  !identical(names(bird_parts$species), names(bird_parts$offsets))
) {
  stop(
    "bird: the count and offset tables do not carry the same ",
    "species columns in the same order.",
    call. = FALSE
  )
}

## 6.10 Bird species lists must be response columns ----
bird_declared <- unique(bird_parts$species_lists$species)
bird_unknown <- setdiff(
  bird_declared,
  names(bird_parts$species)
)

if (length(bird_unknown) > 0) {
  stop(
    "bird: ",
    length(bird_unknown),
    " modelled species are not response columns:\n  ",
    paste(utils::head(bird_unknown, 10), collapse = "\n  "),
    call. = FALSE
  )
}

## 6.11 Bootstrap draws must resolve to surveys ----
# The bootstrap matrix holds raw surveyids. They join to the
# design table, so a draw outside it would drop rows at fit time.
bird_boot_ids <- unique(unlist(bird_parts$bootstrap))
bird_orphan_draws <- setdiff(
  bird_boot_ids,
  bird_parts$design$surveyid
)

if (length(bird_orphan_draws) > 0) {
  stop(
    "bird: ",
    length(bird_orphan_draws),
    " bootstrap draw(s) name a surveyid that is not in the ",
    "design table.",
    call. = FALSE
  )
}

# 7. Write the CSVs ----
# One file per taxon plus the site table, all sharing the
# survey_unit_id key.

## 7.1 Write the taxon tables ----
for (taxon in names(species_tables)) {
  path <- file.path(output_dir, paste0(taxon, ".csv"))
  fwrite(species_tables[[taxon]], path, na = "")

  message(
    "Wrote ",
    basename(path),
    ": ",
    nrow(species_tables[[taxon]]),
    " rows x ",
    ncol(species_tables[[taxon]]),
    " cols"
  )
}

## 7.2 Write the master site table ----
sites_path <- file.path(output_dir, "sites.csv")
fwrite(sites, sites_path, na = "")

message(
  "Wrote sites.csv: ",
  nrow(sites),
  " rows x ",
  ncol(sites),
  " cols"
)

## 7.3 Write the master covariate table ----
# One file beside sites.csv, keyed on survey_unit_id and taxon,
# holding every covariate every taxon's models regress against.
# A model-data frame is rebuilt by joining it to sites.csv and
# the taxon's response table on survey_unit_id, filtering to that
# taxon, and dropping the columns that came back empty.
#
# The per-taxon covariate folder this replaces is removed, so a
# stale copy cannot be picked up by mistake.
old_covariate_dir <- file.path(output_dir, "covariates")

if (dir.exists(old_covariate_dir)) {
  unlink(old_covariate_dir, recursive = TRUE)
  message("Removed the superseded covariates/ folder")
}

covariates_path <- file.path(output_dir, "covariates.csv")
fwrite(covariates, covariates_path, na = "")

message(
  "Wrote covariates.csv: ",
  nrow(covariates),
  " rows x ",
  ncol(covariates),
  " cols (",
  round(file.size(covariates_path) / 1024^2),
  " MB)"
)

dir.create(lookup_dir, recursive = TRUE, showWarnings = FALSE)

columns_path <- file.path(lookup_dir, "covariate_columns.csv")
fwrite(covariate_columns, columns_path, na = "")

renamed_count <- sum(
  covariate_columns$source_column != covariate_columns$master_column
)

message(
  "Wrote lookup/covariate_columns.csv: ",
  nrow(covariate_columns),
  " rows x ",
  ncol(covariate_columns),
  " cols; ",
  renamed_count,
  " column(s) suffixed by block to avoid a collision"
)

## 7.4 Write the shared lookups ----
# Section 6.5 has already confirmed the two prediction matrices
# are the same in all four files, so they are written once.
dir.create(lookup_dir, recursive = TRUE, showWarnings = FALSE)

prediction_matrices <- list(
  veg_prediction_matrix = covariate_parts[[1]]$veg_pm,
  soil_prediction_matrix = covariate_parts[[1]]$soil_pm
)

# Take the v2 CSVs when they are reachable. They are what the v2
# scripts read, and the snapshot objects are missing columns the
# vegetation models need.
for (matrix_name in names(prediction_matrices)) {
  if (is.na(v2_lookup_dir) || !nzchar(v2_lookup_dir)) {
    next
  }

  source_csv <- file.path(
    v2_lookup_dir, v2_lookup_files[[matrix_name]]
  )

  if (file.exists(source_csv)) {
    prediction_matrices[[matrix_name]] <- as.data.frame(
      fread(source_csv)
    )
    message("  using ", source_csv)
  } else {
    warning(
      "SDM_V2_LOOKUP is set but ",
      source_csv,
      " was not found; falling back to the snapshot copy.",
      call. = FALSE
    )
  }
}

for (matrix_name in names(prediction_matrices)) {
  path <- file.path(lookup_dir, paste0(matrix_name, ".csv"))
  fwrite(prediction_matrices[[matrix_name]], path, na = "")

  message(
    "Wrote lookup/",
    basename(path),
    ": ",
    nrow(prediction_matrices[[matrix_name]]),
    " rows x ",
    ncol(prediction_matrices[[matrix_name]]),
    " cols"
  )
}

# The four aggregate columns the vegetation models predict onto.
# Their absence is what separates the snapshot's veg.pm from the
# CSV the v2 scripts read, so it is reported here rather than
# found later by check_prediction_terms().
veg_aggregates <- c("Peatland", "Mineral", "Upland", "CCR1234")
absent_aggregates <- setdiff(
  veg_aggregates,
  colnames(prediction_matrices$veg_prediction_matrix)
)

if (length(absent_aggregates) > 0) {
  message(
    "  note: the vegetation prediction matrix has no column for ",
    paste(absent_aggregates, collapse = ", "),
    ".\n  The vegetation models cannot be fitted until ",
    v2_lookup_files[["veg_prediction_matrix"]],
    "\n  from the v2 project is available. Set SDM_V2_LOOKUP to ",
    "the folder holding it\n  and re-run this script. The ",
    "climate and soil models are unaffected."
  )
}

modelled_species <- do.call(
  rbind,
  lapply(covariate_parts, function(x) x$species_lists)
)
rownames(modelled_species) <- NULL

modelled_path <- file.path(lookup_dir, "modelled_species.csv")
fwrite(modelled_species, modelled_path, na = "")

message(
  "Wrote lookup/modelled_species.csv: ",
  nrow(modelled_species),
  " rows x ",
  ncol(modelled_species),
  " cols"
)

## 7.5 Write the mammal lookups ----
# The prediction matrices are per region and were checked against
# the CSVs on the ABMI Mammals drive, so they are taken from the
# snapshot rather than copied in.
for (region in names(mammal_parts)) {
  path <- file.path(
    lookup_dir,
    paste0("mammal_", region, "_prediction_matrix.csv")
  )
  fwrite(mammal_parts[[region]]$pred_matrix, path, na = "")

  message(
    "Wrote lookup/",
    basename(path),
    ": ",
    nrow(mammal_parts[[region]]$pred_matrix),
    " rows x ",
    ncol(mammal_parts[[region]]$pred_matrix),
    " cols"
  )
}

# Mammals get their own species table rather than rows in
# modelled_species.csv: their work queue is season by occurrence
# threshold, which the plant north/south schema has no room for.
mammal_modelled <- do.call(
  rbind,
  lapply(mammal_parts, function(x) x$species_lists)
)
rownames(mammal_modelled) <- NULL

mammal_modelled_path <- file.path(
  lookup_dir, "mammal_modelled_species.csv"
)
fwrite(mammal_modelled, mammal_modelled_path, na = "")

message(
  "Wrote lookup/mammal_modelled_species.csv: ",
  nrow(mammal_modelled),
  " rows x ",
  ncol(mammal_modelled),
  " cols"
)

# The climate offset the mammal habitat models take. It is
# produced by a separate climate pipeline, so it is copied in
# with survey_unit_id added, keyed the way the rest of the
# dataset is. A deployment with no climate prediction keeps the
# NA the v2 join would have produced.
if (file.exists(mammal_climate_pred_file)) {
  climate_pred <- as.data.frame(
    fread(mammal_climate_pred_file), stringsAsFactors = FALSE
  )

  unit_lookup <- do.call(rbind, lapply(
    names(mammal_parts),
    function(region) {
      data.frame(
        survey_unit_id =
          mammal_parts[[region]]$climate$survey_unit_id,
        location_project =
          mammal_parts[[region]]$climate$location_project,
        stringsAsFactors = FALSE
      )
    }
  ))

  climate_pred <- merge(
    unit_lookup, climate_pred,
    by = "location_project", all.x = TRUE, sort = FALSE
  )

  climate_pred <- climate_pred[
    , c(
      "survey_unit_id", "location_project",
      setdiff(
        names(climate_pred),
        c("survey_unit_id", "location_project")
      )
    )
  ]

  climate_pred_path <- file.path(
    lookup_dir, "mammal_climate_predictions.csv"
  )
  fwrite(climate_pred, climate_pred_path, na = "")

  uncovered <- sum(is.na(climate_pred[[3]]))

  message(
    "Wrote lookup/mammal_climate_predictions.csv: ",
    nrow(climate_pred),
    " rows x ",
    ncol(climate_pred),
    " cols; ",
    uncovered,
    " deployment(s) have no climate prediction"
  )
} else {
  warning(
    "Mammal climate predictions not found at ",
    mammal_climate_pred_file,
    "; the mammal habitat models cannot be fitted without them. ",
    "Set SDM_MAMMAL_CLIMATE_PRED.",
    call. = FALSE
  )
}

## 7.6 Write the bird offsets ----
# The QPAD offsets. Response-shaped rather than covariate-shaped:
# one value per survey and species, carrying the detectability
# correction each Poisson model takes as its offset. It is the
# largest table in the dataset by a wide margin.
offsets_path <- file.path(output_dir, "bird_offsets.csv")
fwrite(bird_parts$offsets, offsets_path, na = "")

message(
  "Wrote bird_offsets.csv: ",
  nrow(bird_parts$offsets),
  " rows x ",
  ncol(bird_parts$offsets),
  " cols (",
  round(file.size(offsets_path) / 1024^2),
  " MB)"
)

## 7.7 Write the bird lookups ----
# The species-region work queue, the bootstrap draws, and the
# factor levels in source order.
bird_modelled_path <- file.path(
  lookup_dir, "bird_modelled_species.csv"
)
fwrite(bird_parts$species_lists, bird_modelled_path, na = "")

message(
  "Wrote lookup/bird_modelled_species.csv: ",
  nrow(bird_parts$species_lists),
  " rows x ",
  ncol(bird_parts$species_lists),
  " cols"
)

# Raw surveyids, not survey_unit_ids: they join to the surveyid
# column carried in covariates.csv for taxon "bird". Keeping them
# raw holds the file to a tenth of the size prefixed keys need.
bird_boot_path <- file.path(
  lookup_dir, "bird_bootstrap_ids.csv"
)
fwrite(bird_parts$bootstrap, bird_boot_path, na = "")

message(
  "Wrote lookup/bird_bootstrap_ids.csv: ",
  nrow(bird_parts$bootstrap),
  " rows x ",
  ncol(bird_parts$bootstrap),
  " cols"
)

# Without this, re-reading a factor from CSV gives alphabetical
# levels, which moves the reference level and renames every
# coefficient the model reports.
bird_levels_path <- file.path(
  lookup_dir, "bird_factor_levels.csv"
)
fwrite(bird_parts$factor_levels, bird_levels_path, na = "")

message(
  "Wrote lookup/bird_factor_levels.csv: ",
  nrow(bird_parts$factor_levels),
  " rows x ",
  ncol(bird_parts$factor_levels),
  " cols"
)

message("Output written to ", output_dir)

# End of script ----
