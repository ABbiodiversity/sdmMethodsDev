# ---
# title: Summarize Result Stores
# author: Brendan Casey
# created: 2026-10-03
# inputs:
#   in pipeline_dir/<run>/<region>/:
#     - coefficients.csv, metrics.csv, grid_predictions.csv,
#       meta.json
# outputs:
#   collect_results() returns the summaries; write_summaries()
#   writes them to out_dir/tables/:
#     - coverage.csv, metric_summary.csv, grid_summary.csv
#       (small; committed)
#     - coefficient_summary.csv (large; gitignored)
# notes:
#   - Reduces the per-draw result stores to per-species summaries,
#     which is what every experiment compares. The same for any
#     experiment, so it lives in the harness: an experiment's own
#     scripts start from these tables.
#   - Draws are summarized by median and the 10th and 90th
#     percentiles rather than mean and standard deviation. A
#     coefficient's distribution over draws is routinely skewed,
#     and a rare species can produce an extreme draw that would
#     drag a mean somewhere no draw actually is.
#   - `boot1` is the iteration-1 value, the full-data fit. It is
#     the like-for-like quantity where a reference fits once
#     rather than bootstrapping, as the v2 mammal models do.
#   - `run` is the folder a store sits in, which run.R names; the
#     taxon, season and part come from the store's meta.json, so
#     the two mammal season runs share the taxon "mammal".
#   - A taxon whose coefficients need translating before they can
#     be compared (birds, onto v2's habitat template) is handled
#     by a function the experiment passes in `translate`, so the
#     harness stays taxon-agnostic.
#   - Each store is read once. The row counts and pooled metrics
#     the run record needs are kept from that read and handed to
#     run_record(), rather than read again.
# ---

# 1. Setup ----

## 1.1 Load packages ----
library(data.table) # grouped summaries (version: 1.16.4)

# 2. Finding stores ----

## 2.1 find_stores() ----

#' Find the Result Stores Under a Pipeline Directory
#'
#' A store is a directory holding a meta.json, laid out as
#' `<pipeline_dir>/<run>/<region>/`.
#'
#' @param pipeline_dir Character.
#' @return A data frame of dir, run, region, taxon, season, part
#'   and final_stage, ordered by run and region.
#'
#' @example # Example usage of the function
#' # find_stores("2_pipeline/exp_000_parity_v2")
find_stores <- function(pipeline_dir) {
  dirs <- list.dirs(pipeline_dir, recursive = TRUE)
  dirs <- dirs[file.exists(file.path(dirs, "meta.json"))]

  if (length(dirs) == 0) {
    return(data.frame(
      dir = character(0), run = character(0), region = character(0),
      taxon = character(0), season = character(0),
      part = character(0), final_stage = character(0),
      stringsAsFactors = FALSE
    ))
  }

  rows <- lapply(dirs, function(dir) {
    meta <- store_meta(dir)

    # The run is read off the folder; the rest from meta.json,
    # rather than parsed out of a path that may not use forward
    # slashes.
    data.frame(
      dir = dir,
      run = basename(dirname(dir)),
      region = if (is.na(meta$region)) basename(dir) else meta$region,
      taxon = if (is.na(meta$taxon)) {
        basename(dirname(dir))
      } else {
        meta$taxon
      },
      season = meta$season,
      part = meta$part,
      final_stage = meta$final_stage,
      stringsAsFactors = FALSE
    )
  })

  stores <- do.call(rbind, rows)
  stores[order(stores$run, stores$region), , drop = FALSE]
}

## 2.2 store_meta() ----

#' Read a Store's meta.json, Tolerating a Missing Field
#'
#' @param dir Character. A result store directory.
#' @return A list with taxon, region, season, part and
#'   final_stage; NA for what the file does not say.
#'
#' @example # Example usage of the function
#' # store_meta("2_pipeline/exp_000_parity_v2/lichen/north")
store_meta <- function(dir) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("Reading meta.json needs the jsonlite package.",
         call. = FALSE)
  }

  meta <- jsonlite::fromJSON(file.path(dir, "meta.json"))

  field <- function(name) {
    value <- meta[[name]]

    if (is.null(value) || length(value) == 0 ||
          identical(value, "NA") || all(is.na(value))) {
      NA_character_
    } else {
      as.character(value[1])
    }
  }

  list(
    taxon = field("taxon"),
    region = field("region"),
    season = field("season"),
    part = field("part"),
    final_stage = if (is.null(meta$stages)) {
      NA_character_
    } else {
      utils::tail(meta$stages, 1)
    }
  )
}

# 3. Summarizing draws ----

## 3.1 summarise_draws() ----

#' Summarize a Value over Bootstrap Draws, per Group
#'
#' @param rows A data frame with `boot` and the value column.
#' @param value Character. The column to summarize.
#' @param keys Character vector of grouping columns.
#' @return A data.table of the keys plus n, median, p10, p90 and
#'   boot1. n counts the finite values; boot1 is the iteration-1
#'   value where there is exactly one.
#'
#' @example # Example usage of the function
#' # summarise_draws(metrics, "value", c("species", "metric"))
summarise_draws <- function(rows, value, keys) {
  rows <- as.data.table(rows)

  # The column is passed through .SDcols rather than named inside
  # the call, because a column may itself be called `value`
  rows[, draw_summary(.SD[[1L]], boot), by = keys, .SDcols = value]
}

## 3.2 draw_summary() ----

#' Summarize One Value over Its Draws
#'
#' @param x Numeric vector, one value per draw.
#' @param boot Integer vector of the draw each value came from.
#' @return A list of n, median, p10, p90 and boot1.
#'
#' @example # Example usage of the function
#' # draw_summary(c(0.1, 0.3, 0.2), 1:3)
draw_summary <- function(x, boot) {
  first <- x[boot == 1L]
  first <- if (length(first) == 1 && is.finite(first)) {
    first
  } else {
    NA_real_
  }
  finite <- x[is.finite(x)]

  if (length(finite) == 0) {
    return(list(n = 0, median = NA_real_, p10 = NA_real_,
                p90 = NA_real_, boot1 = first))
  }

  quantiles <- stats::quantile(
    finite, c(0.1, 0.5, 0.9), names = FALSE
  )

  list(n = as.numeric(length(finite)), median = quantiles[2],
       p10 = quantiles[1], p90 = quantiles[3], boot1 = first)
}

# 4. collect_results() ----

#' Reduce Every Store in a Pipeline Directory to Summaries
#'
#' @param pipeline_dir Character. Where the stores are.
#' @param data_dir Character. Passed to `translate` functions.
#' @param translate Named list of functions, by taxon. Each takes
#'   the store's coefficients, `data_dir` and the region, and
#'   returns extra coefficient rows - a translation of them - to
#'   summarize alongside.
#' @return A list of data frames: `coverage`, `coefficient_summary`,
#'   `metric_summary`, `grid_summary`, and for the run record,
#'   `store_rows` (row counts per store) and `metrics` (every
#'   metric row, labelled with its run and region).
#'
#' @example # Example usage of the function
#' # results <- collect_results("2_pipeline/exp_000_parity_v2",
#' #   data_dir, translate = list(bird = bird_habitat_translation))
collect_results <- function(pipeline_dir, data_dir = NULL,
                            translate = list()) {
  stores <- find_stores(pipeline_dir)

  if (nrow(stores) == 0) {
    message("No result stores in ", pipeline_dir, ".")
  }

  pieces <- lapply(seq_len(nrow(stores)), function(i) {
    store <- stores[i, ]
    labels <- store[, c("taxon", "run", "region", "season", "part")]
    rownames(labels) <- NULL

    coefficients <- read_results(store$dir, "coefficients")
    metrics <- read_results(store$dir, "metrics")
    grid <- read_results(store$dir, "grid_predictions")

    counts <- data.frame(
      run = store$run, region = store$region,
      species = length(unique(c(coefficients$species,
                                metrics$species))),
      draws = length(unique(c(coefficients$boot, metrics$boot))),
      coefficient_rows = NROW(coefficients),
      metric_rows = NROW(metrics),
      grid_rows = NROW(grid),
      stringsAsFactors = FALSE
    )

    # A store written before stages were recorded holds the final
    # stage only
    if (!is.null(coefficients) && !"stage" %in% names(coefficients)) {
      coefficients$stage <- store$final_stage
    }

    # Coefficients a taxon needs translated before comparing
    translator <- translate[[store$taxon]]

    if (is.function(translator) && !is.null(coefficients)) {
      extra <- translator(coefficients, data_dir, store$region)

      if (!is.null(extra) && nrow(extra) > 0) {
        coefficients <- rbind(
          coefficients, extra[, names(coefficients)]
        )
      }
    }

    summarised <- function(rows, value, keys) {
      if (is.null(rows) || nrow(rows) == 0) {
        return(NULL)
      }

      cbind(labels, summarise_draws(rows, value, keys))
    }

    list(
      coverage = cbind(labels, data.frame(
        species = counts$species,
        draws = counts$draws,
        stages = if (is.null(coefficients)) {
          ""
        } else {
          paste(unique(coefficients$stage), collapse = ", ")
        },
        has_coefficients = !is.null(coefficients),
        has_grid = !is.null(grid),
        stringsAsFactors = FALSE
      )),
      coefficient_summary = summarised(
        coefficients, "estimate", c("stage", "species", "term")
      ),
      metric_summary = summarised(
        metrics, "value", c("species", "metric")
      ),
      grid_summary = summarised(
        grid, "prediction", c("species", "grid_unit")
      ),
      store_rows = counts,
      metrics = if (is.null(metrics)) {
        NULL
      } else {
        cbind(run = store$run, metrics)
      }
    )
  })

  combine <- function(name) {
    parts <- lapply(pieces, `[[`, name)
    parts <- parts[!vapply(parts, is.null, logical(1))]

    if (length(parts) == 0) {
      return(NULL)
    }

    out <- as.data.frame(rbindlist(parts, use.names = TRUE))
    rownames(out) <- NULL
    out
  }

  stats::setNames(
    lapply(
      c("coverage", "coefficient_summary", "metric_summary",
        "grid_summary", "store_rows", "metrics"),
      combine
    ),
    c("coverage", "coefficient_summary", "metric_summary",
      "grid_summary", "store_rows", "metrics")
  )
}

# 5. write_summaries() ----

#' Write the Summary Tables
#'
#' @param results From collect_results().
#' @param out_dir Character. Tables go in `out_dir/tables/`.
#' @return The paths written, invisibly.
#'
#' @example # Example usage of the function
#' # write_summaries(results, "3_output/exp_000_parity_v2")
write_summaries <- function(results, out_dir) {
  tables_dir <- file.path(out_dir, "tables")
  dir.create(tables_dir, recursive = TRUE, showWarnings = FALSE)

  tables <- c(
    "coverage", "metric_summary", "grid_summary",
    "coefficient_summary"
  )
  written <- character(0)

  for (name in tables) {
    table <- results[[name]]

    if (is.null(table)) {
      next
    }

    path <- file.path(tables_dir, paste0(name, ".csv"))
    fwrite(table, path, na = "")
    cat("Wrote tables/", name, ".csv: ", nrow(table), " rows\n",
        sep = "")
    written <- c(written, path)
  }

  invisible(written)
}

# End of script ----
