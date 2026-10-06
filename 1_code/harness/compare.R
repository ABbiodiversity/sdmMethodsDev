# ---
# title: Compare an Experiment Against a Baseline
# author: Brendan Casey
# created: 2026-10-03
# inputs:
#   in each experiment's out_dir/tables/:
#     - metric_summary.csv (collect_results())
# outputs:
#   in the candidate's out_dir/tables/:
#     - comparison_metrics.csv: one row per species and metric
#   the per-taxon, region and metric summary is returned (and
#   printed by run_experiment()) but not written
# notes:
#   - Every experiment after exp_000 asks the same thing: did the
#     change do better or worse than the v2 baseline? This answers
#     it the same way for any method, from the two experiments'
#     summary tables, so a new experiment needs one call.
#   - Model fit is compared on the out-of-bag metrics, which
#     score each draw on the units it left out. In-sample metrics
#     flatter a flexible method, so they are not the default.
#   - Rows are matched on taxon, region, season, part, species
#     and metric, so two experiments that name
#     their runs differently still line up.
#   - "Better" depends on the metric: higher AUC, deviance
#     explained and Spearman; lower RMSE; a calibration slope
#     closer to 1. better_direction() states it once.
#   - Each side's draw count is kept in the summary
#     (`draws_baseline`, `draws_candidate`), and a mismatch is
#     warned about: a trial against a full run is not a result.
#   - A difference is a difference in medians over draws. Whether
#     it is larger than draw-to-draw noise is read from
#     `share_better` across species and from the p10-p90 bands in
#     comparison_metrics.csv, not from a single number.
# ---

# 1. Setup ----

## 1.1 Load packages ----
library(data.table) # keyed joins (version: 1.16.4)

# 2. better_direction() ----

#' Which Way Is Better for a Metric
#'
#' @param metric Character vector of metric names, with or
#'   without an `insample_` or `oob_` prefix.
#' @return Character vector: "higher", "lower", "toward_one" or
#'   "none" (prevalence, n: not a measure of fit).
#'
#' @example # Example usage of the function
#' # better_direction(c("oob_auc", "oob_rmse"))
better_direction <- function(metric) {
  base <- sub("^(insample_|oob_)", "", metric)

  ifelse(
    base %in% c("rmse"), "lower",
    ifelse(
      base %in% c("calibration_slope"), "toward_one",
      ifelse(base %in% c("prevalence", "n"), "none", "higher")
    )
  )
}

# 3. compare_experiments() ----

#' Compare an Experiment's Summaries Against a Baseline's
#'
#' @param candidate_dir Character. The experiment's out_dir.
#' @param baseline_dir Character. The baseline's out_dir, e.g.
#'   3_output/exp_000_parity_v2.
#' @param metrics Character vector of metrics to compare, or NULL
#'   for the out-of-bag fit metrics.
#' @param write Logical. Write `metrics` to
#'   `candidate_dir/tables/comparison_metrics.csv`.
#' @return A list of data frames: `metrics` (per species) and
#'   `summary` (per taxon, region and metric).
#'
#' @example # Example usage of the function
#' # compare_experiments("3_output/exp_001_brt",
#' #                     "3_output/exp_000_parity_v2")
compare_experiments <- function(
  candidate_dir,
  baseline_dir,
  metrics = NULL,
  write = TRUE
) {
  read_summary <- function(dir, name) {
    path <- file.path(dir, "tables", paste0(name, ".csv"))

    if (!file.exists(path)) {
      return(NULL)
    }

    rows <- fread(path, na.strings = "")
    # Season and part are empty for most taxa; a join needs them
    # equal, not missing
    for (column in c("season", "part")) {
      if (column %in% names(rows)) {
        rows[[column]] <- ifelse(
          is.na(rows[[column]]), "", as.character(rows[[column]])
        )
      }
    }
    rows
  }

  keys <- c("taxon", "region", "season", "part", "species")
  values <- c("n", "median", "p10", "p90")

  # Step 1: Model fit, per species and metric
  metrics <- metrics %||% c(
    "oob_auc", "oob_deviance_explained", "oob_rmse",
    "oob_spearman", "oob_calibration_slope"
  )

  candidate <- read_summary(candidate_dir, "metric_summary")
  baseline <- read_summary(baseline_dir, "metric_summary")

  if (is.null(candidate) || is.null(baseline)) {
    stop(
      "Both experiments need tables/metric_summary.csv; run their ",
      "collect step first.",
      call. = FALSE
    )
  }

  # The mean and sd ride along where both experiments have them;
  # a baseline summarized before they were added lacks them
  values <- c(values, intersect(
    c("mean", "sd"), intersect(names(candidate), names(baseline))
  ))

  pick <- function(rows) {
    rows[metric %in% metrics, c(keys, "metric", values), with = FALSE]
  }

  joined <- merge(
    pick(baseline), pick(candidate),
    by = c(keys, "metric"), suffixes = c("_baseline", "_candidate")
  )

  joined[, difference := median_candidate - median_baseline]
  joined[, direction := better_direction(metric)]
  joined[, better := data.table::fcase(
    direction == "higher", median_candidate > median_baseline,
    direction == "lower", median_candidate < median_baseline,
    direction == "toward_one",
    abs(median_candidate - 1) < abs(median_baseline - 1),
    default = NA
  )]

  # Step 2: Per taxon, region and metric
  summary <- joined[, list(
    species = .N,
    draws_baseline = stats::median(n_baseline, na.rm = TRUE),
    draws_candidate = stats::median(n_candidate, na.rm = TRUE),
    median_baseline = stats::median(median_baseline, na.rm = TRUE),
    median_candidate = stats::median(median_candidate, na.rm = TRUE),
    median_difference = stats::median(difference, na.rm = TRUE),
    share_better = mean(better, na.rm = TRUE)
  ), by = c("taxon", "region", "season", "part", "metric")]

  # A band from 5 draws is not comparable with one from 100, so a
  # mismatch is said out loud rather than left in a column
  mismatched <- summary[draws_baseline != draws_candidate]

  if (nrow(mismatched) > 0) {
    warning(
      "The two experiments hold different numbers of draws (",
      paste(unique(mismatched$draws_baseline), collapse = ", "),
      " in the baseline, ",
      paste(unique(mismatched$draws_candidate), collapse = ", "),
      " here). Compare like with like before reading the result.",
      call. = FALSE
    )
  }

  out <- list(
    metrics = as.data.frame(joined),
    summary = as.data.frame(summary)
  )

  if (write) {
    tables_dir <- file.path(candidate_dir, "tables")
    dir.create(tables_dir, recursive = TRUE, showWarnings = FALSE)
    fwrite(
      out$metrics,
      file.path(tables_dir, "comparison_metrics.csv"),
      na = ""
    )
  }

  out
}

# End of script ----
