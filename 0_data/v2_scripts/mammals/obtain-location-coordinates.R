# ---
# title:   Download deployment location coordinates from WildTrax
# author:  Marcus Becker
# created: 2026-09-01
# updated: 
#
# inputs:  WildTrax "location" reports for camera projects listed
#          below (same project list as
#          1_code/1_density-estimation/01_download-data.R)
#
# outputs: G:/Shared drives/ABMI Mammals/Data/Locations/
#            deployment-locations.csv
#
# notes:   Habitat modeling scripts (02_process-data-files.R, north
#          and south) need a lookup of deployment location
#          coordinates (deployment_locs) to attribute certain
#          variables (e.g. climate, NSR) to each location. This
#          script produces that lookup by pulling the WildTrax
#          "location" report (rather than "main"/"image_report")
#          for every project used in density estimation.

# ---

rm(list = ls())
gc()

# ── 1. Setup ──────────────────────────────────────────────

# Attach packages
library(tidyverse)
library(wildrtrax)
library(furrr)

# WildTrax credentials and authentication
source("wt_credentials.R")
wt_auth()

# Paths
g_drive <- "G:/Shared drives/ABMI Mammals"
f_cache <- file.path(g_drive, "Data", "Locations",
                      "WildTrax Location Reports")
f_out   <- file.path(g_drive, "Data", "Locations",
                      "deployment-locations.csv")

if (!dir.exists(f_cache)) {
  dir.create(f_cache, recursive = TRUE)
}

# ── 2. Downloader functions ───────────────────────────────

# 2.1 Single project download
# Results are cached as <project>.rds.
# Delete a file to force a re-download
# (e.g., for projects still being processed in WildTrax).
download_project <- function(pid,
                             proj,
                             sensor    = "CAM",
                             reports   = "location",
                             cache_dir = f_cache) {

  cache_file <- file.path(cache_dir, paste0(proj, ".rds"))

  # Already cached — nothing to do.
  if (file.exists(cache_file)) return(invisible(NULL))

  wt_download_report(
    project_id = pid,
    sensor_id  = sensor,
    reports    = reports) |>
    mutate(project = proj) |>
    saveRDS(cache_file)

  invisible(NULL)
}

# Wrap in possibly() so a single failure returns NULL
# rather than killing the entire run.
safe_download <- possibly(download_project,
                          otherwise = NULL)

# ── 3. Projects to Download ──────────────────────

# Ecosystem Health
eh <- c("ABMI Ecosystem Health 2014",
        "ABMI Ecosystem Health 2015",
        "ABMI Ecosystem Health 2016",
        "ABMI Ecosystem Health 2017",
        "ABMI Ecosystem Health 2018",
        "ABMI Ecosystem Health 2019",
        "ABMI Ecosystem Health 2020",
        "ABMI Ecosystem Health 2021",
        "ABMI Ecosystem Health 2022",
        "ABMI Ecosystem Health 2023",
        "ABMI Ecosystem Health 2024",
        "ABMI Ecosystem Health 2025")

# Oilsands Monitoring
osm <- c("ABMI OSM 2021",
          "ABMI OSM 2022",
          "ABMI OSM 2023",
          "ABMI OSM 2024",
          #"ABMI OSM 2025", Not ready yet.
          "ACME OSM 2021",
          "ACME OSM 2022",
          "ACME OSM 2023")

# Off-Grid Monitoring
og <- c("ABMI Off-Grid Monitoring 2015",
        "ABMI Off-Grid Monitoring 2017",
        "ABMI Off-Grid Monitoring 2018",
        # Focal Areas
        "ABMI Northern Focal Areas 2019",
        "ABMI Northern Focal Areas 2020",
        "ABMI Southern Focal Areas 2019",
        "ABMI Southern Focal Areas 2021",
        # Random other ABMI projects
        "ABMI North Saskatchewan Monitoring 2018",
        "ABMI Edge-Interior Surveys 2017",
        "ABMI Citizen Science Monitoring 2016",
        "ABMI Operation Community Grassland 2015",
        "ABMI Adopt-a-Camera 2017",
        "ABMI Amphibian Monitoring 2020")

# Caribou Monitoring Unit (CMU)
cmu <- c("CMU 2017",
         "CMU 2018",
         "CMU Ecosystem Monitoring Camera Program 2019",
         "CMU Ecosystem Monitoring Camera Program 2020",
         "CMU Ecosystem Monitoring Camera Program 2021",
         "CMU Ecosystem Monitoring Camera Program 2022")
         #"CMU Ecosystem Monitoring Camera Program 2024")

# Northwest Species at Risk (NWSAR)
nwsar <- c("Northwest Species at Risk Program 2020",
           "Northwest Species at Risk Program 2021",
           "Northwest Species at Risk Program 2022",
           "Northwest Species at Risk Program 2023")

# Innotech Arrays
# Note that these cameras have no EDD categories, so density
# will not be estimated until someone wants to do that.
ita <- c("Bighorn Camera Array 2019",
         "Bighorn Camera Array 2021",
         "Bighorn Camera Array 2022",
         "Castle Camera Array 2021",
         "Castle Camera Array 2022",
         "Christina Lake Camera Array 2019",
         "Christina Lake Camera Array 2021",
         "Richardson Camera Array 2019",
         "Richardson Camera Array 2021")

# Biodiversity Trajectories
bdt <- c("Biodiversity Trajectories 2023",
         "Biodiversity Trajectories 2025")

# Industry
ind <- c(# CNOOC
         "CNOOC 2017 (Fall)",
         "CNOOC 2017 (Spring)",
         "CNOOC 2018 (Fall)",
         "CNOOC 2018 (Spring)",
         "CNOOC 2019 (Fall)",
         "CNOOC 2019 (Spring)",
         "CNOOC 2020 (Fall)",
         "CNOOC_CameraData_2023_Vertex",
         "CNOOC_CameraData_2024_Vertex",
         "CNOOC_CameraData_2025_Vertex",
         # CENOVUS
         "Cenovus Foster Creek 2019",
         "Cenovus Christina Lake 2019",
         "CENOVUS 2016",
         "CENOVUS 2017",
         "CENOVUS 2018",
         # AOC
         "AOC 2017",
         "AOC 2018",
         "AOC Leismer 2019")

# ── 4. Download location reports ──────────────────────────

# Fetch full project table once; filtered inside
# download_projects() for each group.
all_cam_projects <- wt_get_projects(sensor = "CAM")

project_groups <- list(
  eh    = eh,
  osm   = osm,
  og    = og,
  cmu   = cmu,
  nwsar = nwsar,
  ita   = ita,
  bdt   = bdt,
  ind   = ind
)

# Flatten all groups into a single project table so everything
# queues in one future_walk. This avoids the sequential group
# bottleneck and repeated plan() calls.
all_project_names <- unlist(project_groups, use.names = FALSE)

projects_to_download <- all_cam_projects |>
  filter(project %in% all_project_names) |>
  select(project, project_id)

# I/O-bound: more workers than CPU cores is beneficial here.
plan(multisession,
     workers = min(8, parallelly::availableCores()))

future_walk(
  seq_len(nrow(projects_to_download)),
  \(i) {
    wt_auth()
    safe_download(
      pid  = projects_to_download$project_id[i],
      proj = projects_to_download$project[i]
    )
  },
  .options = furrr_options(
    seed     = NULL,
    packages = c("wildrtrax", "dplyr", "purrr")),
  .progress = TRUE
)

plan(sequential)

# ── 5. Combine into a single lookup csv ───────────────────

location_files <- list.files(
  f_cache,
  pattern    = "\\.rds$",
  full.names = TRUE
)

deployment_locs <- location_files |>
  # Some cached reports are empty (0-row) tibbles, which can
  # cause column types (e.g. `location`) to differ from
  # populated reports and break list_rbind(). Drop empties and
  # coerce `location` to character for a consistent bind.
  map(\(f) {
    df <- readRDS(f)
    if (nrow(df) == 0) return(NULL)
    mutate(df, location = as.character(location))
  }) |>
  list_rbind() |>
  distinct() |>
  select(project, location, latitude, longitude)

write_csv(deployment_locs, f_out)

# ── 
