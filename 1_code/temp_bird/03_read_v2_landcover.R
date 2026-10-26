# ---
# title: Read v2's Raw Bird Landcover Coefficients
# author: Brendan Casey
# created: 2026-10-15
# inputs:
#   on the BirdModels drive, through the work_abmi shortcut:
#     - Results/Archive/LandcoverModels/Coefficients/<region>/
#       <sp>/<Region>Model_<sp>_<draw>.csv
# outputs:
#   in 2_pipeline/temp_bird/:
#     - v2_landcover_draws.csv, one row per species, region, draw
#       and term
# notes:
#   - The target for the landcover model's own coefficients. The
#     published v2 reference (ABMIexploreR) holds only the
#     translated habitat-type values, so the raw glm terms come
#     from v2's archived per-draw files: the same files the
#     harness reproduces draw for draw on the new data.
#   - 5 species x 2 regions x 100 draws = 1,000 small files on a
#     Google Drive mount, read serially (about 0.4 s each): a few
#     minutes, once. The result is cached; delete it to re-read.
# ---

# 1. Setup ----

## 1.1 Load packages ----
library(data.table) # reading the per-draw files (version: 1.18.0)

## 1.2 Settings ----
archive_dir <- paste0(
  "G:/.shortcut-targets-by-id/17Ymt13eHfKvIiuoMl6x-Kn74Z2uVbbzS/",
  "BirdModels/Results/Archive/LandcoverModels/Coefficients"
)
birds <- c("AMRO", "YEWA", "WTSP", "CCSP", "SAVS")
regions <- c("north", "south")
draws <- 1:100

out_file <- "2_pipeline/temp_bird/v2_landcover_draws.csv"

if (!dir.exists(archive_dir)) {
  stop("v2 archive not reachable: ", archive_dir, call. = FALSE)
}

# 2. Read ----
if (file.exists(out_file)) {
  cat("Cached; delete", out_file, "to re-read.\n")
} else {
  rows <- list()

  for (region in regions) {
    for (species in birds) {
      cat(region, species, "\n")

      for (draw in draws) {
        path <- file.path(
          archive_dir, region, species,
          sprintf("%sModel_%s_%d.csv", tools::toTitleCase(region),
                  species, draw)
        )

        if (!file.exists(path)) {
          next
        }

        x <- fread(path)
        rows[[length(rows) + 1]] <- data.table(
          species = species, region = region, boot = draw,
          term = x$name, coef = x$coef
        )
      }
    }
  }

  v2_draws <- rbindlist(rows)

  dir.create(dirname(out_file), recursive = TRUE,
             showWarnings = FALSE)
  fwrite(v2_draws, out_file)

  cat("Wrote", out_file, ":", nrow(v2_draws), "rows,",
      uniqueN(v2_draws[, .(species, region, boot)]),
      "species-region-draws\n")
}

# End of script ----
