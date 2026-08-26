# ---
# title: "Median Bootstrap"
# author: "Brandon Allen"
# created: "2025-04-01"
# inputs: [""3_output/coefficients/COEFS.RData"]
# outputs: ["3_output/tables/median-bootstrap.Rdata"]
# notes: 
#   "This script determines the median coefficient that best represents the 100 bootstrap iterations"
# ---

# 1.0 Environment initialization ----

# 1.1 Clear memory ----
rm(list=ls())
gc()

# 1.2 Load libraries and source functions ----
library(vegan)

# 1.3 Load species models and landcover information ----
load("3_output/coefficients/COEFS.RData")

# 2.0 For each taxonomic group, identify the median bootstrap ----
median.bootstrap <- list()

for (taxon in names(COEFS)) {
    
    # For each taxonomic group, isolate the potential species list
    species.coefs <- COEFS[[taxon]]
    
    # For amphibians, we are only concerned with the vegetation based model
    median.temp <- data.frame(Species = rownames(species.coefs$climate),
                                   Boot = NA)
    
    # Loop through each species
    for (species in median.temp$Species) {
        
        # Isolate the bootstrap coefficients for a species
        # Vegetation
        if(species %in% rownames(species.coefs$vegetation)) {
            
            coef.boot <- t(as.matrix(species.coefs$vegetation[species,,]))
            
        }
        
        if(species %in% rownames(species.coefs$soil)) {
            
            coef.boot <- t(as.matrix(species.coefs$soil[species,,]))
            
        }
        
        if(species %in% rownames(species.coefs$vegetation) & species %in% rownames(species.coefs$soil)) {
            
            coef.veg <- t(as.matrix(species.coefs$vegetation[species,,]))
            coef.soil <- t(as.matrix(species.coefs$soil[species,,]))
            coef.boot <- cbind(coef.veg, coef.soil)
            
        }
        
        # Run an NMDS 
        nmds.summary <- metaMDS(coef.boot, k=2, distance="euclidean", trace=0, na.rm = TRUE)
        
        # Get the site scores
        site.scores <- as.data.frame(scores(nmds.summary, display="sites"))
        
        # Calculate centroid
        centroid.scores <- colMeans(site.scores)
        
        # Get distances to centroid
        site.scores[, "Distance"] <- sqrt((site.scores[, "NMDS1"]-centroid.scores[1])^2 + (site.scores[, "NMDS2"]-centroid.scores[2])^2)
        
        # Get closest bootstrap
        median.boot <- rownames(site.scores)[site.scores$Distance == min(site.scores$Distance)]
        
        # Store
        median.temp$Boot[median.temp$Species == species] <- median.boot
        
    }
    
    # Store the taxonomic group and repeat
    median.bootstrap[[taxon]] <- median.temp
    print(taxon)
    
}

save(median.bootstrap, file = "3_output/tables/median-bootstrap.Rdata")

# Clear memory
rm(list=ls())
gc()
