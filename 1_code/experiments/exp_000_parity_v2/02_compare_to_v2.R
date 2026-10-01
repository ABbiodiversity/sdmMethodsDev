# ---
# title: Compare Against the v2.0 Reference (Experiment 000)
# author: Brendan Casey
# created: 2026-09-09
# inputs:
#   in out_dir/tables/:
#     - coefficient_summary.csv
#   in 0_data/v2_results/, built by _setup/05:
#     - v2_results.csv
# outputs:
#   in out_dir/tables/:
#     - parity_terms.csv
#     - parity_summary.csv
# notes:
#   - The gate itself. Compares this run's coefficients against
#     the published v2 ones, per stage, species and term.
#   - Reads only 0_data/v2_results/v2_results.csv, so it runs
#     with the network drives unmounted.
#   - What is joined to what:
#     - Climate is fitted once, province-wide, in v2, so its
#       reference rows carry region "all". A run's north and
#       south climate results are both scored against them.
#       The harness fits climate per region, so expect a gap
#       until it does not.
#     - Habitat is joined on region. Plant terms are relabelled
#       as v2's 04a standardization does; bird terms are the
#       translated ones from 01_collect_results.R (stage
#       "habitat"), and the raw "landcover" stage is not scored.
#     - Mammals are joined on the hurdle part, and their two
#       season runs are averaged first, because v2's `.all`
#       references average summer and winter.
#   - Parity is distributional where v2 bootstraps: the v2
#     median is scored on whether it falls inside this run's
#     10th-to-90th percentile band. Where v2 fits once (v2_n of
#     1: mammal climate and habitat), the like-for-like run value
#     is iteration 1, the full-data fit, and the absolute
#     difference is the number to read.
#   - Terms v2 overwrites with machinery the harness does not
#     have, or fixes at a placeholder, are flagged from
#     v2_unreachable_terms() and left out of the reachable
#     scores.
#   - Whatever cannot be compared is left in `notes`, which the
#     report prints.
#   - Expects exp_id, data_dir, pipeline_dir and out_dir from
#     run.R, and the plant-group module to be sourced.
# ---

# 1. Setup ----

## 1.1 Resolve paths ----
tables_dir <- file.path(out_dir, "tables")
dir.create(tables_dir, recursive = TRUE, showWarnings = FALSE)

# v2_results/ sits beside test_dataset/ in 0_data/.
reference_path <- file.path(
  dirname(data_dir), "v2_results", "v2_results.csv"
)

## 1.2 Read this run and the reference ----
summary_path <- file.path(tables_dir, "coefficient_summary.csv")

run_coefficients <- if (file.exists(summary_path)) {
  as.data.frame(data.table::fread(summary_path))
} else {
  message(
    "No coefficient summary at ", summary_path,
    "; run 01_collect_results.R first."
  )
  NULL
}

reference <- if (file.exists(reference_path)) {
  as.data.frame(data.table::fread(reference_path))
} else {
  message(
    "No v2 reference at ", reference_path,
    "; run 1_code/_setup/05_harmonize_v2_results.R."
  )
  NULL
}

notes <- list()

# 2. What cannot match ----

## 2.1 v2_unreachable_terms() ----

#' Terms v2 Sets by Machinery the Harness Lacks, or Fixes
#'
#' Built from the v2 code, not from a name pattern. A term here
#' can join and still not be expected to agree, so it is scored
#' but left out of the reachable totals.
#'
#' - Plant age splines, cutblock convergence and the soft-linear
#'   pooling that borrows from them are reproduced by the plant
#'   module (plant_age_splines(), plant_cutblock_convergence()),
#'   and are reachable.
#' - Plant placeholders: 04a sets Water, Bare, SnowIce, Mine,
#'   MineV, HWater and, in the south, SoilUnknown to -10,000.
#' - Mammal age splines and cutblock convergence are reproduced
#'   by modules/mammals/hurdle.R, and are reachable.
#' - Mammal placeholders: section 7.1 adds Bare and Water at 0.
#' - Bird placeholders: 08.PackageCoefficients.R fixes HardLin,
#'   Water, Bare, SnowIce and Mine.
#'
#' @return A data frame of group, region, part, term and reason.
#'   `region` and `part` NA mean any.
#'
#' @example # Example usage of the function
#' # head(v2_unreachable_terms())
v2_unreachable_terms <- function() {
  rows <- function(group, terms, reason, region = NA, part = NA) {
    data.frame(
      group = group, region = region, part = part, term = terms,
      reason = reason, stringsAsFactors = FALSE
    )
  }

  rbind(
    rows(
      "plant",
      c("Water", "Bare", "SnowIce", "Mine", "MineV", "HWater",
        "SoilUnknown"),
      "v2 placeholder"
    ),
    rows("mammal", c("Bare", "Water"), "v2 placeholder"),
    rows(
      "bird", c("HardLin", "Water", "Bare", "SnowIce", "Mine"),
      "v2 placeholder"
    )
  )
}

# 3. Shape the run like the reference ----

## 3.1 The run's key columns ----
run_rows <- NULL

if (!is.null(run_coefficients)) {
  run_rows <- run_coefficients

  # The raw bird landcover coefficients have no v2 counterpart;
  # their translation (stage "habitat") does.
  run_rows <- run_rows[
    !(run_rows$taxon == "bird" & run_rows$stage == "landcover"),
  ]

  # glm names terms as the formula writes them; v2's published
  # tables use plain names. The spatial ones are the bird climate
  # terms; the plant ones are stored columns already.
  v2_names <- c(
    "(Intercept)" = "Intercept",
    "I(Easting^2)" = "Easting2",
    "I(Northing^2)" = "Northing2",
    "Easting:Northing" = "EastingNorthing"
  )
  renamed <- run_rows$term %in% names(v2_names)
  run_rows$term[renamed] <- v2_names[run_rows$term[renamed]]

  # The mammal hurdle writes one stage per v2 table,
  # habitat_presence, habitat_abundance and habitat_total; each
  # is v2's habitat stage for that part.
  hurdle <- grepl("^habitat_(presence|abundance|total)$", run_rows$stage)
  run_rows$part[hurdle] <- sub("^habitat_", "", run_rows$stage[hurdle])
  run_rows$stage[hurdle] <- "habitat"

  # v2 fits climate once across the province.
  run_rows$ref_region <- ifelse(
    run_rows$stage == "climate", "all", run_rows$region
  )

  run_rows$group <- ifelse(
    run_rows$taxon %in% c("bryophyte", "lichen", "mite",
                          "vascular_plant"),
    "plant", run_rows$taxon
  )

  # The part each reference row belongs to. Mammal climate is
  # fitted on presence whichever half runs.
  run_rows$ref_part <- ifelse(
    run_rows$group == "plant", "detection",
    ifelse(
      run_rows$group == "bird", "count",
      ifelse(run_rows$stage == "climate", "presence",
             run_rows$part)
    )
  )

  ## 3.2 Relabel plant habitat terms as v2 publishes them ----
  is_plant_habitat <- run_rows$group == "plant" &
    run_rows$stage == "habitat"

  if (any(is_plant_habitat)) {
    labels <- plant_v2_term_labels(run_rows$term[is_plant_habitat])
    relabelled <- merge(
      run_rows[is_plant_habitat, ], labels,
      by = "term", all.x = TRUE
    )
    relabelled$term <- relabelled$v2_term
    relabelled$v2_term <- NULL

    run_rows <- rbind(
      run_rows[!is_plant_habitat, ],
      relabelled[, names(run_rows)]
    )
  }

  ## 3.3 Average the mammal seasons ----
  # v2's `.all` references are the mean of the summer and winter
  # fits where both exist. The season is part of the harness's
  # species name, so it is stripped and the runs averaged.
  is_mammal <- run_rows$group == "mammal"

  if (any(is_mammal)) {
    mammals <- run_rows[is_mammal, ]

    # Stores written before meta.json recorded the season and
    # part lack them. The season is in the species name, and
    # those runs fitted presence, the spec's default.
    no_season <- is.na(mammals$season) | mammals$season == ""
    mammals$season[no_season] <- tolower(
      sub("^.*_(Summer|Winter)$", "\\1", mammals$species[no_season])
    )

    no_part <- is.na(mammals$ref_part) | mammals$ref_part == ""
    if (any(no_part)) {
      mammals$ref_part[no_part] <- "presence"
      notes[["mammal part"]] <- paste0(
        "mammal: ", sum(no_part), " rows came from stores that do ",
        "not record the hurdle part; read as presence, the ",
        "spec's default."
      )
    }

    mammals$species <- sub("_(Summer|Winter)$", "", mammals$species)

    keys <- c("taxon", "group", "region", "ref_region", "stage",
              "ref_part", "species", "term")
    values <- c("n", "median", "p10", "p90", "boot1")

    averaged <- stats::aggregate(
      mammals[, values],
      by = mammals[, keys],
      FUN = function(x) mean(x, na.rm = TRUE)
    )
    averaged$seasons <- stats::aggregate(
      mammals$season, by = mammals[, keys],
      FUN = function(x) paste(sort(unique(x)), collapse = "+")
    )$x

    run_rows$seasons <- NA_character_
    averaged$run <- "mammal"
    averaged$season <- "all"
    averaged$part <- averaged$ref_part

    run_rows <- rbind(
      run_rows[!is_mammal, ],
      averaged[, names(run_rows)]
    )
  } else {
    run_rows$seasons <- NA_character_
  }
}

# 4. Compare ----

parity <- NULL

if (!is.null(run_rows) && !is.null(reference) &&
      nrow(run_rows) > 0) {
  reference_keys <- reference[, c(
    "taxon", "region", "stage", "part", "species", "term",
    "v2_median", "v2_p10", "v2_p90", "v2_n", "source"
  )]
  names(reference_keys)[names(reference_keys) == "region"] <-
    "ref_region"
  names(reference_keys)[names(reference_keys) == "part"] <-
    "ref_part"

  parity <- merge(
    run_rows, reference_keys,
    by = c("taxon", "ref_region", "stage", "ref_part", "species",
           "term"),
    all.x = TRUE
  )

  ## 4.1 The run value to compare ----
  # Where v2 fits once, its value is a full-data fit, and the
  # like-for-like run value is iteration 1.
  parity$comparison <- ifelse(
    !is.na(parity$v2_n) & parity$v2_n == 1,
    "iteration 1", "median"
  )
  parity$run_value <- ifelse(
    parity$comparison == "iteration 1",
    parity$boot1, parity$median
  )

  ## 4.2 Flag what cannot match ----
  unreachable <- v2_unreachable_terms()

  parity$unreachable_reason <- vapply(
    seq_len(nrow(parity)),
    function(i) {
      hit <- unreachable[
        unreachable$group == parity$group[i] &
          unreachable$term == parity$term[i] &
          (is.na(unreachable$region) |
             unreachable$region == parity$region[i]) &
          (is.na(unreachable$part) |
             unreachable$part == parity$ref_part[i]),
      ]

      if (nrow(hit) == 0) NA_character_ else hit$reason[1]
    },
    character(1)
  )
  parity$reachable <- is.na(parity$unreachable_reason)

  ## 4.2a Flag negligible terms ----
  # Terms model averaging has shrunk to nothing in both runs. They
  # stay in the in-band scores, which the numerical tolerance
  # already handles, but not in the band ratio or the Spearman,
  # where their noise would decide the row.
  term_scales <- term_scale(reference, c("taxon", "stage"))
  parity <- merge(
    parity, term_scales,
    by = c("taxon", "stage", "term"), all.x = TRUE
  )
  parity$negligible <- is_negligible(
    parity$run_value, parity$v2_median, parity$typical
  )

  ## 4.3 Score ----
  matched <- is.finite(parity$v2_median)

  spread <- (parity$p90 - parity$p10) / 2
  parity$absolute_difference <- ifelse(
    matched, abs(parity$run_value - parity$v2_median), NA_real_
  )

  # A term agrees when the v2 median is inside this run's band,
  # or when the two are within numerical tolerance. The second
  # matters for averaged terms carrying almost no model weight:
  # their values run to 1e-20 or 1e-137, and banding numerical
  # noise is meaningless.
  parity$in_band <- matched & (
    (is.finite(parity$p10) & is.finite(parity$p90) &
       parity$v2_median >= parity$p10 &
       parity$v2_median <= parity$p90) |
      parity$absolute_difference <= parity_targets()$numerical_tolerance
  )
  parity$standardized_difference <- ifelse(
    matched & is.finite(spread) & spread > 0,
    parity$absolute_difference / spread, NA_real_
  )

  ## 4.4 Say what did not join ----
  combos <- unique(parity[, c("taxon", "region", "stage")])

  for (i in seq_len(nrow(combos))) {
    one <- parity[
      parity$taxon == combos$taxon[i] &
        parity$region == combos$region[i] &
        parity$stage == combos$stage[i],
    ]
    label <- paste(combos$taxon[i], combos$region[i],
                   combos$stage[i])

    if (!any(is.finite(one$v2_median))) {
      notes[[label]] <- paste0(
        label, ": no species and term matched v2_results.csv."
      )
    }
  }
} else if (is.null(reference)) {
  notes[["reference"]] <- "v2_results.csv not found."
}

# 5. Write ----
if (!is.null(parity) && nrow(parity) > 0) {
  parity <- parity[order(
    parity$taxon, parity$region, parity$stage, parity$species,
    parity$term
  ), ]
  rownames(parity) <- NULL

  data.table::fwrite(
    parity, file.path(tables_dir, "parity_terms.csv"), na = ""
  )

  parity_summary <- do.call(rbind, lapply(
    split(
      parity,
      list(parity$taxon, parity$region, parity$stage),
      drop = TRUE
    ),
    function(block) {
      compared <- block[is.finite(block$v2_median), ]
      reachable <- compared[compared$reachable, ]
      substantive <- reachable[!reachable$negligible, ]

      pct <- function(x) {
        if (length(x) == 0) NA_real_ else round(100 * mean(x), 1)
      }

      med <- function(x) {
        x <- x[is.finite(x)]
        if (length(x) == 0) NA_real_ else round(stats::median(x), 3)
      }

      data.frame(
        taxon = block$taxon[1],
        region = block$region[1],
        stage = block$stage[1],
        comparison = paste(unique(compared$comparison),
                           collapse = "+"),
        species = length(unique(compared$species)),
        terms_compared = nrow(compared),
        # The draws the store actually holds, which the verdict
        # checks: a store overwritten by a shorter run still reads
        # the configured draw count.
        min_draws = if (nrow(compared) == 0) {
          NA_integer_
        } else {
          as.integer(min(compared$n))
        },
        in_band_pct = pct(compared$in_band),
        reachable_terms = nrow(reachable),
        reachable_in_band_pct = pct(reachable$in_band),
        median_standardized_difference = med(
          reachable$standardized_difference
        ),
        median_absolute_difference = med(
          reachable$absolute_difference
        ),
        max_absolute_difference = if (nrow(reachable) == 0) {
          NA_real_
        } else {
          signif(max(reachable$absolute_difference, na.rm = TRUE), 3)
        },
        negligible_terms = sum(reachable$negligible),
        # Per species, then the median: the terms span twenty
        # orders of magnitude, so a rank correlation, as the v2
        # self-agreement calibration uses. Reported, not gated.
        median_spearman = med(vapply(
          split(substantive, substantive$species),
          function(one) {
            if (nrow(one) < 3) {
              return(NA_real_)
            }
            suppressWarnings(stats::cor(
              one$run_value, one$v2_median, method = "spearman"
            ))
          },
          numeric(1)
        )),
        # This run's 10-90% band over v2's, per term; the median
        # per species, then over species, as the v2 calibration
        # takes it. Single terms vary threefold between two v2
        # runs, a species' median does not. NA where v2 has no
        # band: the iteration-1 rows.
        median_band_ratio = med(vapply(
          split(substantive, substantive$species),
          function(one) {
            ratio <- (one$p90 - one$p10) / (one$v2_p90 - one$v2_p10)
            ratio <- ratio[is.finite(ratio) & ratio > 0]
            if (length(ratio) == 0) NA_real_ else stats::median(ratio)
          },
          numeric(1)
        )),
        stringsAsFactors = FALSE
      )
    }
  ))

  # The verdict against the proposed targets. A trial run - fewer
  # draws than v2, or a species subset - is not gated.
  gated <- exists("n_bootstraps") && exists("v2_bootstraps") &&
    exists("focal_species") && n_bootstraps >= v2_bootstraps &&
    is.null(focal_species)

  verdict_of <- function(gate) {
    vapply(
      seq_len(nrow(parity_summary)),
      function(i) {
        with(parity_summary[i, ], parity_verdict(
          comparison, reachable_in_band_pct,
          median_standardized_difference, median_band_ratio,
          max_absolute_difference, gate
        ))
      },
      character(1)
    )
  }

  parity_summary$verdict <- verdict_of(gated)

  # A run with v2's full draw count on a species subset is not the
  # gate, but its rows can still be read against the targets. Said
  # separately, so it is never mistaken for the verdict.
  full_length <- exists("n_bootstraps") && exists("v2_bootstraps") &&
    n_bootstraps >= v2_bootstraps
  parity_summary$indicative_verdict <- if (!gated && full_length) {
    verdict_of(TRUE)
  } else {
    NA_character_
  }

  # A distributional row read from fewer stored draws than v2 has
  # no verdict, whatever the run was configured for: a band from
  # five draws is narrower than one from a hundred.
  short <- grepl("median", parity_summary$comparison) &
    !is.na(parity_summary$min_draws) &
    parity_summary$min_draws < get0("v2_bootstraps", ifnotfound = 0L)
  short_note <- paste0(
    "not gated (store holds ", parity_summary$min_draws, " draws)"
  )
  parity_summary$verdict[short] <- short_note[short]
  if (!all(is.na(parity_summary$indicative_verdict))) {
    parity_summary$indicative_verdict[short] <- short_note[short]
  }

  rownames(parity_summary) <- NULL
  data.table::fwrite(
    parity_summary,
    file.path(tables_dir, "parity_summary.csv"), na = ""
  )

  cat("\nParity against v2, by stage:\n")
  print(parity_summary)
} else {
  cat("\nNo parity comparison produced.\n")
}

for (note in notes) {
  cat("  note: ", note, "\n", sep = "")
}

# End of script ----
