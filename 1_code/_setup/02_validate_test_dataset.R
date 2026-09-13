# ---
# title: Validate the Harmonized Test Dataset
# author: Brendan Casey
# created: 2026-09-08
# inputs:
#   in 0_data/test_dataset/, written by
#   _setup/01_harmonize_model_ready_v2.R:
#     - sites.csv
#     - vascular_plant.csv
#     - bryophyte.csv
#     - lichen.csv
#     - mite.csv
#     - mammal.csv
#     - bird.csv
#     - bird_offsets.csv
#     - covariates.csv
#     - lookup/covariate_columns.csv
#     - lookup/veg_prediction_matrix.csv
#     - lookup/soil_prediction_matrix.csv
#     - lookup/modelled_species.csv
#     - lookup/mammal_<region>_prediction_matrix.csv
#     - lookup/mammal_modelled_species.csv
#     - lookup/mammal_climate_predictions.csv
#     - lookup/bird_modelled_species.csv
#     - lookup/bird_bootstrap_ids.csv
#     - lookup/bird_factor_levels.csv
#   from 0_data/data_snapshots/model_ready_v2/ on ABMI-DATA2:
#     - the four plant-group .Rdata files
#     - the two mammal SpTable .RData files
#   from the BirdModels shared drive, read-only:
#     - Data/Archive/2025/Stratified.Rdata
# outputs:
#   - none; every result is printed to the console
# notes:
#   Two passes over the harmonized dataset. Section 2 describes
#   it: sizes, coverage, value ranges, and whether the tables
#   join the way they are meant to. Section 3 traces every
#   written value back to the snapshot it came from: responses in
#   3.3 to 3.5, covariates in 3.6, and lookups in 3.7 to 3.9.
#
#   Covariates now live in one master table keyed on
#   survey_unit_id and taxon, not in a file per taxon and block.
#   Section 3.6 rebuilds each block from it using
#   lookup/covariate_columns.csv, which maps every master column
#   back to the block and the v2 spelling it came from. That is
#   also what catches a column being dropped or renamed, since a
#   block is only checked against the map's own account of it.
#
#   Covariate values are compared on relative difference, not
#   absolute. A CSV carries about 15 significant digits, so UTMY
#   at 6.6e6 comes back about 6e-9 away from the source; that is
#   a round-trip artefact, not a harmonization error.
#
#   Run after 01_harmonize_model_ready_v2.R, and again whenever
#   the snapshot or that script changes.
# ---

# 1. Setup ----

## 1.1 Load packages ----
library(data.table)

## 1.2 Configure paths ----
# data_dir holds the harmonized CSVs; snapshot_dir holds the
# read-only sources they were built from.
data_dir <- file.path(
  normalizePath(getwd(), winslash = "/"),
  "0_data/test_dataset"
)

snapshot_dir <- Sys.getenv(
  "SDM_SNAPSHOT_V2",
  unset = paste0(
    "//ABMI-DATA2/science/sc/sdmMethodsDev/0_data/",
    "data_snapshots/model_ready_v2"
  )
)

taxa <- c(
  "vascular_plant",
  "bryophyte",
  "lichen",
  "mite",
  "mammal",
  "bird"
)

# The bird data package, read-only on the BirdModels drive.
bird_data_file <- Sys.getenv(
  "SDM_BIRD_DATA",
  unset = paste0(
    "G:/.shortcut-targets-by-id/",
    "17Ymt13eHfKvIiuoMl6x-Kn74Z2uVbbzS/BirdModels/Data/",
    "Archive/2025/Stratified.Rdata"
  )
)

## 1.3 Read the harmonized CSVs ----
sites <- fread(file.path(data_dir, "sites.csv"), na.strings = "")

sp <- lapply(taxa, function(x) {
  fread(file.path(data_dir, paste0(x, ".csv")))
})
names(sp) <- taxa

# The master covariate table and the map that says which block
# and which v2 name each of its columns came from.
covariates <- fread(
  file.path(data_dir, "covariates.csv"),
  na.strings = ""
)

col_map <- fread(
  file.path(data_dir, "lookup", "covariate_columns.csv")
)

# 2. Describe the harmonized dataset ----
# What the six files hold, and whether they hold together.

## 2.1 File overview ----
# Rows, columns and size on disk.
print(data.table(
  file = c("sites", taxa),
  rows = c(nrow(sites), sapply(sp, nrow)),
  cols = c(ncol(sites), sapply(sp, ncol)),
  mb = round(
    file.info(
      file.path(data_dir, paste0(c("sites", taxa), ".csv"))
    )$size /
      1024^2,
    1
  )
))

## 2.1b Master covariate table ----
# One row per survey unit and taxon, not per survey unit. The
# plant files disagree on the same quadrat, so taxon is part of
# the key; see the header of 01_harmonize_model_ready_v2.R.
cat("\ncovariates.csv:", nrow(covariates), "rows x",
  ncol(covariates), "cols\n")
print(covariates[, .N, by = taxon])

# Columns are the union across taxa, so each taxon fills its own
# blocks and leaves the rest empty.
cat("\nnon-empty covariate columns per taxon:\n")
for (tx in unique(covariates$taxon)) {
  sub <- covariates[taxon == tx]
  filled <- sum(vapply(
    sub, function(x) as.numeric(!all(is.na(x))), numeric(1)
  ))
  cat(sprintf(
    "  %-15s %6d rows, %3d of %3d columns used\n",
    tx, nrow(sub), filled - 2, ncol(covariates) - 2
  ))
}

# Which columns were suffixed because two blocks share a name.
cat("\ncolumns suffixed by block:",
  sum(col_map$source_column != col_map$master_column),
  "of", nrow(col_map), "\n")

## 2.2 Site table ----
# Structure of sites.csv
str(sites)

# One row per design; each leaves the other's fields empty
print(head(sites[survey_design == "plant_quadrant"], 3))
print(head(sites[survey_design == "mammal_camera"], 3))
print(head(sites[survey_design == "bird_point_count"], 3))

# Survey units by design and region
print(sites[, .N, by = .(survey_design, region)])

# Units covered by each taxon file
print(sites[, lapply(.SD, sum), .SDcols = patterns("^in_")])

# Units sampled by all four plant taxa
print(sites[
  in_vascular_plant & in_bryophyte & in_lichen & in_mite,
  .N
])

# Temporal and spatial extent
print(sites[, .(
  first_year = min(year, na.rm = TRUE),
  last_year = max(year, na.rm = TRUE)
)])
print(summary(sites[, .(lat, long)]))

# Survey effort, which the mammal cameras alone carry
print(summary(sites[
  survey_design == "mammal_camera",
  .(summer_days, winter_days)
]))

## 2.3 Join integrity ----
# Every taxon key should resolve in sites.csv, with no repeats.
for (tx in taxa) {
  key <- sp[[tx]]$survey_unit_id
  cat(sprintf(
    "%-15s rows %6d | all in sites %-5s | dup keys %d\n",
    tx,
    length(key),
    all(key %in% sites$survey_unit_id),
    sum(duplicated(key))
  ))
}

## 2.4 Response values per taxon ----
# Three response scales, one per design.
#   Plants are 0/1 presence-absence, with no NAs.
#   Mammals are densities. A mammal NA is not a missing record:
#   the v2 script 02_process-data-files.R sets a season's
#   densities to NA when that season has fewer than 10
#   camera-days, so NA means too little effort to estimate from.
#   Birds are integer point counts, paired with a QPAD log
#   offset per survey and species in bird_offsets.csv.
# fill is the share of observed cells with a detection.
for (tx in taxa) {
  m <- as.matrix(sp[[tx]][, -1])
  cat(sprintf(
    "%-15s spp %5d | range %-12s | NA %6d | fill %.3f\n",
    tx,
    ncol(m),
    paste(round(range(m, na.rm = TRUE), 2), collapse = " - "),
    sum(is.na(m)),
    mean(m > 0, na.rm = TRUE)
  ))
}

## 2.5 Species prevalence ----

#' Rank a Taxon's Species by How Widely They Were Detected
#'
#' @param taxon Character. Name of one taxon CSV in `sp`.
#' @param n Integer. How many species to return.
#' @return A data.table of species and the proportion of
#'   surveyed units where each was detected.
#'
#' @example # Example usage of the function
#' # prevalence("mammal", 5)
prevalence <- function(taxon, n = 10) {
  # Step 1: Share of observed cells holding a detection
  m <- as.matrix(sp[[taxon]][, -1])
  p <- sort(colMeans(m > 0, na.rm = TRUE), decreasing = TRUE)

  # Step 2: Return the most widespread few
  data.table(
    species = names(p),
    prop_units = round(unname(p), 3)
  )[seq_len(n)]
}

# Most widespread vascular plants
print(prevalence("vascular_plant"))

# Most widespread mammals
print(prevalence("mammal"))

# Species never detected anywhere, which carry no signal
for (tx in taxa) {
  m <- as.matrix(sp[[tx]][, -1])
  cat(sprintf(
    "%-15s %4d of %5d species never detected\n",
    tx,
    sum(colSums(m > 0, na.rm = TRUE) == 0),
    ncol(m)
  ))
}

## 2.6 Richness per survey unit ----
# Species detected per survey unit.
for (tx in taxa) {
  r <- rowSums(as.matrix(sp[[tx]][, -1]) > 0, na.rm = TRUE)
  cat(sprintf(
    "%-15s richness  min %3.0f  median %6.1f  max %4.0f\n",
    tx,
    min(r),
    median(r),
    max(r)
  ))
}

## 2.7 Mammal specifics ----
mam <- sp$mammal
region <- sites[
  match(mam$survey_unit_id, sites$survey_unit_id),
  region
]

# Mammal rows by region
print(table(region))

# Season pairing: expect one 2 per species, and nothing else
mam_base <- sub("_(Summer|Winter)$", "", names(mam)[-1])
print(table(table(mam_base)))

## 2.8 Peek at a corner of each table ----
# First rows and columns of each taxon file.
for (tx in taxa) {
  cat("\n  ", tx, "\n", sep = "")
  print(sp[[tx]][1:3, 1:6])
}

## 2.9 Example join ----
# What the split layout is for: response from a taxon CSV,
# context from sites.csv, joined on survey_unit_id.
moose <- merge(
  mam[, .(survey_unit_id, Moose_Summer)],
  sites[, .(survey_unit_id, region, nr, lat, long, summer_days)],
  by = "survey_unit_id"
)

print(head(moose))

# Mean Moose_Summer by natural region, as a sanity check
print(moose[,
  .(
    mean_moose = round(mean(Moose_Summer, na.rm = TRUE), 3),
    units = .N
  ),
  by = nr
][order(-mean_moose)])

# 3. Compare the CSVs against the source files ----
# Round trip on 01_harmonize_model_ready_v2.R: every written
# value is traced back to the snapshot it came from.

## 3.1 Name the source files ----
plant_files <- c(
  vascular_plant = "vascular-plant-model-data.Rdata",
  bryophyte = "bryophyte-model-data.Rdata",
  lichen = "lichen-model-data.Rdata",
  mite = "mite-model-data.Rdata"
)

# The mammal climate offset, produced outside this repository.
mammal_climate_pred_file <- Sys.getenv(
  "SDM_MAMMAL_CLIMATE_PRED",
  unset = paste0(
    "G:/Shared drives/ABMI Mammals/Results/Habitat Modeling/",
    "2024/Climate/Predictions/",
    "All Species Climate Predictions.csv"
  )
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

## 3.2 Helper functions ----

#' Load a Snapshot File into an Isolated Environment
#'
#' @param file Character. File name within snapshot_dir.
#' @return An environment holding the file's objects.
#'
#' @example # Example usage of the function
#' # read_source("mite-model-data.Rdata")
read_source <- function(file) {
  # Step 1: Read into a fresh environment, so the six files
  # cannot overwrite each other's objects
  env <- new.env()
  load(file.path(snapshot_dir, file), envir = env)

  return(env)
}

#' Count Disagreements Between Two Blocks of Values
#'
#' NA patterns must match exactly, but values are compared with
#' a tolerance, because a double does not survive the CSV round
#' trip bit-exactly. max_diff reports the drift
#'
#' @param a,b Data frames or matrices of the same shape.
#' @param tol Numeric. Largest difference treated as equal.
#' @return A list with `n`, the count of disagreeing cells, and
#'   `max_diff`, the largest absolute difference seen.
#'
#' @example # Example usage of the function
#' # compare_blocks(csv[, ..spp], clim[, spp])
compare_blocks <- function(a, b, tol = 1e-9) {
  # Step 1: A shape mismatch is not comparable cell by cell
  a <- unname(as.matrix(a))
  b <- unname(as.matrix(b))

  if (!identical(dim(a), dim(b))) {
    return(list(n = NA_integer_, max_diff = NA_real_))
  }

  # Step 2: Count NA-pattern and value disagreements together
  delta <- abs(a - b)

  list(
    n = sum(xor(is.na(a), is.na(b))) +
      sum(delta > tol, na.rm = TRUE),
    max_diff = max(delta, na.rm = TRUE)
  )
}

# Results accumulate here so the checks read as one table.
checks <- list()

#' Record the Outcome of One Check
#'
#' @param source Character. Which file the check ran against.
#' @param check Character. What was tested.
#' @param pass Logical. Whether it held.
#' @param detail Character. Optional supporting figure.
#' @return Invisibly NULL. Appends to `checks`.
#'
#' @example # Example usage of the function
#' # note("mite", "keys match source", TRUE)
note <- function(source, check, pass, detail = "") {
  checks[[length(checks) + 1]] <<- data.table(
    source = source,
    check = check,
    pass = pass,
    detail = detail
  )

  invisible(NULL)
}

#' Reduce a Species String to a Column-Safe Token
#'
#' @param x Character. Species strings.
#' @return Character. CamelCase with no punctuation.
#'
#' @example # Example usage of the function
#' # squash("Voles, Mice and Allies")
#' # [1] "VolesMiceAndAllies"
squash <- function(x) {
  # Step 1: Delete apostrophes so they are not split points
  x <- gsub("'", "", x, fixed = TRUE)

  # Step 2: Split on the remaining punctuation and capitalize
  vapply(
    strsplit(x, "[^A-Za-z0-9]+"),
    function(p) {
      p <- p[nzchar(p)]
      paste0(
        toupper(substring(p, 1, 1)),
        substring(p, 2),
        collapse = ""
      )
    },
    character(1)
  )
}

#' Rebuild a Mammal Column Name as the Harmonizer Would
#'
#' @param cols Character. Source column names, each ending in
#'   "Summer" or "Winter".
#' @return Character. Harmonized names.
#'
#' @example # Example usage of the function
#' # harmonized_name("Black BearSummer")
#' # [1] "BlackBear_Summer"
harmonized_name <- function(cols) {
  season <- ifelse(grepl("Summer$", cols), "Summer", "Winter")

  paste0(squash(sub("(Summer|Winter)$", "", cols)), "_", season)
}

## 3.3 Plant taxa against source ----
# Columns each CSV left behind are collected into `omitted`, to
# confirm only identity, site and climate fields were cut.
omitted <- list()

for (tx in names(plant_files)) {
  cat("  ", tx, "\n", sep = "")
  csv <- fread(file.path(data_dir, paste0(tx, ".csv")))
  env <- read_source(plant_files[[tx]])
  clim <- env$climate.data
  spp <- setdiff(names(csv), "survey_unit_id")

  note(
    tx,
    "keys match source, in order",
    identical(csv$survey_unit_id, as.character(clim$SiteYearQu))
  )

  note(
    tx,
    "every CSV species exists in source",
    all(spp %in% names(clim)),
    paste(setdiff(spp, names(clim)), collapse = ", ")
  )

  cmp <- compare_blocks(csv[, ..spp], clim[, spp])
  note(
    tx,
    "all species values match source",
    cmp$n == 0,
    sprintf("%d cells, max diff %.1g", cmp$n, cmp$max_diff)
  )

  declared <- unique(c(
    env$veg.species.list,
    env$soil.species.list
  ))
  note(
    tx,
    "modelled species all carried through",
    all(declared %in% spp),
    paste(length(setdiff(declared, spp)), "missing")
  )

  s <- sites[match(csv$survey_unit_id, survey_unit_id)]

  note(
    tx,
    "site coordinates match source",
    isTRUE(all.equal(s$lat, as.numeric(clim$Lat))) &&
      isTRUE(all.equal(s$long, as.numeric(clim$Long)))
  )

  note(
    tx,
    "site design fields match source",
    identical(s$year, as.integer(clim$Year)) &&
      identical(s$quadrant, as.character(clim$QUAD)) &&
      identical(s$nr, as.character(clim$NR))
  )

  omitted[[tx]] <- setdiff(names(clim), spp)
}

## 3.4 Mammal against source ----
mam_csv <- fread(file.path(data_dir, "mammal.csv"))

for (rg in names(mammal_files)) {
  env <- read_source(mammal_files[[rg]])
  d <- as.data.frame(env$d, check.names = FALSE)
  src_cols <- names(d)[
    env$first_sp_col_summer:env$last_sp_col_winter
  ]
  out_cols <- harmonized_name(src_cols)
  lab <- paste("mammal", rg)
  cat("  ", lab, "\n", sep = "")

  rows <- which(startsWith(
    mam_csv$survey_unit_id,
    paste0("mammal_", rg, "|")
  ))

  note(lab, "row count matches source", length(rows) == nrow(d))

  # Suffixes disambiguate the repeated location_project values,
  # so strip them before comparing the keys back to source.
  keys <- sub("__[0-9]+$", "", mam_csv$survey_unit_id[rows])
  note(
    lab,
    "keys match source, in order",
    identical(
      keys,
      paste0("mammal_", rg, "|", d$location_project)
    )
  )

  note(
    lab,
    "harmonized names all present in CSV",
    all(out_cols %in% names(mam_csv)),
    paste(setdiff(out_cols, names(mam_csv)), collapse = ", ")
  )

  cmp <- compare_blocks(mam_csv[rows, ..out_cols], d[, src_cols])
  note(
    lab,
    "all species values match source",
    cmp$n == 0,
    sprintf("%d cells, max diff %.1g", cmp$n, cmp$max_diff)
  )

  # Species the other region carries but this one does not must
  # be NA here, never zero.
  all_spp <- setdiff(names(mam_csv), "survey_unit_id")
  absent <- setdiff(all_spp, out_cols)
  note(
    lab,
    "species absent from this region are NA",
    length(absent) == 0 ||
      all(is.na(as.matrix(mam_csv[rows, ..absent]))),
    paste(absent, collapse = ", ")
  )

  s <- sites[match(mam_csv$survey_unit_id[rows], survey_unit_id)]

  note(
    lab,
    "site fields match source",
    isTRUE(all.equal(s$lat, as.numeric(d$Lat))) &&
      identical(s$summer_days, as.integer(d$SummerDays)) &&
      identical(s$winter_days, as.integer(d$WinterDays)) &&
      identical(s$project, as.character(d$project))
  )
}

## 3.5 Covariates and lookups against source ----
# The covariate tables carry what the models regress against, so
# they are traced back the same way the responses were. Values
# are compared on relative difference; see the header.

#' Count Disagreements on Relative Difference
#'
#' The absolute counterpart, compare_blocks(), is right for the
#' response, whose values are small integers. Covariates span
#' UTM coordinates at 1e6 and cover proportions at 1e-4, so a
#' single absolute tolerance cannot serve both.
#'
#' @param a,b Data frames or matrices of the same shape.
#' @param tol Numeric. Largest relative difference treated as
#'   equal. The default is three orders of magnitude above the
#'   drift a 15-significant-digit CSV actually produces.
#' @return A list with `n`, the count of disagreeing cells, and
#'   `max_diff`, the largest relative difference seen.
#'
#' @example # Example usage of the function
#' # compare_blocks_rel(csv[, cols], clim[, cols])
compare_blocks_rel <- function(a, b, tol = 1e-12) {
  # Step 1: A shape mismatch is not comparable cell by cell
  a <- unname(as.matrix(a))
  b <- unname(as.matrix(b))

  if (!identical(dim(a), dim(b))) {
    return(list(n = NA_integer_, max_diff = NA_real_))
  }

  # Step 2: Scale each difference by the source magnitude, with
  # a floor so an exact zero does not divide by zero
  scale <- pmax(abs(b), 1e-300)
  delta <- abs(a - b) / scale

  list(
    n = sum(xor(is.na(a), is.na(b))) +
      sum(delta > tol, na.rm = TRUE),
    max_diff = max(delta, na.rm = TRUE)
  )
}

# The terms 01_harmonize_model_ready_v2.R leaves out of the
# climate table because they are products of stored columns, and
# the expressions the loader rebuilds them with.
derived_terms <- list(
  Easting2 = function(d) d$Easting * d$Easting,
  Northing2 = function(d) d$Northing * d$Northing,
  EastingNorthing = function(d) d$Northing * d$Easting,
  MAPPET = function(d) d$MAP * d$PET,
  MAT2 = function(d) d$MAT * d$MAT,
  CMDMAT = function(d) d$CMD * d$MAT,
  MWMT2 = function(d) d$MWMT * d$MWMT
)

#' Check One Taxon's Covariate Blocks Against Their Source
#'
#' Rebuilds each block from the master table using the column
#' map, then compares it to the frame it came from. The map is
#' what makes this possible: a master column may be suffixed
#' with its block, so the v2 spelling cannot be recovered from
#' the header alone.
#'
#' @param taxon_label Character. Value in covariates$taxon.
#' @param source_frames Named list of source data frames, one
#'   per block, named as the map names the blocks.
#' @param source_ids Character. The survey_unit_id each source
#'   row corresponds to, in source row order. NULL where the
#'   source has no key that survives into the dataset, as for
#'   mammals, whose repeated deployments are disambiguated with
#'   a numbered suffix; the rows are then compared by position
#'   and the row count is asserted instead.
#' @param label Character. Name used in the check output.
#' @return Invisibly NULL. Records checks through note().
#'
#' @example # Example usage of the function
#' # check_covariates("mite", frames, ids, "mite")
check_covariates <- function(taxon_label, source_frames,
                             source_ids, label) {
  sub <- as.data.frame(covariates[taxon == taxon_label])

  note(
    label,
    "covariate rows present",
    nrow(sub) > 0,
    paste(nrow(sub), "rows")
  )

  if (nrow(sub) == 0) {
    return(invisible(NULL))
  }

  # Step 1: Line the rows up with the source before any value is
  # compared, by key where there is one and by position where
  # there is not
  n_source <- nrow(source_frames[[1]])

  if (is.null(source_ids)) {
    note(
      label,
      "covariate row count matches source",
      nrow(sub) == n_source,
      paste(nrow(sub), "vs", n_source, "source rows")
    )

    if (nrow(sub) != n_source) {
      return(invisible(NULL))
    }

    row_order <- seq_len(nrow(sub))
  } else {
    row_order <- match(sub$survey_unit_id, source_ids)

    note(
      label,
      "covariate keys resolve in source",
      !anyNA(row_order),
      paste(sum(is.na(row_order)), "unresolved")
    )

    if (anyNA(row_order)) {
      return(invisible(NULL))
    }
  }

  # Step 2: One pass per block the map records for this taxon
  for (blk in names(source_frames)) {
    m <- col_map[taxon == taxon_label & block == blk]
    source_frame <- source_frames[[blk]]

    if (nrow(m) == 0) {
      note(label, paste(blk, "block recorded in the map"), FALSE)
      next
    }

    absent_master <- setdiff(m$master_column, names(sub))
    absent_source <- setdiff(m$source_column, names(source_frame))

    note(
      label,
      paste(blk, "columns present both sides"),
      length(absent_master) == 0 && length(absent_source) == 0,
      if (length(c(absent_master, absent_source)) > 0) {
        paste(
          utils::head(c(absent_master, absent_source), 5),
          collapse = ", "
        )
      } else {
        paste(nrow(m), "columns")
      }
    )

    if (length(absent_master) > 0 || length(absent_source) > 0) {
      next
    }

    # Step 3: Split by type. Numbers are compared on relative
    # difference, everything else has to round-trip exactly.
    is_num <- vapply(
      m$source_column,
      function(one) is.numeric(source_frame[[one]]),
      logical(1)
    )

    if (any(is_num)) {
      cmp <- compare_blocks_rel(
        sub[, m$master_column[is_num], drop = FALSE],
        source_frame[row_order, m$source_column[is_num],
          drop = FALSE
        ]
      )

      note(
        label,
        paste(blk, "numeric values match source"),
        isTRUE(cmp$n == 0),
        sprintf(
          "%d cols, max rel diff %.2e", sum(is_num), cmp$max_diff
        )
      )
    }

    other <- which(!is_num)
    mismatched <- character(0)

    for (i in other) {
      got <- as.character(sub[[m$master_column[i]]])
      src <- source_frame[row_order, m$source_column[i]]

      # A timestamp is stored formatted, not as POSIXct, so that
      # a CSV round trip cannot shift it by a time zone.
      if (inherits(src, "POSIXct")) {
        src <- format(src)
      }

      if (!identical(got, as.character(src))) {
        mismatched <- c(mismatched, m$source_column[i])
      }
    }

    if (length(other) > 0) {
      note(
        label,
        paste(blk, "non-numeric values match"),
        length(mismatched) == 0,
        if (length(mismatched) > 0) {
          paste(mismatched, collapse = ", ")
        } else {
          paste(length(other), "columns")
        }
      )
    }
  }

  invisible(NULL)
}

for (taxon in names(plant_files)) {
  src <- read_source(plant_files[[taxon]])
  clim <- src$climate.data

  check_covariates(
    taxon,
    list(
      climate = clim,
      veg = src$veg.data,
      soil = src$soil.data
    ),
    as.character(clim$SiteYearQu),
    taxon
  )

  # The seven derived terms are not stored. Confirm each rebuilds
  # from the stored columns to the value the snapshot holds.
  #
  # The filter value is held in its own variable: `taxon` is also
  # a column of the master table, and data.table would resolve
  # both sides of `taxon == taxon` to the column and keep every
  # row.
  this_taxon <- taxon
  clim_csv <- as.data.frame(covariates[taxon == this_taxon])

  sites_csv <- as.data.frame(sites)

  rebuild <- merge(
    clim_csv,
    sites_csv[, c("survey_unit_id", "easting", "northing")],
    by = "survey_unit_id",
    sort = FALSE
  )
  names(rebuild)[names(rebuild) == "easting"] <- "Easting"
  names(rebuild)[names(rebuild) == "northing"] <- "Northing"

  row_order <- match(
    rebuild$survey_unit_id, as.character(clim$SiteYearQu)
  )

  stored_terms <- intersect(names(derived_terms), names(clim))
  worst <- 0

  for (term in stored_terms) {
    cmp <- compare_blocks_rel(
      matrix(derived_terms[[term]](rebuild), ncol = 1),
      matrix(clim[row_order, term], ncol = 1)
    )
    worst <- max(worst, cmp$max_diff, na.rm = TRUE)
  }

  note(
    taxon,
    "derived terms rebuild from stored",
    worst <= 1e-12,
    sprintf(
      "%d terms, max rel diff %.2e", length(stored_terms), worst
    )
  )

  # The two species lists are the work queue, and each has its
  # own ordering that modelled_species.csv has to preserve.
  modelled <- as.data.frame(fread(
    file.path(data_dir, "lookup", "modelled_species.csv")
  ))
  modelled <- modelled[modelled$taxon == taxon, ]

  veg_rows <- modelled[modelled$in_veg_models, ]
  soil_rows <- modelled[modelled$in_soil_models, ]

  note(
    taxon,
    "veg species list round-trips",
    identical(
      veg_rows$species[order(veg_rows$veg_order)],
      src$veg.species.list
    ),
    paste(nrow(veg_rows), "species")
  )

  note(
    taxon,
    "soil species list round-trips",
    identical(
      soil_rows$species[order(soil_rows$soil_order)],
      src$soil.species.list
    ),
    paste(nrow(soil_rows), "species")
  )
}

# The prediction matrices are written once for all four taxa, so
# they are checked once, against the last taxon read above.
veg_pm_csv <- as.data.frame(fread(
  file.path(data_dir, "lookup", "veg_prediction_matrix.csv")
))
soil_pm_csv <- as.data.frame(fread(
  file.path(data_dir, "lookup", "soil_prediction_matrix.csv")
))

# The four aggregate columns the vegetation models are predicted
# onto. They are absent from the snapshot's veg.pm and present in
# the v2 project's veg-prediction-matrix-CC_2024.csv, so this
# check reports which of the two was written.
veg_aggregates <- c("Peatland", "Mineral", "Upland", "CCR1234")
have_aggregates <- all(
  veg_aggregates %in% colnames(veg_pm_csv)
)

note(
  "lookup",
  "veg prediction matrix is the v2 CSV",
  have_aggregates,
  if (have_aggregates) {
    "has the aggregate columns"
  } else {
    paste0(
      "snapshot veg.pm fallback; no ",
      paste(
        setdiff(veg_aggregates, colnames(veg_pm_csv)),
        collapse = ", "
      ),
      " - vegetation models cannot be fitted"
    )
  }
)

note(
  "lookup",
  "soil prediction matrix matches source",
  isTRUE(all.equal(
    soil_pm_csv, src$soil.pm,
    check.attributes = FALSE
  )),
  paste(nrow(soil_pm_csv), "rows x", ncol(soil_pm_csv), "cols")
)

## 3.6 Mammal covariates and lookups against source ----
# Mammal covariates come from the same two SpTable files as the
# mammal response, and are written per region because north and
# south are separate models on overlapping deployments.

mammal_habitat_name <- c(north = "veg", south = "soil")

for (region in names(mammal_files)) {
  env <- read_source(mammal_files[[region]])
  d <- as.data.frame(env$d, stringsAsFactors = FALSE)
  label <- paste("mammal", region)

  # Mammal covariates carry a taxon of mammal_<region>, because
  # north and south are separate models on overlapping
  # deployments. The habitat block is called veg in the north and
  # soil in the south, matching the model each one feeds.
  habitat <- mammal_habitat_name[[region]]
  frames <- list(d, d)
  names(frames) <- c("climate", habitat)

  check_covariates(
    paste0("mammal_", region),
    frames,
    NULL,
    label
  )

  # The prediction matrix travels with the snapshot rather than
  # being copied from the ABMI Mammals drive, because the two
  # were checked and are the same.
  pm_path <- file.path(
    data_dir, "lookup",
    paste0("mammal_", region, "_prediction_matrix.csv")
  )

  note(
    label,
    "prediction matrix matches source",
    isTRUE(all.equal(
      as.data.frame(fread(pm_path)),
      as.data.frame(env$pred_matrix),
      check.attributes = FALSE
    )),
    paste(nrow(env$pred_matrix), "rows")
  )

  # Four ordered lists per region: each season at the modelling
  # threshold and at the use-availability threshold.
  modelled <- as.data.frame(fread(
    file.path(data_dir, "lookup", "mammal_modelled_species.csv")
  ))
  modelled <- modelled[modelled$region == region, ]

  for (season in c("summer", "winter")) {
    rows <- modelled[modelled$season == season, ]

    in_models <- rows$in_models
    got_models <- rows$species_season[in_models][
      order(rows$model_order[in_models])
    ]

    in_ua <- rows$in_ua_models
    got_ua <- rows$species_season[in_ua][
      order(rows$ua_order[in_ua])
    ]

    note(
      label,
      paste(season, "species list round-trips"),
      identical(got_models, env[[paste0("sp_table_", season)]]),
      paste(length(got_models), "species")
    )

    note(
      label,
      paste(season, "ua species list round-trips"),
      identical(
        got_ua, env[[paste0("sp_table_", season, "_ua")]]
      ),
      paste(length(got_ua), "species")
    )
  }
}

## 3.6.1 Mammal climate predictions ----
# The offset the habitat models take, produced by a separate
# climate pipeline and copied in with survey_unit_id added.
climate_pred_path <- file.path(
  data_dir, "lookup", "mammal_climate_predictions.csv"
)

if (file.exists(climate_pred_path) &&
      file.exists(mammal_climate_pred_file)) {
  written <- as.data.frame(
    fread(climate_pred_path, na.strings = "")
  )
  source_pred <- as.data.frame(fread(mammal_climate_pred_file))

  pred_species <- setdiff(
    names(written), c("survey_unit_id", "location_project")
  )

  note(
    "mammal climate",
    "species columns match source",
    identical(
      pred_species,
      setdiff(names(source_pred), "location_project")
    ),
    paste(length(pred_species), "species")
  )

  row_match <- match(
    written$location_project, source_pred$location_project
  )
  covered <- !is.na(row_match)

  cmp <- compare_blocks_rel(
    written[covered, pred_species],
    source_pred[row_match[covered], pred_species]
  )

  note(
    "mammal climate",
    "predictions match source",
    isTRUE(cmp$n == 0),
    sprintf(
      "%d of %d rows covered, max rel diff %.2e",
      sum(covered), nrow(written), cmp$max_diff
    )
  )

  # A deployment the climate pipeline did not reach must carry
  # NA, which is what the v2 join would have produced.
  note(
    "mammal climate",
    "uncovered deployments are NA",
    all(is.na(written[!covered, pred_species])),
    paste(sum(!covered), "uncovered")
  )
} else {
  note(
    "mammal climate",
    "predictions available",
    FALSE,
    "file not found; set SDM_MAMMAL_CLIMATE_PRED"
  )
}

## 3.6.2 Bird response, offsets and covariates ----
# Birds come from one file rather than the snapshot. Its three
# frames are stored row-aligned on surveyid, so the key is
# rebuilt the same way 01_harmonize_model_ready_v2.R does.
if (file.exists(bird_data_file)) {
  benv <- new.env()
  load(bird_data_file, envir = benv)

  bcovs <- as.data.frame(benv$covs)
  bkey <- paste0("bird|", as.integer(bcovs$surveyid))

  bird_csv <- fread(file.path(data_dir, "bird.csv"))
  bird_spp <- setdiff(names(bird_csv), "survey_unit_id")

  note(
    "bird",
    "keys match source, in order",
    identical(bird_csv$survey_unit_id, bkey),
    paste(nrow(bird_csv), "surveys")
  )

  cmp <- compare_blocks(
    bird_csv[, ..bird_spp], benv$bird[, bird_spp]
  )
  note(
    "bird",
    "counts match source",
    isTRUE(cmp$n == 0),
    sprintf("%d cells, max diff %.1g", cmp$n, cmp$max_diff)
  )

  # Counts feed a Poisson model, so they have to be whole and
  # non-negative for the fit to mean anything.
  bird_counts <- as.matrix(bird_csv[, ..bird_spp])
  note(
    "bird",
    "counts are non-negative whole numbers",
    !anyNA(bird_counts) &&
      all(bird_counts >= 0) &&
      all(bird_counts %% 1 == 0),
    paste("max", max(bird_counts))
  )

  # Offsets are response-shaped: one per survey and species, and
  # the model cannot run without the pair.
  off_csv <- fread(file.path(data_dir, "bird_offsets.csv"))

  note(
    "bird",
    "offsets share the response layout",
    identical(names(off_csv), names(bird_csv)) &&
      identical(off_csv$survey_unit_id, bkey),
    paste(ncol(off_csv) - 1, "species")
  )

  cmp <- compare_blocks(
    off_csv[, ..bird_spp], benv$off[, bird_spp]
  )
  note(
    "bird",
    "offsets match source",
    isTRUE(cmp$n == 0),
    sprintf("%d cells, max diff %.1g", cmp$n, cmp$max_diff)
  )

  note(
    "bird",
    "every count has an offset",
    !anyNA(as.matrix(off_csv[, ..bird_spp])),
    paste(sum(is.na(as.matrix(off_csv[, ..bird_spp]))), "NA")
  )

  check_covariates(
    "bird",
    list(
      climate = bcovs,
      veg = bcovs,
      soil = bcovs,
      design = bcovs
    ),
    bkey,
    "bird"
  )

  ## 3.6.3 Bird lookups ----
  bird_modelled <- fread(
    file.path(data_dir, "lookup", "bird_modelled_species.csv")
  )

  note(
    "bird",
    "modelled species round-trip",
    nrow(bird_modelled) == nrow(benv$birdlist) &&
      setequal(bird_modelled$species, benv$birdlist$species),
    paste(
      nrow(bird_modelled), "rows,",
      length(unique(bird_modelled$species)), "species"
    )
  )

  note(
    "bird",
    "modelled species are response columns",
    all(unique(bird_modelled$species) %in% bird_spp),
    paste(
      length(setdiff(unique(bird_modelled$species), bird_spp)),
      "missing"
    )
  )

  # The source names the bootstrap columns "1" to "100", which a
  # CSV header cannot be told apart from a row of data. They are
  # renamed on write, so the check is on shape and values.
  boot_csv <- fread(
    file.path(data_dir, "lookup", "bird_bootstrap_ids.csv")
  )

  note(
    "bird",
    "bootstrap draws match source",
    identical(dim(boot_csv), dim(as.data.frame(benv$boot))) &&
      all(as.matrix(boot_csv) == as.matrix(benv$boot)),
    paste(nrow(boot_csv), "x", ncol(boot_csv))
  )

  bird_design_ids <- covariates[taxon == "bird"]$surveyid

  note(
    "bird",
    "bootstrap draws resolve to a survey",
    all(unique(unlist(boot_csv)) %in% bird_design_ids),
    paste(
      length(setdiff(unique(unlist(boot_csv)), bird_design_ids)),
      "orphan draws"
    )
  )

  # Factor levels have to travel separately: read back from a
  # CSV a factor takes alphabetical levels, which moves the
  # reference level and renames every coefficient.
  levels_csv <- fread(
    file.path(data_dir, "lookup", "bird_factor_levels.csv")
  )

  factor_cols <- names(bcovs)[
    vapply(bcovs, is.factor, logical(1))
  ]

  levels_ok <- all(vapply(
    factor_cols,
    function(one) {
      got <- levels_csv[column == one][order(level_order)]$level
      identical(got, levels(bcovs[[one]]))
    },
    logical(1)
  ))

  note(
    "bird",
    "factor levels kept in source order",
    levels_ok,
    paste(factor_cols, collapse = ", ")
  )
} else {
  note(
    "bird",
    "data package reachable",
    FALSE,
    "file not found; set SDM_BIRD_DATA"
  )
}

## 3.7 Verdict ----
# Every check, then the tally. A FAIL means the CSVs no longer
# match the snapshot they claim to come from.
results <- rbindlist(checks)

for (i in seq_len(nrow(results))) {
  cat(sprintf(
    "%-4s %-15s %-38s %s\n",
    if (isTRUE(results$pass[i])) "ok" else "FAIL",
    results$source[i],
    results$check[i],
    results$detail[i]
  ))
}

cat(sprintf(
  "\n%d of %d checks passed\n",
  sum(results$pass, na.rm = TRUE),
  nrow(results)
))

# Columns the plant detection CSVs left behind.
# Confirm by eye that these are identity, site and climate fields
# only, and that no species is among them.
print(omitted)

# End of script ----
