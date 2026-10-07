# ---
# title: Write a Comparable Record of One Run
# author: Brendan Casey
# created: 2026-09-13
# inputs:
#   - a pipeline directory holding result stores, laid out as
#     <pipeline_dir>/<taxon>/<region>/
# outputs:
#   - one Markdown or plain-text file per run
# notes:
#   - The committed record of a run (configuration, coverage,
#     metrics); the result stores themselves are gitignored.
#   - Built to diff: identical results render byte-identically.
#     Volatile fields sit only in the Provenance section
#     (`provenance = FALSE` drops it), numbers use fixed decimals,
#     rows are ordered deterministically, and missing values are
#     "-". An unseeded run (`seed = NULL`) still differs between
#     runs.
# ---

# 1. Setup ----

## 1.1 Load packages ----
library(data.table) # result store reading (version: 1.16.4)

# 2. Formatting helpers ----

## 2.1 fmt_value() ----

#' Format One Value for a Record Table
#'
#' Fixed decimals for numbers and "-" for anything missing, so
#' that two runs which agree produce identical text.
#'
#' @param x A value of any type.
#' @param digits Integer. Decimal places for numeric values.
#' @return A character vector.
#'
#' @example # Example usage of the function
#' # fmt_value(c(0.68901, NA), digits = 4)
fmt_value <- function(x, digits = 4L) {
  if (is.null(x) || length(x) == 0) {
    return("-")
  }

  # Format by type, not value, so a column never flips between
  # "1" and "1.0000" across runs
  if (is.integer(x)) {
    out <- formatC(x, format = "d")
    out[is.na(x)] <- "-"

    return(out)
  }

  if (is.numeric(x)) {
    out <- formatC(
      x, format = "f", digits = digits, drop0trailing = FALSE
    )
    out[!is.finite(x)] <- "-"

    return(out)
  }

  out <- as.character(x)
  out[is.na(out) | !nzchar(trimws(out))] <- "-"

  out
}

## 2.2 md_table() ----

#' Render a Data Frame as a Markdown Table
#'
#' @param df A data frame. Zero rows renders as "_None._" so the
#'   section still appears in a diff.
#' @param digits Integer. Decimal places for numeric columns.
#' @return A character vector of lines.
#'
#' @example # Example usage of the function
#' # md_table(data.frame(taxon = "bird", auc = 0.689))
md_table <- function(df, digits = 4L) {
  if (is.null(df) || nrow(df) == 0) {
    return("_None._")
  }

  cells <- lapply(df, fmt_value, digits = digits)
  names(cells) <- names(df)

  header <- paste("|", paste(names(df), collapse = " | "), "|")
  divider <- paste(
    "|", paste(rep("---", length(df)), collapse = " | "), "|"
  )

  body <- vapply(
    seq_len(nrow(df)),
    function(i) {
      paste(
        "|",
        paste(vapply(cells, function(x) x[i], character(1)),
              collapse = " | "),
        "|"
      )
    },
    character(1)
  )

  c(header, divider, body)
}

## 2.3 kv_lines() ----

#' Render a Named List as Stable Key-Value Lines
#'
#' Sorted by name, so that adding a setting does not reorder the
#' ones already there.
#'
#' @param values A named list.
#' @param digits Integer. Decimal places for numeric values.
#' @return A character vector of lines.
#'
#' @example # Example usage of the function
#' # kv_lines(list(engine = "glm", draws = 100))
kv_lines <- function(values, digits = 4L) {
  if (is.null(values) || length(values) == 0) {
    return("_None recorded._")
  }

  values <- values[order(names(values))]

  vapply(
    names(values),
    function(name) {
      value <- values[[name]]

      rendered <- if (length(value) > 1) {
        paste(fmt_value(value, digits), collapse = ", ")
      } else {
        fmt_value(value, digits)
      }

      paste0("- **", name, "**: ", rendered)
    },
    character(1)
  )
}

# 3. run_record() ----

#' Write the Committed Record of One Run
#'
#' @param pipeline_dir Character. Where the result stores are.
#' @param out_file Character. Path to write. The extension sets
#'   the format: ".txt" strips the Markdown table pipes, anything
#'   else writes Markdown.
#' @param exp_id Character. The experiment identifier.
#' @param config Named list. What the run was configured to do -
#'   taxa, species count, draws, engines, selection rules.
#'   Rendered sorted by name.
#' @param provenance Logical. Include the volatile section.
#'   FALSE gives a body byte-identical across identical runs.
#' @param digits Integer. Decimal places for every number.
#' @param collected collect_results() output for this pipeline
#'   directory, or NULL to read the stores here.
#' @return The path written, invisibly.
#'
#' @example # Example usage of the function
#' # run_record("2_pipeline/exp_000_parity_v2",
#' #            "3_output/exp_000_parity_v2/run_record.md",
#' #            exp_id = "exp_000_parity_v2",
#' #            config = list(draws = 100))
run_record <- function(
  pipeline_dir,
  out_file,
  exp_id,
  config = list(),
  provenance = TRUE,
  digits = 4L,
  collected = NULL
) {
  if (is.null(collected)) {
    collected <- collect_results(pipeline_dir)
  }

  lines <- c(
    paste("# Run record:", exp_id),
    "",
    paste0(
      "Written by `run_record()`. The result stores this ",
      "describes are gitignored; this file is what remains."
    ),
    ""
  )

  ## 3.1 Provenance ----
  if (provenance) {
    commit <- tryCatch(
      system2("git", c("rev-parse", "--short", "HEAD"),
              stdout = TRUE, stderr = FALSE),
      error = function(e) NA_character_,
      warning = function(e) NA_character_
    )

    lines <- c(
      lines,
      "## Provenance",
      "",
      "_Volatile. Excluded from cross-run comparison._",
      "",
      kv_lines(list(
        written_at = format(
          Sys.time(), "%Y-%m-%d %H:%M:%S", tz = "UTC"
        ),
        git_commit = if (length(commit) == 1) commit else "-",
        r_version = paste(
          R.version$major, R.version$minor, sep = "."
        ),
        pipeline_dir = pipeline_dir
      ), digits),
      ""
    )
  }

  ## 3.2 Configuration ----
  lines <- c(
    lines, "## Configuration", "", kv_lines(config, digits), ""
  )

  ## 3.3 Coverage and artefacts ----
  # Row counts, not file sizes: sizes vary between identical runs
  coverage <- collected$store_rows

  if (!is.null(coverage)) {
    names(coverage)[names(coverage) == "run"] <- "taxon"
    coverage <- coverage[order(coverage$taxon, coverage$region), ]
    coverage$coefficient_rows <- as.integer(coverage$coefficient_rows)
    coverage$metric_rows <- as.integer(coverage$metric_rows)
    coverage$grid_rows <- as.integer(coverage$grid_rows)
    coverage$species <- as.integer(coverage$species)
    coverage$draws <- as.integer(coverage$draws)
  }

  lines <- c(
    lines, "## Coverage", "",
    md_table(coverage, digits), ""
  )

  ## 3.4 Metrics ----
  # Pooled over species and draws
  metric_summary <- NULL

  if (!is.null(collected$metrics) && nrow(collected$metrics) > 0) {
    pooled <- as.data.table(collected$metrics)[
      is.finite(value),
      list(
        n = .N,
        median = stats::median(value),
        p10 = stats::quantile(value, 0.1, names = FALSE),
        p90 = stats::quantile(value, 0.9, names = FALSE),
        mean = mean(value),
        sd = if (.N < 2) NA_real_ else stats::sd(value)
      ),
      by = list(taxon = run, region, metric)
    ]
    setorder(pooled, taxon, region, metric)
    metric_summary <- as.data.frame(pooled)
  }

  lines <- c(
    lines, "## Metrics", "",
    md_table(metric_summary, digits), ""
  )

  ## 3.5 Write ----
  if (grepl("[.]txt$", out_file, ignore.case = TRUE)) {
    # Drop dividers before the pipes, while still recognizable
    lines <- lines[!grepl("^[|] --- ([|] --- )*[|]$", lines)]
    lines <- gsub("^[|] | [|]$", "", lines)
    lines <- gsub(" [|] ", "  ", lines)
  }

  dir.create(
    dirname(out_file), recursive = TRUE, showWarnings = FALSE
  )

  writeLines(lines, out_file)

  invisible(out_file)
}

# End of script ----
