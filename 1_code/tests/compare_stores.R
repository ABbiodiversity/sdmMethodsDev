# ---
# title: Compare Two Sets of Result Stores
# author: Brendan Casey
# created: 2026-10-03
# inputs:
#   two directories laid out as <run>/<region>/ result stores, as
#   run_spec() writes them
# outputs: none; returns a data frame and prints a summary
# notes:
#   - The regression check for any change to the harness, methods
#     or modules: a refactor that is meant to leave results alone
#     should leave every stored coefficient within `tolerance`.
#   - Rows are matched on their keys, not their position, so a
#     change in write order is not mistaken for a change in value.
#   - `max_boot` restricts both sides to the first draws. Draws
#     are seeded per species and drawn in order, so draws 1-5 of a
#     5-draw run are the same rows as draws 1-5 of a 100-draw run.
# ---

# 1. Setup ----

## 1.1 Load packages ----
library(data.table) # keyed joins on large tables (version: 1.16.4)

# 2. compare_stores() ----

#' Compare the Values Two Sets of Stores Hold
#'
#' @param old_dir,new_dir Character. Directories holding
#'   `<run>/<region>/` stores.
#' @param files Character vector of store files to compare,
#'   without the extension.
#' @param tolerance Numeric. Largest absolute difference that
#'   still counts as a match.
#' @param max_boot Integer or NULL. Compare draws up to this one.
#' @param runs Character vector of run folders, or NULL for every
#'   run present in both.
#' @return A data frame, one row per run, region and file, with
#'   row counts on each side, rows only on one side, the largest
#'   absolute difference and whether it matches.
#'
#' @example # Example usage of the function
#' # compare_stores("2_pipeline/_baseline/stores",
#' #                "2_pipeline/exp_000_parity_v2", max_boot = 5)
compare_stores <- function(
  old_dir,
  new_dir,
  files = c("coefficients", "metrics", "grid_predictions"),
  tolerance = 1e-10,
  max_boot = NULL,
  runs = NULL
) {
  store_dirs <- function(root) {
    found <- list.files(
      root, pattern = "^meta\\.json$", recursive = TRUE
    )
    dirname(found)
  }

  shared <- intersect(store_dirs(old_dir), store_dirs(new_dir))

  if (!is.null(runs)) {
    shared <- shared[dirname(shared) %in% runs]
  }

  if (length(shared) == 0) {
    stop("No store is present in both directories.", call. = FALSE)
  }

  # Value columns per file; everything else is a key
  value_columns <- list(
    coefficients = c("estimate", "se"),
    metrics = "value",
    grid_predictions = "prediction",
    unit_predictions = c("prediction", "observed")
  )

  read_one <- function(root, store, what) {
    path <- file.path(root, store, paste0(what, ".csv"))

    if (!file.exists(path)) {
      return(NULL)
    }

    rows <- fread(path)

    if (!is.null(max_boot) && "boot" %in% names(rows)) {
      rows <- rows[boot <= max_boot]
    }

    rows
  }

  out <- list()

  for (store in shared) {
    for (what in files) {
      old <- read_one(old_dir, store, what)
      new <- read_one(new_dir, store, what)

      if (is.null(old) && is.null(new)) {
        next
      }

      values <- value_columns[[what]]
      keys <- setdiff(
        intersect(names(old) %||% names(new), names(new) %||%
                    names(old)),
        values
      )

      row <- data.frame(
        store = store, file = what,
        old_rows = if (is.null(old)) 0L else nrow(old),
        new_rows = if (is.null(new)) 0L else nrow(new),
        only_old = NA_integer_, only_new = NA_integer_,
        max_abs_difference = NA_real_,
        stringsAsFactors = FALSE
      )

      if (!is.null(old) && !is.null(new)) {
        # A key can repeat within a draw (a term written twice is a
        # bug the comparison should surface), so rows are numbered
        # within their key before joining.
        old[, .dup := seq_len(.N), by = keys]
        new[, .dup := seq_len(.N), by = keys]
        joined <- merge(
          old, new, by = c(keys, ".dup"), all = TRUE,
          suffixes = c(".old", ".new")
        )

        first <- paste0(values[1], c(".old", ".new"))
        row$only_old <- sum(is.na(joined[[first[2]]]) &
                              !is.na(joined[[first[1]]]))
        row$only_new <- sum(is.na(joined[[first[1]]]) &
                              !is.na(joined[[first[2]]]))

        differences <- unlist(lapply(values, function(v) {
          a <- joined[[paste0(v, ".old")]]
          b <- joined[[paste0(v, ".new")]]
          both <- !is.na(a) & !is.na(b)
          # NA on one side only is a mismatch, NA on both is not
          c(abs(a[both] - b[both]),
            if (any(xor(is.na(a), is.na(b)))) Inf)
        }))

        row$max_abs_difference <- if (length(differences) == 0) {
          0
        } else {
          max(differences)
        }
      }

      out[[length(out) + 1]] <- row
    }
  }

  result <- do.call(rbind, out)
  result$match <- result$old_rows == result$new_rows &
    result$only_old %in% 0L & result$only_new %in% 0L &
    result$max_abs_difference <= tolerance

  result
}

`%||%` <- function(a, b) if (is.null(a)) b else a

# 3. Command line ----
# Rscript 1_code/tests/compare_stores.R <old_dir> <new_dir>
#   [max_boot] [files]
if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)

  if (length(args) < 2) {
    stop(
      "Usage: Rscript compare_stores.R <old_dir> <new_dir> ",
      "[max_boot] [file,file]",
      call. = FALSE
    )
  }

  result <- compare_stores(
    args[1], args[2],
    max_boot = if (length(args) >= 3 && args[3] != "all") {
      as.integer(args[3])
    } else {
      NULL
    },
    files = if (length(args) >= 4) {
      strsplit(args[4], ",")[[1]]
    } else {
      c("coefficients", "metrics", "grid_predictions")
    }
  )

  print(result, row.names = FALSE)
  cat(
    "\n", sum(result$match), " of ", nrow(result),
    " store files match.\n", sep = ""
  )
}

# End of script ----
