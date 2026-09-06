# ---
# title: Scratch Work
# author: Brendan Casey
# created: 2026-09-06
# inputs:
#   - ad hoc, temporary inputs as needed
# outputs:
#   - none by default
# notes:
#   Temporary workspace for testing, exploration, and one-off
#   tasks. Keep work grouped under dated headings and move any
#   durable code into the appropriate script or module.
#
#   Headings run three deep, so the Outline menu reads as a
#   day > task > step outline:
#     # YYYY-MM-DD ----  one per day of scratch work
#     ## Task ----       one per piece of work that day, named
#                        for what it does, not for the date
#     ### Step ----      stages within a task; the first is
#                        Setup, loading packages and data
#
#   Add new code under the current date heading, creating that
#   heading if the day does not have one yet. A day with only
#   one task still gets both a date and a task heading, so the
#   outline stays the same shape throughout.
# ---

# 2026-09-06 ----

## Inspect the harmonized test dataset ----
# Read the six CSVs written by
# _setup/01_harmonize_model_ready_v2.R and check they hold
# together: that every taxon key resolves in sites.csv, that the
# response values are on the scale each taxon should be on, and
# that the two-file layout joins the way it is meant to.

### Setup ----
library(data.table)

data_dir <- file.path(
  normalizePath(getwd(), winslash = "/"),
  "0_data/test_dataset"
)

taxa <- c(
  "vascular_plant",
  "bryophyte",
  "lichen",
  "mite",
  "mammal"
)

sites <- fread(file.path(data_dir, "sites.csv"))

sp <- lapply(taxa, function(x) {
  fread(file.path(data_dir, paste0(x, ".csv")))
})
names(sp) <- taxa

### File overview ----
# File overview: rows, columns and size on disk
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

### Site table ----
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

### Join integrity ----
# Every taxon key should resolve in sites.csv, with no repeats
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

### Response values per taxon ----
# Plants are 0/1 with no NAs; mammals are counts and carry NAs
# NA means not tabulated, which is not the same as zero.
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

### Species prevalence ----
# Proportion of surveyed units where each species was detected.
prevalence <- function(taxon, n = 10) {
  m <- as.matrix(sp[[taxon]][, -1])
  p <- sort(colMeans(m > 0, na.rm = TRUE), decreasing = TRUE)

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

### Richness per survey unit ----
# Species detected per survey unit
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

### Mammal specifics ----
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

# Raccoon: South-only, and the one name absent from WildTrax
cat(
  "Raccoon_Summer all NA in north:",
  all(is.na(mam$Raccoon_Summer[region == "north"])),
  "\n"
)
cat(
  "Raccoon_Summer observed in south:",
  sum(!is.na(mam$Raccoon_Summer[region == "south"])),
  "rows\n"
)

### Peek at a corner of each table ----
# First rows and columns of each taxon file
for (tx in taxa) {
  cat("\n  ", tx, "\n", sep = "")
  print(sp[[tx]][1:3, 1:6])
}

### Example join ----
# What the split layout is for: response joined to context
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

## Compare the CSVs against the source .RData files ----
# Round trip on 01_harmonize_model_ready_v2.R: every written
# value is traced back to the snapshot it came from. This does
# not call that script's functions, and restates the few rules it
# needs, so a bug in the harmonizer shows up here instead of
# cancelling itself out.

### Setup ----
# Round trip: every written value traced back to the snapshot
# The harmonizer's own functions are not used, so a bug there
# shows up here rather than cancelling itself out.

library(data.table)

snapshot_dir <- Sys.getenv(
  "SDM_SNAPSHOT_V2",
  unset = paste0(
    "//ABMI-DATA2/science/sc/sdmMethodsDev/0_data/",
    "data_snapshots/model_ready_v2"
  )
)

out_dir <- file.path(
  normalizePath(getwd(), winslash = "/"),
  "0_data/test_dataset"
)

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

# na.strings = "" matters here: fwrite wrote NA as empty, and
# without this the character columns read back as "" and every
# is.na() test below would silently return FALSE.
site_csv <- fread(
  file.path(out_dir, "sites.csv"),
  na.strings = ""
)

read_source <- function(file) {
  env <- new.env()
  load(file.path(snapshot_dir, file), envir = env)
  env
}

# Count disagreements between two blocks. NA patterns must match
# exactly, but values are compared with a tolerance: fwrite emits
# 15 significant digits, so a double does not survive the CSV
# round trip bit-exactly. The plant 0/1 blocks come back exact;
# the mammal counts drift by ~1e-13, which max_diff makes
# visible rather than hiding behind a tolerance.
compare_blocks <- function(a, b, tol = 1e-9) {
  a <- unname(as.matrix(a))
  b <- unname(as.matrix(b))

  if (!identical(dim(a), dim(b))) {
    return(list(n = NA_integer_, max_diff = NA_real_))
  }

  delta <- abs(a - b)

  list(
    n = sum(xor(is.na(a), is.na(b))) + sum(delta > tol, na.rm = TRUE),
    max_diff = max(delta, na.rm = TRUE)
  )
}

# Results accumulate here so the checks read as one table.
checks <- list()

note <- function(source, check, pass, detail = "") {
  checks[[length(checks) + 1]] <<- data.table(
    source = source,
    check = check,
    pass = pass,
    detail = detail
  )
}

### Plant taxa against source ----
# Checking the four plant-group CSVs against their .Rdata files
# Columns each CSV left behind are collected into `omitted`,
# to confirm only identity, site and climate fields were cut.

omitted <- list()

for (tx in names(plant_files)) {
  cat("     ", tx, "\n", sep = "")
  csv <- fread(file.path(out_dir, paste0(tx, ".csv")))
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

  declared <- unique(c(env$veg.species.list, env$soil.species.list))
  note(
    tx,
    "modelled species all carried through",
    all(declared %in% spp),
    paste(length(setdiff(declared, spp)), "missing")
  )

  s <- site_csv[match(csv$survey_unit_id, survey_unit_id)]

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

### Mammal against source ----
# Checking mammal.csv against the North and South .RData files
# Column names are rebuilt here as punctuation-stripped
# CamelCase. That they match confirms the WildTrax lookup only
# ever canonicalized punctuation, never renamed a species.

squash <- function(x) {
  x <- gsub("'", "", x, fixed = TRUE)
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

harmonized_name <- function(cols) {
  season <- ifelse(grepl("Summer$", cols), "Summer", "Winter")
  paste0(squash(sub("(Summer|Winter)$", "", cols)), "_", season)
}

mam_csv <- fread(file.path(out_dir, "mammal.csv"))

for (rg in names(mammal_files)) {
  env <- read_source(mammal_files[[rg]])
  d <- as.data.frame(env$d, check.names = FALSE)
  src_cols <- names(d)[
    env$first_sp_col_summer:env$last_sp_col_winter
  ]
  out_cols <- harmonized_name(src_cols)
  lab <- paste("mammal", rg)
  cat("     ", lab, "\n", sep = "")

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
    identical(keys, paste0("mammal_", rg, "|", d$location_project))
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

  s <- site_csv[match(mam_csv$survey_unit_id[rows], survey_unit_id)]

  note(
    lab,
    "site fields match source",
    isTRUE(all.equal(s$lat, as.numeric(d$Lat))) &&
      identical(s$summer_days, as.integer(d$SummerDays)) &&
      identical(s$winter_days, as.integer(d$WinterDays)) &&
      identical(s$project, as.character(d$project))
  )
}

### Verdict ----
# Every check, most specific first
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

# Columns the plant CSVs left behind
# Confirm by eye that these are identity, site and climate
# fields only, and that no species is among them.
print(omitted)

# End of script ----
