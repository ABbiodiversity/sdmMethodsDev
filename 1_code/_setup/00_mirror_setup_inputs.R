# ---
# title: Mirror the _setup Inputs onto ABMI-DATA2
# author: Brendan Casey
# created: 2026-10-05
# inputs:
#   the original locations of every external file _setup/ reads,
#   listed in section 1.3:
#     - //ABMI-DATA2/science/sc/sdmMethodsDev/0_data/
#       data_snapshots/model_ready_v2/
#     - //ABMI-DATA2/science/sc/AB_data_v2023/sites/processed/
#       climate/
#     - //ABMI-DATA2/science/sc/ToEmily/VegetationModels/
#     - the work_abmi, BirdModels and ABMI Mammals Google drives
# outputs:
#   in //ABMI-DATA2/science/sdmMethodsDev/0_data/setup_inputs/
#   (SDM_SETUP_INPUT_ROOT overrides it):
#     - <source>/..., byte-for-byte copies, under each source's
#       own relative paths
#     - inputs_manifest.csv: per file, the original path, the
#       mirror path, bytes, md5, source modification time and
#       the date it was copied
#     - README.md: what the folder is and the rules for it
# notes:
#   - Makes _setup/ runnable by anyone with ABMI-DATA2 access.
#     Originals are never modified.
#   - Never overwrites the mirror: mirrored files are md5-checked
#     and skipped, and a changed source stops the script (move the
#     old copy aside to re-mirror). Copies go via a .partial name.
#   - Not mirrored, deliberately:
#     - the v2 coefficient outputs on the drives (the bird
#       coefficient CSVs, COEFS.RData, the mammal coefficient
#       tables). Parity is scored against ABMIexploreR (06), so
#       nothing in _setup/ reads them.
#     - _setup/06's species-coefs.RData, which 06 downloads from
#       the public ABMIexploreR repository at a pinned commit.
#     - 0_data/v2_scripts/, which is tracked in git.
#   - Run once, from the repository root, by someone who can
#     reach every source. Reads are serial: the Google Drive
#     mount refuses concurrent reads.
# ---

# 1. Setup ----

## 1.1 Load packages ----
library(data.table) # manifest reading and writing (version: 1.16.4)

## 1.2 Resolve the mirror ----
project_root <- normalizePath(getwd(), winslash = "/")
helper <- file.path(project_root, "1_code/_setup/utils/input_paths.R")

if (!file.exists(helper)) {
  stop("Run this from the repository root.", call. = FALSE)
}

source(helper)

manifest_path <- setup_input("inputs_manifest.csv")

## 1.3 The inventory ----
# One entry per source: where it lives, and the paths below it
# that _setup/ reads. A path that is a folder is copied whole.
# The mirror keeps each path below a folder named for the source,
# so the scripts' roots (SDM_V2_PROJECT and the like) carry over.
sources <- list(
  model_ready_v2 = list(
    from = paste0(
      "//ABMI-DATA2/science/sc/sdmMethodsDev/0_data/",
      "data_snapshots/model_ready_v2"
    ),
    paths = "."
  ),
  ab_data_v2023 = list(
    from = paste0(
      "//ABMI-DATA2/science/sc/AB_data_v2023/sites/processed/",
      "climate"
    ),
    paths = "abmi-camera-climate_2023.Rdata"
  ),
  vegetation_models = list(
    from = "//ABMI-DATA2/science/sc/ToEmily/VegetationModels",
    paths = c(
      "0_data/lookup/prediction-matrix",
      "0_data/species/processed/bryophyte-model-data.Rdata",
      "0_data/bootstrap/bryophyte-bootstrap-ids.Rdata",
      "0_data/bootstrap/lichen-bootstrap-ids.Rdata",
      "0_data/bootstrap/mite-bootstrap-ids.Rdata",
      "0_data/bootstrap/vascular-plant-bootstrap-ids.Rdata"
    )
  ),
  birds_data_v2 = list(
    from = paste0(
      "G:/Shared drives/work_abmi/1_projects/active/",
      "sdmMethodsDev/remote/birds_data_v2"
    ),
    paths = "Stratified.Rdata"
  ),
  bird_models = list(
    from = paste0(
      "G:/.shortcut-targets-by-id/",
      "17Ymt13eHfKvIiuoMl6x-Kn74Z2uVbbzS/BirdModels"
    ),
    paths = c(
      "Data/lookups/Xn-veg-v2024.Rdata",
      "Data/lookups/birdlist.csv"
    )
  ),
  abmi_mammals = list(
    from = "G:/Shared drives/ABMI Mammals",
    paths = c(
      paste0(
        "Results/Habitat Modeling/2024/Climate/Predictions/",
        "All Species Climate Predictions.csv"
      ),
      "Data/Lookup Tables/WildTrax Species Strings.RData"
    )
  )
)

# 2. List the files ----
# Stops before copying if any source is unreachable

## 2.1 Expand each source ----
files <- rbindlist(lapply(names(sources), function(name) {
  src <- sources[[name]]

  rel <- unlist(lapply(src$paths, function(path) {
    full <- file.path(src$from, path)

    if (dir.exists(full)) {
      inside <- list.files(full, recursive = TRUE)
      if (path == ".") inside else file.path(path, inside)
    } else {
      path
    }
  }))

  data.table(
    source = name,
    from = file.path(src$from, rel),
    to = file.path(name, rel)
  )
}))

## 2.2 Check every source is reachable ----
missing <- files$from[!file.exists(files$from)]

if (length(missing) > 0) {
  stop(
    "Source file(s) not found:\n  ",
    paste(missing, collapse = "\n  "),
    call. = FALSE
  )
}

cat(
  nrow(files), " files, ",
  round(sum(file.size(files$from)) / 1e9, 2), " GB, from ",
  length(sources), " sources\n",
  sep = ""
)

# 3. Copy ----

## 3.1 The previous manifest, to keep first-copy dates ----
previous <- if (file.exists(manifest_path)) {
  fread(manifest_path, colClasses = "character")
} else {
  NULL
}

## 3.2 Copy each file ----
rows <- vector("list", nrow(files))

for (i in seq_len(nrow(files))) {
  from <- files$from[i]
  to <- setup_input(files$to[i])
  source_md5 <- unname(tools::md5sum(from))

  if (file.exists(to)) {
    # Already mirrored: the copy must still match its source
    if (!identical(unname(tools::md5sum(to)), source_md5)) {
      stop(
        "The source has changed since it was mirrored:\n  ",
        from, "\nThe mirror is never overwritten. Move\n  ", to,
        "\naside first if the new version should replace it.",
        call. = FALSE
      )
    }

    copied <- if (is.null(previous)) {
      NA_character_
    } else {
      previous$copied[match(files$to[i], previous$path)]
    }
    status <- "present"
  } else {
    dir.create(dirname(to), recursive = TRUE, showWarnings = FALSE)
    partial <- paste0(to, ".partial")

    if (!file.copy(from, partial, overwrite = TRUE,
                   copy.date = TRUE)) {
      stop("Copy failed:\n  ", from, call. = FALSE)
    }

    if (!identical(unname(tools::md5sum(partial)), source_md5)) {
      unlink(partial)
      stop("md5 mismatch after copying:\n  ", from, call. = FALSE)
    }

    if (!file.rename(partial, to)) {
      stop("Could not rename into place:\n  ", to, call. = FALSE)
    }

    copied <- NA_character_
    status <- "copied"
  }

  rows[[i]] <- data.table(
    source = files$source[i],
    path = files$to[i],
    original = from,
    bytes = file.size(from),
    md5 = source_md5,
    source_modified = format(
      file.mtime(from), "%Y-%m-%d %H:%M:%S"
    ),
    copied = if (is.na(copied)) format(Sys.Date()) else copied
  )

  cat(sprintf("[%d/%d] %s %s\n", i, nrow(files), status, files$to[i]))
}

# 4. Record ----

## 4.1 The manifest ----
# Rows for files dropped from the inventory are kept as
# provenance for copies still in the mirror
manifest <- rbindlist(rows)

if (!is.null(previous)) {
  kept <- previous[!path %in% manifest$path]
  manifest <- rbind(manifest, kept, fill = TRUE)
}

setorder(manifest, source, path)
fwrite(manifest, manifest_path)

## 4.2 The README ----
writeLines(c(
  "# _setup inputs for sdmMethodsDev",
  "",
  "Byte-for-byte copies of every external file that",
  "`1_code/_setup/` in the sdmMethodsDev repository reads, so",
  "anyone with access to this share can rebuild the test",
  "dataset. Written by `1_code/_setup/00_mirror_setup_inputs.R`.",
  "",
  "- Do not edit, rename or delete anything here. The _setup",
  "  scripts read these paths by default.",
  "- `inputs_manifest.csv` gives each file's original location,",
  "  size, md5 and the date it was copied.",
  "- The originals were left in place; the manifest names them.",
  "- The retired 04 and 05's inputs are not here: their output,",
  "  `v2_results/`, is published frozen under `../v2_results/`."
), setup_input("README.md"))

cat("\nWrote", manifest_path, "\n")

# End of script ----
