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
#   - The result stores are large and gitignored. This writes the
#     one committed artefact of a run: what it was configured to
#     do, what it produced, and what it scored. When the stores
#     are gone, this is what is left.
#   - The format is built to be diffed. Two runs of the same
#     configuration should produce byte-identical bodies, so any
#     difference in a diff is a real difference in the run.
#     Three things follow from that and are not style choices:
#
#     1. Everything that changes between identical runs - the
#        timestamp, the host, the elapsed time - is confined to
#        one Provenance section at the top, and can be dropped
#        with `provenance = FALSE`. Interleaved, it would make
#        every diff non-empty and therefore useless.
#     2. Numbers are formatted to a fixed number of decimals.
#        Unformatted doubles differ in the last place between
#        runs that agree, which reads as a difference.
#     3. Rows and columns are ordered deterministically, and a
#        missing value is written as "-" rather than dropped, so
#        tables stay aligned and a diff points at the value that
#        changed rather than at a row that moved.
#   - What the format guarantees is that identical results
#     render identically. It cannot make an unseeded run
#     reproduce: with `seed = NULL` (v2's behaviour) two runs of
#     the same configuration draw different bootstrap samples
#     and their Metrics sections genuinely differ. With a seed -
#     the default - and with the birds' stored draws, every
#     section is exact.
#   - File sizes are deliberately not recorded. They vary by a
#     few bytes between runs that agree, which is noise in a
#     document whose purpose is comparison. Row counts carry the
#     same information and are stable.
#   - "Record" rather than "manifest": a manifest is an inventory
#     of contents, and this leads with results. The inventory is
#     one section of it. See the repository discussion in
#     docs/framework_design.md.
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

  # Decided by type rather than by value. Choosing the number
  # of decimals from whether the values happen to be whole
  # would let the same column render as "1" in one run and
  # "1.0000" in the next, which is a formatting change showing
  # up as a result change.
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
#' @param df A data frame. Zero rows yields a stated absence
#'   rather than an empty table, so the section still appears
#'   and the diff shows what changed.
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
#'   FALSE gives a body that is byte-identical between two runs
#'   of the same configuration, which is what makes a diff
#'   between experiments readable.
#' @param digits Integer. Decimal places for every number.
#' @param collected The result of collect_results() for this
#'   pipeline directory, or NULL to read the stores here. Passing
#'   it saves reading every store a second time.
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
  # Everything that differs between two identical runs lives
  # here and nowhere else, so the rest of the file diffs clean.
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
  # The inventory. Row counts rather than file sizes: both say
  # what was produced, only one is stable between runs.
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
  # One row per run, region and metric, pooled over species and
  # draws, ordered so that two records line up row for row.
  metric_summary <- NULL

  if (!is.null(collected$metrics) && nrow(collected$metrics) > 0) {
    pooled <- as.data.table(collected$metrics)[
      is.finite(value),
      list(
        n = .N,
        median = stats::median(value),
        p10 = stats::quantile(value, 0.1, names = FALSE),
        p90 = stats::quantile(value, 0.9, names = FALSE)
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
  # A .txt record drops the table pipes rather than the tables,
  # so the same content survives in a plain-text reader.
  if (grepl("[.]txt$", out_file, ignore.case = TRUE)) {
    # Dividers go first: once the pipes are gone the line is
    # no longer recognisable as a divider.
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
