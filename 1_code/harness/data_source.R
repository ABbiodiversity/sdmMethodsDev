# ---
# title: Locate the Published Datasets
# author: Brendan Casey
# created: 2026-10-05
# inputs:
#   - the published datasets on ABMI-DATA2, each a versioned
#     folder with its checksums.csv:
#     //ABMI-DATA2/science/sdmMethodsDev/0_data/
#       test_dataset/<version>/  the frozen test dataset
#       v2_results/<version>/    the v2 parity references
#   - SDM_TEST_DATASET and SDM_V2_RESULTS, optional, folders to
#     read instead
# outputs: none; returns the folder to read
# notes:
#   - Runs read the copies published by
#     _setup/10_publish_datasets.R, so only maintainers run
#     _setup/. sdm_published$versions pins the version read;
#     published versions are never overwritten.
#   - The environment variables redirect to a local copy or to
#     fresh _setup/ output in 0_data/.
#   - Each call checks presence and size against checksums.csv
#     (fast); verify_published() does the full md5 check.
# ---

# 1. Setup ----

## 1.1 Load packages ----
library(data.table) # reads checksums.csv (version: 1.16.4)

## 1.2 The pinned versions ----
# `marker` is a file every copy holds, published or local, so a
# local folder without checksums.csv can still be recognized.
sdm_published <- list(
  root = "//ABMI-DATA2/science/sdmMethodsDev/0_data",
  versions = c(
    test_dataset = "2026-10-05",
    v2_results = "2026-10-05"
  ),
  env = c(
    test_dataset = "SDM_TEST_DATASET",
    v2_results = "SDM_V2_RESULTS"
  ),
  marker = c(
    test_dataset = "lookup/dataset_manifest.csv",
    v2_results = "abmiexplorer/v2_results.csv"
  )
)

# 2. published_dir() ----

#' Resolve a Published Dataset Folder
#'
#' Precedence: `dir`, then the dataset's environment variable,
#' then the pinned published version.
#'
#' @param name Character. "test_dataset" or "v2_results".
#' @param dir Character or NULL. A folder to use as is.
#' @param check Logical. Check the folder before returning it.
#' @return Character. The folder, with forward slashes.
#'
#' @example # Example usage of the function
#' # published_dir("v2_results")
published_dir <- function(name, dir = NULL, check = TRUE) {
  # Step 1: A dataset this file knows
  if (!name %in% names(sdm_published$versions)) {
    stop(
      "Unknown dataset: ", name, ". Known: ",
      paste(names(sdm_published$versions), collapse = ", "),
      call. = FALSE
    )
  }

  # Step 2: The first of argument, environment, pinned version
  from_env <- Sys.getenv(sdm_published$env[[name]], unset = "")

  dir <- dir %||%
    (if (nzchar(from_env)) from_env else NULL) %||%
    file.path(
      sdm_published$root, name, sdm_published$versions[[name]]
    )

  # normalizePath() keeps a share's leading backslashes; the run
  # record reads better with the forward-slash form
  dir <- normalizePath(dir, winslash = "/", mustWork = FALSE)
  dir <- sub("^[\\\\/]{2}", "//", dir)

  # Step 3: Fail now, not partway into a run
  if (isTRUE(check)) {
    check_published(dir, name)
  }

  dir
}

# 3. test_dataset_dir() and v2_results_dir() ----

#' Resolve the Test Dataset Folder
#'
#' @param data_dir Character or NULL. A folder to use as is.
#' @param check Logical. Check the folder before returning it.
#' @return Character. The folder.
#'
#' @example # Example usage of the function
#' # data_dir <- test_dataset_dir()
#' # Sys.setenv(SDM_TEST_DATASET = "0_data/test_dataset")
#' # test_dataset_dir()  # the local _setup/ output
test_dataset_dir <- function(data_dir = NULL, check = TRUE) {
  published_dir("test_dataset", data_dir, check)
}

#' Resolve the v2 Results Folder
#'
#' The parity reference, from _setup/08, is in abmiexplorer/.
#' Files at the top level of the 2026-10-05 version are the
#' retired network-drive build; nothing reads them.
#'
#' @param dir Character or NULL. A folder to use as is.
#' @param check Logical. Check the folder before returning it.
#' @return Character. The folder.
#'
#' @example # Example usage of the function
#' # file.path(v2_results_dir(), "abmiexplorer", "v2_results.csv")
v2_results_dir <- function(dir = NULL, check = TRUE) {
  published_dir("v2_results", dir, check)
}

# 4. check_published() ----

#' Check a Dataset Folder Is Complete
#'
#' Published copies are checked file by file against
#' checksums.csv (presence and size); a local copy without one is
#' only checked for the dataset's marker file.
#'
#' @param dir Character. The folder.
#' @param name Character. The dataset, for its marker file.
#' @return `dir`, invisibly; stops on a problem.
#'
#' @example # Example usage of the function
#' # check_published(test_dataset_dir(check = FALSE),
#' #                 "test_dataset")
check_published <- function(dir, name) {
  # Step 1: The folder
  if (!dir.exists(dir)) {
    stop(
      "Dataset ", name, " not found:\n  ", dir,
      "\nConnect to the ABMI network (or VPN), or set ",
      sdm_published$env[[name]], " to a local copy.",
      call. = FALSE
    )
  }

  # Step 2: A local copy has no checksums; the marker will do
  sums_path <- file.path(dir, "checksums.csv")

  if (!file.exists(sums_path)) {
    marker <- sdm_published$marker[[name]]

    if (!file.exists(file.path(dir, marker))) {
      stop(
        "Not a copy of ", name, " (no ", marker, "):\n  ", dir,
        call. = FALSE
      )
    }

    return(invisible(dir))
  }

  # Step 3: Every published file, at its published size
  sums <- fread(sums_path, colClasses = "character")
  sizes <- file.size(file.path(dir, sums$path))
  bad <- is.na(sizes) | sizes != as.numeric(sums$bytes)

  if (any(bad)) {
    stop(
      "Dataset ", name, " incomplete at ", dir,
      "; missing or wrong size:\n  ",
      paste(head(sums$path[bad], 10), collapse = "\n  "),
      call. = FALSE
    )
  }

  invisible(dir)
}

# 5. verify_published() ----

#' Verify Every File in a Published Dataset by md5
#'
#' Slow over the network (the test dataset is ~0.9 GB); use it
#' after publishing, or when a copy is in doubt.
#'
#' @param dir Character. A published folder.
#' @return Logical. TRUE when every md5 matches, invisibly;
#'   stops otherwise.
#'
#' @example # Example usage of the function
#' # verify_published(test_dataset_dir())
verify_published <- function(dir) {
  sums_path <- file.path(dir, "checksums.csv")

  if (!file.exists(sums_path)) {
    stop("No checksums.csv in ", dir, call. = FALSE)
  }

  sums <- fread(sums_path, colClasses = "character")
  found <- unname(tools::md5sum(file.path(dir, sums$path)))
  bad <- is.na(found) | found != sums$md5

  if (any(bad)) {
    stop(
      "md5 mismatch in ", dir, ":\n  ",
      paste(sums$path[bad], collapse = "\n  "),
      call. = FALSE
    )
  }

  invisible(TRUE)
}

# 6. published_label() ----

#' Name the Copy a Run Read, for the Run Record
#'
#' @param dir Character. The folder.
#' @return Character. "published <version> (<dir>)" for a
#'   published copy, "local (<dir>)" otherwise.
#'
#' @example # Example usage of the function
#' # published_label(test_dataset_dir())
published_label <- function(dir) {
  if (file.exists(file.path(dir, "checksums.csv"))) {
    paste0("published ", basename(dir), " (", dir, ")")
  } else {
    paste0("local (", dir, ")")
  }
}

# End of script ----
