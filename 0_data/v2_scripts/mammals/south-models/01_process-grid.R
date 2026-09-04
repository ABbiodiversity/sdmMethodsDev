# ---
# title:   Process 1km^2 Grid for South Models
# author:  Marcus Becker
# created: 2025-05-14
# updated: 2026-05-14
#
# inputs:
#   veg-hf_grid_v61hf2016v3WildFireUpTo2016.Rdata
#     Sparse matrices of soil + HF cover per km2
#     cell (dd_kgrid: soil_current, soil_reference)
#   kgrid_table_km.Rdata
#     Grid cell metadata: lat/long, natural region,
#     NSR, LUF, and climate variables
#   lookup-soil-hf-v2020.csv
#     Lookup for grouping fine-grained soil and
#     HF types into model-ready categories
#
# outputs:
#   km2-grid-south_current-backfilled_
#   processed_2026-05-14.RData
#     km2_current   current soil + HF grid
#     km2_reference backfilled (reference) grid
#
# notes:
#   South region = cells with soil information and
#   TrueLat < 56.7. The reference grid is required
#   to correctly exclude cells that lack soil info
#   but are currently 100% HF. HFor is excluded
#   from south models. WetlandMargin is always 0
#   in the south (not mapped in GIS).
# ---

rm(list = ls())
gc()

# ── 1. Setup ─────────────────────────────────────

library(tidyverse)

g_drive <- "G:/Shared drives/ABMI Mammals/"

# Subdirectory for habitat model data
path_data <- paste0(
  g_drive,
  "Data/Habitat Models/"
)

# Input files
f_kgrid_hf <- paste0(
  path_data,
  "veg-hf_grid_v61hf2016v3",
  "WildFireUpTo2016.Rdata"
)

f_kgrid_info <- paste0(
  path_data,
  "kgrid_table_km.Rdata"
)

f_lookup <- paste0(
  path_data,
  "lookup-soil-hf-v2020.csv"
)

# Output file
f_out <- paste0(
  path_data,
  "km2-grid-south_",
  "current-backfilled_",
  "processed_2026-05-14.RData"
)

# ── 2. Load input data ───────────────────────────

## 2.1 Soil + HF sparse matrices ----

# Loads dd_kgrid (list of sparse matrices)
load(f_kgrid_hf)

soil_current   <- dd_kgrid[["soil_current"]]
soil_reference <- dd_kgrid[["soil_reference"]]
rm(dd_kgrid)
gc()

## 2.2 Grid cell metadata ----

# Loads kgrid (data frame, rows = grid cells)
load(f_kgrid_info)

kgrid_info <- kgrid |>
  rownames_to_column(var = "LinkID") |>
  rename(
    Long    = POINT_X,
    TrueLat = POINT_Y,
    NR      = NRNAME,
    NSR     = NSRNAME,
    LUF     = LUF_NAME
  ) |>
  # Cap latitude at 56.5 for spatial models
  # (reduces N parkland outsized influence)
  mutate(Lat = pmin(TrueLat, 56.5)) |>
  select(
    LinkID, Lat, Long, TrueLat,
    NR, NSR, LUF, pAspen,
    AHM, PET, FFP, MAP, MAT, MCMT, MWMT
  )

rm(kgrid)

## 2.3 Soil and HF group lookup ----

# First column (type ID) has a BOM prefix in the
# CSV; rename_with handles it regardless of name
soil_gl <- read_csv(f_lookup) |>
  filter(Sector == "Native") |>
  rename_with(~ "ID", .cols = 1)

# HF types are everything outside the native sector
hf_gl <- read_csv(f_lookup) |>
  filter(Sector != "Native") |>
  rename_with(~ "HF_GROUP", .cols = 1)

# ── 3. Process soil grids ────────────────────────

# Convert a sparse soil/HF matrix to a data frame
# with cover expressed as proportions of cell area.
# Note: as.matrix() on a large sparse matrix is
# memory-intensive; gc() is called after each step.
as_prop_df <- function(mat) {
  data.frame(as.matrix(mat)) |>
    mutate(
      cell_area = rowSums(across(everything()))
    ) |>
    mutate(
      across(-last_col(), ~ .x / cell_area)
    ) |>
    rownames_to_column(var = "LinkID") |>
    select(LinkID, cell_area, everything())
}

## 3.1 Convert to proportions ----

message("Converting soil_current ...")
soil_current   <- as_prop_df(soil_current)
gc()

message("Converting soil_reference ...")
soil_reference <- as_prop_df(soil_reference)
gc()

## 3.2 Join kgrid metadata ----

km2_current <- kgrid_info |>
  left_join(soil_current, by = "LinkID")

km2_reference <- kgrid_info |>
  left_join(soil_reference, by = "LinkID")

rm(soil_current, soil_reference)
gc()

## 3.3 Filter to south region ----

# Derive valid LinkIDs from the reference grid.
# A cell is valid if it has soil information
# (UNK == 0) and is not water-dominated
# (UNK + Water < 0.99). The reference grid is
# authoritative here: a cell may be currently
# 100% HF yet still lack soil information.
valid_ids <- km2_reference |>
  filter(
    UNK == 0,
    UNK + Water < 0.99,
    TrueLat < 56.7
  ) |>
  pull(LinkID)

km2_current <- km2_current |>
  filter(LinkID %in% valid_ids)

km2_reference <- km2_reference |>
  filter(LinkID %in% valid_ids)

message(
  nrow(km2_current),
  " km2 cells retained in south region."
)

# ── 4. Aggregate soil types ──────────────────────

# Collapse fine-grained soil types into the model-
# ready groups defined in the lookup table.
# Types not present in the grid are ignored.
aggregate_soil <- function(df, lookup, groups) {
  for (sg in groups) {
    types <- lookup |>
      filter(UseInAnalysis == sg) |>
      pull(ID) |>
      intersect(colnames(df))

    df <- df |>
      mutate(
        !!sg := rowSums(across(all_of(types)))
      )
  }
  # WetlandMargin not mapped in GIS; always 0
  df |> mutate(WetlandMargin = 0)
}

soil_groups <- unique(soil_gl$UseInAnalysis)

message("Aggregating soil types (current) ...")
km2_current <- aggregate_soil(
  km2_current, soil_gl, soil_groups
)

message("Aggregating soil types (reference) ...")
km2_reference <- aggregate_soil(
  km2_reference, soil_gl, soil_groups
)

# ── 5. Aggregate HF types (current only) ─────────

# HF types are not present in the reference grid
# (backfilled = no human footprint by definition).
# HFor is excluded from south models.
hf_groups <- hf_gl |>
  pull(UseInAnalysis) |>
  unique() |>
  setdiff("HFor")

message("Aggregating HF types ...")
for (hg in hf_groups) {
  types <- hf_gl |>
    filter(UseInAnalysis == hg) |>
    pull(HF_GROUP) |>
    intersect(colnames(km2_current))

  km2_current <- km2_current |>
    mutate(
      !!hg := rowSums(across(all_of(types)))
    )
}

# ── 6. Save output ───────────────────────────────

save(
  km2_current,
  km2_reference,
  file = f_out
)

message("Done. Output saved to:\n", f_out)
