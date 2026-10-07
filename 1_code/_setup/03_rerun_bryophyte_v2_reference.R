# ---
# title: Re-run the v2 Bryophyte Models to Restore the Reference
# author: Brendan Casey
# created: 2026-09-10
# inputs:
#   Read via setup_input() (utils/input_paths.R); the original
#   locations are listed, and SDM_* variables can point back.
#   in the v2 project (SDM_V2_PROJECT):
#     - 0_data/species/processed/bryophyte-model-data.Rdata
#     - 0_data/bootstrap/bryophyte-bootstrap-ids.Rdata
#     - 0_data/lookup/prediction-matrix/*.csv
#   in this repository:
#     - 0_data/v2_scripts/plants/hierarchical-model_functions.R
# outputs:
#   in 2_pipeline/v2_reference/:
#     - bryophyte-species-models.Rdata
# notes:
#   - The published bryophyte reference is unusable: every entry
#     is a `could not find function "model.avg"` error (MuMIn was
#     missing on the cluster workers).
#   - Regenerates the climate stage with the frozen v2 functions,
#     unmodified, writing to 2_pipeline/ only.
#   - 134 species x 100 draws x 58 models is large;
#     `species_n` and `boot_n` build a partial reference, which
#     the per-species gate can still use.
#   - Section 3.3 checks MuMIn loads on a worker before fitting.
# ---

# 1. Setup ----

## 1.1 Load packages ----
library(foreach) # sequential %dopar%, as in v2 (version: 1.5.2)
library(parallel) # bootstrap-level parallelism (version: 4.5.0)

## 1.2 Configure ----
project_root <- normalizePath(getwd(), winslash = "/")

# The _setup inputs mirrored on ABMI-DATA2 (setup_input())
source(file.path(project_root, "1_code/_setup/utils/input_paths.R"))

v2_project <- Sys.getenv(
  "SDM_V2_PROJECT",
  unset = setup_input("vegetation_models")
)

out_dir <- file.path(project_root, "2_pipeline/v2_reference")

# NULL runs everything. Set them to build a partial reference.
species_n <- NULL
boot_n <- NULL

n_clusters <- 14

## 1.3 Load the frozen v2 functions ----
# From the byte-identical snapshot in 0_data/v2_scripts/
source(file.path(
  project_root,
  "0_data/v2_scripts/plants/hierarchical-model_functions.R"
))

## 1.4 Set the seed ----
# Seeded, unlike v2, so this reference reproduces itself
boot_seed <- 20260910L

## 1.5 Load the v2 data ----
model_data_path <- file.path(
  v2_project, "0_data/species/processed",
  "bryophyte-model-data.Rdata"
)

bootstrap_path <- file.path(
  v2_project, "0_data/bootstrap", "bryophyte-bootstrap-ids.Rdata"
)

for (path in c(model_data_path, bootstrap_path)) {
  if (!file.exists(path)) {
    stop(
      "v2 input not found:\n  ", path,
      "\nSet SDM_V2_PROJECT to the VegetationModels project.",
      call. = FALSE
    )
  }
}

load(model_data_path)
load(bootstrap_path)

species.list <- unique(c(veg.species.list, soil.species.list))

if (!is.null(species_n)) {
  species.list <- utils::head(species.list, species_n)
  veg.species.list <- intersect(veg.species.list, species.list)
  soil.species.list <- intersect(soil.species.list, species.list)
}

boot.iter <- if (is.null(boot_n)) 1:100 else seq_len(boot_n)

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

cat(
  "Re-running v2 bryophyte models: ", length(species.list),
  " species x ", length(boot.iter), " bootstraps\n",
  sep = ""
)

# 2. Bootstrap ids ----
# Checked, not trusted: the bryophyte file holds 3 draws, not 100

## 2.1 Check what the stored ids carry ----
stored_draws <- min(vapply(bootstrap.ids, ncol, integer(1)))

cat("Stored bootstrap draws: ", stored_draws, "\n", sep = "")

## 2.2 Regenerate when they fall short ----
# A fresh, seeded draw (an unseeded partial set cannot be
# extended); the seed is saved beside the ids
if (stored_draws < max(boot.iter)) {
  cat(
    "Regenerating: ", max(boot.iter), " draws needed, ",
    stored_draws, " stored.\n",
    sep = ""
  )

  source(file.path(
    project_root,
    "0_data/v2_scripts/plants/bootstrapping_functions.R"
  ))

  # The spatial blocks v2 resamples within, on its own grid.
  site.block <- data.frame(
    LongBlock = cut(
      climate.data$Long, c(-121, -116, -112, -109)
    ),
    LatBlock = cut(climate.data$Lat, c(48, 51, 54, 57, 61))
  )

  site.block$Block <- interaction(
    droplevels(site.block$LongBlock),
    droplevels(site.block$LatBlock),
    sep = "::", drop = TRUE
  )

  reclass.site <- data.frame(
    Orig = unique(site.block$Block),
    Update = letters[seq_along(unique(site.block$Block))]
  )

  climate.data$Block <- reclass.site$Update[
    match(site.block$Block, reclass.site$Orig)
  ]

  rm(site.block, reclass.site)

  set.seed(boot_seed)

  boot_cluster <- makeCluster(n_clusters)
  clusterSetRNGStream(boot_cluster, boot_seed)

  clusterExport(boot_cluster, c(
    "climate.data", "boot.iter", "bootstrap_data"
  ))

  boot_start <- Sys.time()

  bootstrap.list <- lapply(species.list, function(one) {
    # Exported by name: a worker cannot see the loop variable
    # of a closure whose environment is the global one.
    focal <- one
    clusterExport(boot_cluster, "focal", envir = environment())

    parSapply(
      boot_cluster, as.list(boot.iter),
      FUN = function(boot) {
        tryCatch(
          bootstrap_data(
            data = climate.data, species = focal,
            threshold = 20, boot = boot
          ),
          error = function(e) e
        )
      }
    )
  })

  names(bootstrap.list) <- species.list
  stopCluster(boot_cluster)

  bootstrap.ids <- lapply(bootstrap.list, simplify2array)

  cat(
    "Regenerated ", length(bootstrap.ids), " species in ",
    format(round(Sys.time() - boot_start, 1)), "\n",
    sep = ""
  )

  save(
    bootstrap.ids, boot_seed,
    file = file.path(out_dir, "bryophyte-bootstrap-ids.Rdata")
  )
}

# 3. Climate models ----
# v2's 58 candidates: 14 base, 14 bioclim, 30 spatial

## 3.1 Define the model sets ----
climate.models <- list(
  as.formula(paste("pcount ~ 1")),
  as.formula(paste("pcount ~ PET")),
  as.formula(paste("pcount ~ CMD")),
  as.formula(paste("pcount ~ MAT")),
  as.formula(paste("pcount ~ FFP")),
  as.formula(paste("pcount ~ MAP + FFP")),
  as.formula(paste("pcount ~ MAP + FFP + CMD")),
  as.formula(paste("pcount ~ MAP + PET + CMD + MAPPET")),
  as.formula(paste("pcount ~ MAT + MAP + CMD + CMDMAT")),
  as.formula(paste("pcount ~ MAT + MAP")),
  as.formula(paste("pcount ~ MWMT + TD")),
  as.formula(paste("pcount ~ CMD + PET")),
  as.formula(paste("pcount ~ MAT + MAT2 + MWMT + MWMT2")),
  as.formula(paste("pcount ~ TD + FFP + MAT"))
)

bioclim.models <- list(as.formula(paste(".~.+ bio9 + bio15")))

space.models <- list(
  as.formula(paste(".~.+ Easting + Northing")),
  as.formula(paste(".~.+ Easting + Northing + EastingNorthing")),
  as.formula(paste(
    ".~.+ Easting + Northing + Easting2 + Northing2 +",
    "EastingNorthing"
  ))
)

## 3.2 Start the cluster ----
core.input <- makeCluster(n_clusters)

clusterExport(core.input, c(
  "climate.data", "species.list", "bootstrap.ids",
  "climate.models", "bioclim.models", "space.models", "boot.iter",
  "climate_models"
))

invisible(clusterEvalQ(core.input, {
  library(AICcmodavg)
  library(arm)
  library(binom)
  library(mapproj)
  library(mgcv)
  library(MuMIn)
  library(pROC)
  library(RcmdrMisc)
}))

## 3.3 Confirm MuMIn is loadable on a worker ----
# The failure behind the unusable published reference
worker_has_mumin <- unlist(clusterEvalQ(
  core.input, exists("model.avg")
))

if (!all(worker_has_mumin)) {
  stopCluster(core.input)
  stop(
    "model.avg() is not available on ", sum(!worker_has_mumin),
    " of ", length(worker_has_mumin), " cluster workers.\n",
    "That is the failure that made the published reference ",
    "unusable. Install MuMIn where the workers can see it.",
    call. = FALSE
  )
}

cat("MuMIn confirmed on all ", length(worker_has_mumin),
    " workers\n", sep = "")

## 3.4 Fit ----
climate_start <- Sys.time()

climate.coef <- foreach(species = species.list) %dopar%
  t(parSapply(
    core.input,
    as.list(boot.iter),
    FUN = function(boot) {
      tryCatch(
        climate_models(
          species = species, data = climate.data,
          boot.data = bootstrap.ids,
          climate.models = climate.models,
          bioclim.models = bioclim.models,
          space.models = space.models, boot = boot
        ),
        error = function(e) e
      )
    }
  ))

names(climate.coef) <- species.list
stopCluster(core.input)

# Counted per draw: one bad draw in 100 leaves a usable species
usable_species <- sum(
  vapply(climate.coef, is.numeric, logical(1))
)

failed_draws <- sum(vapply(
  climate.coef,
  function(x) {
    if (is.numeric(x)) {
      return(0L)
    }

    sum(vapply(
      seq_along(x), function(i) inherits(x[[i]], "condition"),
      logical(1)
    ))
  },
  integer(1)
))

cat(
  "Climate: ", usable_species, " of ", length(climate.coef),
  " species fully usable; ", failed_draws, " failed draw(s),",
  " in ", format(round(Sys.time() - climate_start, 1)), "\n",
  sep = ""
)

if (usable_species == 0 && failed_draws > 0) {
  first <- climate.coef[[1]]
  first_message <- "unknown"

  for (i in seq_along(first)) {
    if (inherits(first[[i]], "condition")) {
      first_message <- conditionMessage(first[[i]])
      break
    }
  }

  stop(
    "No species produced a usable set. First error: ",
    first_message,
    call. = FALSE
  )
}

# 4. Save ----
# Climate only; the habitat sets depend on it and are a separate
# run
save(
  climate.coef,
  file = file.path(out_dir, "bryophyte-species-models.Rdata")
)

cat(
  "Wrote ", file.path(out_dir, "bryophyte-species-models.Rdata"),
  "\n",
  sep = ""
)

# End of script ----
