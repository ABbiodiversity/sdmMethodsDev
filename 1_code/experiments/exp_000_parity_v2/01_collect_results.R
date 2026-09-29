# ---
# title: Collect Model Output (Experiment 000)
# author: Brendan Casey
# created: 2026-09-09
# inputs:
#   in pipeline_dir/<run>/<region>/:
#     - coefficients.csv, metrics.csv, meta.json
#   0_data/test_dataset/, for the bird translation
# outputs:
#   in out_dir/tables/:
#     - coefficient_summary.csv
#     - metric_summary.csv
#     - coverage.csv
# notes:
#   - Reduces the per-draw result stores to per-species summaries,
#     which is what the comparison and the report read. The raw
#     stores stay in pipeline_dir: 100 draws by every species is
#     too large to commit.
#   - One row per stage, not only the last, so the climate stage
#     can be compared as well as the habitat stage. Stores
#     written before stages were recorded carry the final stage
#     only, and are labelled with it from meta.json.
#   - Bird landcover coefficients are also translated onto v2's
#     standardized habitat template, by
#     modules/birds/standardize.R, and added as stage "habitat".
#     The raw coefficients stay as stage "landcover".
#   - Bootstrap draws are summarized by median and the 10th and
#     90th percentiles rather than mean and standard deviation.
#     A coefficient distribution over draws is routinely skewed,
#     and a rare species can produce an extreme draw that would
#     drag a mean somewhere no draw actually is.
#   - `boot1` is the iteration-1 value, the full-data fit. It is
#     the like-for-like quantity where v2 fits once rather than
#     bootstrapping, as the mammal habitat stage does.
#   - `run` is the spec's key in run.R and names the store; the
#     taxon, season and part come from the store's meta.json, so
#     the two mammal season runs share the taxon "mammal".
#   - Expects exp_id, data_dir, pipeline_dir and out_dir from
#     run.R, and the bird module to be sourced.
# ---

# 1. Setup ----

## 1.1 Load packages ----
library(jsonlite) # reading meta.json (version: 1.8.9)

## 1.2 Resolve paths ----
tables_dir <- file.path(out_dir, "tables")
dir.create(tables_dir, recursive = TRUE, showWarnings = FALSE)

## 1.3 Find the result stores ----
# One per run and region, wherever a run wrote one.
store_dirs <- list.dirs(pipeline_dir, recursive = TRUE)
store_dirs <- store_dirs[
  file.exists(file.path(store_dirs, "meta.json"))
]

if (length(store_dirs) == 0) {
  message(
    "No result stores in ", pipeline_dir,
    "; run section 2 of run.R first."
  )
}

# 2. Summarize ----

## 2.1 Helpers ----

#' Summarize a Value over Bootstrap Draws
#'
#' @param x Numeric vector.
#' @param boot Integer vector of the draw each value came from.
#' @return A named numeric vector of n, median, 10th and 90th
#'   percentiles, and the iteration-1 value.
#'
#' @example # Example usage of the function
#' # draw_summary(c(0.1, 0.3, 0.2), 1:3)
draw_summary <- function(x, boot) {
  boot1 <- x[boot == 1L]
  boot1 <- if (length(boot1) == 1 && is.finite(boot1)) {
    boot1
  } else {
    NA_real_
  }

  x <- x[is.finite(x)]

  if (length(x) == 0) {
    return(c(n = 0, median = NA_real_, p10 = NA_real_,
             p90 = NA_real_, boot1 = boot1))
  }

  quantiles <- stats::quantile(x, c(0.1, 0.5, 0.9), names = FALSE)

  c(n = length(x), median = quantiles[2], p10 = quantiles[1],
    p90 = quantiles[3], boot1 = boot1)
}

#' Read a Store's meta.json, Tolerating a Missing Field
#'
#' @param dir Character. A result store directory.
#' @return A list with taxon, season, part and final_stage.
#'
#' @example # Example usage of the function
#' # store_meta(store_dirs[1])
store_meta <- function(dir) {
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

## 2.2 Walk the stores ----
coefficient_rows <- list()
metric_rows <- list()
coverage_rows <- list()

for (dir_one in store_dirs) {
  # A store is <pipeline_dir>/<run>/<region>/. The run is read
  # off the folder; the rest from meta.json, rather than parsed
  # out of a path that may not use forward slashes.
  meta <- store_meta(dir_one)
  run <- basename(dirname(dir_one))
  region <- if (is.na(meta$region)) basename(dir_one) else meta$region
  taxon <- if (is.na(meta$taxon)) run else meta$taxon

  labels <- data.frame(
    taxon = taxon, run = run, region = region,
    season = meta$season, part = meta$part,
    stringsAsFactors = FALSE
  )

  coefficients <- read_results(dir_one, "coefficients")
  metrics <- read_results(dir_one, "metrics")

  # A store written before stages were recorded holds the final
  # stage only.
  if (!is.null(coefficients) && !"stage" %in% names(coefficients)) {
    coefficients$stage <- meta$final_stage
  }

  # Bird landcover, translated onto v2's standardized template
  if (identical(taxon, "bird") && !is.null(coefficients)) {
    landcover <- coefficients[coefficients$stage == "landcover", ]

    if (nrow(landcover) > 0) {
      translated <- standardize_bird_coefficients(
        landcover, data_dir, region
      )
      coefficients <- rbind(
        coefficients,
        translated[, names(coefficients)]
      )
    }
  }

  coverage_rows[[dir_one]] <- cbind(
    labels,
    data.frame(
      species = length(unique(c(
        coefficients$species, metrics$species
      ))),
      draws = length(unique(c(coefficients$boot, metrics$boot))),
      stages = if (is.null(coefficients)) {
        ""
      } else {
        paste(unique(coefficients$stage), collapse = ", ")
      },
      has_coefficients = !is.null(coefficients),
      has_grid = !is.null(read_results(dir_one, "grid_predictions")),
      stringsAsFactors = FALSE
    )
  )

  if (!is.null(coefficients)) {
    split_key <- interaction(
      coefficients$species, coefficients$stage, coefficients$term,
      drop = TRUE
    )

    coefficient_rows[[dir_one]] <- do.call(rbind, lapply(
      split(coefficients, split_key),
      function(block) {
        cbind(
          labels,
          data.frame(
            stage = block$stage[1],
            species = block$species[1], term = block$term[1],
            stringsAsFactors = FALSE
          ),
          as.data.frame(t(draw_summary(block$estimate, block$boot)))
        )
      }
    ))
  }

  if (!is.null(metrics)) {
    split_key <- interaction(
      metrics$species, metrics$metric, drop = TRUE
    )

    metric_rows[[dir_one]] <- do.call(rbind, lapply(
      split(metrics, split_key),
      function(block) {
        cbind(
          labels,
          data.frame(
            species = block$species[1], metric = block$metric[1],
            stringsAsFactors = FALSE
          ),
          as.data.frame(t(draw_summary(block$value, block$boot)))
        )
      }
    ))
  }
}

# 3. Write ----
coefficient_summary <- do.call(rbind, coefficient_rows)
metric_summary <- do.call(rbind, metric_rows)
coverage <- do.call(rbind, coverage_rows)

for (one in list(
  list(coefficient_summary, "coefficient_summary.csv"),
  list(metric_summary, "metric_summary.csv"),
  list(coverage, "coverage.csv")
)) {
  if (!is.null(one[[1]])) {
    rownames(one[[1]]) <- NULL
    data.table::fwrite(
      one[[1]], file.path(tables_dir, one[[2]]), na = ""
    )
    cat("Wrote tables/", one[[2]], ": ", nrow(one[[1]]),
        " rows\n", sep = "")
  }
}

# End of script ----
