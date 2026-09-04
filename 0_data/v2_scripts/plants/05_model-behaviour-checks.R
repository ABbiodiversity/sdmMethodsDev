# ---
# title: "Model behaviour checks"
# author: "Brandon Allen"
# created: "2025-02-12"
# inputs: ["3_output/coefficients/COEFS.RData";
#          "0_data/previous-version/COEFS.RData";
#          "0_data/lookup/landcover/lookup-veg-hf-age-v2020.csv";
#          "0_data/lookup/landcover/lookup-soil-hf-v2020.csv";
#          "0_data/external/kgrid/backfillV7_w2w_2021HFI.Rdata";
#          "0_data/external/mapping/provincial-boundary.Rdata";
#          "0_data/external/kgrid/kgrid_2.2.Rdata"]
# outputs: ["3_output/figures/landscape-simulation.jpeg";]
#           "3_output/figures/maximum-habitat.jpeg"
# notes: 
#   "This script performs two checks of model behaviour.
#    1) If landcover coefficients are artificially set to 0, predictions for species habitat
#    suitability converge to 0 as the unsuitable habitat expands to take up the entire region.
#    2) If the current age distribution on the landscape changes, the maximum amount of suitable
#    habitat available to the species will occur when it landscape distribution aligns with the
#    habitat and age relationships of the species."
# ---

# 1.0 Environment initialization ----

# 1.1 Clear memory ----
rm(list=ls())
gc()

# 1.2 Load libraries and source functions ----
library(ggplot2)
library(ggnewscale)
library(ggpubr)
library(MetBrewer)
library(sf)
source("1_code/r-scripts/data-standardization_functions.R")

# 1.3 Load the landcover information landcover information ----
load("0_data/external/mapping/provincial-boundary.Rdata")
load("0_data/external/kgrid/kgrid_2.2.Rdata") 
load("0_data/external/kgrid/backfillV7_w2w_2021HFI.Rdata")
veg.lookup <- read.csv("0_data/lookup/landcover/lookup-veg-hf-age-v2020.csv")
soil.lookup <- read.csv("0_data/lookup/landcover/lookup-soil-hf-v2020.csv")

# 1.4 Load the coefficients
load("3_output/coefficients/COEFS.RData")

# 1.5 Define the link functions used for making predictions
inv.link <- binomial()$linkinv
link <- binomial()$linkfun

# 2.0 Landcover standardization ----

# 2.1 Clean landcover to the appropriate categories ----
veg.cur <- landscape_hf_summary(data.in = as.data.frame(as.matrix(d.wide$veg.reference)),
                                landscape.lookup = veg.lookup,
                                class.in = "ID", class.out = "UseInAnalysis_Simplified")


# 2.2 Convert each matrix to proportions ----
veg.cur <- as.data.frame(veg.cur)
veg.cur <- veg.cur / rowSums(veg.cur)
veg.cur$LinkID <- rownames(veg.cur)

# 2.3 Create the additional climate variables and landcover ----
kgrid$Easting2 <- kgrid$Easting * kgrid$Easting
kgrid$Northing2 <- kgrid$Northing * kgrid$Northing
kgrid$EastingNorthing <- kgrid$Easting * kgrid$Northing
kgrid$PET <- kgrid$Eref
kgrid$MAPPET <- kgrid$MAP * kgrid$PET
kgrid$MAT2 <- kgrid$MAT * kgrid$MAT
kgrid$CMDMAT <- kgrid$CMD * kgrid$MAT
kgrid$MWMT2 <- kgrid$MWMT * kgrid$MWMT
kgrid$Intercept <- 1

veg.cur$Crop <- 0

# 2.4 Merge Climate and landcover information ----
veg.cur <- merge.data.frame(kgrid, veg.cur, by = "LinkID")
rownames(veg.cur) <- as.character(veg.cur$LinkID)

# Clean up memory
rm(d.wide, soil.lookup, veg.lookup)

# 3.0 Response to unsuitable landcover coefficients ----
results <- list()
for(taxon in names(COEFS)) {
    
    # Subset taxonomic group
    new.veg.coef <- COEFS[[taxon]]$vegetation
    new.climate.coef <- COEFS[[taxon]]$climate
    
    results.template <- data.frame(Species = rep(rownames(new.veg.coef), 11),
                                   Proportion = c(rep(0, nrow(new.veg.coef)), rep(0.1, nrow(new.veg.coef)),
                                                  rep(0.2, nrow(new.veg.coef)), rep(0.3, nrow(new.veg.coef)),
                                                  rep(0.4, nrow(new.veg.coef)), rep(0.5, nrow(new.veg.coef)),
                                                  rep(0.6, nrow(new.veg.coef)), rep(0.7, nrow(new.veg.coef)),
                                                  rep(0.8, nrow(new.veg.coef)), rep(0.9, nrow(new.veg.coef)),
                                                  rep(1, nrow(new.veg.coef))),
                                   Total = NA)
    
    
    for(species in rownames(new.veg.coef)) {
        
        # New coefficients
        # Isolate the coefficients
        spp.clim <- new.climate.coef[species, , 1]
        spp.veg <- new.veg.coef[species, , 1]
        spp.veg <- spp.veg[names(spp.veg) %in% c("Climate", colnames(veg.cur))]
        
        # Assign Crop to -10000
        spp.veg["Crop"] <- -10000
        
        # Standardize the climate data
        climate.veg <- as.matrix(veg.cur[, names(spp.clim)])
        veg <- as.matrix(veg.cur[, names(spp.veg)[-1]])
        
        # Predict space/climate component
        climate.pred <- matrix(inv.link(drop(climate.veg %*% spp.clim)), ncol = 1,
                               dimnames = list(rownames(climate.veg), "Climate"))
        
        # Truncate climate prediction
        climate.pred.og <- ifelse(climate.pred >= quantile(climate.pred, 0.99),
                                  quantile(climate.pred, 0.99),
                                  climate.pred)
        
        # Use this to predict the joint climate contribution
        climate.pred <- (climate.pred.og * spp.veg["Climate"])
        
        # Using these prediction, create a matrix and get the climate adjusted veg coefficients
        climate.matrix <- matrix(climate.pred, nrow = nrow(veg), ncol = ncol(veg))
        
        # Align the coefficients and landcover information
        veg.coef <- spp.veg[colnames(veg)]
        
        # Joint climate prediction
        veg.coef <- t(t(climate.matrix) + veg.coef)
        
        # For each landscape scenario, create the prediction and sum
        for (percentage in c(0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1)) {
            
            veg.temp <- veg - (veg * percentage)
            veg.temp[, "Crop"] <- percentage
            
            results.template[results.template$Species == species & 
                                 results.template$Proportion == percentage, "Total"] <- sum(veg.temp * inv.link(veg.coef), na.rm = TRUE)

        }
        
        print(species)
        
    }
    
    results[[taxon]] <- results.template
    
}

save(results, file = "3_output/validation/unsuitable-landcover-simulation.Rdata")

# 1.1 Evaluate the correction ----
# Seems to look good upon quick glance
cor.results <- list()
for(taxon in names(results)) {
    
    species.results <- results[[taxon]]
    temp.results <- data.frame(Species = unique(species.results$Species),
                               Correlation  = NA)
    
    for (species in unique(species.results$Species)) {
        
        temp.data <- species.results[species.results$Species == species, ]
        temp.results[temp.results$Species == species, "Correlation"] <- cor(temp.data$Proportion, temp.data$Total)
        
    }
    
    cor.results[[taxon]] <- temp.results
    
}

# 4.0 Response to age relationships ----
results <- list()
for(taxon in names(COEFS)) {
    
    # Subset taxonomic group
    new.veg.coef <- COEFS[[taxon]]$vegetation
    new.climate.coef <- COEFS[[taxon]]$climate
    
    # Assuming if model behaviour will be consistent across stand types
    results.template <- data.frame(Species = sort(rep(rownames(new.veg.coef), 9)),
                                   Landcover = rep(c("WhiteSpruceR", "WhiteSpruce1",
                                                     "WhiteSpruce2", "WhiteSpruce3",
                                                     "WhiteSpruce4", "WhiteSpruce5", 
                                                     "WhiteSpruce6", "WhiteSpruce7",
                                                     "WhiteSpruce8"), nrow(new.veg.coef)), 
                                   Coefficient = NA,
                                   Total = NA)
    
    for(species in rownames(new.veg.coef)) {
        
        # New coefficients
        # Isolate the coefficients
        spp.clim <- new.climate.coef[species, , 1]
        spp.veg <- new.veg.coef[species, , 1]
        spp.veg <- spp.veg[names(spp.veg) %in% c("Climate", colnames(veg.cur))]
        
        # Standardize the climate data
        climate.veg <- as.matrix(veg.cur[, names(spp.clim)])
        veg <- as.matrix(veg.cur[, names(spp.veg)[-1]])
        
        # Predict space/climate component
        climate.pred <- matrix(inv.link(drop(climate.veg %*% spp.clim)), ncol = 1,
                               dimnames = list(rownames(climate.veg), "Climate"))
        
        # Truncate climate prediction
        climate.pred.og <- ifelse(climate.pred >= quantile(climate.pred, 0.99),
                                  quantile(climate.pred, 0.99),
                                  climate.pred)
        
        # Use this to predict the joint climate contribution
        climate.pred <- (climate.pred.og * spp.veg["Climate"])
        
        # Using these prediction, create a matrix and get the climate adjusted veg coefficients
        climate.matrix <- matrix(climate.pred, nrow = nrow(veg), ncol = ncol(veg))
        
        # Align the coefficients and landcover information
        veg.coef <- spp.veg[colnames(veg)]
        
        # Store the original coefficients
        results.template[results.template$Species == species, "Coefficient"] <- plogis(veg.coef[unique(results.template$Landcover)])
        
        # Calculate the landcover total for the target habitat type
        target.habitat <- rowSums(veg[, unique(results.template$Landcover)])
        
        # Joint climate prediction
        veg.coef <- t(t(climate.matrix) + veg.coef)
        
        # For each landscape scenario, create the prediction and sum
        for (landcover in unique(results.template$Landcover)) {
            
            # Remove the target habitat type
            veg.temp <- veg
            veg.temp[, unique(results.template$Landcover)] <- 0
            
            # Add the sum of all target habitat types to a single age class
            veg.temp[, landcover] <- target.habitat
            
            # Calculate the prediction
            results.template[results.template$Species == species & 
                                 results.template$Landcover == landcover, "Total"] <- sum(veg.temp * inv.link(veg.coef), na.rm = TRUE)
            
        }
        
        print(species)
        
    }
    
    results[[taxon]] <- results.template
    
}
 
save(results, file = "3_output/validation/age-relationships-landcover-simulation.Rdata")


# 4.1 Evaluate the correction ----
# Seems to look good upon quick glance
cor.results <- list()
for(taxon in names(results)) {
    
    species.results <- results[[taxon]]
    temp.results <- data.frame(Species = unique(species.results$Species),
                               Correlation  = NA)
    
    for (species in unique(species.results$Species)) {
        
        temp.data <- species.results[species.results$Species == species, ]
        temp.results[temp.results$Species == species, "Correlation"] <- cor(temp.data$Coefficient, temp.data$Total)
        
    }
    
    cor.results[[taxon]] <- temp.results
    
}

rm(list=ls())
gc()