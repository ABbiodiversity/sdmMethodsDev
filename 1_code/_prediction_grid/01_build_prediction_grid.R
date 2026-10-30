# ---
# title: Build the Unified Prediction Grid
# author: Brendan Casey
# created: 2026-10-27
# inputs:
#   - kgrid_2.2.Rdata (object `kgrid`), the v2.0 1 km grid
#   - backfillV7_w2w_2021HFI.Rdata (object `d.wide`), backfill
#     v7 land cover with 2021 HFI, m2 per cell and class
#   - lookup-veg-hf-age-v2020.csv, lookup-soil-hf-v2020.csv
#   (paths and md5s in utils/grid_settings.R)
# outputs:
#   in 2_pipeline/shared/prediction_grid/<version>/:
#     - cells.rds: data.table, one row per cell, LinkID order
#     - landcover_{veg,soil}_{current,reference}.rds: dgCMatrix
#       of class proportions, rows identical to cells$LinkID
#     - landcover_classes.csv: class order, IDs and area per layer
#     - lookups/: byte copies of the two lookups
#     - build_record.csv, README.md
#   - 2_pipeline/shared/prediction_grid/manifest.md, rewritten
# notes:
#   - One grid for every taxon: the v2.0 kgrid attributes and
#     backfill proportions on the sciSpatialR::ab_grid() 1 km
#     lattice. Nothing is recomputed from rasters, so prediction
#     covariates match the training covariates (decision D1).
#   - Land cover is summarized as v2.0's landscape_hf_summary()
#     does (birds/00.Functions.R:14-45, the same in mammals):
#     backfill IDs summed to UseInAnalysis_Simplified, classes in
#     lookup order, only classes present, divided by the row
#     total. Taxon-specific renames are module data, not grid.
#   - SDM_GRID_RES_M other than 1000 stops: there is no 500 m
#     backfill summary (docs/prediction_design.md section 1.1).
#   - An existing version is not overwritten unless
#     SDM_GRID_OVERWRITE=TRUE (local build only; published
#     versions are never overwritten).
#   - Run from the repository root. Reads ~225 MB over the
#     network; about 2 minutes and 6 GB of memory.
# ---

# 1. Setup ----

## 1.1 Load packages ----
library(data.table) # cell table (version: 1.18.0)
library(Matrix) # sparse land-cover matrices (version: 1.7.3)
library(terra) # lattice cell numbers (version: 1.9.46)
library(sciSpatialR) # ab_grid() lattice (version: 0.1.0)

## 1.2 Settings ----
if (!file.exists("1_code/_prediction_grid/utils/grid_settings.R")) {
  stop("Run this from the repository root.", call. = FALSE)
}

source("1_code/_prediction_grid/utils/grid_settings.R")

res_m <- as.numeric(Sys.getenv(
  "SDM_GRID_RES_M",
  unset = prediction_grid_settings$res_m
))

if (res_m != 1000) {
  stop(
    "Only res_m = 1000 can be built: the backfill land cover ",
    "exists only as 1 km cell summaries. A ", res_m, " m grid ",
    "needs the backfill v7 polygons summarized at ", res_m,
    " m first (docs/prediction_design.md section 1.1).",
    call. = FALSE
  )
}

version <- prediction_grid_settings$version
out_dir <- grid_build_dir(version)
overwrite <- isTRUE(as.logical(
  Sys.getenv("SDM_GRID_OVERWRITE", unset = "FALSE")
))

if (dir.exists(out_dir) && !overwrite) {
  stop(
    "Already built: ", out_dir,
    "\nSet SDM_GRID_OVERWRITE=TRUE to rebuild it locally.",
    call. = FALSE
  )
}

## 1.3 Import data ----
# Each source is checked against the md5 the version was named
# for before it is read.
src <- lapply(
  names(prediction_grid_settings$sources), grid_source
)
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

cat("Read kgrid (", nrow(kgrid), " cells) and backfill (",
    paste(names(d_wide), collapse = ", "), ")\n", sep = "")

# 2. Cell table ----
# kgrid columns as stored, IDs as character, plus the lattice
# cell number and the aliases the training covariates use.

## 2.1 Check the kgrid IDs ----
# kgrid row names are not LinkIDs; v2.0 joins on the column.
link_id <- as.character(kgrid$LinkID)

if (anyDuplicated(link_id) > 0 || anyNA(link_id)) {
  stop("kgrid LinkID has duplicates or NAs.", call. = FALSE)
}

if (!identical(link_id, paste(kgrid$Row, kgrid$Col, sep = "_"))) {
  stop("kgrid LinkID is not Row_Col.", call. = FALSE)
}

## 2.2 Place each cell on the ab_grid() lattice ----
# Cell numbers from Row/Col; Easting/Northing must fall in the
# same cell, which confirms the lattice is the kgrid's.
lattice <- ab_grid()
cell <- cellFromRowCol(lattice, kgrid$Row, kgrid$Col)
cell_xy <- cellFromXY(lattice, cbind(kgrid$Easting, kgrid$Northing))

if (anyNA(cell) || !identical(cell, cell_xy)) {
  stop(
    "kgrid Row/Col and Easting/Northing disagree with the ",
    "ab_grid() lattice in ",
    sum(is.na(cell) | cell != cell_xy, na.rm = TRUE), " cells.",
    call. = FALSE
  )
}

## 2.3 Assemble ----
# X and Y are dropped: they are not EPSG:3400 cell centres
# (docs/prediction_inventory.md section 5.3).
missing_clim <- setdiff(prediction_grid_settings$climate,
                        names(kgrid))

if (length(missing_clim) > 0) {
  stop("kgrid lacks climate columns: ",
       paste(missing_clim, collapse = ", "), call. = FALSE)
}

cells <- data.table(
  LinkID = link_id,
  Row = kgrid$Row,
  Col = kgrid$Col,
  cell = as.integer(cell),
  LinkID10 = as.character(kgrid$LinkID10),
  Row10 = as.integer(kgrid$Row10),
  Col10 = as.integer(kgrid$Col10),
  Easting = kgrid$Easting,
  Northing = kgrid$Northing,
  UTMX = kgrid$Easting,
  UTMY = kgrid$Northing,
  Longitude = kgrid$Longitude,
  Latitude = kgrid$Latitude,
  AreaKm2 = kgrid$AreaKm2,
  NrName = as.character(kgrid$NrName),
  NsrName = as.character(kgrid$NsrName),
  LufName = as.character(kgrid$LufName),
  ReportingBoundaries = as.character(kgrid$ReportingBoundaries),
  wN = kgrid$wN,
  wS = kgrid$wS,
  pAspen = kgrid$pAspen,
  pWater = kgrid$pWater,
  Elevation = kgrid$Elevation
)

# PET is Eref, as in the plant training data and the v2.0 plant
# grid (docs/prediction_inventory.md section 5.6)
for (v in prediction_grid_settings$climate) {
  set(cells, j = v, value = kgrid[[v]])
}

cells[, PET := Eref]

# 3. Land cover ----
# Each d.wide layer, in m2, to class proportions.

## 3.1 summarize_landcover() ----

#' Sum Backfill Columns to Simplified Classes, as Proportions
#'
#' Matches v2.0's landscape_hf_summary() followed by division
#' by the row total, but stays sparse.
#'
#' @param m dgCMatrix. Cells x backfill IDs, m2.
#' @param lookup data.frame. With `ID` and
#'   `UseInAnalysis_Simplified`.
#' @return A list: `prop` (dgCMatrix, cells x classes), `total`
#'   (numeric, m2 per cell), and `classes` (data.frame).
#'
#' @example # Example usage of the function
#' # summarize_landcover(d_wide$veg.current, lookups$veg_lookup)
summarize_landcover <- function(m, lookup) {
  # Step 1: Lookup rows for the IDs present, in lookup order;
  # IDs not in the lookup are dropped, as v2.0 drops them
  lookup <- lookup[lookup$ID %in% colnames(m), ]
  dropped <- setdiff(colnames(m), lookup$ID)
  classes <- unique(lookup$UseInAnalysis_Simplified)

  if (anyNA(classes) || any(classes == "")) {
    stop("Lookup has blank simplified classes.", call. = FALSE)
  }

  # Step 2: An ID x class indicator, then sum by product
  ind <- sparseMatrix(
    i = match(lookup$ID, colnames(m)),
    j = match(lookup$UseInAnalysis_Simplified, classes),
    x = 1,
    dims = c(ncol(m), length(classes)),
    dimnames = list(colnames(m), classes)
  )

  area <- m %*% ind
  total <- rowSums(area)

  # Step 3: Proportions; a zero-total row would be NaN in v2.0
  # and is left all-zero here, flagged by `total`
  scale <- ifelse(total > 0, 1 / total, 0)
  prop <- as(Diagonal(x = scale) %*% area, "CsparseMatrix")
  dimnames(prop) <- list(NULL, classes)

  ids <- vapply(classes, function(k) {
    paste(lookup$ID[lookup$UseInAnalysis_Simplified == k],
          collapse = ";")
  }, character(1))

  list(
    prop = prop,
    total = total,
    dropped = dropped,
    classes = data.frame(
      class = classes,
      order = seq_along(classes),
      backfill_ids = unname(ids),
      area_km2 = unname(colSums(area)) / 1e6
    )
  )
}

## 3.2 Summarize each layer ----
lc_spec <- prediction_grid_settings$landcover
landcover <- list()
class_tables <- list()

for (i in seq_len(nrow(lc_spec))) {
  m <- d_wide[[lc_spec$d_wide[i]]]

  # Rows must be the kgrid's cells in the kgrid's order
  if (!identical(rownames(m), link_id)) {
    stop(lc_spec$d_wide[i], " rows are not kgrid LinkID order.",
         call. = FALSE)
  }

  s <- summarize_landcover(m, lookups[[lc_spec$lookup[i]]])

  if (length(s$dropped) > 0) {
    warning(lc_spec$d_wide[i], ": backfill IDs not in the ",
            "lookup, dropped: ", paste(s$dropped, collapse = ", "))
  }

  landcover[[lc_spec$layer[i]]] <- s$prop
  class_tables[[i]] <- cbind(
    layer = lc_spec$layer[i],
    region = lc_spec$region[i],
    scenario = lc_spec$scenario[i],
    s$classes
  )

  # The backfill area per cell, kept once (same in every layer)
  if (i == 1) {
    cells[, landcover_m2 := s$total]
  } else if (max(abs(s$total - cells$landcover_m2)) > 1e-3) {
    warning(lc_spec$d_wide[i], " cell totals differ from ",
            lc_spec$d_wide[1], "'s.")
  }

  cat(sprintf("  %-15s %3d classes, %s cells with land cover\n",
              lc_spec$layer[i], ncol(s$prop),
              format(sum(s$total > 0), big.mark = ",")))
}

classes <- rbindlist(class_tables)
rm(d_wide, kgrid)

# 4. Write ----

## 4.1 The version folder ----
dir.create(file.path(out_dir, "lookups"), recursive = TRUE,
           showWarnings = FALSE)

saveRDS(cells, file.path(out_dir, "cells.rds"))

for (layer in names(landcover)) {
  saveRDS(landcover[[layer]],
          file.path(out_dir, paste0("landcover_", layer, ".rds")))
}

fwrite(classes, file.path(out_dir, "landcover_classes.csv"))

invisible(file.copy(src$veg_lookup,
          file.path(out_dir, "lookups", basename(src$veg_lookup)),
          overwrite = TRUE, copy.date = TRUE))
invisible(file.copy(src$soil_lookup,
          file.path(out_dir, "lookups", basename(src$soil_lookup)),
          overwrite = TRUE, copy.date = TRUE))

## 4.2 The build record ----
git_commit <- tryCatch(
  system2("git", c("rev-parse", "HEAD"), stdout = TRUE),
  error = function(e) "unknown"
)
git_dirty <- tryCatch(
  length(system2("git", c("status", "--porcelain"),
                 stdout = TRUE)) > 0,
  error = function(e) NA
)

record <- data.frame(
  key = c(
    "version", "built", "user", "script", "commit", "res_m",
    "cells", "lattice", "crs", "crosswalk", "R",
    paste0("source_", names(src))
  ),
  value = c(
    version,
    format(Sys.time(), "%Y-%m-%d %H:%M"),
    Sys.info()[["user"]],
    "1_code/_prediction_grid/01_build_prediction_grid.R",
    paste0(git_commit,
           if (isTRUE(git_dirty)) " (uncommitted changes)" else ""),
    res_m,
    nrow(cells),
    paste0(
      "sciSpatialR::ab_grid() ", nrow(lattice), " x ",
      ncol(lattice), ", ", res(lattice)[1], " m, extent ",
      paste(round(as.vector(ext(lattice)), 1), collapse = " ")
    ),
    "EPSG:3400",
    paste(
      "identity on LinkID: same cells, same order as kgrid_2.2",
      "(Row/Col and Easting/Northing fall in the same lattice",
      "cell for every row)"
    ),
    R.version.string,
    vapply(src, function(p) {
      paste(p, attr(p, "md5"), sep = " | ")
    }, character(1))
  )
)

fwrite(record, file.path(out_dir, "build_record.csv"))

## 4.3 The version README ----
writeLines(c(
  paste0("# Prediction grid ", version),
  "",
  "The unified 1 km prediction grid for every taxon: the v2.0",
  "kgrid 2.2 attributes and backfill v7 (2021 HFI) land-cover",
  "proportions on the `sciSpatialR::ab_grid()` lattice",
  "(EPSG:3400). Built by",
  "`1_code/_prediction_grid/01_build_prediction_grid.R`;",
  "design in `docs/prediction_design.md` section 1.",
  "",
  "| File | Content |",
  "| --- | --- |",
  paste0(
    "| `cells.rds` | data.table, ", nrow(cells), " rows in ",
    "kgrid `LinkID` order: IDs, `cell` (ab_grid cell number), ",
    "coordinates, regions, `wN`/`wS`, `pAspen`, climate, ",
    "`PET` (= `Eref`), `landcover_m2` |"
  ),
  paste0(
    "| `landcover_<region>_<scenario>.rds` | dgCMatrix of ",
    "class proportions, rows identical to `cells$LinkID`; ",
    "veg = north, soil = south |"
  ),
  "| `landcover_classes.csv` | Class order, backfill IDs, area |",
  "| `lookups/` | Byte copies of the v2020 lookups used |",
  "| `build_record.csv` | Sources with md5, commit, date |",
  "",
  "`UTMX`/`UTMY` repeat `Easting`/`Northing` under the",
  "training-data names. kgrid `X`/`Y` are dropped: they are",
  "not EPSG:3400 cell centres. `wN`/`wS` are stored as given",
  "in the kgrid."
), file.path(out_dir, "README.md"))

## 4.4 The manifest ----
manifest <- write_grid_manifest()

cat("\nBuilt ", out_dir, "\n  ",
    paste(list.files(out_dir, recursive = TRUE), collapse = "\n  "),
    "\nManifest: ", manifest, "\n", sep = "")

# End of script ----
