# ---
# title: Collect v2 Model Output (Experiment 000)
# author: Brendan Casey
# created: 2026-09-05
# inputs:
#   in pipeline_dir/<taxon>/:
#     - models/<taxon>-species-models.Rdata
#     - validation/<taxon>-models-validation.Rdata
# outputs:
#   in out_dir/tables/:
#     - species_<taxon>.csv
#     - validation_summary.csv
# notes:
#   - Placeholder. Reads the model output each taxon left in
#     pipeline_dir and writes flat summaries to out_dir.
#   - Raw model objects stay in pipeline_dir on purpose. They are
#     100 bootstraps by every species by three model families,
#     which is too large to commit; only the derived summaries
#     belong in 3_output/.
#   - Expects exp_id, pipeline_dir and out_dir from run.R. Both
#     paths are taken from there rather than rebuilt here, so a
#     run pointed at a scratch disk is still read correctly.
# ---

# 1. Setup ----

## 1.1 Resolve paths ----
# Sourced by run.R, so the experiment configuration is already
# in the environment.
tables_dir <- file.path(out_dir, "tables")
dir.create(tables_dir, recursive = TRUE, showWarnings = FALSE)

## 1.2 Identify the taxa that produced output ----
# A taxon appears here only once its stages have run into this
# pipeline_dir, in this pass or an earlier one.
run_taxa <- list.dirs(
  pipeline_dir, full.names = FALSE, recursive = FALSE
)
run_taxa <- setdiff(run_taxa, "logs")

# 2. Collect model coefficients ----
# TODO: load each <taxon>-species-models.Rdata, reduce the
# bootstrap coefficient arrays to per-species summaries, and
# write one table per taxon.

# 3. Collect validation metrics ----
# TODO: load each <taxon>-models-validation.Rdata and write the
# per-species AUC and fit measures to validation_summary.csv.

# 4. Report what was found ----
cat(
  "01_collect_results.R is a placeholder. Taxa found in ",
  pipeline_dir, ": ",
  if (length(run_taxa) > 0) {
    paste(run_taxa, collapse = ", ")
  } else {
    "none"
  },
  "\n",
  sep = ""
)

# End of script ----
