# ---
# title:   Process 1km² Grid for North Models
# author:  Marcus Becker
# created: 2026-05-15
# updated: 2026-05-15
#
# inputs:
#   veg-hf_grid_v61hf2016v3WildFireUpTo2016.Rdata
#     Sparse matrices of veg + HF cover per km²
#     cell (dd_kgrid: veg_current, veg_reference)
#   kgrid_2.2.Rdata
#     Grid cell metadata: LinkID, lat/long, NR/NSR/
#     LUF, Easting/Northing, and climate variables.
#     Note: column names differ from kgrid_table_km
#     (Longitude/Latitude/NrName/NsrName/LufName).
#   lookup-hf-class.csv
#     Lookup for grouping fine-grained HF types
#     into model-ready categories
#
# outputs:
#   km2-grid-north_current-backfilled_
#   processed_YYYY-MM-DD.RData
#     km2_current   current veg + HF grid
#     km2_reference backfilled (reference) grid
#
# notes:
#   North region = all cells where NR != "Grassland".
#   Age class 9 is collapsed into class 8 for all
#   forest types (insufficient data in class 9).
#   WetlandMargin is always 0 (not mapped at the
#   1km² scale). NSR_ALT dummy columns are produced
#   for use in spatial models. The reference grid
#   uses the same veg aggregation but has no HF
#   columns (backfilled = no human footprint).
#   HFor absorbs CC* types; this differs from south
#   models where HFor is excluded entirely.
# ---

rm(list = ls())
gc()

# ── 1. Setup ─────────────────────────────────────

library(tidyverse)
library(Matrix)

g_drive <- "G:/Shared drives/ABMI Mammals/"

f_kgrid_hf <- paste0(
  g_drive,
  "Data/Habitat Models/",
  "veg-hf_grid_v61hf2016v3",
  "WildFireUpTo2016.Rdata"
)

# kgrid_2.2: newer grid from S drive with updated
# climate variables and revised column names
f_kgrid_info <- paste0(
  "S:/sc/AB_data_v2023/",
  "kgrid/kgrid_2.2.Rdata"
)

f_lookup <- paste0(
  g_drive,
  "Data/Habitat Models/",
  "lookup-hf-class.csv"
)

f_out <- paste0(
  g_drive,
  "Data/Habitat Models/",
  "km2-grid-north_",
  "current-backfilled_",
  "processed_", Sys.Date(), ".RData"
)

# ── 2. Load input data ───────────────────────────

## 2.1 Veg + HF sparse matrices ----

# Loads dd_kgrid (list of sparse matrices)
load(f_kgrid_hf)

veg_current   <- dd_kgrid[["veg_current"]]
veg_reference <- dd_kgrid[["veg_reference"]]
rm(dd_kgrid)
gc()

## 2.2 Grid cell metadata ----

# Loads kgrid (data frame; rows = grid cells).
# kgrid_2.2 has LinkID as a regular column
# (not row names, unlike kgrid_table_km).
load(f_kgrid_info)

kgrid_info <- kgrid |>
  rename(
    Long    = Longitude,
    TrueLat = Latitude,
    NR      = NrName,
    NSR     = NsrName,
    LUF     = LufName
  ) |>
  # Floor latitude at 51.5 for spatial models
  # (reduces influence of southernmost north cells)
  mutate(Lat = pmax(TrueLat, 51.5)) |>
  select(
    LinkID, Lat, Long, TrueLat,
    NR, NSR, LUF, pAspen,
    Easting, Northing, MAT:AgeOffset
  )

rm(kgrid)

## 2.3 HF group lookup ----

# First column may carry a BOM prefix in the CSV;
# rename_with handles it regardless of name
hf_gl <- read_csv(
  f_lookup, show_col_types = FALSE
) |>
  rename_with(~ "HF_GROUP", .cols = 1)

# ── 3. Convert sparse matrices to proportions ────

# Converts a sparse veg/HF matrix to a data frame
# with cover expressed as proportions of cell area.
# Note: as.matrix() on large sparse objects is
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

message("Converting veg_current ...")
veg_current   <- as_prop_df(veg_current)
gc()

message("Converting veg_reference ...")
veg_reference <- as_prop_df(veg_reference)
gc()

# ── 4. Join metadata and filter to north ─────────

# North = everything except Grassland NR. No soil-
# coverage filter is applied here; the veg grid
# provides full coverage for all north cells.
km2_current <- kgrid_info |>
  left_join(veg_current, by = "LinkID") |>
  filter(NR != "Grassland")

km2_reference <- kgrid_info |>
  left_join(veg_reference, by = "LinkID") |>
  filter(NR != "Grassland")

rm(veg_current, veg_reference)
gc()

message(
  nrow(km2_current),
  " km² cells retained in north region."
)

# ── 5. Aggregate veg types ───────────────────────

# Collapse fine-grained veg classes into model-
# ready groups. Age class 9 is absorbed into 8.
# WetlandMargin is set to 0 (not mapped at 1km²).
aggregate_veg <- function(df) {
  df |>
    mutate(
      TreedSwamp       = rowSums(
        across(TreedSwamp1:TreedSwamp9)
      ),
      TreedFen         = rowSums(
        across(TreedFen1:TreedFen9)
      ),
      TreedShrubSwamp  = TreedSwamp + ShrubbySwamp,
      NonTreedFenMarsh = ShrubbyFen + GraminoidFen +
                         Marsh,
      # Collapse age class 9 into 8
      Spruce8    = Spruce8    + Spruce9,
      Pine8      = Pine8      + Pine9,
      Decid8     = Decid8     + Decid9,
      Mixedwood8 = Mixedwood8 + Mixedwood9,
      TreedBog8  = TreedBog8  + TreedBog9,
      TreedFen8  = TreedFen8  + TreedFen9,
      WetlandMargin = 0
    ) |>
    select(-ends_with("9"))
}

message("Aggregating veg types (current) ...")
km2_current   <- aggregate_veg(km2_current)

message("Aggregating veg types (reference) ...")
km2_reference <- aggregate_veg(km2_reference)

# ── 6. Add NSR dummy columns ──────────────────────

# Recode NSR into 7 broad groups for spatial models,
# then pivot to wide dummy-column format.
add_nsr_dummies <- function(df) {
  df |>
    mutate(NSR_ALT = case_when(
      NSR %in% c(
        "Central Parkland",
        "Foothills Parkland",
        "Peace River Parkland"
      )                          ~ "NSR1Parkland",
      NSR == "Dry Mixedwood"     ~ "NSR1DryMixedwood",
      NSR == "Central Mixedwood" ~ "NSR1CentralMixedwood",
      NSR %in% c(
        "Lower Foothills",
        "Upper Foothills"
      )                          ~ "NSR1Foothills",
      NSR %in% c(
        "Lower Boreal Highlands",
        "Upper Boreal Highlands",
        "Boreal Subarctic",
        "Northern Mixedwood"
      )                          ~ "NSR1North",
      NSR %in% c(
        "Kazan Uplands",
        "Peace-Athabasca Delta",
        "Athabasca Plain"
      )                          ~ "NSR1Shield",
      NSR %in% c(
        "Montane", "Subalpine", "Alpine"
      )                          ~ "NSR1Mountain"
    )) |>
    mutate(value = 1L) |>
    pivot_wider(
      names_from  = NSR_ALT,
      values_from = value,
      values_fill = list(value = 0L)
    )
}

km2_current   <- add_nsr_dummies(km2_current)
km2_reference <- add_nsr_dummies(km2_reference)

# ── 7. Aggregate HF types (current only) ─────────

# The reference grid has no HF columns (backfilled).
# Three grouping schemes are applied in sequence:
#   UseInAnalysis — primary analysis groups
#   SuccAlien     — successional vs. alien
#   NonlinLin     — linear vs. non-linear
# HFor absorbs CC* (cutblock) columns; unlike south
# models, HFor is retained in the north.
add_hf_groups <- function(df, lookup, group_col,
                           add_cc_to = NULL) {
  groups <- lookup |>
    pull(all_of(group_col)) |>
    unique() |>
    na.omit()

  for (grp in groups) {
    types <- lookup |>
      filter(.data[[group_col]] == grp) |>
      pull(HF_GROUP) |>
      intersect(colnames(df))

    if (!is.null(add_cc_to) && grp == add_cc_to) {
      cc_cols <- str_subset(colnames(df), "^CC")
      types   <- union(types, cc_cols)
    }

    if (length(types) == 0) next

    df <- df |>
      mutate(
        !!grp := rowSums(across(all_of(types)))
      )
  }
  df
}

message("Aggregating HF types ...")
km2_current <- km2_current |>
  add_hf_groups(
    hf_gl, "UseInAnalysis", add_cc_to = "HFor"
  ) |>
  add_hf_groups(
    hf_gl, "SuccAlien", add_cc_to = "Succ"
  ) |>
  add_hf_groups(
    hf_gl, "NonlinLin", add_cc_to = "Nonlin"
  )

# ── 8. Save output ───────────────────────────────

save(
  km2_current,
  km2_reference,
  file = f_out
)

message("Done. Output saved to:\n", f_out)
