# ---
# title: How Well Does v2 Agree With Itself? (Experiment 000)
# author: Brendan Casey
# created: 2026-09-29
# inputs:
#   - 2_pipeline/v2_reference/bryophyte-species-models.Rdata,
#     from 1_code/_setup/03_rerun_bryophyte_v2_reference.R
#   - 0_data/v2_results/v2_results.csv, the bryophyte climate
#     rows, which come from v2's COEFS.RData
# outputs:
#   in 3_output/exp_000_parity_v2/tables/:
#     - v2_self_agreement.csv, per species and term
#     - v2_self_agreement_summary.csv, the rates the gate's
#       distributional targets are set from
# notes:
#   - The ceiling for any distributional parity target. v2 seeds
#     no bootstrap, so two runs of the same v2 code on the same
#     data disagree; asking the harness to agree with v2 more
#     closely than v2 agrees with itself would fail a perfect
#     reimplementation.
#   - The two runs are the bryophyte climate stage: v2's original
#     run, as published in COEFS.RData, and the rerun
#     _setup/03 made with the frozen v2 functions. Same code, same
#     data, different unseeded draws; 134 species by 19 terms by
#     100 draws each.
#   - Scored exactly as 02_compare_to_v2.R scores the harness, in
#     both directions: is one run's median inside the other's
#     10th-to-90th percentile band, and how far apart are the
#     medians relative to half that band. The two directions are
#     reported separately and averaged.
#   - Also the Spearman correlation of the medians across terms,
#     per species, because the terms span twenty orders of
#     magnitude and a Pearson correlation would read only the
#     intercept.
#   - Climate only: the regenerated reference has no habitat
#     stage. The rate is assumed to carry to the plant habitat
#     stage; that is an assumption, stated in the README.
#   - Run once, from the repository root, after _setup/03 and 05.
#     Not part of run.R's sequence.
# ---

# 1. Setup ----

## 1.1 Load packages ----
library(data.table) # reading and writing tables (version: 1.16.4)

## 1.2 Resolve paths ----
project_root <- normalizePath(getwd(), winslash = "/")
rerun_path <- file.path(
  project_root, "2_pipeline", "v2_reference",
  "bryophyte-species-models.Rdata"
)
results_path <- file.path(
  project_root, "0_data", "v2_results", "v2_results.csv"
)
tables_dir <- file.path(
  project_root, "3_output", "exp_000_parity_v2", "tables"
)
dir.create(tables_dir, recursive = TRUE, showWarnings = FALSE)

for (path in c(rerun_path, results_path)) {
  if (!file.exists(path)) {
    stop("Input not found:\n  ", path, call. = FALSE)
  }
}

## 1.3 Read the two runs ----
rerun_env <- new.env()
load(rerun_path, envir = rerun_env)
rerun <- rerun_env$climate.coef

published <- fread(results_path)[
  taxon == "bryophyte" & stage == "climate"
]

# 2. Summarize the rerun as the published run is summarized ----
rerun_summary <- rbindlist(lapply(names(rerun), function(species) {
  draws <- rerun[[species]]

  if (!is.matrix(draws)) {
    return(NULL)
  }

  rbindlist(lapply(colnames(draws), function(term) {
    values <- draws[, term]
    values <- values[is.finite(values)]

    data.table(
      species = species, term = term,
      rerun_median = stats::median(values),
      rerun_p10 = stats::quantile(values, 0.1, names = FALSE),
      rerun_p90 = stats::quantile(values, 0.9, names = FALSE)
    )
  }))
}))

# 3. Score each run against the other ----
joined <- merge(
  rerun_summary,
  published[, .(species, term, pub_median = v2_median,
                pub_p10 = v2_p10, pub_p90 = v2_p90)],
  by = c("species", "term")
)

joined[, `:=`(
  published_in_rerun_band =
    pub_median >= rerun_p10 & pub_median <= rerun_p90,
  rerun_in_published_band =
    rerun_median >= pub_p10 & rerun_median <= pub_p90,
  standardized_difference_rerun =
    abs(pub_median - rerun_median) / ((rerun_p90 - rerun_p10) / 2),
  standardized_difference_published =
    abs(pub_median - rerun_median) / ((pub_p90 - pub_p10) / 2)
)]

by_species <- joined[, .(
  spearman = suppressWarnings(stats::cor(
    rerun_median, pub_median, method = "spearman"
  ))
), by = species]

finite_median <- function(x) stats::median(x[is.finite(x)])

summary_table <- data.table(
  stage = "climate",
  taxon = "bryophyte",
  species = uniqueN(joined$species),
  terms = nrow(joined),
  in_band_pct_published_in_rerun = round(
    100 * mean(joined$published_in_rerun_band), 1
  ),
  in_band_pct_rerun_in_published = round(
    100 * mean(joined$rerun_in_published_band), 1
  ),
  in_band_pct = round(100 * mean(c(
    joined$published_in_rerun_band, joined$rerun_in_published_band
  )), 1),
  median_standardized_difference = round(finite_median(c(
    joined$standardized_difference_rerun,
    joined$standardized_difference_published
  )), 3),
  median_spearman = round(finite_median(by_species$spearman), 3),
  p10_spearman = round(stats::quantile(
    by_species$spearman, 0.1, na.rm = TRUE, names = FALSE
  ), 3)
)

# 4. Write ----
fwrite(joined, file.path(tables_dir, "v2_self_agreement.csv"))
fwrite(
  summary_table,
  file.path(tables_dir, "v2_self_agreement_summary.csv")
)

cat("v2 against itself, bryophyte climate:\n")
print(summary_table)

# End of script ----
