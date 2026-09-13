# ---
# title: Collect Model Output (Experiment 000)
# author: Brendan Casey
# created: 2026-09-09
# inputs:
#   in pipeline_dir/<taxon>/<region>/:
#     - coefficients.csv, metrics.csv, meta.json
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
#   - Bootstrap draws are summarized by median and the 10th and
#     90th percentiles rather than mean and standard deviation.
#     A coefficient distribution over draws is routinely skewed,
#     and a rare species can produce an extreme draw that would
#     drag a mean somewhere no draw actually is.
#   - Expects exp_id, pipeline_dir and out_dir from run.R.
# ---

# 1. Setup ----

## 1.1 Resolve paths ----
tables_dir <- file.path(out_dir, "tables")
dir.create(tables_dir, recursive = TRUE, showWarnings = FALSE)

## 1.2 Find the result stores ----
# One per taxon and region, wherever a run wrote one.
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

## 2.1 Helper ----

#' Summarize a Value over Bootstrap Draws
#'
#' @param x Numeric vector.
#' @return A named numeric vector of n, median and 10th and 90th
#'   percentiles.
#'
#' @example # Example usage of the function
#' # draw_summary(c(0.1, 0.3, 0.2))
draw_summary <- function(x) {
  x <- x[is.finite(x)]

  if (length(x) == 0) {
    return(c(n = 0, median = NA_real_, p10 = NA_real_,
             p90 = NA_real_))
  }

  quantiles <- stats::quantile(x, c(0.1, 0.5, 0.9), names = FALSE)

  c(n = length(x), median = quantiles[2], p10 = quantiles[1],
    p90 = quantiles[3])
}

## 2.2 Walk the stores ----
coefficient_rows <- list()
metric_rows <- list()
coverage_rows <- list()

for (dir_one in store_dirs) {
  parts <- strsplit(
    sub(paste0("^", pipeline_dir, "/?"), "", dir_one), "/"
  )[[1]]

  taxon <- parts[1]
  region <- if (length(parts) > 1) parts[2] else NA_character_

  coefficients <- read_results(dir_one, "coefficients")
  metrics <- read_results(dir_one, "metrics")

  coverage_rows[[dir_one]] <- data.frame(
    taxon = taxon,
    region = region,
    species = length(unique(c(
      coefficients$species, metrics$species
    ))),
    draws = length(unique(c(coefficients$boot, metrics$boot))),
    has_coefficients = !is.null(coefficients),
    has_grid = !is.null(read_results(dir_one, "grid_predictions")),
    stringsAsFactors = FALSE
  )

  if (!is.null(coefficients)) {
    split_key <- interaction(
      coefficients$species, coefficients$term, drop = TRUE
    )

    summarized <- do.call(rbind, lapply(
      split(coefficients, split_key),
      function(block) {
        cbind(
          data.frame(
            taxon = taxon, region = region,
            species = block$species[1], term = block$term[1],
            stringsAsFactors = FALSE
          ),
          as.data.frame(t(draw_summary(block$estimate)))
        )
      }
    ))

    coefficient_rows[[dir_one]] <- summarized
  }

  if (!is.null(metrics)) {
    split_key <- interaction(
      metrics$species, metrics$metric, drop = TRUE
    )

    summarized <- do.call(rbind, lapply(
      split(metrics, split_key),
      function(block) {
        cbind(
          data.frame(
            taxon = taxon, region = region,
            species = block$species[1], metric = block$metric[1],
            stringsAsFactors = FALSE
          ),
          as.data.frame(t(draw_summary(block$value)))
        )
      }
    ))

    metric_rows[[dir_one]] <- summarized
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
