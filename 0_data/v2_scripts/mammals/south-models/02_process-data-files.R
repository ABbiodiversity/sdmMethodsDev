# ---
# title:   Process Data Files for South Models
# author:  Marcus Becker
# created: 2026-05-14
#
# inputs:
#   Density CSV (wide format)
#     One row per deployment x year; species
#     densities in columns (snake_case names)
#   Soil + HF site CSV
#     SoilHF class per deployment (point summary);
#     covers ABMI and CMU only (not NWSAR or BG)
#   lookup-soil-hf-v2020.csv
#     HF and soil group definitions
#   Deployment locations CSV
#     NearestSite, lat/long per location; covers
#     ABMI and CMU but not Big Grids
#   Site climate summary CSV
#     NR, NSR, LUF, climate vars per ABMI site
#   Lure CSV
#     ABMI and CMU only; NWSAR and BG are always
#     unlured and handled in script
#   Prediction matrix CSV (south)
#
# outputs:
#   R Dataset SpTable ... South ... YYYY.RData
#     d                 analysis-ready data frame
#     first_sp_col_summer, last_sp_col_summer
#     first_sp_col_winter, last_sp_col_winter
#     sp_table_summer, sp_table_summer_ua
#     sp_table_winter, sp_table_winter_ua
#     pred_matrix       south prediction matrix
#
# notes:
#   South region = Grassland or Parkland NR,
#   or Dry Mixedwood NSR, and TrueLat <= 56.7.
#   CutBlock sites and those with no soil info
#   (UNK > 0) are excluded from analysis.
#   HFor is not used in south models.
#   Big Grids sites are dropped because they are
#   absent from both the locations file and the
#   soil/HF file. ABMI Southern Focal Areas 2019
#   sites (OG-ABMI-...) are also absent from the
#   locations file and are dropped.
#   Paths marked !! need updating each cycle.
# ---

rm(list = ls())
gc()

# ── 1. Setup ─────────────────────────────────────

library(tidyverse)

# Path to Shared Google Drive
g_drive <- "G:/Shared drives/ABMI Mammals/"

# Species density data for south modeling
f_density <- paste0(
  g_drive,
  "Results/Density/Deployments/Archive/",
  "abmi-cmu-bg-nwsar_all-years_",
  "density_wide_2022-01-13.csv"
)

# Soil + HF point summary per deployment
# (ABMI and CMU projects only)
f_soilhf <- paste0(
  g_drive,
  "Data/Habitat Models/",
  "abmi-cmu_all-years_",
  "veghf-soilhf-detdistveg_2021-10-06.csv"
)

f_lookup <- paste0(
  g_drive,
  "Data/Habitat Models/",
  "lookup-soil-hf-v2020.csv"
)

f_locations <- paste0(
  g_drive,
  "Data/Habitat Models/",
  "Deployment locations all Nov 2021.csv"
)

f_site_climate <- paste0(
  g_drive,
  "Data/Habitat Models/",
  "Site summary with climate.csv"
)

# Lure file covers ABMI and CMU only
f_lure <- paste0(
  g_drive,
  "Data/Habitat Models/",
  "abmi-cmu_all-years_lure_2021-10-07.csv"
)

f_pred_matrix <- paste0(
  g_drive,
  "Data/Habitat Models/",
  "Prediction matrix for ABMI South",
  " coefficients 2020.csv"
)

f_out <- paste0(
  g_drive,
  "Data/Habitat Models/",
  "R Dataset SpTable for ABMI South",
  " mammal coefficients 2024.RData"
)

# ── 2. Load lookups and auxiliary files ──────────

## 2.1 HF and soil group lookups ----

# First column is the individual GIS type name;
# rename_with handles any BOM encoding variation
lookup_hf <- read_csv(
  f_lookup, show_col_types = FALSE
) |>
  filter(Sector != "Native") |>
  rename_with(~ "HF_GROUP", .cols = 1)

lookup_soil <- read_csv(
  f_lookup, show_col_types = FALSE
) |>
  filter(Sector == "Native") |>
  rename_with(~ "soil_type", .cols = 1) |>
  mutate(UseInAnalysis = as.character(UseInAnalysis))

## 2.2 ABMI site reference data ----

# Provides NR, NSR, LUF, and climate variables
# for each ABMI site. Deployments are linked to
# their nearest ABMI site in section 5.
# Note: PUBLIC_LATTITUDE is a typo in the source.
abmi_sites <- read_csv(
  f_site_climate, show_col_types = FALSE
) |>
  rename(
    Long   = PUBLIC_LONGITUDE,
    Lat    = PUBLIC_LATTITUDE,
    NR     = NATURAL_REGIONS,
    NSR    = NATURAL_SUBREGIONS,
    LUF    = LANDUSE_FRAMEWORK,
    pAspen = pAspen_mean
  )

## 2.3 Lure lookup ----

# NWSAR and Big Grids are always unlured and
# are assigned "No" explicitly in section 8.
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

# Helper: convert snake_case to PascalCase
# e.g. black_bear_summer -> BlackBearSummer
to_pascal <- function(x) {
  x |>
    str_split("_") |>
    map(\(parts) paste(str_to_title(parts),
                       collapse = "")) |>
    unlist()
}

# Qualifying projects use prefix matching so that
# year-suffixed names (e.g. "CMU 2017") are caught
qualifying_projects <- c(
  "ABMI Ecosystem Health",
  "ABMI Northern Focal Areas",
  "ABMI Southern Focal Areas 2019",
  "Big Grids",
  "CMU",
  "Northwest Species at Risk"
)

project_regex <- paste0(
  "^(",
  paste(qualifying_projects, collapse = "|"),
  ")"
)

density <- read_csv(
  f_density, show_col_types = FALSE
) |>
  # Convert species cols from snake_case to PascalCase
  # (badger_summer -> BadgerSummer), leaving
  # location, project, summer, winter unchanged
  rename_with(to_pascal, .cols = matches(
    "_summer$|_winter$"
  )) |>
  filter(
    str_detect(project, project_regex),
    # Exclude unrelated sub-projects bundled
    # under ABMI Ecosystem Health
    !str_starts(location, "OG-EI"),
    !str_starts(location, "OG-CITS"),
    !str_starts(location, "OG-RIVR")
  )

message(nrow(density), " deployments after project filter.")

# ── 4. Process site-level soil + HF ──────────────

## 4.1 Reshape to wide form ----

# The soil/HF file has one SoilHF class per
# deployment. Pivot to one column per class (0/1),
# so site-level data can be grouped and used the
# same way as the km2 grid.
# Rows with NA SoilHF (mostly north sites or sites
# lacking GIS processing) are removed here.
soilhf_site <- read_csv(
  f_soilhf, show_col_types = FALSE
) |>
  filter(!is.na(SoilHF)) |>
  # ABMI-W sites target the wetland margin stratum
  # regardless of their GIS classification
  mutate(
    SoilHF = if_else(
      str_starts(location, "ABMI-W"),
      "WetlandMargin", SoilHF
    )
  ) |>
  mutate(present = 1L) |>
  pivot_wider(
    names_from  = SoilHF,
    values_from = present,
    values_fill = 0L
  )

## 4.2 Helper: aggregate columns by HF grouping ----

# Adds one column per group to df, summing the
# component HF types present in the data.
# group_col: lookup column defining the grouping
# exclude:   group names to skip entirely
# add_cc_to: group that absorbs CC* types
#            (cutblocks; not relevant for south)
add_hf_groups <- function(
    df, lookup, group_col,
    exclude   = character(0),
    add_cc_to = NULL) {

  groups <- lookup |>
    pull(all_of(group_col)) |>
    unique() |>
    na.omit() |>
    setdiff(exclude)

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

soilhf_site <- soilhf_site |>
  # Primary analysis groups; HFor not used south
  add_hf_groups(
    lookup_hf, "UseInAnalysis",
    exclude = "HFor"
  ) |>
  # Broader successional vs. alien grouping
  add_hf_groups(
    lookup_hf, "SuccAlien",
    add_cc_to = "Succ"
  ) |>
  # Linear vs. non-linear footprint grouping
  add_hf_groups(
    lookup_hf, "NonlinLin",
    add_cc_to = "Nonlin"
  )

# Extra combined HF variables
soilhf_site <- soilhf_site |>
  mutate(
    NonAgAlien = Alien - Crop - RoughP - TameP,
    Cult       = Crop + TameP + RoughP,
    RurUrbInd  = Urban + Rural + Industrial +
                 HardLin + Mine
  )

## 4.4 Group soil types ----

# UNK -> SoilUnknown, Water -> SoilWater in the
# lookup. SoilWater is excluded (absent in south);
# raw UNK and Water columns are retained for the
# south filter and combined variable calculations.
soil_group_names <- unique(
  lookup_soil$UseInAnalysis
) |>
  setdiff("SoilWater")

for (soil_grp in soil_group_names) {
  types <- lookup_soil |>
    filter(UseInAnalysis == soil_grp) |>
    pull(soil_type) |>
    intersect(colnames(soilhf_site))

  if (length(types) == 0) next

  soilhf_site <- soilhf_site |>
    mutate(
      !!soil_grp := rowSums(across(all_of(types)))
    )
}

## 4.5 Additional combined soil variables ----

soilhf_site <- soilhf_site |>
  mutate(
    ClayWet       = ClaySub + Other,
    SandyRapid    = SandyLoam + RapidDrain,
    ThinBlow      = ThinBreak + Blowout,
    Nonproductive = ClaySub + Other +
                    RapidDrain + ThinBreak + Blowout,
    Productive    = Loamy + SandyLoam,
    AllNative     = Nonproductive + Productive,
    AllNativeSucc = AllNative + Succ,
    # All cover types except WetlandMargin;
    # uses raw UNK and Water columns (not grouped)
    AllExceptMargin = AllNative + UNK + Water +
                      Succ + Alien
  )

# ── 5. Add site metadata ─────────────────────────

## 5.1 Load and clean deployment locations ----

# Covers ABMI and CMU sites; Big Grids (BG-...)
# and Southern Focal Areas (OG-ABMI-...) are
# absent and will be dropped in section 5.2.
deployment_locs <- read_csv(
  f_locations, show_col_types = FALSE
) |>
  rename(
    location = `Site Name`,
    Lat      = `Public Latitude`,
    Long     = `Public Longitude`
  ) |>
  mutate(
    # Remove leading zeros: ABMI-0409-NE -> ABMI-409-NE
    location = str_replace(
      location, "-(0+)([1-9])", "-\\2"
    ),
    # Strip "ABMI-" prefix to match density file
    # names (e.g. "409-NE"); preserve other prefixes
    # like "OG-ABMI-..."
    location = if_else(
      str_starts(location, "ABMI-"),
      str_remove(location, "^ABMI-"),
      location
    )
  ) |>
  select(location, NearestSite, Lat, Long) |>
  distinct(location, .keep_all = TRUE)

## 5.2 Join locations to density data ----

density <- density |>
  left_join(deployment_locs, by = "location") |>
  # Remove deployments with no location record
  # (Big Grids and OG-ABMI sites dropped here)
  filter(!is.na(NearestSite)) |>
  mutate(
    # Coerce to numeric; non-numeric strings (e.g.
    # "") become NA and are resolved in step 5.3
    NearestSite = suppressWarnings(
      as.numeric(NearestSite)
    )
  )

message(nrow(density), " deployments after location join.")

## 5.3 Nearest ABMI site fallback ----

# For any deployment where NearestSite is NA after
# numeric coercion but lat/long is available,
# assign the closest ABMI site by Euclidean distance
for (i in seq_len(nrow(density))) {
  if (is.na(density$NearestSite[i]) &
      !is.na(density$Lat[i])) {
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
      SITE_ID, NR, NSR, LUF, pAspen,
      AHM, PET, FFP, MAP, MAT, MCMT, MWMT
    ),
    by = c("NearestSite" = "SITE_ID")
  ) |>
  mutate(
    TrueLat = Lat,
    # Cap latitude for spatial models, reducing
    # outsized influence of northern parkland sites
    Lat = pmin(Lat, 56.5)
  )

# ── 6. Merge density + soil/HF, filter south ─────

## 6.1 Build join key and prepare soil/HF cols ----

soilhf_site <- soilhf_site |>
  mutate(
    location_project = paste(
      location, project, sep = "_"
    )
  )

density_meta <- density_meta |>
  mutate(
    location_project = paste(
      location, project, sep = "_"
    )
  )

# Retain key + all numeric columns from soilhf_site.
# This includes both raw 0/1 soil/HF columns
# (needed for UNK and CutBlocks filters) and all
# grouped and combined columns.
soilhf_wide <- soilhf_site |>
  select(location_project, where(is.numeric))

## 6.2 Join ----

# Deployments without a soil/HF match will have
# NA for UNK and are dropped by the south filter.
d <- density_meta |>
  left_join(soilhf_wide, by = "location_project")

n_missing_soilhf <- sum(is.na(d$UNK))
if (n_missing_soilhf > 0) {
  message(
    n_missing_soilhf,
    " deployments have no soil/HF data",
    " and will be dropped."
  )
}

## 6.3 Filter to south region ----

# South = Grassland or Parkland NR, or Dry
# Mixedwood NSR, south of 56.7 degrees.
# CutBlock sites and those with UNK > 0 (no soil
# information) are also excluded.
d <- d |>
  filter(
    NR %in% c("Grassland", "Parkland") |
      NSR == "Dry Mixedwood",
    TrueLat <= 56.7,
    CutBlocks == 0,
    !is.na(UNK),
    UNK == 0
  )

message(nrow(d), " deployments in south region.")

# ── 7. Additional combined site variables ────────

d <- d |>
  mutate(
    # Energy sector soft linear features
    EnSoftLinSeismic = EnSoftLin + EnSeismic,
    # All soft linear feature types combined
    SoftLin          = EnSoftLin + EnSeismic +
                       TrSoftLin,
    # Rough geographic boundary for Peace River area
    PeaceRiver       = TrueLat > 54.5 & Long < -115
  )

# ── 8. Add lure info ──────────────────────────────

d <- d |>
  left_join(
    select(lure_lookup, location_project, Lured),
    by = "location_project"
  ) |>
  mutate(
    # NWSAR and Big Grids are always unlured
    Lured = case_when(
      str_starts(project, "Big Grids")         ~ "No",
      str_starts(project, "Northwest Species") ~ "No",
      TRUE ~ Lured
    )
  )

n_missing_lure <- sum(is.na(d$Lured))
if (n_missing_lure > 0) {
  message(
    n_missing_lure,
    " deployments still have missing lure",
    " status — check lure file."
  )
}

# ── 9. Season thresholds and sampling weights ─────

# Rename season day columns used in downstream scripts
d <- d |>
  rename(SummerDays = summer, WinterDays = winter)

# Drop deployments with <10 days in both seasons
d <- d |>
  filter(SummerDays >= 10 | WinterDays >= 10)

# Set species densities to NA for seasons with
# <10 sampling days, so those season-deployment
# records are excluded from seasonal models
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

# ── 10. Build species tables ──────────────────────

# Species density columns span BadgerSummer to
# WoodlandCaribouWinter (interleaved Summer/Winter
# order). Indices are stable as long as the density
# file column order doesn't change.
# !! Verify first/last species if list changes !!
first_sp_col_summer <- which(
  names(d) == "BadgerSummer"
)
last_sp_col_summer <- which(
  names(d) == "WoodlandCaribouSummer"
)
first_sp_col_winter <- which(
  names(d) == "BadgerWinter"
)
last_sp_col_winter <- which(
  names(d) == "WoodlandCaribouWinter"
)

## 10.1 Summer species ----

sp_table_summer <- sp_table_summer_ua <-
  names(d)[first_sp_col_summer:last_sp_col_summer] |>
  str_subset("Summer")

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

## 10.2 Winter species ----

sp_table_winter <- sp_table_winter_ua <-
  names(d)[first_sp_col_winter:last_sp_col_winter] |>
  str_subset("Winter")

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

# Species not modelled in the south region
# RedSquirrel, Fisher: data quality issues
# BlackBear: hibernation; winter observations
#           near-zero and not meaningful for
#           habitat modeling
sp_table_winter <- sp_table_winter[
  !sp_table_winter %in%
    c("RedSquirrelWinter", "FisherWinter",
      "BlackBearWinter")
]

# ── 11. Save output ───────────────────────────────

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
