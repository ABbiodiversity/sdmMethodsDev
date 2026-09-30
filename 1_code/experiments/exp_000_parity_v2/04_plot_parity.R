# ---
# title: Plot Parity Against v2 (Experiment 000)
# author: Brendan Casey
# created: 2026-09-30
# inputs:
#   in out_dir/tables/:
#     - parity_terms.csv, from 02_compare_to_v2.R
# outputs:
#   in out_dir/figures/:
#     - parity_<taxon>.png, one per taxon
#     - parity_mean.png, every taxon averaged, one facet each
# notes:
#   - One figure per taxon. Each panel is a stage and region (and,
#     for mammals, a hurdle part) for one species; each row a term.
#     v2 and exp_000 are drawn in different colours as a median and
#     a 10th-to-90th percentile bar, the same summaries the gate
#     compares.
#   - Intervals, not densities: v2's reference keeps only the
#     median and the 10th and 90th percentiles of its draws, so its
#     full distribution cannot be drawn. The run's is summarized
#     the same way, so the two are read alike.
#   - Terms span 1e-144 to 1e2, so no single axis holds them. Each
#     term is put on its own scale, relative to v2: 0 is v2's
#     median and one unit is half v2's 10-90% band, the scale the
#     gate's standardized difference uses. Where v2 fitted once and
#     has no band (the mammal hurdle), one unit is half the run's
#     band instead, and v2 is drawn as a point. There the gate
#     compares the run's first draw with v2's single fit, so that
#     draw is drawn too, as its own colour.
#   - Values beyond +/- 4 units are drawn at the panel's edge, so
#     one far-off term does not flatten the rest. Terms the gate
#     cannot reach, or with no band to scale by, are left out and
#     counted in the caption.
#   - parity_mean.png averages the same scaled values over every
#     species and term, one facet per taxon (or per group; section
#     1.4), one row per stage and region.
#   - Expects out_dir from run.R. Can also be run on its own from
#     the repository root after 02_compare_to_v2.R.
# ---

# 1. Setup ----

## 1.1 Load packages ----
library(data.table) # reading and reshaping tables (version: 1.18.0)
library(ggplot2) # plotting (version: 4.0.3)

## 1.2 Resolve paths ----
if (!exists("out_dir")) {
  out_dir <- file.path(getwd(), "3_output", "exp_000_parity_v2")
}

terms_path <- file.path(out_dir, "tables", "parity_terms.csv")
figures_dir <- file.path(out_dir, "figures")

if (!file.exists(terms_path)) {
  stop(
    "parity_terms.csv not found; run 02_compare_to_v2.R first:\n  ",
    terms_path,
    call. = FALSE
  )
}

dir.create(figures_dir, recursive = TRUE, showWarnings = FALSE)

## 1.3 Import data ----
parity_terms <- fread(terms_path)

## 1.4 Choose the mean figure's facets ----
# "taxon" gives one facet per taxon; "group" pools the four plant
# taxa into one facet beside mammals and birds.
mean_facet <- "taxon"

if (!mean_facet %in% c("taxon", "group")) {
  stop("mean_facet must be \"taxon\" or \"group\".", call. = FALSE)
}

# 2. Put each term on v2's scale ----
# Input: one row per taxon, region, stage, part, species and term,
# with the run's and v2's median and 10th and 90th percentiles.
# Output: plot_data, one row per term and source, in v2 units.

## 2.1 Choose the unit per term ----
# Half v2's band where it has one; otherwise half the run's.
axis_limit <- 4

parity_terms[, `:=`(
  v2_half = (v2_p90 - v2_p10) / 2,
  run_half = (p90 - p10) / 2
)]
parity_terms[, unit := fifelse(
  is.finite(v2_half) & v2_half > 0, v2_half, run_half
)]

plottable <- parity_terms[
  reachable & is.finite(v2_median) & is.finite(median) &
    is.finite(unit) & unit > 0
]

## 2.2 Label panels ----
# A mammal row also names its hurdle part, which v2 reports
# separately.
plottable[, panel := paste(stage, region, sep = " / ")]
plottable[taxon == "mammal", panel := paste(panel, part, sep = " / ")]

## 2.3 Rescale and stack the two sources ----
scaled <- function(x, data) (x - data$v2_median) / data$unit

plot_data <- rbind(
  plottable[, .(
    taxon, group, panel, species, term,
    source = "v2",
    centre = 0,
    low = scaled(v2_p10, .SD),
    high = scaled(v2_p90, .SD)
  )],
  plottable[, .(
    taxon, group, panel, species, term,
    source = "exp_000",
    centre = scaled(median, .SD),
    low = scaled(p10, .SD),
    high = scaled(p90, .SD)
  )],
  # Where v2 fitted once, the gate compares the run's first draw,
  # not its median; drawn as a point so the test itself is seen.
  plottable[comparison == "iteration 1", .(
    taxon, group, panel, species, term,
    source = "exp_000 iteration 1",
    centre = scaled(boot1, .SD),
    low = NA_real_,
    high = NA_real_
  )]
)

plot_data[, source := factor(
  source, levels = c("v2", "exp_000", "exp_000 iteration 1")
)]

# Past the axis limit, drawn at the edge rather than dropped
clamp <- function(x) pmin(pmax(x, -axis_limit), axis_limit)
plot_data[, `:=`(
  clipped = abs(centre) > axis_limit,
  centre = clamp(centre),
  low = clamp(low),
  high = clamp(high)
)]

# 3. Plot ----

#' Plot One Taxon's Parity Against v2
#'
#' Draws each term's median and 10-90% band for v2 and the run,
#' in v2 units, faceted by panel and species.
#'
#' @param data data.table. plot_data rows for one taxon.
#' @param dropped Integer. Terms left out, for the caption.
#' @param taxon Character. The taxon, for the title.
#' @return A ggplot object.
#'
#' @example # Example usage of the function
#' # plot_parity_taxon(plot_data[taxon == "lichen"], 0L, "lichen")
plot_parity_taxon <- function(data, dropped, taxon) {
  # Terms top to bottom in the order the table lists them
  data <- copy(data)
  data[, term := factor(term, levels = rev(unique(term)))]

  dodge <- position_dodge(width = 0.6)

  ggplot(data, aes(y = term, colour = source)) +
    geom_vline(xintercept = 0, colour = "grey70") +
    geom_vline(
      xintercept = c(-1, 1),
      colour = "grey85", linetype = "dashed"
    ) +
    geom_linerange(
      aes(xmin = low, xmax = high),
      position = dodge, na.rm = TRUE
    ) +
    geom_point(
      aes(x = centre, shape = clipped),
      position = dodge, size = 1.4
    ) +
    scale_colour_manual(
      values = c(
        v2 = "#0072B2", exp_000 = "#D55E00",
        `exp_000 iteration 1` = "#009E73"
      ),
      drop = TRUE
    ) +
    scale_shape_manual(
      values = c(`FALSE` = 16, `TRUE` = 4),
      guide = "none"
    ) +
    scale_x_continuous(limits = c(-axis_limit, axis_limit)) +
    facet_grid(
      panel ~ species,
      scales = "free_y", space = "free_y"
    ) +
    labs(
      title = paste0("Parity against v2: ", taxon),
      subtitle = paste(
        "Median (point) and 10th-90th percentile (bar) of each",
        "term, in v2 units:\n0 is v2's median; +/- 1 is half",
        "v2's band (the run's band where v2 fitted once).",
        "\nAn x marks a median beyond the axis, drawn at its edge."
      ),
      caption = paste0(
        "Terms left out (unreachable, or no band to scale by): ",
        dropped
      ),
      x = "Difference from v2's median, in half-band units",
      y = NULL, colour = NULL
    ) +
    theme_bw(base_size = 9) +
    theme(
      legend.position = "top",
      strip.text.y = element_text(angle = 0),
      axis.text.y = element_text(size = 6)
    )
}

## 3.1 Write one figure per taxon ----
# Height follows the number of rows, so habitat stages with a
# hundred terms stay legible; capped at ggsave's 50-inch limit.
for (one_taxon in sort(unique(plot_data$taxon))) {
  taxon_data <- plot_data[taxon == one_taxon]
  dropped <- nrow(parity_terms[taxon == one_taxon]) -
    nrow(plottable[taxon == one_taxon])

  rows <- uniqueN(taxon_data[, .(panel, term)])
  height <- min(49, 2 + rows * 0.14)
  width <- 3 + 3 * uniqueN(taxon_data$species)

  figure <- plot_parity_taxon(taxon_data, dropped, one_taxon)
  out_file <- file.path(
    figures_dir, paste0("parity_", one_taxon, ".png")
  )

  ggsave(
    out_file, figure,
    width = width, height = height, dpi = 150, limitsize = FALSE
  )

  cat("Parity figure: ", out_file, "\n", sep = "")
}

# 4. Plot mean parity per taxon ----
# One figure, one facet per taxon (or group), each row a stage and
# region. Input: plot_data. Output: parity_mean.png.
#
# The per-term values are averaged over every species and term in
# the row, still in v2 units, so v2 sits at 0 and its bar is its
# mean band. The averages use the clamped values, so a term past
# the axis counts as +/- 4, not as its full distance.
#
# A signed mean shows bias but lets a +2 and a -2 cancel, so each
# row is also labelled with the mean absolute difference of the
# run's median from v2's, and the share of terms whose v2 median
# lies inside the run's band: the gate's first two measures.

## 4.1 Average per facet, row and source ----
plot_data[, facet := get(mean_facet)]

mean_data <- plot_data[, .(
  centre = mean(centre),
  low = mean(low, na.rm = TRUE),
  high = mean(high, na.rm = TRUE),
  terms = .N
), by = .(facet, panel, source)]

# Where every value is NA (the iteration-1 point) mean() is NaN
mean_data[!is.finite(low), low := NA_real_]
mean_data[!is.finite(high), high := NA_real_]

mean_labels <- plot_data[source == "exp_000", .(
  label = sprintf(
    "|d| %.2f, in band %.0f%%, %d terms",
    mean(abs(centre)),
    100 * mean(low <= 0 & high >= 0),
    .N
  )
), by = .(facet, panel)]

# The measures go in the row's axis label, clear of the bars
mean_data <- merge(mean_data, mean_labels, by = c("facet", "panel"))
mean_data[, row := paste0(panel, "\n", label)]

## 4.2 Draw ----

#' Plot Mean Parity Against v2 by Taxon
#'
#' Draws, per facet and stage, the mean scaled median and mean
#' 10-90% band of v2 and the run; each row's label carries the
#' mean absolute difference and the in-band share.
#'
#' @param data data.table. mean_data: facet, panel, row, source,
#'   centre, low, high.
#' @return A ggplot object.
#'
#' @example # Example usage of the function
#' # plot_parity_mean(mean_data)
plot_parity_mean <- function(data) {
  # Rows top to bottom: climate before habitat, north before south
  data <- copy(data)
  data[, row := factor(row, levels = rev(sort(unique(row))))]

  dodge <- position_dodge(width = 0.5)

  ggplot(data, aes(y = row, colour = source)) +
    geom_vline(xintercept = 0, colour = "grey70") +
    geom_vline(
      xintercept = c(-1, 1),
      colour = "grey85", linetype = "dashed"
    ) +
    geom_linerange(
      aes(xmin = low, xmax = high),
      position = dodge, linewidth = 0.8, na.rm = TRUE
    ) +
    geom_point(aes(x = centre), position = dodge, size = 2) +
    scale_colour_manual(
      values = c(
        v2 = "#0072B2", exp_000 = "#D55E00",
        `exp_000 iteration 1` = "#009E73"
      )
    ) +
    scale_x_continuous(limits = c(-axis_limit, axis_limit)) +
    facet_wrap(~facet, scales = "free_y", ncol = 2) +
    labs(
      title = "Mean parity against v2",
      subtitle = paste(
        "Mean over species and terms of each term's median (point)",
        "and 10th-90th percentile (bar),\nin v2 units: 0 is v2's",
        "median; +/- 1 is half v2's band (the run's band where v2",
        "fitted once).\n|d|: mean absolute difference of the run's",
        "median from v2's. In band: v2's median inside the run's",
        "band."
      ),
      x = "Difference from v2's median, in half-band units",
      y = NULL, colour = NULL
    ) +
    theme_bw(base_size = 9) +
    theme(legend.position = "top")
}

mean_file <- file.path(figures_dir, "parity_mean.png")
mean_rows <- max(mean_data[, uniqueN(panel), by = facet]$V1)
mean_facets <- uniqueN(mean_data$facet)

ggsave(
  mean_file, plot_parity_mean(mean_data),
  width = 10,
  height = 2 + ceiling(mean_facets / 2) * (0.6 + 0.55 * mean_rows),
  dpi = 150
)

cat("Parity figure: ", mean_file, "\n", sep = "")

# End of script ----
