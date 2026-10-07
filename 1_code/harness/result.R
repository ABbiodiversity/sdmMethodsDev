# ---
# title: The Standard Result Object
# author: Brendan Casey
# created: 2026-09-09
# inputs: none; writes to the store directory it is given
# outputs:
#   in the store directory:
#     - grid_predictions.csv
#     - unit_predictions.csv
#     - coefficients.csv
#     - metrics.csv
#     - meta.json
# notes:
#   - Every engine writes the same files, so comparison code reads
#     only this contract. grid_predictions.csv compares any
#     engines; coefficients.csv is written only when the engine
#     has coefficients (v2 parity is checked there).
#   - Rows are appended per draw, so a failure late in a long run
#     loses little. Parallel species write headerless shards;
#     merge_result_shards() appends them in queue order, matching
#     a serial run byte for byte.
#   - unit_predictions.csv is opt-in: it can reach gigabytes
#     (birds) and nothing downstream reads it.
# ---

# 1. Setup ----

## 1.1 Load packages ----
library(data.table) # fast appending writes (version: 1.16.4)

# 2. result_store() ----

## 2.1 result_columns() ----

#' The Columns of Each Result File
#'
#' @return A named list of character vectors.
#'
#' @example # Example usage of the function
#' # result_columns()$metrics
result_columns <- function() {
  list(
    grid_predictions = c(
      "species", "region", "boot", "grid_unit", "prediction"
    ),
    unit_predictions = c(
      "species", "region", "boot", "survey_unit_id", "prediction",
      "observed"
    ),
    coefficients = c(
      "species", "region", "stage", "boot", "term", "estimate", "se"
    ),
    metrics = c("species", "region", "boot", "metric", "value")
  )
}

## 2.2 result_store() ----

#' Open a Result Store
#'
#' @param dir Character. Directory to write into.
#' @param overwrite Logical. Remove existing result files first.
#'   FALSE continues a run that stopped part way.
#' @param header Logical. Write a header line when a file is
#'   started. FALSE for a shard, which is merged under one header.
#' @param unit_predictions Character. "none" writes no unit
#'   predictions, "oob" only the units a draw left out, "all"
#'   every unit.
#' @return A store object.
#'
#' @example # Example usage of the function
#' # store <- result_store("2_pipeline/exp_001/bryophyte")
result_store <- function(
  dir,
  overwrite = TRUE,
  header = TRUE,
  unit_predictions = c("none", "oob", "all")
) {
  unit_predictions <- match.arg(unit_predictions)
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)

  files <- paste0(names(result_columns()), ".csv")

  if (overwrite) {
    existing <- file.path(dir, c(files, "meta.json"))
    file.remove(existing[file.exists(existing)])
  }

  structure(
    list(
      dir = dir, files = files, header = header,
      unit_predictions = unit_predictions
    ),
    class = "result_store"
  )
}

## 2.3 merge_result_shards() ----

#' Combine Shard Stores into One Store
#'
#' @param store A result_store() to write into, with a header.
#' @param shard_dirs Character vector of shard directories, in the
#'   order their rows should appear.
#' @return NULL, invisibly.
#'
#' @example # Example usage of the function
#' # merge_result_shards(store, file.path(shards, species))
merge_result_shards <- function(store, shard_dirs) {
  columns <- result_columns()

  for (what in names(columns)) {
    target <- file.path(store$dir, paste0(what, ".csv"))
    parts <- file.path(shard_dirs, paste0(what, ".csv"))
    parts <- parts[file.exists(parts)]

    if (length(parts) == 0) {
      next
    }

    # The header is written by fwrite itself, from an empty table,
    # so its line ending matches the rows appended under it
    if (!file.exists(target)) {
      empty <- stats::setNames(
        as.data.frame(
          rep(list(character(0)), length(columns[[what]]))
        ),
        columns[[what]]
      )
      fwrite(empty, target)
    }

    for (part in parts) {
      file.append(target, part)
    }
  }

  invisible(NULL)
}

# 3. result_append() ----

#' Append Rows to One Result File
#'
#' @param store A result_store().
#' @param what Character. One of the store's file names, without
#'   the extension.
#' @param rows A data frame. Nothing is written when it is NULL
#'   or empty.
#' @return NULL, invisibly.
#'
#' @example # Example usage of the function
#' # result_append(store, "metrics", metric_rows)
result_append <- function(store, what, rows) {
  if (is.null(rows) || nrow(rows) == 0) {
    return(invisible(NULL))
  }

  path <- file.path(store$dir, paste0(what, ".csv"))
  started <- file.exists(path)

  # Header on first write only; shards have none
  fwrite(
    rows, path, append = started,
    col.names = store$header && !started, na = ""
  )

  invisible(NULL)
}

# 4. Writers ----

## 4.1 write_grid_predictions() ----

#' Record Predictions onto the Prediction Grid
#'
#' @param store A result_store().
#' @param species,region Character. What was fitted.
#' @param boot Integer. Resampling iteration.
#' @param grid_unit Character vector of prediction grid row names
#'   (habitat types).
#' @param prediction Numeric vector, on the response scale.
#' @return NULL, invisibly.
#'
#' @example # Example usage of the function
#' # write_grid_predictions(store, "ALFL", "north", 1,
#' #                        rownames(pm), preds)
write_grid_predictions <- function(
  store, species, region, boot, grid_unit, prediction
) {
  result_append(store, "grid_predictions", data.frame(
    species = species,
    region = region,
    boot = as.integer(boot),
    grid_unit = as.character(grid_unit),
    prediction = as.numeric(prediction),
    stringsAsFactors = FALSE
  ))
}

## 4.2 write_unit_predictions() ----

#' Record Predictions at Survey Units
#'
#' @param store A result_store().
#' @param species,region Character.
#' @param boot Integer.
#' @param survey_unit_id Character vector.
#' @param prediction,observed Numeric vectors.
#' @param in_bag Logical vector, TRUE where the unit was in the
#'   draw. Used when the store keeps out-of-bag units only.
#' @return NULL, invisibly. Nothing is written when the store's
#'   `unit_predictions` is "none".
#'
#' @example # Example usage of the function
#' # write_unit_predictions(store, "ALFL", "north", 1, ids,
#' #                        preds, obs)
write_unit_predictions <- function(
  store, species, region, boot, survey_unit_id, prediction,
  observed, in_bag = NULL
) {
  if (store$unit_predictions == "none") {
    return(invisible(NULL))
  }

  # Only the held-out units, where the run asks for those alone
  if (store$unit_predictions == "oob" && !is.null(in_bag)) {
    keep <- !in_bag
    survey_unit_id <- survey_unit_id[keep]
    prediction <- prediction[keep]
    observed <- observed[keep]
  }

  result_append(store, "unit_predictions", data.frame(
    species = species,
    region = region,
    boot = as.integer(boot),
    survey_unit_id = as.character(survey_unit_id),
    prediction = as.numeric(prediction),
    observed = as.numeric(observed),
    stringsAsFactors = FALSE
  ))
}

## 4.3 write_coefficients() ----

#' Record Coefficients, Where the Engine Has Them
#'
#' @param store A result_store().
#' @param species,region Character.
#' @param boot Integer.
#' @param coefficients A data frame of term, estimate and se, or
#'   NULL for an engine that has none.
#' @param stage Character. The stage the coefficients came from;
#'   every stage is recorded, not only the last.
#' @return NULL, invisibly.
#'
#' @example # Example usage of the function
#' # write_coefficients(store, "ALFL", "north", 1, coefs,
#' #                    stage = "climate")
write_coefficients <- function(
  store, species, region, boot, coefficients, stage = NA_character_
) {
  if (is.null(coefficients) || nrow(coefficients) == 0) {
    return(invisible(NULL))
  }

  result_append(store, "coefficients", data.frame(
    species = species,
    region = region,
    stage = as.character(stage),
    boot = as.integer(boot),
    term = as.character(coefficients$term),
    estimate = as.numeric(coefficients$estimate),
    se = as.numeric(coefficients$se),
    stringsAsFactors = FALSE
  ))
}

## 4.4 write_metrics() ----

#' Record Scores
#'
#' @param store A result_store().
#' @param species,region Character.
#' @param boot Integer.
#' @param metrics A data frame of metric and value, from
#'   compute_metrics().
#' @return NULL, invisibly.
#'
#' @example # Example usage of the function
#' # write_metrics(store, "ALFL", "north", 1, scores)
write_metrics <- function(store, species, region, boot, metrics) {
  if (is.null(metrics) || nrow(metrics) == 0) {
    return(invisible(NULL))
  }

  result_append(store, "metrics", data.frame(
    species = species,
    region = region,
    boot = as.integer(boot),
    metric = as.character(metrics$metric),
    value = as.numeric(metrics$value),
    stringsAsFactors = FALSE
  ))
}

## 4.5 write_meta() ----

#' Record What a Run Was
#'
#' Hand-written JSON, not jsonlite, to keep the harness to base R
#' plus data.table.
#'
#' @param store A result_store().
#' @param meta A named list of scalars and character vectors.
#' @return NULL, invisibly.
#'
#' @example # Example usage of the function
#' # write_meta(store, list(engine = "glm", boot_n = 100))
write_meta <- function(store, meta) {
  escape <- function(x) {
    x <- gsub("\\\\", "\\\\\\\\", as.character(x))
    x <- gsub('"', '\\\\"', x)
    gsub("[\r\n]+", " ", x)
  }

  render <- function(value) {
    if (is.null(value) || length(value) == 0) {
      return("null")
    }

    if (is.numeric(value) && length(value) == 1 &&
          is.finite(value)) {
      return(format(value, scientific = FALSE))
    }

    if (is.logical(value) && length(value) == 1 && !is.na(value)) {
      return(if (value) "true" else "false")
    }

    if (length(value) > 1) {
      return(paste0(
        "[", paste0('"', escape(value), '"', collapse = ", "), "]"
      ))
    }

    paste0('"', escape(value), '"')
  }

  lines <- vapply(
    names(meta),
    function(name) {
      paste0('  "', escape(name), '": ', render(meta[[name]]))
    },
    character(1)
  )

  writeLines(
    c("{", paste(lines, collapse = ",\n"), "}"),
    file.path(store$dir, "meta.json")
  )

  invisible(NULL)
}

# 5. read_results() ----

#' Read a Result Store Back
#'
#' A missing file returns NULL: an engine without coefficients
#' writes none.
#'
#' @param dir Character. A store directory.
#' @param what Character. Which file, without the extension.
#' @return A data frame, or NULL when the file is absent.
#'
#' @example # Example usage of the function
#' # read_results("2_pipeline/exp_001/bryophyte", "metrics")
read_results <- function(dir, what) {
  path <- file.path(dir, paste0(what, ".csv"))

  if (!file.exists(path)) {
    return(NULL)
  }

  as.data.frame(fread(path))
}

# End of script ----
