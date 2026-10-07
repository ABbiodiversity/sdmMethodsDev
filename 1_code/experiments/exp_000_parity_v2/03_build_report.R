# ---
# title: Build the Experiment 000 Report
# author: Brendan Casey
# created: 2026-09-09
# inputs:
#   - `config`, from run.R: id, specs, taxa, focal_species,
#     n_bootstraps, v2_bootstraps, seed, out_dir and the v2
#     reference settings
#   - `results`: coverage and metric_summary (collect_results()),
#     parity_summary and parity_notes (01_compare_to_v2.R)
#   - in config$v2_reference_dir:
#     - v2_results_coverage.csv
# outputs:
#   in out_dir/:
#     - report.md
# notes:
#   - Holds no status of its own: coverage comes from the specs'
#     `v2_coverage`, references from v2_results_coverage.csv, and
#     results from the comparison step.
#   - Leads with the kind of run, since a trial writes the same
#     files as a full run. Run as a script_step().
# ---

# 1. Setup ----

## 1.1 Resolve paths ----
report_file <- file.path(config$out_dir, "report.md")
v2_coverage_path <- file.path(
  config$v2_reference_dir, "v2_results_coverage.csv"
)
v2_reference_builder <- config$v2_reference_builder

## 1.2 Read the inputs ----
coverage <- results$coverage
metric_summary <- results$metric_summary
parity_summary <- results$parity_summary
v2_coverage <- if (file.exists(v2_coverage_path)) {
  as.data.frame(data.table::fread(v2_coverage_path))
} else {
  NULL
}

# The comparison step's unreachable references
gate_notes <- unlist(results$parity_notes, use.names = FALSE)

# 2. Assemble ----

## 2.1 Helpers ----
# Tables are rendered by md_table() (harness/run_record.R), so the
# report and the run record format numbers the same way.
markdown_table <- function(x, empty = "_Nothing recorded._") {
  if (is.null(x) || nrow(x) == 0) empty else md_table(x, digits = 3L)
}

## 2.2 What kind of run this was ----
is_full_species <- is.null(config$focal_species)
is_full_draws <- config$n_bootstraps >= config$v2_bootstraps

run_kind <- if (is_full_species && is_full_draws) {
  "**Full run.** Every species, every draw."
} else {
  paste0(
    "**Trial run.** ",
    if (!is_full_species) {
      paste0(length(config$focal_species), " focal species")
    } else {
      "every species"
    },
    ", ", config$n_bootstraps, " of ", config$v2_bootstraps,
    " draws. ",
    "Its parity numbers show the pipeline ran; they are not a ",
    "parity read."
  )
}

seed_text <- if (is.null(config$seed)) {
  "unseeded, as in v2"
} else {
  paste0(
    "`seed = ", config$seed, "`, one derived seed per species"
  )
}

## 2.3 v2 references ----
reference_lines <- if (is.null(v2_coverage)) {
  paste0(
    "_`v2_results_coverage.csv` not found; run ",
    "`", v2_reference_builder, "`._"
  )
} else {
  markdown_table(
    v2_coverage[, intersect(
      c("source_label", "reachable", "rows", "species", "note"),
      names(v2_coverage)
    )]
  )
}

gate_lines <- if (length(gate_notes) == 0) {
  paste(
    "_Every taxon and region that ran had a reference to",
    "compare against._"
  )
} else {
  paste0("- ", gate_notes)
}

## 2.4 Model fit ----
fit_lines <- if (is.null(metric_summary)) {
  "_No metrics recorded._"
} else {
  # Out-of-bag is the honest read; in-sample is what v2 reports
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
          column <- paste0("median_", label)
          row[[column]] <- if (length(values) == 0) {
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
  paste0("# ", config$id),
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
    spec_coverage(config$specs),
    "_No specs ran._"
  ),
  "",
  "## v2 references",
  "",
  paste0(
    "Scored against `", config$v2_reference,
    "`, built by `", v2_reference_builder, "`. What it holds, ",
    "from `v2_results_coverage.csv`:"
  ),
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
    "band-width ratio (this run's band over v2's) is between ",
    paste(round(parity_targets()$band_ratio_range, 2),
          collapse = " and "),
    ". `median_spearman` is reported, not gated. ",
    "A trial run is not gated."
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
    "Median AUC over species, scored on each run's final model:",
    "for plants, v2's own prediction from its coefficient tables.",
    "`insample` scores the units each draw fitted; `oob` the units",
    "it left out, the held-out read. `v2val` is v2's validation,",
    "scored from the coefficients as v2 does (plants only), so for",
    "plants `v2val_full` equals `insample_auc`. Iteration 1 is the",
    "full data and has no out-of-bag units."
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
results$report_file <- report_file

# End of script ----
