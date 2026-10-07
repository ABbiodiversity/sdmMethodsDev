# ---
# title: Compare Against the v2.0 Reference (Experiment 000)
# author: Brendan Casey
# created: 2026-09-09
# inputs:
#   - `config`, from run.R: out_dir, data_dir, v2_reference_dir,
#     n_bootstraps, v2_bootstraps, focal_species
#   - `results$coefficient_summary`, from collect_results()
#   - in config$v2_reference_dir:
#     - v2_results.csv, built by _setup/08 from the pinned
#       ABMIexploreR coefficients
# outputs:
#   - in out_dir/tables/: parity_terms.csv, parity_summary.csv
#   - `results$parity`, `results$parity_summary` and
#     `results$parity_notes`, for the later steps
# notes:
#   - The gate: this run's coefficients against v2's, per stage,
#     species and term. Reads only v2_results.csv.
#   - What is joined to what:
#     - v2 climate reference rows carry region "all"; a run's
#       north and south climate results are both scored against
#       them.
#     - Habitat is joined on region. Plant terms are relabelled
#       as v2's 04a standardization does; bird terms are the
#       translated ones collect_results() adds (stage "habitat",
#       via run.R's `translate`), and the raw "landcover" stage
#       is not scored.
#     - Mammals are joined on the hurdle part, and their two
#       season runs are averaged first, because v2's `.all`
#       references average summer and winter.
#   - Where v2 bootstraps, the v2 median is scored against this
#     run's 10-90% band. Where v2 fits once (mammals, v2_n = 1),
#     iteration 1 is compared and the absolute difference read.
#   - Terms from v2_unreachable_terms() are left out of the
#     reachable scores. What cannot be compared goes to
#     `results$parity_notes`.
#   - Run as a script_step().
# ---

# 1. Setup ----

## 1.1 Resolve paths ----
tables_dir <- file.path(config$out_dir, "tables")
dir.create(tables_dir, recursive = TRUE, showWarnings = FALSE)

reference_path <- file.path(config$v2_reference_dir, "v2_results.csv")
reference_builder <- config$v2_reference_builder

## 1.2 Read this run and the reference ----
run_coefficients <- results$coefficient_summary

if (is.null(run_coefficients)) {
  message("No coefficients were collected; nothing to compare.")
}

reference <- if (file.exists(reference_path)) {
  as.data.frame(data.table::fread(reference_path))
} else {
  message(
    "No v2 reference at ", reference_path,
    "; run ", reference_builder, "."
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

  # glm names terms as the formula writes them (e.g. the bird
  # spatial terms); v2's tables use plain names
  v2_names <- c(
    "(Intercept)" = "Intercept",
    "I(Easting^2)" = "Easting2",
    "I(Northing^2)" = "Northing2",
    "Easting:Northing" = "EastingNorthing"
  )
  renamed <- run_rows$term %in% names(v2_names)
  run_rows$term[renamed] <- v2_names[run_rows$term[renamed]]

  # The hurdle's habitat_<part> stages map to v2's habitat stage
  hurdle <- grepl(
    "^habitat_(presence|abundance|total)$", run_rows$stage
  )
  run_rows$part[hurdle] <- sub(
    "^habitat_", "", run_rows$stage[hurdle]
  )
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
  # v2's `.all` references average summer and winter
  is_mammal <- run_rows$group == "mammal"

  if (any(is_mammal)) {
    mammals <- run_rows[is_mammal, ]

    # Older stores lack season and part in meta.json: take the
    # season from the species name; those runs fitted presence
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
    values <- c("n", "median", "p10", "p90", "boot1", "mean", "sd")

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
  # Where v2 fits once, compare iteration 1
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
  # Kept in the in-band scores (the tolerance handles them), not
  # in the band ratio or Spearman, where their noise would decide
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

  # In band, or within numerical tolerance (near-zero averaged
  # terms run to 1e-20 or 1e-137)
  parity$in_band <- matched & (
    (is.finite(parity$p10) & is.finite(parity$p90) &
       parity$v2_median >= parity$p10 &
       parity$v2_median <= parity$p90) |
      parity$absolute_difference <=
        parity_targets()$numerical_tolerance
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
        # Draws actually stored, not configured
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
        # Per species, then the median (as the v2 calibration).
        # Reported, not gated.
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
        # Band ratio: median per species, then over species (as
        # the calibration). NA for iteration-1 rows.
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
  full_length <- config$n_bootstraps >= config$v2_bootstraps
  gated <- full_length && is.null(config$focal_species)

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

  # Full draws on a species subset: readable, but not the gate
  parity_summary$indicative_verdict <- if (!gated && full_length) {
    verdict_of(TRUE)
  } else {
    NA_character_
  }

  # Fewer stored draws than v2: no verdict
  short <- grepl("median", parity_summary$comparison) &
    !is.na(parity_summary$min_draws) &
    parity_summary$min_draws < config$v2_bootstraps
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
  parity_summary <- NULL
  cat("\nNo parity comparison produced.\n")
}

for (note in notes) {
  cat("  note: ", note, "\n", sep = "")
}

# 6. Hand on ----
results$parity <- parity
results$parity_summary <- parity_summary
results$parity_notes <- notes

# End of script ----
