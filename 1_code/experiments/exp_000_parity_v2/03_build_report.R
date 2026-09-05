# ---
# title: Build the Experiment 000 Report
# author: Brendan Casey
# created: 2026-09-05
# inputs:
#   in 3_output/exp_000_parity_v2/:
#     - tables/parity_<taxon>.csv
#     - figures/parity_<taxon>.png
# outputs:
#   in 3_output/exp_000_parity_v2/:
#     - report.md
# notes:
#   - Placeholder. Assembles the tables and figures into the
#     committed report that states whether the parity gate
#     passed, per taxon.
#   - Writing a stub report.md on every run keeps the experiment
#     folder complete, so a partial run is still legible.
#   - Expects exp_id, project_root, and out_dir from run.R.
# ---

# 1. Setup ----

## 1.1 Resolve paths ----
report_file <- file.path(out_dir, "report.md")

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# 2. Assemble the report ----
# TODO: read the parity tables and figures and write the results
# section. For now the file records that the run happened and
# which species vector produced it.
report_lines <- c(
  paste0("# ", exp_id),
  "",
  paste0("Generated ", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
  "",
  "## Status",
  "",
  "Placeholder report. The parity comparison in",
  "`02_compare_to_v2.R` is not yet implemented, so no result is",
  "stated here yet.",
  ""
)

# 3. Write the report ----
writeLines(report_lines, report_file)

cat("Wrote ", report_file, "\n", sep = "")

# End of script ----
