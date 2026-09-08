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
# outputs:
#   in 0_data/test_dataset/:
#     - sites.csv           one row per survey unit, all sources
#     - vascular_plant.csv  survey_unit_id + species columns
#     - bryophyte.csv       survey_unit_id + species columns
#     - lichen.csv          survey_unit_id + species columns
#     - mite.csv            survey_unit_id + species columns
#     - mammal.csv          survey_unit_id + species columns
#   in 0_data/test_dataset/covariates/, per plant-group taxon:
#     - <taxon>_climate.csv  survey_unit_id + climate covariates
#     - <taxon>_veg.csv      survey_unit_id + north veg and HF
#     - <taxon>_soil.csv     survey_unit_id + south soil and HF
#   and for mammals, per region:
#     - mammal_north_climate.csv, mammal_north_veg.csv
#     - mammal_south_climate.csv, mammal_south_soil.csv
#   in 0_data/test_dataset/lookup/:
#     - veg_prediction_matrix.csv   north habitat prediction grid
#     - soil_prediction_matrix.csv  south habitat prediction grid
#     - modelled_species.csv        which species each model set
#                                   is fitted for, per plant taxon
#     - mammal_<region>_prediction_matrix.csv
#     - mammal_modelled_species.csv
#     - mammal_climate_predictions.csv
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
#   1_code/modules/plants/ can run from 0_data/test_dataset/
#   alone rather than reaching back to the snapshot.
#
#   Covariates are written per taxon rather than once, because
#   the four files do not agree. Bryophyte, lichen and vascular
#   plant share identical veg and soil values on shared survey
#   units, but mite does not: its veg and soil blocks differ on
#   nearly every column while its climate block matches exactly.
#   That points at a different spatial support or HF vintage in
#   the mite source, so the four are kept separate rather than
#   reconciled here.
#
#   Mammal covariates come from the same two SpTable files as
#   the mammal response, because those files are themselves the
#   output of the v2 scripts in 0_data/v2_scripts/mammals/. Their
#   embedded pred_matrix objects were checked against
#   prediction-matrix_north.csv and Prediction matrix for ABMI
#   South coefficients 2020.csv on the ABMI Mammals drive and are
#   identical, so no separate lookup is needed for them.
#
#   Mammals are written per region rather than per taxon. North
#   and south are separate models on overlapping deployments -
#   512 location_project values appear in both files - so their
#   covariates cannot be stacked into one table the way the
#   response is.
#
#   Set SDM_V2_LOOKUP to the v2 project folder holding
#   veg-prediction-matrix-CC_2024.csv and
#   soil-prediction-matrix_2024.csv. Without it the prediction
#   matrices fall back to the snapshot's veg.pm and soil.pm, and
#   the vegetation models cannot be fitted - see section 1.5.
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

# Covariates and lookups are split into their own folders so the
# response tables stay the obvious contents of test_dataset/.
covariate_dir <- file.path(output_dir, "covariates")
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

## 1.6 Name the mammal climate predictions ----
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

## 1.7 Name the v2 prediction-matrix lookups ----
# The v2 modelling scripts do not use the veg.pm and soil.pm
# objects carried in the snapshot. They read these two CSVs from
# the v2 project instead, and the two are not the same: veg.pm is
# missing the aggregate habitat columns - Peatland, Mineral,
# Upland and CCR1234 - that four of the twelve vegetation models
# are predicted onto.
#
# So the CSVs are preferred when SDM_V2_LOOKUP points at them,
# and the snapshot objects are the fallback. Section 7.4 says
# which was used, because a fallback run cannot fit the
# vegetation models.
v2_lookup_dir <- Sys.getenv("SDM_V2_LOOKUP", unset = NA_character_)

v2_lookup_files <- c(
  veg_prediction_matrix = "veg-prediction-matrix-CC_2024.csv",
  soil_prediction_matrix = "soil-prediction-matrix_2024.csv"
)

## 1.8 Name the WildTrax species lookup ----
# The naming authority for mammal species.
wt_species_file <- Sys.getenv(
  "SDM_WT_SPECIES",
  unset = paste0(
    "G:/Shared drives/ABMI Mammals/Data/Lookup Tables/",
    "WildTrax Species Strings.RData"
  )
)

## 1.9 Check the inputs are reachable ----
# Fail before any reading, so a disconnected drive is obvious.
all_files <- c(
  file.path(snapshot_dir, c(plant_files, mammal_files)),
  wt_species_file
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

## 2.8 read_mammal_region() ----

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
    lapply(mammal_parts, function(x) x$sites)
  )
)
rownames(all_sites) <- NULL

## 5.2 Record which taxon files cover each unit ----
# The four plant taxa share the SiteYearQu key but sample
# different unit sets. The flags make that coverage explicit.
taxon_units <- c(
  lapply(plant_parts, function(x) x$species$survey_unit_id),
  list(mammal = mammal_species$survey_unit_id)
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

# 6. Validate the assembled tables ----
# Cheap checks that would catch a layout change in a future
# snapshot before the CSVs are trusted downstream.

species_tables <- c(
  lapply(plant_parts, function(x) x$species),
  list(mammal = mammal_species)
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
# describe exactly the same set.
for (taxon in names(covariate_parts)) {
  response_ids <- species_tables[[taxon]]$survey_unit_id

  for (block in c("climate", "veg", "soil")) {
    block_ids <- covariate_parts[[taxon]][[block]]$survey_unit_id

    if (!setequal(response_ids, block_ids)) {
      stop(
        taxon,
        ": the ",
        block,
        " covariates and the response cover different survey ",
        "units (",
        length(setdiff(response_ids, block_ids)),
        " missing, ",
        length(setdiff(block_ids, response_ids)),
        " extra).",
        call. = FALSE
      )
    }
  }
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

## 7.3 Write the plant-group covariate tables ----
# Three per taxon, each keyed on survey_unit_id like the response
# tables, so a model-data frame is rebuilt by joining rather than
# by trusting column positions.
dir.create(covariate_dir, recursive = TRUE, showWarnings = FALSE)

for (taxon in names(covariate_parts)) {
  for (block in c("climate", "veg", "soil")) {
    path <- file.path(
      covariate_dir,
      paste0(taxon, "_", block, ".csv")
    )
    fwrite(covariate_parts[[taxon]][[block]], path, na = "")

    message(
      "Wrote covariates/",
      basename(path),
      ": ",
      nrow(covariate_parts[[taxon]][[block]]),
      " rows x ",
      ncol(covariate_parts[[taxon]][[block]]),
      " cols"
    )
  }
}

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
  if (is.na(v2_lookup_dir)) {
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

## 7.5 Write the mammal covariate tables ----
# Per region, not per taxon. North and south are separate models
# on overlapping deployments, so their covariates cannot be
# stacked the way the response is. The habitat block is named
# veg in the north and soil in the south, matching the plant
# convention and the model each one feeds.
mammal_habitat_names <- c(north = "veg", south = "soil")

for (region in names(mammal_parts)) {
  blocks <- list(
    climate = mammal_parts[[region]]$climate,
    habitat = mammal_parts[[region]]$habitat
  )

  names(blocks)[2] <- mammal_habitat_names[[region]]

  for (block in names(blocks)) {
    path <- file.path(
      covariate_dir,
      paste0("mammal_", region, "_", block, ".csv")
    )
    fwrite(blocks[[block]], path, na = "")

    message(
      "Wrote covariates/",
      basename(path),
      ": ",
      nrow(blocks[[block]]),
      " rows x ",
      ncol(blocks[[block]]),
      " cols"
    )
  }
}

## 7.6 Write the mammal lookups ----
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

message("Output written to ", output_dir)

# End of script ----
