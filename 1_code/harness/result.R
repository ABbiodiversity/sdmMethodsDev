# ---
# title: The Standard Result Object
# author: Brendan Casey
# created: 2026-09-09
# outputs:
#   in the store directory:
#     - grid_predictions.csv
#     - unit_predictions.csv
#     - coefficients.csv
#     - metrics.csv
#     - meta.json
# notes:
#   - Every run writes the same five files whatever the engine,
#     which is what makes a GLM run and a boosted-tree run
#     comparable. Comparison code reads this contract and nothing
#     else.
#   - grid_predictions.csv is the common currency. Coefficients
#     cannot compare a GLM to a tree - a tree has no Peatland
#     coefficient - but every engine can predict onto the rows of
#     a prediction matrix, which is also the quantity v2 reports.
#   - coefficients.csv is still written when the engine has
#     coefficients, because parity against v2 is checked there.
#     Its absence is recorded in meta.json rather than being
#     silently empty.
#   - Writing is append-per-species rather than one object at the
#     end. A bird run is 172 species by 100 bootstraps, and
#     holding all of it before the first write would risk losing
#     a long run to a failure in its last species.
#   - meta.json records the configuration a run cannot be
#     reproduced without: engine, selection rule, covariates,
#     seed, and the resampling scheme. The seed matters most - v2
#     set none, so a v2-configured run is not reproducible even
#     against itself.
# ---

# 1. Setup ----

## 1.1 Load packages ----
library(data.table) # fast appending writes (version: 1.16.4)

# 2. result_store() ----

#' Open a Result Store
#'
#' Creates the directory and records which files have been
#' started, so each is written with a header once and appended to
#' after that.
#'
#' @param dir Character. Directory to write into.
#' @param overwrite Logical. Remove existing result files first.
#'   FALSE lets a run add to a store, which is how a run that
#'   stopped part way is continued.
#' @return A store object.
#'
#' @example # Example usage of the function
#' # store <- result_store("2_pipeline/exp_001/bryophyte")
result_store <- function(dir, overwrite = TRUE) {
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)

  files <- c(
    "grid_predictions.csv", "unit_predictions.csv",
    "coefficients.csv", "metrics.csv"
  )

  if (overwrite) {
    existing <- file.path(dir, files)
    file.remove(existing[file.exists(existing)])
  }

  structure(
    list(dir = dir, files = files),
    class = "result_store"
  )
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

  # data.table writes the header only on the first call, so the
  # file stays a single valid CSV across appends
  fwrite(
    rows, path, append = file.exists(path),
    col.names = !file.exists(path), na = ""
  )

  invisible(NULL)
}

# 4. Writers ----
# One per file, each fixing the column set so that a downstream
# comparison can rely on it.

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
#' @return NULL, invisibly.
#'
#' @example # Example usage of the function
#' # write_unit_predictions(store, "ALFL", "north", 1, ids,
#' #                        preds, obs)
write_unit_predictions <- function(
  store, species, region, boot, survey_unit_id, prediction,
  observed
) {
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
#' @return NULL, invisibly.
#'
#' @example # Example usage of the function
#' # write_coefficients(store, "ALFL", "north", 1, coefs)
write_coefficients <- function(
  store, species, region, boot, coefficients
) {
  if (is.null(coefficients) || nrow(coefficients) == 0) {
    return(invisible(NULL))
  }

  result_append(store, "coefficients", data.frame(
    species = species,
    region = region,
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
#' Everything needed to say what produced the other four files.
#' Written as JSON by hand rather than through jsonlite, so the
#' harness keeps its base-R-plus-data.table dependency.
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
#' What comparison scripts use. A missing file returns NULL
#' rather than stopping, because an engine without coefficients
#' legitimately writes none.
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
