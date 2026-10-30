# ---
# title: Compare Spatial Predictions with v2 (Experiment 000)
# author: Brendan Casey
# created: 2026-10-27
# inputs:
#   - `config` and `results`, from run.R, with prediction enabled
#   - 2_pipeline/exp_000_parity_v2/predictions/<run>/, from the
#     predict step, and the result stores
#   - the prediction grid and the published v2 results
#     (harness/data_source.R)
# outputs:
#   - 3_output/exp_000_parity_v2/tables/prediction_parity.csv
#   - `results$prediction_parity`
# notes:
#   - docs/prediction_design.md section 4, two layers:
#     - A, the port check (a gate): the predict step's map of
#       each species' mapped draw against a line-by-line
#       transcription of v2's map script given the same
#       coefficients (utils/v2_map_transcription.R). Agreement
#       within `port_relative_difference` passes.
#     - B, the model check (reported, not gated): harness-fitted
#       maps against the map of v2's published coefficients, both
#       through the predict step. Correlations, mean absolute
#       difference, totals, and the share of cells within 20%.
#   - Departure from the design: layer A feeds both sides the
#     harness's own draw, not v2's published coefficients. The
#     published table uses ABMIexploreR's harmonized labels (with
#     aliases such as IndustrialRural), not the names v2's map
#     scripts read, so feeding it to the transcription would need
#     a rename that is not v2's code. The port check tests the
#     code, so any coefficients serve.
#   - Layer B's v2 side is v2's published coefficients: the
#     median over v2's 100 draws for birds and plants, v2's single
#     fit for mammals. v2's own maps used its median bootstrap
#     (birds) and draw 1 (plants), which are not published, so
#     birds and plants compare with v2's median coefficients.
#   - Computes on the cells the predict step computed, so the
#     caps match it: every cell, or the extent when the run's caps
#     come from the extent.
# ---

# 1. Setup ----

## 1.1 Load packages ----
library(data.table) # tables (version: 1.18.0)

## 1.2 Settings and helpers ----
exp_dir <- file.path(config$project_root, "1_code", "experiments",
                     "exp_000_parity_v2")
source(file.path(exp_dir, "utils", "parity_targets.R"))
source(file.path(exp_dir, "utils", "v2_map_transcription.R"))

settings <- config$prediction
targets <- prediction_parity_targets()

# 2. compare_maps() ----

#' Agreement Statistics Between Two Maps
#'
#' @param candidate,reference Numeric, one per cell.
#' @param area Numeric. Cell areas, km2.
#' @return A one-row data.table.
#'
#' @example # Example usage of the function
#' # compare_maps(harness, v2, cells$AreaKm2)
compare_maps <- function(candidate, reference, area) {
  both <- !is.na(candidate) & !is.na(reference)
  a <- candidate[both]
  b <- reference[both]
  relative <- abs(a - b) / pmax(abs(b), 1e-12)

  data.table(
    cells = sum(both),
    na_mismatch = sum(is.na(candidate) != is.na(reference)),
    max_abs_difference = max(abs(a - b)),
    max_rel_difference = max(relative),
    pearson = suppressWarnings(stats::cor(a, b)),
    spearman = suppressWarnings(
      stats::cor(a, b, method = "spearman")
    ),
    mean_abs_difference = mean(abs(a - b)),
    mad_relative = mean(abs(a - b)) / mean(abs(b)),
    # The harness's total over the compared cells as a multiple of
    # v2's: 1 is the same total, 0.9 is 10% lower
    harness_total_vs_v2 = sum(a * area[both]) / sum(b * area[both]),
    harness_total_vs_v2_unweighted = sum(a) / sum(b),
    share_within_20pct = mean(relative <= 0.2)
  )
}

# 3. published_set() ----

#' v2's Published Coefficients as a Harness Coefficient Set
#'
#' Each term of the harness's own set (the template) takes v2's
#' published value under the same name or v2's label for it:
#' plant_v2_term_labels() for plants; for birds, TreedFenR to
#' TreedFen8 read v2's single TreedFen. A term v2 does not
#' publish is left out.
#'
#' @param template A coefficient set (harness names), draw 1.
#' @param published The species' rows of v2_results.csv.
#' @param taxon Character.
#' @return A coefficient set, `boot` 0.
#'
#' @example # Example usage of the function
#' # published_set(sets[["1"]], v2_rows, "bird")
published_set <- function(template, published, taxon) {
  plant <- taxon %in% c("bryophyte", "lichen", "mite",
                        "vascular_plant")

  lookup <- function(terms, rows) {
    values <- stats::setNames(rows$v2_median, rows$term)

    stats::setNames(vapply(terms, function(t) {
      candidates <- c(
        t,
        if (plant) plant_v2_term_labels(t)$v2_term,
        if (taxon == "bird" && grepl("^TreedFen[R1-8]$", t)) {
          "TreedFen"
        }
      )
      hit <- candidates[candidates %in% names(values)]
      if (length(hit) == 0) NA_real_ else values[[hit[1]]]
    }, numeric(1)), terms)
  }

  climate <- published[published$stage == "climate", ]

  regions <- lapply(names(template$regions), function(region) {
    table <- template$regions[[region]]
    rows <- published[published$stage == "habitat" &
                        published$region == region, ]

    if (is.list(table)) {
      out <- lapply(names(table), function(part) {
        v <- lookup(names(table[[part]]), rows[rows$part == part, ])
        v[!is.na(v)]
      })
      stats::setNames(out, names(table))
    } else {
      v <- lookup(names(table), rows)
      v[!is.na(v)]
    }
  })
  names(regions) <- names(template$regions)

  # A region v2 publishes nothing for is one v2 did not model, so
  # v2's single-region rule applies, not a map of zeros
  published_regions <- unique(
    published$region[published$stage == "habitat"]
  )
  regions <- regions[names(regions) %in% published_regions]

  list(
    boot = 0L,
    climate = data.frame(term = climate$term,
                         estimate = climate$v2_median),
    regions = regions,
    models = list()
  )
}

# 4. Compare ----

if (!isTRUE(settings$enabled)) {
  message("Prediction parity: prediction is off; skipped.")
} else {
  grid <- load_spatial_grid(settings$grid_dir)
  jobs <- spatial_jobs(config)
  v2 <- as.data.frame(fread(file.path(config$v2_reference_dir,
                                      "v2_results.csv")))

  out_rows <- extent_cells(grid$cells, settings$extent)
  computed <- if (settings$caps_from == "province") {
    seq_len(nrow(grid$cells))
  } else {
    out_rows
  }
  out_index <- match(out_rows, computed)
  area <- grid$cells$AreaKm2[out_rows]
  rows <- list()

  for (scenario in settings$scenarios) {
    # v2's dense frames, built once per scenario
    frames <- v2_frames(grid, computed, scenario)
    full <- prediction_context(grid, computed, scenario)
    out <- prediction_context(grid, out_rows, scenario)

    for (job in jobs) {
      path <- file.path(
        config$pipeline_dir, "predictions", job$label,
        paste0(safe_name(job$species), "__", scenario, ".rds")
      )

      if (!file.exists(path)) {
        next
      }

      mapped <- readRDS(path)
      member <- job$members[[1]]
      boot <- mapped$chosen_draw %||%
        as.integer(sub("^draw", "", names(mapped$maps)[1]))
      stage_map <- mapped$maps$median_draw %||% mapped$maps[[1]]
      label <- function(...) {
        data.table(taxon = job$taxon, run = job$label,
                   species = job$species, scenario = scenario, ...)
      }

      # Step 1: Layer A, the port check
      port <- tryCatch({
        transcribed <- switch(
          if (job$taxon == "bird") {
            "bird"
          } else if (job$taxon == "mammal") {
            "mammal"
          } else {
            "plant"
          },
          bird = {
            i <- v2_bird_inputs(config$pipeline_dir, config$data_dir,
                                job$species, boot)
            m <- v2_bird_map(i$climate.i, i$joint_n, i$joint_s,
                             species_final_cap(job$spatial,
                                               job$species),
                             frames)
            list(climate = m$Climate, map = m$Provincial)
          },
          mammal = {
            i <- v2_mammal_inputs(config$pipeline_dir, job$species,
                                  boot)
            m <- v2_mammal_map(i$climate_coefs, i$north, i$south,
                               frames)
            list(climate = m$Climate, map = m$Combined)
          },
          plant = {
            i <- v2_plant_inputs(config$pipeline_dir, job$label,
                                 job$species, boot)
            m <- v2_plant_map(i$spp.clim, i$spp.veg, i$spp.soil,
                              frames)
            list(climate = m$Climate, map = m$NewPred)
          }
        )

        rbind(
          label(layer = "A", compare = paste0("draw ", boot,
                                              ": stage vs v2 code"),
                surface = "climate",
                compare_maps(mapped$climate,
                             transcribed$climate[out_index], area)),
          label(layer = "A", compare = paste0("draw ", boot,
                                              ": stage vs v2 code"),
                surface = "map",
                compare_maps(stage_map, transcribed$map[out_index],
                             area))
        )
      }, error = function(e) {
        label(layer = "A", compare = "port check failed",
              surface = conditionMessage(e))
      })

      # Step 2: Layer B, the model check
      model <- tryCatch({
        sets <- pool_seasons(lapply(job$members, member_draws,
                                    config = config))
        published <- v2[v2$taxon == job$taxon &
                          v2$species == job$species, ]

        if (nrow(published) == 0) {
          stop("no published v2 coefficients")
        }

        v2_set <- published_set(sets[["1"]], published, job$taxon)
        v2_map <- predict_draw(v2_set, job, member, full, out,
                               out_index, config)

        candidates <- list(median_draw = stage_map)

        if (!is.null(mapped$maps$mean)) {
          candidates$mean <- mapped$maps$mean
        }

        # v2 maps draw 1 for plants and fits mammals once
        if ("1" %in% names(sets) && !isTRUE(boot == 1)) {
          candidates$draw1 <- predict_draw(
            sets[["1"]], job, member, full, out, out_index, config
          )$combined
        }

        rbindlist(lapply(names(candidates), function(k) {
          label(layer = "B", compare = paste(k, "vs v2 published"),
                surface = "map",
                compare_maps(candidates[[k]], v2_map$combined, area))
        }))
      }, error = function(e) {
        label(layer = "B", compare = "model check failed",
              surface = conditionMessage(e))
      })

      rows[[length(rows) + 1]] <- rbind(port, model, fill = TRUE)
    }
  }

  parity <- rbindlist(rows, fill = TRUE)

  if (nrow(parity) > 0) {
    # Layer A is gated; layer B's targets are indicative
    port_limit <- targets$port_relative_difference
    parity[, status := fifelse(
      layer == "A",
      fifelse(!is.na(max_rel_difference) &
                max_rel_difference < port_limit &
                na_mismatch == 0, "pass", "fail"),
      fifelse(!is.na(spearman) & spearman >= targets$min_spearman &
                harness_total_vs_v2 >=
                  targets$harness_total_vs_v2_range[1] &
                harness_total_vs_v2 <=
                  targets$harness_total_vs_v2_range[2],
              "meets indicative target", "below indicative target")
    )]

    tables <- file.path(config$out_dir, "tables")
    dir.create(tables, recursive = TRUE, showWarnings = FALSE)
    fwrite(parity, file.path(tables, "prediction_parity.csv"))

    shown <- parity[, .(layer, taxon, species, scenario, compare,
                        surface, max_rel_difference = signif(
                          max_rel_difference, 3),
                        spearman = round(spearman, 3),
                        harness_total_vs_v2 = round(
                          harness_total_vs_v2, 3),
                        status)]
    print(shown, nrows = 200)
  }

  results$prediction_parity <- parity
}

# End of script ----
