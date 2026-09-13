# ---
# title: Compare Against the v2.0 Reference (Experiment 000)
# author: Brendan Casey
# created: 2026-09-05
# inputs:
#   in 3_output/exp_000_parity_v2/tables/:
#     - species_<taxon>.csv
#     - validation_summary.csv
#   reference:
#     - the published v2.0 model output (source to be agreed)
# outputs:
#   in 3_output/exp_000_parity_v2/:
#     - tables/parity_<taxon>.csv
#     - figures/parity_<taxon>.png
# notes:
#   - Placeholder. This is the parity gate - it compares what
#     this repository produced against the species models v2.0
#     results for the same species.
#   - Open question: where the v2.0 reference output comes from.
#     Either a frozen snapshot under 0_data/ with a pointer in
#     manifest.md, or the external v2 project. The comparison
#     cannot be written until that is settled.
#   - The minimum acceptable parity target is not yet defined and
#     will need to be agreed per taxon.
#   - Expects exp_id, project_root, and out_dir from run.R.
# ---

# 1. Setup ----

## 1.1 Resolve paths ----
tables_dir <- file.path(out_dir, "tables")

figures_dir <- file.path(out_dir, "figures")
dir.create(figures_dir, recursive = TRUE, showWarnings = FALSE)

# 2. Compare coefficients ----
# TODO: join this run's per-species coefficients to the v2.0
# reference and record the differences per model family.

# 3. Compare validation metrics ----
# TODO: compare AUC and fit measures per species and bootstrap.

# 4. Summarize parity ----
# TODO: write parity_<taxon>.csv and the matching figure, then
# state the result against the agreed target.
cat(
  "02_compare_to_v2.R is a placeholder. The v2.0 reference ",
  "source and the parity target are still to be agreed.\n",
  sep = ""
)

# End of script ----
