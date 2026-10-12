# ---
# title: Load the Harmonized Test Dataset
# author: Brendan Casey
# created: 2026-09-09
# inputs:
#   in the test dataset (see harness/data_source.R):
#     - sites.csv
#     - covariates.csv
#     - each taxon's response and offset files, as named in
#       lookup/dataset_manifest.csv
#     - lookup/factor_levels.csv
# outputs: none; returns objects in memory
# notes:
#   - Taxon-agnostic: file locations and covariate keys come from
#     lookup/dataset_manifest.csv (_setup/07). The key is
#     `<taxon>_<region>` for mammals, whose north and south files
#     hold different values for the same deployment.
#   - Reads are column-selective (covariates.csv is ~218 MB, 457
#     columns). build_model_data() loads once per taxon and
#     region; model_frame() cuts per-species frames from it.
#   - Derivable covariates are computed on load (needs
#     covariate_sets.R); an experiment's covariate_files are
#     joined on load, so 0_data/ is never changed.
#   - TODO: a Parquet or duckdb store would allow row selection.
# ---

# 1. Setup ----

## 1.1 Load packages ----
library(data.table) # column-selective CSV reading (version: 1.16.4)

# 2. The dataset manifest ----

## 2.1 dataset_manifest() ----

#' Read Where Each Taxon's Files Are
#'
#' One row per taxon and region.
#'
#' @param data_dir Character. The test dataset folder.
#' @return A data frame.
#'
#' @example # Example usage of the function
#' # dataset_manifest(data_dir)
dataset_manifest <- function(data_dir) {
  path <- file.path(data_dir, "lookup", "dataset_manifest.csv")

  if (!file.exists(path)) {
    stop(
      "Dataset manifest not found:
  ", path,
      "
Run 1_code/_setup/07_harmonize_lookups.R first.",
      call. = FALSE
    )
  }

  cached_read(path, function(p) {
    as.data.frame(fread(p, na.strings = "", colClasses = "character"))
  })
}

## 2.2 manifest_entry() ----

#' One Taxon's Manifest Row
#'
#' @param data_dir Character. The test dataset folder.
#' @param taxon Character. Taxon slug.
#' @param region Character, or NULL for the taxon's first region,
#'   which is enough for anything that does not vary by region.
#' @return A one-row data frame.
#'
#' @example # Example usage of the function
#' # manifest_entry(data_dir, "mammal", "north")$covariate_key
manifest_entry <- function(data_dir, taxon, region = NULL) {
  manifest <- dataset_manifest(data_dir)
  rows <- manifest[manifest$taxon == taxon, ]

  if (nrow(rows) == 0) {
    stop(
      "Taxon `", taxon, "` is not in the dataset manifest. Taxa: ",
      paste(unique(manifest$taxon), collapse = ", "),
      call. = FALSE
    )
  }

  if (!is.null(region)) {
    rows <- rows[rows$region == region, ]

    if (nrow(rows) == 0) {
      stop(
        "The manifest has no region `", region, "` for ", taxon,
        ".", call. = FALSE
      )
    }
  }

  rows[1, , drop = FALSE]
}

## 2.3 covariate_key() ----

#' Name a Taxon's Key in covariates.csv
#'
#' @param taxon Character. Taxon slug.
#' @param region Character, or NULL when the taxon's covariates
#'   are not stored per region.
#' @param data_dir Character. The test dataset folder.
#' @return Character. The value to match in the `taxon` column of
#'   covariates.csv.
#'
#' @example # Example usage of the function
#' # covariate_key("mammal", "north", data_dir) # "mammal_north"
#' # covariate_key("bryophyte", NULL, data_dir) # "bryophyte"
covariate_key <- function(taxon, region = NULL, data_dir) {
  if (is.null(region)) {
    return(taxon)
  }

  manifest_entry(data_dir, taxon, region)$covariate_key
}

# 3. load_sites() ----

#' Load the Survey Unit Table
#'
#' One row per survey unit across every design, with an
#' `in_<taxon>` coverage flag per taxon.
#'
#' @param data_dir Character. The test dataset folder.
#' @param taxon Character. Keep only units that taxon covers, or
#'   NULL for every unit.
#' @param columns Character vector of columns to read, or NULL
#'   for all of them.
#' @return A data frame, one row per survey unit.
#'
#' @example # Example usage of the function
#' # sites <- load_sites(test_dataset_dir(), taxon = "bird")
#' # nrow(sites)
load_sites <- function(data_dir, taxon = NULL, columns = NULL) {
  path <- file.path(data_dir, "sites.csv")
  check_dataset_file(path)

  # Step 1: Read the coverage flag even if not requested
  flag <- if (is.null(taxon)) NULL else paste0("in_", taxon)

  if (!is.null(columns)) {
    columns <- unique(c("survey_unit_id", columns, flag))
    sites <- as.data.frame(fread(path, select = columns))
  } else {
    sites <- as.data.frame(fread(path))
  }

  # Step 2: Narrow to the units the taxon covers
  if (!is.null(flag)) {
    if (!flag %in% names(sites)) {
      stop(
        "sites.csv has no coverage flag `", flag, "`. Taxa in ",
        "this dataset: ",
        paste(
          sub("^in_", "", grep("^in_", names(sites), value = TRUE)),
          collapse = ", "
        ),
        call. = FALSE
      )
    }

    sites <- sites[!is.na(sites[[flag]]) & sites[[flag]], ]
  }

  rownames(sites) <- NULL

  sites
}

# 4. load_response() ----

#' Load One Taxon's Response Table
#'
#' Values are as recorded (plant detections, mammal densities,
#' bird counts); model_frame() applies the spec's transform.
#'
#' @param taxon Character. Taxon slug.
#' @param data_dir Character. The test dataset folder.
#' @param species Character vector of species columns to read, or
#'   NULL for all of them.
#' @return A data frame of survey_unit_id and species columns.
#'
#' @example # Example usage of the function
#' # y <- load_response("bryophyte", data_dir,
#' #                    species = "Aulacomnium.palustre")
load_response <- function(taxon, data_dir, species = NULL) {
  path <- file.path(
    data_dir, manifest_entry(data_dir, taxon)$response_file
  )
  check_dataset_file(path)

  if (is.null(species)) {
    return(as.data.frame(fread(path)))
  }

  # Step 1: Fail on an unknown species
  available <- names(fread(path, nrows = 0))
  unknown <- setdiff(species, available)

  if (length(unknown) > 0) {
    stop(
      length(unknown), " species not in ", basename(path), ":\n  ",
      paste(utils::head(unknown, 10), collapse = "\n  "),
      call. = FALSE
    )
  }

  as.data.frame(
    fread(path, select = unique(c("survey_unit_id", species)))
  )
}

# 5. load_offsets() ----

#' Load One Taxon's Offsets
#'
#' Only birds have offsets (QPAD log-offsets per unit and
#' species). Other taxa return NULL, not zeros: a zero offset is
#' a modelling choice.
#'
#' @param taxon Character. Taxon slug.
#' @param data_dir Character. The test dataset folder.
#' @param species Character vector of species columns to read, or
#'   NULL for all of them.
#' @return A data frame of survey_unit_id and species columns, or
#'   NULL when the taxon has no offsets file.
#'
#' @example # Example usage of the function
#' # off <- load_offsets("bird", data_dir, species = "ALFL")
load_offsets <- function(taxon, data_dir, species = NULL) {
  offset_file <- manifest_entry(data_dir, taxon)$offset_file

  if (is.na(offset_file)) {
    return(NULL)
  }

  path <- file.path(data_dir, offset_file)
  check_dataset_file(path)

  if (is.null(species)) {
    return(as.data.frame(fread(path)))
  }

  available <- names(fread(path, nrows = 0))
  present <- intersect(species, available)

  if (length(present) == 0) {
    return(NULL)
  }

  as.data.frame(
    fread(path, select = unique(c("survey_unit_id", present)))
  )
}

# 6. load_covariates() ----

#' Load Covariates for One Taxon and Region
#'
#'
#' @param taxon Character. Taxon slug.
#' @param data_dir Character. The test dataset folder.
#' @param columns Character vector of master column names.
#' @param region Character. Region name, or NULL when the taxon's
#'   covariates are not stored per region.
#' @return A data frame of survey_unit_id and the requested
#'   columns.
#'
#' @example # Example usage of the function
#' # x <- load_covariates("mammal", data_dir,
#' #                      columns = c("MAT", "MAP"),
#' #                      region = "north")
load_covariates <- function(
  taxon,
  data_dir,
  columns,
  region = NULL
) {
  path <- file.path(data_dir, "covariates.csv")
  check_dataset_file(path)

  key <- covariate_key(taxon, region, data_dir)

  # Step 1: Check the taxon's catalogue, not the file header: the
  # wide table holds other taxa's columns, which read back as all
  # NA here.
  stored <- available_covariates(
    taxon, data_dir = data_dir, region = region,
    include_derived = FALSE
  )

  derivable <- derivable_covariates(columns, stored)
  to_read <- setdiff(columns, derivable)

  for (one in derivable) {
    to_read <- unique(c(to_read, derived_covariates()[[one]]$inputs))
  }

  unknown <- setdiff(to_read, stored)

  if (length(unknown) > 0) {
    stop(
      length(unknown), " covariate(s) not available for ", taxon,
      if (is.null(region)) "" else paste0(" (", region, ")"),
      ":\n  ",
      paste(utils::head(unknown, 10), collapse = "\n  "),
      "\nThey may exist for another taxon; covariates.csv is one",
      "\nwide table, so this taxon's rows would be all NA.",
      call. = FALSE
    )
  }

  # Step 2: Read only columns not already cached for this key;
  # stages request overlapping column sets.
  info <- file.info(path)
  cache_key <- paste(
    "covariates", normalizePath(path, winslash = "/"),
    format(info$mtime, "%Y%m%d%H%M%OS3"), info$size, key,
    sep = "|"
  )
  held <- if (exists(cache_key, envir = .sdm_cache)) {
    get(cache_key, envir = .sdm_cache)
  } else {
    NULL
  }
  to_load <- setdiff(to_read, names(held))

  if (is.null(held) || length(to_load) > 0) {
    fresh <- fread(
      path, select = unique(c("survey_unit_id", "taxon", to_load))
    )

    fresh <- fresh[fresh$taxon == key, ]

    if (nrow(fresh) == 0) {
      keys <- unique(fread(path, select = "taxon")$taxon)
      stop(
        "No covariate rows for key `", key, "`. Keys present: ",
        paste(keys, collapse = ", "),
        call. = FALSE
      )
    }

    fresh[, taxon := NULL]
    fresh <- as.data.frame(fresh)

    held <- if (is.null(held)) {
      fresh
    } else {
      # Rows always come back in file order, so columns line up
      cbind(held, fresh[, to_load, drop = FALSE])
    }

    assign(cache_key, held, envir = .sdm_cache)
  }

  covariates <- held[, unique(c("survey_unit_id", to_read)),
                     drop = FALSE]

  # Step 3: Derive, then return exactly the requested columns
  if (length(derivable) > 0) {
    covariates <- apply_derivations(covariates, derivable)
  }

  covariates[, unique(c("survey_unit_id", columns)), drop = FALSE]
}

## 6.1 check_covariate_files() ----

#' Check the Covariate Files an Experiment Adds
#'
#' Each file must have a unique survey_unit_id key and only
#' columns no other source has.
#'
#' @param files Character vector of CSV paths.
#' @param data_dir Character. The test dataset folder.
#' @return `files`, invisibly; stops on the first problem.
#'
#' @example # Example usage of the function
#' # check_covariate_files("2_pipeline/exp_002/inputs/soil.csv",
#' #                       data_dir)
check_covariate_files <- function(files, data_dir) {
  taken <- names(fread(file.path(data_dir, "covariates.csv"),
                       nrows = 0))

  for (path in files) {
    if (!file.exists(path)) {
      stop(
        "Covariate file not found: ", path, "\nRun the ",
        "experiment's script that writes it first.",
        call. = FALSE
      )
    }

    header <- names(fread(path, nrows = 0))

    if (!"survey_unit_id" %in% header) {
      stop("Covariate file ", basename(path), " has no ",
           "survey_unit_id column.", call. = FALSE)
    }

    ids <- fread(path, select = "survey_unit_id",
                 colClasses = "character")$survey_unit_id

    if (anyDuplicated(ids) > 0) {
      stop("Covariate file ", basename(path), " repeats a ",
           "survey_unit_id; it needs one row per unit.",
           call. = FALSE)
    }

    added <- setdiff(header, "survey_unit_id")
    clash <- intersect(added, taken)

    if (length(clash) > 0) {
      stop(
        "Covariate file ", basename(path), " repeats column(s) ",
        "already in covariates.csv or another file: ",
        paste(utils::head(clash, 10), collapse = ", "),
        ". Give them new names.",
        call. = FALSE
      )
    }

    taken <- c(taken, added)
  }

  invisible(files)
}

## 6.2 covariate_file_columns() ----

#' The Columns a Set of Covariate Files Holds
#'
#' @param files Character vector of CSV paths, or NULL.
#' @return A character vector of column names, without
#'   survey_unit_id.
#'
#' @example # Example usage of the function
#' # covariate_file_columns("2_pipeline/exp_002/inputs/soil.csv")
covariate_file_columns <- function(files) {
  unique(unlist(lapply(files, function(path) {
    setdiff(names(fread(path, nrows = 0)), "survey_unit_id")
  })))
}

## 6.3 add_covariate_files() ----

#' Join Covariates from an Experiment's Own Files
#'
#' Units a file does not list get NA and drop out of models that
#' use the column.
#'
#' @param x A data frame with survey_unit_id, from
#'   load_covariates().
#' @param files Character vector of CSV paths, or NULL.
#' @param columns Character vector of the columns to add.
#' @return `x` with the columns added.
#'
#' @example # Example usage of the function
#' # add_covariate_files(x, "2_pipeline/exp_002/inputs/soil.csv",
#' #                     "sg_clay_0_5cm")
add_covariate_files <- function(x, files, columns) {
  for (path in files) {
    table <- cached_read(path, function(p) {
      as.data.frame(fread(
        p, colClasses = list(character = "survey_unit_id")
      ))
    }, tag = "covariate_file")

    wanted <- setdiff(
      intersect(columns, names(table)),
      c("survey_unit_id", names(x))
    )

    if (length(wanted) == 0) {
      next
    }

    rows <- match(as.character(x$survey_unit_id),
                  table$survey_unit_id)
    x[wanted] <- table[rows, wanted, drop = FALSE]
  }

  x
}

# 7. apply_factor_levels() ----

#' Restore Stored Factor Levels
#'
#' CSV reads categoricals back as character, and alphabetical
#' factoring would change the reference level and every contrast.
#' Restores the source order from lookup/factor_levels.csv. An
#' unknown level is an error: the lookup is stale.
#'
#' @param frame A data frame.
#' @param data_dir Character. The test dataset folder.
#' @param taxon Character. Taxon slug.
#' @return The frame, with the recorded columns as factors.
#'
#' @example # Example usage of the function
#' # apply_factor_levels(frame, data_dir, "bird")
apply_factor_levels <- function(frame, data_dir, taxon) {
  path <- file.path(data_dir, "lookup", "factor_levels.csv")
  check_dataset_file(path)

  levels_table <- cached_read(
    path, function(p) as.data.frame(fread(p))
  )
  levels_table <- levels_table[levels_table$taxon == taxon, ]

  if (nrow(levels_table) == 0) {
    return(frame)
  }

  # Also match block-suffixed columns (e.g. bird `method` as
  # method_veg, method_soil) via covariate_columns.csv
  map_path <- file.path(data_dir, "lookup", "covariate_columns.csv")
  column_map <- if (file.exists(map_path)) {
    map <- covariate_catalogue(data_dir)
    map[map$taxon == taxon, c("source_column", "master_column")]
  } else {
    data.frame(source_column = character(0),
               master_column = character(0))
  }

  targets_of <- function(column) {
    masters <- column_map$master_column[
      column_map$source_column == column
    ]
    intersect(unique(c(column, masters)), names(frame))
  }

  for (source_column in unique(levels_table$column)) {
    rows <- levels_table[levels_table$column == source_column, ]
    ordered_levels <- rows$level[order(rows$level_order)]

    for (column in targets_of(source_column)) {
      frame[[column]] <- restore_factor(
        frame[[column]], ordered_levels, taxon, column
      )
    }
  }

  frame
}

## 7.1 restore_factor() ----

#' Factor One Column to a Stored Level Order
#'
#' @param x A vector as read from CSV.
#' @param ordered_levels Character vector of levels, reference
#'   first.
#' @param taxon,column Character. Named in any error.
#' @return A factor.
#'
#' @example # Example usage of the function
#' # restore_factor(c("PC", "eBird"), c("PC", "eBird"), "bird", "m")
restore_factor <- function(x, ordered_levels, taxon, column) {
  values <- as.character(x)

  # Tables are written with `na = ""`, so a missing value reads
  # back as "" and would fail the level guard (e.g. blank `soilc`
  # in 194 southern bird surveys). Restoring NA matches v2, where
  # glm drops those rows.
  values[!nzchar(trimws(values))] <- NA_character_

  unknown <- setdiff(stats::na.omit(unique(values)), ordered_levels)

  if (length(unknown) > 0) {
    stop(
      taxon, ": `", column, "` holds ", length(unknown),
      " level(s) the factor lookup does not list:
",
      paste(utils::head(unknown, 10), collapse = "
"),
      "
The lookup is stale; admitting them would change the",
      "
reference level and every contrast.",
      call. = FALSE
    )
  }

  factor(values, levels = ordered_levels)
}

# 8. build_model_data() ----

#' Assemble Everything One Taxon and Region Needs
#'
#' Loaded once per taxon and region, aligned on survey_unit_id;
#' re-reading per species would cost more than fitting.
#'
#' @param taxon Character. Taxon slug.
#' @param data_dir Character. The test dataset folder.
#' @param species Character vector of species to model.
#' @param covariates Character vector of master column names.
#' @param region Character. Region name, or NULL.
#' @param region_filter A one-sided formula evaluated against the
#'   assembled frame, or NULL. Rows where it is not TRUE are
#'   dropped (e.g. ~ nr != "Grassland").
#' @param weight_column Character. A covariate to use as model
#'   weights; loaded automatically.
#' @param aliases Named list, alias to source column. Lets a
#'   model set name a column the dataset stores otherwise.
#' @param site_columns Character vector of sites.csv columns to
#'   carry, beyond survey_unit_id, or NULL for site_columns().
#' @param covariate_files Character vector of an experiment's own
#'   covariate CSVs, or NULL. Columns they hold are read from them
#'   rather than from covariates.csv.
#' @return A list with `covariates` (one row per unit, including
#'   the site columns), `response`, `offset` (or NULL), `units`,
#'   `taxon` and `region`.
#'
#' @example # Example usage of the function
#' # md <- build_model_data(
#' #   taxon = "bryophyte", data_dir = data_dir,
#' #   species = "Aulacomnium.palustre",
#' #   covariates = c("MAT", "MAP"),
#' #   region_filter = ~ nr != "Grassland")
build_model_data <- function(
  taxon,
  data_dir,
  species,
  covariates,
  region = NULL,
  region_filter = NULL,
  weight_column = NULL,
  aliases = list(),
  site_columns = NULL,
  covariate_files = NULL
) {
  site_columns <- site_columns %||% site_columns()

  # Step 1: Read each piece, narrowed to what was asked for
  if (!is.null(weight_column)) {
    covariates <- unique(c(covariates, weight_column))
  }

  from_files <- intersect(
    covariates, covariate_file_columns(covariate_files)
  )
  x <- load_covariates(
    taxon, data_dir, setdiff(covariates, from_files), region
  )
  x <- add_covariate_files(x, covariate_files, from_files)
  y <- load_response(taxon, data_dir, species)
  off <- load_offsets(taxon, data_dir, species)
  sites <- load_sites(data_dir, taxon, site_columns)

  # Step 2: Keep units present in covariates, response and sites
  units <- intersect(
    as.character(x$survey_unit_id), as.character(y$survey_unit_id)
  )
  units <- intersect(units, as.character(sites$survey_unit_id))

  if (length(units) == 0) {
    stop(
      "No survey units shared between the covariates, the ",
      "response and sites.csv for ", taxon,
      if (is.null(region)) "" else paste0(" (", region, ")"),
      ".",
      call. = FALSE
    )
  }

  align <- function(frame) {
    frame[match(units, as.character(frame$survey_unit_id)), ,
          drop = FALSE]
  }

  x <- align(x)
  site_rows <- align(sites)

  # Step 3: Join the site fields onto the covariates, so a region
  # filter can name either
  keep <- setdiff(names(site_rows), names(x))
  frame <- cbind(x, site_rows[, keep, drop = FALSE])
  rownames(frame) <- NULL

  # Step 3b: Restore factor levels before the region filter
  frame <- apply_factor_levels(frame, data_dir, taxon)

  # Step 3c: Aliases, e.g. mammal `seas_days` is summer_days or
  # winter_days depending on the season modelled
  for (alias in names(aliases)) {
    source_column <- aliases[[alias]]

    if (!source_column %in% names(frame)) {
      stop(
        "Cannot alias `", alias, "` to `", source_column,
        "`: no such column.",
        call. = FALSE
      )
    }

    frame[[alias]] <- frame[[source_column]]
  }

  # Step 4: Apply the spec's region filter
  if (!is.null(region_filter)) {
    keep_rows <- eval(
      rlang_f_rhs(region_filter),
      envir = frame,
      enclos = parent.frame()
    )

    if (!is.logical(keep_rows) || length(keep_rows) != nrow(frame)) {
      stop(
        "region_filter must evaluate to one logical value per ",
        "survey unit; got ", class(keep_rows)[1], " of length ",
        length(keep_rows), ".",
        call. = FALSE
      )
    }

    keep_rows[is.na(keep_rows)] <- FALSE
    frame <- frame[keep_rows, , drop = FALSE]
    units <- units[keep_rows]
    rownames(frame) <- NULL
  }

  if (nrow(frame) == 0) {
    stop(
      "The region filter removed every survey unit for ", taxon,
      if (is.null(region)) "" else paste0(" (", region, ")"),
      ".",
      call. = FALSE
    )
  }

  list(
    covariates = frame,
    response = align_to_units(y, units),
    offset = if (is.null(off)) NULL else align_to_units(off, units),
    units = units,
    taxon = taxon,
    region = region
  )
}

# 9. model_frame() ----

#' Cut a One-Species Modelling Frame
#'
#' Adds one species' response, offset and weight under fixed
#' names, so formulas and engines never name the species.
#'
#' @param model_data A list from build_model_data().
#' @param species Character. One species column.
#' @param transform Character or function. "identity", or
#'   "detection" (value > 0 becomes 1, as in the plant scripts).
#'   A function taking two arguments also gets the frame (e.g.
#'   the mammal lure correction needs `lured` and `location`).
#' @param weight_column Character. A covariate column to use as
#'   model weights, or NULL.
#' @param response_name,offset_name,weight_name Character. Column
#'   names to write into the frame.
#' @return A data frame with the covariates plus the response,
#'   and the offset and weight when they apply.
#'
#' @example # Example usage of the function
#' # d <- model_frame(md, "Aulacomnium.palustre",
#' #                  transform = "detection")
model_frame <- function(
  model_data,
  species,
  transform = "identity",
  weight_column = NULL,
  response_name = "response",
  offset_name = "offset",
  weight_name = "weight"
) {
  if (!species %in% names(model_data$response)) {
    stop(
      "`", species, "` is not a column of the ",
      model_data$taxon, " response table.",
      call. = FALSE
    )
  }

  frame <- model_data$covariates
  values <- model_data$response[[species]]

  # Step 1: Apply the response transform, keeping raw values for
  # stages that transform differently (the mammal climate stage
  # fits presence even in the abundance run)
  frame[[paste0(response_name, "_raw")]] <- values

  frame[[response_name]] <- apply_response_transform(
    values, transform, frame
  )

  # Step 2: Attach the offset. A species missing from the offsets
  # file is an error, not a silent zero offset.
  if (!is.null(model_data$offset)) {
    if (!species %in% names(model_data$offset)) {
      stop(
        "`", species, "` has no offset in the ", model_data$taxon,
        " offsets file, but the taxon uses offsets.",
        call. = FALSE
      )
    }

    frame[[offset_name]] <- model_data$offset[[species]]
  }

  # Step 3: Attach weights, named as a covariate column
  if (!is.null(weight_column)) {
    if (!weight_column %in% names(frame)) {
      stop(
        "Weight column `", weight_column, "` is not among the ",
        "loaded covariates.",
        call. = FALSE
      )
    }

    frame[[weight_name]] <- frame[[weight_column]]
  }

  frame
}

# 10. Helpers ----

## 10.1 check_dataset_file() ----

#' Fail Clearly on a Missing Dataset File
#'
#' @param path Character. Path to check.
#' @return NULL, invisibly. Stops when the file is absent.
#'
#' @example # Example usage of the function
#' # check_dataset_file(file.path(data_dir, "sites.csv"))
check_dataset_file <- function(path) {
  if (!file.exists(path)) {
    stop(
      "Test dataset file not found:\n  ", path,
      "\nRun 1_code/_setup/01_harmonize_model_ready_v2.R first.",
      call. = FALSE
    )
  }

  invisible(NULL)
}

## 10.2 site_columns() ----

#' The Site Fields Every Model Frame Carries
#'
#' Read from sites.csv, so filters and formulas can name them
#' without loading them as covariates.
#'
#' @return A character vector of sites.csv column names.
#'
#' @example # Example usage of the function
#' # site_columns()
site_columns <- function() {
  c(
    "lat", "long", "easting", "northing", "nr", "nsr", "luf", "year",
    "lured", "location", "summer_days", "winter_days"
  )
}

## 10.3 align_to_units() ----

#' Put a Keyed Frame in a Given Survey Unit Order
#'
#' @param frame A data frame with a survey_unit_id column.
#' @param units Character vector of survey unit ids.
#' @return The frame, reordered, with survey_unit_id first.
#'
#' @example # Example usage of the function
#' # align_to_units(response, units)
align_to_units <- function(frame, units) {
  out <- frame[
    match(units, as.character(frame$survey_unit_id)), ,
    drop = FALSE
  ]
  rownames(out) <- NULL

  out
}

## 10.4 apply_response_transform() ----

#' Turn a Recorded Value into a Modelling Response
#'
#' @param values Numeric vector as recorded.
#' @param transform Character ("identity" or "detection") or a
#'   function.
#' @param frame The assembled frame, passed to a transform that
#'   takes a second argument.
#' @return A numeric vector.
#'
#' @example # Example usage of the function
#' # apply_response_transform(c(0, 0.4, 2), "detection")
apply_response_transform <- function(
  values, transform, frame = NULL
) {
  if (is.function(transform)) {
    # A two-argument transform also gets the frame
    if (length(formals(transform)) > 1) {
      return(transform(values, frame))
    }

    return(transform(values))
  }

  switch(
    transform,
    identity = values,
    detection = as.integer(ifelse(values > 0, 1L, 0L)),
    stop(
      "Unknown response transform `", transform,
      "`. Use \"identity\", \"detection\", or a function.",
      call. = FALSE
    )
  )
}

## 10.5 rlang_f_rhs() ----

#' Take the Right-Hand Side of a One-Sided Formula
#'
#' Local helper to avoid an rlang dependency.
#'
#' @param f A one-sided formula, e.g. ~ nr != "Grassland".
#' @return The unevaluated right-hand side.
#'
#' @example # Example usage of the function
#' # rlang_f_rhs(~ nr != "Grassland")
rlang_f_rhs <- function(f) {
  if (!inherits(f, "formula")) {
    stop("Expected a one-sided formula.", call. = FALSE)
  }

  f[[length(f)]]
}

# End of script ----
