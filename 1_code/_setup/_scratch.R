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
#   Headings run three deep, so the Jump To menu reads as a
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
# Read-only; nothing here writes back to 0_data/.

### Setup ----
library(data.table) # fast CSV reading (version: 1.18.0)

data_dir <- file.path(
  normalizePath(getwd(), winslash = "/"), "0_data/test_dataset"
)

taxa <- c(
  "vascular_plant", "bryophyte", "lichen", "mite", "mammal"
)

sites <- fread(file.path(data_dir, "sites.csv"))

sp <- lapply(taxa, function(x) {
  fread(file.path(data_dir, paste0(x, ".csv")))
})
names(sp) <- taxa

### File overview ----
# Row and column counts against file size on disk.
data.table(
  file = c("sites", taxa),
  rows = c(nrow(sites), sapply(sp, nrow)),
  cols = c(ncol(sites), sapply(sp, ncol)),
  mb = round(
    file.info(
      file.path(data_dir, paste0(c("sites", taxa), ".csv"))
    )$size / 1024^2,
    1
  )
)

### Site table ----
str(sites)

# The two survey designs carry different identity fields, so each
# leaves the other's columns empty.
head(sites[survey_design == "plant_quadrant"], 3)
head(sites[survey_design == "mammal_camera"], 3)

sites[, .N, by = .(survey_design, region)]

# How many units each taxon file covers, and how many plant units
# all four plant taxa share.
sites[, lapply(.SD, sum), .SDcols = patterns("^in_")]
sites[in_vascular_plant & in_bryophyte & in_lichen & in_mite, .N]

# Temporal and spatial extent
sites[, .(
  first_year = min(year, na.rm = TRUE),
  last_year = max(year, na.rm = TRUE)
)]
summary(sites[, .(lat, long)])

# Effort exists for the mammal cameras only
summary(sites[
  survey_design == "mammal_camera",
  .(summer_days, winter_days)
])

### Join integrity ----
# Every taxon key should resolve in sites.csv, with no repeats.
for (tx in taxa) {
  key <- sp[[tx]]$survey_unit_id
  cat(sprintf(
    "%-15s rows %6d | all in sites %-5s | dup keys %d\n",
    tx, length(key), all(key %in% sites$survey_unit_id),
    sum(duplicated(key))
  ))
}

### Response values per taxon ----
# Plants are 0/1 with no NAs; mammals are continuous counts and
# do carry NAs, which mean "not tabulated", not zero.
for (tx in taxa) {
  m <- as.matrix(sp[[tx]][, -1])
  cat(sprintf(
    "%-15s spp %5d | range %-12s | NA %6d | fill %.3f\n",
    tx, ncol(m),
    paste(round(range(m, na.rm = TRUE), 2), collapse = " - "),
    sum(is.na(m)), mean(m > 0, na.rm = TRUE)
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

prevalence("vascular_plant")
prevalence("mammal")

# Species with no detections anywhere - the first thing to check
# before modelling, since they carry no signal.
for (tx in taxa) {
  m <- as.matrix(sp[[tx]][, -1])
  cat(sprintf(
    "%-15s %4d of %5d species never detected\n",
    tx, sum(colSums(m > 0, na.rm = TRUE) == 0), ncol(m)
  ))
}

### Richness per survey unit ----
for (tx in taxa) {
  r <- rowSums(as.matrix(sp[[tx]][, -1]) > 0, na.rm = TRUE)
  cat(sprintf(
    "%-15s richness  min %3.0f  median %6.1f  max %4.0f\n",
    tx, min(r), median(r), max(r)
  ))
}

### Mammal specifics ----
mam <- sp$mammal
region <- sites[
  match(mam$survey_unit_id, sites$survey_unit_id), region
]

table(region)

# Every species should appear as a Summer and a Winter column,
# so this table should read "2" for every base name.
mam_base <- sub("_(Summer|Winter)$", "", names(mam)[-1])
table(table(mam_base))

# Raccoon is the one South-only species, and the one name absent
# from the WildTrax lookup: NA across every North row.
cat(
  "Raccoon_Summer all NA in north:",
  all(is.na(mam$Raccoon_Summer[region == "north"])), "\n"
)
cat(
  "Raccoon_Summer observed in south:",
  sum(!is.na(mam$Raccoon_Summer[region == "south"])), "rows\n"
)

### Peek at a corner of each table ----
for (tx in taxa) {
  cat("\n---", tx, "---\n")
  print(sp[[tx]][1:3, 1:6])
}

### Example join ----
# What the two-file layout is for: response from a taxon CSV,
# context from sites.csv, joined on survey_unit_id.
moose <- merge(
  mam[, .(survey_unit_id, Moose_Summer)],
  sites[, .(survey_unit_id, region, nr, lat, long, summer_days)],
  by = "survey_unit_id"
)

head(moose)

moose[, .(
  mean_moose = round(mean(Moose_Summer, na.rm = TRUE), 3),
  units = .N
), by = nr][order(-mean_moose)]

# End of script ----
