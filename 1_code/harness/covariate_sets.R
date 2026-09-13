# ---
# title: Name and Resolve Covariate Sets
# author: Brendan Casey
# created: 2026-09-09
# inputs:
#   in 0_data/test_dataset/lookup/:
#     - covariate_columns.csv
# outputs: none; returns objects in memory
# notes:
#   - Turns a named covariate set into the master column names a
#     taxon actually has. This is what lets an experiment ask for
#     "climate_v2_topography" instead of editing a formula list,
#     which is the mechanism behind the include/exclude
#     covariate questions this repository exists to ask.
#   - covariate_columns.csv maps taxon and block to master column,
#     so the same set resolves to different columns per taxon
#     where the source data differ, and fails loudly where a
#     taxon simply does not have a covariate.
#   - Requires covariate_key() from data_load.R, which is the one
#     place a taxon's covariate key is derived; source that file
#     first.
#   - Sets are defined here rather than in a spec because they
#     cross taxa: the point of a named set is that the same
#     request means the same thing for plants, mammals and birds.
#   - A set may name another set, so sets compose. Recursion is
#     depth-limited rather than trusted, because a typo that
#     makes a set reference itself would otherwise hang.
#   - Future improvement - topography and remote-sensing sets are
#     declared below but resolve to nothing until a _setup script
#     adds those columns to covariates.csv. They are listed so
#     the gap is visible rather than discovered mid-experiment.
# ---

# 1. Setup ----

## 1.1 Load packages ----
library(data.table) # lookup table reading (version: 1.16.4)

# 2. Covariate set definitions ----

## 2.1 covariate_sets() ----

#' Named Covariate Bundles
#'
#' Each entry is a character vector of master column names, of
#' block names, or of other set names. Blocks are taken from
#' covariate_columns.csv, so `block:veg` means whatever the veg
#' block holds for the taxon being resolved.
#'
#' @return A named list of character vectors.
#'
#' @example # Example usage of the function
#' # names(covariate_sets())
#' # covariate_sets()$climate_v2
covariate_sets <- function() {
  list(
    # The whole of a block, as the source file defines it. These
    # are what a parity run uses.
    climate_all = "block:climate",
    veg_all = "block:veg",
    soil_all = "block:soil",
    design_all = "block:design",

    # The climate terms the v2 plant model sets draw on. Named
    # explicitly rather than as the block, because the block
    # carries derived and design columns too.
    #
    # This is a plant-scale set. Birds carry only five climate
    # columns, so asking for it on birds fails; use
    # climate_common for an experiment spanning both.
    climate_v2 = c(
      "MAT", "MAP", "MWMT", "MCMT", "TD", "MSP", "AHM", "SHM",
      "PET", "CMD", "FFP", "EMT", "EXT", "MTD", "PS"
    ),

    # The climate columns every taxon has, and so the widest set
    # a cross-taxa experiment can use without the taxa silently
    # fitting different models.
    #
    # Five columns, once the mammal camera climate is joined.
    # It was two before that: mammals carried no TD, CMD or EMT,
    # because the SpTable climate block is a different and
    # narrower extraction than the one their models were fitted
    # against. Birds still have no MAT or PET, which is what
    # keeps the shared set at five rather than more.
    #
    # Re-derive with common_covariates() after any dataset
    # version change rather than trusting this list.
    climate_common = c("MAP", "FFP", "TD", "CMD", "EMT"),

    # The wider set birds and the plant groups share, for an
    # experiment that leaves mammals out.
    climate_common_plants_birds = c(
      "MAP", "TD", "CMD", "FFP", "EMT"
    ),

    # Topography. Not in the dataset yet; see the header.
    topography = c("elevation", "slope", "aspect", "TRI", "TPI"),

    # Remote sensing. Not in the dataset yet; see the header.
    remote_sensing = c(
      "canopy_height", "canopy_cover", "ndvi", "lai"
    ),

    # Compositions, which is the point of naming sets at all.
    climate_v2_topography = c("climate_v2", "topography"),
    climate_v2_remote = c("climate_v2", "remote_sensing")
  )
}

# 3. derived_covariates() ----

## 3.1 derived_covariates() ----

#' Covariates Computed from Other Stored Columns
#'
#' Some taxa lack a covariate that their own model set needs, but
#' hold the columns it is defined from. Deriving it lets that
#' taxon join an experiment it would otherwise be excluded from.
#'
#' Derivation is only sound where the definition is exact. Each
#' entry records how it was checked against a taxon that carries
#' both the inputs and the answer, so a derivation is a verified
#' claim rather than an assumption. A quantity that only
#' correlates with its supposed formula does not belong here -
#' see the note on CMD below.
#'
#' @return A named list, each entry with `inputs`, `fn` and
#'   `note`.
#'
#' @example # Example usage of the function
#' # names(derived_covariates())
#' # derived_covariates()$TD$note
derived_covariates <- function() {
  list(
    # Continentality: the summer-winter temperature range.
    # Checked against the vascular plant table, which carries
    # TD, MWMT and MCMT: agrees to 0.1 degrees, which is the
    # precision the normals are stored at.
    TD = list(
      inputs = c("MWMT", "MCMT"),
      fn = function(d) d$MWMT - d$MCMT,
      note = paste(
        "MWMT - MCMT. Verified against vascular_plant to 0.1 C,",
        "the storage precision of the climate normals."
      )
    )

    # CMD is deliberately absent. The mammal climate script
    # glosses it as "PET - MAP, >= 0", but checked against the
    # vascular plant table that formula is off by up to 195 mm
    # (r = 0.975). Climatic moisture deficit is a monthly sum,
    # not an annual difference, so it cannot be recovered from
    # the stored annual columns and has to be sourced.
    ,

    # The products the harmonizer deliberately does not store,
    # because a separately stored square would not equal the
    # square of the stored column at CSV precision. The plant
    # climate model set fits all four, so a plant run needs them
    # derived. Each was checked against the frozen v2 source and
    # agrees exactly.
    MAPPET = list(
      inputs = c("MAP", "PET"),
      fn = function(d) d$MAP * d$PET,
      note = "MAP * PET. Exact against the v2 source."
    ),
    MAT2 = list(
      inputs = "MAT",
      fn = function(d) d$MAT * d$MAT,
      note = "MAT squared. Exact against the v2 source."
    ),
    CMDMAT = list(
      inputs = c("CMD", "MAT"),
      fn = function(d) d$CMD * d$MAT,
      note = "CMD * MAT. Exact against the v2 source."
    ),
    MWMT2 = list(
      inputs = "MWMT",
      fn = function(d) d$MWMT * d$MWMT,
      note = "MWMT squared. Exact against the v2 source."
    ),

    # The spatial trend terms, likewise. Easting and Northing are
    # UTMX and UTMY under another name - identical in the v2
    # source - and sites.csv carries them too, but the model set
    # names them, so they are reachable from the covariate table
    # alone rather than only through a join.
    Easting = list(
      inputs = "UTMX",
      fn = function(d) d$UTMX,
      note = "UTMX. Identical in the v2 source."
    ),
    Northing = list(
      inputs = "UTMY",
      fn = function(d) d$UTMY,
      note = "UTMY. Identical in the v2 source."
    ),
    Easting2 = list(
      inputs = "UTMX",
      fn = function(d) d$UTMX * d$UTMX,
      note = "UTMX squared. Exact against the v2 source."
    ),
    Northing2 = list(
      inputs = "UTMY",
      fn = function(d) d$UTMY * d$UTMY,
      note = "UTMY squared. Exact against the v2 source."
    ),
    EastingNorthing = list(
      inputs = c("UTMX", "UTMY"),
      fn = function(d) d$UTMY * d$UTMX,
      note = "UTMY * UTMX. Exact against the v2 source."
    )
  )
}

## 3.2 derivable_covariates() ----

#' Which Requested Covariates Can Be Derived Here
#'
#' @param requested Character vector of master column names.
#' @param available Character vector of columns the taxon has.
#' @param derived Named list from derived_covariates().
#' @return A character vector of the requested columns that are
#'   absent but derivable from columns that are present.
#'
#' @example # Example usage of the function
#' # derivable_covariates("TD", c("MWMT", "MCMT"))
derivable_covariates <- function(
  requested,
  available,
  derived = derived_covariates()
) {
  missing_columns <- setdiff(requested, available)
  candidates <- intersect(missing_columns, names(derived))

  candidates[vapply(
    candidates,
    function(one) all(derived[[one]]$inputs %in% available),
    logical(1)
  )]
}

## 3.3 apply_derivations() ----

#' Compute Derived Covariates onto a Loaded Frame
#'
#' @param frame A data frame carrying the input columns.
#' @param columns Character vector of derived columns to add.
#' @param derived Named list from derived_covariates().
#' @return The frame with the derived columns added.
#'
#' @example # Example usage of the function
#' # apply_derivations(frame, "TD")
apply_derivations <- function(
  frame,
  columns,
  derived = derived_covariates()
) {
  for (one in columns) {
    definition <- derived[[one]]

    absent <- setdiff(definition$inputs, names(frame))

    if (length(absent) > 0) {
      stop(
        "Cannot derive `", one, "`: missing ",
        paste(absent, collapse = ", "), ".",
        call. = FALSE
      )
    }

    frame[[one]] <- definition$fn(frame)
  }

  frame
}

# 4. covariate_catalogue() ----

#' Read the Covariate Column Catalogue
#'
#' @param data_dir Character. Path to 0_data/test_dataset.
#' @param taxon Character. Keep only this taxon's rows, or NULL
#'   for all of them.
#' @return A data frame of taxon, block, source_column and
#'   master_column.
#'
#' @example # Example usage of the function
#' # cat <- covariate_catalogue(data_dir, taxon = "bryophyte")
#' # unique(cat$block)
covariate_catalogue <- function(data_dir, taxon = NULL) {
  path <- file.path(
    data_dir, "lookup", "covariate_columns.csv"
  )

  if (!file.exists(path)) {
    stop(
      "Covariate catalogue not found:\n  ", path,
      "\nRun 1_code/_setup/01_harmonize_model_ready_v2.R first.",
      call. = FALSE
    )
  }

  catalogue <- as.data.frame(fread(path))

  if (!is.null(taxon)) {
    # The catalogue is keyed the way covariates.csv is, so a
    # split taxon has one row set per region.
    keys <- unique(catalogue$taxon)
    matching <- keys[
      keys == taxon | startsWith(keys, paste0(taxon, "_"))
    ]

    if (length(matching) == 0) {
      stop(
        "No covariate catalogue entries for taxon `", taxon,
        "`. Taxa present: ", paste(keys, collapse = ", "),
        call. = FALSE
      )
    }

    catalogue <- catalogue[catalogue$taxon %in% matching, ]
  }

  rownames(catalogue) <- NULL

  catalogue
}

# 5. available_covariates() ----

#' List the Covariates One Taxon and Region Have
#'
#' @param data_dir Character. Path to 0_data/test_dataset.
#' @param taxon Character. Taxon slug.
#' @param region Character. Region name, or NULL.
#' @param block Character. Restrict to one block, or NULL.
#' @param include_derived Logical. Count covariates that are not
#'   stored but can be computed from stored ones. TRUE by
#'   default, because a derived column is as usable as a stored
#'   one; FALSE answers what the dataset literally holds.
#' @return A character vector of master column names.
#'
#' @example # Example usage of the function
#' # available_covariates(data_dir, "mammal", "north", "veg")
available_covariates <- function(
  data_dir,
  taxon,
  region = NULL,
  block = NULL,
  include_derived = TRUE
) {
  key <- covariate_key(taxon, region)
  catalogue <- covariate_catalogue(data_dir)
  rows <- catalogue[catalogue$taxon == key, ]

  if (nrow(rows) == 0) {
    stop(
      "No covariate catalogue entries for key `", key, "`.",
      call. = FALSE
    )
  }

  if (!is.null(block)) {
    rows <- rows[rows$block %in% block, ]
  }

  stored <- unique(rows$master_column)

  if (!include_derived) {
    return(stored)
  }

  # A derived column counts as available wherever its inputs are,
  # which is what lets mammals reach TD without it being stored.
  derived <- derived_covariates()
  reachable <- names(derived)[vapply(
    names(derived),
    function(one) all(derived[[one]]$inputs %in% stored),
    logical(1)
  )]

  unique(c(stored, reachable))
}

# 6. common_covariates() ----

#' Find the Covariates Several Taxa Share
#'
#' A cross-taxa experiment can only compare taxa on covariates
#' they all have. Asking for more means each taxon quietly fits a
#' different model, which is the one thing a comparison must not
#' do.
#'
#' @param data_dir Character. Path to 0_data/test_dataset.
#' @param taxa Character vector of taxon slugs.
#' @param block Character. Restrict to one block, or NULL.
#' @return A character vector of master column names present for
#'   every taxon given, across all of their regions.
#'
#' @example # Example usage of the function
#' # common_covariates(data_dir, c("bryophyte", "bird"),
#' #                   block = "climate")
common_covariates <- function(data_dir, taxa, block = NULL) {
  catalogue <- covariate_catalogue(data_dir)

  per_taxon <- lapply(taxa, function(one) {
    keys <- unique(catalogue$taxon)
    matching <- keys[
      keys == one | startsWith(keys, paste0(one, "_"))
    ]

    if (length(matching) == 0) {
      stop(
        "No covariate catalogue entries for taxon `", one, "`.",
        call. = FALSE
      )
    }

    rows <- catalogue[catalogue$taxon %in% matching, ]

    if (!is.null(block)) {
      rows <- rows[rows$block %in% block, ]
    }

    # A split taxon must have the column in every region, or it
    # is not usable for that taxon as a whole.
    per_key <- split(rows$master_column, rows$taxon)

    Reduce(intersect, lapply(per_key, unique))
  })

  Reduce(intersect, per_taxon)
}

# 7. term_map() ----

#' Map v2 Term Names onto Harmonized Column Names
#'
#' The v2 model formulas name columns as the source files did.
#' The harmonizer suffixed any column that appears in more than
#' one block with the block it came from, because the north and
#' south files carry columns of the same name holding different
#' values - `HardLin` means the hard linear cover measured for
#' the vegetation model in one and for the soil model in the
#' other. 84 plant columns and 6 bird columns are affected.
#'
#' Without this mapping a v2 formula asks for `HardLin`, which
#' exists in the wide table for some other taxon and reads back
#' as NA, so the map is what keeps a habitat model from silently
#' losing its footprint terms.
#'
#' @param data_dir Character. Path to 0_data/test_dataset.
#' @param taxon Character. Taxon slug.
#' @param region Character. Region name, or NULL.
#' @param block Character. Restrict to one block, or NULL for
#'   every block the taxon has.
#' @return A named character vector, source name to master name,
#'   holding only the names that differ.
#'
#' @example # Example usage of the function
#' # term_map(data_dir, "lichen", block = "veg")[["HardLin"]]
term_map <- function(
  data_dir,
  taxon,
  region = NULL,
  block = NULL
) {
  key <- covariate_key(taxon, region)
  catalogue <- covariate_catalogue(data_dir)
  rows <- catalogue[catalogue$taxon == key, ]

  if (!is.null(block)) {
    rows <- rows[rows$block %in% block, ]
  }

  rows <- rows[rows$source_column != rows$master_column, ]

  if (nrow(rows) == 0) {
    return(stats::setNames(character(0), character(0)))
  }

  stats::setNames(rows$master_column, rows$source_column)
}

# 8. apply_term_map() ----

#' Rewrite Source Names to Master Names
#'
#' Applied to model formula text and to prediction grid column
#' names, so both speak the dataset's names while the v2 sets and
#' the grids keep the names they were written with.
#'
#' @param x Character vector of formula text, or of column names.
#' @param map A named vector from term_map().
#' @return `x`, with whole-word matches replaced.
#'
#' @example # Example usage of the function
#' # apply_term_map(". ~ . + HardLin", map)
apply_term_map <- function(x, map) {
  if (length(map) == 0 || length(x) == 0) {
    return(x)
  }

  # A staged model set is a list of groups, so the rewrite
  # recurses rather than assuming a flat vector.
  if (is.list(x)) {
    return(lapply(x, apply_term_map, map = map))
  }

  # Longest names first, so `SurrHardLin` is not half-rewritten
  # by the rule for `HardLin`. Word boundaries alone would not
  # settle it, because the shorter name is a suffix of the
  # longer one rather than a separate word.
  order_by_length <- order(nchar(names(map)), decreasing = TRUE)

  for (i in order_by_length) {
    x <- gsub(
      paste0("\\b", names(map)[i], "\\b"), map[[i]], x
    )
  }

  x
}

# 9. resolve_covariates() ----

#' Resolve Covariate Set Names to Master Columns
#'
#' Expands set names, block references and bare column names into
#' the master columns a taxon and region actually have. A name
#' that resolves to nothing is an error, not an empty result:
#' silently dropping a covariate would make an experiment look
#' like it tested something it did not.
#'
#' @param requested Character vector of set names, `block:<name>`
#'   references, or master column names.
#' @param data_dir Character. Path to 0_data/test_dataset.
#' @param taxon Character. Taxon slug.
#' @param region Character. Region name, or NULL.
#' @param sets Named list of covariate sets.
#' @param strict Logical. TRUE stops when a requested covariate
#'   is unavailable. FALSE drops it with a warning, which is a
#'   deliberate research choice - each taxon then fits its own
#'   best available set - and is never the default, because a
#'   silently different model per taxon would invalidate a
#'   cross-taxa comparison.
#' @param max_depth Integer. How far a set may reference another
#'   set before the nesting is treated as circular.
#' @return A character vector of master column names, in the
#'   order requested, without duplicates.
#'
#' @example # Example usage of the function
#' # resolve_covariates("climate_v2", data_dir, "bryophyte")
#' # resolve_covariates(c("block:veg", "MAT"), data_dir, "mite")
resolve_covariates <- function(
  requested,
  data_dir,
  taxon,
  region = NULL,
  sets = covariate_sets(),
  strict = TRUE,
  max_depth = 10L
) {
  available <- available_covariates(data_dir, taxon, region)

  # Step 1: Expand set names and block references until only
  # column names are left. Depth-limited, so a set that names
  # itself fails rather than hanging.
  expand <- function(names_in, depth) {
    if (depth > max_depth) {
      stop(
        "Covariate sets nest more than ", max_depth,
        " deep; is a set referencing itself?",
        call. = FALSE
      )
    }

    out <- character(0)

    for (one in names_in) {
      if (startsWith(one, "block:")) {
        block <- sub("^block:", "", one)
        out <- c(
          out,
          available_covariates(data_dir, taxon, region, block)
        )
      } else if (one %in% names(sets)) {
        out <- c(out, expand(sets[[one]], depth + 1L))
      } else {
        out <- c(out, one)
      }
    }

    out
  }

  columns <- unique(expand(requested, 1L))

  # Step 2: Report what this taxon does not have. Set names are
  # reported separately from bare columns, because an empty set
  # usually means a covariate has not been added to the dataset
  # yet, while an unknown column usually means a typo.
  missing_columns <- setdiff(columns, available)

  if (length(missing_columns) > 0 && !strict) {
    warning(
      "Dropping ", length(missing_columns), " covariate(s) not ",
      "available for ", taxon,
      if (is.null(region)) "" else paste0(" (", region, ")"),
      ": ", paste(utils::head(missing_columns, 5), collapse = ", "),
      call. = FALSE
    )

    return(intersect(columns, available))
  }

  if (length(missing_columns) > 0) {
    empty_sets <- requested[
      requested %in% names(sets) &
        vapply(
          requested,
          function(one) {
            if (!one %in% names(sets)) {
              return(FALSE)
            }
            length(
              intersect(expand(sets[[one]], 1L), available)
            ) == 0
          },
          logical(1)
        )
    ]

    stop(
      length(missing_columns), " covariate(s) not available for ",
      taxon,
      if (is.null(region)) "" else paste0(" (", region, ")"),
      ":\n  ",
      paste(utils::head(missing_columns, 10), collapse = "\n  "),
      if (length(empty_sets) > 0) {
        paste0(
          "\nThe set(s) ", paste(empty_sets, collapse = ", "),
          " resolve to nothing for this taxon. If these are new",
          "\ncovariates, add them to covariates.csv through a",
          "\n1_code/_setup/ script first."
        )
      } else {
        ""
      },
      call. = FALSE
    )
  }

  columns
}

# End of script ----
