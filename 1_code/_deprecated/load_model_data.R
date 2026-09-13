# ---
# title: Load Plant-Group Model Data from the Test Dataset
# author: Brendan Casey
# created: 2026-09-08
# inputs:
#   in 0_data/test_dataset/:
#     - sites.csv
#     - <taxon>.csv
#     - covariates/<taxon>_climate.csv
#     - covariates/<taxon>_veg.csv
#     - covariates/<taxon>_soil.csv
#     - lookup/veg_prediction_matrix.csv
#     - lookup/soil_prediction_matrix.csv
#     - lookup/modelled_species.csv
# outputs: none; returns objects in memory
# notes:
#   - Rebuilds the three model frames the v2 plant scripts used to
#     load from <taxon>-model-data.Rdata, from the harmonized CSVs
#     instead. The frames it returns are equivalent to the v2
#     objects of the same name, so the v2 function files in
#     functions/ run against them unmodified.
#   - The v2 code took its vegetation coefficient names
#     positionally, as colnames(veg.data)[403:489] and three other
#     per-taxon spans. Those spans are all the same 87 habitat
#     types, and they are the first 87 columns of the vegetation
#     covariate table, so veg_coef_names names them instead. That
#     removes the one place where a reordered snapshot would have
#     silently renamed every vegetation coefficient.
#   - Protocol is carried only for bryophytes and lichens, because
#     only those two v2 scripts fit it. plant_taxa() is the single
#     record of which taxa do, and 02 and 03 read the flag from
#     there rather than repeating it.
#   - Both row-addressing styles the v2 functions use are
#     supported: the hierarchical models index by rownames
#     (data[site.id, ]) and the validation indexes by column
#     (data$SiteYearQu %in% site.id), so SiteYearQu is kept as a
#     column and as the rownames.
#   - Future improvement - the same reader would serve mammals
#     once their covariates are harmonized; nothing here is
#     specific to the plant taxa except plant_taxa() and the site
#     field mapping.
# ---

# 1. Setup ----

## 1.1 Load packages ----
library(data.table) # fast CSV reading (version: 1.16.4)

# 2. plant_taxa() ----

#' Describe the Plant-Group Taxa
#'
#' The one record of which taxa exist and which of them fit a
#' Protocol term. In v2 that distinction was implicit in four
#' near-identical scripts: 02a and 02b carried `Protocol` in every
#' habitat formula and passed `protocol.flag = TRUE`, while 02c
#' and 02d carried neither. It is stated once here so the single
#' modelling script can reproduce both variants.
#'
#' @return A data frame with `taxon`, `use_protocol`, and
#'   `label` (the taxon as it reads in a log line).
#'
#' @example # Example usage of the function
#' # plant_taxa()
#' # subset(plant_taxa(), taxon == "mite")$use_protocol
plant_taxa <- function() {
  data.frame(
    taxon = c("bryophyte", "lichen", "mite", "vascular_plant"),
    use_protocol = c(TRUE, TRUE, FALSE, FALSE),
    label = c("bryophytes", "lichens", "mites", "vascular plants"),
    stringsAsFactors = FALSE
  )
}

# 3. taxon_uses_protocol() ----

#' Look Up One Taxon's Protocol Flag
#'
#' @param taxon Character. One of the taxa in `plant_taxa()`.
#' @return Logical. TRUE when that taxon's v2 scripts fit a
#'   Protocol term.
#'
#' @example # Example usage of the function
#' # taxon_uses_protocol("lichen")
taxon_uses_protocol <- function(taxon) {
  taxa <- plant_taxa()
  match_row <- match(taxon, taxa$taxon)

  if (is.na(match_row)) {
    stop(
      "Unknown taxon '",
      taxon,
      "'. Expected one of: ",
      paste(taxa$taxon, collapse = ", "),
      call. = FALSE
    )
  }

  taxa$use_protocol[match_row]
}

# 4. check_prediction_terms() ----

#' Check a Model Set Against Its Prediction Matrix
#'
#' Every habitat term a model fits is later predicted onto a row
#' of the prediction matrix, so a term the matrix has no column
#' for cannot be predicted. In v2 that surfaced only once fitting
#' reached the prediction step, as `object '<term>' not found`
#' raised separately inside every bootstrap of every species.
#' Checking up front turns it into one readable failure.
#'
#' `Climate`, `Protocol` and `paspen` are excluded: they are
#' columns the model functions attach to the data themselves, and
#' the prediction matrix is not expected to carry them.
#'
#' @param models List of model formulas.
#' @param prediction_matrix Data frame. The prediction matrix the
#'   fitted models are predicted onto, with `VegType` already
#'   moved to the rownames.
#' @param what Character. Label for the model set, used in the
#'   error message (e.g. "vegetation").
#' @param source_note Character. Where the matrix came from, so
#'   the message says what to fix.
#' @return NULL, invisibly. Stops when a term has no column.
#'
#' @example # Example usage of the function
#' # check_prediction_terms(
#' #   vegetation.models, prediction.matrix, "vegetation"
#' # )
check_prediction_terms <- function(
  models,
  prediction_matrix,
  what,
  source_note = ""
) {
  # Step 1: Collect the habitat terms across the whole model set
  attached_by_model_code <- c(
    "pcount", "Climate", "Protocol", "paspen"
  )

  terms <- unique(unlist(lapply(models, all.vars)))
  terms <- setdiff(terms, attached_by_model_code)

  # Step 2: Report every missing column at once
  missing_terms <- setdiff(terms, colnames(prediction_matrix))

  if (length(missing_terms) > 0) {
    stop(
      "The ", what, " prediction matrix has no column for ",
      length(missing_terms), " term(s) the models fit:\n  ",
      paste(missing_terms, collapse = "\n  "),
      "\n", source_note,
      call. = FALSE
    )
  }

  invisible(NULL)
}

# 5. load_plant_model_data() ----

#' Rebuild One Taxon's v2 Model Frames from the Test Dataset
#'
#' Joins the response, site and covariate tables into the three
#' frames the v2 plant scripts expect - `climate.data`,
#' `veg.data` and `soil.data` - and returns them alongside the
#' prediction matrices and species lists.
#'
#' `climate.data` is identity + response + climate covariates.
#' `veg.data` and `soil.data` are that frame plus their own
#' habitat block, which is how the v2 files were built: each
#' habitat frame is a superset of the climate frame, so a model
#' formula can name a species, a climate term and a habitat term
#' at once.
#'
#' @param taxon Character. One of the taxa in `plant_taxa()`.
#' @param data_dir Character. Path to 0_data/test_dataset.
#' @param species Character vector of species to model, or NULL
#'   to keep every species the snapshot declares as modelled.
#' @return A list with `climate.data`, `veg.data`, `soil.data`,
#'   `veg.pm`, `soil.pm`, `veg.species.list`, `soil.species.list`
#'   and `veg_coef_names`.
#'
#' @example # Example usage of the function
#' # model_data <- load_plant_model_data(
#' #   taxon = "bryophyte",
#' #   data_dir = "0_data/test_dataset"
#' # )
#' # dim(model_data$veg.data)
load_plant_model_data <- function(
  taxon,
  data_dir,
  species = NULL
) {
  taxon_uses_protocol(taxon)

  # Step 1: Confirm every file is present, so a missing covariate
  # table fails here rather than as a cryptic formula error hours
  # into a bootstrap run.
  paths <- c(
    sites = file.path(data_dir, "sites.csv"),
    response = file.path(data_dir, paste0(taxon, ".csv")),
    climate = file.path(
      data_dir, "covariates", paste0(taxon, "_climate.csv")
    ),
    veg = file.path(
      data_dir, "covariates", paste0(taxon, "_veg.csv")
    ),
    soil = file.path(
      data_dir, "covariates", paste0(taxon, "_soil.csv")
    ),
    veg_pm = file.path(
      data_dir, "lookup", "veg_prediction_matrix.csv"
    ),
    soil_pm = file.path(
      data_dir, "lookup", "soil_prediction_matrix.csv"
    ),
    modelled = file.path(
      data_dir, "lookup", "modelled_species.csv"
    )
  )

  missing_paths <- paths[!file.exists(paths)]

  if (length(missing_paths) > 0) {
    stop(
      "Test dataset files not found:\n  ",
      paste(missing_paths, collapse = "\n  "),
      "\nRun 1_code/_setup/01_harmonize_model_ready_v2.R first.",
      call. = FALSE
    )
  }

  read_table <- function(path) {
    as.data.frame(fread(path, na.strings = ""))
  }

  response <- read_table(paths[["response"]])
  climate_covariates <- read_table(paths[["climate"]])
  veg_covariates <- read_table(paths[["veg"]])
  soil_covariates <- read_table(paths[["soil"]])

  # Step 2: Take the site fields back under their v2 names. The
  # harmonizer factored them out of the covariate tables into
  # sites.csv, so each value has one home; the v2 functions read
  # them as NR, Lat and so on, and reference them by name.
  site_fields <- c(
    SiteYearQu = "survey_unit_id",
    SiteYear = "site_year",
    Site = "site",
    Year = "year",
    QUAD = "quadrant",
    OnOffGrid = "on_off_grid",
    Lat = "lat",
    Long = "long",
    Elevation = "elevation",
    NR = "nr",
    NSR = "nsr",
    LufName = "luf",
    Easting = "easting",
    Northing = "northing"
  )

  sites <- read_table(paths[["sites"]])[, site_fields]
  names(sites) <- names(site_fields)

  # Step 3: Put every table in the response table's row order, so
  # the three frames stay aligned and reproduce the v2 ordering.
  unit_ids <- as.character(response$survey_unit_id)

  align <- function(frame, what) {
    row_order <- match(unit_ids, as.character(frame$survey_unit_id))

    if (anyNA(row_order)) {
      stop(
        taxon,
        ": ",
        sum(is.na(row_order)),
        " survey unit(s) in the response have no ",
        what,
        " row.",
        call. = FALSE
      )
    }

    frame[row_order, setdiff(names(frame), "survey_unit_id"),
          drop = FALSE]
  }

  site_rows <- sites[
    match(unit_ids, sites$SiteYearQu), , drop = FALSE
  ]

  if (anyNA(site_rows$SiteYearQu)) {
    stop(
      taxon,
      ": ",
      sum(is.na(site_rows$SiteYearQu)),
      " survey unit(s) in the response are absent from sites.csv.",
      call. = FALSE
    )
  }

  # Step 4: Assemble the climate frame - identity, response and
  # climate covariates - then extend it with each habitat block.
  species_columns <- response[
    , setdiff(names(response), "survey_unit_id"), drop = FALSE
  ]

  climate.data <- cbind(
    site_rows,
    species_columns,
    align(climate_covariates, "climate covariate")
  )

  # Step 4b: Recompute the terms that are products of other
  # columns, using the same expressions
  # 01a_data-standardization.R used. They are derived rather than
  # stored so they stay exactly consistent with the columns they
  # come from: a CSV carries about 15 significant digits, and a
  # separately stored Northing2 would not equal Northing squared.
  climate.data$Easting2 <-
    climate.data$Easting * climate.data$Easting
  climate.data$Northing2 <-
    climate.data$Northing * climate.data$Northing
  climate.data$EastingNorthing <-
    climate.data$Northing * climate.data$Easting
  climate.data$MAPPET <- climate.data$MAP * climate.data$PET
  climate.data$MAT2 <- climate.data$MAT * climate.data$MAT
  climate.data$CMDMAT <- climate.data$CMD * climate.data$MAT
  climate.data$MWMT2 <- climate.data$MWMT * climate.data$MWMT

  veg_block <- align(veg_covariates, "vegetation covariate")
  soil_block <- align(soil_covariates, "soil covariate")

  veg.data <- cbind(climate.data, veg_block)
  soil.data <- cbind(climate.data, soil_block)

  # Step 5: Address rows both ways. The hierarchical models index
  # by rownames and the validation matches on the SiteYearQu
  # column, so the identifier has to be reachable as both.
  for (frame_name in c("climate.data", "veg.data", "soil.data")) {
    frame <- get(frame_name)
    rownames(frame) <- frame$SiteYearQu
    assign(frame_name, frame)
  }

  # Step 6: Protocol is a factor in the v2 data, and the habitat
  # formulas fit it as one. fread reads it as character, so it is
  # converted back for the two taxa that carry it.
  if (taxon_uses_protocol(taxon)) {
    if (!"Protocol" %in% names(climate.data)) {
      stop(
        taxon,
        " fits a Protocol term but no Protocol column was found ",
        "in its climate covariates.",
        call. = FALSE
      )
    }

    climate.data$Protocol <- as.factor(climate.data$Protocol)
    veg.data$Protocol <- as.factor(veg.data$Protocol)
    soil.data$Protocol <- as.factor(soil.data$Protocol)
  }

  # Step 7: Name the 87 habitat types the vegetation coefficient
  # template is built from. They are the head of the vegetation
  # block, which is the same set the v2 scripts reached by
  # position; the rest of the block holds the aggregates the
  # formulas call for, such as Peatland and CCDecidMixed234.
  veg_coef_names <- names(veg_block)[1:87]

  # Step 8: Read the work queue, narrowed to `species` when the
  # caller names one. The lists say which species each model set
  # is fitted for, and they differ: a species can be common
  # enough to model in the north and not in the south.
  modelled <- read_table(paths[["modelled"]])
  modelled <- modelled[modelled$taxon == taxon, ]

  if (nrow(modelled) == 0) {
    stop(
      "No modelled species listed for ",
      taxon,
      " in lookup/modelled_species.csv.",
      call. = FALSE
    )
  }

  if (!is.null(species)) {
    unknown <- setdiff(species, modelled$species)

    if (length(unknown) > 0) {
      stop(
        "Species not modelled for ",
        taxon,
        ":\n  ",
        paste(unknown, collapse = "\n  "),
        call. = FALSE
      )
    }

    # Subsetting rather than reordering keeps the v2 queue order,
    # so a narrowed run visits species in the same sequence.
    modelled <- modelled[modelled$species %in% species, ]
  }

  # Each list keeps its own v2 ordering, recorded per species by
  # the harmonizer. The two differ, so neither can be recovered
  # from the row order of modelled_species.csv alone.
  veg_rows <- modelled[modelled$in_veg_models, ]
  soil_rows <- modelled[modelled$in_soil_models, ]

  veg.species.list <-
    veg_rows$species[order(veg_rows$veg_order)]
  soil.species.list <-
    soil_rows$species[order(soil_rows$soil_order)]

  message(
    "Loaded ",
    taxon,
    ": ",
    nrow(climate.data),
    " survey units, ",
    length(veg.species.list),
    " vegetation and ",
    length(soil.species.list),
    " soil species"
  )

  return(list(
    climate.data = climate.data,
    veg.data = veg.data,
    soil.data = soil.data,
    veg.pm = read_table(paths[["veg_pm"]]),
    soil.pm = read_table(paths[["soil_pm"]]),
    veg.species.list = veg.species.list,
    soil.species.list = soil.species.list,
    veg_coef_names = veg_coef_names
  ))
}

# End of script ----
