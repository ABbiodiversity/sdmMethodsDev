# ---
# title: Translate Bird Coefficients to the Standardized Template
# author: Brendan Casey; translation logic by Elly Knight (v2)
# created: 2026-09-29
# inputs:
#   in the test dataset (see harness/data_source.R):
#     - covariates.csv, the bird rows
#     - lookup/bird_veg_age_matrix.csv, from
#       1_code/_setup/06_harmonize_bird_translation_lookup.R
#     - lookup/covariate_columns.csv, lookup/bird_factor_levels.csv
# outputs: none; returns objects in memory
# notes:
#   - A port of the translation in v2's 08.PackageCoefficients.R
#     (cloned in 1_code/_setup/04_package_bird_coefficients.R).
#     v2 publishes bird landcover effects on the standardized
#     cross-taxa habitat types - WhiteSpruceR to WhiteSpruce8,
#     Loamy, EnSoftLin and so on - not as raw glm coefficients,
#     so the harness's raw coefficients have to be translated
#     the same way before they can be compared.
#   - North: the raw coefficients are multiplied by v2's `age`
#     matrix, one row per standardized type. Linear features and
#     wellsites are re-expressed as the mean predicted abundance
#     where the feature is present, then capped at the most
#     abundant open or footprint type.
#   - South: soil types are the intercept plus each soil
#     contrast; the linear features are re-expressed and capped
#     the same way against the full south design.
#   - Everything is on the log scale, as v2 stores it, and
#     clamped to +/- 10,000 as v2 does, so a zero-abundance type
#     reads -10,000 rather than -Inf.
#   - Standard errors are not translated. The gate compares
#     estimates only.
#   - Two v2 quirks are reproduced rather than corrected, because
#     the point is to match v2:
#     - The mSoft substitution tests for zero after the
#       coefficients are exponentiated, so it never fires.
#     - The NESP north Climate effect is multiplied by 0.1 twice,
#       because v2 applies the truncation once after the north
#       loop and again after the south loop.
#   - One deviation. v2 indexes a model matrix built with the
#     default na.action by the row numbers of the unfiltered
#     data, which misaligns the rows if any modelled column has
#     a missing value. Here the design is built with na.pass and
#     missing rows are left out of the means.
# ---

# 1. Setup ----

## 1.1 Load packages ----
library(data.table) # lookup reading (version: 1.16.4)

# 2. Naming ----

## 2.1 bird_sort_interaction() ----

#' Put Interaction Pieces in a Fixed Order
#'
#' v2's `fix_names()`: `wtAge:isCon` and `isCon:wtAge` are the
#' same term, so both are written with their pieces sorted.
#'
#' @param x Character vector of term names.
#' @return The names with interaction pieces sorted.
#'
#' @example # Example usage of the function
#' # bird_sort_interaction("wtAge:isCon") # "isCon:wtAge"
bird_sort_interaction <- function(x) {
  vapply(
    strsplit(x, ":", fixed = TRUE),
    function(pieces) paste(sort(pieces), collapse = ":"),
    character(1)
  )
}

## 2.2 bird_column_map() ----

#' Map the Harness's Column Names Back to v2's
#'
#' The harmonizer suffixed columns that sit in more than one
#' block - `road` became `road_veg` and `road_soil` - so model
#' terms carry the suffix and v2's lookups do not.
#'
#' @param data_dir Character. The test dataset folder.
#' @param block Character. "veg" for north, "soil" for south.
#' @return A data frame of source and master names, one row per
#'   source column, preferring the given block.
#'
#' @example # Example usage of the function
#' # bird_column_map(data_dir, "veg")
bird_column_map <- function(data_dir, block) {
  map <- as.data.frame(fread(
    file.path(data_dir, "lookup", "covariate_columns.csv")
  ))
  map <- map[map$taxon == "bird", ]

  # The block's own copy wins; a column in no other block is
  # taken from wherever it is.
  map <- map[order(map$block != block), ]
  map[!duplicated(map$source_column),
      c("source_column", "master_column")]
}

## 2.3 bird_v2_term_names() ----

#' Rename Harness Model Terms to v2's Raw Names
#'
#' @param terms Character vector of harness coefficient names.
#' @param column_map From bird_column_map().
#' @return Character vector of v2 names: `Intercept`, `climate`,
#'   unsuffixed columns, sorted interactions.
#'
#' @example # Example usage of the function
#' # bird_v2_term_names(c("(Intercept)", "method_veg1SPT"), map)
bird_v2_term_names <- function(terms, column_map) {
  suffixed <- column_map[
    column_map$master_column != column_map$source_column,
  ]
  # Longest first, so mWell_veg is not caught by a shorter name
  suffixed <- suffixed[
    order(-nchar(suffixed$master_column)),
  ]

  rename_piece <- function(piece) {
    if (piece == "(Intercept)") {
      return("Intercept")
    }

    if (piece == "Climate") {
      return("climate")
    }

    for (i in seq_len(nrow(suffixed))) {
      master <- suffixed$master_column[i]

      if (startsWith(piece, master)) {
        return(paste0(
          suffixed$source_column[i],
          substring(piece, nchar(master) + 1)
        ))
      }
    }

    piece
  }

  renamed <- vapply(
    strsplit(terms, ":", fixed = TRUE),
    function(pieces) {
      paste(vapply(pieces, rename_piece, character(1)),
            collapse = ":")
    },
    character(1)
  )

  bird_sort_interaction(renamed)
}

# 3. Translation context ----

## 3.1 bird_model_terms() ----

#' Every Term in a Bird Landcover Model Set
#'
#' v2's `get_terms()`: the union of the terms across every
#' candidate, which is the design v2 predicts from.
#'
#' @param set Character. A model set name.
#' @return Character vector of terms, in source naming.
#'
#' @example # Example usage of the function
#' # bird_model_terms("landcover_bird_south_v2")
bird_model_terms <- function(set) {
  formulas <- unlist(get_model_set(set), use.names = FALSE)
  terms <- sub("^\\s*\\.\\s*~\\s*\\.\\s*\\+", "", formulas)
  terms <- unlist(strsplit(terms, "[+*]"))
  terms <- trimws(terms)
  unique(terms[nzchar(terms)])
}

## 3.2 bird_translation_context() ----

#' Assemble What the Translation Needs for One Region
#'
#' Built once per region and reused for every species and draw:
#' the covariates under v2's names, the design matrix, and the
#' row sets the linear-feature adjustment averages over.
#'
#' @param data_dir Character. The test dataset folder.
#' @param region Character. "north" or "south".
#' @return A list.
#'
#' @example # Example usage of the function
#' # ctx <- bird_translation_context(data_dir, "north")
bird_translation_context <- function(data_dir, region) {
  block <- if (region == "north") "veg" else "soil"
  column_map <- bird_column_map(data_dir, block)
  set <- paste0("landcover_bird_", region, "_v2")
  model_terms <- bird_model_terms(set)

  # Step 1: The columns the design and the row filters need,
  # under v2's names
  source_columns <- unique(c(
    unlist(strsplit(model_terms, ":", fixed = TRUE)),
    "vegc", "fcc2",
    if (region == "north") "useNorth" else c("useSouth", "soilc")
  ))
  source_columns <- intersect(
    source_columns, column_map$source_column
  )
  master_columns <- column_map$master_column[
    match(source_columns, column_map$source_column)
  ]

  covariates <- load_covariates(
    "bird", data_dir, unique(master_columns)
  )
  names(covariates) <- c(
    "survey_unit_id",
    column_map$source_column[
      match(names(covariates)[-1], column_map$master_column)
    ]
  )
  covariates <- apply_factor_levels(covariates, data_dir, "bird")

  # Step 2: The region's rows, as v2 selects them
  keep <- if (region == "north") {
    covariates$useNorth %in% c(1, TRUE)
  } else {
    covariates$useSouth %in% c(1, TRUE) & !is.na(covariates$soilc)
  }
  covariates <- covariates[keep, , drop = FALSE]

  # Step 3: The design matrix, with v2's column names
  design <- stats::model.matrix(
    stats::as.formula(paste("~", paste(model_terms, collapse = " + "))),
    stats::model.frame(
      stats::as.formula(
        paste("~", paste(model_terms, collapse = " + "))
      ),
      covariates, na.action = stats::na.pass
    )
  )
  colnames(design) <- bird_sort_interaction(
    sub("^\\(Intercept\\)$", "Intercept", colnames(design))
  )

  # Step 4: v2's human-modified types, excluded from the linear
  # adjustment so they do not interfere with it
  human <- c(
    "Crop", "Industrial", "Mine", "RoughP", "Rural", "TameP",
    "Urban"
  )
  not_human <- !(as.character(covariates$vegc) %in% human)

  linear_vars <- if (region == "north") {
    c("mWell", "mEnSft", "mTrSft", "mSeism")
  } else {
    c("mWell", "mSoft")
  }

  # Rows where the feature is present (v2's anti-join on zero
  # keeps missing values), off human-modified types, and in the
  # north outside harvest
  linear_rows <- lapply(
    stats::setNames(linear_vars, linear_vars),
    function(one) {
      present <- is.na(covariates[[one]]) | covariates[[one]] != 0
      rows <- present & not_human

      if (region == "north") {
        rows <- rows & !is.na(covariates$fcc2) & covariates$fcc2 == 0
      }

      which(rows)
    }
  )

  age <- NULL

  if (region == "north") {
    age_table <- as.data.frame(fread(
      file.path(data_dir, "lookup", "bird_veg_age_matrix.csv")
    ))
    age <- as.matrix(age_table[, -1])
    rownames(age) <- age_table$type
    colnames(age) <- bird_sort_interaction(colnames(age))
  }

  list(
    region = region,
    column_map = column_map,
    design = design,
    linear_rows = linear_rows,
    age = age,
    soil_levels = if (region == "south") {
      levels(covariates$soilc)
    } else {
      NULL
    }
  )
}

# 4. Translation ----

## 4.1 standardize_bird_draw() ----

#' Translate One Draw's Raw Coefficients
#'
#' @param raw Named numeric vector, v2 raw names.
#' @param context From bird_translation_context().
#' @param species Character. For v2's NESP adjustment.
#' @return Named numeric vector on the standardized template,
#'   log scale.
#'
#' @example # Example usage of the function
#' # standardize_bird_draw(raw, ctx, "AMRO")
standardize_bird_draw <- function(raw, context, species) {
  # Absent terms are zero, as v2's full join fills them
  value <- function(names_in) {
    out <- raw[names_in]
    out[is.na(out)] <- 0
    stats::setNames(out, names_in)
  }

  design <- context$design

  mean_abundance <- function(rows, multiplier) {
    x <- design[rows, , drop = FALSE]
    eta <- drop(x %*% value(colnames(x)))
    mean(exp(eta) * multiplier, na.rm = TRUE)
  }

  if (context$region == "north") {
    age <- context$age

    # Step 1: Standardized habitat types from the age matrix
    lam <- exp(drop(age %*% value(colnames(age))))

    # Step 2: Linear features. v2 exponentiates, then tests for
    # zero, so the mSoft substitution below never fires; kept
    # so the code reads as v2's does.
    hf <- exp(value(c("mWell", "mSoft", "mEnSft", "mTrSft",
                      "mSeism")))

    for (one in c("mEnSft", "mTrSft", "mSeism")) {
      if (hf[["mSoft"]] != 0 && hf[[one]] == 0) {
        hf[[one]] <- hf[["mSoft"]]
      }
    }

    # v2 predicts from the age-matrix columns only
    design <- design[, colnames(age), drop = FALSE]

    linear <- vapply(
      c("mWell", "mEnSft", "mTrSft", "mSeism"),
      function(one) {
        mean_abundance(context$linear_rows[[one]], hf[[one]])
      },
      numeric(1)
    )

    # Step 3: Cap at the most abundant open or footprint type
    open <- max(lam[c(
      names(lam)[endsWith(names(lam), "R")],
      "GrassHerb", "Shrub", "GraminoidFen", "Marsh"
    )])
    footprint <- max(lam[c("Industrial", "Rural", "Urban")])
    linear <- pmin(linear, max(open, footprint))
    names(linear) <- c("Wellsites", "EnSoftLin", "TrSoftLin",
                       "EnSeismic")

    out <- c(
      Climate = exp(value("climate")[[1]]),
      lam[names(lam) != "Mine"],
      linear,
      HardLin = 0, Water = 0, Bare = 0, SnowIce = 0, Mine = 0,
      MineV = unname(lam["Mine"])
    )

    names(out) <- gsub("Spruce", "WhiteSpruce", names(out))
    names(out) <- gsub("Decid", "Deciduous", names(out))
    names(out) <- gsub("TreedBog", "BlackSpruce", names(out))
  } else {
    soil_levels <- context$soil_levels

    # Step 1: Soil types, the intercept plus each contrast
    contrasts <- c(0, value(paste0("soilc", soil_levels[-1])))
    lam <- exp(value("Intercept")[[1]] + contrasts)
    names(lam) <- soil_levels

    # Step 2: Linear features, against the full south design
    linear <- vapply(
      c("mWell", "mSoft"),
      function(one) {
        mean_abundance(
          context$linear_rows[[one]], exp(value(one)[[1]])
        )
      },
      numeric(1)
    )

    # Step 3: Cap at the most abundant open or footprint type
    open <- max(lam[c("Loamy", "Blowout", "ClaySub", "RapidDrain",
                      "SandyLoam", "ThinBreak", "Other")])
    footprint <- max(lam[c("Industrial", "Rural", "Urban")])
    linear <- pmin(linear, max(open, footprint))

    out <- c(
      Climate = exp(value("climate")[[1]]),
      lam[!names(lam) %in% c("Mine", "Water", "Wellsites")],
      pAspen = exp(value("paspen")[[1]]),
      Wellsites = linear[["mWell"]],
      EnSeismic = linear[["mSoft"]],
      EnSoftLin = linear[["mSoft"]],
      TrSoftLin = linear[["mSoft"]],
      HardLin = 0, Water = 0, Mine = 0,
      MineV = unname(lam["Mine"])
    )
  }

  # Step 4: Back to the log scale, clamped as v2 does
  out <- log(out)
  out[out > 1e4] <- 1e4
  out[out < -1e4] <- -1e4

  # v2 truncates the NESP north Climate effect, twice
  if (context$region == "north" && species == "NESP") {
    out[["Climate"]] <- out[["Climate"]] * 0.1 * 0.1
  }

  out
}

## 4.2 standardize_bird_coefficients() ----

#' Translate a Store's Bird Landcover Coefficients
#'
#' @param coefficients A data frame of species, region, boot,
#'   term and estimate: the landcover stage, one region.
#' @param data_dir Character. The test dataset folder.
#' @param region Character. "north" or "south".
#' @return A data frame of the same columns, on the standardized
#'   template, with stage "habitat" and se NA.
#'
#' @example # Example usage of the function
#' # standardize_bird_coefficients(landcover, data_dir, "north")
standardize_bird_coefficients <- function(
  coefficients, data_dir, region
) {
  if (is.null(coefficients) || nrow(coefficients) == 0) {
    return(NULL)
  }

  context <- bird_translation_context(data_dir, region)

  coefficients$v2_term <- bird_v2_term_names(
    coefficients$term, context$column_map
  )

  draws <- split(
    coefficients,
    list(coefficients$species, coefficients$boot),
    drop = TRUE
  )

  rows <- lapply(draws, function(one) {
    raw <- stats::setNames(one$estimate, one$v2_term)
    translated <- standardize_bird_draw(
      raw, context, one$species[1]
    )

    data.frame(
      species = one$species[1],
      region = region,
      stage = "habitat",
      boot = one$boot[1],
      term = names(translated),
      estimate = unname(translated),
      se = NA_real_,
      stringsAsFactors = FALSE
    )
  })

  out <- do.call(rbind, rows)
  rownames(out) <- NULL

  out
}

# 5. bird_habitat_translation() ----

#' Translate a Store's Bird Landcover onto v2's Habitat Template
#'
#' The form collect_results() takes in `translate`: given a
#' store's coefficients, returns the landcover stage translated
#' onto v2's standardized habitat types as extra rows, stage
#' "habitat". The raw "landcover" rows stay as they are.
#'
#' @param coefficients A store's coefficients.
#' @param data_dir Character. The test dataset folder.
#' @param region Character. "north" or "south".
#' @return A data frame of coefficient rows, or NULL.
#'
#' @example # Example usage of the function
#' # collect_results(pipeline_dir, data_dir,
#' #   translate = list(bird = bird_habitat_translation))
bird_habitat_translation <- function(coefficients, data_dir, region) {
  landcover <- coefficients[coefficients$stage == "landcover", ]

  if (nrow(landcover) == 0) {
    return(NULL)
  }

  standardize_bird_coefficients(landcover, data_dir, region)
}

# End of script ----
