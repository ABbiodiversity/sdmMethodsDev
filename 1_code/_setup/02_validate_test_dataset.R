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
#   from 0_data/data_snapshots/model_ready_v2/ on ABMI-DATA2:
#     - the four plant-group .Rdata files
#     - the two mammal SpTable .RData files
# outputs:
#   - none; every result is printed to the console
# notes:
#   Two passes over the harmonized dataset. Section 2 describes
#   it: sizes, coverage, value ranges, and whether the two-file
#   layout joins the way it is meant to. Section 3 traces every
#   written value back to the snapshot it came from.
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
  "mammal"
)

## 1.3 Read the harmonized CSVs ----
sites <- fread(file.path(data_dir, "sites.csv"), na.strings = "")

sp <- lapply(taxa, function(x) {
  fread(file.path(data_dir, paste0(x, ".csv")))
})
names(sp) <- taxa

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

## 2.2 Site table ----
# Structure of sites.csv
str(sites)

# One row per design; each leaves the other's fields empty
print(head(sites[survey_design == "plant_quadrant"], 3))
print(head(sites[survey_design == "mammal_camera"], 3))

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
# Plants are 0/1 presence-absence, with no NAs.
# Mammals are densities. A mammal NA is not a missing
# record either. The v2 script 02_process-data-files.R
# sets a season's densities to NA when that season has
# fewer than 10 camera-days, so NA means too little
# effort to estimate from.
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

## 3.5 Verdict ----
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
