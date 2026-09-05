# ---
# title: Collect v2 Model Output (Experiment 000)
# author: Brendan Casey
# created: 2026-09-05
# inputs:
#   in 2_pipeline/exp_000_parity_v2/<taxon>/3_output/:
#     - models/<taxon>-species-models.Rdata
#     - validation/<taxon>-models-validation.Rdata
# outputs:
#   in 3_output/exp_000_parity_v2/tables/:
#     - species_<taxon>.csv
#     - validation_summary.csv
# notes:
#   - Placeholder. Reads the raw output each taxon module left in
#     2_pipeline/ and writes flat summaries to 3_output/.
#   - Raw model objects stay in 2_pipeline/ on purpose. They are
#     100 bootstraps by every species by three model families,
#     which is too large to commit; only the derived summaries
#     belong in 3_output/.
#   - Expects exp_id, project_root, and out_dir from run.R.
# ---

# 1. Setup ----

## 1.1 Resolve paths ----
# Sourced by run.R, so the experiment configuration is already
# in the environment.
pipeline_dir <- file.path(project_root, "2_pipeline", exp_id)

tables_dir <- file.path(out_dir, "tables")
dir.create(tables_dir, recursive = TRUE, showWarnings = FALSE)

## 1.2 Identify the taxa that produced output ----
# A taxon appears here only when its module ran in this pass.
staged_taxa <- list.dirs(
  pipeline_dir, full.names = FALSE, recursive = FALSE
)
staged_taxa <- setdiff(staged_taxa, "logs")

# 2. Collect model coefficients ----
# TODO: load each <taxon>-species-models.Rdata, reduce the
# bootstrap coefficient arrays to per-species summaries, and
# write one table per taxon.

# 3. Collect validation metrics ----
# TODO: load each <taxon>-models-validation.Rdata and write the
# per-species AUC and fit measures to validation_summary.csv.

# 4. Report what was found ----
cat(
  "01_collect_results.R is a placeholder. Taxa staged in ",
  pipeline_dir, ": ",
  if (length(staged_taxa) > 0) {
    paste(staged_taxa, collapse = ", ")
  } else {
    "none"
  },
  "\n",
  sep = ""
)

# End of script ----
