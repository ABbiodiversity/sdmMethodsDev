# ---
# title: Extract SoilGrids Covariates for Experiment 002
# author: Brendan Casey
# created: 2026-10-04
# inputs:
#   - SoilGrids 2.0, ABMI 1 km variant, from the sciSpatialR
#     catalogue (geoscientificInformation/soilgrids_250_v2_ab/
#     abmi1km), on //ABMI-DATA2; SDM_SOILGRIDS overrides the path
#   - sites.csv from the published test dataset (see
#     1_code/harness/data_source.R), read only
# outputs:
#   in 2_pipeline/exp_002_soilgrids/inputs/:
#     - soilgrids_0_5cm.csv: survey_unit_id plus ten
#       sg_*_0_5cm columns, one row per survey unit
#     - soilgrids_0_5cm_source.csv: where the columns came from
# notes:
#   - Written to 2_pipeline/, not the frozen test dataset; run.R
#     passes the file as `covariate_files`.
#   - All ten SoilGrids properties published at 0-5 cm (organic
#     carbon stock is 0-30 cm only, so excluded), in the layer's
#     units. Gap-filled cells are interpolations (see the layer's
#     readme).
#   - Each unit takes its 1 km cell's value, located by easting
#     and northing in EPSG:3400 (the layer's grid). Checked
#     2026-10-04: plant units match projected lat/long to 1e-8 m;
#     98% of v2's south-only bird units fall in the Grassland and
#     Parkland regions. Mammals have no coordinates, so NA.
# ---

# 1. Setup ----

## 1.1 Load packages ----
library(data.table)  # reading and writing tables (version: 1.18.0)
library(sciSpatialR) # catalogue access, extraction (version: 0.1.0)
library(sf)          # survey unit points (version: 1.1.2)

## 1.2 Resolve paths ----
project_root <- normalizePath(getwd(), winslash = "/")
resolver <- file.path(project_root, "1_code/harness/data_source.R")

if (!file.exists(resolver)) {
  stop("Run this from the repository root.", call. = FALSE)
}

source(resolver)
sites_path <- file.path(test_dataset_dir(), "sites.csv")
out_dir <- file.path(
  project_root, "2_pipeline", "exp_002_soilgrids", "inputs"
)

layer_id <- "geoscientificInformation/soilgrids_250_v2_ab/abmi1km"
layer_path <- Sys.getenv("SDM_SOILGRIDS", unset = "")

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# 2. Read the layer's shallowest depth ----
soil <- if (nzchar(layer_path)) {
  terra::rast(layer_path)
} else {
  get_layer(layer_id)
}

shallow <- grep("_0-5cm_mean$", names(soil), value = TRUE)

if (length(shallow) != 10) {
  stop(
    "Expected ten 0-5 cm bands in ", layer_id, "; found ",
    length(shallow), ".",
    call. = FALSE
  )
}

soil <- soil[[shallow]]

# Column names the formulas can use: sg_clay_0_5cm
names(soil) <- paste0(
  "sg_", sub("_0-5cm_mean$", "", shallow), "_0_5cm"
)
soil_columns <- names(soil)

# 3. Extract at every survey unit ----
sites <- fread(
  sites_path,
  select = c("survey_unit_id", "easting", "northing"),
  colClasses = list(character = "survey_unit_id")
)
located <- sites[!is.na(easting) & !is.na(northing)]

points <- st_as_sf(
  located, coords = c("easting", "northing"), crs = 3400
)

values <- as.data.table(
  extract_points(soil, points, bind = FALSE)
)
values <- values[, soil_columns, with = FALSE]

# One row per survey unit, NA where a unit has no location
soil_table <- data.table(survey_unit_id = sites$survey_unit_id)
rows <- match(sites$survey_unit_id, located$survey_unit_id)

for (column in soil_columns) {
  set(soil_table, j = column, value = values[[column]][rows])
}

## 3.1 Report ----
cat(
  "Survey units:", nrow(sites), "\n",
  "  located:", nrow(located), "\n",
  "  without coordinates (soil left NA):",
  nrow(sites) - nrow(located), "\n",
  "  located but outside the layer:",
  sum(!stats::complete.cases(values)), "\n"
)
print(summary(values))

# 4. Write ----
fwrite(soil_table, file.path(out_dir, "soilgrids_0_5cm.csv"),
       na = "")

fwrite(data.table(
  columns = paste(soil_columns, collapse = " "),
  source = layer_id,
  doi = paste0(
    "10.17027/isric-soilgrids.",
    "713396fa-1687-11ea-a7c0-a0481ca9e724"
  ),
  depth = "0-5 cm",
  extracted = format(Sys.Date()),
  method = "value of the 1 km cell each survey unit falls in"
), file.path(out_dir, "soilgrids_0_5cm_source.csv"))

cat("Wrote", nrow(soil_table), "survey units to", out_dir, "\n")

# End of script ----
