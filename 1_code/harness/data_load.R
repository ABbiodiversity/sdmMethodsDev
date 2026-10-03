# ---
# title: Load the Harmonized Test Dataset
# author: Brendan Casey
# created: 2026-09-09
# inputs:
#   in 0_data/test_dataset/:
#     - sites.csv
#     - covariates.csv
#     - each taxon's response and offset files, as named in
#       lookup/dataset_manifest.csv
#     - lookup/factor_levels.csv
# outputs: none; returns objects in memory
# notes:
#   - The taxon-agnostic data layer. Every reader takes the taxon
#     as an argument and knows nothing else about it; what a taxon
#     means is carried by its spec, not by this file.
#   - Where each taxon's files are, and the key its rows carry in
#     covariates.csv, is read from lookup/dataset_manifest.csv
#     (written by _setup/09). Nothing here names a taxon. The key
#     is the taxon for most taxa, but the taxon and region for
#     mammals, whose north and south files carry different values
#     for the same deployment.
#   - Reading is column-selective. covariates.csv is 218 MB and
#     457 columns wide; a run wants a handful, so every reader
#     takes the columns it needs rather than loading the table.
#   - build_model_data() loads once per taxon and region, and
#     model_frame() then cuts a per-species frame out of it. A
#     bird run is 215,758 units by 172 species, so re-reading per
#     species would dominate the run time.
#   - covariates.csv is one wide table across every taxon, so a
#     column another taxon carries reads back as all NA here.
#     load_covariates() checks the per-taxon catalogue rather
#     than the file header for that reason.
#   - A covariate a taxon does not store but can be computed from
#     ones it does is derived on load, through the registry in
#     covariate_sets.R. That is how mammals reach TD, which their
#     own climate model set needs and their source file lacks.
#     Requires covariate_sets.R to be sourced first.
#   - Future improvement - a Parquet or duckdb backing store
#     would let a bird run select rows as well as columns.
# ---

# 1. Setup ----

## 1.1 Load packages ----
library(data.table) # column-selective CSV reading (version: 1.16.4)

# 2. The dataset manifest ----

## 2.1 dataset_manifest() ----

#' Read Where Each Taxon's Files Are
#'
#' One row per taxon and region: the response file, the offset
#' file, the covariate key, the habitat prediction grid, and any
#' stored bootstrap draws.
#'
#' @param data_dir Character. Path to 0_data/test_dataset.
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
Run 1_code/_setup/09_harmonize_lookups.R first.",
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
#' @param data_dir Character. Path to 0_data/test_dataset.
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
#' @param data_dir Character. Path to 0_data/test_dataset.
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
#' One row per survey unit across every design. Carries the
#' identity, design and location fields the covariate tables
#' factor out, and an `in_<taxon>` flag per taxon.
#'
#' @param data_dir Character. Path to 0_data/test_dataset.
#' @param taxon Character. Keep only units that taxon covers, or
#'   NULL for every unit.
#' @param columns Character vector of columns to read, or NULL
#'   for all of them.
#' @return A data frame, one row per survey unit.
#'
#' @example # Example usage of the function
#' # sites <- load_sites("0_data/test_dataset", taxon = "bird")
#' # nrow(sites)
load_sites <- function(data_dir, taxon = NULL, columns = NULL) {
  path <- file.path(data_dir, "sites.csv")
  check_dataset_file(path)

  # Step 1: The coverage flag has to be read even when it is not
  # among the requested columns, or the filter cannot be applied
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
#' `survey_unit_id` plus one column per species. Values are
#' whatever the source recorded - detections for plants, densities
#' for mammals, counts for birds - and are left untransformed
#' here. The spec's response transform is applied in
#' model_frame().
#'
#' @param taxon Character. Taxon slug.
#' @param data_dir Character. Path to 0_data/test_dataset.
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

  # Step 1: Fail on an unknown species here rather than returning
  # a frame that is quietly missing a column
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
#' Birds carry a QPAD log-offset per survey unit and species,
#' which makes a count comparable across survey protocols and
#' detectability. No other taxon has one, and NULL is the honest
#' answer for them rather than a column of zeros - a zero offset
#' is a modelling choice, and this is a data reader.
#'
#' @param taxon Character. Taxon slug.
#' @param data_dir Character. Path to 0_data/test_dataset.
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
#' Reads the requested columns from covariates.csv and keeps the
#' rows belonging to one covariate key.
#'
#' @param taxon Character. Taxon slug.
#' @param data_dir Character. Path to 0_data/test_dataset.
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

  # Step 1: Check against what this taxon has, not against the
  # file header. covariates.csv is one wide table across every
  # taxon, so a column another taxon carries is present in the
  # header and reads back as all NA here. Checking the header
  # alone would hand back a column of nothing and let the model
  # silently drop every row.
  stored <- available_covariates(
    taxon, data_dir = data_dir, region = region,
    include_derived = FALSE
  )

  # A column this taxon does not store may still be computable
  # from ones it does.
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

  # Step 2: Read the columns this key has not read before. The
  # file is 218 MB, and a spec asks for overlapping column sets -
  # the province climate, then each region's habitat - so columns
  # already read for the key are kept for the session and only
  # the rest are read.
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

    # Keep this key's rows, then drop the key column so the result
    # is survey_unit_id plus covariates
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
      # Rows come back in file order every time, so the new
      # columns line up with the held ones
      cbind(held, fresh[, to_load, drop = FALSE])
    }

    assign(cache_key, held, envir = .sdm_cache)
  }

  covariates <- held[, unique(c("survey_unit_id", to_read)),
                     drop = FALSE]

  # Step 3: Compute whatever was derivable rather than stored,
  # then hand back exactly the columns that were asked for
  if (length(derivable) > 0) {
    covariates <- apply_derivations(covariates, derivable)
  }

  covariates[, unique(c("survey_unit_id", columns)), drop = FALSE]
}

# 7. apply_factor_levels() ----

#' Restore Stored Factor Levels
#'
#' Some covariates are categorical - the bird vegetation and soil
#' classes, and the survey method. A CSV reads them back as
#' character, and a model then factors them alphabetically, which
#' silently changes the reference level and so every contrast
#' coefficient. lookup/factor_levels.csv records, per taxon, the
#' order the source used, and this restores it.
#'
#' A level present in the data but not in the lookup is an error
#' rather than an extra level: it means the lookup is stale, and
#' quietly admitting it would change the contrasts.
#'
#' @param frame A data frame.
#' @param data_dir Character. Path to 0_data/test_dataset.
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

  # The lookup names columns as the source did. A column the
  # harmonizer suffixed because it sits in more than one block -
  # the bird `method`, stored as method_veg and method_soil - is
  # loaded under its suffixed name, so the lookup is matched
  # through covariate_columns.csv as well. Without this those
  # columns fall back to alphabetical levels, which moves the
  # reference level and every contrast.
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

  # Every harmonized table is written with `na = ""`, so a
  # missing factor value reads back as a blank string rather
  # than NA. Left alone it survives as an extra level, and the
  # guard below then rejects the whole run over a level that
  # is not a level at all - which is what a blank `soilc`
  # does to 194 of the 91,001 southern bird surveys.
  #
  # v2 never sees this: it reads the same values as NA and
  # glm's default na.action drops those rows. Restoring the
  # NA here reproduces that, rather than inventing a rule.
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
#' Loads the response, covariates, offsets and site fields once,
#' aligned on survey_unit_id, and applies the region filter. The
#' per-species frame is then cut from this by model_frame().
#'
#' Loading once matters: a bird run is 215,758 survey units by
#' 172 species, and re-reading per species would cost more than
#' the fitting.
#'
#' @param taxon Character. Taxon slug.
#' @param data_dir Character. Path to 0_data/test_dataset.
#' @param species Character vector of species to model.
#' @param covariates Character vector of master column names.
#' @param region Character. Region name, or NULL.
#' @param region_filter A one-sided formula evaluated against the
#'   assembled frame, or NULL. Rows where it is not TRUE are
#'   dropped (e.g. ~ nr != "Grassland").
#' @param weight_column Character. A covariate to use as model
#'   weights. Added to `covariates` automatically, so a caller
#'   naming a weight does not also have to remember to load it.
#' @param aliases Named list, alias to source column. Lets a
#'   model set name a column the dataset stores otherwise.
#' @param site_columns Character vector of sites.csv columns to
#'   carry, beyond survey_unit_id, or NULL for site_columns().
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
  site_columns = NULL
) {
  site_columns <- site_columns %||% site_columns()

  # Step 1: Read each piece, narrowed to what was asked for. The
  # weight is a covariate like any other, so it is added here
  # rather than left for the caller to remember.
  if (!is.null(weight_column)) {
    covariates <- unique(c(covariates, weight_column))
  }

  x <- load_covariates(taxon, data_dir, covariates, region)
  y <- load_response(taxon, data_dir, species)
  off <- load_offsets(taxon, data_dir, species)
  sites <- load_sites(data_dir, taxon, site_columns)

  # Step 2: Take the survey units the covariates and the response
  # agree on. A unit in one but not the other cannot be modelled,
  # and silently dropping it is what a plain join would do.
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

  # Step 3b: Restore any recorded factor levels, before the
  # region filter, so a filter may name a categorical column.
  frame <- apply_factor_levels(frame, data_dir, taxon)

  # Step 3c: Alias columns a model set names under a different
  # name than the dataset stores them under. The mammal formulas
  # fit `seas_days`, which is summer_days or winter_days
  # depending on which season is being modelled - one name for a
  # column whose identity is part of the run's configuration.
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

  # Step 4: Apply the region filter. It is a spec-supplied
  # expression rather than a taxon rule known here, which is what
  # keeps this file taxon-agnostic.
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
#' Adds the response, offset and weight for one species to the
#' shared covariate frame, under fixed names, so a model formula
#' and a fitting engine never have to know the species.
#'
#' @param model_data A list from build_model_data().
#' @param species Character. One species column.
#' @param transform Character or function. "identity" leaves the
#'   response alone; "detection" makes it 1 where the value is
#'   above zero, which is how the plant scripts turn a cover
#'   value into a presence. A function is applied as given, and
#'   is passed the frame as a second argument when it takes one -
#'   the mammal lure correction needs `lured` and `location`.
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

  # Step 1: Apply the response transform
  # The untransformed values are kept alongside, because a stage
  # may need a different transform of the same response. The
  # mammal climate stage fits presence whichever half of the
  # hurdle is being run, so the abundance run still needs the
  # presence form to get its climate offset.
  frame[[paste0(response_name, "_raw")]] <- values

  frame[[response_name]] <- apply_response_transform(
    values, transform, frame
  )

  # Step 2: Attach the offset when the taxon has one. A species
  # missing from the offsets file is an error rather than a zero:
  # a silent zero offset would make that species' counts look
  # like every other species' rates.
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
#' Read from sites.csv rather than covariates.csv, so a region
#' filter or a formula may name them without loading them as
#' covariates.
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
    # A transform that declares a second argument gets the
    # frame, so a correction can depend on design columns
    # rather than on the response alone.
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
#' Kept as a small local helper rather than a rlang dependency,
#' because the harness is otherwise base R plus data.table.
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
