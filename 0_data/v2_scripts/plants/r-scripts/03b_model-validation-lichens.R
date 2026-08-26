# ---
# title: "Model Validation (Lichens)"
# author: "Brandon Allen"
# created: "2025-03-17"
# inputs: ["0_data/species/processed/lichen-model-data.Rdata";
#          "0_data/bootstrap/lichen-bootstrap-ids.Rdata";
#          "3_output/models/lichen-species-models.Rdata";
#          "1_code/r-scripts/model-validation_functions.R"]
# outputs: ["3_output/tables/lichen-models-validation.Rdata"]
# notes: 
#   "This script performs model validation checks (e.g., AUC, prediction methods, etc) 
#    for the lichen species models."
# ---

# 1.0 Environment initialization ----
rm(list=ls())
gc()

# 1.1 load libraries and source functions and data ----
library(foreach)
library(parallel)
source("1_code/r-scripts/model-validation_functions.R")
load("0_data/species/processed/lichen-model-data.Rdata")
load("0_data/bootstrap/lichen-bootstrap-ids.Rdata")
load("3_output/models/lichen-species-models.Rdata")

# 1.2 Define bootstrap iterations ----
species.list <- names(climate.coef)
veg.species.list <- names(vegetation.coef)
soil.species.list <- names(soil.coef)
boot.iter <- 1:100

# 1.3 Prepare coefficients for model fit evaluation and coefficient plots ----
# Remove standard error, NA values, and adjust to qlogis(0.001)
for(species in veg.species.list) {
    
    climate.coef[[species]][is.na(climate.coef[[species]])] <- qlogis(0.001)
    
    vegetation.coef[[species]][is.na(vegetation.coef[[species]])] <- qlogis(0.001)
    vegetation.coef[[species]] <- vegetation.coef[[species]][, -grep(".SE", colnames(vegetation.coef[[species]]))]
    
}

for(species in soil.species.list) {
    
    climate.coef[[species]][is.na(climate.coef[[species]])] <- qlogis(0.001)
    
    soil.coef[[species]][is.na(soil.coef[[species]])] <- qlogis(0.001)
    soil.coef[[species]] <- soil.coef[[species]][, -grep(".SE", colnames(soil.coef[[species]]))]
    
}

# 2.0 Vegetation Model Fit ----

# 2.1 Define cores and objects for parallel processing ----
n.clusters <- 14
core.input <- makeCluster(n.clusters)
clusterExport(core.input, c("veg.data","veg.species.list", "bootstrap.ids", 
                            "vegetation.coef", "climate.coef", 
                            "boot.iter", "model_validation"))
clusterEvalQ(core.input, {
    
    # Load relevant libraries
    library(pROC)
    
})

# 2.2 Loop through each species ----
vegetation.fit <- foreach(species = veg.species.list) %dopar% 
    
    t(parSapply(core.input, 
                as.list(boot.iter),
                FUN = function(boot) tryCatch(model_validation(species = species,
                                                               data = veg.data, 
                                                               boot.data = bootstrap.ids,
                                                               climate.coef = climate.coef,
                                                               landcover.coef = vegetation.coef,
                                                               landcover.type = "Vegetation", 
                                                               protocol.flag = TRUE,
                                                               boot = boot), error = function(e) e)
    ))

names(vegetation.fit) <- veg.species.list

stopCluster(core.input)

# 3.0 Soil Model Fit ----

# 3.1 Define cores and objects for parallel processing ----
n.clusters <- 14
core.input <- makeCluster(n.clusters)
clusterExport(core.input, c("soil.data", "soil.species.list", "bootstrap.ids", 
                            "soil.coef", "climate.coef", 
                            "boot.iter", "model_validation"))
clusterEvalQ(core.input, {
    
    # Load relevant libraries
    library(pROC)
    
})

# 3.2 Loop through each species ----
soil.fit <- foreach(species = soil.species.list) %dopar% 
    
    t(parSapply(core.input, 
                as.list(boot.iter),
                FUN = function(boot) tryCatch(model_validation(species = species,
                                                               data = soil.data, 
                                                               boot.data = bootstrap.ids,
                                                               climate.coef = climate.coef,
                                                               landcover.coef = soil.coef,
                                                               landcover.type = "Soil", 
                                                               protocol.flag = TRUE,
                                                               boot = boot), error = function(e) e)
    ))

names(soil.fit) <- soil.species.list

stopCluster(core.input)

# 4.0 Save results ----
save(vegetation.fit, soil.fit, file = "3_output/validation/lichen-models-validation.Rdata")

rm(list=ls())
gc()
