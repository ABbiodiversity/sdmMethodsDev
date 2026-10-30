# ---
# title: Check the Unified Prediction Grid
# author: Brendan Casey
# created: 2026-10-27
# inputs:
#   - 2_pipeline/shared/prediction_grid/<version>/, from 01
#   - the four grid sources (utils/grid_settings.R), re-read for
#     the comparisons against the raw files
#   - covariates.csv of the pinned test dataset
#     (harness/data_source.R), for the training ranges
# outputs:
#   - <version>/qa_summary.csv: one row per check, with status
#     pass, note or fail
#   - <version>/qa_covariate_ranges.csv: training range per
#     taxon and covariate, and the share of grid cells outside
#   - docs/prediction_grid_qa.md
#   - 2_pipeline/shared/prediction_grid/manifest.md, rewritten
# notes:
#   - Implements docs/prediction_design.md section 1.8. "fail" means
#     the grid does not match its sources or the lattice and must
#     not be published; "note" records a fact a user needs, such
#     as cells outside a taxon's training range.
#   - The cell table is compared with the raw kgrid in full, not
#     sampled. The land cover is compared in full against a
#     sparse re-summary and, for 200 seeded random cells, against
#     a transcription of v2.0's landscape_hf_summary() run on
#     dense rows, as v2.0 runs it.
#   - Run from the repository root after 01. About 3 minutes.
# ---

# 1. Setup ----

## 1.1 Load packages ----
library(data.table) # tables (version: 1.18.0)
library(Matrix) # sparse land cover (version: 1.7.3)
library(terra) # raster from cell numbers (version: 1.9.46)
library(sciSpatialR) # ab_grid(), check_alignment() (version: 0.1.0)

## 1.2 Settings ----
if (!file.exists("1_code/_prediction_grid/utils/grid_settings.R")) {
  stop("Run this from the repository root.", call. = FALSE)
}

source("1_code/_prediction_grid/utils/grid_settings.R")
source("1_code/harness/data_source.R")

version <- prediction_grid_settings$version
grid_dir <- grid_build_dir(version)
report_path <- "docs/prediction_grid_qa.md"
n_spot <- 200
prop_tol <- 1e-9

if (!file.exists(file.path(grid_dir, "build_record.csv"))) {
  stop("No built grid at ", grid_dir, ". Run 01 first.",
       call. = FALSE)
}

## 1.3 Import data ----
cells <- readRDS(file.path(grid_dir, "cells.rds"))
lc_spec <- prediction_grid_settings$landcover
landcover <- lapply(lc_spec$layer, function(layer) {
  readRDS(file.path(grid_dir, paste0("landcover_", layer, ".rds")))
})
names(landcover) <- lc_spec$layer

src <- lapply(names(prediction_grid_settings$sources),
              grid_source)
names(src) <- names(prediction_grid_settings$sources)

kgrid_env <- new.env()
load(src$kgrid, envir = kgrid_env)
kgrid <- kgrid_env$kgrid

backfill_env <- new.env()
load(src$backfill, envir = backfill_env)
d_wide <- backfill_env$d.wide
rm(kgrid_env, backfill_env)

lookups <- list(
  veg_lookup = read.csv(src$veg_lookup),
  soil_lookup = read.csv(src$soil_lookup)
)

# 2. Check helpers ----

## 2.1 add_check() ----
qa <- list()

#' Record One QA Check
#'
#' @param group Character. The check group, for the report.
#' @param check Character. What was checked.
#' @param ok Logical. TRUE passes; FALSE is `if_false`.
#' @param value Character. The measured value.
#' @param if_false Character. "fail" or "note".
#' @return NULL, invisibly; appends to `qa`.
#'
#' @example # Example usage of the function
#' # add_check("Cells", "Cell count", nrow(cells) == 664762,
#' #           nrow(cells))
add_check <- function(group, check, ok, value,
                      if_false = "fail") {
  qa[[length(qa) + 1]] <<- data.table(
    group = group,
    check = check,
    status = if (isTRUE(ok)) "pass" else if_false,
    value = paste(value, collapse = "; ")
  )
  invisible(NULL)
}

# Counts in full, tiny values in scientific notation, the rest
# to `digits` significant figures
fmt <- function(x, digits = 3) {
  vapply(x, function(v) {
    if (is.na(v)) {
      return("NA")
    }

    if (v == round(v) && abs(v) < 1e15) {
      return(format(v, big.mark = ",", scientific = FALSE))
    }

    if (v != 0 && abs(v) < 1e-3) {
      return(format(signif(v, digits), scientific = TRUE))
    }

    format(signif(v, digits), big.mark = ",", scientific = FALSE)
  }, character(1))
}

# 3. Cells, IDs, lattice ----

## 3.1 Count and IDs ----
add_check("Cells", "Cell count is 664,762",
          nrow(cells) == 664762, fmt(nrow(cells)))
add_check("Cells", "LinkID unique, no NA",
          !anyDuplicated(cells$LinkID) && !anyNA(cells$LinkID),
          paste(sum(duplicated(cells$LinkID)), "duplicates,",
                sum(is.na(cells$LinkID)), "NA"))
add_check("Cells", "LinkID and order identical to kgrid_2.2",
          identical(cells$LinkID, as.character(kgrid$LinkID)),
          "compared in full")
add_check("Cells", "LinkID == Row_Col",
          identical(cells$LinkID,
                    paste(cells$Row, cells$Col, sep = "_")),
          "compared in full")

## 3.2 Lattice, extent, CRS ----
# A raster from the cell numbers must align with ab_grid() and
# fill exactly its non-NA cells.
lattice <- ab_grid()
grid_rast <- rast(lattice)
values(grid_rast) <- NA_real_
grid_rast[cells$cell] <- 1

aligned <- check_alignment(grid_rast, lattice, verbose = FALSE)
add_check("Lattice", "check_alignment() against ab_grid()",
          length(aligned) > 0 && all(aligned),
          paste0(names(aligned), " ", aligned))
add_check("Lattice", "CRS is EPSG:3400",
          identical(crs(grid_rast, describe = TRUE)$code, "3400"),
          crs(grid_rast, describe = TRUE)$code)
add_check("Lattice", "Extent and resolution",
          isTRUE(all.equal(unname(as.vector(ext(grid_rast))),
                           c(170616.2, 865616.2, 5425532,
                             6659532),
                           tolerance = 1e-6)) &&
            all(res(grid_rast) == 1000),
          paste(round(as.vector(ext(grid_rast)), 1),
                collapse = " "))

lattice_cells <- which(!is.na(values(lattice, mat = FALSE)))
add_check("Lattice", "Cells equal the non-NA ab_grid() cells",
          identical(sort(cells$cell), as.integer(lattice_cells)),
          paste(fmt(length(lattice_cells)), "lattice cells"))
add_check("Lattice", "Easting/Northing fall in their cell",
          identical(
            as.integer(cellFromXY(lattice,
                                  cbind(cells$Easting,
                                        cells$Northing))),
            cells$cell
          ),
          "compared in full")

# 4. Attributes against the raw kgrid ----
# Every stored kgrid column must equal its source exactly.

## 4.1 Exact copies ----
copied <- c(
  "Row", "Col", "Easting", "Northing", "Longitude", "Latitude",
  "AreaKm2", "wN", "wS", "pAspen", "pWater", "Elevation",
  prediction_grid_settings$climate
)
# NAs must sit in the same cells (HTV has some)
differs <- copied[!vapply(copied, function(v) {
  a <- cells[[v]]
  b <- kgrid[[v]]
  isTRUE(all((a == b) | (is.na(a) & is.na(b)), na.rm = FALSE) &&
           identical(is.na(a), is.na(b)))
}, logical(1))]
add_check("Attributes",
          paste(length(copied), "kgrid columns identical"),
          length(differs) == 0,
          if (length(differs) == 0) "all identical" else differs)

factors <- c("NrName", "NsrName", "LufName",
             "ReportingBoundaries", "LinkID10")
differs <- factors[!vapply(factors, function(v) {
  identical(cells[[v]], as.character(kgrid[[v]]))
}, logical(1))]
add_check("Attributes", "Region and ID labels identical",
          length(differs) == 0,
          if (length(differs) == 0) "all identical" else differs)

add_check("Attributes", "UTMX/UTMY equal Easting/Northing",
          identical(cells$UTMX, cells$Easting) &&
            identical(cells$UTMY, cells$Northing),
          "compared in full")
add_check("Attributes", "PET equals Eref",
          identical(cells$PET, as.numeric(cells$Eref)) ||
            identical(cells$PET, cells$Eref),
          "compared in full")

## 4.2 Region weights ----
w_sum <- cells$wN + cells$wS
add_check("Weights", "wN + wS = 1",
          max(abs(w_sum - 1)) < 1e-12,
          paste("max |wN + wS - 1| =", fmt(max(abs(w_sum - 1)))))

w_frac <- cells[wN > 0 & wN < 1, .N, by = NrName][order(-N)]
add_check("Weights", "Cells with fractional wN (by NrName)",
          FALSE,
          paste0(w_frac$NrName, " ", fmt(w_frac$N)),
          if_false = "note")

## 4.3 NA counts ----
na_counts <- vapply(cells, function(x) sum(is.na(x)), numeric(1))
na_cols <- na_counts[na_counts > 0]
add_check("Attributes", "NA values by column",
          length(na_cols) == 0,
          if (length(na_cols) == 0) "none" else
            paste(names(na_cols), na_cols),
          if_false = "note")

## 4.4 TD against MWMT - MCMT ----
# The harness derives TD as MWMT - MCMT when a taxon lacks it;
# the grid uses the kgrid's stored TD.
td_diff <- abs(cells$TD - (cells$MWMT - cells$MCMT))
add_check("Attributes", "kgrid TD equals MWMT - MCMT (0.1 C)",
          max(td_diff) <= 0.1 + 1e-9,
          paste("max difference", fmt(max(td_diff)), "C"),
          if_false = "note")

# 5. Land cover ----

## 5.1 Proportions per layer ----
for (layer in names(landcover)) {
  rs <- rowSums(landcover[[layer]])
  bad <- which(abs(rs - 1) > prop_tol)
  add_check(
    "Land cover", paste(layer, "rows sum to 1"),
    length(bad) == 0,
    if (length(bad) == 0) {
      paste("max |sum - 1| =", fmt(max(abs(rs - 1))))
    } else {
      paste(length(bad), "rows; first:",
            paste(head(cells$LinkID[bad], 5), collapse = ", "))
    }
  )
  add_check(
    "Land cover", paste(layer, "has no negative or NA values"),
    !anyNA(landcover[[layer]]@x) && min(landcover[[layer]]@x) >= 0,
    paste("min", fmt(min(landcover[[layer]]@x)))
  )
}

## 5.2 Backfill area against AreaKm2 ----
area_diff <- cells$landcover_m2 / 1e6 - cells$AreaKm2
add_check("Land cover", "Backfill area per cell equals AreaKm2",
          max(abs(area_diff)) < 1e-3,
          paste0(
            fmt(sum(abs(area_diff) > 1e-3)), " cells differ by ",
            "more than 0.001 km2; max |difference| = ",
            fmt(max(abs(area_diff))), " km2. Proportions use ",
            "the backfill area, as in v2.0"
          ),
          if_false = "note")

## 5.3 Every layer against the raw backfill ----
# Full comparison: re-sum the raw m2 by class and divide.
for (i in seq_len(nrow(lc_spec))) {
  m <- d_wide[[lc_spec$d_wide[i]]]
  lk <- lookups[[lc_spec$lookup[i]]]
  lk <- lk[lk$ID %in% colnames(m), ]
  stored <- landcover[[lc_spec$layer[i]]]

  same_classes <- identical(
    colnames(stored), unique(lk$UseInAnalysis_Simplified)
  )
  worst <- 0

  if (same_classes) {
    for (k in colnames(stored)) {
      ids <- lk$ID[lk$UseInAnalysis_Simplified == k]
      raw <- rowSums(m[, ids, drop = FALSE]) /
        cells$landcover_m2
      worst <- max(worst, max(abs(raw - stored[, k])))
    }
  }

  add_check(
    "Land cover",
    paste(lc_spec$layer[i], "equals raw backfill (all cells)"),
    same_classes && worst < 1e-12,
    if (same_classes) {
      paste("classes in lookup order; max difference", fmt(worst))
    } else {
      "class names or order differ from the lookup"
    }
  )
}

## 5.4 Spot check against v2.0's own function ----
# landscape_hf_summary() transcribed from
# 0_data/v2_scripts/birds/00.Functions.R:14-45, run on dense
# rows as v2.0 runs it.
v2_landscape_hf_summary <- function(data.in, landscape.lookup,
                                    class.in, class.out) {
  landscape.lookup <- landscape.lookup[
    landscape.lookup[, class.in] %in% colnames(data.in),
  ]
  out_classes <- unique(landscape.lookup[, class.out])
  landscape.clean <- matrix(nrow = nrow(data.in),
                            ncol = length(out_classes))

  for (abmi.coef in seq_along(out_classes)) {
    coef.temp <- as.character(landscape.lookup[
      landscape.lookup[, class.out] %in%
        as.character(out_classes)[abmi.coef],
      class.in
    ])

    if (length(coef.temp) == 1) {
      landscape.clean[, abmi.coef] <- data.in[, coef.temp]
    } else {
      landscape.clean[, abmi.coef] <- rowSums(data.in[, coef.temp])
    }
  }

  colnames(landscape.clean) <- as.character(out_classes)
  rownames(landscape.clean) <- rownames(data.in)
  landscape.clean
}

set.seed(20261027)
spot <- sort(sample(nrow(cells), n_spot))

for (i in seq_len(nrow(lc_spec))) {
  m <- d_wide[[lc_spec$d_wide[i]]]
  dense <- as.data.frame(as.matrix(m[spot, , drop = FALSE]))
  v2 <- v2_landscape_hf_summary(
    dense, lookups[[lc_spec$lookup[i]]],
    class.in = "ID", class.out = "UseInAnalysis_Simplified"
  )
  v2 <- v2 / rowSums(v2)
  stored <- as.matrix(landcover[[lc_spec$layer[i]]][spot, ])
  ok <- identical(colnames(v2), colnames(stored)) &&
    identical(rownames(v2), cells$LinkID[spot])
  worst <- if (ok) max(abs(v2 - stored)) else NA

  add_check(
    "Land cover",
    paste(lc_spec$layer[i], "equals v2.0 function,", n_spot,
          "random cells"),
    ok && worst < 1e-12,
    if (ok) paste("max difference", fmt(worst)) else
      "class names or LinkIDs differ"
  )
}

## 5.5 Class sets ----
classes <- fread(file.path(grid_dir, "landcover_classes.csv"))

for (reg in c("north", "south")) {
  cur <- classes[region == reg & scenario == "current", class]
  ref <- classes[region == reg & scenario == "reference",
                 class]
  add_check(
    "Land cover",
    paste(reg, "reference classes are a subset of current"),
    all(ref %in% cur),
    paste0(length(cur), " current, ", length(ref),
           " reference classes",
           if (!all(ref %in% cur)) {
             paste0("; reference only: ",
                    paste(setdiff(ref, cur), collapse = ", "))
           } else {
             ""
           }),
    if_false = "note"
  )
}

rm(d_wide, kgrid)

# 6. Covariate ranges against the training data ----
# Cells outside a taxon's training range are extrapolation, not
# a grid error, so these are notes.

## 6.1 Training ranges ----
range_vars <- c(
  prediction_grid_settings$climate, "PET", "pAspen", "UTMX",
  "UTMY"
)
covariates_path <- file.path(test_dataset_dir(), "covariates.csv")
header <- names(fread(covariates_path, nrows = 0))
train_vars <- intersect(range_vars, header)
train <- fread(covariates_path, select = c("taxon", train_vars))

ranges <- rbindlist(lapply(train_vars, function(v) {
  train[!is.na(get(v)), .(
    covariate = v,
    train_min = min(get(v)),
    train_max = max(get(v)),
    train_n = .N
  ), by = taxon]
}))

## 6.2 Share of grid cells outside ----
# Region-specific training sets (mammal_north, mammal_south) are
# compared only with the cells their region's model predicts:
# wN > 0 for north, wS > 0 for south. Other taxa's climate
# models cover the province.
cells_in <- function(taxon) {
  if (endsWith(taxon, "_north")) {
    cells$wN > 0
  } else if (endsWith(taxon, "_south")) {
    cells$wS > 0
  } else {
    rep(TRUE, nrow(cells))
  }
}

ranges[, cells_used := fifelse(
  endsWith(taxon, "_north"), "wN > 0",
  fifelse(endsWith(taxon, "_south"), "wS > 0", "province")
)]
ranges[, `:=`(
  grid_min = mapply(function(v, tx) {
    min(cells[[v]][cells_in(tx)], na.rm = TRUE)
  }, covariate, taxon),
  grid_max = mapply(function(v, tx) {
    max(cells[[v]][cells_in(tx)], na.rm = TRUE)
  }, covariate, taxon),
  share_outside = mapply(function(v, tx, lo, hi) {
    x <- cells[[v]][cells_in(tx)]
    mean(x < lo | x > hi, na.rm = TRUE)
  }, covariate, taxon, train_min, train_max)
)]
setorder(ranges, taxon, -share_outside)
fwrite(ranges, file.path(grid_dir, "qa_covariate_ranges.csv"))

worst_range <- ranges[, .SD[which.max(share_outside)], by = taxon]
add_check(
  "Training ranges",
  "Largest share of cells outside the training range, by taxon",
  FALSE,
  worst_range[, paste0(taxon, " ", covariate, " ",
                       fmt(100 * share_outside, 2), "%")],
  if_false = "note"
)

no_train <- setdiff(range_vars, header)
missing_by_taxon <- ranges[, .(n = .N), by = taxon][
  n < length(train_vars)]
add_check(
  "Training ranges",
  "Grid covariates with no training values",
  length(no_train) == 0 && nrow(missing_by_taxon) == 0,
  c(
    if (length(no_train) > 0) {
      paste("absent from covariates.csv:",
            paste(no_train, collapse = ", "))
    },
    if (nrow(missing_by_taxon) > 0) {
      paste0(missing_by_taxon$taxon, " has ", missing_by_taxon$n,
             " of ", length(train_vars))
    }
  ),
  if_false = "note"
)

# 7. Write ----

## 7.1 The summary table ----
qa <- rbindlist(qa)
qa[, checked := format(Sys.time(), "%Y-%m-%d %H:%M")]
fwrite(qa, file.path(grid_dir, "qa_summary.csv"))

## 7.2 The report ----
md_table <- function(d) {
  d <- as.data.frame(d)
  c(
    paste0("| ", paste(names(d), collapse = " | "), " |"),
    paste0("|", strrep(" --- |", ncol(d))),
    apply(d, 1, function(r) {
      paste0("| ", paste(gsub("|", "\\|", r, fixed = TRUE),
                         collapse = " | "),
             " |")
    })
  )
}

top_ranges <- ranges[share_outside > 0][
  order(taxon, -share_outside)][, head(.SD, 5), by = taxon]
top_ranges <- top_ranges[, .(
  taxon, covariate, cells = cells_used,
  train = paste(fmt(train_min, 4), "to", fmt(train_max, 4)),
  grid = paste(fmt(grid_min, 4), "to", fmt(grid_max, 4)),
  `% cells outside` = fmt(100 * share_outside, 2)
)]

writeLines(c(
  paste0("# Prediction grid QA: ", version),
  "",
  paste0(
    "Checked ", qa$checked[1], " by ",
    "`1_code/_prediction_grid/02_qa_prediction_grid.R` on the ",
    "local build in `", grid_dir, "`. Design: ",
    "[prediction_design.md](prediction_design.md) section 1.8."
  ),
  "",
  paste0(
    "**Result:** ", sum(qa$status == "pass"), " pass, ",
    sum(qa$status == "note"), " note, ",
    sum(qa$status == "fail"), " fail. A fail means the grid ",
    "doesn't match its sources or the lattice. A note records ",
    "a fact users need."
  ),
  "",
  "## Checks",
  "",
  md_table(qa[, .(group, check, status, value)]),
  "",
  "## Covariates outside the training range",
  "",
  paste0(
    "Training ranges come from `covariates.csv` in the pinned ",
    "test dataset (", basename(test_dataset_dir()), "). Up to ",
    "five covariates per taxon with the largest share of grid ",
    "cells outside the range. Every grid covariate the taxon ",
    "stores is listed, whether or not its models use it. ",
    "Mammal north and south are compared only with the cells ",
    "their model predicts (`wN > 0`, `wS > 0`). The full table ",
    "is `qa_covariate_ranges.csv` in the version folder."
  ),
  "",
  md_table(top_ranges),
  ""
), report_path)

## 7.3 The manifest ----
write_grid_manifest()

cat("\n", sum(qa$status == "pass"), " pass, ",
    sum(qa$status == "note"), " note, ",
    sum(qa$status == "fail"), " fail\nReport: ", report_path,
    "\n", sep = "")

if (any(qa$status == "fail")) {
  print(qa[status == "fail"])
}

# End of script ----
