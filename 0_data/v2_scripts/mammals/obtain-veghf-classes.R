# ----------------------------------------------------------
# title:   Obtain veghf classes at camera points for
#          species habitat modeling
#
# author:  Marcus Becker
# created: 2026-04-15
# updated: 2026-09-01
# inputs:  abmi-cam-aru_2009_2023.RData (S drive; d.wide.pts,
#            site.lookup)
#          Per-project density CSVs (G drive; Results/Density/
#            Locations/<project>.csv), read directly by known
#            path -- NOT via directory search
# outputs: all-projects_veghf-classes-for-habitat-modeling_
#            <date>.csv (G drive; Data/Habitat Models/)
# notes:   The density data is treated as the source of truth
#          for which project/location combinations exist and
#          which year(s) a physical site was actually surveyed
#          by camera -- NOT the GIS veghf point's own survey
#          year or site.lookup's recorded deployment year (both
#          can be stale/incomplete for a given site, e.g. a
#          revisited Ecosystem Health site or a resurveyed CMU/
#          NWSAR grid). A physical GIS point's veghf class is
#          treated as effectively constant across whichever
#          years/projects the density file says it was surveyed;
#          when a point has more than one veghf record across
#          years (true vegetation change/revisits), the record
#          closest to the density project's own year is used.
#
#          Matching therefore runs "density-first": every
#          project/location in the density files is looked up
#          against the GIS Site_ID via the WildTrax crosswalk in
#          site.lookup, and only THEN matched to a veghf record.
#          Not every density location has a resolvable veghf
#          record (site.lookup crosswalk gaps for the newest
#          project years, non-Alberta CMU/NWSAR sub-sites with no
#          Alberta GIS point, or genuinely uncertain/probabilistic
#          vegetation classification at the point) -- some loss is
#          expected and reported below.
# ----------------------------------------------------------

# 1.0 Initializing environment

rm(list = ls())
gc()

library(tidyverse)
library(Matrix)

# ----------------------------------------------------------

# 2.0 Paths

s_drive <- "S:/sc/AB_data_v2023/sites/processed/landcover/"
g_drive <- "G:/Shared drives/ABMI Mammals"

f_cam_aru   <- file.path(s_drive, "abmi-cam-aru_2009_2023.RData")
density_dir <- file.path(g_drive, "Results", "Density", "Locations")
f_out       <- file.path(
  g_drive, "Data", "Habitat Models",
  paste0("all-projects_veghf-classes-for-habitat-modeling_",
         Sys.Date(), ".csv"))

# ----------------------------------------------------------

# 3.0 Load data

# Cam/ARU site data -- d.wide.pts (veg condition at the point,
# sparse matrix) and site.lookup (GIS Site_ID -> WildTrax
# deployment name/project crosswalk).
load(f_cam_aru)
rm(list = c("d.wide.100m", "d.wide.150m", "d.wide.56m", "d.wide.500m"))

# ----------------------------------------------------------

# 4.0 Format veghf points ("current" condition)

# Extract veg condition at the point, keeping only points with a
# single certain classification. A point is "certain" when
# exactly one category is non-zero -- NOT when its value equals
# 1, since some points use a different weighting scale (e.g. an
# unambiguous Pipeline point can be recorded as "4" rather than
# "1"). Using max == 1 as the certainty test (as in an earlier
# version of this script) both wrongly excluded ~110 unambiguous
# points on a non-1 scale AND wrongly included points with a
# genuine second non-zero category that happened to equal 1
# (e.g. Decid5 == 1 and IndustrialSiteRuralEnergy == 1 at the
# same point) -- fixed 2026-09-01.
points_current <- as.matrix(d.wide.pts[["veg.current"]])
points_current <- points_current[apply(points_current, 1, \(r) sum(r > 0) == 1), ]

points_current <- as.data.frame(points_current) |>
  rownames_to_column(var = "location") |>
  pivot_longer(SpruceR:last_col(), names_to = "veghf") |>
  filter(value > 0) |>
  select(-value) |>
  separate(location, into = c("location", "survey_year"),
           sep = "_", convert = TRUE) |>
  mutate(age = case_when(
    str_ends(veghf, "R") ~ 0L,
    .default = as.integer(str_extract(veghf, "\\d+$"))
  )) |>
  # "BG-" (Big Grids 2016) points have no associated density
  # data -- exclude up front.
  filter(!str_starts(location, "BG-"))

stopifnot(!anyDuplicated(points_current[c("location", "survey_year")]))

# ----------------------------------------------------------

# 5.0 GIS Site_ID <-> WildTrax project/location crosswalk

# Only sites with an actual camera deployment (CAM or BOTH) --
# ARU-only / NONE / NO DATA rows have no camera density data.
# Fall back to the GIS Site_ID for the WildTrax-side location
# when WildtraxName is missing but a project is still known.
# "Camera Model Comparison" projects are never used in habitat
# modeling. Deliberately dropping survey_year here (see notes
# above) -- a Site_ID can be legitimately associated with a
# project/location in a different year than its own GIS survey
# year, and a single Site_ID/WildtraxName pair can also appear
# under multiple projects across repeat visits (e.g. CMU/NWSAR
# grids resurveyed in later years, revisited Ecosystem Health
# sites).
wt_crosswalk <- site.lookup |>
  filter(deployment %in% c("CAM", "BOTH")) |>
  mutate(
    wt_location = as.character(coalesce(WildtraxName, Site_ID)),
    project     = as.character(WildtraxProject)
  ) |>
  select(project, wt_location, location = Site_ID) |>
  distinct() |>
  filter(!is.na(project), !str_detect(project, "Camera Model Comparison"))

# ----------------------------------------------------------

# 6.0 Density-first matching

# Candidate project universe, reconstructed from
# 1_code/1_density-estimation/01_download-data.R. Excludes:
# AOC, CNOOC, Cenovus/CENOVUS (industry, per user instruction);
# ACME OSM (per user instruction -- not used downstream);
# Biodiversity Trajectories 2025 (per user instruction, 2023
# kept); Innotech Arrays (no EDD categories -> no density file
# is ever produced); ABMI OSM 2024 (per user instruction);
# Camera Model Comparison (not used downstream, excluded above
# in the crosswalk already).
candidate_projects <- c(
  paste0("ABMI Ecosystem Health ", 2014:2024),
  c("ABMI OSM 2021", "ABMI OSM 2022", "ABMI OSM 2023"),
  c("ABMI Off-Grid Monitoring 2015", "ABMI Off-Grid Monitoring 2017",
    "ABMI Off-Grid Monitoring 2018",
    "ABMI Northern Focal Areas 2019", "ABMI Northern Focal Areas 2020",
    "ABMI Southern Focal Areas 2019", "ABMI Southern Focal Areas 2021",
    "ABMI North Saskatchewan Monitoring 2018",
    "ABMI Edge-Interior Surveys 2017",
    "ABMI Citizen Science Monitoring 2016",
    "ABMI Operation Community Grassland 2015",
    "ABMI Adopt-a-Camera 2017",
    "ABMI Amphibian Monitoring 2020"),
  c("CMU 2017", "CMU 2018",
    "CMU Ecosystem Monitoring Camera Program 2019",
    "CMU Ecosystem Monitoring Camera Program 2020",
    "CMU Ecosystem Monitoring Camera Program 2021",
    "CMU Ecosystem Monitoring Camera Program 2022"),
  paste0("Northwest Species at Risk Program ", 2020:2023),
  "Biodiversity Trajectories 2023"
)

candidate_files <- file.path(density_dir, paste0(candidate_projects, ".csv"))
candidate_files <- candidate_files[file.exists(candidate_files)]

# The density files are the source of truth for which
# project/location combinations actually exist.
density_locs <- candidate_files |>
  map(\(f) read_csv(f, col_select = c(project, location),
                     col_types = cols(project = "c", location = "c")) |>
        distinct()) |>
  list_rbind() |>
  distinct()

# density (project, location) -> GIS Site_ID
density_with_site <- density_locs |>
  left_join(wt_crosswalk, by = c("project", "location" = "wt_location"),
            relationship = "many-to-many")

# GIS Site_ID -> veghf (may have >1 record across survey years)
veghf_final <- density_with_site |>
  filter(!is.na(location.y)) |>
  rename(gis_location = location.y) |>
  mutate(project_year = as.integer(str_extract(project, "\\d{4}"))) |>
  left_join(
    points_current |> select(gis_location = location, survey_year, veghf, age),
    by = "gis_location", relationship = "many-to-many"
  ) |>
  filter(!is.na(veghf)) |>
  # When a Site_ID has veghf records from more than one survey
  # year (true revisits), prefer the record closest to the
  # density project's own year; break remaining ties
  # alphabetically for reproducibility.
  arrange(project, location, abs(survey_year - project_year), veghf) |>
  distinct(project, location, .keep_all = TRUE) |>
  select(project, location, survey_year, veghf, age) |>
  arrange(project, location)

stopifnot(!anyDuplicated(veghf_final[c("project", "location")]))

# ----------------------------------------------------------

# 7.0 QA and output

# Diagnostic: density locations with no resolvable veghf record
# (kept for QA -- not written to the output csv). Known,
# unfixable sources: site.lookup crosswalk gaps for the newest
# project years (e.g. ABMI Ecosystem Health 2024, Northwest
# Species at Risk Program 2023 have NO WildtraxProject entries
# in site.lookup at all yet), non-Alberta CMU sub-sites (AUB-,
# DEW-, LRN-, MCC-, MAL- prefixes -- Saskatchewan grids with no
# Alberta GIS point), and points with genuinely uncertain
# (multi-category) vegetation classification.
density_unmatched <- density_locs |>
  anti_join(veghf_final, by = c("project", "location"))

cat(
  nrow(veghf_final), "of", nrow(density_locs),
  "density locations matched to a veghf class (",
  round(100 * nrow(veghf_final) / nrow(density_locs), 1), "%)\n"
)

write_csv(veghf_final, f_out)

# ----------------------------------------------------------
