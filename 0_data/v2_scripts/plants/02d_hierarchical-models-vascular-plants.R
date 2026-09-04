# ---
# title: "ABMI Heirachical Models (Vascular Plants)"
# author: "Brandon Allen"
# created: "2024-12-16"
# inputs: ["0_data/species/processed/vascular-plant-model-data.Rdata";
#          "0_data/bootstrap/vascular-plant-bootstrap-ids.Rdata";
#          "1_code/r-scripts/hierarchical-model_functions.R"]
# outputs: ["3_output/models/vascular-plant-species-models.Rdata"]
# notes: 
#   "This script generates the bootstrap species distribution models for vascular plants"
# --- 
#

# 1.0 Load libraries, functions, and cleaned data ----
rm(list=ls())
gc()

library(foreach)
library(parallel)
source("1_code/r-scripts/hierarchical-model_functions.R")
load("0_data/species/processed/vascular-plant-model-data.Rdata")
load("0_data/bootstrap/vascular-plant-bootstrap-ids.Rdata")

# Define species names and bootstrap iterations
species.list <- unique(c(veg.species.list, soil.species.list))
boot.iter <- 1:100

# 2.0 Climate models ----
# These are run for the 100 bootstrap iterations based on the spatially thinned data

# 2.1 Define climate models ----
climate.models <- list(as.formula(paste("pcount ~ 1")),
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
                       as.formula(paste("pcount ~ TD + FFP + MAT")))

bioclim.models <- list(as.formula(paste(".~.+ bio9 + bio15")))

# 2.2 Define spatial models ----
space.models <- list(as.formula(paste(".~.+ Easting + Northing")),
                     as.formula(paste(".~.+ Easting + Northing + EastingNorthing")),
                     as.formula(paste(".~.+ Easting + Northing + Easting2 + Northing2 + EastingNorthing")))

# 2.3 Define cores and objects for parallel processing ----
n.clusters <- 14
core.input <- makeCluster(n.clusters)
clusterExport(core.input, c("climate.data", "species.list", "bootstrap.ids", 
                            "climate.models", "bioclim.models", "space.models", "boot.iter", 
                            "climate_models"))
clusterEvalQ(core.input, {
            
            # Load relevant libraries
            library(AICcmodavg) # Model averaging
            library(arm) # Allows for the use of bayesglm function
            library(binom)  # For exact binomial confidence intervals
            library(mapproj)  # For projected maps
            library(mgcv)  # For binomial GAM
            library(MuMIn)
            library(pROC)
            library(RcmdrMisc)
            
})

# 3.4 Loop through each species ----
climate.coef <- foreach(species = species.list) %dopar% 
            
            t(parSapply(core.input, 
                        as.list(boot.iter),
                        FUN = function(boot) tryCatch(climate_models(species = species,
                                                                     data = climate.data, 
                                                                     boot.data = bootstrap.ids,
                                                                     climate.models = climate.models,
                                                                     bioclim.models = bioclim.models,
                                                                     space.models = space.models,
                                                                     boot = boot), error = function(e) e)
            ))

names(climate.coef) <- species.list

stopCluster(core.input)

# 3.0 Vegetation models ----
# These are run for the 100 bootstrap iterations based on the spatially thinned data

# 3.1 Define prediction matrix ----
prediction.matrix <- read.csv("0_data/lookup/prediction-matrix/veg-prediction-matrix-CC_2024.csv")
rownames(prediction.matrix) <- prediction.matrix$VegType
prediction.matrix <- prediction.matrix[, -1]

# 3.2 Define vegetation models ----
vegetation.models <- list(as.formula(paste("pcount ~ Climate + WhiteSpruce + Pine + Deciduous + Mixedwood + BlackSpruce + TreedFen + TreedSwamp + GraminoidFen + ShrubbyFen + ShrubbyBog + ShrubbySwamp + Marsh + Grass + Shrub + CCWhiteSpruceR + CCWhiteSpruce1 + CCWhiteSpruce234 + CCPineR + CCPine1234 + CCDecidMixedR + CCDecidMixed1 + CCDecidMixed234 + HardLin + EnSeismic + EnSoftLin + TrSoftLin + UrbInd + Wellsites + Crop + RoughP + TameP")),
                          as.formula(paste("pcount ~ Climate + WhiteSpruce + Pine + Deciduous + Mixedwood + Peatland + Mineral + Grass + Shrub + CCWhiteSpruceR + CCWhiteSpruce1 + CCWhiteSpruce234 + CCPineR + CCPine1234 + CCDecidMixedR + CCDecidMixed1 + CCDecidMixed234 + HardLin + EnSeismic + EnSoftLin + TrSoftLin + UrbInd + Wellsites + Crop + RoughP + TameP")),
                          as.formula(paste("pcount ~ Climate + WhiteSpruce + Pine + Deciduous + Mixedwood + Bog + TreedFen + + NonTreedFen + TreedSwamp + ShrubbySwamp + Marsh + Grass + Shrub + CCWhiteSpruceR + CCWhiteSpruce1 + CCWhiteSpruce234 + CCPineR + CCPine1234 + CCDecidMixedR + CCDecidMixed1 + CCDecidMixed234 + HardLin + EnSeismic + EnSoftLin + TrSoftLin + UrbInd + Wellsites + Crop + RoughP + TameP")),
                          as.formula(paste("pcount ~ Climate + WhiteSpruce + Pine + Deciduous + Mixedwood + Bog + Fen + TreedSwamp + ShrubbySwamp + Marsh + Grass + Shrub + CCWhiteSpruceR + CCWhiteSpruce1 + CCWhiteSpruce234 + CCPineR + CCPine1234 + CCDecidMixedR + CCDecidMixed1 + CCDecidMixed234 + HardLin + EnSeismic + EnSoftLin + TrSoftLin + UrbInd + Wellsites + Crop + RoughP + TameP")),
                          as.formula(paste("pcount ~ Climate + WhiteSpruce + Pine + Deciduous + Mixedwood + Bog + Fen + Swamp + Marsh + GrassShrub + CCWhiteSprucePineR + CCWhiteSprucePine1 + CCWhiteSprucePine234 + CCDecidMixedR + CCDecidMixed1 + CCDecidMixed234 + HardLin + SoftLin + UrbInd + Wellsites + Crop + RoughP + TameP")),
                          as.formula(paste("pcount ~ Climate + WhiteSpruce + Pine + Deciduous + Mixedwood + Peatland + Mineral + GrassShrub + CCWhiteSprucePineR1234 + CCDecidMixedR1234 + HardLin + SoftLin + UrbIndWellsites + Crop + Pasture")),
                          as.formula(paste("pcount ~ Climate + WhiteSpruce + Pine + Deciduous + Mixedwood + Lowland + GrassShrub + CCWhiteSprucePineR1234 + CCDecidMixedR1234 + SoftLin + Alien")),
                          as.formula(paste("pcount ~ Climate + Upland + BlackSpruce + TreedFen + TreedSwamp + GraminoidFen + ShrubbyFen + ShrubbyBog + ShrubbySwamp + Marsh + Grass + Shrub + CCR1234 + HardLin + EnSeismic + EnSoftLin + TrSoftLin + UrbInd + Wellsites + Crop + RoughP + TameP")),
                          as.formula(paste("pcount ~ Climate + Upland + Bog + Fen + Swamp + Marsh + Grass + Shrub + CCR1234 + HardLin + EnSeismic + EnSoftLin + TrSoftLin + UrbInd + Wellsites + Crop + RoughP + TameP")),
                          as.formula(paste("pcount ~ Climate + Upland + Peatland + Swamp + Marsh + GrassShrub + CCR1234 + HardLin + SoftLin + UrbInd + Wellsites + Crop + RoughP + TameP")),
                          as.formula(paste("pcount ~ Climate + Upland + Peatland + Mineral + GrassShrub + CCR1234 + HardLin + SoftLin + UrbIndWellsites + Crop + Pasture")),
                          as.formula(paste("pcount ~ Climate + Upland + Lowland + GrassShrub + CCR1234 + SoftLin + Alien"))
                       )

# 3.3 Define vegetation coefficients ----
coef.names <- c("Intercept", "Climate", colnames(veg.data)[1408:1494])
coef.template <- rep(NA, length(coef.names))
names(coef.template) <- coef.names

# 3.4 Define cores and objects for parallel processing ----
n.clusters <- 14
core.input <- makeCluster(n.clusters)
clusterExport(core.input, c("veg.data", "species.list", "bootstrap.ids", "vegetation.models", 
                            "prediction.matrix", "climate.coef", "boot.iter", 
                            "coef.template", "vegetation_models"))
clusterEvalQ(core.input, {
            
            # Load relevant libraries
            library(AICcmodavg) # Model averaging
            library(arm) # Allows for the use of bayesglm function
            library(binom)  # For exact binomial confidence intervals
            library(mapproj)  # For projected maps
            library(mgcv)  # For binomial GAM
            library(MuMIn)
            library(pROC)
            library(RcmdrMisc)
            
})

# 3.5 Loop through each species ----
vegetation.coef <- foreach(species = veg.species.list) %dopar% 
            
            t(parSapply(core.input, 
                        as.list(boot.iter),
                        FUN = function(boot) tryCatch(vegetation_models(species = species,
                                                                        data = veg.data, 
                                                                        boot.data = bootstrap.ids,
                                                                        habitat.models = vegetation.models,
                                                                        prediction.matrix = prediction.matrix,
                                                                        climate.coef = climate.coef,
                                                                        coef.template = coef.template,
                                                                        weight.method = "IVW",
                                                                        coef.adjust = TRUE,
                                                                        protocol.flag = FALSE,
                                                                        boot = boot), error = function(e) e)
            ))

names(vegetation.coef) <- veg.species.list

stopCluster(core.input)

# 4.0 Soil models ----
# These are run for the 100 bootstrap iterations based on the spatially thinned data

# 4.1 Define prediction matrix ----
prediction.matrix <- read.csv("0_data/lookup/prediction-matrix/soil-prediction-matrix_2024.csv")
rownames(prediction.matrix) <- prediction.matrix$VegType
prediction.matrix <- prediction.matrix[, -1]

# 4.2 Define the soil models ----
soil.models <- list(as.formula(paste("pcount ~ Climate + Blowout + ClaySub + Loamy + RapidDrain + SandyLoam + ThinBreak + Other + UrbInd + Wellsites + Crop + TameP + RoughP + EnSoftLin + EnSeismic + TrSoftLin + HardLin")),
                       as.formula(paste("pcount ~ Climate + Blowout + ClaySubThin + Loamy + SandyRapid + Other +  UrbInd+ Wellsites + Crop + TameP + RoughP + EnSoftLin + EnSeismic + TrSoftLin + HardLin")),
                       as.formula(paste("pcount ~ Climate + Productive + Nonproductive + Other + UrbInd + Wellsites + Crop + TameP + RoughP + EnSoftLin + EnSeismic + TrSoftLin + HardLin")),
                       as.formula(paste("pcount ~ Climate + Blowout + ClaySub + Loamy + RapidDrain + SandyLoam + ThinBreak  + Other + UrbIndWellsites + Crop + Pasture + SoftLin + HardLin")),
                       as.formula(paste("pcount ~ Climate + Blowout + ClaySubThin + Loamy + SandyRapid + Other + UrbIndWellsites + Crop + Pasture + SoftLin + HardLin")),
                       as.formula(paste("pcount ~ Climate + Productive + Nonproductive + Other + UrbIndWellsites + Crop + Pasture + SoftLin + HardLin")),
                       as.formula(paste("pcount ~ Climate + Productive + Nonproductive + Other + UrbIndWellsites + Cult + SoftLin + HardLin")),
                       as.formula(paste("pcount ~ Climate + Productive + Nonproductive + Other + Alien + SoftLin")),
                       as.formula(paste("pcount ~ Climate + Blowout + ClaySub + Loamy + RapidDrain + SandyLoam + ThinBreak  + Other + UrbInd + Wellsites + Crop + TameP + RoughP + EnSoftLin + EnSeismic + TrSoftLin + HardLin + paspen")),
                       as.formula(paste("pcount ~ Climate + Blowout + ClaySubThin + Loamy + SandyRapid +  Other +  UrbInd + Wellsites + Crop + TameP + RoughP + EnSoftLin + EnSeismic + TrSoftLin + HardLin + paspen")),
                       as.formula(paste("pcount ~ Climate + Productive + Nonproductive + Other + UrbInd + Wellsites + Crop + TameP + RoughP + EnSoftLin + EnSeismic + TrSoftLin + HardLin + paspen")),
                       as.formula(paste("pcount ~ Climate + Blowout + ClaySub + Loamy +RapidDrain + SandyLoam + ThinBreak  + Other + UrbIndWellsites + Crop + Pasture + SoftLin + HardLin + paspen")),
                       as.formula(paste("pcount ~ Climate + Blowout + ClaySubThin + Loamy + SandyRapid + Other + UrbIndWellsites + Crop + Pasture + SoftLin + HardLin + paspen")),
                       as.formula(paste("pcount ~ Climate + Productive + Nonproductive + Other + UrbIndWellsites + Crop + Pasture + SoftLin + HardLin + paspen")),
                       as.formula(paste("pcount ~ Climate + Productive + Nonproductive + Other + UrbIndWellsites + Cult + SoftLin + HardLin + paspen")),
                       as.formula(paste("pcount ~ Climate + Productive + Nonproductive + Other + Alien + SoftLin + paspen")))

# 4.3 Define soil coefficients ----
coef.names <- c("Intercept", "Climate", "paspen", "Loamy", "SandyLoam", "ClaySub", "RapidDrain",
                "Blowout", "ThinBreak", "Other", "EnSeismic",
                "EnSoftLin", "TrSoftLin", "HardLin", "UrbInd",
                "Wellsites", "Crop", "TameP", "RoughP")
coef.template <- rep(NA, length(coef.names))
names(coef.template) <- coef.names

# 4.4 Define cores and objects for parallel processing ----
n.clusters <- 14
core.input <- makeCluster(n.clusters)
clusterExport(core.input, c("soil.data", "species.list", "bootstrap.ids", "soil.models", 
                            "prediction.matrix", "climate.coef", "boot.iter", 
                            "coef.template", "soil_models"))
clusterEvalQ(core.input, {
            
            # Load relevant libraries
            library(AICcmodavg) # Model averaging
            library(arm) # Allows for the use of bayesglm function
            library(binom)  # For exact binomial confidence intervals
            library(mapproj)  # For projected maps
            library(mgcv)  # For binomial GAM
            library(MuMIn)
            library(pROC)
            library(RcmdrMisc)
            
})

# 4.5 Loop through each species ----
soil.coef <- foreach(species = soil.species.list) %dopar% 
            
            t(parSapply(core.input, 
                        as.list(boot.iter),
                        FUN = function(boot) tryCatch(soil_models(species = species,
                                                                  data = soil.data, 
                                                                  boot.data = bootstrap.ids,
                                                                  habitat.models = soil.models,
                                                                  prediction.matrix = prediction.matrix,
                                                                  climate.coef = climate.coef,
                                                                  coef.template = coef.template,
                                                                  weight.method = "IVW",
                                                                  coef.adjust = TRUE,
                                                                  protocol.flag = FALSE,
                                                                  boot = boot), error = function(e) e)
            ))

names(soil.coef) <- soil.species.list

stopCluster(core.input)

# 5.0 Save the results from all three sets of models ----
save(climate.coef, soil.coef, vegetation.coef, file = "3_output/models/vascular-plant-species-models.Rdata")

# Clear memory
rm(list=ls())
gc()
