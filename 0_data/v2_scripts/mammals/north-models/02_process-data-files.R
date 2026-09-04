# ---
# title:   Process Data Files for North Models
# author:  Marcus Becker
# created: 2026-05-15
# updated: 2026-05-15
#
# inputs:
#   Density CSV (wide format)
#     One row per deployment x year; species
#     densities in columns (common_name_season
#     format, e.g. Beaver_summer)
#   VegHF point summary CSV
#     VEGHFAGEclass per deployment (one row per
#     deployment x project)
#   lookup-hf-class.csv
#     HF group definitions (UseInAnalysis,
#     SuccAlien, NonlinLin)
#   Deployment locations CSV
#     project, location, latitude, longitude
#   Site climate summary CSV
#     NR, NSR, LUF, climate vars per ABMI site
#   Lure CSV
#     ABMI and CMU only; NWSAR and BG are always
#     unlured and handled in script
#   Prediction matrix CSV (north)
#
# outputs:
#   R Dataset SpTable for ABMI North mammal
#   coefficients 2026.RData
#     d                 analysis-ready data frame
#     first_sp_col_summer, last_sp_col_summer
#     first_sp_col_winter, last_sp_col_winter
#     sp_table_summer, sp_table_summer_ua
#     sp_table_winter, sp_table_winter_ua
#     pred_matrix       north prediction matrix
#
# notes:
#   North region = NR in Boreal, Canadian Shield,
#   Foothills, Rocky Mountain, or Parkland; Water
#   sites excluded. VegHF age classes are the core
#   habitat variable (not soil types as in south).
#   GameTrail sites are excluded (CMU trail study).
#   All sites get NearestSite assigned from lat/long
#   distance to the closest ABMI site.
#   Bug fix from original: winter species are now
#   correctly set to NA (not summer) when
#   WinterDays < 10.
#   The north+south combined RData previously saved
#   here has been removed; the climate pipeline now
#   has its own data preparation script.
#   Paths marked !! need updating each cycle.
# ---

rm(list = ls())
gc()

# ── 1. Setup ─────────────────────────────────────

library(tidyverse)

g_drive <- "G:/Shared drives/ABMI Mammals/"

# Update density file each cycle
f_density <- paste0(
  g_drive,
  "Results/Density/Locations/Archive/",
  "all-projects_all-years_",
  "wide-density-for-habitat-modeling.csv"
)

f_veghf <- paste0(
  g_drive,
  "Data/Habitat Models/",
  "all-projects_all-years_",
  "veghfageclass-for-habitat-modeling.csv"
)

f_lookup <- paste0(
  g_drive,
  "Data/Habitat Models/",
  "lookup-hf-class.csv"
)

f_locations <- paste0(
  g_drive,
  "Data/Habitat Models/",
  "all-projects_all-years_",
  "locations-for-habitat-modeling.csv"
)

f_site_climate <- paste0(
  g_drive,
  "Data/Habitat Models/",
  "site-climate-summary_v2020.csv"
)

f_lure <- paste0(
  g_drive,
  "Data/Habitat Models/",
  "abmi-cmu_all-years_lure_2021-10-07.csv"
)

f_pred_matrix <- paste0(
  g_drive,
  "Data/Habitat Models/",
  "prediction-matrix_north.csv"
)

f_out <- paste0(
  g_drive,
  "Data/Habitat Models/",
  "R Dataset SpTable for ABMI North",
  " mammal coefficients 2024.RData"
)

# ── 2. Load lookups and auxiliary files ──────────

## 2.1 HF group lookup ----

# First column may carry a BOM prefix in the CSV;
# rename_with handles it regardless of name
hf_gl <- read_csv(
  f_lookup, show_col_types = FALSE
) |>
  rename_with(~ "HF_GROUP", .cols = 1)

## 2.2 ABMI site reference data ----

# Provides NR, NSR, LUF, and climate variables
# for each ABMI site. Deployments are linked to
# their nearest ABMI site in section 5.
# Note: PUBLIC_LATTITUDE is a typo in the source.
abmi_sites <- read_csv(
  f_site_climate, show_col_types = FALSE
) |>
  rename(
    Long = PUBLIC_LONGITUDE,
    Lat  = PUBLIC_LATTITUDE,
    NR   = NATURAL_REGIONS,
    NSR  = NATURAL_SUBREGIONS,
    LUF  = LANDUSE_FRAMEWORK
  )

## 2.3 Lure lookup ----

# NWSAR and Big Grids are always unlured and are
# assigned "No" explicitly in section 10.
lure_lookup <- read_csv(
  f_lure, show_col_types = FALSE
) |>
  rename(Lured = lure) |>
  mutate(
    location_project = paste(
      location, project, sep = "_"
    )
  ) |>
  distinct(location_project, .keep_all = TRUE)

## 2.4 Prediction matrix ----

pred_matrix <- read_csv(
  f_pred_matrix, show_col_types = FALSE
)

# ── 3. Process density data ───────────────────────

# Species columns are named <common_name>_<season>
# (e.g. Beaver_summer, Black Bear_summer). Rename
# to PascalSuffix format (BeaverSummer) by replacing
# the _season suffix while preserving common names
# (including spaces and hyphens in multi-word names
# such as White-tailed Jack RabbitSummer).
density <- read_csv(
  f_density, show_col_types = FALSE
) |>
  rename_with(
    ~ .x |>
      str_replace("_summer$", "Summer") |>
      str_replace("_winter$", "Winter") |>
      str_remove_all("\\."),
    .cols = matches("_summer$|_winter$")
  ) |>
  filter(
    str_detect(
      project,
      paste(
        "ABMI Ecosystem Health",
        "Northern Focal",
        "Big Grids",
        "CMU",
        "Northwest",
        "ABMI Off-Grid Monitoring",
        "ABMI OSM",
        sep = "|"
      )
    )
  )

message(nrow(density), " deployments after project filter.")

# ── 4. Process site-level VegHF ──────────────────

## 4.1 Reshape to wide form ----

# The VegHF file has one VEGHFAGEclass per
# deployment. ABMI-W sites target the wetland
# margin stratum regardless of GIS classification.
# GameTrail sites are excluded (CMU trail study).
veghf_site <- read_csv(
  f_veghf, show_col_types = FALSE
) |>
  rename(VegHF = VEGHFAGEclass) |>
  filter(!is.na(VegHF)) |>
  mutate(
    VegHF = if_else(
      str_starts(location, "W") &
        !str_starts(location, "WAB"),
      "WetlandMargin", VegHF
    )
  ) |>
  filter(!str_starts(VegHF, "GameTrail")) |>
  mutate(present = 1L) |>
  pivot_wider(
    names_from  = VegHF,
    values_from = present,
    values_fill = 0L,
    values_fn   = max
  )

## 4.2 Helper: aggregate columns by HF grouping ----

# Adds one column per group to df, summing the
# component HF types present in the data.
# add_cc_to: group that absorbs CC* (cutblock) types
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

## 4.3 Group HF types (three grouping schemes) ----

# HFor absorbs CC* types (unlike south, where HFor
# is excluded). Check max of broad groups after:
# table(veghf_site$Succ); table(veghf_site$Alien)
veghf_site <- veghf_site |>
  add_hf_groups(
    hf_gl, "UseInAnalysis", add_cc_to = "HFor"
  ) |>
  add_hf_groups(
    hf_gl, "SuccAlien", add_cc_to = "Succ"
  ) |>
  add_hf_groups(
    hf_gl, "NonlinLin", add_cc_to = "Nonlin"
  )

## 4.4 Prepare for join ----

# Keep location_project key and all numeric columns
# (individual VegHF binary columns needed for veg
# aggregation in section 7, plus HF group columns).
veghf_wide <- veghf_site |>
  mutate(
    location_project = paste(
      location, project, sep = "_"
    )
  ) |>
  select(location_project, where(is.numeric))

# ── 5. Add site metadata ─────────────────────────

## 5.1 Load deployment locations ----

# Locations file provides lat/long per deployment.
# latitude/longitude stored as character in source.
deployment_locs <- read_csv(
  f_locations, show_col_types = FALSE
) |>
  mutate(
    Lat  = as.numeric(latitude),
    Long = as.numeric(longitude)
  ) |>
  select(-latitude, -longitude) |>
  distinct()

## 5.2 Join locations to density data ----

density <- density |>
  left_join(
    deployment_locs, by = c("project", "location")
  ) |>
  filter(!is.na(Lat))

message(nrow(density), " deployments after location join.")

## 5.3 Nearest ABMI site ----

# All sites get NearestSite from the closest ABMI
# site by Euclidean distance (lat/long).
density <- density |>
  mutate(NearestSite = NA_integer_)

for (i in seq_len(nrow(density))) {
  if (!is.na(density$Lat[i])) {
    density$NearestSite[i] <- abmi_sites$SITE_ID[
      which.min(
        (density$Long[i] - abmi_sites$Long)^2 +
        (density$Lat[i]  - abmi_sites$Lat)^2
      )
    ]
  }
}

## 5.4 Join climate and region variables ----

density_meta <- density |>
  left_join(
    select(
      abmi_sites,
      SITE_ID, NR, NSR, LUF,
      AHM, PET, FFP, MAP, MAT, MCMT, MWMT
    ),
    by = c("NearestSite" = "SITE_ID")
  ) |>
  mutate(
    TrueLat = Lat,
    # Floor latitude at 51.5 for spatial models
    Lat = pmax(Lat, 51.5)
  ) |>
  mutate(
    location_project = paste(
      location, project, sep = "_"
    )
  )

# ── 6. Merge density + VegHF, filter north ───────

# Inner join: deployments without a VegHF record
# (unprocessed GIS sites) are dropped here.
d <- density_meta |>
  inner_join(veghf_wide, by = "location_project")

message(nrow(d), " deployments after VegHF join.")

# North = Boreal, Canadian Shield, Foothills,
# Rocky Mountain, or Parkland NR. Water sites
# (camera placed on water) are excluded.
d <- d |>
  filter(
    NR %in% c(
      "Boreal", "Canadian Shield", "Foothills",
      "Rocky Mountain", "Parkland"
    ),
    Water != 1
  )

message(nrow(d), " deployments in north region.")

# ── 7. Aggregate veg types ───────────────────────

## 7.1 Wetland and cutblock class aggregates ----

# Combine VegHF age classes into model-ready groups.
# Marsh absorbs GraminoidFen (set to 0 afterwards).
d <- d |>
  mutate(
    TreedBog      = rowSums(across(starts_with("TreedBog"))),
    TreedFen      = rowSums(across(starts_with("TreedFen"))),
    ShrubbyBogFen = ShrubbyBog + ShrubbyFen,
    TreedSwamp    = rowSums(across(starts_with("TreedSwamp"))),
    CCDecidMixed  = rowSums(
      across(matches("^CCDecid|^CCMixed"))
    ),
    CCSpruce      = rowSums(across(starts_with("CCSpruce"))),
    CCPine        = rowSums(across(starts_with("CCPine"))),
    CCConif       = CCSpruce + CCPine,
    Marsh         = Marsh + GraminoidFen,
    GraminoidFen  = 0
  )

## 7.2 Collapse age class 9 into 8 ----

# Class 9 (>140yr) has insufficient data across all
# forest types; absorbed into class 8.
d <- d |>
  mutate(
    Spruce8    = Spruce8    + Spruce9,
    Decid8     = Decid8     + Decid9,
    Pine8      = Pine8      + Pine9,
    Mixedwood8 = Mixedwood8 + Mixedwood9,
    TreedFen8  = TreedFen8  + TreedFen9,
    TreedBog8  = TreedBog8  + TreedBog9
  ) |>
  select(-ends_with("9"))

## 7.3 Consolidate rare CC age classes ----

d <- d |>
  mutate(
    # CCPine class 2 and 3 have too few records
    CCPine1      = CCPine1 + CCPine2 + CCPine3,
    # CCMixedwood class 3 and 4 have too few records
    CCMixedwood2 = CCMixedwood2 + CCMixedwood3 +
                   CCMixedwood4,
    # CCSpruce class 3 and 4 have too few records
    CCSpruce2    = CCSpruce2 + CCSpruce3 + CCSpruce4
  ) |>
  select(
    -CCPine2, -CCPine3,
    -CCMixedwood3, -CCMixedwood4,
    -CCSpruce3, -CCSpruce4
  )

## 7.4 All-age stand totals ----

# Sum all age classes (including R = regenerating)
# for each forest type. Note: Mixedwood has no
# class 1. TreedBogFen = all TreedFen + all TreedBog
# (TreedBog and TreedFen totals were computed in 7.1
# before the 9->8 collapse, so they are correct).
d <- d |>
  mutate(
    Spruce = SpruceR + Spruce1 + Spruce2 + Spruce3 +
             Spruce4 + Spruce5 + Spruce6 + Spruce7 +
             Spruce8,
    Pine   = PineR + Pine1 + Pine2 + Pine3 +
             Pine4 + Pine5 + Pine6 + Pine7 + Pine8,
    Decid  = DecidR + Decid1 + Decid2 + Decid3 +
             Decid4 + Decid5 + Decid6 + Decid7 +
             Decid8,
    Mixedwood = MixedwoodR + Mixedwood2 + Mixedwood3 +
                Mixedwood4 + Mixedwood5 + Mixedwood6 +
                Mixedwood7 + Mixedwood8,
    # TreedBogFen: all TreedFen types + all TreedBog
    # age classes (both totals from section 7.1)
    TreedBogFen = TreedFen + TreedBog
  )

# ── 8. Add combined veg/HF variables ─────────────

d <- d |>
  mutate(
    DecidMixed       = Decid + Mixedwood,
    UpCon            = Spruce + Pine,
    CCAll            = CCDecidMixed + CCSpruce,
    Cult             = CultivationCrop +
                       CultivationRoughPasture +
                       CultivationTamePasture,
    RurUrbInd        = Rural + Urban + Industrial +
                       HardLin,
    EnSoftLinSeismic = EnSoftLin + EnSeismic,
    SoftLin          = EnSoftLin + EnSeismic +
                       TrSoftLin,
    ShrubbyWet       = ShrubbyBogFen + ShrubbySwamp,
    OpenWet          = ShrubbyWet + Marsh + GraminoidFen,
    TreedWet         = TreedBogFen + TreedSwamp,
    GrassShrub       = GrassHerb + Shrub,
    TreedAll         = DecidMixed + UpCon + TreedWet,
    OpenAll          = GrassShrub + OpenWet,
    Boreal           = TreedAll + OpenWet,
    THF              = Alien + Succ,
    Lowland          = TreedWet + OpenWet,
    UplandForest     = UpCon + DecidMixed,
    Upland           = 1 - Lowland - THF - WetlandMargin
  )

# ── 9. Add NSR grouping ───────────────────────────

# 7-level NSR grouping for site-level data; labels
# differ from the NSR_ALT dummy columns in the grid.
d <- d |>
  mutate(NSR1 = case_when(
    NSR %in% c(
      "Central Parkland",
      "Foothills Parkland",
      "Peace River Parkland"
    )                          ~ "Parkland",
    NSR == "Dry Mixedwood"     ~ "DryMixedwood",
    NSR == "Central Mixedwood" ~ "CentralMixedwood",
    NSR %in% c(
      "Lower Foothills",
      "Upper Foothills"
    )                          ~ "Foothills",
    NSR %in% c(
      "Lower Boreal Highlands",
      "Upper Boreal Highlands",
      "Boreal Subarctic",
      "Northern Mixedwood"
    )                          ~ "North",
    NSR %in% c(
      "Athabasca Plain",
      "Kazan Uplands",
      "Peace-Athabasca Delta"
    )                          ~ "Shield",
    NSR %in% c(
      "Montane", "Subalpine", "Alpine"
    )                          ~ "Mountain"
  ))

# ── 10. Add lure info ─────────────────────────────

d <- d |>
  left_join(
    select(lure_lookup, location_project, Lured),
    by = "location_project"
  ) |>
  # Deployments not in lure file are unlured
  mutate(Lured = replace_na(Lured, "No"))

n_missing_lure <- sum(is.na(d$Lured))
if (n_missing_lure > 0) {
  message(
    n_missing_lure,
    " deployments still have missing lure",
    " status — check lure file."
  )
}

# ── 11. Season thresholds and sampling weights ────

d <- d |>
  rename(SummerDays = summer, WinterDays = winter)

# Drop deployments with <10 days in both seasons
d <- d |>
  filter(SummerDays >= 10 | WinterDays >= 10)

# Set species densities to NA for seasons with
# <10 sampling days
summer_sp_cols <- names(d) |>
  str_subset("Summer") |>
  setdiff("SummerDays")

winter_sp_cols <- names(d) |>
  str_subset("Winter") |>
  setdiff("WinterDays")

d <- d |>
  mutate(
    across(
      all_of(summer_sp_cols),
      ~ if_else(SummerDays < 10, NA_real_, .x)
    ),
    across(
      all_of(winter_sp_cols),
      ~ if_else(WinterDays < 10, NA_real_, .x)
    )
  )

# Weights = inverse of qualifying visits per
# location, to down-weight repeat-sampled sites
d <- d |>
  group_by(location) |>
  mutate(
    n_summer  = sum(SummerDays >= 10, na.rm = TRUE),
    n_winter  = sum(WinterDays >= 10, na.rm = TRUE),
    wt_summer = if_else(n_summer > 0, 1 / n_summer, 0),
    wt_winter = if_else(n_winter > 0, 1 / n_winter, 0)
  ) |>
  ungroup() |>
  select(-n_summer, -n_winter)

# ── 12. Build species tables ──────────────────────

# Derive first/last species column indices from
# summer_sp_cols and winter_sp_cols (computed in
# section 11) rather than hard-coding species names.
# This is robust to changes in the species list or
# column ordering in the density file.
first_sp_col_summer <- min(
  which(names(d) %in% summer_sp_cols)
)
last_sp_col_summer <- max(
  which(names(d) %in% summer_sp_cols)
)
first_sp_col_winter <- min(
  which(names(d) %in% winter_sp_cols)
)
last_sp_col_winter <- max(
  which(names(d) %in% winter_sp_cols)
)

## 12.1 Summer species ----

sp_table_summer <- sp_table_summer_ua <- summer_sp_cols

occ_summer <- map_dbl(
  sp_table_summer,
  ~ sum(sign(d[[.x]]) * d$wt_summer, na.rm = TRUE)
)
sp_table_summer    <- sp_table_summer[occ_summer >= 20]

occ_summer_ua <- map_dbl(
  sp_table_summer_ua,
  ~ sum(sign(d[[.x]]) * d$wt_summer, na.rm = TRUE)
)
sp_table_summer_ua <- sp_table_summer_ua[
  occ_summer_ua >= 3
]

## 12.2 Winter species ----

sp_table_winter <- sp_table_winter_ua <- winter_sp_cols

occ_winter <- map_dbl(
  sp_table_winter,
  ~ sum(sign(d[[.x]]) * d$wt_winter, na.rm = TRUE)
)
sp_table_winter    <- sp_table_winter[occ_winter >= 20]

occ_winter_ua <- map_dbl(
  sp_table_winter_ua,
  ~ sum(sign(d[[.x]]) * d$wt_winter, na.rm = TRUE)
)
sp_table_winter_ua <- sp_table_winter_ua[
  occ_winter_ua >= 3
]

# ── 13. Save output ───────────────────────────────

save(
  file = f_out,
  d,
  first_sp_col_summer, last_sp_col_summer,
  first_sp_col_winter, last_sp_col_winter,
  sp_table_summer, sp_table_summer_ua,
  sp_table_winter, sp_table_winter_ua,
  pred_matrix
)

message("Done. Output saved to:\n", f_out)
