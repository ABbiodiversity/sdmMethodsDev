
# ---
# title: "Bootstrap generation"
# author: "Brandon Allen"
# created: "2024-12-16"
# inputs: ["0_data/species/processed/bryophyte-model-data.Rdata";
#           "0_data/species/processed/lichen-model-data.Rdata";
#           "0_data/species/processed/vascular-plant-model-data.Rdata";
#           "0_data/species/processed/mite-model-data.Rdata"]
# outputs: ["0_data/species/processed/bryophyte-model-data.Rdata";
#           "0_data/species/processed/lichen-model-data.Rdata";
#           "0_data/species/processed/vascular-plant-model-data.Rdata";
#           "0_data/species/processed/mite-model-data.Rdata"]
# notes: 
#   "This script generates the list of bootstrap ids that will be used for the climate,
#    vegetation and soil based models. This process only needs to be completed once prior
#    to running the models. In addition, as we have a pre-generated list of species from Ermias,
#    we are only considering the bootstrap process for that subset."
# ---

# 1.0 Bryophytes ----
rm(list=ls())
gc()

# 1.1 Load libraries, source functions, and data sets
library(foreach)
library(parallel)
source("1_code/r-scripts/bootstrapping_functions.R")
load("0_data/species/processed/bryophyte-model-data.Rdata")

# 1.2 Define the bootstrap blocks for sampling
site.block <- data.frame(LongBlock = cut(climate.data$Long, c(-121, -116, -112,-109)),
                         LatBlock = cut(climate.data$Lat, c(48, 51, 54, 57, 61)))
site.block$Block <- interaction(droplevels(site.block$LongBlock), droplevels(site.block$LatBlock), sep="::", drop=TRUE)

# Reclassify
reclass.site <- data.frame(Orig = unique(site.block$Block),
                           Update = letters[1:length(unique(site.block$Block))])
climate.data$Block <- reclass.site$Update[match(site.block$Block, reclass.site$Orig)]

rm(site.block, reclass.site)

# 1.3 Generate the cluster required for bootstrapping
species.list <- unique(c(veg.species.list, soil.species.list))
boot.iter <- 1:100

# Define the cores and objects required for for parallel processing
n.clusters <- 16
core.input <- makeCluster(n.clusters)
clusterExport(core.input, c("climate.data", "species.list", "boot.iter",
                            "bootstrap_data"))
clusterEvalQ(core.input, {
    
    
})

# 1.4 Generate the bootstrap ids, simplify to array and save
bootstrap.list <- foreach(species = species.list) %dopar% 
    
    parSapply(core.input, 
              as.list(boot.iter),
              FUN = function(boot) tryCatch(bootstrap_data(data = climate.data,
                                                           species = species,
                                                           threshold = 20,
                                                           boot = boot), error = function(e) e)
    )

names(bootstrap.list) <- species.list
stopCluster(core.input)
bootstrap.ids <- list()

for(species in species.list) {
    
    bootstrap.ids[[species]] <- simplify2array(bootstrap.list[[species]])
 
}

save(bootstrap.ids, file = "0_data/bootstrap/bryophyte-bootstrap-ids.Rdata")

# 2.0 Lichens ----
rm(list=ls())
gc()

# 2.1 Load libraries, source functions, and data sets
library(foreach)
library(parallel)
source("1_code/r-scripts/bootstrapping_functions.R")
load("0_data/species/processed/lichen-model-data.Rdata")

# 1.2 Define the bootstrap blocks for sampling
site.block <- data.frame(LongBlock = cut(climate.data$Long, c(-121, -116, -112,-109)),
                         LatBlock = cut(climate.data$Lat, c(48, 51, 54, 57, 61)))
site.block$Block <- interaction(droplevels(site.block$LongBlock), droplevels(site.block$LatBlock), sep="::", drop=TRUE)

# Reclassify
reclass.site <- data.frame(Orig = unique(site.block$Block),
                           Update = letters[1:length(unique(site.block$Block))])
climate.data$Block <- reclass.site$Update[match(site.block$Block, reclass.site$Orig)]

rm(site.block, reclass.site)

# 2.3 Generate the cluster required for bootstrapping
species.list <- unique(c(veg.species.list, soil.species.list))
boot.iter <- 1:100

# Define the cores and objects required for for parallel processing
n.clusters <- 16
core.input <- makeCluster(n.clusters)
clusterExport(core.input, c("climate.data", "species.list", "boot.iter",
                            "bootstrap_data"))
clusterEvalQ(core.input, {
    
    
})

# 2.4 Generate the bootstrap ids, simplify to array and save
bootstrap.list <- foreach(species = species.list) %dopar% 
    
    parSapply(core.input, 
              as.list(boot.iter),
              FUN = function(boot) tryCatch(bootstrap_data(data = climate.data,
                                                           species = species,
                                                           threshold = 20,
                                                           boot = boot), error = function(e) e)
    )

names(bootstrap.list) <- species.list
stopCluster(core.input)
bootstrap.ids <- list()

for(species in species.list) {
    
    bootstrap.ids[[species]] <- simplify2array(bootstrap.list[[species]])

}

save(bootstrap.ids, file = "0_data/bootstrap/lichen-bootstrap-ids.Rdata")

# 3.0 Vascular Plants ----
rm(list=ls())
gc()

# 3.1 Load libraries, source functions, and data sets
library(foreach)
library(parallel)
source("1_code/r-scripts/bootstrapping_functions.R")
load("0_data/species/processed/vascular-plant-model-data.Rdata")

# 3.2 Define the bootstrap blocks for sampling
site.block <- data.frame(LongBlock = cut(climate.data$Long, c(-121, -116, -112,-109)),
                         LatBlock = cut(climate.data$Lat, c(48, 51, 54, 57, 61)))
site.block$Block <- interaction(droplevels(site.block$LongBlock), droplevels(site.block$LatBlock), sep="::", drop=TRUE)

# Reclassify
reclass.site <- data.frame(Orig = unique(site.block$Block),
                           Update = letters[1:length(unique(site.block$Block))])
climate.data$Block <- reclass.site$Update[match(site.block$Block, reclass.site$Orig)]

rm(site.block, reclass.site)

# 3.3 Generate the cluster required for bootstrapping
species.list <- unique(c(veg.species.list, soil.species.list))
boot.iter <- 1:100

# Define the cores and objects required for for parallel processing
n.clusters <- 16
core.input <- makeCluster(n.clusters)
clusterExport(core.input, c("climate.data", "species.list", "boot.iter",
                            "bootstrap_data"))
clusterEvalQ(core.input, {
    
    
})

# 3.4 Generate the bootstrap ids, simplify to array and save
bootstrap.list <- foreach(species = species.list) %dopar% 
    
    parSapply(core.input, 
              as.list(boot.iter),
              FUN = function(boot) tryCatch(bootstrap_data(data = climate.data,
                                                           species = species,
                                                           threshold = 20,
                                                           boot = boot), error = function(e) e)
    )

names(bootstrap.list) <- species.list
stopCluster(core.input)
bootstrap.ids <- list()

for(species in species.list) {
    
    bootstrap.ids[[species]] <- simplify2array(bootstrap.list[[species]])

}

save(bootstrap.ids, file = "0_data/bootstrap/vascular-plant-bootstrap-ids.Rdata")

# 4.0 Mites ----
rm(list=ls())
gc()

# 4.1 Load libraries, source functions, and data sets
library(foreach)
library(parallel)
source("1_code/r-scripts/bootstrapping_functions.R")
load("0_data/species/processed/mite-model-data.Rdata")

# 4.2 Define the bootstrap blocks for sampling
site.block <- data.frame(LongBlock = cut(climate.data$Long, c(-121, -116, -112,-109)),
                         LatBlock = cut(climate.data$Lat, c(48, 51, 54, 57, 61)))
site.block$Block <- interaction(droplevels(site.block$LongBlock), droplevels(site.block$LatBlock), sep="::", drop=TRUE)

# Reclassify
reclass.site <- data.frame(Orig = unique(site.block$Block),
                           Update = letters[1:length(unique(site.block$Block))])
climate.data$Block <- reclass.site$Update[match(site.block$Block, reclass.site$Orig)]

rm(site.block, reclass.site)

# 4.3 Generate the cluster required for bootstrapping
species.list <- unique(c(veg.species.list, soil.species.list))
boot.iter <- 1:100

# Define the cores and objects required for for parallel processing
n.clusters <- 16
core.input <- makeCluster(n.clusters)
clusterExport(core.input, c("climate.data", "species.list", "boot.iter",
                            "bootstrap_data"))
clusterEvalQ(core.input, {
    
    
})

# 4.4 Generate the bootstrap ids, simplify to array and save
bootstrap.list <- foreach(species = species.list) %dopar% 
    
    parSapply(core.input, 
              as.list(boot.iter),
              FUN = function(boot) tryCatch(bootstrap_data(data = climate.data,
                                                           species = species,
                                                           threshold = 20,
                                                           boot = boot), error = function(e) e)
    )

names(bootstrap.list) <- species.list
stopCluster(core.input)
bootstrap.ids <- list()

for(species in species.list) {
    
    bootstrap.ids[[species]] <- simplify2array(bootstrap.list[[species]])

}

save(bootstrap.ids, file = "0_data/bootstrap/mite-bootstrap-ids.Rdata")

rm(list=ls())
gc()
