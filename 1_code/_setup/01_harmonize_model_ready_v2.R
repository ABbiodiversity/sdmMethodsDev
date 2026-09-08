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
# notes:
#   Source files use two incompatible survey designs, so
#   they are harmonized into one shared convention rather than
#   one table: every taxon CSV is `survey_unit_id` followed by
#   that taxon's species columns, and every identity, design and
#   location field is factored out into sites.csv. Join any taxon
#   CSV to sites.csv on survey_unit_id.
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

## 1.5 Name the WildTrax species lookup ----
# The naming authority for mammal species.
wt_species_file <- Sys.getenv(
  "SDM_WT_SPECIES",
  unset = paste0(
    "G:/Shared drives/ABMI Mammals/Data/Lookup Tables/",
    "WildTrax Species Strings.RData"
  )
)

## 1.6 Check the inputs are reachable ----
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
#'   columns) and `sites` (one row per survey unit).
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

## 2.7 read_mammal_region() ----

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

  message(
    "  mammal ",
    region,
    ": ",
    nrow(species),
    " units x ",
    length(species_cols),
    " species-season columns"
  )

  return(list(species = species, sites = sites))
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

## 3.2 Read the mammal files ----
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
message("Output written to ", output_dir)

# End of script ----
