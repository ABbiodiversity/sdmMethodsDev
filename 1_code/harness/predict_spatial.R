# ---
# title: Predict Fitted Species Models onto the Prediction Grid
# author: Brendan Casey
# created: 2026-10-27
# inputs:
#   - the published prediction grid (data_source.R,
#     prediction_grid_dir()): cells.rds and the
#     landcover_<region>_<scenario>.rds matrices
#   - the experiment's result stores, 2_pipeline/<id>/<run>/
#     <region>/coefficients.csv, and, for engines without
#     coefficients, the fitted objects in <region>/_models/
#   - each spec's `spatial` settings and its class map CSV
# outputs:
#   - 2_pipeline/<id>/predictions/<run>/<species>__<scenario>.rds
#   - 3_output/<id>/maps/<run>/<species>__<scenario>__<stat>.tif
#   - 3_output/<id>/tables/prediction_summary.csv
# notes:
#   - The predict step of run_experiment(), after fitting. It
#     reads stored coefficients, so it needs no refit, and can be
#     rerun alone: run_experiment(config, fit = FALSE).
#   - Ports v2's own prediction rule, the same for every taxon
#     (docs/prediction_design.md section 2.2):
#       1. climate per cell from the climate stage, back-
#          transformed and capped at a quantile;
#       2. per region (veg north, soil south) and habitat class,
#          the class's link coefficient plus Climate x slope (plus
#          pAspen x slope where the region has one), back-
#          transformed and mixed by the cell's class proportions;
#       3. north and south blended by wN and wS, with the taxon's
#          rule for species modelled in one region;
#       4. a final quantile cap.
#     Sources: birds 09.Predict.R, mammals
#     make-species-predictions.R, plants 04c_prediction-
#     comparison.R. Taxon differences are module settings.
#   - Caps are quantiles over every computed cell. With
#     `caps_from = "province"` (the default) every cell is
#     computed and only the extent is written, so a subset keeps
#     v2's caps.
#   - Draws: "median" maps one real draw, the one whose
#     predictions at a fixed sample of cells sit closest to the
#     per-cell median across draws (section 2.4). "all" also
#     writes the per-cell mean and SD. Integers map those draws.
#   - Engines without coefficients are predicted from their
#     saved fitted objects on pure-stand rows: the region's
#     prediction matrix, one row per habitat type, at each cell's
#     climate (section 2.6). Not part of v2 parity.
# ---

# 1. Setup ----

## 1.1 Load packages ----
library(data.table) # tables and summaries (version: 1.18.0)
library(Matrix) # sparse land-cover matrices (version: 1.7.3)
# terra and sciSpatialR, for the rasters, are loaded only when
# rasters are written.

# 2. prediction_config() ----

#' State an Experiment's Spatial Prediction Settings
#'
#' The harness defaults reproduce v2's prediction, except the
#' draw rule (`draws`), which is the decision of 2026-10-26.
#'
#' @param enabled Logical. Predict after fitting. Off by default,
#'   because it adds run time.
#' @param species Character vector of species to predict, by run
#'   name (e.g. "Moose_Summer") or pooled name ("Moose"), or NULL
#'   for every species fitted.
#' @param scenarios Character. "current" (v2's live scripts) and,
#'   optionally, "reference" (backfilled land cover).
#' @param draws "median" (default), "all", or an integer vector
#'   of draw numbers. v2 maps draw 1 for plants and its single fit
#'   for mammals; `draws = 1` reproduces that.
#' @param extent NULL for the province, "parity_test" (Col 300 to
#'   400, which crosses both regions and the blend zone), a list
#'   of cell-table filters such as `list(LufName = "Lower
#'   Peace")`, or `list(bbox = c(xmin, xmax, ymin, ymax))` in
#'   EPSG:3400.
#' @param caps_from Character. "province" computes every cell so
#'   the caps are v2's, and writes only the extent; "extent"
#'   computes and caps only the extent, which is quicker and is
#'   not v2's cap.
#' @param outputs Character. Any of "table", "raster", "png".
#' @param summaries Character. Any of "province",
#'   "natural_region".
#' @param sample_cells Integer. Cells in the median-draw sample.
#' @param chunk_cells Integer. Rows per prediction call for
#'   engines without coefficients.
#' @param workers Integer or NULL. Species predicted at once;
#'   NULL takes the experiment's `workers`.
#' @param grid_dir Character or NULL. A grid folder to read
#'   instead of the pinned one.
#' @return A list of class `prediction_config`.
#'
#' @example # Example usage of the function
#' # prediction_config(enabled = TRUE)
#' # prediction_config(enabled = TRUE, draws = "all",
#' #                   extent = "parity_test")
prediction_config <- function(
  enabled = FALSE,
  species = NULL,
  scenarios = "current",
  draws = "median",
  extent = NULL,
  caps_from = "province",
  outputs = c("table", "raster"),
  summaries = c("province", "natural_region"),
  sample_cells = 10000L,
  chunk_cells = 50000L,
  workers = NULL,
  grid_dir = NULL
) {
  out <- structure(
    list(
      enabled = enabled, species = species, scenarios = scenarios,
      draws = draws, extent = extent, caps_from = caps_from,
      outputs = outputs, summaries = summaries,
      sample_cells = sample_cells, chunk_cells = chunk_cells,
      workers = workers, grid_dir = grid_dir
    ),
    class = "prediction_config"
  )

  problems <- check_prediction_config(out)

  if (length(problems) > 0) {
    stop(
      "prediction_config() found ", length(problems),
      " problem(s):\n  - ", paste(problems, collapse = "\n  - "),
      call. = FALSE
    )
  }

  out$sample_cells <- as.integer(sample_cells)
  out$chunk_cells <- as.integer(chunk_cells)

  if (is.numeric(draws)) {
    out$draws <- sort(unique(as.integer(draws)))
  }

  out
}

## 2.1 check_prediction_config() ----

#' Check Prediction Settings
#'
#' @param x A prediction_config().
#' @return A character vector of problems, empty when fine.
#'
#' @example # Example usage of the function
#' # check_prediction_config(prediction_config())
check_prediction_config <- function(x) {
  problems <- character(0)
  problem <- function(...) {
    problems <<- c(problems, paste0(...))
  }
  whole <- function(v) {
    is.numeric(v) && length(v) == 1L && !is.na(v) && v >= 1 &&
      v == round(v)
  }

  if (!is.logical(x$enabled) || length(x$enabled) != 1L ||
        is.na(x$enabled)) {
    problem("`enabled` must be TRUE or FALSE.")
  }

  bad <- setdiff(x$scenarios, c("current", "reference"))

  if (length(x$scenarios) == 0 || length(bad) > 0) {
    problem("`scenarios` must be \"current\" and/or \"reference\".")
  }

  draws_ok <- (is.character(x$draws) && length(x$draws) == 1L &&
                 x$draws %in% c("median", "all")) ||
    (is.numeric(x$draws) && length(x$draws) > 0 &&
       all(!is.na(x$draws)) && all(x$draws >= 1) &&
       all(x$draws == round(x$draws)))

  if (!draws_ok) {
    problem("`draws` must be \"median\", \"all\" or draw numbers.")
  }

  extent_ok <- is.null(x$extent) ||
    identical(x$extent, "parity_test") ||
    (is.list(x$extent) && length(x$extent) > 0 &&
       !is.null(names(x$extent)) && all(nzchar(names(x$extent))))

  if (!extent_ok) {
    problem(
      "`extent` must be NULL, \"parity_test\", or a named list ",
      "of filters, such as list(LufName = \"Lower Peace\")."
    )
  }

  if (is.list(x$extent) && !is.null(x$extent$bbox) &&
        (!is.numeric(x$extent$bbox) ||
           length(x$extent$bbox) != 4L)) {
    problem("`extent$bbox` must be c(xmin, xmax, ymin, ymax).")
  }

  if (!identical(x$caps_from, "province") &&
        !identical(x$caps_from, "extent")) {
    problem("`caps_from` must be \"province\" or \"extent\".")
  }

  bad <- setdiff(x$outputs, c("table", "raster", "png"))

  if (length(bad) > 0) {
    problem("Unknown `outputs`: ", paste(bad, collapse = ", "), ".")
  }

  bad <- setdiff(x$summaries, c("province", "natural_region"))

  if (length(bad) > 0) {
    problem("Unknown `summaries`: ", paste(bad, collapse = ", "),
            ".")
  }

  if (!whole(x$sample_cells)) {
    problem("`sample_cells` must be a whole number of 1 or more.")
  }

  if (!whole(x$chunk_cells)) {
    problem("`chunk_cells` must be a whole number of 1 or more.")
  }

  if (!is.null(x$workers) && !whole(x$workers)) {
    problem("`workers` must be NULL or a whole number.")
  }

  problems
}

## 2.2 print.prediction_config() ----

#' Print Prediction Settings in One Line
#'
#' @param x A prediction_config().
#' @param ... Unused.
#' @return `x`, invisibly.
#'
#' @example # Example usage of the function
#' # print(prediction_config())
print.prediction_config <- function(x, ...) {
  cat(prediction_label(x), "\n", sep = "")
  invisible(x)
}

## 2.3 prediction_label() ----

#' Describe Prediction Settings in One Line
#'
#' @param x A prediction_config().
#' @return Character.
#'
#' @example # Example usage of the function
#' # prediction_label(prediction_config(enabled = TRUE))
prediction_label <- function(x) {
  if (!isTRUE(x$enabled)) {
    return("off")
  }

  paste0(
    "draws ", paste(x$draws, collapse = ","), "; scenarios ",
    paste(x$scenarios, collapse = ","), "; extent ",
    extent_label(x$extent), " (caps from ", x$caps_from, ")"
  )
}

## 2.4 extent_label() ----

#' Name an Extent for Records and Tables
#'
#' @param extent An extent, as prediction_config() takes it.
#' @return Character.
#'
#' @example # Example usage of the function
#' # extent_label(list(LufName = "Lower Peace"))
extent_label <- function(extent) {
  if (is.null(extent)) {
    return("province")
  }

  if (is.character(extent)) {
    return(extent)
  }

  # A run of whole numbers reads as a range, e.g. Col=300:400
  value_label <- function(x) {
    if (is.numeric(x) && length(x) > 2 && all(diff(x) == 1)) {
      paste0(x[1], ":", x[length(x)])
    } else {
      paste(x, collapse = "|")
    }
  }

  paste(vapply(names(extent), function(k) {
    paste0(k, "=", value_label(extent[[k]]))
  }, character(1)), collapse = "; ")
}

# 3. Module settings ----

## 3.1 spatial_fields() ----

#' The Fields a Spec's `spatial` Settings May Carry
#'
#' @return A character vector.
#'
#' @example # Example usage of the function
#' # spatial_fields()
spatial_fields <- function() {
  c(
    "link", "climate_stage", "climate_cap", "combine",
    "habitat_stages", "habitat_coefficients", "climate_term",
    "aspen", "class_map", "single_region", "region_mask",
    "final_cap", "infinite_to_median", "season_average"
  )
}

## 3.2 check_spatial_spec() ----

#' Check a Spec's `spatial` Settings
#'
#' Called by validate_spec(), so a bad setting fails before
#' anything is fitted.
#'
#' @param spatial A spec's `spatial` list.
#' @param project_root Character. Class maps are relative to it.
#' @return A character vector of problems, empty when fine.
#'
#' @example # Example usage of the function
#' # check_spatial_spec(bird_spec()$spatial)
check_spatial_spec <- function(
  spatial,
  project_root = getOption("sdm.project_root", ".")
) {
  problems <- character(0)
  problem <- function(...) {
    problems <<- c(problems, paste0("`spatial`: ", ...))
  }

  if (!is.list(spatial)) {
    return("`spatial` must be a list.")
  }

  extra <- setdiff(names(spatial), spatial_fields())

  if (length(extra) > 0) {
    problem("unknown field(s): ", paste(extra, collapse = ", "), ".")
  }

  if (length(spatial$link) != 1L ||
        !spatial$link %in% c("logit", "log")) {
    problem("`link` must be \"logit\" or \"log\".")
  }

  combine <- spatial$combine %||% "mixture"

  if (!combine %in% c("mixture", "mammal_hurdle")) {
    problem("`combine` must be \"mixture\" or \"mammal_hurdle\".")
  }

  if (combine == "mammal_hurdle" &&
        !all(c("presence", "total") %in%
               names(spatial$habitat_stages))) {
    problem(
      "the mammal hurdle needs `habitat_stages` naming its ",
      "presence and total stages."
    )
  }

  rule <- spatial$single_region %||% "zero"

  if (!rule %in% c("zero", "na", "na_by_nr")) {
    problem("`single_region` must be \"zero\", \"na\" or ",
            "\"na_by_nr\".")
  }

  if (rule == "na_by_nr" &&
        !all(vapply(spatial$region_mask, inherits, logical(1),
                    "formula"))) {
    problem("\"na_by_nr\" needs `region_mask`: a formula per ",
            "region, such as ~ NrName != \"Grassland\".")
  }

  caps <- c(spatial$climate_cap %||% 0.99, spatial$final_cap)

  if (!is.numeric(caps) || any(is.na(caps)) || any(caps <= 0) ||
        any(caps > 1)) {
    problem("caps must be quantiles above 0 and up to 1.")
  }

  if (length(spatial$final_cap) > 1 &&
        !"default" %in% names(spatial$final_cap)) {
    problem("a per-species `final_cap` needs a `default` entry.")
  }

  if (!is.null(spatial$habitat_coefficients) &&
        !is.function(spatial$habitat_coefficients)) {
    problem("`habitat_coefficients` must be a function.")
  }

  path <- spatial_class_map_path(spatial, project_root)

  if (is.null(path) || !file.exists(path)) {
    problem("class map not found: ", spatial$class_map %||% "NULL")
  }

  problems
}

## 3.3 spatial_class_map_path() ----

#' Resolve a Spec's Class Map
#'
#' @param spatial A spec's `spatial` list.
#' @param project_root Character.
#' @return Character or NULL.
#'
#' @example # Example usage of the function
#' # spatial_class_map_path(bird_spec()$spatial)
spatial_class_map_path <- function(
  spatial,
  project_root = getOption("sdm.project_root", ".")
) {
  if (is.null(spatial$class_map)) {
    return(NULL)
  }

  file.path(project_root, spatial$class_map)
}

## 3.4 read_class_map() ----

#' Read a Module's Class Map
#'
#' One row per region and grid class: the model term(s) that
#' give the class its effect (`model_class`; several, separated
#' by ";", are averaged on the link scale, as v2 averages bird
#' TreedFen ages), the prediction-matrix row(s) for engines
#' without coefficients (`engine_class`), and a fixed link value
#' where v2 fixes one (`fixed_value`). A class with none of these
#' adds nothing, as v2's select-by-name drops it.
#'
#' @param path Character.
#' @return A data.frame.
#'
#' @example # Example usage of the function
#' # read_class_map("1_code/modules/birds/spatial_classes.csv")
read_class_map <- function(path) {
  cached_read(path, function(p) {
    map <- as.data.frame(fread(
      p, colClasses = c(fixed_value = "numeric"), na.strings = ""
    ))

    needed <- c("region", "grid_class", "model_class",
                "engine_class", "fixed_value")
    absent <- setdiff(needed, names(map))

    if (length(absent) > 0) {
      stop("Class map ", p, " lacks ", paste(absent, collapse = ", "),
           call. = FALSE)
    }

    for (k in c("model_class", "engine_class")) {
      map[[k]][is.na(map[[k]])] <- ""
    }

    map
  }, tag = "class_map")
}

# 4. The grid ----

## 4.1 load_spatial_grid() ----

#' Read the Prediction Grid Once per Session
#'
#' The cell table gains the derived covariates the climate
#' stages name (Easting2, MAPPET and the rest), computed as the
#' harness computes them for training (derived_covariates()), and
#' an all-zero `offset`.
#'
#' @param dir Character or NULL. The grid folder; NULL for the
#'   pinned published copy.
#' @return A list: `dir`, `label`, `cells` (data.frame), and
#'   `landcover`, a list by region of lists by scenario of
#'   dgCMatrix.
#'
#' @example # Example usage of the function
#' # grid <- load_spatial_grid()
load_spatial_grid <- function(dir = NULL) {
  dir <- prediction_grid_dir(dir)

  cached_read(file.path(dir, "cells.rds"), function(path) {
    cells <- as.data.frame(readRDS(path))

    # Step 1: The derived covariates, defined once in the harness
    for (name in names(derived_covariates())) {
      one <- derived_covariates()[[name]]

      derivable <- all(one$inputs %in% names(cells))

      if (!name %in% names(cells) && derivable) {
        cells[[name]] <- one$fn(cells)
      }
    }

    cells$offset <- 0

    # Step 2: The land cover, by region and scenario
    layers <- list(
      north = c(current = "veg_current",
                reference = "veg_reference"),
      south = c(current = "soil_current",
                reference = "soil_reference")
    )
    landcover <- lapply(layers, function(region) {
      lapply(region, function(layer) {
        readRDS(file.path(dir, paste0("landcover_", layer, ".rds")))
      })
    })

    list(
      dir = dir,
      label = published_label(dir),
      cells = cells,
      landcover = landcover
    )
  }, tag = "spatial_grid")
}

## 4.2 extent_cells() ----

#' Which Cells an Extent Covers
#'
#' @param cells The grid's cell table.
#' @param extent An extent, as prediction_config() takes it.
#' @return An integer vector of row numbers.
#'
#' @example # Example usage of the function
#' # extent_cells(grid$cells, "parity_test")
extent_cells <- function(cells, extent) {
  if (is.null(extent)) {
    return(seq_len(nrow(cells)))
  }

  if (identical(extent, "parity_test")) {
    extent <- list(Col = 300:400)
  }

  keep <- rep(TRUE, nrow(cells))

  for (key in names(extent)) {
    if (key == "bbox") {
      b <- extent$bbox
      keep <- keep & cells$Easting >= b[1] & cells$Easting <= b[2] &
        cells$Northing >= b[3] & cells$Northing <= b[4]
    } else if (key %in% names(cells)) {
      keep <- keep & cells[[key]] %in% extent[[key]]
    } else {
      stop("Extent filter `", key, "` is not a grid column.",
           call. = FALSE)
    }
  }

  if (!any(keep)) {
    stop("The extent covers no cells.", call. = FALSE)
  }

  which(keep)
}

## 4.3 sample_cells_for_draws() ----

#' The Fixed Cell Sample the Median Draw Is Chosen On
#'
#' Equal shares from the three wN bands (south only, the blend
#' zone, north only), so both regions and the overlap are
#' represented. Seeded, so the same grid gives the same sample.
#'
#' @param cells The computed cells.
#' @param n Integer. Cells to draw.
#' @param seed Integer.
#' @return An integer vector of row numbers, sorted.
#'
#' @example # Example usage of the function
#' # sample_cells_for_draws(grid$cells, 10000L, 20261027L)
sample_cells_for_draws <- function(cells, n, seed = 20261027L) {
  band <- ifelse(cells$wN <= 0, "south",
                 ifelse(cells$wN >= 1, "north", "blend"))
  groups <- split(seq_len(nrow(cells)), band)
  share <- ceiling(n / length(groups))

  old <- if (exists(".Random.seed", envir = globalenv())) {
    get(".Random.seed", envir = globalenv())
  }
  on.exit(if (!is.null(old)) {
    assign(".Random.seed", old, envir = globalenv())
  })
  set.seed(seed)

  picked <- unlist(lapply(groups, function(rows) {
    if (length(rows) <= share) rows else sample(rows, share)
  }), use.names = FALSE)

  sort(picked)
}

## 4.4 prediction_context() ----

#' The Cells, Land Cover and Weights for One Computation
#'
#' Rows of the land-cover matrices are subset once, and the
#' non-zero entries indexed, so each draw mixes classes with
#' vector arithmetic.
#'
#' @param grid From load_spatial_grid().
#' @param rows Integer. The computed cells (row numbers).
#' @param scenario Character.
#' @return A list.
#'
#' @example # Example usage of the function
#' # ctx <- prediction_context(grid, seq_len(1000), "current")
prediction_context <- function(grid, rows, scenario) {
  cells <- grid$cells[rows, , drop = FALSE]

  landcover <- lapply(grid$landcover, function(region) {
    m <- region[[scenario]][rows, , drop = FALSE]
    m <- as(m, "CsparseMatrix")

    list(
      matrix = m,
      row = m@i + 1L,
      col = rep.int(seq_len(ncol(m)), diff(m@p)),
      classes = colnames(m)
    )
  })

  list(
    rows = rows,
    cells = cells,
    scenario = scenario,
    landcover = landcover
  )
}

# 5. Coefficients from the stores ----

## 5.1 spatial_jobs() ----

#' One Prediction Job per Species, Across the Runs It Pools
#'
#' Runs whose spec has `season_average` are pooled by taxon:
#' a mammal's summer and winter runs make one job, named without
#' the season, as v2 maps one table per species.
#'
#' @param config An experiment_config().
#' @return A list of jobs: `label` (the output folder), `taxon`,
#'   `species` (output name), `spatial`, and `members` (run,
#'   species, spec).
#'
#' @example # Example usage of the function
#' # jobs <- spatial_jobs(config)
spatial_jobs <- function(config) {
  wanted <- config$prediction$species
  members <- list()

  for (key in names(config$specs)) {
    spec <- config$specs[[key]]

    if (is.null(spec$spatial)) {
      message("Prediction: run `", key, "` has no `spatial` ",
              "settings; skipped.")
      next
    }

    stores <- file.path(config$pipeline_dir, key,
                        names(spec$regions))
    fitted <- unique(unlist(lapply(stores, function(dir) {
      rows <- read_store_coefficients(dir)
      models <- file.path(dir, "_models")
      c(
        if (!is.null(rows)) unique(as.character(rows$species)),
        if (dir.exists(models)) {
          list.files(models)
        }
      )
    })))

    pooled <- isTRUE(spec$spatial$season_average) &&
      !is.null(spec$season)

    for (sp in fitted) {
      name <- if (pooled) season_free_name(sp) else sp

      if (!is.null(wanted) && !sp %in% wanted && !name %in% wanted) {
        next
      }

      label <- if (pooled) spec$taxon else key
      id <- paste(label, name, sep = "|")

      members[[id]] <- c(
        members[[id]],
        list(list(run = key, species = sp, spec = spec))
      )
    }
  }

  lapply(names(members), function(id) {
    first <- members[[id]][[1]]
    list(
      label = strsplit(id, "|", fixed = TRUE)[[1]][1],
      taxon = first$spec$taxon,
      species = strsplit(id, "|", fixed = TRUE)[[1]][2],
      spatial = first$spec$spatial,
      members = members[[id]]
    )
  })
}

## 5.2 read_store_coefficients() ----

#' A Store's Coefficients, Read Once per Session
#'
#' Every species of a run reads the same file, so it is cached
#' (keyed on its modification time, so a refit is re-read).
#'
#' @param dir Character. A region store.
#' @return A data.frame, or NULL when the store has none.
#'
#' @example # Example usage of the function
#' # read_store_coefficients("2_pipeline/exp_000/bird/north")
read_store_coefficients <- function(dir) {
  path <- file.path(dir, "coefficients.csv")

  if (!file.exists(path)) {
    return(NULL)
  }

  cached_read(path, function(p) as.data.frame(fread(p)),
              tag = "store_coefficients")
}

## 5.3 season_free_name() ----

#' A Species Name Without Its Season
#'
#' @param x Character, e.g. "Moose_Summer".
#' @return Character, e.g. "Moose".
#'
#' @example # Example usage of the function
#' # season_free_name("Moose_Winter")
season_free_name <- function(x) {
  sub("_(Summer|Winter)$", "", x)
}

## 5.3 member_draws() ----

#' One Run's Coefficient Sets for a Species, by Draw
#'
#' Reads the species' rows from each region store, applies the
#' module's habitat translation (birds), and reshapes them into
#' one set per draw: the climate coefficients, each region's
#' habitat tables, and the saved fitted objects for stages with
#' no coefficients.
#'
#' @param member One of a job's `members`.
#' @param config An experiment_config().
#' @return A named list by draw number of coefficient sets.
#'
#' @example # Example usage of the function
#' # sets <- member_draws(job$members[[1]], config)
member_draws <- function(member, config) {
  spec <- member$spec
  spatial <- spec$spatial
  sp <- member$species
  climate_stage <- spatial$climate_stage %||% "climate"
  habitat_stages <- spatial$habitat_stages %||% "habitat"
  regions <- list()
  climate <- NULL
  models <- list()

  for (region in names(spec$regions)) {
    dir <- file.path(config$pipeline_dir, member$run, region)
    rows <- read_store_coefficients(dir)

    if (!is.null(rows)) {
      rows <- rows[rows$species == sp, , drop = FALSE]
    }

    # Saved fitted objects, for stages without coefficients
    model_dir <- file.path(dir, "_models", safe_name(sp))

    if (dir.exists(model_dir)) {
      models[[region]] <- model_dir
    }

    if (is.null(rows) || nrow(rows) == 0) {
      next
    }

    # The climate stage is province-wide: each store holds the
    # same copy; v2 reads the north one where there is one
    if (is.null(climate)) {
      climate <- rows[rows$stage == climate_stage, , drop = FALSE]
    }

    if (is.function(spatial$habitat_coefficients)) {
      translated <- spatial$habitat_coefficients(
        rows, config$data_dir, region
      )
      rows <- rbind(rows[, names(translated)], translated)
    }

    regions[[region]] <- rows[rows$stage %in% habitat_stages, ,
                              drop = FALSE]
  }

  boots <- sort(unique(c(
    climate$boot, unlist(lapply(regions, `[[`, "boot")),
    unlist(lapply(models, function(d) {
      as.integer(sub("__.*$", "", list.files(d)))
    }))
  )))

  sets <- lapply(boots, function(b) {
    one_region <- function(rows) {
      rows <- rows[rows$boot == b, , drop = FALSE]
      split_stages(rows, habitat_stages)
    }

    list(
      boot = b,
      climate = if (!is.null(climate)) {
        climate[climate$boot == b, c("term", "estimate")]
      },
      regions = lapply(regions, one_region),
      models = models
    )
  })

  stats::setNames(sets, boots)
}

## 5.4 split_stages() ----

#' A Region's Habitat Rows as Named Vectors, by Stage
#'
#' @param rows Coefficient rows for one draw.
#' @param stages Character. The habitat stage(s); named for the
#'   mammal hurdle (presence, total, abundance).
#' @return A named numeric vector (one stage) or a named list of
#'   them, or NULL when the draw has no rows.
#'
#' @example # Example usage of the function
#' # split_stages(rows, "habitat")
split_stages <- function(rows, stages) {
  if (nrow(rows) == 0) {
    return(NULL)
  }

  vec <- function(stage) {
    r <- rows[rows$stage == stage, , drop = FALSE]
    if (nrow(r) == 0) NULL else stats::setNames(r$estimate, r$term)
  }

  if (is.null(names(stages))) {
    return(vec(stages[1]))
  }

  out <- lapply(stages, vec)
  if (all(vapply(out, is.null, logical(1)))) NULL else out
}

## 5.5 pool_seasons() ----

#' Average Two Seasons' Coefficient Sets, Draw by Draw
#'
#' As v2 averages its mammal `.all` tables
#' (north-models/03_basic-models.R:1067-1100, south 883-915): the
#' presence and total tables on their own (response) scale, the
#' pAspen slopes on their link scales (stored as plogis and exp),
#' and the climate coefficients, which are the same model in
#' both seasons, term by term. A species in one season keeps that
#' season. Draws present in only one season are dropped.
#'
#' @param seasons A list of member_draws() results.
#' @return One member_draws()-shaped list.
#'
#' @example # Example usage of the function
#' # pooled <- pool_seasons(list(summer, winter))
pool_seasons <- function(seasons) {
  if (length(seasons) == 1) {
    return(seasons[[1]])
  }

  boots <- Reduce(intersect, lapply(seasons, names))

  mean_vec <- function(vectors, scale = c("identity", "logit",
                                           "log")) {
    scale <- match.arg(scale)
    terms <- unique(unlist(lapply(vectors, names)))
    to <- switch(scale, identity = identity, logit = stats::qlogis,
                 log = log)
    from <- switch(scale, identity = identity,
                   logit = stats::plogis, log = exp)

    values <- vapply(terms, function(t) {
      x <- vapply(vectors, function(v) {
        if (t %in% names(v)) to(v[[t]]) else NA_real_
      }, numeric(1))
      mean(x, na.rm = TRUE)
    }, numeric(1))

    from(values)
  }

  pooled <- lapply(boots, function(b) {
    sets <- lapply(seasons, `[[`, b)
    regions <- unique(unlist(lapply(sets, function(s) {
      names(s$regions)
    })))

    climate_terms <- lapply(sets, function(s) {
      stats::setNames(s$climate$estimate, s$climate$term)
    })
    climate <- mean_vec(climate_terms)

    out_regions <- lapply(stats::setNames(regions, regions),
                          function(r) {
      tables <- Filter(Negate(is.null), lapply(sets, function(s) {
        s$regions[[r]]
      }))
      parts <- unique(unlist(lapply(tables, names)))

      stats::setNames(lapply(parts, function(part) {
        vectors <- Filter(Negate(is.null),
                          lapply(tables, `[[`, part))
        aspen <- lapply(vectors, function(v) v["pAspen"])
        body <- lapply(vectors, function(v) {
          v[names(v) != "pAspen"]
        })
        averaged <- mean_vec(body)

        if (any(vapply(vectors, function(v) "pAspen" %in% names(v),
                       logical(1)))) {
          aspen_scale <- if (part == "presence") "logit" else "log"
          averaged <- c(
            averaged,
            pAspen = unname(mean_vec(
              lapply(aspen, function(a) {
                stats::setNames(a, "pAspen")[!is.na(a)]
              }),
              aspen_scale
            ))
          )
        }

        averaged
      }), parts)
    })

    list(
      boot = sets[[1]]$boot,
      climate = data.frame(
        term = names(climate), estimate = unname(climate),
        stringsAsFactors = FALSE
      ),
      regions = out_regions,
      models = list()
    )
  })

  stats::setNames(pooled, boots)
}

# 6. One draw ----

## 6.1 inverse_link() ----

#' A Spatial Link's Inverse, as v2 Applies It
#'
#' @param link Character. "logit" or "log".
#' @return A function.
#'
#' @example # Example usage of the function
#' # inverse_link("log")(c(-800, 0, 800))
inverse_link <- function(link) {
  switch(
    link,
    # binomial()$linkinv, as v2's plant and mammal scripts use:
    # unlike plogis(), it is bounded at machine epsilon beyond
    # +/- 30 on the link scale
    logit = stats::make.link("logit")$linkinv,
    # v2's bird inv.link, bounded as v2 bounds it
    log = function(eta) {
      pmin(pmax(exp(eta), .Machine$double.eps), .Machine$double.xmax)
    }
  )
}

## 6.2 class_values() ----

#' Each Grid Class's Link Value, from a Coefficient Vector
#'
#' @param map The class map rows for one region.
#' @param classes Character. The grid classes, in matrix order.
#' @param coefficients Named numeric. The habitat table.
#' @param column Character. "model_class" or "engine_class".
#' @param fixed Logical. Use `fixed_value` where no term maps.
#' @return Named numeric, NA for a class that adds nothing.
#'
#' @example # Example usage of the function
#' # class_values(map, ctx$landcover$north$classes, b)
class_values <- function(map, classes, coefficients,
                         column = "model_class", fixed = TRUE) {
  row <- match(classes, map$grid_class)

  values <- vapply(seq_along(classes), function(k) {
    if (is.na(row[k])) {
      return(NA_real_)
    }

    terms <- map[[column]][row[k]]

    if (nzchar(terms)) {
      parts <- strsplit(terms, ";", fixed = TRUE)[[1]]
      x <- coefficients[parts]
      # A missing term drops the class, as v2's any_of() does
      if (any(is.na(x))) NA_real_ else mean(x)
    } else if (fixed && !is.na(map$fixed_value[row[k]])) {
      map$fixed_value[row[k]]
    } else {
      NA_real_
    }
  }, numeric(1))

  stats::setNames(values, classes)
}

## 6.3 mix_classes() ----

#' Mix Per-Class Predictions by Each Cell's Proportions
#'
#' @param lc One region of a prediction_context().
#' @param contribution Numeric, one per non-zero entry of the
#'   land-cover matrix: the class prediction at that cell.
#' @return Numeric, one per cell.
#'
#' @example # Example usage of the function
#' # mix_classes(ctx$landcover$north, values)
mix_classes <- function(lc, contribution) {
  m <- lc$matrix
  contribution[is.na(contribution)] <- 0
  m@x <- m@x * contribution
  Matrix::rowSums(m)
}

## 6.4 predict_climate() ----

#' The Climate Stage at Every Computed Cell, Capped
#'
#' @param set A coefficient set (one draw).
#' @param member The job member, for saved fitted objects.
#' @param ctx A prediction_context() of every computed cell.
#' @param spatial The spec's `spatial` settings.
#' @return Numeric, one per cell, on the scale the habitat stage
#'   reads `Climate` on, capped at `climate_cap`.
#'
#' @example # Example usage of the function
#' # predict_climate(set, member, ctx, spatial)
predict_climate <- function(set, member, ctx, spatial) {
  inv <- inverse_link(spatial$link)

  value <- if (!is.null(set$climate) && nrow(set$climate) > 0) {
    inv(predict_from_coefficients(set$climate, ctx$cells, "link"))
  } else {
    stage <- spatial$climate_stage %||% "climate"
    fit <- read_saved_stage(set, stage)
    stage_def <- Filter(function(s) identical(s$name, stage),
                        member$spec$stages)[[1]]
    link <- fit$predict(ctx$cells, "link")
    switch(
      stage_def$carry_scale %||% "response",
      response = stats::plogis(link),
      link = link,
      exp = inverse_link("log")(link)
    )
  }

  cap <- stats::quantile(value, spatial$climate_cap %||% 0.99,
                         names = FALSE, na.rm = TRUE)
  pmin(value, cap)
}

## 6.5 read_saved_stage() ----

#' Read a Stage's Saved Fitted Object for One Draw
#'
#' @param set A coefficient set, carrying `models`.
#' @param stage Character. The stage name.
#' @param region Character or NULL. Where to look first.
#' @return The saved selection result.
#'
#' @example # Example usage of the function
#' # fit <- read_saved_stage(set, "climate")
read_saved_stage <- function(set, stage, region = NULL) {
  dirs <- unlist(c(set$models[region], set$models))
  file <- paste0(set$boot, "__", stage, ".rds")
  paths <- file.path(dirs, file)
  hit <- paths[file.exists(paths)]

  if (length(hit) == 0) {
    stop(
      "Stage `", stage, "`, draw ", set$boot, ", has neither ",
      "coefficients nor a saved fitted object. Fit with ",
      "prediction enabled, so the object is saved.",
      call. = FALSE
    )
  }

  readRDS(hit[1])
}

## 6.6 predict_region() ----

#' One Region's Prediction at the Output Cells
#'
#' @param set A coefficient set (one draw).
#' @param region Character.
#' @param climate Numeric, the capped climate at the output cells.
#' @param ctx A prediction_context() of the output cells.
#' @param job The prediction job.
#' @param member The job member (for engines without
#'   coefficients).
#' @param config An experiment_config().
#' @return Numeric, one per output cell, or NULL when the species
#'   is not modelled in the region.
#'
#' @example # Example usage of the function
#' # predict_region(set, "north", clim, ctx, job, member, config)
predict_region <- function(set, region, climate, ctx, job, member,
                           config) {
  spatial <- job$spatial
  table <- set$regions[[region]]
  lc <- ctx$landcover[[region]]
  map <- read_class_map(spatial_class_map_path(spatial))
  map <- map[map$region == region, , drop = FALSE]
  aspen_term <- spatial$aspen[[region]]
  term <- spatial$climate_term %||% "Climate"
  combine <- spatial$combine %||% "mixture"

  if (is.null(table)) {
    has_model <- !is.null(set$models[[region]]) &&
      file.exists(file.path(
        set$models[[region]],
        paste0(set$boot, "__", habitat_stage_name(member$spec),
               ".rds")
      ))

    if (!has_model) {
      return(NULL)
    }

    if (combine != "mixture") {
      stop("Engines without coefficients are mapped only with ",
           "`combine = \"mixture\"`.", call. = FALSE)
    }

    return(predict_region_engine(
      set, region, climate, ctx, job, member, config, map
    ))
  }

  # Cell-level pieces, one per non-zero land-cover entry
  rows <- lc$row
  pa <- ctx$cells$pAspen

  if (combine == "mixture") {
    # v2: eta = b_v + Climate x slope (+ pAspen x slope), then
    # inv.link, mixed by proportion (09.Predict.R:159-216,
    # 04c:108-135, 226-253)
    b <- class_values(map, lc$classes, table)
    slope <- if (term %in% names(table)) table[[term]] else 0
    has_aspen <- !is.null(aspen_term) &&
      aspen_term %in% names(table)
    aspen <- if (has_aspen) {
      table[[aspen_term]]
    } else {
      0
    }
    shift <- climate * slope + pa * aspen
    eta <- b[lc$col] + shift[rows]

    return(mix_classes(lc, inverse_link(spatial$link)(eta)))
  }

  # The mammal hurdle (make-species-predictions.R:514-618):
  # TA_v x plogis(Climate x logit(PA_Climate) + pAspen x slope +
  # logit(PA_v)) / PA_v x exp(pAspen x AGP slope)
  presence <- table$presence
  total <- table$total
  abundance <- table$abundance
  pa_v <- class_values(map, lc$classes, presence, fixed = FALSE)
  ta_v <- class_values(map, lc$classes, total, fixed = FALSE)
  beta <- stats::qlogis(presence[[term]])

  # The hurdle tables always carry the region's pAspen slopes
  # (stored as plogis and exp, as v2 publishes them); a store
  # without them predates that and would map pAspen as zero
  if (!is.null(aspen_term) &&
        !(aspen_term %in% names(presence) &&
            aspen_term %in% names(abundance))) {
    stop(
      "The ", region, " hurdle tables lack `", aspen_term, "`. ",
      "The store predates the pAspen slopes; refit the run.",
      call. = FALSE
    )
  }

  aspen_pa <- if (is.null(aspen_term)) {
    0
  } else {
    stats::qlogis(presence[[aspen_term]])
  }
  aspen_agp <- if (is.null(aspen_term)) {
    0
  } else {
    log(abundance[[aspen_term]])
  }

  linear <- climate * beta + pa * aspen_pa
  multiplier <- exp(aspen_agp * pa)
  pa_e <- pa_v[lc$col]
  adjusted <- inverse_link("logit")(
    linear[rows] + stats::qlogis(pmax(pa_e, 1e-300))
  )
  contribution <- ifelse(
    pa_e > 0, ta_v[lc$col] * (adjusted / pa_e) * multiplier[rows], 0
  )

  mix_classes(lc, contribution)
}

## 6.7 habitat_stage_name() ----

#' The Name of a Spec's Last (Habitat) Stage
#'
#' @param spec A taxon spec.
#' @return Character.
#'
#' @example # Example usage of the function
#' # habitat_stage_name(bird_spec())
habitat_stage_name <- function(spec) {
  utils::tail(vapply(spec$stages, `[[`, character(1), "name"), 1)
}

## 6.8 predict_region_engine() ----

#' One Region's Prediction from a Saved Fitted Object
#'
#' Pure-stand rows: for each cell and each habitat type present
#' in it, the region's prediction-matrix row for that type, at
#' the cell's climate and pAspen, with the stage's held values
#' (Protocol, effort), as predict_grid() holds them. Only the
#' (cell, type) pairs with cover are predicted.
#'
#' @param set,region,climate,ctx,job,member,config As
#'   predict_region().
#' @param map The class map rows for the region.
#' @return Numeric, one per output cell.
#'
#' @example # Example usage of the function
#' # predict_region_engine(set, "north", clim, ctx, job, member,
#' #                       config, map)
predict_region_engine <- function(set, region, climate, ctx, job,
                                  member, config, map) {
  spec <- member$spec
  lc <- ctx$landcover[[region]]
  stage_name <- habitat_stage_name(spec)
  fit <- read_saved_stage(set, stage_name, region)

  # Step 1: The region's prediction matrix, in the model's names,
  # as prepare_region() builds it
  request <- region_request(spec, region, config$data_dir)
  region_spec <- spec$regions[[region]]
  grid_name <- region_spec$grid %||%
    manifest_entry(config$data_dir, spec$taxon, region)$grid
  types <- load_prediction_grid(config$data_dir, grid_name)
  names(types) <- apply_term_map(names(types), request$rename)
  types <- types[
    !rownames(types) %in% region_spec$grid_drop_rows,
    !names(types) %in% region_spec$grid_drop_cols,
    drop = FALSE
  ]

  stage <- Filter(function(s) identical(s$name, stage_name),
                  request$spec$stages)[[1]]
  constants <- c(stage$constants %||% list(),
                 stage$grid_constants %||% list())
  climate_column <- stage$carry_from_as %||% "Climate"
  aspen_column <- job$spatial$aspen[[region]]

  for (one in names(constants)) {
    types[[one]] <- constants[[one]]
  }

  formulas <- fit$formulas %||% list(fit$formula)
  needed <- unique(unlist(lapply(
    Filter(function(f) !is.null(f) && !identical(f, NA_character_),
           formulas),
    formula_variables
  )))

  for (one in setdiff(needed, names(types))) {
    types[[one]] <- 0
  }

  types$offset <- 0

  # Step 2: Each grid class's type(s); several are averaged on
  # the link scale
  engine <- map$engine_class[match(lc$classes, map$grid_class)]
  engine[is.na(engine)] <- ""
  pieces <- strsplit(engine, ";", fixed = TRUE)
  used <- intersect(unique(unlist(pieces)), rownames(types))

  # Step 3: Predict each used type at the cells with cover in a
  # class that reads it, in chunks
  eta <- numeric(length(lc$row))
  counts <- numeric(length(lc$row))
  chunk <- config$prediction$chunk_cells

  for (type in used) {
    classes <- which(vapply(pieces, function(p) type %in% p,
                            logical(1)))
    entries <- which(lc$col %in% classes)

    if (length(entries) == 0) {
      next
    }

    for (start in seq(1, length(entries), by = chunk)) {
      idx <- entries[start:min(start + chunk - 1, length(entries))]
      cell <- lc$row[idx]
      newdata <- types[rep(type, length(idx)), , drop = FALSE]
      newdata[[climate_column]] <- climate[cell]

      if (!is.null(aspen_column) && aspen_column %in% names(types)) {
        newdata[[aspen_column]] <- ctx$cells$pAspen[cell]
      }

      eta[idx] <- eta[idx] + as.numeric(fit$predict(newdata, "link"))
      counts[idx] <- counts[idx] + 1
    }
  }

  eta[counts == 0] <- NA_real_
  eta <- eta / pmax(counts, 1)

  mix_classes(lc, inverse_link(job$spatial$link)(eta))
}

## 6.9 combine_regions() ----

#' Blend North and South, Then Cap, as Each Taxon Does
#'
#' @param north,south Numeric or NULL. The region predictions.
#' @param ctx A prediction_context() of the output cells.
#' @param spatial The `spatial` settings.
#' @param final_cap Numeric. The cap quantile, or NA for none
#'   (the median-draw sample is not capped).
#' @return Numeric, one per output cell.
#'
#' @example # Example usage of the function
#' # combine_regions(north, south, ctx, spatial, 0.995)
combine_regions <- function(north, south, ctx, spatial, final_cap) {
  wN <- ctx$cells$wN
  wS <- ctx$cells$wS
  rule <- spatial$single_region %||% "zero"
  both <- !is.null(north) && !is.null(south)
  cap <- function(x) {
    if (is.na(final_cap)) {
      return(x)
    }
    q <- stats::quantile(x, final_cap, names = FALSE, na.rm = TRUE)
    pmin(x, q)
  }

  # v2 birds: an infinite region prediction takes the median
  # (09.Predict.R:230-231)
  if (isTRUE(spatial$infinite_to_median)) {
    fix <- function(x) {
      if (is.null(x)) {
        return(x)
      }

      replace(x, is.infinite(x), stats::median(x))
    }
    north <- fix(north)
    south <- fix(south)
  }

  if (both || rule == "zero") {
    # Birds set a region the species is not modelled in to zero
    zero <- numeric(nrow(ctx$cells))
    return(cap((north %||% zero) * wN + (south %||% zero) * wS))
  }

  one <- if (!is.null(north)) "north" else "south"
  value <- if (one == "north") north else south

  if (rule == "na") {
    # Mammals: the region's own prediction, NA where its weight is
    # zero, then capped without the NAs (make-species-
    # predictions.R:628-647)
    weight <- if (one == "north") wN else wS
    value[weight == 0] <- NA_real_
    return(cap(value))
  }

  # Plants: capped first, then NA outside the region's natural
  # regions (04c:440-468)
  value <- cap(value)
  keep <- eval(spatial$region_mask[[one]][[2]], ctx$cells)
  value[!keep] <- NA_real_
  value
}

## 6.10 predict_draw() ----

#' One Draw's Full Prediction at the Output Cells
#'
#' @param set A coefficient set.
#' @param job The prediction job.
#' @param member The member whose saved objects to read.
#' @param full A prediction_context() of every computed cell
#'   (climate is capped over these).
#' @param out A prediction_context() of the output cells, whose
#'   rows index `full`.
#' @param out_index Integer. `out`'s rows within `full`.
#' @param config An experiment_config().
#' @param cap Logical. Apply the final cap.
#' @return A list of `climate`, `north`, `south`, `combined`, and
#'   the caps used.
#'
#' @example # Example usage of the function
#' # predict_draw(set, job, member, full, out, idx, config)
predict_draw <- function(set, job, member, full, out, out_index,
                         config, cap = TRUE) {
  spatial <- job$spatial
  climate_all <- predict_climate(set, member, full, spatial)

  # A capped map is mixed and capped over every computed cell, so
  # the final cap is the province's, then cut to the output cells.
  # The uncapped median-draw sample needs only its own cells.
  target <- if (cap) full else out
  keep <- if (cap) out_index else seq_len(nrow(out$cells))
  climate <- if (cap) climate_all else climate_all[out_index]

  north <- predict_region(set, "north", climate, target, job, member,
                          config)
  south <- predict_region(set, "south", climate, target, job, member,
                          config)

  if (is.null(north) && is.null(south)) {
    stop("No region has a habitat model for draw ", set$boot, ".",
         call. = FALSE)
  }

  final_cap <- if (cap) {
    species_final_cap(spatial, job$species)
  } else {
    NA_real_
  }
  combined <- combine_regions(north, south, target, spatial,
                              final_cap)

  list(
    climate = climate[keep],
    north = north[keep],
    south = south[keep],
    combined = combined[keep],
    climate_cap = max(climate_all, na.rm = TRUE),
    final_cap = final_cap
  )
}

## 6.11 species_final_cap() ----

#' A Species' Final Cap Quantile
#'
#' @param spatial The `spatial` settings.
#' @param species Character.
#' @return Numeric.
#'
#' @example # Example usage of the function
#' # species_final_cap(bird_spec()$spatial, "NOFL") # 0.99
species_final_cap <- function(spatial, species) {
  caps <- spatial$final_cap %||% 0.99

  if (length(caps) == 1) {
    return(unname(caps))
  }

  if (species %in% names(caps)) caps[[species]] else caps[["default"]]
}

# 7. Draw selection ----

## 7.1 select_median_draw() ----

#' The Draw Closest to the Per-Cell Median
#'
#' Every draw is predicted at the fixed sample (climate capped
#' over every computed cell, no final cap), put on the link
#' scale, and compared with the per-cell median across draws.
#' The draw with the smallest sum of squared differences is
#' chosen; ties go to the lowest draw number.
#'
#' @param sets A member_draws()-shaped list.
#' @param job,member,config As predict_draw().
#' @param full A prediction_context() of every computed cell.
#' @param sample Integer. Sample rows within `full`.
#' @param grid From load_spatial_grid().
#' @return A list of `boot` (the chosen draw) and `distance` (by
#'   draw).
#'
#' @example # Example usage of the function
#' # select_median_draw(sets, job, member, config, full, s, grid)
select_median_draw <- function(sets, job, member, config, full,
                               sample, grid) {
  if (length(sets) == 1) {
    return(list(boot = sets[[1]]$boot, distance = 0))
  }

  sample_ctx <- prediction_context(
    grid, full$rows[sample], full$scenario
  )
  scale <- if (job$spatial$link == "logit" &&
                 (job$spatial$combine %||% "mixture") == "mixture") {
    function(x) stats::qlogis(pmin(pmax(x, 1e-12), 1 - 1e-12))
  } else {
    function(x) log(pmax(x, .Machine$double.eps))
  }

  predicted <- vapply(sets, function(set) {
    p <- tryCatch(
      predict_draw(set, job, member, full, sample_ctx, sample,
                   config, cap = FALSE)$combined,
      error = function(e) rep(NA_real_, length(sample))
    )
    scale(p)
  }, numeric(length(sample)))

  centre <- apply(predicted, 1, stats::median, na.rm = TRUE)
  distance <- colSums((predicted - centre)^2, na.rm = TRUE)
  failed <- colSums(!is.na(predicted)) == 0
  distance[failed] <- Inf

  boots <- vapply(sets, `[[`, numeric(1), "boot")
  chosen <- boots[order(distance, boots)[1]]

  list(boot = chosen, distance = stats::setNames(distance, boots))
}

# 8. One species ----

## 8.1 predict_species_spatial() ----

#' Predict One Job: Every Scenario, by the Draw Rule
#'
#' @param job From spatial_jobs().
#' @param config An experiment_config().
#' @return A data.frame of summary rows, one per scenario,
#'   statistic and area; `status` says whether it worked.
#'
#' @example # Example usage of the function
#' # predict_species_spatial(jobs[[1]], config)
predict_species_spatial <- function(job, config) {
  settings <- config$prediction
  grid <- load_spatial_grid(settings$grid_dir)

  # Step 1: The coefficient sets, seasons pooled
  sets <- pool_seasons(lapply(job$members, member_draws,
                              config = config))
  member <- job$members[[1]]

  if (length(sets) == 0) {
    stop("No stored draws for ", job$species, ".", call. = FALSE)
  }

  # Step 2: The cells computed and written
  out_rows <- extent_cells(grid$cells, settings$extent)
  computed <- if (settings$caps_from == "province") {
    seq_len(nrow(grid$cells))
  } else {
    out_rows
  }
  out_index <- match(out_rows, computed)

  # Step 3: The draws to map. The median draw is chosen on the
  # current scenario and used for every scenario.
  draws <- settings$draws
  chosen <- NULL
  selection <- NULL

  if (identical(draws, "median") || identical(draws, "all")) {
    full <- prediction_context(grid, computed, "current")
    sample <- sample_cells_for_draws(
      full$cells, settings$sample_cells, config$seed %||% 20261027L
    )
    selection <- select_median_draw(
      sets, job, member, config, full, sample, grid
    )
    chosen <- selection$boot
  } else {
    missing_draws <- setdiff(draws, as.integer(names(sets)))

    if (length(missing_draws) > 0) {
      stop("Draw(s) not stored: ", paste(missing_draws,
                                          collapse = ", "),
           call. = FALSE)
    }
  }

  rows <- list()

  for (scenario in settings$scenarios) {
    full <- prediction_context(grid, computed, scenario)
    out <- prediction_context(grid, out_rows, scenario)
    maps <- list()
    per_draw <- NULL

    # Step 4: The chosen draw, then the others the rule asks for
    if (!is.null(chosen)) {
      per_draw <- predict_draw(sets[[as.character(chosen)]], job,
                               member, full, out, out_index, config)
      maps$median_draw <- per_draw$combined
    }

    extra <- if (identical(draws, "all")) {
      names(sets)
    } else if (is.numeric(draws)) {
      as.character(draws)
    } else {
      character(0)
    }

    if (length(extra) > 0) {
      n <- 0
      mean_x <- 0
      m2 <- 0

      for (b in extra) {
        one <- predict_draw(sets[[b]], job, member, full, out,
                            out_index, config)

        if (is.numeric(draws)) {
          maps[[paste0("draw", b)]] <- one$combined
          per_draw <- per_draw %||% one
        }

        # Welford's running mean and variance, cell by cell
        n <- n + 1
        delta <- one$combined - mean_x
        mean_x <- mean_x + delta / n
        m2 <- m2 + delta * (one$combined - mean_x)
      }

      if (length(extra) > 1) {
        maps$mean <- mean_x
        maps$sd <- sqrt(m2 / (n - 1))
      }
    }

    # Step 5: Write
    write_species_prediction(
      job, scenario, out, maps, per_draw, chosen, selection,
      config, grid
    )

    rows[[scenario]] <- summarise_prediction(
      job, scenario, out, maps, per_draw, chosen, sets, config, grid
    )
  }

  rbindlist(rows, fill = TRUE)
}

# 9. Writing ----

## 9.1 write_species_prediction() ----

#' Write One Species and Scenario: RDS, Rasters, Quick-Looks
#'
#' @param job,scenario,out,maps,per_draw,chosen,selection,config,grid
#'   From predict_species_spatial().
#' @return NULL, invisibly.
#'
#' @example # Example usage of the function
#' # write_species_prediction(...)
write_species_prediction <- function(job, scenario, out, maps,
                                     per_draw, chosen, selection,
                                     config, grid) {
  file_stem <- paste0(safe_name(job$species), "__", scenario)
  rds_dir <- file.path(config$pipeline_dir, "predictions", job$label)
  dir.create(rds_dir, recursive = TRUE, showWarnings = FALSE)

  saveRDS(
    list(
      species = job$species,
      run = job$label,
      runs = vapply(job$members, `[[`, character(1), "run"),
      scenario = scenario,
      grid = grid$label,
      LinkID = out$cells$LinkID,
      cell = out$cells$cell,
      chosen_draw = chosen,
      draw_distance = selection$distance,
      climate = per_draw$climate,
      north = per_draw$north,
      south = per_draw$south,
      maps = maps,
      caps = c(climate = per_draw$climate_cap,
               final = per_draw$final_cap),
      settings = unclass(config$prediction)
    ),
    file.path(rds_dir, paste0(file_stem, ".rds"))
  )

  outputs <- config$prediction$outputs

  if (!any(c("raster", "png") %in% outputs)) {
    return(invisible(NULL))
  }

  if (!requireNamespace("terra", quietly = TRUE) ||
        !requireNamespace("sciSpatialR", quietly = TRUE)) {
    stop("Rasters need the terra and sciSpatialR packages.",
         call. = FALSE)
  }

  map_dir <- file.path(config$out_dir, "maps", job$label)
  dir.create(map_dir, recursive = TRUE, showWarnings = FALSE)
  lattice <- sciSpatialR::ab_grid()

  for (stat in names(maps)) {
    r <- terra::rast(lattice)
    values <- rep(NA_real_, terra::ncell(r))
    values[out$cells$cell] <- maps[[stat]]
    terra::values(r) <- values
    names(r) <- paste(job$species, scenario, stat, sep = "_")

    if ("raster" %in% outputs) {
      terra::writeRaster(
        r, file.path(map_dir, paste0(file_stem, "__", stat, ".tif")),
        datatype = "FLT4S", overwrite = TRUE,
        gdal = c("COMPRESS=DEFLATE", "TILED=YES")
      )
    }

    if ("png" %in% outputs) {
      png_dir <- file.path(map_dir, "png")
      dir.create(png_dir, showWarnings = FALSE)
      grDevices::png(
        file.path(png_dir, paste0(file_stem, "__", stat, ".png")),
        width = 900, height = 1400, res = 150
      )
      terra::plot(r, main = paste(job$species, scenario, stat))
      grDevices::dev.off()
    }
  }

  invisible(NULL)
}

## 9.2 summarise_prediction() ----

#' Summary Rows for One Species and Scenario
#'
#' Totals are area-weighted by AreaKm2 and, as v2 reports them,
#' unweighted (a sum over cells).
#'
#' @param job,scenario,out,maps,per_draw,chosen,sets,config,grid
#'   From predict_species_spatial().
#' @return A data.table, one row per statistic and area.
#'
#' @example # Example usage of the function
#' # summarise_prediction(...)
summarise_prediction <- function(job, scenario, out, maps, per_draw,
                                 chosen, sets, config, grid) {
  areas <- list()

  if ("province" %in% config$prediction$summaries) {
    label <- if (is.null(config$prediction$extent)) {
      "province"
    } else {
      paste0("extent: ", extent_label(config$prediction$extent))
    }
    areas[[label]] <- rep(TRUE, nrow(out$cells))
  }

  if ("natural_region" %in% config$prediction$summaries) {
    for (nr in sort(unique(out$cells$NrName))) {
      areas[[nr]] <- out$cells$NrName == nr
    }
  }

  rbindlist(lapply(names(maps), function(stat) {
    x <- maps[[stat]]

    rbindlist(lapply(names(areas), function(area) {
      keep <- areas[[area]]
      v <- x[keep]
      data.table(
        run = job$label,
        taxon = job$taxon,
        species = job$species,
        scenario = scenario,
        draws = paste(config$prediction$draws, collapse = ","),
        n_draws = length(sets),
        chosen_draw = chosen %||% NA_integer_,
        stat = stat,
        area = area,
        cells = sum(keep),
        na_cells = sum(is.na(v)),
        mean = mean(v, na.rm = TRUE),
        median = stats::median(v, na.rm = TRUE),
        q99 = stats::quantile(v, 0.99, names = FALSE, na.rm = TRUE),
        max = max(v, na.rm = TRUE),
        total_area_weighted = sum(v * out$cells$AreaKm2[keep],
                                  na.rm = TRUE),
        total_unweighted = sum(v, na.rm = TRUE),
        climate_cap_value = per_draw$climate_cap,
        final_cap = per_draw$final_cap,
        status = "ok",
        note = NA_character_,
        grid = grid$label
      )
    }))
  }))
}

# 10. run_spatial_predictions() ----

#' The Predict Step: Every Job, Then the Summary Table
#'
#' @param config An experiment_config() with `prediction`.
#' @return A data.table, the summary rows, invisibly; also
#'   written to tables/prediction_summary.csv when "table" is in
#'   `outputs`.
#'
#' @example # Example usage of the function
#' # run_spatial_predictions(config)
run_spatial_predictions <- function(config) {
  settings <- config$prediction
  jobs <- spatial_jobs(config)

  if (length(jobs) == 0) {
    message("Prediction: nothing to predict.")
    return(invisible(NULL))
  }

  workers <- min(settings$workers %||% config$workers, length(jobs))
  cat("Predicting ", length(jobs), " species on ", workers,
      " worker(s): ", prediction_label(settings), "\n", sep = "")

  results <- if (workers <= 1) {
    lapply(jobs, function(job) {
      out <- predict_job_worker(list(job = job, config = config))
      cat(".")
      out
    })
  } else {
    # As run_jobs(): workers load the framework, with the hooks
    project_root <- getOption("sdm.project_root")

    if (is.null(project_root)) {
      stop("Parallel prediction needs load_framework() to have ",
           "been called.", call. = FALSE)
    }

    cluster <- parallel::makePSOCKcluster(workers)
    on.exit(parallel::stopCluster(cluster), add = TRUE)
    parallel::clusterCall(cluster, load_worker, project_root,
                          getOption("sdm.hook_files"))
    tasks <- lapply(jobs, function(job) {
      list(job = job, config = config)
    })
    parallel::clusterApplyLB(cluster, tasks, predict_job_worker)
  }

  cat("\n")
  summary <- rbindlist(results, fill = TRUE)
  failed <- unique(summary[summary$status != "ok",
                           c("run", "species", "note")])

  if (nrow(failed) > 0) {
    message(
      "Prediction failed for ", nrow(failed), " species:\n  ",
      paste0(failed$run, " ", failed$species, ": ", failed$note,
             collapse = "\n  ")
    )
  }

  if ("table" %in% settings$outputs) {
    tables <- file.path(config$out_dir, "tables")
    dir.create(tables, recursive = TRUE, showWarnings = FALSE)
    fwrite(summary, file.path(tables, "prediction_summary.csv"),
           na = "")
  }

  invisible(summary)
}

## 10.1 predict_job_worker() ----

#' Predict One Job, Here or in a Background Session
#'
#' A failed species is logged as a row, not an error, so the
#' rest still run.
#'
#' @param task List of `job` (from spatial_jobs()) and `config`.
#' @return Summary rows, as predict_species_spatial().
#'
#' @example # Example usage of the function
#' # predict_job_worker(list(job = jobs[[1]], config = config))
predict_job_worker <- function(task) {
  job <- task$job
  config <- task$config
  started <- Sys.time()
  tryCatch(
    {
      rows <- predict_species_spatial(job, config)
      rows$seconds <- as.numeric(difftime(Sys.time(), started,
                                          units = "secs"))
      rows
    },
    error = function(e) {
      data.table(
        run = job$label, taxon = job$taxon, species = job$species,
        status = "error", note = conditionMessage(e)
      )
    }
  )
}

# End of script ----
