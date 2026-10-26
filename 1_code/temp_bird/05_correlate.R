# ---
# title: Correlate Target, 2025 and 2026-08 Bird Coefficients
# author: Brendan Casey
# created: 2026-10-15
# inputs:
#   from 04_plot_old_new_target.R, in 3_output/temp_bird/tables/:
#     - bird_old_new_target_terms.csv
# outputs:
#   in 3_output/temp_bird/tables/:
#     - bird_coefficient_correlations.csv
# notes:
#   - Simple correlation tests between the three sets of model
#     coefficient medians: v2 target vs Data 2025, v2 target vs
#     Data 2026-08, and Data 2025 vs Data 2026-08.
#   - One test per species and component (climate, north and
#     south landcover, north and south habitat), plus a pooled
#     test per component across the five species. Each
#     observation is one term's median over the bootstrap fits.
#   - Spearman is the one to read. Within a component the terms
#     span up to ~14 orders of magnitude (the climate intercept is
#     ~-300, the quadratic spatial terms ~1e-12), so a Pearson r
#     there is set almost entirely by the largest terms. Pearson
#     is reported beside it for completeness.
#   - Terms are paired where both sides have a value; a landcover
#     term selected in no draw on one side drops out of that pair.
#   - With 10 climate terms per species, p-values are coarse.
# ---

# 1. Setup ----

## 1.1 Load packages ----
library(data.table) # reshaping and summaries (version: 1.18.0)

## 1.2 Paths ----
tables_dir <- "3_output/temp_bird/tables"
terms_path <- file.path(tables_dir, "bird_old_new_target_terms.csv")
out_path <- file.path(tables_dir, "bird_coefficient_correlations.csv")

if (!file.exists(terms_path)) {
  stop("Not found: ", terms_path, "; run 04_plot_old_new_target.R.",
       call. = FALSE)
}

# 2. Shape the coefficients ----
# One row per species, component and term; one column per set.
terms <- fread(terms_path)
terms[, component := paste(region, stage)]

runs <- dcast(
  terms, species + component + term ~ version, value.var = "median"
)
target <- unique(
  terms[, .(species, component, term, `v2 target` = v2_median)]
)
wide <- merge(target, runs, by = c("species", "component", "term"))

# The three pairs tested
pairs <- list(
  c("v2 target", "Data 2025"),
  c("v2 target", "Data 2026-08"),
  c("Data 2025", "Data 2026-08")
)

# 3. Test ----

## 3.1 correlate() ----

#' Pearson and Spearman Tests for Every Pair in One Group
#'
#' @param data A data table with one column per coefficient set.
#' @return A data table: one row per pair and method, with the
#'   estimate, p-value and number of terms.
#'
#' @example # Example usage of the function
#' # correlate(wide[species == "AMRO" & component == "all climate"])
correlate <- function(data) {
  rbindlist(lapply(pairs, function(pair) {
    x <- data[[pair[1]]]
    y <- data[[pair[2]]]
    keep <- is.finite(x) & is.finite(y)
    x <- x[keep]
    y <- y[keep]

    rbindlist(lapply(c("spearman", "pearson"), function(method) {
      # A constant column has no correlation to test
      test <- if (length(x) >= 3 && stats::sd(x) > 0 &&
                    stats::sd(y) > 0) {
        suppressWarnings(stats::cor.test(x, y, method = method))
      } else {
        NULL
      }

      data.table(
        pair = paste(pair, collapse = " vs "),
        method = method,
        r = if (is.null(test)) NA_real_ else unname(test$estimate),
        p_value = if (is.null(test)) NA_real_ else test$p.value,
        terms = length(x)
      )
    }))
  }))
}

## 3.2 By species and pooled ----
by_species <- wide[, correlate(.SD), by = .(species, component)]
pooled <- wide[, correlate(.SD), by = component][
  , species := "all five"
]

correlations <- rbind(by_species, pooled, use.names = TRUE)
correlations[, `:=`(r = round(r, 4), p_value = signif(p_value, 3))]
setorder(correlations, component, species, method, pair)

fwrite(correlations, out_path)

# 4. Report ----
# Spearman, the one to read, one row per species and component
cat("\nSpearman r (terms):\n")
spearman <- correlations[method == "spearman"]
spearman[, cell := sprintf("%.3f (%d)", r, terms)]
print(dcast(spearman, component + species ~ pair, value.var = "cell"))

cat("\nWrote", out_path, "\n")

# End of script ----
