# ---
# title: Compare Bootstrap Climate Coefficients, Set Against Set
# author: Brendan Casey
# created: 2026-10-15
# inputs:
#   from 02_fit_old_new.R, in 2_pipeline/temp_bird/:
#     - new/pipeline/bird/north/coefficients.csv (Data 2025)
#     - old/pipeline/bird/north/coefficients.csv (Data 2026-08)
#   on the BirdModels drive, through the work_abmi shortcut:
#     - Results/Archive/ClimateModels/Coefficients/<sp>/
#       ClimateModelCoefficients_<sp>_<draw>.csv, v2's draws
# outputs:
#   in 2_pipeline/temp_bird/:
#     - v2_climate_draws.csv, v2's per-draw climate coefficients
#   in 3_output/temp_bird/tables/:
#     - bird_climate_draw_comparison.csv
# notes:
#   - For each climate predictor and species, a run's 100
#     bootstrap coefficients are compared with v2's 100 as two
#     sets, not draw by draw:
#     - Kolmogorov-Smirnov: do the two distributions differ in
#       centre, spread or shape? D is the largest gap between
#       their cumulative distributions, 0 (identical) to 1 (no
#       overlap).
#     - Wilcoxon rank-sum: does one set sit higher or lower?
#     - The difference in medians, and the same in units of half
#       v2's 10-90% range (exp_000's standardized difference).
#   - Unpaired on purpose. Data 2026-08's draws are different
#     resamples from v2's, so pairing draw i with draw i would
#     compare unrelated fits.
#   - Climate is fitted once per draw on the province, so the
#     north store holds it; the south store holds the same fits.
#   - v2's 500 files are read serially from Google Drive (about
#     0.4 s each) and cached; delete the cache to re-read.
# ---

# 1. Setup ----

## 1.1 Load packages ----
library(data.table) # reading, reshaping and tests (version: 1.18.0)

## 1.2 Paths and settings ----
runs_dir <- "2_pipeline/temp_bird"
tables_dir <- "3_output/temp_bird/tables"
cache_path <- file.path(runs_dir, "v2_climate_draws.csv")
out_path <- file.path(
  tables_dir, "bird_climate_draw_comparison.csv"
)

archive_dir <- paste0(
  "G:/.shortcut-targets-by-id/17Ymt13eHfKvIiuoMl6x-Kn74Z2uVbbzS/",
  "BirdModels/Results/Archive/ClimateModels/Coefficients"
)
birds <- c("AMRO", "YEWA", "WTSP", "CCSP", "SAVS")
draws <- 1:100

versions <- c("Data 2025" = "new", "Data 2026-08" = "old")

predictor_order <- c(
  "Intercept", "MAP", "FFP", "TD", "CMD", "Easting", "Northing",
  "EastingNorthing", "Easting2", "Northing2"
)

# glm's names for the spatial terms, as exp_000 renames them
v2_names <- c(
  "(Intercept)" = "Intercept", "I(Easting^2)" = "Easting2",
  "I(Northing^2)" = "Northing2",
  "Easting:Northing" = "EastingNorthing"
)
rename_terms <- function(term) {
  renamed <- term %in% names(v2_names)
  term[renamed] <- v2_names[term[renamed]]
  term
}

# 2. Read ----

## 2.1 v2's draws ----
if (!file.exists(cache_path)) {
  if (!dir.exists(archive_dir)) {
    stop("v2 archive not reachable: ", archive_dir, call. = FALSE)
  }

  rows <- list()

  for (species in birds) {
    cat("Reading v2 climate draws:", species, "\n")

    for (draw in draws) {
      path <- file.path(
        archive_dir, species,
        sprintf("ClimateModelCoefficients_%s_%d.csv", species, draw)
      )

      if (!file.exists(path)) {
        next
      }

      x <- fread(path)
      rows[[length(rows) + 1]] <- data.table(
        species = species, boot = draw, term = x[[1]],
        coef = x$coef
      )
    }
  }

  fwrite(rbindlist(rows), cache_path)
}

v2_draws <- fread(cache_path)
v2_draws[, term := rename_terms(term)]

## 2.2 The runs' draws ----
run_draws <- rbindlist(lapply(names(versions), function(label) {
  path <- file.path(
    runs_dir, versions[[label]],
    "pipeline/bird/north/coefficients.csv"
  )

  if (!file.exists(path)) {
    stop("Not found: ", path, "; run 02_fit_old_new.R.",
         call. = FALSE)
  }

  x <- fread(path)[stage == "climate" & species %in% birds]
  x[, .(version = label, species, boot, term = rename_terms(term),
        estimate)]
}))

# 3. Compare set against set ----

## 3.1 compare_sets() ----

#' Two-Sample Comparison of a Run's Draws Against v2's
#'
#' @param run Numeric. A run's bootstrap coefficients.
#' @param target Numeric. v2's bootstrap coefficients.
#' @return A list of test statistics and differences.
#'
#' @example # Example usage of the function
#' # compare_sets(rnorm(100), rnorm(100))
compare_sets <- function(run, target) {
  run <- run[is.finite(run)]
  target <- target[is.finite(target)]

  # Ties (identical sets) make the exact tests impossible; the
  # asymptotic versions are used and their warnings silenced.
  ks <- suppressWarnings(
    stats::ks.test(run, target, exact = FALSE)
  )
  wilcox <- suppressWarnings(
    stats::wilcox.test(run, target, exact = FALSE)
  )

  # Set against set: both sorted and paired by rank, the
  # correlation behind a Q-Q plot. High when the two sets share a
  # shape; blind to a shift, which KS and Wilcoxon see.
  qq <- if (length(run) == length(target) && length(run) >= 3) {
    stats::cor.test(sort(run), sort(target))
  } else {
    NULL
  }

  half_band <- diff(
    stats::quantile(target, c(0.1, 0.9), names = FALSE)
  ) / 2
  median_gap <- stats::median(run) - stats::median(target)

  list(
    run_draws = length(run),
    target_draws = length(target),
    qq_r = if (is.null(qq)) {
      NA_real_
    } else {
      round(unname(qq$estimate), 4)
    },
    qq_p = if (is.null(qq)) NA_real_ else signif(qq$p.value, 3),
    ks_d = round(unname(ks$statistic), 3),
    ks_p = signif(ks$p.value, 3),
    wilcox_p = signif(wilcox$p.value, 3),
    median_difference = signif(median_gap, 4),
    standardized_difference = if (half_band > 0) {
      round(median_gap / half_band, 3)
    } else {
      NA_real_
    }
  )
}

## 3.2 Every predictor, species and run ----
comparison <- rbindlist(lapply(names(versions), function(label) {
  run <- run_draws[version == label]

  run[, {
    target <- v2_draws[
      species == .BY$species & term == .BY$predictor, coef
    ]
    c(list(version = label), compare_sets(estimate, target))
  }, by = .(predictor = term, species)]
}))

comparison[, predictor := factor(
  predictor, levels = predictor_order
)]
setorder(comparison, predictor, species, version)

dir.create(tables_dir, recursive = TRUE, showWarnings = FALSE)
fwrite(comparison, out_path)

# 4. Report ----
# KS D and p, one row per predictor and species, as markdown
wide <- dcast(
  comparison, predictor + species ~ version,
  value.var = c("ks_d", "ks_p")
)

cell <- function(d, p) sprintf("D = %.2f, p = %.3g", d, p)

cat("\n| Predictor | Species | 2025 vs target |",
    "2026-08 vs target |\n")
cat("| --- | --- | --- | --- |\n")
for (i in seq_len(nrow(wide))) {
  cat(sprintf(
    "| %s | %s | %s | %s |\n",
    wide$predictor[i], wide$species[i],
    cell(wide[["ks_d_Data 2025"]][i], wide[["ks_p_Data 2025"]][i]),
    cell(wide[["ks_d_Data 2026-08"]][i],
         wide[["ks_p_Data 2026-08"]][i])
  ))
}

cat("\nWrote", out_path, "\n")

# End of script ----
