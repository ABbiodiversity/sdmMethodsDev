# ---
# title: Harmonize the v2 Results into One Parity Reference
# author: Brendan Casey
# created: 2026-09-13
# inputs:
#   plants, in the VegetationModels project:
#     - 3_output/coefficients/COEFS.RData
#   mammals, on the ABMI Mammals drive:
#     - .../Landcover/North/Coefficient Tables/*.Rdata
#     - .../Landcover/South/Coefficient Tables/*.Rdata
#     - .../Climate/Coefficients/* Climate Coefficients.RData
#   birds, preferred:
#     - 2_pipeline/v2_reference/Birds2024.RData, from
#       1_code/_setup/04_package_bird_coefficients.R
#   birds, fallback, on the work_abmi shared drive reached
#   through remote/BirdModels.lnk:
#     - Results/Archive/ClimateModels/Coefficients/<sp>/*.csv
#     - Results/Archive/LandcoverModels/Coefficients/<region>/
#       <sp>/*.csv
# outputs:
#   - 0_data/v2_results/v2_results.csv
#   - 0_data/v2_results/v2_results_coverage.csv
# notes:
#   - Legacy: not re-run. Parity is scored against the
#     ABMIexploreR reference (08). Its output is published frozen
#     with 0_data/v2_results/ by 10_publish_datasets.R, and its
#     inputs are not mirrored to ABMI-DATA2.
#   - One long table of the published v2 results, so that a run
#     in 3_output/exp_000_parity_v2/ can be scored against a
#     single file rather than against three storage formats on
#     two drives.
#
#   - The v2 outputs are stored three different ways. Plants are
#     3-D arrays of species by term by bootstrap draw. Mammal
#     landcover is a species-by-term matrix with no draws, since
#     that stage fits once. Mammal climate is one small data
#     frame per species. This flattens all three to the same
#     columns, and records `v2_n` so a consumer can tell a
#     100-draw distribution from a single fitted value.
#
#   - Plants come from COEFS.RData rather than from the
#     per-taxon model files. That is v2's own standardization
#     output, and its header says it exists "to allow for the
#     checking of model coefficients between versions", which is
#     this exact use. It also sidesteps a trap: the published
#     bryophyte-species-models.Rdata is entirely error objects,
#     while the bryophyte arrays inside COEFS.RData are complete
#     and finite. COEFS was built before that file was
#     overwritten by a failed re-run.
#
#   - Mammal seasons are averaged, not selected. v2 writes one
#     row per species in its `.all` tables, holding the mean of
#     the summer and winter fits where both exist and the single
#     fit where only one does. The harness models seasons
#     separately, so a `Moose_Summer` result is NOT comparable
#     to the moose row here unless moose is summer-only. The
#     season column says "all" to make that visible rather than
#     leaving it to be discovered. Comparing properly means
#     averaging the harness's two seasons first.
#
#   - Plant climate is fitted once on all data, not per region,
#     so those rows carry region "all". A run's north and south
#     climate results are both scored against them.
#
#   - Birds are the slow one, and are cached. Their coefficients
#     are stored as one small csv per species per draw, roughly
#     31,000 files, on a Google Drive mount that costs about
#     470 ms per file opened serially. Reading them twelve at a
#     time brings a full pass to about half an hour, and the
#     result is cached so a re-run is seconds. Delete the cache
#     or set refresh_birds to rebuild it.
#
#   - The bird path in the v2 scripts, G:/Shared drives/
#     ABMI_RHedley/Projects/BirdModels, is not mounted here. The
#     same directory is reached through a shortcut on the
#     work_abmi drive, which resolves to a shortcut-targets-by-id
#     path. That resolved path is the default below.
#
#   - Bird results are taken from Results/Archive/, not from
#     Results/. The live directory holds a partial re-run of a
#     single species from August 2026; the archive holds the last
#     complete set, 133 species for climate and 112 north and 68
#     south for landcover. The two disagree numerically, as two
#     runs of an unseeded pipeline must, so they are not mixed.
#     The script picks whichever has more species and says which
#     it used.
#
#   - Read only. Nothing is written to either source drive.
# ---

# 1. Setup ----

## 1.1 Load packages ----
library(data.table) # fast csv reading and writing (v: 1.16.4)
library(parallel) # bird reads are latency-bound (version: 4.5.0)

## 1.2 Resolve the source locations ----
# Overridable, because the drives are mounted differently on
# different machines.
project_root <- normalizePath(getwd(), winslash = "/")

v2_plant_project <- Sys.getenv(
  "SDM_V2_PROJECT",
  unset = "//ABMI-DATA2/science/sc/ToEmily/VegetationModels"
)

v2_mammal_root <- Sys.getenv(
  "SDM_V2_MAMMAL_ROOT",
  unset = paste0(
    "G:/Shared drives/ABMI Mammals/Results/Habitat Modeling/2024"
  )
)

# The path in the v2 scripts is not mounted. This is the same
# directory reached through remote/BirdModels.lnk on work_abmi.
v2_bird_root <- Sys.getenv(
  "SDM_V2_BIRD_ROOT",
  unset = paste0(
    "G:/.shortcut-targets-by-id/",
    "17Ymt13eHfKvIiuoMl6x-Kn74Z2uVbbzS/BirdModels"
  )
)

# Birds cost about half an hour on a cold cache. FALSE skips
# them and records the taxon as deliberately excluded.
include_birds <- TRUE

# TRUE ignores the cache and re-reads every file.
refresh_birds <- FALSE

# 1 reads serially, which is the only setting measured to be
# reliable here: concurrency trips a refusal state in Google
# Drive that outlasts retries. Serial costs about three hours
# for the full set, once, and then it is cached.
bird_workers <- 1L

# The harmonized reference is analysis-ready data, so it sits in
# 0_data alongside v2_scripts rather than in 2_pipeline. What
# stays in 2_pipeline is genuinely intermediate: the bird read
# cache, and the packaged bird object that 04 writes.
results_dir <- file.path(project_root, "0_data/v2_results")

out_dir <- file.path(project_root, "2_pipeline/v2_reference")

for (one in c(results_dir, out_dir)) {
  dir.create(one, recursive = TRUE, showWarnings = FALSE)
}

## 1.3 Name the output columns ----
# Declared once so every reader returns the same frame and a
# missing source cannot quietly change the schema.
result_columns <- c(
  "taxon", "region", "stage", "part", "season",
  "species", "species_v2", "term",
  "v2_median", "v2_p10", "v2_p90", "v2_se", "v2_n", "source"
)

# 2. Plants ----
# COEFS[[group]][[part]] is species x term x draw.

## 2.1 Name the mapping from v2 groups to data slugs ----
plant_groups <- c(
  Bryophytes = "bryophyte",
  Lichens = "lichen",
  Mites = "mite",
  VascularPlants = "vascular_plant"
)

# v2 fits vegetation in the north and soil in the south. Climate
# is fitted once on everything.
plant_parts <- list(
  vegetation = list(region = "north", stage = "habitat"),
  soil = list(region = "south", stage = "habitat"),
  climate = list(region = "all", stage = "climate")
)

## 2.2 read_plant_results() ----

#' Flatten the Plant Coefficient Arrays
#'
#' @param path Character. Path to COEFS.RData.
#' @return A data frame in the output schema, or NULL.
#'
#' @example # Example usage of the function
#' # read_plant_results("3_output/coefficients/COEFS.RData")
read_plant_results <- function(path) {
  if (!file.exists(path)) {
    return(NULL)
  }

  env <- new.env()
  load(path, envir = env)

  if (is.null(env$COEFS)) {
    return(NULL)
  }

  rows <- list()

  for (group in names(env$COEFS)) {
    slug <- plant_groups[[group]]

    if (is.null(slug)) {
      next
    }

    for (part in names(plant_parts)) {
      values <- env$COEFS[[group]][[part]]

      if (is.null(values) || length(dim(values)) != 3) {
        next
      }

      # Summarized across draws, which is dimension three. The
      # band is what the gate scores against, so it is computed
      # here once rather than in every consumer.
      summarize <- function(f) {
        apply(values, c(1, 2), function(x) {
          x <- x[is.finite(x)]

          if (length(x) == 0) {
            return(NA_real_)
          }

          f(x)
        })
      }

      medians <- summarize(stats::median)
      p10 <- summarize(function(x) {
        stats::quantile(x, 0.1, names = FALSE)
      })
      p90 <- summarize(function(x) {
        stats::quantile(x, 0.9, names = FALSE)
      })
      counts <- apply(values, c(1, 2), function(x) {
        sum(is.finite(x))
      })

      species <- rownames(medians)
      terms <- colnames(medians)

      block <- data.frame(
        taxon = slug,
        region = plant_parts[[part]]$region,
        stage = plant_parts[[part]]$stage,
        part = "detection",
        season = NA_character_,
        species = rep(species, times = length(terms)),
        species_v2 = rep(species, times = length(terms)),
        term = rep(terms, each = length(species)),
        v2_median = as.vector(medians),
        v2_p10 = as.vector(p10),
        v2_p90 = as.vector(p90),
        v2_se = NA_real_,
        v2_n = as.vector(counts),
        source = basename(path),
        stringsAsFactors = FALSE
      )

      rows[[paste(group, part)]] <- block[block$v2_n > 0, ]
    }
  }

  if (length(rows) == 0) {
    return(NULL)
  }

  do.call(rbind, rows)
}

# 3. Mammals ----

## 3.1 mammal_key() ----

#' Reduce a v2 Mammal Name to the Harness Key
#'
#' v2 names species with spaces and punctuation, and the
#' harmonized response squashes them. Reducing both to letters
#' is what the existing comparison already does.
#'
#' @param x Character vector of v2 species names.
#' @return Character vector of keys.
#'
#' @example # Example usage of the function
#' # mammal_key("Elk (wapiti)") # "Elkwapiti"
mammal_key <- function(x) {
  gsub("[^A-Za-z]", "", x)
}

## 3.2 read_mammal_landcover() ----

#' Flatten One Mammal Landcover Coefficient Table
#'
#' The three reported quantities are different things, so each
#' is kept as its own `part` rather than merged: presence is a
#' probability, abundance-given-presence is on the response
#' scale, and total is their calibrated product.
#'
#' @param dir_path Character. A Coefficient Tables directory.
#' @param region Character. "north" or "south".
#' @return A data frame in the output schema, or NULL.
#'
#' @example # Example usage of the function
#' # read_mammal_landcover(dir_path, "north")
read_mammal_landcover <- function(dir_path, region) {
  if (!dir.exists(dir_path)) {
    return(NULL)
  }

  files <- sort(list.files(
    dir_path, pattern = "[.]Rdata$", full.names = TRUE
  ))

  if (length(files) == 0) {
    return(NULL)
  }

  # The newest table wins. v2 keeps dated copies side by side.
  path <- files[length(files)]

  env <- new.env()
  load(path, envir = env)

  parts <- list(
    presence = c("Coef.pa.all", "Coef.pa.se.all"),
    abundance = c("Coef.agp.all", "Coef.agp.se.all"),
    total = c("Coef.mean.all", "Coef.mean.se.all")
  )

  rows <- list()

  for (part in names(parts)) {
    estimates <- env[[parts[[part]][1]]]
    errors <- env[[parts[[part]][2]]]

    if (is.null(estimates)) {
      next
    }

    species <- rownames(estimates)
    terms <- colnames(estimates)

    # The standard errors are a separate matrix and can carry a
    # different term set, so they are matched by name.
    se_values <- if (is.null(errors)) {
      rep(NA_real_, length(estimates))
    } else {
      as.vector(errors[
        match(species, rownames(errors)),
        match(terms, colnames(errors)),
        drop = FALSE
      ])
    }

    rows[[part]] <- data.frame(
      taxon = "mammal",
      region = region,
      stage = "habitat",
      part = part,
      # See the header: this is the mean of the seasons where
      # both were fitted, not one of them.
      season = "all",
      species = rep(mammal_key(species), times = length(terms)),
      species_v2 = rep(species, times = length(terms)),
      term = rep(terms, each = length(species)),
      v2_median = as.vector(estimates),
      v2_p10 = NA_real_,
      v2_p90 = NA_real_,
      v2_se = se_values,
      v2_n = 1L,
      source = basename(path),
      stringsAsFactors = FALSE
    )
  }

  if (length(rows) == 0) {
    return(NULL)
  }

  out <- do.call(rbind, rows)

  out[is.finite(out$v2_median), ]
}

## 3.3 read_mammal_climate() ----

#' Flatten the Mammal Climate Coefficients
#'
#' One file per species, each holding an AICc-averaged
#' coefficient per term. The mammal climate pipeline does not
#' bootstrap, so there is no band.
#'
#' @param dir_path Character. The Climate/Coefficients folder.
#' @return A data frame in the output schema, or NULL.
#'
#' @example # Example usage of the function
#' # read_mammal_climate(dir_path)
read_mammal_climate <- function(dir_path) {
  if (!dir.exists(dir_path)) {
    return(NULL)
  }

  files <- list.files(
    dir_path, pattern = "Climate Coefficients[.]RData$",
    full.names = TRUE
  )

  if (length(files) == 0) {
    return(NULL)
  }

  rows <- lapply(files, function(path) {
    env <- new.env()
    load(path, envir = env)

    if (is.null(env$avg_coef)) {
      return(NULL)
    }

    name <- sub(
      " Climate Coefficients[.]RData$", "", basename(path)
    )

    data.frame(
      taxon = "mammal",
      region = "all",
      stage = "climate",
      part = "presence",
      season = "all",
      species = mammal_key(name),
      species_v2 = name,
      # v2 names the intercept with parentheses here and without
      # them in the plant tables. Normalized to the plant form,
      # which is what the comparison already expects.
      term = sub(
        "^\\(Intercept\\)$", "Intercept",
        as.character(env$avg_coef$term)
      ),
      v2_median = as.numeric(env$avg_coef$coef),
      v2_p10 = NA_real_,
      v2_p90 = NA_real_,
      v2_se = NA_real_,
      v2_n = 1L,
      source = basename(path),
      stringsAsFactors = FALSE
    )
  })

  out <- do.call(rbind, rows)

  if (is.null(out)) {
    return(NULL)
  }

  out[is.finite(out$v2_median), ]
}

# 4. Birds ----
# One csv per species per draw, on a high-latency mount.

## 4.1 bird_source_dir() ----

#' Choose Between the Live and Archived Bird Results
#'
#' The live directory holds a partial re-run; the archive holds
#' the last complete set. Two runs of an unseeded pipeline give
#' different numbers, so they are never mixed: whichever covers
#' more species wins outright.
#'
#' @param root Character. The BirdModels directory.
#' @param leaf Character. Path below Results, for example
#'   "ClimateModels/Coefficients".
#' @return A list of dir, label and species count, or NULL.
#'
#' @example # Example usage of the function
#' # bird_source_dir(root, "ClimateModels/Coefficients")
bird_source_dir <- function(root, leaf) {
  options <- list(
    live = file.path(root, "Results", leaf),
    archive = file.path(root, "Results", "Archive", leaf)
  )

  counts <- vapply(options, function(one) {
    if (!dir.exists(one)) {
      return(-1L)
    }

    length(list.dirs(one, recursive = FALSE))
  }, integer(1))

  if (all(counts < 0)) {
    return(NULL)
  }

  best <- names(counts)[which.max(counts)]

  list(
    dir = options[[best]],
    label = best,
    species = counts[[best]]
  )
}

## 4.2 read_bird_csv_set() ----

#' Read Every Draw for Every Species Under One Directory
#'
#' Worked one species at a time, with retries, because this
#' mount fails under sustained parallel load. Two things were
#' learned the hard way and are encoded here.
#'
#' A single parallel call over all 13,300 files kills the socket
#' cluster part-way through and loses everything, so the unit of
#' work is one species, about a hundred files.
#'
#' Under load, Google Drive starts refusing to materialize files
#' with "Invalid request code". The failure is transient: every
#' file that failed in one pass read correctly moments later.
#' So a failed read is retried inside the worker after a pause,
#' failed species are retried again at the end, and the caller
#' is told what is still missing rather than being handed a
#' quietly short result.
#'
#' @param dir_path Character. Holds one directory per species.
#' @param term_column Character. Which column names the term.
#'   The climate files write rownames into an unnamed first
#'   column, which fread calls V1; the landcover files carry a
#'   "name" column instead.
#' @param workers Integer. Parallel readers. Kept low on
#'   purpose: throughput is not the constraint, the mount is.
#' @param attempts Integer. Passes over the species that failed.
#' @return A data frame of species, term, boot, coef and se,
#'   carrying a "failed" attribute naming any species missing.
#'
#' @example # Example usage of the function
#' # read_bird_csv_set(dir_path, "V1", workers = 4)
read_bird_csv_set <- function(dir_path, term_column, workers,
                              attempts = 3L) {
  species_dirs <- list.dirs(dir_path, recursive = FALSE)

  if (length(species_dirs) == 0) {
    return(NULL)
  }

  cat("  ", length(species_dirs), " species directories\n",
      sep = "")

  # workers = 1 means no cluster at all. Measured on this mount:
  # 400 consecutive serial reads succeeded with zero failures at
  # about 360 ms each, where four parallel readers threw the
  # mount into a refusal state that outlasted several retries.
  # Concurrency, not volume, is what trips it.
  serial <- workers <= 1L

  cluster <- if (serial) NULL else makeCluster(workers)

  on.exit(
    if (!is.null(cluster)) try(stopCluster(cluster), silent = TRUE),
    add = TRUE
  )

  # Retried inside the worker, because a refusal is transient
  # and a short pause is cheaper than losing the species.
  read_file <- function(path) {
    for (try_n in 1:4) {
      x <- tryCatch(
        data.table::fread(path), error = function(e) NULL
      )

      if (!is.null(x) && nrow(x) > 0) {
        return(as.data.frame(x))
      }

      Sys.sleep(0.25 * try_n)
    }

    NULL
  }

  if (!serial) {
    clusterExport(cluster, "read_file", envir = environment())
  }

  read_species <- function(files) {
    if (serial) {
      return(lapply(files, read_file))
    }

    parLapply(cluster, files, read_file)
  }

  started <- Sys.time()
  collected <- list()
  pending <- species_dirs

  for (pass in seq_len(attempts)) {
    if (length(pending) == 0) {
      break
    }

    if (pass > 1) {
      cat("    retry pass ", pass, " for ", length(pending),
          " species\n", sep = "")

      # A refusal state persists well past twenty seconds, which
      # is why the first retrying version still failed every
      # pass. Two minutes is what it takes to clear.
      Sys.sleep(120)
    }

    still_pending <- character(0)

    for (index in seq_along(pending)) {
      one_dir <- pending[index]
      species <- basename(one_dir)

      files <- list.files(
        one_dir, pattern = "[.]csv$", full.names = TRUE
      )

      if (length(files) == 0) {
        next
      }

      parts <- tryCatch(
        read_species(files),
        error = function(e) NULL
      )

      # A dead cluster is the other failure mode; rebuild it.
      if (is.null(parts) && !serial) {
        try(stopCluster(cluster), silent = TRUE)
        cluster <- makeCluster(workers)
        clusterExport(
          cluster, "read_file", envir = environment()
        )

        parts <- tryCatch(
          read_species(files),
          error = function(e) NULL
        )
      }

      usable <- !vapply(parts, is.null, logical(1))

      if (is.null(parts) || !any(usable)) {
        still_pending <- c(still_pending, one_dir)
        next
      }

      draws <- suppressWarnings(as.integer(sub(
        "[.]csv$", "", sub(".*_", "", basename(files))
      )))

      rows <- lapply(which(usable), function(i) {
        x <- parts[[i]]

        if (!term_column %in% names(x)) {
          return(NULL)
        }

        data.frame(
          species = species,
          term = as.character(x[[term_column]]),
          boot = draws[i],
          coef = as.numeric(x$coef),
          se = as.numeric(x$se),
          stringsAsFactors = FALSE
        )
      })

      collected[[species]] <- do.call(rbind, rows)

      # A species read only in part is worth keeping but is not
      # complete, so it goes round again.
      if (sum(usable) < length(files)) {
        still_pending <- c(still_pending, one_dir)
      }

      if (index %% 20 == 0 || index == length(pending)) {
        cat("    ", index, " of ", length(pending), " (",
            format(round(Sys.time() - started, 1)), ")\n",
            sep = "")
      }
    }

    pending <- still_pending
  }

  failed <- basename(pending)

  if (length(failed) > 0) {
    cat("    incomplete after ", attempts, " passes: ",
        length(failed), " species (",
        paste(utils::head(failed, 5), collapse = ", "), ")\n",
        sep = "")
  }

  out <- do.call(rbind, collected)

  if (is.null(out)) {
    return(NULL)
  }

  out <- out[is.finite(out$coef), ]
  attr(out, "failed") <- failed

  out
}

## 4.3 summarize_bird_draws() ----

#' Reduce Bird Draws to the Output Schema
#'
#' @param draws A data frame from read_bird_csv_set().
#' @param region Character. "north", "south" or "all".
#' @param stage Character. "climate" or "habitat".
#' @param source Character. Which directory it came from.
#' @return A data frame in the output schema, or NULL.
#'
#' @example # Example usage of the function
#' # summarize_bird_draws(draws, "north", "habitat", "archive")
summarize_bird_draws <- function(draws, region, stage, source) {
  if (is.null(draws) || nrow(draws) == 0) {
    return(NULL)
  }

  # Grouped with data.table rather than by pasting species and
  # term into one string key. A pasted key needs a separator
  # that can appear in neither, and bird terms legitimately
  # carry punctuation such as I(Easting^2) and Easting:Northing.
  values <- data.table::as.data.table(draws)

  summary_rows <- as.data.frame(
    values[
      is.finite(coef),
      list(
        v2_median = stats::median(coef),
        v2_p10 = stats::quantile(coef, 0.1, names = FALSE),
        v2_p90 = stats::quantile(coef, 0.9, names = FALSE),
        v2_n = .N
      ),
      by = list(species, term)
    ]
  )

  if (nrow(summary_rows) == 0) {
    return(NULL)
  }

  data.frame(
    taxon = "bird",
    region = region,
    stage = stage,
    # Birds model counts, not detection or density.
    part = "count",
    season = NA_character_,
    species = summary_rows$species,
    species_v2 = summary_rows$species,
    # v2 writes the intercept with parentheses here; normalized
    # to the plant form that the comparison expects.
    term = sub(
      "^[(]Intercept[)]$", "Intercept", summary_rows$term
    ),
    v2_median = summary_rows$v2_median,
    v2_p10 = summary_rows$v2_p10,
    v2_p90 = summary_rows$v2_p90,
    v2_se = NA_real_,
    v2_n = summary_rows$v2_n,
    source = source,
    stringsAsFactors = FALSE
  )
}

## 4.4 read_bird_results() ----

#' Read and Cache Every Bird Result
#'
#' @param root Character. The BirdModels directory.
#' @param cache_path Character. Where the cached frame lives.
#' @param workers Integer. Parallel readers.
#' @param refresh Logical. TRUE ignores any cache.
#' @return A list of rows and a note.
#'
#' @example # Example usage of the function
#' # read_bird_results(root, cache_path, 12L, FALSE)
read_bird_results <- function(root, cache_path, workers,
                              refresh = FALSE) {
  if (!refresh && file.exists(cache_path)) {
    cat("Reading birds from cache:", cache_path, "\n")

    return(list(rows = readRDS(cache_path), note = "from cache"))
  }

  if (!dir.exists(root)) {
    return(list(rows = NULL, note = "bird root not reachable"))
  }

  blocks <- list()
  labels <- character(0)
  missing <- character(0)

  climate <- bird_source_dir(root, "ClimateModels/Coefficients")

  if (!is.null(climate)) {
    cat("Reading bird climate (", climate$label, "):\n", sep = "")

    draws <- read_bird_csv_set(climate$dir, "V1", workers)

    blocks$climate <- summarize_bird_draws(
      draws, "all", "climate", paste("bird", climate$label)
    )

    missing <- c(missing, attr(draws, "failed"))
    labels <- c(labels, paste0("climate: ", climate$label))
  }

  for (region in c("north", "south")) {
    leaf <- file.path("LandcoverModels/Coefficients", region)
    landcover <- bird_source_dir(root, leaf)

    if (is.null(landcover)) {
      next
    }

    cat("Reading bird landcover ", region, " (",
        landcover$label, "):\n", sep = "")

    draws <- read_bird_csv_set(landcover$dir, "name", workers)

    blocks[[region]] <- summarize_bird_draws(
      draws, region, "habitat", paste("bird", landcover$label)
    )

    missing <- c(missing, attr(draws, "failed"))
    labels <- c(labels, paste0(region, ": ", landcover$label))
  }

  kept <- blocks[!vapply(blocks, is.null, logical(1))]

  if (length(kept) == 0) {
    return(list(rows = NULL, note = "no bird coefficients found"))
  }

  rows <- do.call(rbind, kept)

  note <- paste(labels, collapse = "; ")

  # An incomplete read is never cached. Caching one would make
  # the next run silently reuse a short reference, which is the
  # worst of both: fast and wrong.
  if (length(missing) > 0) {
    note <- paste0(
      note, "; INCOMPLETE, ", length(missing),
      " species unread, not cached"
    )

    cat("  not caching: ", length(missing),
        " species could not be read
", sep = "")

    return(list(rows = rows, note = note))
  }

  dir.create(
    dirname(cache_path), recursive = TRUE, showWarnings = FALSE
  )
  saveRDS(rows, cache_path)

  list(rows = rows, note = note)
}

## 4.5 read_packaged_birds() ----

#' Flatten the Packaged Bird Object
#'
#' Reads the `birds` object that 04_package_bird_coefficients.R
#' writes, which is the v2 packaging step run against the
#' per-draw csvs.
#'
#' Preferred over reading those csvs directly for two reasons.
#' It is one file rather than 31,000 on a mount that throttles.
#' And its coefficients are already on the cross-taxa
#' standardized template, the same WhiteSpruceR and Loamy term
#' space the plant tables use, rather than the raw glm factor
#' names vegcCrop and soilcLoamy, which nothing else shares.
#'
#' The object holds `marginal` for the climate stage and `joint`
#' for the landcover stage, each species by term by draw. The
#' north and south entries carry the same `marginal`, because v2
#' fits climate once on all data, so it is read from the north
#' entry only and filed as region "all".
#'
#' @param path Character. Path to the packaged Birds RData.
#' @return A data frame in the output schema, or NULL.
#'
#' @example # Example usage of the function
#' # read_packaged_birds("2_pipeline/v2_reference/Birds2024.RData")
read_packaged_birds <- function(path) {
  if (!file.exists(path)) {
    return(NULL)
  }

  env <- new.env()
  load(path, envir = env)

  birds <- env$birds

  if (is.null(birds) || is.null(birds$north)) {
    return(NULL)
  }

  # Summarized across draws, which is the third dimension.
  summarize_array <- function(values, region, stage) {
    if (is.null(values) || length(dim(values)) != 3) {
      return(NULL)
    }

    across <- function(f) {
      apply(values, c(1, 2), function(x) {
        x <- x[is.finite(x)]

        if (length(x) == 0) {
          return(NA_real_)
        }

        f(x)
      })
    }

    medians <- across(stats::median)
    p10 <- across(function(x) {
      stats::quantile(x, 0.1, names = FALSE)
    })
    p90 <- across(function(x) {
      stats::quantile(x, 0.9, names = FALSE)
    })
    counts <- apply(values, c(1, 2), function(x) {
      sum(is.finite(x))
    })

    species <- rownames(medians)
    terms <- colnames(medians)

    out <- data.frame(
      taxon = "bird",
      region = region,
      stage = stage,
      # Birds model counts, not detection or density.
      part = "count",
      season = NA_character_,
      species = rep(species, times = length(terms)),
      species_v2 = rep(species, times = length(terms)),
      term = rep(terms, each = length(species)),
      v2_median = as.vector(medians),
      v2_p10 = as.vector(p10),
      v2_p90 = as.vector(p90),
      v2_se = NA_real_,
      v2_n = as.vector(counts),
      source = basename(path),
      stringsAsFactors = FALSE
    )

    out[out$v2_n > 0, ]
  }

  rows <- list(
    climate = summarize_array(
      birds$north$marginal, "all", "climate"
    ),
    north = summarize_array(
      birds$north$joint, "north", "habitat"
    ),
    south = summarize_array(
      birds$south$joint, "south", "habitat"
    )
  )

  kept <- rows[!vapply(rows, is.null, logical(1))]

  if (length(kept) == 0) {
    return(NULL)
  }

  do.call(rbind, kept)
}

# 5. Assemble ----

blocks <- list()
coverage <- list()

#' Record What a Source Contributed
#'
#' @param label Character. Taxon or taxon and stage.
#' @param rows A data frame or NULL.
#' @param where Character. The path looked at.
#' @param reason Character. Why it is empty, when it is.
#' @return A one-row data frame.
#'
#' @example # Example usage of the function
#' # note_source("plants", rows, path, NA)
note_source <- function(label, rows, where, reason = NA) {
  data.frame(
    source_label = label,
    reachable = !is.null(rows) && nrow(rows) > 0,
    rows = if (is.null(rows)) 0L else nrow(rows),
    species = if (is.null(rows)) {
      0L
    } else {
      length(unique(rows$species))
    },
    looked_in = where,
    note = reason,
    stringsAsFactors = FALSE
  )
}

## 5.1 Plants ----
plant_path <- file.path(
  v2_plant_project, "3_output/coefficients/COEFS.RData"
)

cat("Reading plants from", plant_path, "\n")

plant_rows <- read_plant_results(plant_path)
blocks$plants <- plant_rows

coverage$plants <- note_source(
  "plants (4 taxa)", plant_rows, plant_path,
  if (is.null(plant_rows)) "COEFS.RData not found" else NA
)

## 5.2 Mammal landcover ----
for (region in c("north", "south")) {
  dir_path <- file.path(
    v2_mammal_root, "Landcover",
    tools::toTitleCase(region), "Coefficient Tables"
  )

  cat("Reading mammal", region, "from", dir_path, "\n")

  rows <- read_mammal_landcover(dir_path, region)
  blocks[[paste0("mammal_", region)]] <- rows

  coverage[[paste0("mammal_", region)]] <- note_source(
    paste("mammal landcover", region), rows, dir_path,
    if (is.null(rows)) "no coefficient table found" else NA
  )
}

## 5.3 Mammal climate ----
climate_dir <- file.path(v2_mammal_root, "Climate/Coefficients")

cat("Reading mammal climate from", climate_dir, "\n")

climate_rows <- read_mammal_climate(climate_dir)
blocks$mammal_climate <- climate_rows

coverage$mammal_climate <- note_source(
  "mammal climate", climate_rows, climate_dir,
  if (is.null(climate_rows)) "no coefficient files found" else NA
)

## 5.4 Birds ----
# The packaged object first. 04_package_bird_coefficients.R
# builds it by running the v2 packaging step against the
# per-draw csvs, which is the only way birds reach the
# cross-taxa standardized term space. Reading the csvs here is
# the fallback for when that has not been run: it works, but it
# yields raw glm factor names that join to nothing else.
bird_packaged <- file.path(out_dir, "Birds2024.RData")
bird_cache <- file.path(out_dir, "cache/bird_v2_results.rds")

if (!include_birds) {
  coverage$bird <- note_source(
    "bird", NULL, v2_bird_root,
    "skipped; set include_birds to TRUE"
  )
} else if (file.exists(bird_packaged)) {
  bird_rows <- read_packaged_birds(bird_packaged)

  blocks$bird <- bird_rows

  coverage$bird <- note_source(
    "bird", bird_rows, bird_packaged,
    "packaged, standardized term space"
  )
} else {
  cat(
    "No packaged birds at ", bird_packaged,
    "\n  falling back to the per-draw csvs; run",
    " 04_package_bird_coefficients.R\n  for the standardized",
    " term space.\n",
    sep = ""
  )

  bird_result <- read_bird_results(
    v2_bird_root, bird_cache, bird_workers, refresh_birds
  )

  blocks$bird <- bird_result$rows

  coverage$bird <- note_source(
    "bird", bird_result$rows, v2_bird_root,
    paste("raw csvs;", bird_result$note)
  )
}

# 6. Write ----

kept <- blocks[!vapply(blocks, is.null, logical(1))]
results <- do.call(rbind, kept)

if (is.null(results) || nrow(results) == 0) {
  stop(
    "No v2 results were reachable. Check the drive mounts and ",
    "the SDM_V2_* environment variables.",
    call. = FALSE
  )
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

results_path <- file.path(results_dir, "v2_results.csv")
coverage_path <- file.path(
  results_dir, "v2_results_coverage.csv"
)

fwrite(results, results_path, na = "")
fwrite(do.call(rbind, coverage), coverage_path, na = "")

cat("\nWrote", results_path, "\n")
cat(nrow(results), "rows,", length(unique(results$species)),
    "species,", length(unique(results$taxon)), "taxa\n\n")

print(as.data.frame(table(results$taxon, results$stage)))

cat("\nCoverage:\n")
print(do.call(rbind, coverage)[, c(
  "source_label", "reachable", "rows", "species"
)])

# End of script ----
