# ---
# title: Publish the Test Dataset and v2 Results to ABMI-DATA2
# author: Brendan Casey
# created: 2026-10-05
# inputs:
#   - 0_data/test_dataset/, from _setup/01-09, checked by 02
#   - 0_data/v2_results/, from _setup/05 (top level, the "drives"
#     reference) and 08 (abmiexplorer/)
# outputs:
#   in //ABMI-DATA2/science/sdmMethodsDev/0_data/ (SDM_SHARE_ROOT
#   overrides it), for each dataset:
#     - <name>/<version>/, a copy of the local folder
#     - <name>/<version>/checksums.csv: path, bytes, md5
#     - <name>/<version>/publish_record.md: when, by whom, from
#       which commit
# notes:
#   - Experiments, tests and downstream scripts read these
#     published copies (1_code/harness/data_source.R), so only
#     whoever rebuilds the data runs _setup/.
#   - A published version is never overwritten. The script stops
#     if <version>/ exists; a rebuilt dataset is published as a
#     new version and data_source.R's pin is moved to it.
#   - Files go to <version>.partial/ first, are re-hashed there
#     against the local md5s, and only then is the folder renamed
#     to <version>/, so a reader never sees a half copy.
#   - SDM_DATASET_VERSION sets the version (default: today's
#     date, YYYY-MM-DD). SDM_PUBLISH picks the datasets,
#     comma-separated (default: test_dataset,v2_results).
#   - Run 02_validate_test_dataset.R first. It is not run from
#     here because it re-reads every source.
#   - Run from the repository root.
# ---

# 1. Setup ----

## 1.1 Load packages ----
library(data.table) # checksums writing (version: 1.16.4)

## 1.2 Resolve paths and settings ----
project_root <- normalizePath(getwd(), winslash = "/")
resolver <- file.path(project_root, "1_code/harness/data_source.R")

if (!file.exists(resolver)) {
  stop("Run this from the repository root.", call. = FALSE)
}

# For the share root and each dataset's marker file
source(resolver)

share_root <- Sys.getenv(
  "SDM_SHARE_ROOT",
  unset = sdm_published$root
)

version <- Sys.getenv(
  "SDM_DATASET_VERSION",
  unset = format(Sys.Date())
)

datasets <- trimws(strsplit(
  Sys.getenv("SDM_PUBLISH", unset = "test_dataset,v2_results"),
  ","
)[[1]])

if (!grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", version)) {
  stop(
    "SDM_DATASET_VERSION must be a date, YYYY-MM-DD.",
    call. = FALSE
  )
}

unknown <- setdiff(datasets, names(sdm_published$versions))

if (length(unknown) > 0) {
  stop("Unknown dataset(s): ", paste(unknown, collapse = ", "),
       call. = FALSE)
}

## 1.3 The commit the data was built with ----
git_commit <- tryCatch(
  system2("git", c("rev-parse", "HEAD"), stdout = TRUE),
  error = function(e) "unknown"
)

git_dirty <- tryCatch(
  length(system2("git", c("status", "--porcelain"),
                 stdout = TRUE)) > 0,
  error = function(e) NA
)

# 2. publish_dataset() ----

#' Copy One Local Dataset to the Share as a New Version
#'
#' @param name Character. A dataset under 0_data/, such as
#'   "test_dataset".
#' @param version Character. The version folder to create.
#' @return Character. The published folder, invisibly.
#'
#' @example # Example usage of the function
#' # publish_dataset("v2_results", "2026-10-05")
publish_dataset <- function(name, version) {
  # Step 1: The local copy, complete enough to be the dataset
  local_dir <- file.path(project_root, "0_data", name)
  marker <- sdm_published$marker[[name]]

  if (!file.exists(file.path(local_dir, marker))) {
    stop("No ", marker, " in ", local_dir, call. = FALSE)
  }

  # Step 2: A new version, never an existing or half-made one
  target <- file.path(share_root, name, version)
  partial <- paste0(target, ".partial")

  if (dir.exists(target)) {
    stop(
      "Already published, and never overwritten:\n  ", target,
      "\nSet SDM_DATASET_VERSION to publish a new version.",
      call. = FALSE
    )
  }

  if (dir.exists(partial)) {
    stop(
      "A previous publish did not finish:\n  ", partial,
      "\nDelete it, then run this again.",
      call. = FALSE
    )
  }

  # Step 3: The files and their md5s
  rel <- list.files(local_dir, recursive = TRUE, all.files = TRUE)
  rel <- rel[basename(rel) != ".gitkeep"]
  sums <- data.table(
    path = rel,
    bytes = file.size(file.path(local_dir, rel)),
    md5 = unname(tools::md5sum(file.path(local_dir, rel)))
  )

  cat(
    name, ": ", nrow(sums), " files, ",
    round(sum(sums$bytes) / 1e9, 2), " GB -> ", target, "\n",
    sep = ""
  )

  # Step 4: Copy into the partial folder
  for (i in seq_len(nrow(sums))) {
    to <- file.path(partial, sums$path[i])
    dir.create(dirname(to), recursive = TRUE, showWarnings = FALSE)

    if (!file.copy(file.path(local_dir, sums$path[i]), to,
                   copy.date = TRUE)) {
      stop("Copy failed: ", sums$path[i], call. = FALSE)
    }

    cat(sprintf("  [%d/%d] %s\n", i, nrow(sums), sums$path[i]))
  }

  # Step 5: Re-hash the share copy before it is made visible
  copied <- unname(tools::md5sum(file.path(partial, sums$path)))
  bad <- is.na(copied) | copied != sums$md5

  if (any(bad)) {
    stop(
      "md5 mismatch on the share; ", partial, " left for ",
      "inspection:\n  ", paste(sums$path[bad], collapse = "\n  "),
      call. = FALSE
    )
  }

  # Step 6: Checksums and the record, then make it visible
  fwrite(sums, file.path(partial, "checksums.csv"))

  writeLines(c(
    paste0("# ", name, " ", version),
    "",
    paste0("- Published: ", format(Sys.time(), "%Y-%m-%d %H:%M")),
    paste0("- By: ", Sys.info()[["user"]]),
    paste0("- From: ", local_dir),
    paste0(
      "- Commit: ", git_commit,
      if (isTRUE(git_dirty)) " (with uncommitted changes)" else ""
    ),
    paste0("- Files: ", nrow(sums), ", ",
           round(sum(sums$bytes) / 1e6, 1), " MB"),
    paste0("- R: ", R.version.string),
    "",
    "Built by 1_code/_setup/ in the sdmMethodsDev repository and",
    "published by 1_code/_setup/10_publish_datasets.R. Never",
    "edited after publishing; checksums.csv lists every file."
  ), file.path(partial, "publish_record.md"))

  if (!file.rename(partial, target)) {
    stop("Could not rename ", partial, " to ", target, call. = FALSE)
  }

  invisible(target)
}

# 3. Publish ----
published <- vapply(
  datasets, publish_dataset, character(1), version = version
)

cat(
  "\nPublished:\n  ", paste(published, collapse = "\n  "),
  "\n\nTo use them, set sdm_published$versions in ",
  "1_code/harness/data_source.R to \"", version, "\".\n",
  sep = ""
)

# End of script ----
