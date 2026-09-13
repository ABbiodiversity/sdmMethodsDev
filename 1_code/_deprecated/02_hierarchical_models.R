# ---
# title: Fit Bootstrapped Hierarchical Models (Plant Groups)
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
#   in this repository:
#     - 1_code/modules/plants/load_model_data.R
#     - 1_code/modules/plants/functions/
#       hierarchical-model_functions.R
# outputs:
#   in run_dir:
#     - models/<taxon>-species-models.Rdata
#       (climate.coef, vegetation.coef, soil.coef)
# notes:
#   - Rewrite of the v2 scripts 02a-02d, which were four
#     near-identical files. They differed only in the taxon they
#     loaded and in whether they fitted a Protocol term, so they
#     are one script here, parameterized by `taxon`. The formula
#     text in section 2 is the v2 text verbatim, and the Protocol
#     term is inserted for the taxa whose v2 script carried it,
#     which reproduces all 42 formulas of both variants exactly.
#   - The v2 scripts read a <taxon>-model-data.Rdata that 01a
#     built against paths on the v2 project. This one reads the
#     harmonized test dataset, so a run needs only this
#     repository and 0_data/test_dataset/.
#   - Output location is the caller's to choose. v2 hard-coded
#     3_output/models/; here run_dir comes from the experiment.
#   - All three model sets are defined in section 2, before any
#     of them is fitted. v2 defined each set immediately before
#     fitting it, which meant a model naming a habitat type its
#     prediction matrix had no column for failed only after the
#     climate models had already run.
#   - The species selection is `species_subset`, not `species`.
#     The v2 code loops with `for (species in species.list)`,
#     which would otherwise overwrite the selection and leave the
#     next stage running on one species.
#   - boot_iter and n_clusters were hard-coded in v2 as 1:100 and
#     14. They are parameters here, but they default to the v2
#     values, so a parity run sets neither.
#   - The v2 code took its vegetation coefficient names
#     positionally, as colnames(veg.data)[403:489] and three
#     other per-taxon spans. load_model_data.R names them
#     instead; see its header for why.
#   - foreach() runs with no backend registered, exactly as in
#     v2, so the outer %dopar% is sequential and the parallelism
#     is the inner parSapply over bootstraps. Left as it is:
#     registering a backend would change the run, not just its
#     speed.
#   - Future improvement - the three model sets differ only in
#     their data, formulas and fitting function, so sections 3 to
#     5 could share one helper rather than repeating the cluster
#     setup.
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

# NULL models every species the snapshot declares as modelled.
if (!exists("species_subset", inherits = FALSE)) {
  species_subset <- NULL
}

# The v2 defaults. Lower them for a smoke test.
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
  "1_code/modules/plants/functions/hierarchical-model_functions.R"
))

model_data <- load_plant_model_data(
  taxon = taxon,
  data_dir = data_dir,
  species = species_subset
)

climate.data <- model_data$climate.data
veg.data <- model_data$veg.data
soil.data <- model_data$soil.data

veg.species.list <- model_data$veg.species.list
soil.species.list <- model_data$soil.species.list
species.list <- unique(c(veg.species.list, soil.species.list))

## 1.4 Load the bootstrap ids ----
# Written by 01_bootstrap_ids.R into the same run_dir.
bootstrap_path <- file.path(
  run_dir, "bootstrap", paste0(taxon, "-bootstrap-ids.Rdata")
)

if (!file.exists(bootstrap_path)) {
  stop(
    "No bootstrap ids at ",
    bootstrap_path,
    "\nRun 1_code/modules/plants/01_bootstrap_ids.R first.",
    call. = FALSE
  )
}

load(bootstrap_path)

## 1.5 Set the Protocol term for this taxon ----
# v2 fitted Protocol for bryophytes and lichens, and not for
# mites or vascular plants. plant_taxa() is the record of which.
use_protocol <- taxon_uses_protocol(taxon)

# In v2 the two Protocol scripts were their non-Protocol
# counterparts with the term inserted directly after Climate, and
# nowhere else. Applying that rule to the formula text in section
# 2 reproduces both variants exactly.
#
# The environment is set to the global environment, matching v2,
# where every formula was built at the top level.
build_models <- function(model_text, protocol = use_protocol) {
  lapply(
    model_text,
    function(one) {
      if (protocol) {
        one <- sub(
          "pcount ~ Climate",
          "pcount ~ Climate + Protocol",
          one,
          fixed = TRUE
        )
      }

      as.formula(one, env = globalenv())
    }
  )
}

# Prefix for the coefficient templates, for the same reason.
coef_prefix <- if (use_protocol) {
  c("Intercept", "Climate", "Protocol")
} else {
  c("Intercept", "Climate")
}

## 1.6 Create the output folder ----
# save() does not create a missing folder, so a run would
# otherwise fail after the modelling rather than before it.
dir.create(
  file.path(run_dir, "models"),
  recursive = TRUE, showWarnings = FALSE
)

cat(
  "Fitting ", taxon, ": ", length(species.list), " species x ",
  length(boot_iter), " bootstraps on ", n_clusters, " cores\n",
  sep = ""
)

# 2. Define the model sets ----
# Everything the three fitting sections need, built before any of
# them runs, so a mismatch between a model and its prediction
# matrix is found in seconds rather than after the climate models
# have been fitted.

## 2.1 Define climate models ----
# The climate formulas carry no Protocol term in either v2
# variant, so they are built without one.
climate.model.text <- c(
  "pcount ~ 1",
  "pcount ~ PET",
  "pcount ~ CMD",
  "pcount ~ MAT",
  "pcount ~ FFP",
  "pcount ~ MAP + FFP",
  "pcount ~ MAP + FFP + CMD",
  "pcount ~ MAP + PET + CMD + MAPPET",
  "pcount ~ MAT + MAP + CMD + CMDMAT",
  "pcount ~ MAT + MAP",
  "pcount ~ MWMT + TD",
  "pcount ~ CMD + PET",
  "pcount ~ MAT + MAT2 + MWMT + MWMT2",
  "pcount ~ TD + FFP + MAT"
)

climate.models <- build_models(
  climate.model.text, protocol = FALSE
)

bioclim.model.text <- c(
  ".~.+ bio9 + bio15"
)

bioclim.models <- build_models(
  bioclim.model.text, protocol = FALSE
)

## 2.2 Define spatial models ----
space.model.text <- c(
  ".~.+ Easting + Northing",
  ".~.+ Easting + Northing + EastingNorthing",
  ".~.+ Easting + Northing + Easting2 + Northing2 + EastingNorthing"
)

space.models <- build_models(space.model.text, protocol = FALSE)

## 2.3 Define the prediction matrices ----
# Both are needed for the checks below, so unlike v2 they are
# held under separate names rather than one reused
# prediction.matrix.
veg.prediction.matrix <- model_data$veg.pm
rownames(veg.prediction.matrix) <- veg.prediction.matrix$VegType
veg.prediction.matrix <- veg.prediction.matrix[, -1]

soil.prediction.matrix <- model_data$soil.pm
rownames(soil.prediction.matrix) <- soil.prediction.matrix$VegType
soil.prediction.matrix <- soil.prediction.matrix[, -1]

## 2.4 Define vegetation models ----
vegetation.model.text <- c(
  "pcount ~ Climate + WhiteSpruce + Pine + Deciduous + Mixedwood + BlackSpruce + TreedFen + TreedSwamp + GraminoidFen + ShrubbyFen + ShrubbyBog + ShrubbySwamp + Marsh + Grass + Shrub + CCWhiteSpruceR + CCWhiteSpruce1 + CCWhiteSpruce234 + CCPineR + CCPine1234 + CCDecidMixedR + CCDecidMixed1 + CCDecidMixed234 + HardLin + EnSeismic + EnSoftLin + TrSoftLin + UrbInd + Wellsites + Crop + RoughP + TameP",
  "pcount ~ Climate + WhiteSpruce + Pine + Deciduous + Mixedwood + Peatland + Mineral + Grass + Shrub + CCWhiteSpruceR + CCWhiteSpruce1 + CCWhiteSpruce234 + CCPineR + CCPine1234 + CCDecidMixedR + CCDecidMixed1 + CCDecidMixed234 + HardLin + EnSeismic + EnSoftLin + TrSoftLin + UrbInd + Wellsites + Crop + RoughP + TameP",
  "pcount ~ Climate + WhiteSpruce + Pine + Deciduous + Mixedwood + Bog + TreedFen + + NonTreedFen + TreedSwamp + ShrubbySwamp + Marsh + Grass + Shrub + CCWhiteSpruceR + CCWhiteSpruce1 + CCWhiteSpruce234 + CCPineR + CCPine1234 + CCDecidMixedR + CCDecidMixed1 + CCDecidMixed234 + HardLin + EnSeismic + EnSoftLin + TrSoftLin + UrbInd + Wellsites + Crop + RoughP + TameP",
  "pcount ~ Climate + WhiteSpruce + Pine + Deciduous + Mixedwood + Bog + Fen + TreedSwamp + ShrubbySwamp + Marsh + Grass + Shrub + CCWhiteSpruceR + CCWhiteSpruce1 + CCWhiteSpruce234 + CCPineR + CCPine1234 + CCDecidMixedR + CCDecidMixed1 + CCDecidMixed234 + HardLin + EnSeismic + EnSoftLin + TrSoftLin + UrbInd + Wellsites + Crop + RoughP + TameP",
  "pcount ~ Climate + WhiteSpruce + Pine + Deciduous + Mixedwood + Bog + Fen + Swamp + Marsh + GrassShrub + CCWhiteSprucePineR + CCWhiteSprucePine1 + CCWhiteSprucePine234 + CCDecidMixedR + CCDecidMixed1 + CCDecidMixed234 + HardLin + SoftLin + UrbInd + Wellsites + Crop + RoughP + TameP",
  "pcount ~ Climate + WhiteSpruce + Pine + Deciduous + Mixedwood + Peatland + Mineral + GrassShrub + CCWhiteSprucePineR1234 + CCDecidMixedR1234 + HardLin + SoftLin + UrbIndWellsites + Crop + Pasture",
  "pcount ~ Climate + WhiteSpruce + Pine + Deciduous + Mixedwood + Lowland + GrassShrub + CCWhiteSprucePineR1234 + CCDecidMixedR1234 + SoftLin + Alien",
  "pcount ~ Climate + Upland + BlackSpruce + TreedFen + TreedSwamp + GraminoidFen + ShrubbyFen + ShrubbyBog + ShrubbySwamp + Marsh + Grass + Shrub + CCR1234 + HardLin + EnSeismic + EnSoftLin + TrSoftLin + UrbInd + Wellsites + Crop + RoughP + TameP",
  "pcount ~ Climate + Upland + Bog + Fen + Swamp + Marsh + Grass + Shrub + CCR1234 + HardLin + EnSeismic + EnSoftLin + TrSoftLin + UrbInd + Wellsites + Crop + RoughP + TameP",
  "pcount ~ Climate + Upland + Peatland + Swamp + Marsh + GrassShrub + CCR1234 + HardLin + SoftLin + UrbInd + Wellsites + Crop + RoughP + TameP",
  "pcount ~ Climate + Upland + Peatland + Mineral + GrassShrub + CCR1234 + HardLin + SoftLin + UrbIndWellsites + Crop + Pasture",
  "pcount ~ Climate + Upland + Lowland + GrassShrub + CCR1234 + SoftLin + Alien"
)

vegetation.models <- build_models(vegetation.model.text)

## 2.5 Define soil models ----
soil.model.text <- c(
  "pcount ~ Climate + Blowout + ClaySub + Loamy + RapidDrain + SandyLoam + ThinBreak + Other + UrbInd + Wellsites + Crop + TameP + RoughP + EnSoftLin + EnSeismic + TrSoftLin + HardLin",
  "pcount ~ Climate + Blowout + ClaySubThin + Loamy + SandyRapid + Other +  UrbInd+ Wellsites + Crop + TameP + RoughP + EnSoftLin + EnSeismic + TrSoftLin + HardLin",
  "pcount ~ Climate + Productive + Nonproductive + Other + UrbInd + Wellsites + Crop + TameP + RoughP + EnSoftLin + EnSeismic + TrSoftLin + HardLin",
  "pcount ~ Climate + Blowout + ClaySub + Loamy + RapidDrain + SandyLoam + ThinBreak  + Other + UrbIndWellsites + Crop + Pasture + SoftLin + HardLin",
  "pcount ~ Climate + Blowout + ClaySubThin + Loamy + SandyRapid + Other + UrbIndWellsites + Crop + Pasture + SoftLin + HardLin",
  "pcount ~ Climate + Productive + Nonproductive + Other + UrbIndWellsites + Crop + Pasture + SoftLin + HardLin",
  "pcount ~ Climate + Productive + Nonproductive + Other + UrbIndWellsites + Cult + SoftLin + HardLin",
  "pcount ~ Climate + Productive + Nonproductive + Other + Alien + SoftLin",
  "pcount ~ Climate + Blowout + ClaySub + Loamy + RapidDrain + SandyLoam + ThinBreak  + Other + UrbInd + Wellsites + Crop + TameP + RoughP + EnSoftLin + EnSeismic + TrSoftLin + HardLin + paspen",
  "pcount ~ Climate + Blowout + ClaySubThin + Loamy + SandyRapid +  Other +  UrbInd + Wellsites + Crop + TameP + RoughP + EnSoftLin + EnSeismic + TrSoftLin + HardLin + paspen",
  "pcount ~ Climate + Productive + Nonproductive + Other + UrbInd + Wellsites + Crop + TameP + RoughP + EnSoftLin + EnSeismic + TrSoftLin + HardLin + paspen",
  "pcount ~ Climate + Blowout + ClaySub + Loamy +RapidDrain + SandyLoam + ThinBreak  + Other + UrbIndWellsites + Crop + Pasture + SoftLin + HardLin + paspen",
  "pcount ~ Climate + Blowout + ClaySubThin + Loamy + SandyRapid + Other + UrbIndWellsites + Crop + Pasture + SoftLin + HardLin + paspen",
  "pcount ~ Climate + Productive + Nonproductive + Other + UrbIndWellsites + Crop + Pasture + SoftLin + HardLin + paspen",
  "pcount ~ Climate + Productive + Nonproductive + Other + UrbIndWellsites + Cult + SoftLin + HardLin + paspen",
  "pcount ~ Climate + Productive + Nonproductive + Other + Alien + SoftLin + paspen"
)

soil.models <- build_models(soil.model.text)

## 2.6 Check the models against the prediction matrices ----
# Every habitat term is predicted onto a column of its prediction
# matrix after fitting, so a term with no column cannot be
# predicted. In v2 that surfaced as `object '<term>' not found`
# raised inside every bootstrap of every species.
pm_source_note <- paste0(
  "\nThe matrices in ", data_dir, "/lookup/ are written from ",
  "the\nsnapshot's veg.pm and soil.pm. The v2 scripts instead ",
  "read\nveg-prediction-matrix-CC_2024.csv and\n",
  "soil-prediction-matrix_2024.csv from the v2 project, which\n",
  "carry the aggregate habitat columns the snapshot copies do\n",
  "not. Set SDM_V2_LOOKUP to the folder holding those two files\n",
  "and re-run 1_code/_setup/01_harmonize_model_ready_v2.R."
)

check_prediction_terms(
  vegetation.models, veg.prediction.matrix, "vegetation",
  pm_source_note
)

check_prediction_terms(
  soil.models, soil.prediction.matrix, "soil", pm_source_note
)

## 2.7 Define the coefficient templates ----
# The vegetation template is the 87 habitat types, named by
# load_model_data.R rather than taken positionally.
veg.coef.names <- c(coef_prefix, model_data$veg_coef_names)
veg.coef.template <- rep(NA, length(veg.coef.names))
names(veg.coef.template) <- veg.coef.names

soil.coef.names <- c(
  "paspen",
  "Loamy",
  "SandyLoam",
  "ClaySub",
  "RapidDrain",
  "Blowout",
  "ThinBreak",
  "Other",
  "EnSeismic",
  "EnSoftLin",
  "TrSoftLin",
  "HardLin",
  "UrbInd",
  "Wellsites",
  "Crop",
  "TameP",
  "RoughP"
)

soil.coef.template.names <- c(coef_prefix, soil.coef.names)
soil.coef.template <- rep(
  NA, length(soil.coef.template.names)
)
names(soil.coef.template) <- soil.coef.template.names

# 3. Fit the climate models ----
# Run over every bootstrap iteration on the spatially thinned
# data. The fitted climate coefficients feed both habitat model
# sets, so this section runs first.

## 3.1 Define cores and objects for parallel processing ----
core.input <- makeCluster(n_clusters)
clusterExport(
  core.input,
  c("climate.data", "species.list", "bootstrap.ids",
    "climate.models", "bioclim.models", "space.models",
    "boot_iter", "climate_models")
)
clusterEvalQ(core.input, {

  # Load relevant libraries
  library(AICcmodavg) # Model averaging
  library(arm) # Allows for the use of bayesglm function
  library(binom) # For exact binomial confidence intervals
  library(mapproj) # For projected maps
  library(mgcv) # For binomial GAM
  library(MuMIn)
  library(pROC)
  library(RcmdrMisc)

})

## 3.2 Loop through each species ----
climate.coef <- foreach(species = species.list) %dopar%

  t(parSapply(
    core.input,
    as.list(boot_iter),
    FUN = function(boot) {
      tryCatch(
        climate_models(
          species = species,
          data = climate.data,
          boot.data = bootstrap.ids,
          climate.models = climate.models,
          bioclim.models = bioclim.models,
          space.models = space.models,
          boot = boot
        ),
        error = function(e) e
      )
    }
  ))

names(climate.coef) <- species.list

stopCluster(core.input)

# 4. Fit the vegetation models ----
# The north model set, fitted for veg.species.list.

## 4.1 Define cores and objects for parallel processing ----
# use_protocol is read inside the worker closure, so it has to be
# exported. v2 passed a literal TRUE or FALSE and did not.
core.input <- makeCluster(n_clusters)
clusterExport(
  core.input,
  c("veg.data", "species.list", "bootstrap.ids",
    "vegetation.models", "veg.prediction.matrix", "climate.coef",
    "boot_iter", "veg.coef.template", "use_protocol",
    "vegetation_models")
)
clusterEvalQ(core.input, {

  # Load relevant libraries
  library(AICcmodavg) # Model averaging
  library(arm) # Allows for the use of bayesglm function
  library(binom) # For exact binomial confidence intervals
  library(mapproj) # For projected maps
  library(mgcv) # For binomial GAM
  library(MuMIn)
  library(pROC)
  library(RcmdrMisc)

})

## 4.2 Loop through each species ----
vegetation.coef <- foreach(species = veg.species.list) %dopar%

  t(parSapply(
    core.input,
    as.list(boot_iter),
    FUN = function(boot) {
      tryCatch(
        vegetation_models(
          species = species,
          data = veg.data,
          boot.data = bootstrap.ids,
          habitat.models = vegetation.models,
          prediction.matrix = veg.prediction.matrix,
          climate.coef = climate.coef,
          coef.template = veg.coef.template,
          weight.method = "IVW",
          coef.adjust = TRUE,
          protocol.flag = use_protocol,
          boot = boot
        ),
        error = function(e) e
      )
    }
  ))

names(vegetation.coef) <- veg.species.list

stopCluster(core.input)

# 5. Fit the soil models ----
# The south model set, fitted for soil.species.list. A species
# can be common enough to model in one region and not the other,
# so the two lists differ.

## 5.1 Define cores and objects for parallel processing ----
core.input <- makeCluster(n_clusters)
clusterExport(
  core.input,
  c("soil.data", "species.list", "bootstrap.ids", "soil.models",
    "soil.prediction.matrix", "climate.coef", "boot_iter",
    "soil.coef.template", "use_protocol", "soil_models")
)
clusterEvalQ(core.input, {

  # Load relevant libraries
  library(AICcmodavg) # Model averaging
  library(arm) # Allows for the use of bayesglm function
  library(binom) # For exact binomial confidence intervals
  library(mapproj) # For projected maps
  library(mgcv) # For binomial GAM
  library(MuMIn)
  library(pROC)
  library(RcmdrMisc)

})

## 5.2 Loop through each species ----
soil.coef <- foreach(species = soil.species.list) %dopar%

  t(parSapply(
    core.input,
    as.list(boot_iter),
    FUN = function(boot) {
      tryCatch(
        soil_models(
          species = species,
          data = soil.data,
          boot.data = bootstrap.ids,
          habitat.models = soil.models,
          prediction.matrix = soil.prediction.matrix,
          climate.coef = climate.coef,
          coef.template = soil.coef.template,
          weight.method = "IVW",
          coef.adjust = TRUE,
          protocol.flag = use_protocol,
          boot = boot
        ),
        error = function(e) e
      )
    }
  ))

names(soil.coef) <- soil.species.list

stopCluster(core.input)

# 6. Save the results from all three model sets ----
models_path <- file.path(
  run_dir, "models", paste0(taxon, "-species-models.Rdata")
)

save(climate.coef, soil.coef, vegetation.coef, file = models_path)

cat("Wrote ", models_path, "\n", sep = "")

# End of script ----
