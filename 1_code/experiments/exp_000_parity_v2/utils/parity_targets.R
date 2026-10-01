# ---
# title: Parity Targets for Experiment 000
# author: Brendan Casey
# created: 2026-09-29
# inputs:
#   - 3_output/exp_000_parity_v2/tables/v2_self_agreement_summary.csv,
#     from v2_self_agreement.R, for the evidence behind the
#     distributional targets
# outputs: none; returns objects in memory
# notes:
#   - What "pass" means, per comparison type. Proposed from the
#     v2 self-agreement calibration; they stand until agreed or
#     changed, and the report says they are proposals.
#   - Two kinds of comparison:
#     - Numerical, where v2 fitted once on the same data the
#       harness fits at iteration 1 (the mammal hurdle): every
#       reachable term within `numerical_tolerance`. The ports
#       reach 2e-14, so 1e-6 leaves room only for platform
#       arithmetic, not for a method difference.
#     - Distributional, where v2 bootstraps unseeded: the v2
#       median inside this run's 10th-to-90th percentile band
#       for at least `min_in_band_pct` of reachable terms, a
#       median standardized difference no larger than
#       `max_standardized_difference`, and a median band-width
#       ratio (this run's band over v2's) inside
#       `band_ratio_range`.
#   - Why a band-width ratio. The in-band and standardized
#     difference tests both measure against this run's own band,
#     so a harness that is noisier than v2 passes them more
#     easily. The ratio closes that: too wide or too narrow a band
#     fails, including one read from a store holding too few
#     draws.
#   - Spearman of the medians is reported but no longer gated.
#     Model averaging shrinks unsupported terms towards zero in
#     both runs, and ranking values of 1e-30 against 1e-40 ranks
#     noise: it failed the mite climate stage with every term in
#     band. It caught nothing the other tests missed.
#   - The calibration (bryophyte climate, two v2 runs of the same
#     code): 100% in band, median standardized difference 0.019;
#     per-species median band ratio 1.00, 5th to 95th percentile
#     0.78 to 1.21. The targets sit outside those by a margin,
#     because one harness run is compared with one v2 run and both
#     carry sampling error:
#     - in band: 90%, ten points under v2's own 100%;
#     - standardized difference: 0.25, over ten times v2's own;
#     - band ratio: 0.75 to 1.33, symmetric on a log scale
#       (1 / 0.75) and just outside v2's 90% range.
#   - The ratio is taken per species as the median over its
#     terms, then as the median over species. Single terms are
#     useless for it: between two v2 runs, 10% of terms differ in
#     width threefold or more.
#   - Negligible terms are left out of the ratio (and of the
#     reported Spearman): those both runs put below a millionth
#     of the term's typical size, from is_negligible(). Model
#     averaging leaves them at 1e-20 to 1e-140, where band widths
#     are noise; without the rule, twelve such terms took the
#     lichen Physcia ratio to 0.31 while its seven real terms sat
#     at 0.7 to 1.2.
#   - The calibration covers the plant climate stage only. The
#     same targets are applied to the plant habitat stage and the
#     bird stages on the assumption that v2's self-agreement is
#     similar there; no second v2 run exists to check it.
#   - A trial run - fewer draws than v2 or a species subset - is
#     not gated at all: its bands are too wide or its coverage too
#     narrow for a verdict to mean anything.
# ---

# 1. Setup ----

## 1.1 Load packages ----
# Base R only.

# 2. parity_targets() ----

#' The Proposed Parity Targets
#'
#' @return A named list of thresholds.
#'
#' @example # Example usage of the function
#' # parity_targets()$min_in_band_pct
parity_targets <- function() {
  list(
    status = "proposed, not yet agreed",
    numerical_tolerance = 1e-6,
    min_in_band_pct = 90,
    max_standardized_difference = 0.25,
    band_ratio_range = c(0.75, 1 / 0.75),
    negligible_fraction = 1e-6
  )
}

# 3. is_negligible() and term_scale() ----

#' Flag Terms Model Averaging Has Shrunk to Nothing
#'
#' A term is negligible for a species when both runs put it below
#' `fraction` of that term's typical size: the 90th percentile of
#' its absolute v2 median over every species of the taxon and
#' stage. Typical size is taken per term because terms carry
#' units: an Easting coefficient of 1e-6 is real, a MAP one of
#' 1e-21 is not.
#'
#' @param run_value,v2_value Numeric. The two runs' medians.
#' @param typical Numeric. The term's typical absolute size.
#' @param fraction Numeric. From parity_targets().
#' @return Logical, TRUE where both runs are negligible.
#'
#' @example # Example usage of the function
#' # is_negligible(1e-22, 1e-21, typical = 1e-3)
is_negligible <- function(
  run_value, v2_value, typical,
  fraction = parity_targets()$negligible_fraction
) {
  limit <- fraction * typical
  is.finite(limit) & is.finite(run_value) & is.finite(v2_value) &
    abs(run_value) < limit & abs(v2_value) < limit
}

#' Typical Absolute Size of Each Term
#'
#' @param reference data.frame with group columns, `term` and
#'   `v2_median`: every species, not only the run's.
#' @param by Character. The grouping columns besides `term`.
#' @return data.frame of the groups, `term` and `typical`.
#'
#' @example # Example usage of the function
#' # term_scale(reference, c("taxon", "stage"))
term_scale <- function(reference, by) {
  values <- reference[is.finite(reference$v2_median), ]
  stats::aggregate(
    list(typical = abs(values$v2_median)),
    values[, c(by, "term")],
    function(x) stats::quantile(x, 0.9, names = FALSE)
  )
}

# 4. parity_verdict() ----

#' Read One Parity Summary Row Against the Targets
#'
#' @param comparison Character. "median" or "iteration 1".
#' @param in_band_pct,median_standardized_difference Numbers from
#'   the parity summary.
#' @param median_band_ratio,max_absolute_difference Numbers from
#'   the parity summary.
#' @param gated Logical. FALSE for a trial run.
#' @param targets From parity_targets().
#' @return Character: "pass", "fail", "no comparison" or
#'   "not gated (trial run)".
#'
#' @example # Example usage of the function
#' # parity_verdict("median", 95, 0.1, 1.02, NA, TRUE)
parity_verdict <- function(
  comparison, in_band_pct, median_standardized_difference,
  median_band_ratio, max_absolute_difference, gated,
  targets = parity_targets()
) {
  if (!gated) {
    return("not gated (trial run)")
  }

  if (identical(comparison, "iteration 1")) {
    if (!is.finite(max_absolute_difference)) {
      return("no comparison")
    }

    return(if (max_absolute_difference <= targets$numerical_tolerance) {
      "pass"
    } else {
      "fail"
    })
  }

  if (!is.finite(in_band_pct)) {
    return("no comparison")
  }

  passes <- in_band_pct >= targets$min_in_band_pct &&
    is.finite(median_standardized_difference) &&
    median_standardized_difference <=
      targets$max_standardized_difference &&
    is.finite(median_band_ratio) &&
    median_band_ratio >= targets$band_ratio_range[1] &&
    median_band_ratio <= targets$band_ratio_range[2]

  if (passes) "pass" else "fail"
}

# End of script ----
