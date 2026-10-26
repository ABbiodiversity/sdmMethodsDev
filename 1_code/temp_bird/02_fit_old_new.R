# ---
# title: Fit Five Birds on the Old and New Stratified Data
# author: Brendan Casey
# created: 2026-10-15
# inputs:
#   - the pinned published test dataset (new: v2's own
#     Stratified.Rdata)
#   - 2_pipeline/temp_bird/test_dataset_old/, from
#     01_build_old_dataset.R (old: the 2026-08-19 rebuild)
# outputs:
#   in 2_pipeline/temp_bird/<new|old>/:
#     - pipeline/, the result stores and run log
#     - out/tables/coefficient_summary.csv and the other summaries
# notes:
#   - The same v2 bird spec, species, draws and seed on both
#     datasets, so the fits differ only in the bird data.
#   - No baseline comparison and no run record: this is a
#     one-off check, not an experiment.
#   - 100 draws, so medians and 10-90% bands can be set against
#     v2's. On the new data, draws match v2's own; on the old
#     data they are different draws.
#   - Takes roughly 15-30 minutes per dataset on 12 workers.
#     Set `versions` to one of them to fit only that one.
# ---

# 1. Setup ----

## 1.1 Load the framework ----
source("1_code/harness/harness.R")
load_framework()

## 1.2 Settings ----
birds <- c(
  bird = "AMRO",
  bird = "YEWA",
  bird = "WTSP",
  bird = "CCSP",
  bird = "SAVS"
)

datasets <- c(
  new = paste0(
    "//ABMI-DATA2/science/sdmMethodsDev/0_data/test_dataset/",
    "2026-10-05"
  ),
  old = "2_pipeline/temp_bird/test_dataset_old"
)

versions <- c("new", "old")

n_bootstraps <- 100L
workers <- 12L

if (!dir.exists(datasets[["old"]]) && "old" %in% versions) {
  stop("Run 01_build_old_dataset.R first.", call. = FALSE)
}

# 2. Fit ----
for (version in versions) {
  cat("\n######## ", version, " ########\n", sep = "")

  config <- experiment_config(
    id = paste0("temp_bird_", version),
    specs = standard_specs(),
    species = birds,
    n_bootstraps = n_bootstraps,
    seed = 20260909L,
    workers = workers,
    baseline = NULL,
    data_dir = datasets[[version]],
    pipeline_dir = file.path("2_pipeline/temp_bird", version,
                             "pipeline"),
    out_dir = file.path("2_pipeline/temp_bird", version, "out")
  )

  run_experiment(
    config,
    translate = list(bird = bird_habitat_translation),
    record = FALSE
  )
}

# End of script ----
