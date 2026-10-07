# ---
# title: How Well Does v2 Agree With Itself? (Experiment 000)
# author: Brendan Casey
# created: 2026-09-29
# inputs:
#   - 2_pipeline/v2_reference/bryophyte-species-models.Rdata,
#     from 1_code/_setup/03_rerun_bryophyte_v2_reference.R
#   - abmiexplorer/v2_results.csv from the published v2 results
#     (see 1_code/harness/data_source.R), the bryophyte climate
#     rows, from _setup/08. These are v2's original run: they
#     match v2's COEFS.RData to ~1e-15
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
#     run, as ABMIexploreR publishes it, and the rerun _setup/03
#     made with the frozen v2 functions. Same code, same data,
#     different unseeded draws; 19 terms by 100 draws for each
#     species both hold. Bryum.All is not published, so it
#     drops out (133 of the rerun's 134 species).
#   - Scored exactly as 01_compare_to_v2.R scores the harness, in
#     both directions: is one run's median inside the other's
#     10th-to-90th percentile band, and how far apart are the
#     medians relative to half that band. The two directions are
#     reported separately and averaged.
#   - Also the per-species Spearman of the medians (terms span
#     twenty orders of magnitude, so not Pearson). Reported, not
#     gated.
#   - And the band-width ratio, the rerun's 10-90% band over the
#     published run's, as a median per species. Its 5th to 95th
#     percentile over species sets the gate's band_ratio_range.
#   - Climate only: the regenerated reference has no habitat
#     stage. The rate is assumed to carry to the plant habitat
#     stage; that is an assumption, stated in the README.
#   - Run once, from the repository root, after _setup/03 and 08.
#     Not part of run.R's sequence.
# ---

# 1. Setup ----

## 1.1 Load packages ----
library(data.table) # reading and writing tables (version: 1.16.4)

## 1.2 Resolve paths ----
project_root <- normalizePath(getwd(), winslash = "/")

# The gate's negligible-term rule, so both are scored alike
source(file.path(
  project_root,
  "1_code/experiments/exp_000_parity_v2/utils/parity_targets.R"
))
rerun_path <- file.path(
  project_root, "2_pipeline", "v2_reference",
  "bryophyte-species-models.Rdata"
)
source(file.path(project_root, "1_code/harness/data_source.R"))
results_path <- file.path(
  v2_results_dir(), "abmiexplorer", "v2_results.csv"
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
      rerun_p90 = stats::quantile(values, 0.9, names = FALSE),
      rerun_mean = mean(values),
      rerun_sd = if (length(values) < 2) {
        NA_real_
      } else {
        stats::sd(values)
      }
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

# Scored as the gate scores: in band, or within the numerical
# tolerance for terms whose values are effectively zero.
tolerance <- 1e-6

joined[, `:=`(
  published_in_rerun_band =
    (pub_median >= rerun_p10 & pub_median <= rerun_p90) |
    abs(pub_median - rerun_median) <= tolerance,
  rerun_in_published_band =
    (rerun_median >= pub_p10 & rerun_median <= pub_p90) |
    abs(pub_median - rerun_median) <= tolerance,
  standardized_difference_rerun =
    abs(pub_median - rerun_median) / ((rerun_p90 - rerun_p10) / 2),
  standardized_difference_published =
    abs(pub_median - rerun_median) / ((pub_p90 - pub_p10) / 2)
)]

finite_median <- function(x) stats::median(x[is.finite(x)])

# The rerun's band width over the published run's. Summarized per
# species as the median over its terms, as the gate takes it, and
# without the terms both runs shrink to nothing, by the gate's
# is_negligible() rule.
joined[, band_ratio := (rerun_p90 - rerun_p10) / (pub_p90 - pub_p10)]

term_scales <- as.data.table(term_scale(
  as.data.frame(published), c("taxon", "stage")
))
joined <- merge(
  joined, term_scales[, .(term, typical)],
  by = "term", all.x = TRUE
)
joined[, negligible := is_negligible(
  rerun_median, pub_median, typical
)]

by_species <- joined[!(negligible), .(
  spearman = suppressWarnings(stats::cor(
    rerun_median, pub_median, method = "spearman"
  )),
  band_ratio = finite_median(band_ratio[band_ratio > 0])
), by = species]

summary_table <- data.table(
  stage = "climate",
  taxon = "bryophyte",
  species = uniqueN(joined$species),
  terms = nrow(joined),
  negligible_terms = sum(joined$negligible),
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
  ), 3),
  median_band_ratio = round(finite_median(by_species$band_ratio), 3),
  p05_band_ratio = round(stats::quantile(
    by_species$band_ratio, 0.05, na.rm = TRUE, names = FALSE
  ), 3),
  p95_band_ratio = round(stats::quantile(
    by_species$band_ratio, 0.95, na.rm = TRUE, names = FALSE
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
