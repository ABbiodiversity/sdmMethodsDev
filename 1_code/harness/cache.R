# ---
# title: Session Cache for Dataset Reads
# author: Brendan Casey
# created: 2026-10-03
# inputs: none
# outputs: none; holds read results in memory
# notes:
#   - Keeps one copy per file per session of lookups that were
#     re-read many times per run. Keyed on path, mtime, size and a
#     read tag, so an edited file is re-read, not served stale.
#   - Only file reads are cached, never fits or results, so the
#     cache cannot change what a run computes.
# ---

# 1. Setup ----

## 1.1 Load packages ----
# Base R only.

## 1.2 The cache ----
if (!exists(".sdm_cache", inherits = FALSE)) {
  .sdm_cache <- new.env(parent = emptyenv())
}

# 2. cached_read() ----

#' Read a File Once per Session
#'
#' @param path Character. The file to read.
#' @param reader A function of the path returning its contents.
#' @param tag Character. Distinguishes two different reads of the
#'   same file, such as one column subset and another.
#' @return Whatever `reader` returns.
#'
#' @example # Example usage of the function
#' # map <- cached_read(path, function(p) as.data.frame(fread(p)))
cached_read <- function(path, reader, tag = "") {
  info <- file.info(path)

  if (is.na(info$size)) {
    return(reader(path))
  }

  key <- paste(
    normalizePath(path, winslash = "/", mustWork = FALSE),
    format(info$mtime, "%Y%m%d%H%M%OS3"), info$size, tag,
    sep = "|"
  )

  if (!exists(key, envir = .sdm_cache, inherits = FALSE)) {
    assign(key, reader(path), envir = .sdm_cache)
  }

  get(key, envir = .sdm_cache, inherits = FALSE)
}

# 3. clear_cache() ----

#' Empty the Session Cache
#'
#' @return The number of entries removed, invisibly.
#'
#' @example # Example usage of the function
#' # clear_cache()
clear_cache <- function() {
  keys <- ls(.sdm_cache, all.names = TRUE)
  rm(list = keys, envir = .sdm_cache)

  invisible(length(keys))
}

# End of script ----
