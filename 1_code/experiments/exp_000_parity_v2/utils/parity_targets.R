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
#       `max_standardized_difference`, and a median per-species
#       Spearman correlation of the medians of at least
#       `min_spearman`.
#   - The calibration (bryophyte climate, two v2 runs of the same
#     code): 100% in band, median standardized difference 0.019,
#     median Spearman 0.998, 10th-percentile Spearman 0.887. The
#     targets sit below those by a margin, because one harness
#     run is compared with one v2 run and both carry sampling
#     error:
#     - in band: 90%, ten points under v2's own 100%;
#     - standardized difference: 0.25, over ten times v2's own;
#     - Spearman: 0.95.
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
    min_spearman = 0.95
  )
}

# 3. parity_verdict() ----

#' Read One Parity Summary Row Against the Targets
#'
#' @param comparison Character. "median" or "iteration 1".
#' @param in_band_pct,median_standardized_difference,median_spearman,max_absolute_difference
#'   Numbers from the parity summary.
#' @param gated Logical. FALSE for a trial run.
#' @param targets From parity_targets().
#' @return Character: "pass", "fail", "no comparison" or
#'   "not gated (trial run)".
#'
#' @example # Example usage of the function
#' # parity_verdict("median", 95, 0.1, 0.99, NA, TRUE)
parity_verdict <- function(
  comparison, in_band_pct, median_standardized_difference,
  median_spearman, max_absolute_difference, gated,
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
    median_standardized_difference <= targets$max_standardized_difference &&
    is.finite(median_spearman) &&
    median_spearman >= targets$min_spearman

  if (passes) "pass" else "fail"
}

# End of script ----
