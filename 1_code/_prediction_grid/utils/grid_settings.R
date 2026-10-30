# ---
# title: Prediction Grid Settings and Source Paths
# author: Brendan Casey
# created: 2026-10-27
# inputs: none
# outputs: none; defines prediction_grid_settings, grid_source(),
#   grid_build_dir() and write_grid_manifest()
# notes:
#   - One place for the grid version, its resolution, and the
#     four v2.0 source files with their expected md5s. The
#     version names its sources, so a source with another md5
#     needs a new version, not a rebuild of this one.
#   - Each source path can be overridden with its environment
#     variable (for example SDM_GRID_KGRID), so a local copy can
#     be read. SDM_GRID_BUILD_ROOT moves the local build folder.
#   - The kgrid and backfill are read from ABMI-DATA2 by UNC
#     path (S: on most ABMI machines). The lookups are on the
#     mammal shared drive; each grid version keeps byte copies.
#   - See docs/prediction_design.md section 1 for the design.
# ---

# 1. Settings ----
# `res_m` is the only resolution with covariate inputs today:
# the backfill exists only as 1 km cell summaries
# (docs/prediction_design.md section 1.1).
prediction_grid_settings <- list(
  version = "kgrid22_bf7hfi2021_1km_v1",
  res_m = 1000,
  build_root = Sys.getenv(
    "SDM_GRID_BUILD_ROOT",
    unset = "2_pipeline/shared/prediction_grid"
  ),
  sources = list(
    kgrid = list(
      path = paste0(
        "//ABMI-DATA2/science/sc/AB_data_v2023/kgrid/",
        "kgrid_2.2.Rdata"
      ),
      env = "SDM_GRID_KGRID",
      md5 = "5cb58d609acc54c575832e0785943790"
    ),
    backfill = list(
      path = paste0(
        "//ABMI-DATA2/science/sc/AB_data_v2023/landcover/",
        "backfillV7_w2w_2021HFI.Rdata"
      ),
      env = "SDM_GRID_BACKFILL",
      md5 = "f3c034c6e38868e63035562834fb0a6f"
    ),
    veg_lookup = list(
      path = paste0(
        "G:/Shared drives/ABMI Mammals/Data/Habitat Models/",
        "lookup-veg-hf-age-v2020.csv"
      ),
      env = "SDM_GRID_VEG_LOOKUP",
      md5 = "2bbd27d44b14b7f3d29dfeeb5815ef34"
    ),
    soil_lookup = list(
      path = paste0(
        "G:/Shared drives/ABMI Mammals/Data/Habitat Models/",
        "lookup-soil-hf-v2020.csv"
      ),
      env = "SDM_GRID_SOIL_LOOKUP",
      md5 = "b38cec8c68d592f4596999c9c3f36011"
    )
  ),
  # kgrid climate normals, kept as named. PET is added as Eref.
  climate = c(
    "MAT", "MWMT", "MCMT", "TD", "MAP", "MSP", "AHM", "SHM",
    "DD_0", "DD5", "DD_18", "DD18", "NFFD", "bFFP", "eFFP",
    "FFP", "PAS", "EMT", "EXT", "Eref", "CMD", "RH", "CMI",
    "DD1040", "bio9", "bio15", "HTV"
  ),
  # Land-cover layers: d.wide element, lookup, and region
  landcover = data.frame(
    layer = c(
      "veg_current", "veg_reference",
      "soil_current", "soil_reference"
    ),
    d_wide = c(
      "veg.current", "veg.reference",
      "soil.current", "soil.reference"
    ),
    lookup = c("veg_lookup", "veg_lookup", "soil_lookup",
               "soil_lookup"),
    region = c("north", "north", "south", "south"),
    scenario = c("current", "reference", "current", "reference")
  )
)

# 2. grid_source() ----

#' Resolve and Check One Grid Source File
#'
#' @param name Character. A name in
#'   `prediction_grid_settings$sources`.
#' @param check_md5 Logical. Stop when the file's md5 differs
#'   from the expected one.
#' @return Character. The path, with its md5 as attribute "md5".
#'
#' @example # Example usage of the function
#' # grid_source("kgrid")
grid_source <- function(name, check_md5 = TRUE) {
  # Step 1: The environment variable, then the default path
  src <- prediction_grid_settings$sources[[name]]

  if (is.null(src)) {
    stop("Unknown grid source: ", name, call. = FALSE)
  }

  from_env <- Sys.getenv(src$env, unset = "")
  path <- if (nzchar(from_env)) from_env else src$path

  if (!file.exists(path)) {
    stop(
      "Grid source ", name, " not found:\n  ", path,
      "\nConnect to the ABMI network (or VPN), or set ",
      src$env, " to a local copy.",
      call. = FALSE
    )
  }

  # Step 2: The file the version was named for
  md5 <- unname(tools::md5sum(path))

  if (isTRUE(check_md5) && !identical(md5, src$md5)) {
    stop(
      "Grid source ", name, " has md5 ", md5, ", not ",
      src$md5, ":\n  ", path,
      "\nA changed source needs a new grid version.",
      call. = FALSE
    )
  }

  structure(path, md5 = md5)
}

# 3. grid_build_dir() ----

#' The Local Build Folder of a Grid Version
#'
#' @param version Character. The grid version.
#' @return Character. The folder (not created).
#'
#' @example # Example usage of the function
#' # grid_build_dir()
grid_build_dir <- function(
    version = prediction_grid_settings$version) {
  file.path(prediction_grid_settings$build_root, version)
}

# 4. write_grid_manifest() ----

#' Rewrite manifest.md from Every Built Version's Records
#'
#' Each version folder holds build_record.csv (from 01) and,
#' once checked, qa_summary.csv (from 02). The manifest is
#' rebuilt from them, so it never disagrees with the folders.
#'
#' @param root Character. The folder holding the versions.
#' @return Character. The manifest path, invisibly.
#'
#' @example # Example usage of the function
#' # write_grid_manifest()
write_grid_manifest <- function(
    root = prediction_grid_settings$build_root) {
  # Step 1: The versions with a build record
  versions <- list.dirs(root, full.names = FALSE,
                        recursive = FALSE)
  versions <- versions[file.exists(
    file.path(root, versions, "build_record.csv")
  )]

  lines <- c(
    "# Prediction grid manifest",
    "",
    "One entry per built version. Rebuilt by",
    "`1_code/_prediction_grid/utils/grid_settings.R` from each",
    "version's `build_record.csv` and `qa_summary.csv`; do not",
    "edit by hand. Design: `docs/prediction_design.md` section 1.",
    ""
  )

  # Step 2: One section per version
  for (v in sort(versions)) {
    rec <- read.csv(file.path(root, v, "build_record.csv"),
                    colClasses = "character")
    get <- function(key) rec$value[rec$key == key]

    lines <- c(
      lines,
      paste0("## ", v),
      "",
      paste0("- Built: ", get("built"), " by ", get("user")),
      paste0("- Script: `", get("script"), "`"),
      paste0("- Commit: ", get("commit")),
      paste0("- Resolution: ", get("res_m"), " m; cells: ",
             get("cells")),
      paste0("- Lattice: ", get("lattice")),
      paste0("- Crosswalk to the v2.0 kgrid: ", get("crosswalk")),
      "",
      "| Source | Path | md5 |",
      "| --- | --- | --- |"
    )

    src <- rec[startsWith(rec$key, "source_"), ]

    for (i in seq_len(nrow(src))) {
      parts <- strsplit(src$value[i], " | ", fixed = TRUE)[[1]]
      lines <- c(lines, paste0(
        "| ", sub("^source_", "", src$key[i]), " | `",
        parts[1], "` | ", parts[2], " |"
      ))
    }

    # Step 3: The QA outcome, when 02 has run
    qa_path <- file.path(root, v, "qa_summary.csv")

    if (file.exists(qa_path)) {
      qa <- read.csv(qa_path, colClasses = "character")
      lines <- c(
        lines, "",
        paste0(
          "QA (", qa$checked[1], "): ",
          sum(qa$status == "pass"), " pass, ",
          sum(qa$status == "note"), " note, ",
          sum(qa$status == "fail"), " fail. ",
          "Details: `docs/prediction_grid_qa.md`."
        )
      )
    } else {
      lines <- c(lines, "", "QA: not yet run.")
    }

    lines <- c(lines, "")
  }

  path <- file.path(root, "manifest.md")
  writeLines(lines, path)
  invisible(path)
}

# End of script ----
