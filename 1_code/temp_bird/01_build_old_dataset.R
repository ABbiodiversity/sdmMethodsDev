# ---
# title: Build the Old-Bird-Data Copy of the Test Dataset
# author: Brendan Casey
# created: 2026-10-15
# inputs:
#   - the pinned published test dataset on ABMI-DATA2
#     (test_dataset/2026-10-05), harmonized from v2's own
#     Stratified.Rdata (remote/birds_data_v2)
#   - 0_data/test_dataset_backup_2026-10-02_aug2026_birds/, the
#     test dataset as harmonized from the BirdModels drive's
#     Data/Archive/2025/Stratified.Rdata, rebuilt 2026-08-19
# outputs:
#   - 2_pipeline/temp_bird/test_dataset_old/, a full test dataset
#     identical to the published one except for the bird inputs
# notes:
#   - The "old" side of the old-vs-new bird comparison. Only the
#     bird inputs are swapped, so a difference between the two
#     fits is a difference in the Stratified.Rdata, nothing else.
#   - Swapped: bird.csv, bird_offsets.csv, the bird bootstrap ids
#     and modelled-species list, and the bird rows' columns of
#     covariates.csv that differ (on 2026-10-15, `use` only).
#   - checksums.csv is left out, so the harness reads the copy
#     as a local folder rather than checking it as published.
#   - About 860 MB; copied once, then reused unless deleted.
# ---

# 1. Setup ----

## 1.1 Load packages ----
library(data.table) # reading and patching covariates (v: 1.18.0)

## 1.2 Paths ----
published_dir <- paste0(
  "//ABMI-DATA2/science/sdmMethodsDev/0_data/test_dataset/",
  "2026-10-05"
)
backup_dir <- "0_data/test_dataset_backup_2026-10-02_aug2026_birds"
old_dir <- "2_pipeline/temp_bird/test_dataset_old"

for (one in c(published_dir, backup_dir)) {
  if (!dir.exists(one)) {
    stop("Not found: ", one, call. = FALSE)
  }
}

# 2. Copy the published dataset ----
# Everything but its publication files.
unlink(old_dir, recursive = TRUE)
dir.create(old_dir, recursive = TRUE)

files <- list.files(published_dir, recursive = TRUE)
files <- files[!files %in% c("checksums.csv", "publish_record.md")]

for (one in files) {
  dir.create(
    dirname(file.path(old_dir, one)),
    recursive = TRUE, showWarnings = FALSE
  )
  file.copy(file.path(published_dir, one), file.path(old_dir, one))
}

# 3. Swap in the old bird inputs ----

## 3.1 Whole files ----
bird_files <- c(
  "bird.csv",
  "bird_offsets.csv",
  "lookup/bird_bootstrap_ids.csv",
  "lookup/bird_modelled_species.csv"
)

for (one in bird_files) {
  file.copy(
    file.path(backup_dir, one), file.path(old_dir, one),
    overwrite = TRUE
  )
}

## 3.2 Bird rows of covariates.csv ----
# Only the columns that differ, so anything added to the dataset
# since the backup is kept.
covariates <- fread(file.path(published_dir, "covariates.csv"))
old_birds <- fread(
  file.path(backup_dir, "covariates.csv")
)[taxon == "bird"]

bird_rows <- which(covariates$taxon == "bird")
new_birds <- covariates[bird_rows]

if (nrow(new_birds) != nrow(old_birds)) {
  stop("The two datasets hold different bird surveys.",
       call. = FALSE)
}

old_birds <- old_birds[
  match(new_birds$survey_unit_id, old_birds$survey_unit_id)
]

shared <- setdiff(
  intersect(names(new_birds), names(old_birds)),
  c("survey_unit_id", "taxon")
)
differing <- shared[vapply(shared, function(column) {
  !isTRUE(all.equal(
    new_birds[[column]], old_birds[[column]],
    check.attributes = FALSE
  ))
}, logical(1))]

cat("Bird covariate columns swapped:",
    paste(differing, collapse = ", "), "\n")

for (column in differing) {
  set(covariates, i = bird_rows, j = column,
      value = old_birds[[column]])
}

fwrite(covariates, file.path(old_dir, "covariates.csv"))

# 4. Check ----
# The two Stratified.Rdata versions differ in draw size.
draw_size <- function(dir) {
  nrow(fread(
    file.path(dir, "lookup/bird_bootstrap_ids.csv"), select = 1
  ))
}

cat("Surveys per draw: old", draw_size(old_dir),
    "(expect 58035), new", draw_size(published_dir),
    "(expect 58210)\n")
cat("Wrote", old_dir, "\n")

# End of script ----
