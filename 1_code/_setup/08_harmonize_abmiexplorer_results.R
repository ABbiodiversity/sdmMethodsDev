# ---
# title: Harmonize the ABMIexploreR Coefficients into a Parity
#   Reference
# author: Brendan Casey
# created: 2026-10-02
# inputs:
#   - data/species-coefs.RData from the ABbiodiversity/ABMIexploreR
#     GitHub repository, at the commit pinned in section 1.2
#   - Data/lookups/birdlist.csv on the BirdModels drive, for the
#     bird four-letter codes the harness keys on
#   - 0_data/test_dataset/mammal.csv, header only, for the mammal
#     keys the harness uses
# outputs:
#   - 0_data/external/abmiexplorer/<sha>/species-coefs.RData, the
#     downloaded source, never overwritten
#   - 0_data/v2_results/abmiexplorer/v2_results.csv
#   - 0_data/v2_results/abmiexplorer/v2_results_coverage.csv
# notes:
#   - An alternative to 05_harmonize_v2_results.R. Same output
#     schema, so 02_compare_to_v2.R reads either; run.R's
#     `v2_reference` chooses which. This one needs no network
#     drive for any taxon but birds, and those only for names.
#
#   - ABMIexploreR is ABMI's published distribution of the v2
#     coefficients: one `species.coefs` list holding, per taxon,
#     species x term x draw arrays for Vegetation (north), Soil
#     (south) and Climate (province-wide), on the link scale.
#
#   - Pinned to a commit, not to HEAD. The data file changes
#     between commits: on 2026-07-27 the mammal models added in
#     July 2025 (an earlier fit, presence in the north only) were
#     replaced by the 2024 models the harness reproduces. An
#     unpinned read would move the reference under a finished
#     run. Only the data file is
#     downloaded; installing the package would pull terra and
#     friends for nothing this script uses.
#
#   - Checked against 05's reference on 2026-10-02, at the pinned
#     commit:
#     - Plants and birds are the same models. Every shared
#       species and term matches to ~1e-15, except species where
#       some v2 draws failed. 05 drops the failed draws (v2_n
#       below 100); the package holds 100 finite draws for every
#       cell, so its median moves slightly for those species.
#     - The package is the published subset: about 10% fewer
#       plant species than COEFS.RData, and 124 of 133 birds.
#       Bryum.All, AMRO and YEWA, in the parity_check set, are
#       not in it.
#     - Mammals are the same models as 05's 2024 coefficient
#       tables, presence, abundance and total, north and south,
#       to ~1e-16 once back-transformed. The package stores them
#       on the link scale (logit for presence, log for the other
#       two) where the tables are on the response scale, which
#       the harness writes, so they are back-transformed here.
#       Its 100 draws are one fit repeated, as v2 fits mammal
#       habitat once, so they are written as v2_n 1 and the
#       comparison reads iteration 1, as it does against 05.
#       South WetlandMargin is not in the package.
#     - Amphibians are in the package and have no module yet.
#       Their rows are written; nothing joins them.
#
#   - The package relabels some terms against the names the
#     harness writes, and mammals on the cross-taxa template
#     rather than their native terms. Where the values were
#     verified identical, an alias row is added under the
#     harness's name and the package's row is kept; see
#     term_aliases(). Bird TreedFen
#     is one coefficient in the package and nine age classes in
#     v2 (r ~ 0.99 with each), so it is not aliased.
#
#   - The package pads every species to a full term template
#     with exact zeros. A cell whose every draw is exactly zero
#     is padding, not a fitted coefficient, and is dropped.
#
#   - Read only, apart from the one download.
# ---

# 1. Setup ----

## 1.1 Load packages ----
library(data.table) # summarizing and writing (version: 1.18.0)

## 1.2 Pin the source ----
# Change the commit deliberately, then re-run. The download
# lands in its own folder, so an old reference stays readable.
explorer_repo <- "ABbiodiversity/ABMIexploreR"

explorer_sha <- Sys.getenv(
  "SDM_ABMIEXPLORER_SHA",
  unset = "848eeed5f7a3347606a02c19211fe35be41240d1"
)

explorer_file <- "data/species-coefs.RData"

## 1.3 Resolve the other locations ----
project_root <- normalizePath(getwd(), winslash = "/")

# The same lookup v2's 08.PackageCoefficients.R uses to turn
# bird codes into the names the package carries.
bird_lookup_path <- Sys.getenv(
  "SDM_V2_BIRD_LOOKUP",
  unset = paste0(
    "G:/.shortcut-targets-by-id/",
    "17Ymt13eHfKvIiuoMl6x-Kn74Z2uVbbzS/BirdModels/",
    "Data/lookups/birdlist.csv"
  )
)

mammal_data_path <- file.path(
  project_root, "0_data/test_dataset/mammal.csv"
)

source_dir <- file.path(
  project_root, "0_data/external/abmiexplorer", explorer_sha
)
results_dir <- file.path(
  project_root, "0_data/v2_results/abmiexplorer"
)

for (one in c(source_dir, results_dir)) {
  dir.create(one, recursive = TRUE, showWarnings = FALSE)
}

## 1.4 Name the output columns ----
# Identical to 05, so the comparison reads either file.
result_columns <- c(
  "taxon", "region", "stage", "part", "season",
  "species", "species_v2", "term",
  "v2_median", "v2_p10", "v2_p90", "v2_se", "v2_n", "source"
)

source_label <- paste0(
  "ABMIexploreR@", substr(explorer_sha, 1, 7)
)

## 1.5 Fetch the pinned data file ----
coefs_path <- file.path(source_dir, basename(explorer_file))

if (!file.exists(coefs_path)) {
  url <- paste0(
    "https://raw.githubusercontent.com/", explorer_repo, "/",
    explorer_sha, "/", explorer_file
  )

  cat("Downloading", url, "\n")

  # Written to a temporary name first, so an interrupted
  # download never leaves a truncated file where a good one is
  # expected.
  partial <- paste0(coefs_path, ".part")
  old_timeout <- options(timeout = max(600, getOption("timeout")))
  status <- utils::download.file(url, partial, mode = "wb")
  options(old_timeout)

  if (status != 0) {
    stop("Download failed: ", url, call. = FALSE)
  }

  invisible(file.rename(partial, coefs_path))
}

coefs_env <- new.env()
load(coefs_path, envir = coefs_env)
species_coefs <- coefs_env$species.coefs

if (!is.list(species_coefs) || length(species_coefs) == 0) {
  stop(
    coefs_path, " holds no `species.coefs` list.", call. = FALSE
  )
}

# 2. Map the package onto the harness ----

## 2.1 Taxa, models and parts ----
taxon_slugs <- c(
  Amphibians = "amphibian",
  Birds = "bird",
  Bryophytes = "bryophyte",
  Lichens = "lichen",
  Mammals = "mammal",
  Mites = "mite",
  VascularPlants = "vascular_plant"
)

# Vegetation is fitted in the north, soil in the south, and
# climate once on everything, as in 05.
model_parts <- list(
  Vegetation = list(region = "north", stage = "habitat"),
  Soil = list(region = "south", stage = "habitat"),
  Climate = list(region = "all", stage = "climate")
)

# The part each taxon's rows are joined on. Mammal habitat is a
# hurdle stored as three arrays; mammal climate is fitted on
# presence.
mammal_parts <- c(
  PA = "presence", AGP = "abundance", TA = "total"
)

# The package stores mammal habitat on the link scale; v2's
# tables, and the harness, are on the response scale. Verified
# exact against 05 on 2026-10-02. Mammal climate is on the link
# scale in both, so it is left alone.
mammal_inverse_links <- list(
  presence = stats::plogis, abundance = exp, total = exp
)

part_of <- function(slug, stage, hurdle = NA) {
  if (slug == "bird") {
    return("count")
  }

  if (slug == "mammal") {
    return(if (stage == "climate") "presence" else hurdle)
  }

  "detection"
}

## 2.2 term_aliases() ----

#' Package Terms Under the Names the Harness Writes
#'
#' Each pair was checked on 2026-10-02 against 05's reference:
#' the package term's medians equal the v2 term's for every
#' shared species in the north. The package collapsed the fen
#' age classes and renamed the human-footprint classes; birds
#' also call v2's BlackSpruce classes TreedBog. Mammals are on
#' the cross-taxa template, so their native stand names are
#' restored, and each unaged stand type takes the value of its
#' age classes, which v2 holds equal for mammals.
#'
#' @param slug Character. A taxon slug.
#' @return A data frame of `from` and `to` term names.
#'
#' @example # Example usage of the function
#' # term_aliases("lichen")
term_aliases <- function(slug) {
  footprint <- data.frame(
    from = c("RuralResidential", "UrbanIndustrial",
             "IndustrialRural"),
    to = c("Rural", "Urban", "Industrial")
  )

  ages <- c("R", 1:8)

  if (slug %in% c("bryophyte", "lichen", "mite",
                  "vascular_plant")) {
    # Plant fen ages carry one shared value in v2, so the single
    # package term stands for each of them exactly.
    return(rbind(
      footprint,
      data.frame(from = "TreedFen", to = paste0("TreedFen", ages))
    ))
  }

  if (slug == "bird") {
    return(rbind(
      footprint,
      data.frame(
        from = paste0("TreedBog", ages),
        to = paste0("BlackSpruce", ages)
      )
    ))
  }

  if (slug == "mammal") {
    stands <- c(
      WhiteSpruce = "Spruce", Deciduous = "Decid",
      Pine = "Pine", Mixedwood = "Mixedwood", TreedBog = "TreedBog"
    )
    cutblocks <- c(
      CCWhiteSpruce = "CCSpruce", CCDeciduous = "CCDecid"
    )
    renamed <- stands[names(stands) != stands]

    return(rbind(
      footprint,
      data.frame(from = "Wellsites", to = "Well"),
      data.frame(
        from = paste0(rep(names(renamed), each = 9), ages),
        to = paste0(rep(renamed, each = 9), ages)
      ),
      data.frame(
        from = paste0(rep(names(cutblocks), each = 5), c("R", 1:4)),
        to = paste0(rep(cutblocks, each = 5), c("R", 1:4))
      ),
      data.frame(from = paste0(names(stands), "R"), to = stands)
    ))
  }

  data.frame(from = character(0), to = character(0))
}

## 2.3 Species keys ----
# Plants and amphibians key on the package's own SpeciesID.
# Birds key on the four-letter code, mammals on the column
# stems in the harness's mammal data.

### 2.3.1 Bird codes ----
bird_codes <- if (file.exists(bird_lookup_path)) {
  lookup <- fread(bird_lookup_path, select = c("code", "sppid"))
  stats::setNames(lookup$code, lookup$sppid)
} else {
  warning(
    "Bird lookup not found at ", bird_lookup_path,
    "; birds are keyed on the package name and will not join. ",
    "Set SDM_V2_BIRD_LOOKUP.",
    call. = FALSE
  )
  character(0)
}

### 2.3.2 Mammal keys ----
mammal_keys <- if (file.exists(mammal_data_path)) {
  stems <- names(fread(mammal_data_path, nrows = 0))
  unique(sub("_(Summer|Winter)$", "", stems[-1]))
} else {
  character(0)
}

#' Translate Package Species Names to Harness Keys
#'
#' @param names Character vector of package SpeciesIDs.
#' @param slug Character. The taxon slug.
#' @return Character vector of keys, the package name where no
#'   key is known.
#'
#' @example # Example usage of the function
#' # species_key(c("Grizzlybear", "Elk"), "mammal")
species_key <- function(names, slug) {
  if (slug == "bird") {
    keys <- unname(bird_codes[names])
    return(ifelse(is.na(keys), names, keys))
  }

  if (slug == "mammal" && length(mammal_keys) > 0) {
    # The package and the harness differ only in case, except
    # elk, which v2's survey data calls "Elk (wapiti)".
    names <- ifelse(names == "Elk", "ElkWapiti", names)
    keys <- mammal_keys[match(tolower(names), tolower(mammal_keys))]
    return(ifelse(is.na(keys), names, keys))
  }

  names
}

# 3. Flatten ----

## 3.1 flatten_array() ----

#' Summarize One Species x Term x Draw Array
#'
#' @param values Numeric 3-D array, draws in the third dimension.
#' @param slug Character. Taxon slug.
#' @param model Character. "Vegetation", "Soil" or "Climate".
#' @param hurdle Character. The mammal hurdle part, or NA.
#' @return A data frame in the output schema, or NULL.
#'
#' @example # Example usage of the function
#' # flatten_array(species_coefs$Lichens$Climate, "lichen",
#' #               "Climate")
flatten_array <- function(values, slug, model, hurdle = NA) {
  if (is.null(values) || length(dim(values)) != 3) {
    return(NULL)
  }

  species <- dimnames(values)[[1]]
  terms <- dimnames(values)[[2]]

  # One row per species and term, draws across. Column-major
  # order means species vary fastest, which the rep() calls
  # below follow.
  draws <- matrix(values, ncol = dim(values)[3])

  finite <- is.finite(draws)
  draws[!finite] <- NA_real_
  counts <- rowSums(finite)

  # Template padding: every draw exactly zero. Checked before any
  # back-transform, which would turn the zeros into 0.5 or 1. Not
  # applied to the mammal hurdle, which carries no padding and
  # where v2 fixes the abundance Climate term at a real 0.
  padding <- counts > 0 & is.na(hurdle) &
    rowSums(draws != 0, na.rm = TRUE) == 0

  # v2 fits mammals once; the package repeats that fit in every
  # draw. A repeated fit is one value, not a distribution, so it
  # is written as v2_n 1 and scored on iteration 1.
  single_fit <- slug == "mammal" &&
    all(apply(draws, 1, function(x) {
      length(unique(x[!is.na(x)])) <= 1
    }))

  if (slug == "mammal" && !is.na(hurdle)) {
    draws <- mammal_inverse_links[[hurdle]](draws)
  }

  keep <- counts > 0 & !padding

  quantiles <- apply(
    draws[keep, , drop = FALSE], 1, stats::quantile,
    probs = c(0.1, 0.5, 0.9), na.rm = TRUE, names = FALSE
  )

  stage <- model_parts[[model]]$stage
  species_v2 <- rep(species, times = length(terms))[keep]

  data.frame(
    taxon = slug,
    region = model_parts[[model]]$region,
    stage = stage,
    part = part_of(slug, stage, hurdle),
    season = if (slug == "mammal") "all" else NA_character_,
    species = species_key(species_v2, slug),
    species_v2 = species_v2,
    term = rep(terms, each = length(species))[keep],
    v2_median = quantiles[2, ],
    v2_p10 = if (single_fit) NA_real_ else quantiles[1, ],
    v2_p90 = if (single_fit) NA_real_ else quantiles[3, ],
    v2_se = NA_real_,
    v2_n = if (single_fit) 1L else counts[keep],
    source = source_label,
    stringsAsFactors = FALSE
  )
}

## 3.2 add_aliases() ----

#' Copy Relabelled Terms Under the Harness's Names
#'
#' @param rows A data frame in the output schema, one taxon.
#' @param slug Character. The taxon slug.
#' @return `rows` with the alias rows appended.
#'
#' @example # Example usage of the function
#' # add_aliases(rows, "bird")
add_aliases <- function(rows, slug) {
  aliases <- term_aliases(slug)

  if (is.null(rows) || nrow(aliases) == 0) {
    return(rows)
  }

  copies <- merge(
    rows, aliases, by.x = "term", by.y = "from"
  )

  # A term the package already carries under the harness's name
  # is never shadowed by an alias.
  present <- paste(rows$region, rows$species, rows$term)
  copies$term <- copies$to
  copies <- copies[
    !paste(copies$region, copies$species, copies$term) %in% present,
    result_columns
  ]

  rbind(rows, copies)
}

# 4. Assemble ----
blocks <- list()
coverage <- list()

for (taxon in names(species_coefs)) {
  slug <- taxon_slugs[[taxon]]

  if (is.null(slug)) {
    cat("Skipping unrecognized taxon", taxon, "\n")
    next
  }

  for (model in names(model_parts)) {
    values <- species_coefs[[taxon]][[model]]
    label <- paste(slug, model_parts[[model]]$region,
                   model_parts[[model]]$stage)
    note <- NA_character_

    # Mammal habitat is a list of hurdle arrays, named PA, AGP
    # and TA; everything else is one unnamed array.
    arrays <- if (is.list(values) && !is.array(values)) {
      values[intersect(names(mammal_parts), names(values))]
    } else {
      list(values)
    }

    rows <- do.call(rbind, lapply(seq_along(arrays), function(i) {
      hurdle <- if (is.null(names(arrays))) {
        NA
      } else {
        mammal_parts[[names(arrays)[i]]]
      }
      flatten_array(arrays[[i]], slug, model, hurdle)
    }))

    rows <- add_aliases(rows, slug)
    blocks[[label]] <- rows

    # A bird without a code keeps its package name and cannot
    # join, so the count is reported rather than discovered.
    unkeyed <- if (slug == "bird" && !is.null(rows)) {
      sum(!unique(rows$species_v2) %in% names(bird_codes))
    } else {
      0L
    }

    coverage[[label]] <- data.frame(
      source_label = label,
      reachable = !is.null(rows) && nrow(rows) > 0,
      rows = if (is.null(rows)) 0L else nrow(rows),
      species = if (is.null(rows)) {
        0L
      } else {
        length(unique(rows$species))
      },
      looked_in = paste0(explorer_repo, "@", explorer_sha),
      note = if (is.na(note) && unkeyed > 0) {
        paste(unkeyed, "species have no bird code")
      } else {
        note
      },
      stringsAsFactors = FALSE
    )
  }
}

# 5. Write ----
kept <- blocks[!vapply(blocks, is.null, logical(1))]
results <- do.call(rbind, kept)

if (is.null(results) || nrow(results) == 0) {
  stop("No coefficients were read from ", coefs_path,
       call. = FALSE)
}

rownames(results) <- NULL
results <- results[, result_columns]

# Ordered so the file is stable between builds and diffable.
results <- results[
  order(
    results$taxon, results$region, results$stage, results$part,
    results$species, results$term
  ), ,
  drop = FALSE
]

coverage <- do.call(rbind, coverage)
rownames(coverage) <- NULL

results_path <- file.path(results_dir, "v2_results.csv")
coverage_path <- file.path(results_dir, "v2_results_coverage.csv")

fwrite(results, results_path, na = "")
fwrite(coverage, coverage_path, na = "")

cat("\nWrote", results_path, "\n")
cat(nrow(results), "rows,", length(unique(results$species)),
    "species,", length(unique(results$taxon)), "taxa, from",
    source_label, "\n\n")

print(coverage[, c("source_label", "reachable", "rows", "species",
                   "note")])

# End of script ----
