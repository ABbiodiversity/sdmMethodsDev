# ---
# title: Name and Resolve Covariate Sets
# author: Brendan Casey
# created: 2026-09-09
# inputs:
#   in the test dataset's lookup/ (see data_source.R):
#     - covariate_columns.csv
# outputs: none; returns objects in memory
# notes:
#   - Resolves named, cross-taxa covariate sets to the master
#     columns each taxon has (via covariate_columns.csv), failing
#     loudly where a taxon lacks one. Sets may name other sets.
#   - Needs covariate_key() from data_load.R.
#   - The topography and remote_sensing sets are not in the frozen
#     dataset and resolve to nothing; they are listed so the gap
#     is visible.
# ---

# 1. Setup ----

## 1.1 Load packages ----
library(data.table) # lookup table reading (version: 1.16.4)

# 2. Covariate set definitions ----

## 2.1 covariate_sets() ----

#' Named Covariate Bundles
#'
#' Entries hold master column names, other set names, or
#' `block:<name>`, which means whatever that block holds for the
#' taxon being resolved.
#'
#' @return A named list of character vectors.
#'
#' @example # Example usage of the function
#' # names(covariate_sets())
#' # covariate_sets()$climate_v2
covariate_sets <- function() {
  list(
    # Whole blocks, as parity runs use
    climate_all = "block:climate",
    veg_all = "block:veg",
    soil_all = "block:soil",
    design_all = "block:design",

    # The climate terms v2 plant model sets draw on (the block
    # also holds derived and design columns). Fails on birds; use
    # climate_common across taxa.
    climate_v2 = c(
      "MAT", "MAP", "MWMT", "MCMT", "TD", "MSP", "AHM", "SHM",
      "PET", "CMD", "FFP", "EMT", "EXT", "MTD", "PS"
    ),

    # Climate columns every taxon has (birds lack MAT and PET).
    # Re-derive with common_covariates() after a dataset change.
    climate_common = c("MAP", "FFP", "TD", "CMD", "EMT"),

    # The wider set birds and the plant groups share, for an
    # experiment that leaves mammals out.
    climate_common_plants_birds = c(
      "MAP", "TD", "CMD", "FFP", "EMT"
    ),

    topography = c("elevation", "slope", "aspect", "TRI", "TPI"),

    remote_sensing = c(
      "canopy_height", "canopy_cover", "ndvi", "lai"
    ),

    climate_v2_topography = c("climate_v2", "topography"),
    climate_v2_remote = c("climate_v2", "remote_sensing")
  )
}

# 3. derived_covariates() ----

## 3.1 derived_covariates() ----

#' Covariates Computed from Other Stored Columns
#'
#' Only exact definitions belong here; each entry's `note` says
#' how it was verified. A quantity that merely correlates with a
#' formula does not (see CMD below).
#'
#' @return A named list, each entry with `inputs`, `fn` and
#'   `note`.
#'
#' @example # Example usage of the function
#' # names(derived_covariates())
#' # derived_covariates()$TD$note
derived_covariates <- function() {
  list(
    TD = list(
      inputs = c("MWMT", "MCMT"),
      fn = function(d) d$MWMT - d$MCMT,
      note = paste(
        "MWMT - MCMT. Verified against vascular_plant to 0.1 C,",
        "the storage precision of the climate normals."
      )
    )

    # CMD is deliberately absent: "PET - MAP, >= 0" (the mammal
    # script's gloss) is off by up to 195 mm against
    # vascular_plant, because CMD is a monthly sum.
    ,

    # Products are not stored: a stored square would not equal
    # the square of the stored column at CSV precision. The plant
    # climate set fits all four.
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

    # Spatial trend terms, named as the v2 model sets name them,
    # so they come from the covariate table without a join
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
#' @param data_dir Character. The test dataset folder.
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

  catalogue <- cached_read(path, function(p) as.data.frame(fread(p)))

  if (!is.null(taxon)) {
    # A taxon split by region has keys like `<taxon>_<region>`
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
#' @param data_dir Character. The test dataset folder.
#' @param taxon Character. Taxon slug.
#' @param region Character. Region name, or NULL.
#' @param block Character. Restrict to one block, or NULL.
#' @param include_derived Logical. Also count covariates
#'   derivable from stored ones (see derived_covariates()).
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
  key <- covariate_key(taxon, region, data_dir)
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

  # e.g. mammals reach TD without it being stored
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
#' Cross-taxa comparisons must use only shared covariates, or
#' each taxon fits a different model.
#'
#' @param data_dir Character. The test dataset folder.
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

    # A split taxon must have the column in every region
    per_key <- split(rows$master_column, rows$taxon)

    Reduce(intersect, lapply(per_key, unique))
  })

  Reduce(intersect, per_taxon)
}

# 7. term_map() ----

#' Map v2 Term Names onto Harmonized Column Names
#'
#' The harmonizer suffixed columns found in more than one block
#' with their block, because same-named columns hold different
#' values (e.g. `HardLin` in the veg and soil blocks). 84 plant
#' and 6 bird columns are affected. Unmapped, a v2 formula would
#' read another taxon's column as NA and silently lose terms.
#'
#' @param data_dir Character. The test dataset folder.
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
  key <- covariate_key(taxon, region, data_dir)
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
#' Applied to formula text and prediction grid column names, so
#' v2 sets and grids keep their original names.
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

  # Staged model sets are lists of groups
  if (is.list(x)) {
    return(lapply(x, apply_term_map, map = map))
  }

  # Longest names first, so `SurrHardLin` is not half-rewritten
  # by the rule for `HardLin`
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
#' An unavailable covariate is an error by default: dropping it
#' silently would misreport what an experiment tested.
#'
#' @param requested Character vector of set names, `block:<name>`
#'   references, or master column names.
#' @param data_dir Character. The test dataset folder.
#' @param taxon Character. Taxon slug.
#' @param region Character. Region name, or NULL.
#' @param sets Named list of covariate sets.
#' @param strict Logical. FALSE drops unavailable covariates with
#'   a warning, so each taxon fits a different set; never use it
#'   for cross-taxa comparisons.
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

  # Step 1: Expand sets and blocks to columns. Depth-limited, so
  # a self-referencing set fails rather than hanging.
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

  # Step 2: Report what this taxon lacks. Empty sets are named
  # separately: they usually mean missing data, not a typo.
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
