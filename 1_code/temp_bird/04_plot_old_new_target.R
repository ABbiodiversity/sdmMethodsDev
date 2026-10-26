# ---
# title: Compare Bird Coefficients on Old and New Stratified Data
# author: Brendan Casey
# created: 2026-10-15
# inputs:
#   from 02_fit_old_new.R, in 2_pipeline/temp_bird/:
#     - new/out/tables/coefficient_summary.csv, fitted on v2's
#       own Stratified.Rdata (remote/birds_data_v2)
#     - old/out/tables/coefficient_summary.csv, fitted on the
#       BirdModels Data/Archive/2025 rebuild (2026-08-19)
#   from 03_read_v2_landcover.R, in 2_pipeline/temp_bird/:
#     - v2_landcover_draws.csv, v2's raw landcover coefficients
#   - the pinned v2 reference, abmiexplorer/v2_results.csv
#   - 1_code/experiments/exp_000_parity_v2/utils/parity_targets.R,
#     the parity rules the flags apply
# outputs:
#   in 3_output/temp_bird/figures/:
#     - bird_climate_old_new_target.png
#     - bird_landcover_north_old_new_target.png
#     - bird_landcover_south_old_new_target.png
#   in 3_output/temp_bird/tables/:
#     - bird_old_new_target_terms.csv, bird_old_new_summary.csv
# notes:
#   - Three stages are compared:
#     - climate: the averaged climate coefficients, against the
#       published v2 reference.
#     - landcover: the landcover glm's own coefficients (vegc,
#       wtAge, road, method...), against v2's archived per-draw
#       files. Both sides are summarized over the draws in which a
#       term was selected, since staged selection drops some
#       terms from some draws; `n` and `v2_n` count those draws.
#     - habitat: those coefficients translated onto v2's habitat
#       types, against the published v2 reference, which is what
#       exp_000 gates. In the tables only.
#   - Climate names are renamed to v2's, scored against v2's
#     province-wide fit, and v2's placeholder habitat types are
#     left out, as in exp_000.
#   - Parity is flagged with exp_000's rules, not new ones. A
#     term is at parity when v2's median is inside the run's
#     10-90% band, or within the numerical tolerance of the run's
#     median. A species and component passes when parity_verdict()
#     says so: enough terms in band, a small median standardized
#     difference and a matching band width. Negligible terms (both
#     sides shrunk to nothing) are left out of the last two, as in
#     exp_000.
#   - Terms span ~14 orders of magnitude, so each term and species
#     gets its own panel and axis, on the coefficient's own scale.
#     The axis is constrained to v2's 10-90% band plus one band
#     width either side; values beyond it are labelled.
# ---

# 1. Setup ----

## 1.1 Load packages ----
library(data.table) # joins and summaries (version: 1.18.0)
library(ggplot2) # figures (version: 3.5.x)

## 1.2 Load the parity rules ----
# exp_000's targets and verdict, so a flag here means what it
# means in the parity gate.
source(file.path(
  "1_code/experiments/exp_000_parity_v2/utils/parity_targets.R"
))
targets <- parity_targets()

## 1.3 Paths ----
runs_dir <- "2_pipeline/temp_bird"
root <- "3_output/temp_bird"
reference_path <- paste0(
  "//ABMI-DATA2/science/sdmMethodsDev/0_data/v2_results/",
  "2026-10-05/abmiexplorer/v2_results.csv"
)
v2_landcover_path <- file.path(runs_dir, "v2_landcover_draws.csv")

for (one in c("figures", "tables")) {
  dir.create(file.path(root, one), recursive = TRUE,
             showWarnings = FALSE)
}

## 1.4 Encoding ----
# Target is the reference, so it wears neutral ink rather than a
# series hue; new and old take categorical slots 1 and 2. Shapes
# repeat the identity so it never rests on colour alone.
series_colours <- c(
  "v2 target" = "#1f1f1e", "Data 2025" = "#2a78d6",
  "Data 2026-08" = "#eb6834"
)
series_shapes <- c(
  "v2 target" = 18, "Data 2025" = 16, "Data 2026-08" = 17
)

# 2. Read and join ----

## 2.1 landcover_name() ----

#' Put a Harness Landcover Term in v2's Naming
#'
#' The harmonizer suffixed columns found in both blocks - road
#' became road_veg and road_soil - so the harness's terms carry a
#' suffix v2's do not. The carried climate column is named
#' Climate in the harness and climate in v2.
#'
#' @param term Character vector of harness term names.
#' @return The names as v2 writes them.
#'
#' @example # Example usage of the function
#' # landcover_name(c("method_veg1SPM", "mWell_veg", "Climate"))
landcover_name <- function(term) {
  # No v2 term contains either suffix, so it is dropped wherever
  # it sits: mWell_veg, and method_vegeBird inside a level name
  term <- gsub("_(veg|soil)", "", term)
  term[term == "Climate"] <- "climate"
  term
}

## 2.2 read_run() ----

#' Read One Run's Bird Coefficients in v2's Term Space
#'
#' @param version Character. "new" or "old".
#' @return A data table of species, region, stage, term, the
#'   run's median, p10 and p90, and the draws holding the term.
#'
#' @example # Example usage of the function
#' # read_run("new")
read_run <- function(version) {
  path <- file.path(
    runs_dir, version, "out/tables/coefficient_summary.csv"
  )

  if (!file.exists(path)) {
    stop("Not found: ", path, "; run 02_fit_old_new.R.",
         call. = FALSE)
  }

  x <- fread(path)[
    taxon == "bird" &
      stage %in% c("climate", "habitat", "landcover")
  ]

  # glm's climate names, as exp_000 renames them
  v2_names <- c(
    "(Intercept)" = "Intercept", "I(Easting^2)" = "Easting2",
    "I(Northing^2)" = "Northing2",
    "Easting:Northing" = "EastingNorthing"
  )
  is_climate <- x$stage == "climate" & x$term %in% names(v2_names)
  x$term[is_climate] <- v2_names[x$term[is_climate]]

  is_landcover <- x$stage == "landcover"
  x$term[is_landcover] <- landcover_name(x$term[is_landcover])

  # One province-wide climate fit is stored under both regions
  x <- x[!(stage == "climate" & region == "south")]
  x[stage == "climate", region := "all"]

  x[, .(species, region, stage, term, median, p10, p90, n,
        version = version)]
}

runs <- rbind(read_run("new"), read_run("old"))

## 2.3 The targets ----

### 2.3.1 Climate and habitat: the published reference ----
reference_all <- fread(reference_path)[taxon == "bird"]
published <- reference_all[
  , .(species, region, stage, term, v2_median, v2_p10, v2_p90,
      v2_n)
]

### 2.3.2 Landcover: v2's archived draws ----
if (!file.exists(v2_landcover_path)) {
  stop("Not found: ", v2_landcover_path,
       "; run 03_read_v2_landcover.R.", call. = FALSE)
}

v2_draws <- fread(v2_landcover_path)

# Summarized as the harness summarizes: over the draws holding the
# term
v2_landcover <- v2_draws[is.finite(coef), .(
  stage = "landcover",
  v2_median = stats::median(coef),
  v2_p10 = stats::quantile(coef, 0.1, names = FALSE),
  v2_p90 = stats::quantile(coef, 0.9, names = FALSE),
  v2_n = .N
), by = .(species, region, term)]

reference <- rbind(published, v2_landcover, use.names = TRUE)

# Each term's typical size, for exp_000's negligible-term rule:
# over every bird for the published stages, over these five for
# landcover
typical <- rbind(
  as.data.table(term_scale(
    as.data.frame(reference_all), c("taxon", "stage")
  ))[, .(stage, term, typical)],
  v2_landcover[, .(
    typical = stats::quantile(abs(v2_median), 0.9, names = FALSE)
  ), by = .(stage, term)]
)

## 2.4 Join ----
# v2 fixes these habitat types at -10,000; nothing fits them
placeholders <- c("HardLin", "Water", "Bare", "SnowIce", "Mine")

joined <- merge(
  runs, reference,
  by = c("species", "region", "stage", "term")
)[!(stage == "habitat" & term %in% placeholders)]

stopifnot(nrow(joined) > 0)

# Landcover terms on one side only: a term selected in no draw
unmatched <- fsetdiff(
  unique(runs[stage == "landcover", .(species, region, term)]),
  unique(v2_landcover[, .(species, region, term)])
)
if (nrow(unmatched) > 0) {
  cat("Landcover terms in a run with no v2 counterpart:\n")
  print(unmatched)
}

joined[, version := factor(
  ifelse(version == "new", "Data 2025", "Data 2026-08"),
  levels = c("Data 2025", "Data 2026-08")
)]

# 3. Parity flags ----

## 3.1 Per term ----
# exp_000's rule: v2's median inside the run's band, or the two
# medians within numerical tolerance.
joined <- merge(joined, typical, by = c("stage", "term"),
                all.x = TRUE)
joined[, absolute_difference := abs(median - v2_median)]
joined[, in_band := v2_median >= p10 & v2_median <= p90]
joined[, within_tolerance :=
         absolute_difference <= targets$numerical_tolerance]
joined[, parity := in_band | within_tolerance]
joined[, standardized_difference := fifelse(
  p90 > p10, absolute_difference / ((p90 - p10) / 2), NA_real_
)]
joined[, band_ratio := fifelse(
  v2_p90 > v2_p10, (p90 - p10) / (v2_p90 - v2_p10), NA_real_
)]
joined[, negligible := is_negligible(median, v2_median, typical)]

## 3.2 Per species and component ----
# The verdict exp_000 gives a parity summary row.
summary_table <- joined[, {
  substantive <- !negligible
  ratio <- band_ratio[substantive]
  ratio <- ratio[is.finite(ratio) & ratio > 0]
  std_diff <- standardized_difference[is.finite(
    standardized_difference
  )]

  in_band_pct <- round(100 * mean(parity), 1)
  median_std_diff <- if (length(std_diff) > 0) {
    round(stats::median(std_diff), 3)
  } else {
    NA_real_
  }
  median_band_ratio <- if (length(ratio) > 0) {
    round(stats::median(ratio), 3)
  } else {
    NA_real_
  }

  list(
    terms = .N,
    terms_at_parity = sum(parity),
    in_band_pct = in_band_pct,
    median_standardized_difference = median_std_diff,
    median_band_ratio = median_band_ratio,
    median_abs_diff = signif(stats::median(absolute_difference), 3),
    max_abs_diff = signif(max(absolute_difference), 3),
    parity = parity_verdict(
      "median", in_band_pct, median_std_diff, median_band_ratio,
      max(absolute_difference), gated = TRUE, targets = targets
    )
  )
}, by = .(species, component = paste(region, stage), version)]

setorder(summary_table, species, component, version)

fwrite(
  joined, file.path(root, "tables/bird_old_new_target_terms.csv")
)
fwrite(
  summary_table, file.path(root, "tables/bird_old_new_summary.csv")
)
print(dcast(
  summary_table, species + component ~ version,
  value.var = c("in_band_pct", "parity")
))

# 4. Figures ----

## 4.1 to_panels() ----

#' Lay Out Old, New and Target for One Panel per Term
#'
#' Coefficients are drawn on their own scale, so each term and
#' species gets its own x axis. The axis is constrained to v2's
#' 10-90% band plus one band width either side: v2's spread stays
#' readable, and anything beyond it is pinned to the panel edge
#' and labelled with its real value.
#'
#' @param data A data table of joined rows for one figure.
#' @param term_levels Character. Terms in display order.
#' @return A list of the plotting rows and each panel's extent.
#'
#' @example # Example usage of the function
#' # to_panels(joined[stage == "climate"], climate_terms)
to_panels <- function(data, term_levels) {
  x <- copy(data)

  # Step 1: One panel per term and species, every combination
  # kept, so each row is a term and each column a species
  species_levels <- sort(unique(x$species))
  term_levels <- term_levels[term_levels %in% x$term]
  panel_levels <- as.vector(t(outer(
    term_levels, species_levels, paste, sep = "  |  "
  )))
  panel_of <- function(term, species) {
    factor(paste(term, species, sep = "  |  "), levels = panel_levels)
  }

  # Step 2: The axis for each panel, from v2's band. A band of no
  # width (a term v2 fixed) borrows a tenth of the target's size.
  limits <- unique(x[, .(term, species, v2_median, v2_p10, v2_p90)])
  limits[, width := v2_p90 - v2_p10]
  limits[width <= 0 | !is.finite(width),
         width := pmax(abs(v2_median) * 0.1, 1e-12)]
  limits[, `:=`(lo = v2_p10 - width, hi = v2_p90 + width)]

  # Step 3: Long rows, target first, then new and old
  target <- limits[, .(
    term, species, series = "v2 target", median = v2_median,
    p10 = v2_p10, p90 = v2_p90
  )]
  runs <- x[, .(
    term, species, series = as.character(version), median, p10, p90
  )]
  rows <- rbind(target, runs)
  rows <- merge(rows, limits[, .(term, species, lo, hi)],
                by = c("term", "species"))

  # Step 4: Pin anything beyond the axis to its edge, and label it
  rows[, off_scale := median < lo | median > hi]
  rows[, label := fifelse(
    off_scale, formatC(median, digits = 3, format = "g"),
    NA_character_
  )]
  for (column in c("median", "p10", "p90")) {
    set(rows, j = column,
        value = pmin(pmax(rows[[column]], rows$lo), rows$hi))
  }

  rows[, panel := panel_of(term, species)]
  rows[, series := factor(
    series, levels = rev(c("v2 target", "Data 2025", "Data 2026-08"))
  )]

  extent <- melt(
    limits[, .(term, species, lo, hi)],
    id.vars = c("term", "species"), value.name = "x"
  )
  extent[, panel := panel_of(term, species)]

  list(rows = rows, extent = extent, ncol = length(species_levels))
}

## 4.2 panel_plot() ----

#' Draw Old, New and Target Coefficients, One Panel per Term
#'
#' @param panels A list from to_panels().
#' @param title,subtitle Character.
#' @return A ggplot.
#'
#' @example # Example usage of the function
#' # panel_plot(to_panels(rows, terms), "Title", "Subtitle")
panel_plot <- function(panels, title, subtitle) {
  ggplot(panels$rows, aes(y = series)) +
    geom_blank(
      data = panels$extent, aes(x = x), inherit.aes = FALSE
    ) +
    geom_linerange(
      aes(xmin = p10, xmax = p90, colour = series),
      linewidth = 0.6
    ) +
    geom_point(
      aes(x = median, colour = series, shape = series), size = 1.8
    ) +
    geom_text(
      aes(x = median, label = label, colour = series,
          hjust = ifelse(off_scale & median >= hi, 1, 0)),
      vjust = -0.8, size = 2.3, show.legend = FALSE, na.rm = TRUE
    ) +
    facet_wrap(
      ~panel, ncol = panels$ncol, scales = "free_x", drop = FALSE
    ) +
    scale_colour_manual(
      values = series_colours, name = NULL,
      breaks = names(series_colours)
    ) +
    scale_shape_manual(
      values = series_shapes, name = NULL,
      breaks = names(series_shapes)
    ) +
    scale_x_continuous(n.breaks = 3) +
    labs(title = title, subtitle = subtitle, x = "Coefficient",
         y = NULL) +
    theme_minimal(base_size = 9) +
    theme(
      panel.grid.minor = element_blank(),
      panel.grid.major.y = element_blank(),
      panel.grid.major.x = element_line(colour = "#ecebe7"),
      axis.text.y = element_blank(),
      axis.text.x = element_text(size = 6.5, colour = "#55544f"),
      legend.position = "top",
      plot.background = element_rect(fill = "#fcfcfb", colour = NA),
      strip.text = element_text(size = 7.5, hjust = 0),
      panel.spacing.x = unit(1.6, "lines"),
      plot.margin = margin(8, 16, 8, 8)
    )
}

caption <- "Median and 10-90% range of 100 bootstrap fits."

## 4.3 Climate ----
climate_terms <- c(
  "Intercept", "MAP", "FFP", "TD", "CMD", "Easting", "Northing",
  "EastingNorthing", "Easting2", "Northing2"
)
climate_panels <- to_panels(joined[stage == "climate"], climate_terms)

ggsave(
  file.path(root, "figures/bird_climate_old_new_target.png"),
  panel_plot(
    climate_panels,
    "Bootstrapped climate coefficients: bird data 2025 vs 2026-08",
    caption
  ),
  width = 13, height = 1.0 * length(climate_terms) + 1.5,
  dpi = 200, limitsize = FALSE
)

## 4.4 Climate variables only ----
# The four climate variables, without the intercept or the
# spatial trend terms, which trade off against each other.
climate_variables <- c("MAP", "FFP", "TD", "CMD")
variable_panels <- to_panels(
  joined[stage == "climate" & term %in% climate_variables],
  climate_variables
)

ggsave(
  file.path(
    root, "figures/bird_climate_variables_old_new_target.png"
  ),
  panel_plot(
    variable_panels,
    paste(
      "Bootstrapped climate variable coefficients:",
      "bird data 2025 vs 2026-08"
    ),
    caption
  ),
  width = 13, height = 1.0 * length(climate_variables) + 1.5,
  dpi = 200
)

## 4.5 First five landcover variables ----
# The first five habitat predictors in v2's model order, per
# region, without the intercept or the carried climate term.
first_landcover <- lapply(c(north = "north", south = "south"),
                          function(one_region) {
  terms <- unique(v2_draws[region == one_region, term])
  head(setdiff(terms, c("(Intercept)", "climate")), 5)
})

first_rows <- joined[
  stage == "landcover" & (
    (region == "north" & term %in% first_landcover$north) |
      (region == "south" & term %in% first_landcover$south)
  )
]
first_terms <- c(first_landcover$north, first_landcover$south)

ggsave(
  file.path(
    root, "figures/bird_landcover_first5_old_new_target.png"
  ),
  panel_plot(
    to_panels(first_rows, first_terms),
    paste(
      "Bootstrapped landcover coefficients, first five per region:",
      "bird data 2025 vs 2026-08"
    ),
    paste(caption, "North: vegc terms; south: soilc terms.")
  ),
  width = 13, height = 1.0 * length(first_terms) + 1.5,
  dpi = 200
)

## 4.6 Landcover ----
# The landcover glm's own coefficients, one figure per region, in
# the order v2's models list them.
landcover_terms <- unique(c(
  unique(v2_draws$term), unique(joined[stage == "landcover", term])
))

for (one_region in c("north", "south")) {
  rows <- joined[stage == "landcover" & region == one_region]
  panels <- to_panels(rows, landcover_terms)
  n_terms <- length(unique(rows$term))

  ggsave(
    file.path(root, sprintf(
      "figures/bird_landcover_%s_old_new_target.png", one_region
    )),
    panel_plot(
      panels,
      paste(
        "Bootstrapped", one_region,
        "landcover coefficients: bird data 2025 vs 2026-08"
      ),
      paste(caption, "Only draws where the term was selected.")
    ),
    width = 13, height = 1.0 * n_terms + 1.5,
    dpi = 150, limitsize = FALSE
  )
}

# Figures this version replaces would otherwise linger
for (old_figure in c(
  "bird_habitat_old_new_target.png",
  "bird_landcover_old_new_target.png"
)) {
  old_path <- file.path(root, "figures", old_figure)
  if (file.exists(old_path)) {
    file.remove(old_path)
  }
}

cat("Wrote figures and tables to", root, "\n")

# End of script ----
