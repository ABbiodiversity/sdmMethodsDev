# ---
# title: Load the Harmonized Test Dataset
# author: Brendan Casey
# created: 2026-09-09
# inputs:
#   in 0_data/test_dataset/:
#     - sites.csv
#     - <taxon>.csv
#     - covariates.csv
#     - <taxon>_offsets.csv (birds only)
# outputs: none; returns objects in memory
# notes:
#   - The taxon-agnostic data layer. Every reader takes the taxon
#     as an argument and knows nothing else about it; what a taxon
#     means is carried by its spec, not by this file.
#   - covariates.csv is keyed on survey_unit_id and a covariate
#     key, which is the taxon for most taxa but the taxon and
#     region for mammals, whose north and south files carry
#     different values for the same deployment. covariate_key()
#     is the one place that difference is expressed.
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

# 2. covariate_key() ----

#' Name a Taxon's Key in covariates.csv
#'
#' Most taxa have one covariate row per survey unit. Mammals have
#' two models fitted on overlapping deployments, north and south,
#' whose covariates disagree, so their rows are keyed by taxon and
#' region together.
#'
#' @param taxon Character. Taxon slug, as in the response file
#'   name (e.g. "bryophyte", "mammal", "bird").
#' @param region Character. Region name, or NULL when the taxon
#'   is not split.
#' @param split_taxa Character vector of taxa whose covariates
#'   are stored per region.
#' @return Character. The value to match in the `taxon` column of
#'   covariates.csv.
#'
#' @example # Example usage of the function
#' # covariate_key("mammal", "north")   # "mammal_north"
#' # covariate_key("bryophyte", "north") # "bryophyte"
covariate_key <- function(
  taxon,
  region = NULL,
  split_taxa = c("mammal")
) {
  if (is.null(region) || !taxon %in% split_taxa) {
    return(taxon)
  }

  paste(taxon, region, sep = "_")
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
  path <- file.path(data_dir, paste0(taxon, ".csv"))
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
  path <- file.path(data_dir, paste0(taxon, "_offsets.csv"))

  if (!file.exists(path)) {
    return(NULL)
  }

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

  key <- covariate_key(taxon, region)

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

  covariates <- fread(
    path,
    select = unique(c("survey_unit_id", "taxon", to_read))
  )

  # Step 2: Keep this taxon's rows, then drop the key column so
  # the result is survey_unit_id plus covariates
  covariates <- covariates[covariates$taxon == key, ]

  if (nrow(covariates) == 0) {
    keys <- unique(fread(path, select = "taxon")$taxon)
    stop(
      "No covariate rows for key `", key, "`. Keys present: ",
      paste(keys, collapse = ", "),
      call. = FALSE
    )
  }

  covariates[, taxon := NULL]

  covariates <- as.data.frame(covariates)

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
#' coefficient. `<taxon>_factor_levels.csv` records the order the
#' source used, and this restores it.
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
  path <- file.path(
    data_dir, "lookup", paste0(taxon, "_factor_levels.csv")
  )

  if (!file.exists(path)) {
    return(frame)
  }

  levels_table <- as.data.frame(fread(path))

  for (column in unique(levels_table$column)) {
    if (!column %in% names(frame)) {
      next
    }

    rows <- levels_table[levels_table$column == column, ]
    ordered_levels <- rows$level[order(rows$level_order)]

    values <- as.character(frame[[column]])
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

    frame[[column]] <- factor(values, levels = ordered_levels)
  }

  frame
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
#'   carry, beyond survey_unit_id.
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
  site_columns = c(
    "lat", "long", "nr", "nsr", "luf", "year",
    "lured", "location", "summer_days", "winter_days"
  )
) {
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

## 10.2 align_to_units() ----

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

## 10.3 apply_response_transform() ----

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

## 10.4 rlang_f_rhs() ----

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
