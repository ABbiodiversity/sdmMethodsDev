# ---
# title: Validate Bootstrapped Models (Plant Groups)
# author: Brendan Casey
# created: 2026-09-08
# inputs:
#   set by the calling experiment, or defaulted in 1.2:
#     - taxon, data_dir, run_dir, species_subset, boot_iter,
#       n_clusters
#   in data_dir:
#     - <taxon>.csv, sites.csv, covariates/, lookup/
#   in run_dir:
#     - bootstrap/<taxon>-bootstrap-ids.Rdata, from 01
#     - models/<taxon>-species-models.Rdata, from 02
#   in this repository:
#     - 1_code/modules/plants/load_model_data.R
#     - 1_code/modules/plants/functions/
#       model-validation_functions.R
# outputs:
#   in run_dir:
#     - validation/<taxon>-models-validation.Rdata
#       (vegetation.fit, soil.fit)
# notes:
#   - Rewrite of the v2 scripts 03a-03d, which were four
#     near-identical files differing only in the taxon they
#     loaded and in protocol.flag. They are one script here,
#     parameterized by `taxon`, with the flag read from
#     plant_taxa() so it cannot drift from what 02 fitted.
#   - The species queue comes from the fitted model object rather
#     than from the data, exactly as v2 did, so validation covers
#     what was actually fitted even when 02 ran on a subset.
#   - NA coefficients are set to qlogis(0.001) before scoring and
#     the standard error columns are dropped, which is v2's
#     handling of a bootstrap that failed to converge: an
#     unestimated coefficient is scored as near-zero probability
#     rather than dropping the iteration.
#   - v2's 03a header names its output byrophyte-...Rdata while
#     the code writes bryophyte-...Rdata. The name is built from
#     `taxon` here, so the two cannot disagree.
#   - The species selection is `species_subset`, not `species`.
#     The v2 code loops with `for (species in species.list)`,
#     which would otherwise overwrite the selection and leave the
#     next stage running on one species.
#   - Future improvement - the two model sets differ only in
#     their data, coefficients and landcover.type, so they could
#     share one helper rather than repeating the cluster setup.
# ---

# 1. Setup ----

## 1.1 Load packages ----
library(foreach) # sequential %dopar% loop, as in v2 (version: 1.5.2)
library(parallel) # bootstrap-level parallelism (version: 4.5.0)

## 1.2 Configure the run ----
# Values a calling experiment has already set are kept, so this
# script runs either from 1_code/experiments/ or on its own.
if (!exists("project_root", inherits = FALSE)) {
  project_root <- normalizePath(getwd(), winslash = "/")
}

if (!exists("taxon", inherits = FALSE)) {
  taxon <- "bryophyte"
}

if (!exists("data_dir", inherits = FALSE)) {
  data_dir <- file.path(project_root, "0_data/test_dataset")
}

if (!exists("run_dir", inherits = FALSE)) {
  run_dir <- file.path(project_root, "2_pipeline/plants")
}

if (!exists("species_subset", inherits = FALSE)) {
  species_subset <- NULL
}

# The v2 defaults.
if (!exists("boot_iter", inherits = FALSE)) {
  boot_iter <- 1:100
}

if (!exists("n_clusters", inherits = FALSE)) {
  n_clusters <- 14
}

## 1.3 Load functions and data ----
source(file.path(
  project_root, "1_code/modules/plants/load_model_data.R"
))
source(file.path(
  project_root,
  "1_code/modules/plants/functions/model-validation_functions.R"
))

model_data <- load_plant_model_data(
  taxon = taxon,
  data_dir = data_dir,
  species = species_subset
)

veg.data <- model_data$veg.data
soil.data <- model_data$soil.data

use_protocol <- taxon_uses_protocol(taxon)

## 1.4 Load the bootstrap ids and the fitted models ----
bootstrap_path <- file.path(
  run_dir, "bootstrap", paste0(taxon, "-bootstrap-ids.Rdata")
)

models_path <- file.path(
  run_dir, "models", paste0(taxon, "-species-models.Rdata")
)

missing_inputs <- c(bootstrap_path, models_path)
missing_inputs <- missing_inputs[!file.exists(missing_inputs)]

if (length(missing_inputs) > 0) {
  stop(
    "Validation inputs not found:\n  ",
    paste(missing_inputs, collapse = "\n  "),
    "\nRun 01_bootstrap_ids.R and 02_hierarchical_models.R first.",
    call. = FALSE
  )
}

load(bootstrap_path)
load(models_path)

## 1.5 Take the species queue from the fitted models ----
# Not from the data. 02 may have run on a subset, and only what
# it fitted can be scored.
species.list <- names(climate.coef)
veg.species.list <- names(vegetation.coef)
soil.species.list <- names(soil.coef)

dir.create(
  file.path(run_dir, "validation"),
  recursive = TRUE, showWarnings = FALSE
)

cat(
  "Validating ", taxon, ": ", length(veg.species.list),
  " vegetation and ", length(soil.species.list),
  " soil species x ", length(boot_iter), " bootstraps\n",
  sep = ""
)

## 1.6 Prepare coefficients for model fit evaluation ----
# A bootstrap that failed to estimate a coefficient leaves NA.
# v2 scores those as qlogis(0.001), a near-zero probability,
# rather than dropping the iteration, and drops the standard
# error columns, which are not used in scoring.
for (one_species in veg.species.list) {

  climate.coef[[one_species]][
    is.na(climate.coef[[one_species]])
  ] <- qlogis(0.001)

  vegetation.coef[[one_species]][
    is.na(vegetation.coef[[one_species]])
  ] <- qlogis(0.001)
  vegetation.coef[[one_species]] <- vegetation.coef[[one_species]][
    , -grep(".SE", colnames(vegetation.coef[[one_species]]))
  ]

}

for (one_species in soil.species.list) {

  climate.coef[[one_species]][
    is.na(climate.coef[[one_species]])
  ] <- qlogis(0.001)

  soil.coef[[one_species]][
    is.na(soil.coef[[one_species]])
  ] <- qlogis(0.001)
  soil.coef[[one_species]] <- soil.coef[[one_species]][
    , -grep(".SE", colnames(soil.coef[[one_species]]))
  ]

}

# 2. Vegetation model fit ----
# Scores the north model set per species per bootstrap, on AUC
# and the related measures model_validation() returns.

## 2.1 Define cores and objects for parallel processing ----
core.input <- makeCluster(n_clusters)
clusterExport(
  core.input,
  c("veg.data", "veg.species.list", "bootstrap.ids",
    "vegetation.coef", "climate.coef", "boot_iter",
    "use_protocol", "model_validation")
)
clusterEvalQ(core.input, {

  # Load relevant libraries
  library(pROC)

})

## 2.2 Loop through each species ----
vegetation.fit <- foreach(species = veg.species.list) %dopar%

  t(parSapply(
    core.input,
    as.list(boot_iter),
    FUN = function(boot) {
      tryCatch(
        model_validation(
          species = species,
          data = veg.data,
          boot.data = bootstrap.ids,
          climate.coef = climate.coef,
          landcover.coef = vegetation.coef,
          landcover.type = "Vegetation",
          protocol.flag = use_protocol,
          boot = boot
        ),
        error = function(e) e
      )
    }
  ))

names(vegetation.fit) <- veg.species.list

stopCluster(core.input)

# 3. Soil model fit ----
# The same scoring for the south model set.

## 3.1 Define cores and objects for parallel processing ----
core.input <- makeCluster(n_clusters)
clusterExport(
  core.input,
  c("soil.data", "soil.species.list", "bootstrap.ids",
    "soil.coef", "climate.coef", "boot_iter", "use_protocol",
    "model_validation")
)
clusterEvalQ(core.input, {

  # Load relevant libraries
  library(pROC)

})

## 3.2 Loop through each species ----
soil.fit <- foreach(species = soil.species.list) %dopar%

  t(parSapply(
    core.input,
    as.list(boot_iter),
    FUN = function(boot) {
      tryCatch(
        model_validation(
          species = species,
          data = soil.data,
          boot.data = bootstrap.ids,
          climate.coef = climate.coef,
          landcover.coef = soil.coef,
          landcover.type = "Soil",
          protocol.flag = use_protocol,
          boot = boot
        ),
        error = function(e) e
      )
    }
  ))

names(soil.fit) <- soil.species.list

stopCluster(core.input)

# 4. Save the results ----
validation_path <- file.path(
  run_dir, "validation",
  paste0(taxon, "-models-validation.Rdata")
)

save(vegetation.fit, soil.fit, file = validation_path)

cat("Wrote ", validation_path, "\n", sep = "")

# End of script ----
