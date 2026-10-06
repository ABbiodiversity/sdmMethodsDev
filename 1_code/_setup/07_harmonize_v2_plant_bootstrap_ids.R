# ---
# title: Harmonize v2's Stored Plant-Group Bootstrap Draws
# author: Brendan Casey
# created: 2026-09-29
# inputs:
#   Read from the input mirror on ABMI-DATA2 (utils/
#   input_paths.R; 00_mirror_setup_inputs.R made it). The
#   locations below are the originals, which the SDM_* variables
#   can point back to.
#   in the v2 plant project (SDM_V2_PROJECT):
#     - 0_data/bootstrap/lichen-bootstrap-ids.Rdata
#     - 0_data/bootstrap/mite-bootstrap-ids.Rdata
#     - 0_data/bootstrap/vascular-plant-bootstrap-ids.Rdata
#   in this repository:
#     - 2_pipeline/v2_reference/bryophyte-bootstrap-ids.Rdata,
#       from 03_rerun_bryophyte_v2_reference.R
# outputs:
#   in 0_data/test_dataset/lookup/v2_bootstrap_ids/<taxon>/:
#     - <species>.rds, one per species
# notes:
#   - v2 draws its plant bootstrap once per species, without a
#     seed, and stores the draws. Replaying them is what makes
#     parity numerical rather than distributional: the harness
#     then fits the rows v2 fitted, draw by draw. The plant specs
#     read them with `bootstrap = "v2_ids"`.
#   - Each file is v2's matrix for one species, survey units by
#     100 draws, holding SiteYearQu, which is the test dataset's
#     survey_unit_id for the plant-group taxa. Draw 1 is the full
#     data; the others are drawn with replacement, so ids repeat.
#   - Written per species rather than per taxon, because the full
#     sets are large - 1.3 GB compressed for vascular plants - and
#     a run needs only the species it models. Set SDM_V2_BOOT_TAXA
#     and SDM_V2_BOOT_SPECIES (comma-separated) to harmonize a
#     subset; unset, every species of every taxon is written.
#   - Bryophytes come from the regenerated draws, because the
#     published file holds 3 draws. Those are the draws the
#     regenerated reference in 2_pipeline/v2_reference/ was fitted
#     on, not the ones behind COEFS.RData, so bryophyte parity
#     against v2_results.csv stays distributional.
#   - Ids not in sites.csv are counted and reported, not dropped.
# ---

# 1. Setup ----

## 1.1 Load packages ----
library(data.table) # reading sites.csv (version: 1.16.4)

## 1.2 Resolve paths ----
project_root <- normalizePath(getwd(), winslash = "/")

# The _setup inputs mirrored on ABMI-DATA2 (setup_input())
source(file.path(project_root, "1_code/_setup/utils/input_paths.R"))

v2_project <- Sys.getenv(
  "SDM_V2_PROJECT",
  unset = setup_input("vegetation_models")
)

sources <- c(
  bryophyte = file.path(
    project_root, "2_pipeline", "v2_reference",
    "bryophyte-bootstrap-ids.Rdata"
  ),
  lichen = file.path(
    v2_project, "0_data", "bootstrap", "lichen-bootstrap-ids.Rdata"
  ),
  mite = file.path(
    v2_project, "0_data", "bootstrap", "mite-bootstrap-ids.Rdata"
  ),
  vascular_plant = file.path(
    v2_project, "0_data", "bootstrap",
    "vascular-plant-bootstrap-ids.Rdata"
  )
)

out_root <- file.path(
  project_root, "0_data", "test_dataset", "lookup",
  "v2_bootstrap_ids"
)

## 1.3 Choose what to harmonize ----
`%||%` <- function(a, b) if (is.null(a)) b else a

split_env <- function(name) {
  value <- Sys.getenv(name, unset = "")
  if (!nzchar(value)) NULL else trimws(strsplit(value, ",")[[1]])
}

taxa <- split_env("SDM_V2_BOOT_TAXA") %||% names(sources)
species_filter <- split_env("SDM_V2_BOOT_SPECIES")

unknown_taxa <- setdiff(taxa, names(sources))

if (length(unknown_taxa) > 0) {
  stop("Unknown taxa: ", paste(unknown_taxa, collapse = ", "),
       call. = FALSE)
}

sites <- fread(
  file.path(project_root, "0_data", "test_dataset", "sites.csv"),
  select = "survey_unit_id"
)$survey_unit_id

# 2. Harmonize ----
for (taxon in taxa) {
  path <- sources[[taxon]]

  if (!file.exists(path)) {
    stop("Bootstrap ids not found for ", taxon, ":\n  ", path,
         call. = FALSE)
  }

  cat("Reading ", taxon, " ...\n", sep = "")
  source_env <- new.env()
  load(path, envir = source_env)
  ids <- source_env$bootstrap.ids

  if (!is.list(ids) || is.null(names(ids))) {
    stop(taxon, ": `bootstrap.ids` is not a named list.",
         call. = FALSE)
  }

  keep <- if (is.null(species_filter)) {
    names(ids)
  } else {
    intersect(names(ids), species_filter)
  }

  out_dir <- file.path(out_root, taxon)
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

  written <- 0L
  skipped <- character(0)
  unmatched <- 0L

  for (species in keep) {
    draws <- ids[[species]]

    # A species whose draws errored in v2 is stored as an error
    # object, not a matrix; there is nothing to replay.
    if (!is.matrix(draws) || !is.character(draws)) {
      skipped <- c(skipped, species)
      next
    }

    unmatched <- unmatched + sum(!draws[, 1] %in% sites)
    saveRDS(
      unname(draws),
      file.path(out_dir, paste0(species, ".rds"))
    )
    written <- written + 1L
  }

  cat(
    "  ", taxon, ": wrote ", written, " species",
    if (length(skipped) > 0) {
      paste0("; skipped ", length(skipped), " with no usable draws")
    } else {
      ""
    },
    if (unmatched > 0) {
      paste0("; WARNING ", unmatched, " draw-1 ids not in sites.csv")
    } else {
      ""
    },
    "\n",
    sep = ""
  )

  rm(source_env, ids)
  gc()
}

# End of script ----
