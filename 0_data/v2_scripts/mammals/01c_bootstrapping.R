#
# Title: Bootstrapping
# Created: July 5th, 2024
# Last Updated: July 5th, 2024
# Author: Brandon Allen
# Objective: Create the site list for the bootstrap iterations. 
# Keywords: Bootstrap
# Notes: 
#
#############
# Bootstrap # 
#############~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Clear memory
rm(list=ls())
gc()

# Load libraries for parallel processing
library(foreach)
library(parallel)

# Source functions
source("src/bootstrapping_functions.R")

# Load species, landcover, and climate data
load("data/processed/site/amphibian-model-data.Rdata")

###########################
# Define bootstrap blocks #
###########################

site.block <- data.frame(LongBlock = cut(climate.data$Longitude, c(-121, -116, -112,-109)),
                         LatBlock = cut(climate.data$Latitude, c(48, 51, 54, 57, 61)))
site.block$Block <- interaction(droplevels(site.block$LongBlock), droplevels(site.block$LatBlock), sep="::", drop=TRUE)

# Reclassify
reclass.site <- data.frame(Orig = unique(site.block$Block),
                           Update = letters[1:length(unique(site.block$Block))])
climate.data$Block <- reclass.site$Update[match(site.block$Block, reclass.site$Orig)]

rm(site.block, reclass.site)

##############################
# Perform bootstrap sampling #
##############################

# Define species list and number of bootstraps
species.list <- c("BCFR", "CATO", "WETO", "WOFR")
boot.iter <- 1:100

# Define the cores and objects required for for parallel processing
n.clusters <- 14
core.input <- makeCluster(n.clusters)
clusterExport(core.input, c("climate.data", "species.list", "boot.iter",
                            "bootstrap_data"))
clusterEvalQ(core.input, {

            
})

# Loop through each species
bootstrap.ids <- foreach(species = species.list) %dopar% 
            
            parSapply(core.input, 
                      as.list(boot.iter),
                      FUN = function(boot) tryCatch(bootstrap_data(data = climate.data,
                                                                   species = species,
                                                                   boot = boot), error = function(e) e)
            )

names(bootstrap.ids) <- species.list

stopCluster(core.input)

# Save the results
save(bootstrap.ids, file = "data/processed/bootstrap/bootstrap-ids.Rdata")

# Clear memory
rm(list=ls())
gc()