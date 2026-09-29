# ---
# title: Build the Experiment 000 Report
# author: Brendan Casey
# created: 2026-09-09
# inputs:
#   from run.R:
#     - specs, run_taxa, focal_species, n_bootstraps,
#       v2_bootstraps, boot_seed
#   from 02_compare_to_v2.R, when it ran this session:
#     - notes, the references it could not reach
#   in out_dir/tables/:
#     - coverage.csv, metric_summary.csv, parity_summary.csv
#   in 0_data/v2_results/:
#     - v2_results_coverage.csv
# outputs:
#   in out_dir/:
#     - report.md
# notes:
#   - Holds no status of its own. What each spec reproduces of v2
#     is read from the specs' `v2_coverage`, what v2 reference
#     exists from v2_results_coverage.csv, and what the gate
#     actually reached from the comparison step. Coverage is
#     stated once, in the specs, so the report cannot drift from
#     them.
#   - States what kind of run this was first. A trial run writes
#     the same files as a full one, and its parity numbers are
#     not a parity read.
#   - Written on every run, so a partial run still leaves a
#     legible record of what it was.
#   - Expects exp_id, data_dir, pipeline_dir, out_dir and the
#     run settings above from run.R.
# ---

# 1. Setup ----

## 1.1 Resolve paths ----
tables_dir <- file.path(out_dir, "tables")
report_file <- file.path(out_dir, "report.md")

# v2_results/ sits beside test_dataset/ in 0_data/.
v2_coverage_path <- file.path(
  dirname(data_dir), "v2_results", "v2_results_coverage.csv"
)

read_table <- function(path) {
  if (!file.exists(path)) {
    return(NULL)
  }

  as.data.frame(data.table::fread(path))
}

## 1.2 Read the inputs ----
coverage <- read_table(file.path(tables_dir, "coverage.csv"))
metric_summary <- read_table(
  file.path(tables_dir, "metric_summary.csv")
)
parity_summary <- read_table(
  file.path(tables_dir, "parity_summary.csv")
)
v2_reference <- read_table(v2_coverage_path)

# The specs that ran, not every spec defined, so the coverage
# table describes this run.
run_specs <- specs[intersect(run_taxa, names(specs))]

# The comparison step leaves its unreachable references in
# `notes`. Absent when it did not run this session.
gate_notes <- if (exists("notes") && is.list(notes)) {
  unlist(notes, use.names = FALSE)
} else {
  character(0)
}

# 2. Assemble ----

## 2.1 Helpers ----

#' Render a Data Frame as a Markdown Table
#'
#' @param x A data frame, or NULL.
#' @param empty Character. What to say when there is nothing.
#' @return A character vector of markdown lines.
#'
#' @example # Example usage of the function
#' # markdown_table(coverage)
markdown_table <- function(x, empty = "_Nothing recorded._") {
  if (is.null(x) || nrow(x) == 0) {
    return(empty)
  }

  # A pipe inside a cell would split it into two columns.
  cells <- as.data.frame(
    lapply(x, function(col) gsub("|", "\\|", col, fixed = TRUE)),
    stringsAsFactors = FALSE
  )

  header <- paste("|", paste(names(x), collapse = " | "), "|")
  rule <- paste(
    "|", paste(rep("---", ncol(x)), collapse = " | "), "|"
  )

  rows <- apply(cells, 1, function(row) {
    paste("|", paste(row, collapse = " | "), "|")
  })

  c(header, rule, rows)
}

## 2.2 What kind of run this was ----
is_full_species <- is.null(focal_species)
is_full_draws <- n_bootstraps >= v2_bootstraps

run_kind <- if (is_full_species && is_full_draws) {
  "**Full run.** Every species, every draw."
} else {
  paste0(
    "**Trial run.** ",
    if (!is_full_species) {
      paste0(length(focal_species), " focal species")
    } else {
      "every species"
    },
    ", ", n_bootstraps, " of ", v2_bootstraps, " draws. ",
    "Its parity numbers show the pipeline ran; they are not a ",
    "parity read."
  )
}

seed_text <- if (is.null(boot_seed)) {
  "unseeded, as in v2"
} else {
  paste0(
    "`boot_seed = ", boot_seed, "`, one derived seed per species"
  )
}

## 2.3 v2 references ----
reference_lines <- if (is.null(v2_reference)) {
  paste0(
    "_`v2_results_coverage.csv` not found; run ",
    "`1_code/_setup/05_harmonize_v2_results.R`._"
  )
} else {
  markdown_table(
    v2_reference[, intersect(
      c("source_label", "reachable", "rows", "species", "note"),
      names(v2_reference)
    )]
  )
}

gate_lines <- if (length(gate_notes) == 0) {
  "_Every taxon and region that ran had a reference to compare against._"
} else {
  paste0("- ", gate_notes)
}

## 2.4 Model fit ----
fit_lines <- if (is.null(metric_summary)) {
  "_No metrics recorded._"
} else {
  # In-sample against held-out, and v2's own validation where
  # the spec supplies it. Out-of-bag is the honest read;
  # in-sample is what v2 reports.
  shown <- c(
    insample_auc = "insample_auc",
    oob_auc = "oob_auc",
    v2val_full = "v2val_Full",
    oob_v2val_full = "oob_v2val_Full"
  )
  auc <- metric_summary[metric_summary$metric %in% shown, ]

  if (nrow(auc) == 0) {
    "_No AUC recorded._"
  } else {
    markdown_table(do.call(rbind, lapply(
      split(auc, list(auc$taxon, auc$region), drop = TRUE),
      function(block) {
        row <- data.frame(
          taxon = block$taxon[1],
          region = block$region[1],
          species = length(unique(block$species)),
          stringsAsFactors = FALSE
        )

        for (label in names(shown)) {
          values <- block$median[block$metric == shown[[label]]]
          row[[paste0("median_", label)]] <- if (length(values) == 0) {
            NA_real_
          } else {
            round(stats::median(values, na.rm = TRUE), 3)
          }
        }

        row
      }
    )))
  }
}

## 2.5 Write the report ----
lines <- c(
  paste0("# ", exp_id),
  "",
  paste0("Generated ", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
  "",
  run_kind,
  "",
  paste0("Draws: ", seed_text, "."),
  "",
  "## What each spec reproduces of v2",
  "",
  "Read from each spec's `v2_coverage`, which is where coverage is",
  "stated. Change it there, not here.",
  "",
  markdown_table(
    spec_coverage(run_specs),
    "_No specs ran._"
  ),
  "",
  "## v2 references",
  "",
  "What `0_data/v2_results/` holds, from `v2_results_coverage.csv`:",
  "",
  reference_lines,
  "",
  "What this run's comparison could not reach:",
  "",
  gate_lines,
  "",
  "## What ran",
  "",
  markdown_table(coverage),
  "",
  "## Parity against v2, by stage",
  "",
  "Every stage is compared against `v2_results.csv`. Climate is",
  "scored against v2's province-wide fit in both regions. Terms v2",
  "fixes at a placeholder are left out of the reachable scores.",
  "",
  paste0(
    "`verdict` reads each row against the parity targets in ",
    "`utils/parity_targets.R` (", parity_targets()$status, "): ",
    "numerical rows (iteration 1) pass when every reachable term is ",
    "within ", parity_targets()$numerical_tolerance, "; ",
    "distributional rows when at least ",
    parity_targets()$min_in_band_pct, "% of reachable terms are in ",
    "band, the median standardized difference is at most ",
    parity_targets()$max_standardized_difference, ", and the median ",
    "per-species Spearman correlation is at least ",
    parity_targets()$min_spearman, ". A trial run is not gated."
  ),
  "",
  markdown_table(
    parity_summary,
    "_No comparison produced. See the references above._"
  ),
  "",
  "Where v2 bootstraps, parity is **distributional**: v2 seeds no",
  "random draw, so two v2 runs differ, and each term is scored on",
  "whether the v2 median falls inside this run's",
  "10th-to-90th percentile band. Where v2 fits once",
  "(`comparison` = iteration 1: mammals), the run's full-data fit",
  "is compared directly; read `median_absolute_difference`.",
  "",
  "## Model fit",
  "",
  paste(
    "Median AUC over species. `insample` scores the units each",
    "draw fitted; `oob` the units it left out, the held-out read.",
    "`v2val` is v2's validation, scored from the coefficients as v2",
    "does (plants only). Iteration 1 is the full data and has no",
    "out-of-bag units."
  ),
  "",
  fit_lines,
  "",
  "## What is still needed",
  "",
  "See the experiment's `README.md` for what blocks the gate, and",
  "`docs/reviews/2026-09-28_alignment_review.md` for the full",
  "remediation plan.",
  ""
)

writeLines(lines, report_file)

cat("Wrote ", report_file, "\n", sep = "")

# End of script ----
