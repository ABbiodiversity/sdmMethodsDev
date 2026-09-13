# ---
# title: Build the Experiment 000 Report
# author: Brendan Casey
# created: 2026-09-09
# inputs:
#   in out_dir/tables/:
#     - coverage.csv, metric_summary.csv, parity_summary.csv
# outputs:
#   in out_dir/:
#     - report.md
# notes:
#   - States what the gate covered and what it found. Coverage is
#     stated first and explicitly, because the gate currently
#     reaches the climate stage only and a report that led with a
#     parity percentage would imply more than was tested.
#   - Written on every run, so a partial run still leaves a
#     legible record of what it was.
#   - Expects exp_id, data_dir, pipeline_dir and out_dir from
#     run.R.
# ---

# 1. Setup ----

## 1.1 Resolve paths ----
tables_dir <- file.path(out_dir, "tables")
report_file <- file.path(out_dir, "report.md")

read_table <- function(name) {
  path <- file.path(tables_dir, name)

  if (!file.exists(path)) {
    return(NULL)
  }

  as.data.frame(data.table::fread(path))
}

coverage <- read_table("coverage.csv")
metric_summary <- read_table("metric_summary.csv")
parity_summary <- read_table("parity_summary.csv")

# 2. Assemble ----

## 2.1 Helper ----

#' Render a Data Frame as a Markdown Table
#'
#' @param x A data frame, or NULL.
#' @param empty Character. What to say when there is nothing.
#' @return A character vector of markdown lines.
#'
#' @example # Example usage of the function
#' # markdown_table(coverage)
markdown_table <- function(x, empty = "_Nothing recorded._") {
  if (is.null(x) || nrow(x) == 0) {
    return(empty)
  }

  header <- paste("|", paste(names(x), collapse = " | "), "|")
  rule <- paste(
    "|", paste(rep("---", ncol(x)), collapse = " | "), "|"
  )

  rows <- apply(x, 1, function(row) {
    paste("|", paste(row, collapse = " | "), "|")
  })

  c(header, rule, rows)
}

## 2.2 Write the report ----
lines <- c(
  paste0("# ", exp_id),
  "",
  paste0("Generated ", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
  "",
  "## What this gate covers",
  "",
  "| Taxon | Climate | Habitat |",
  "| --- | --- | --- |",
  "| Plants | v2 58-model set | fitted, less the age splines |",
  "| Birds | v2 8-model set | v2 staged landcover groups |",
  "| Mammals | 4 of 9 models (`CMD` missing) | not reproduced |",
  "",
  "For plants, v2 overwrites 45 of the 87 vegetation effects with",
  "GAM splines over stand age, and settles the cutblock age",
  "classes 3 and 4 by a convergence step. Neither is implemented,",
  "so those terms will not match and are reported separately:",
  "`reachable_in_band_pct` is the share of the terms the harness",
  "actually fits, and is the number to read the gate on.",
  "",
  "Parity here is **distributional, not numerical**. v2 seeds no",
  "random draw, so two v2 runs give different coefficients;",
  "matching numbers is not something v2 can do even against",
  "itself. Each term is scored on whether the v2 value falls",
  "inside this run's 10th-to-90th percentile band across draws.",
  "",
  "## What ran",
  "",
  markdown_table(coverage),
  "",
  "## Climate-stage parity",
  "",
  markdown_table(
    parity_summary,
    "_No comparison produced. See the notes below._"
  ),
  "",
  "## Model fit",
  "",
  if (is.null(metric_summary)) {
    "_No metrics recorded._"
  } else {
    auc <- metric_summary[metric_summary$metric == "auc", ]

    if (nrow(auc) == 0) {
      "_No AUC recorded._"
    } else {
      markdown_table(do.call(rbind, lapply(
        split(auc, list(auc$taxon, auc$region), drop = TRUE),
        function(block) {
          data.frame(
            taxon = block$taxon[1],
            region = block$region[1],
            species = nrow(block),
            median_auc = round(
              stats::median(block$median, na.rm = TRUE), 3
            ),
            stringsAsFactors = FALSE
          )
        }
      )))
    }
  },
  "",
  "## Known gaps in the reference",
  "",
  "- **Bryophytes have no usable v2 reference.** Every species",
  "  and every draw in `bryophyte-species-models.Rdata` is an",
  "  error object: `could not find function \"model.avg\"`. MuMIn",
  "  was not available to the cluster workers on the run that",
  "  produced it. Lichens, mites and vascular plants are",
  "  complete. That file has to be re-run before bryophytes can",
  "  be gated.",
  "- **No bird reference is reachable**, so birds cannot be",
  "  compared, only run.",
  "- **Mammal climate has no bootstrap distribution.** The v2",
  "  mammal climate pipeline fits once and averages by AICc",
  "  weight, so its reference is a single value per term and the",
  "  band test is one-sided.",
  "",
  "## Before this gate can be closed",
  "",
  "1. Agree a numeric parity target per taxon. Without one,",
  "   \"did it pass\" has no answer.",
  "2. Re-run the bryophyte v2 models.",
  "3. Source `CMD` for mammals, so their climate stage can fit",
  "   the full nine-model set rather than four of them.",
  "4. Reproduce the habitat stages.",
  ""
)

writeLines(lines, report_file)

cat("Wrote ", report_file, "\n", sep = "")

# End of script ----
