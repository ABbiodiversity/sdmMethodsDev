# ---
# title: Publish the Prediction Grid to ABMI-DATA2
# author: Brendan Casey
# created: 2026-10-27
# inputs:
#   - 2_pipeline/shared/prediction_grid/<version>/, from 01,
#     checked by 02 (qa_summary.csv with no "fail")
#   - 2_pipeline/shared/prediction_grid/manifest.md
# outputs:
#   in //ABMI-DATA2/science/sdmMethodsDev/0_data/prediction_grid/
#   (SDM_SHARE_ROOT overrides the 0_data root):
#     - <version>/, a copy of the local version folder
#     - <version>/checksums.csv: path, bytes, md5
#     - <version>/publish_record.md: when, by whom, from which
#       commit
#     - manifest.md, replaced by the local manifest
# notes:
#   - Runs read this copy through
#     harness/data_source.R (prediction_grid_dir()). A published
#     version is never overwritten: build a new version and move
#     the pin.
#   - Files are copied to <version>.partial/, re-hashed, then
#     renamed, so readers never see a half copy (the pattern of
#     _setup/08_publish_datasets.R).
#   - manifest.md is an index of versions, not a version, so it
#     is the one file replaced on each publish.
#   - Run from the repository root, only with approval.
# ---

# 1. Setup ----

## 1.1 Load packages ----
library(data.table) # checksums writing (version: 1.18.0)

## 1.2 Settings ----
if (!file.exists("1_code/_prediction_grid/utils/grid_settings.R")) {
  stop("Run this from the repository root.", call. = FALSE)
}

source("1_code/_prediction_grid/utils/grid_settings.R")
source("1_code/harness/data_source.R")

version <- prediction_grid_settings$version
local_dir <- grid_build_dir(version)
share_root <- file.path(
  Sys.getenv("SDM_SHARE_ROOT", unset = sdm_published$root),
  "prediction_grid"
)
target <- file.path(share_root, version)
partial <- paste0(target, ".partial")

## 1.3 Only a checked build ----
qa_path <- file.path(local_dir, "qa_summary.csv")

if (!file.exists(qa_path)) {
  stop("No qa_summary.csv in ", local_dir,
       ". Run 02_qa_prediction_grid.R first.", call. = FALSE)
}

qa <- fread(qa_path)

if (any(qa$status == "fail")) {
  stop("QA has failures; not publishing:\n  ",
       paste(qa[status == "fail", check], collapse = "\n  "),
       call. = FALSE)
}

if (dir.exists(target)) {
  stop("Already published, and never overwritten:\n  ", target,
       call. = FALSE)
}

if (dir.exists(partial)) {
  stop("A previous publish did not finish:\n  ", partial,
       "\nDelete it, then run this again.", call. = FALSE)
}

## 1.4 The commit the grid was built with ----
git_commit <- tryCatch(
  system2("git", c("rev-parse", "HEAD"), stdout = TRUE),
  error = function(e) "unknown"
)
git_dirty <- tryCatch(
  length(system2("git", c("status", "--porcelain"),
                 stdout = TRUE)) > 0,
  error = function(e) NA
)

# 2. Copy ----

## 2.1 The files and their md5s ----
rel <- list.files(local_dir, recursive = TRUE, all.files = TRUE)
sums <- data.table(
  path = rel,
  bytes = file.size(file.path(local_dir, rel)),
  md5 = unname(tools::md5sum(file.path(local_dir, rel)))
)

cat(version, ": ", nrow(sums), " files, ",
    round(sum(sums$bytes) / 1e6, 1), " MB -> ", target, "\n",
    sep = "")

## 2.2 Into the partial folder ----
for (i in seq_len(nrow(sums))) {
  to <- file.path(partial, sums$path[i])
  dir.create(dirname(to), recursive = TRUE, showWarnings = FALSE)

  if (!file.copy(file.path(local_dir, sums$path[i]), to,
                 copy.date = TRUE)) {
    stop("Copy failed: ", sums$path[i], call. = FALSE)
  }

  cat(sprintf("  [%d/%d] %s\n", i, nrow(sums), sums$path[i]))
}

## 2.3 Re-hash the share copy before it is made visible ----
copied <- unname(tools::md5sum(file.path(partial, sums$path)))
bad <- is.na(copied) | copied != sums$md5

if (any(bad)) {
  stop("md5 mismatch on the share; ", partial, " left for ",
       "inspection:\n  ", paste(sums$path[bad], collapse = "\n  "),
       call. = FALSE)
}

# 3. Record and make visible ----
fwrite(sums, file.path(partial, "checksums.csv"))

writeLines(c(
  paste0("# prediction_grid ", version),
  "",
  paste0("- Published: ", format(Sys.time(), "%Y-%m-%d %H:%M")),
  paste0("- By: ", Sys.info()[["user"]]),
  paste0("- From: ", normalizePath(local_dir, winslash = "/")),
  paste0(
    "- Commit: ", git_commit,
    if (isTRUE(git_dirty)) " (with uncommitted changes)" else ""
  ),
  paste0("- Files: ", nrow(sums), ", ",
         round(sum(sums$bytes) / 1e6, 1), " MB"),
  paste0("- QA: ", sum(qa$status == "pass"), " pass, ",
         sum(qa$status == "note"), " note, 0 fail (",
         qa$checked[1], ")"),
  paste0("- R: ", R.version.string),
  "",
  "Built by 1_code/_prediction_grid/ in the sdmMethodsDev",
  "repository. Never edited after publishing; checksums.csv",
  "lists every file. See README.md and manifest.md."
), file.path(partial, "publish_record.md"))

if (!file.rename(partial, target)) {
  stop("Could not rename ", partial, " to ", target, call. = FALSE)
}

# The index of versions, replaced on each publish
invisible(file.copy(
  file.path(prediction_grid_settings$build_root, "manifest.md"),
  file.path(share_root, "manifest.md"),
  overwrite = TRUE
))

cat("\nPublished ", target, "\nTo use it, set ",
    "sdm_published$versions[\"prediction_grid\"] in ",
    "1_code/harness/data_source.R to \"", version, "\".\n",
    sep = "")

# End of script ----
