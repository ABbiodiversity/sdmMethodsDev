# ---
# title: "Spatial Prediction Comparison"
# author: "Brandon Allen"
# created: "2025-02-12"
# inputs: ["3_output/coefficients/COEFS.RData";
#          "0_data/previous-version/COEFS.RData";
#          "0_data/lookup/landcover/lookup-veg-hf-age-v2020.csv";
#          "0_data/lookup/landcover/lookup-soil-hf-v2020.csv";
#          "0_data/external/kgrid/backfillV7_w2w_2021HFI.Rdata";
#          "0_data/external/mapping/provincial-boundary.Rdata";
#          "0_data/external/kgrid/kgrid_2.2.Rdata"]
# outputs: ["Prediction Comparison Figures"]
# notes: 
#   "This script compares the update species model predictions to the previous versions. 
#    For species with similar results, and that have been previously reviewed,
#    we accept for the current version. When discrepancies occur, we reach out to the PC for review."
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

# 1.4 Load the two versions of the coefficients
load("3_output/coefficients/COEFS.RData")
COEFS.new <- COEFS
load("0_data/previous-coefficients/COEFS.RData")
COEFS.old <- COEFS

rm(COEFS)

# 1.5 Define the link functions used for making predictions
inv.link <- binomial()$linkinv
link <- binomial()$linkfun

# 2.0 Landcover standardization ----

# 2.1 Clean landcover to the appropriate categories ----
veg.cur <- landscape_hf_summary(data.in = as.data.frame(as.matrix(d.wide$veg.current)),
                                landscape.lookup = veg.lookup,
                                class.in = "ID", class.out = "UseInAnalysis_Simplified")
soil.cur <- landscape_hf_summary(data.in = as.data.frame(as.matrix(d.wide$soil.current)),
                                 landscape.lookup = soil.lookup,
                                 class.in = "ID", class.out = "UseInAnalysis_Simplified")

# 2.2 Convert each matrix to proportions ----
veg.cur <- as.data.frame(veg.cur)
veg.cur <- veg.cur / rowSums(veg.cur)
veg.cur$LinkID <- rownames(veg.cur)

soil.cur <- as.data.frame(soil.cur)
soil.cur <- soil.cur / rowSums(soil.cur)
soil.cur$LinkID <- rownames(soil.cur)

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

veg.cur$MineV <- 0
soil.cur$MineV <- 0

# 2.4 Merge Climate and landcover information ----
veg.cur <- merge.data.frame(kgrid, veg.cur, by = "LinkID")
rownames(veg.cur) <- as.character(veg.cur$LinkID)
soil.cur <- merge.data.frame(kgrid, soil.cur, by = "LinkID")
rownames(soil.cur) <- as.character(soil.cur$LinkID)
veg.cur <- veg.cur[rownames(soil.cur), ] # Align

# Clean up memory
rm(d.wide, soil.lookup, veg.lookup)

# 3.0 Vegetation based models ----
for(taxon in names(COEFS.new)) {
    
    # Subset taxonomic group
    new.veg.coef <- COEFS.new[[taxon]]$vegetation
    new.climate.coef <- COEFS.new[[taxon]]$climate
    old.veg.coef <- COEFS.old[[taxon]]$vegetation
    old.climate.coef <- COEFS.old[[taxon]]$climate
    
    for(species in rownames(new.veg.coef)) {
        
        # New coefficients
        # Isolate the coefficients
        spp.clim <- new.climate.coef[species, , 1]
        spp.veg <- new.veg.coef[species, , 1]
        
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
        veg.pred <- rowSums(veg * inv.link(veg.coef))
        
        # Store the results
        climate.pred.new <- data.frame(LinkID = rownames(climate.pred.og),
                                   NewPred = climate.pred.og[,1])
        veg.pred.new <- data.frame(LinkID = names(veg.pred),
                               NewPred = as.numeric(veg.pred))

        # Old coefficients
        if(species %in% rownames(old.veg.coef)) {
            
            # Isolate the coefficients
            spp.clim <- old.climate.coef[species, , 1]
            spp.veg <- old.veg.coef[species, , 1]
            
            # Standardize the climate data
            names(spp.clim) <- c("Intercept", "MAP", "FFP", "TD", "CMD", "bio9", "bio15", "PET",
                                 "MAT", "MWMT", "Easting", "Northing", "Easting2", "Northing2",
                                 "EastingNorthing", "MAPPET", "CMDMAT", "MAT2", "MWMT2")
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
            veg.pred <- rowSums(veg * inv.link(veg.coef))
            
            # Store the results
            climate.pred <- data.frame(LinkID = rownames(climate.pred.og),
                                       OldPred = climate.pred.og[,1])
            veg.pred <- data.frame(LinkID = names(veg.pred),
                                   OldPred = as.numeric(veg.pred))
            
            climate.pred <- merge.data.frame(climate.pred.new, climate.pred, by = "LinkID")
            veg.pred <- merge.data.frame(veg.pred.new, veg.pred, by = "LinkID")
            
        } else {
            
            climate.pred <- climate.pred.new
            climate.pred$OldPred <- 0
            veg.pred <- veg.pred.new
            veg.pred$OldPred <- 0
            
        }
        
        # Save results
        if(!dir.exists(paste0("3_output/temporary/", taxon, "/", species))) {
            
            dir.create(paste0("3_output/temporary/", taxon, "/", species), recursive = TRUE)
            
        }

        save(climate.pred, veg.pred, 
             file = paste0("3_output/temporary/", taxon, "/", species, "/vegetation-model.Rdata"))
        
        print(species)
   
    }
       
}

# 4.0 Soil based models ----
for(taxon in names(COEFS.new)) {
    
    # Subset taxonomic group
    new.soil.coef <- COEFS.new[[taxon]]$soil
    new.climate.coef <- COEFS.new[[taxon]]$climate
    old.soil.coef <- COEFS.old[[taxon]]$soil
    old.climate.coef <- COEFS.old[[taxon]]$climate
    
    for(species in rownames(new.soil.coef)) {
        
        # New coefficients
        # Isolate the coefficients
        spp.clim <- new.climate.coef[species, , 1]
        spp.soil <- new.soil.coef[species, , 1]
        
        # Standardize the climate data
        climate.soil <- as.matrix(soil.cur[, names(spp.clim)])
        soil <- as.matrix(soil.cur[, names(spp.soil)[-c(1,2)]])
        
        # Predict space/climate component
        climate.pred <- matrix(inv.link(drop(climate.soil %*% spp.clim)), ncol = 1,
                               dimnames = list(rownames(climate.soil), "Climate"))
        
        # Truncate climate prediction
        climate.pred.og <- ifelse(climate.pred >= quantile(climate.pred, 0.99),
                                  quantile(climate.pred, 0.99),
                                  climate.pred)
        
        # Use this to predict the joint climate contribution (Add the paspen component too)
        climate.pred <- (climate.pred.og * spp.soil["Climate"]) + (soil.cur$pAspen * spp.soil["pAspen"])
        
        # Using these prediction, create a matrix and get the climate adjusted soil coefficients
        climate.matrix <- matrix(climate.pred, nrow = nrow(soil), ncol = ncol(soil))
        
        # Align the coefficients and landcover information
        soil.coef <- spp.soil[colnames(soil)]
        
        # Joint climate prediction
        soil.coef <- t(t(climate.matrix) + soil.coef)
        soil.pred <- rowSums(soil * inv.link(soil.coef))
        
        # Store the results
        climate.pred.new <- data.frame(LinkID = rownames(climate.pred.og),
                                       NewPred = climate.pred.og[,1])
        soil.pred.new <- data.frame(LinkID = names(soil.pred),
                                   NewPred = as.numeric(soil.pred))
        
        # Old coefficients
        if(species %in% rownames(old.soil.coef)) {
            
            # Isolate the coefficients
            spp.clim <- old.climate.coef[species, , 1]
            spp.soil <- old.soil.coef[species, , 1]
            
            # Standardize the climate data
            names(spp.clim) <- c("Intercept", "MAP", "FFP", "TD", "CMD", "bio9", "bio15", "PET",
                                 "MAT", "MWMT", "Easting", "Northing", "Easting2", "Northing2",
                                 "EastingNorthing", "MAPPET", "CMDMAT", "MAT2", "MWMT2")
            climate.soil <- as.matrix(soil.cur[, names(spp.clim)])
            soil <- as.matrix(soil.cur[, names(spp.soil)[-c(1,2)]])
            
            # Predict space/climate component
            climate.pred <- matrix(inv.link(drop(climate.soil %*% spp.clim)), ncol = 1,
                                   dimnames = list(rownames(climate.soil), "Climate"))
            
            # Truncate climate prediction
            climate.pred.og <- ifelse(climate.pred >= quantile(climate.pred, 0.99),
                                      quantile(climate.pred, 0.99),
                                      climate.pred)
            
            # Use this to predict the joint climate contribution (Add the paspen component too)
            climate.pred <- (climate.pred.og * spp.soil["Climate"]) + (soil.cur$pAspen * spp.soil["pAspen"])
            
            # Using these prediction, create a matrix and get the climate adjusted soil coefficients
            climate.matrix <- matrix(climate.pred, nrow = nrow(soil), ncol = ncol(soil))
            
            # Align the coefficients and landcover information
            soil.coef <- spp.soil[colnames(soil)]
            
            # Joint climate prediction
            soil.coef <- t(t(climate.matrix) + soil.coef)
            soil.pred <- rowSums(soil * inv.link(soil.coef))
            
            # Store the results
            climate.pred <- data.frame(LinkID = rownames(climate.pred.og),
                                       OldPred = climate.pred.og[,1])
            soil.pred <- data.frame(LinkID = names(soil.pred),
                                   OldPred = as.numeric(soil.pred))
            
            climate.pred <- merge.data.frame(climate.pred.new, climate.pred, by = "LinkID")
            soil.pred <- merge.data.frame(soil.pred.new, soil.pred, by = "LinkID")
            
        } else {
            
            climate.pred <- climate.pred.new
            climate.pred$OldPred <- 0
            soil.pred <- soil.pred.new
            soil.pred$OldPred <- 0
            
        } 
        
        # Save results
        if(!dir.exists(paste0("3_output/temporary/", taxon, "/", species))) {
            
            dir.create(paste0("3_output/temporary/", taxon, "/", species), recursive = TRUE)
            
        }
        
        save(climate.pred, soil.pred, 
             file = paste0("3_output/temporary/", taxon, "/", species, "/soil-model.Rdata"))
        
        print(species)
        
    }
    
}
 
# 5.0 Visualization ----

for(taxon in names(COEFS.new)) {
    
    # Subset taxonomic group
    species.list <- rownames(COEFS.new[[taxon]]$climate)
    
    for(species in species.list) {
        
        # 5.1 Climate models
        # Load the species data
        veg.path <- paste0("3_output/temporary/", taxon, "/", species, "/vegetation-model.Rdata")
        soil.path <- paste0("3_output/temporary/", taxon, "/", species, "/soil-model.Rdata")
        
        if(file.exists(veg.path)) {
            
            load(veg.path)
            
        } 
        
        if(file.exists(soil.path)) {
            
            load(soil.path)
            colnames(soil.pred) <- c("LinkID", "NewSoil", "OldSoil")
            
        }
        
        # New prediction
        kgrid.map <- merge.data.frame(kgrid, climate.pred, by = "LinkID")
        kgrid.map$NewPred <- ifelse(kgrid.map$NewPred >= quantile(kgrid.map$NewPred, 0.99),
                                       quantile(kgrid.map$NewPred, 0.99),
                                       kgrid.map$NewPred)
        kgrid.map$OldPred <- ifelse(kgrid.map$OldPred >= quantile(kgrid.map$OldPred, 0.99),
                                    quantile(kgrid.map$OldPred, 0.99),
                                    kgrid.map$OldPred)
        max.abundance <- max(kgrid.map$NewPred)
        climate.new <- ggplot() +
            geom_sf(data = province.shapefile, aes(color = NRNAME, fill = NRNAME), show.legend = FALSE) +
            scale_fill_manual(values =  alpha(province.shapefile$Color, 0.2)) +
            scale_color_manual(values =  alpha(province.shapefile$Color, 0.1)) +
            new_scale_color() +
            new_scale_fill() +
            geom_raster(data = kgrid.map , aes(x = X, y = Y, fill = NewPred)) +
            scale_fill_gradientn(name = paste0("Relative\nAbundance"), colors = rev(met.brewer(name = "Hiroshige", n = 100, type = "continuous")), limits = c(0,max.abundance), guide = "colourbar") +
            scale_color_gradientn(colors = rev(met.brewer(name = "Hiroshige", n = 100, type = "continuous")), limits = c(0,max.abundance), guide = "none") +
            theme_light() +
            ggtitle("New Climate Model") +
            theme(axis.title.x = element_blank(),
                  axis.title.y = element_blank(),
                  axis.text.x = element_text(size=18),
                  axis.text.y = element_text(size=18),
                  panel.grid.major.y = element_blank(),
                  legend.text = element_text(size=14),
                  legend.title = element_text(size=16),
                  legend.key.size = unit(1, "cm"),
                  axis.line = element_line(colour = "black"),
                  panel.border = element_rect(colour = "black", fill=NA, size=1),
                  legend.position = c(0.15, 0.15))
        
        max.abundance <- max(kgrid.map$OldPred)
        climate.old <- ggplot() +
            geom_sf(data = province.shapefile, aes(color = NRNAME, fill = NRNAME), show.legend = FALSE) +
            scale_fill_manual(values =  alpha(province.shapefile$Color, 0.2)) +
            scale_color_manual(values =  alpha(province.shapefile$Color, 0.1)) +
            new_scale_color() +
            new_scale_fill() +
            geom_raster(data = kgrid.map , aes(x = X, y = Y, fill = OldPred)) +
            scale_fill_gradientn(name = paste0("Relative\nAbundance"), colors = rev(met.brewer(name = "Hiroshige", n = 100, type = "continuous")), limits = c(0,max.abundance), guide = "colourbar") +
            scale_color_gradientn(colors = rev(met.brewer(name = "Hiroshige", n = 100, type = "continuous")), limits = c(0,max.abundance), guide = "none") +
            theme_light() +
            ggtitle("Old Climate Model") +
            theme(axis.title.x = element_blank(),
                  axis.title.y = element_blank(),
                  axis.text.x = element_text(size=18),
                  axis.text.y = element_text(size=18),
                  panel.grid.major.y = element_blank(),
                  legend.text = element_text(size=14),
                  legend.title = element_text(size=16),
                  legend.key.size = unit(1, "cm"),
                  axis.line = element_line(colour = "black"),
                  panel.border = element_rect(colour = "black", fill=NA, size=1),
                  legend.position = c(0.15, 0.15))
        
        ggsave(filename = paste0("3_output/figures/", taxon, "/", species, "/climate.jpeg"),
               plot = ggarrange(climate.new, climate.old, ncol = 2),
               height = 900,
               width = 1200,
               dpi = 72,
               quality = 100,
               units = "px", 
               create.dir = TRUE)
        
        # 5.2 Landcover models
        # If both exist
        if(file.exists(veg.path) & file.exists(soil.path)) {
            
            kgrid.map <- merge.data.frame(kgrid, veg.pred, by = "LinkID")
            kgrid.map <- merge.data.frame(kgrid.map, soil.pred, by = "LinkID")
            kgrid.map$NewPred <- (kgrid.map$NewPred * kgrid.map$wN) + (kgrid.map$NewSoil * kgrid.map$wS)
            kgrid.map$OldPred <- (kgrid.map$OldPred * kgrid.map$wN) + (kgrid.map$OldSoil * kgrid.map$wS)
            kgrid.map$NewPred <- ifelse(kgrid.map$NewPred >= quantile(kgrid.map$NewPred, 0.99),
                                        quantile(kgrid.map$NewPred, 0.99),
                                        kgrid.map$NewPred)
            kgrid.map$OldPred <- ifelse(kgrid.map$OldPred >= quantile(kgrid.map$OldPred, 0.99),
                                        quantile(kgrid.map$OldPred, 0.99),
                                        kgrid.map$OldPred)
            
        } 
        
        # If only veg
        if(file.exists(veg.path) & !file.exists(soil.path)) {
            
            kgrid.map <- merge.data.frame(kgrid, veg.pred, by = "LinkID")
            kgrid.map$NewPred <- ifelse(kgrid.map$NewPred >= quantile(kgrid.map$NewPred, 0.99),
                                        quantile(kgrid.map$NewPred, 0.99),
                                        kgrid.map$NewPred)
            kgrid.map$OldPred <- ifelse(kgrid.map$OldPred >= quantile(kgrid.map$OldPred, 0.99),
                                        quantile(kgrid.map$OldPred, 0.99),
                                        kgrid.map$OldPred)
            
            kgrid.map$NewPred[kgrid.map$NrName == "Grassland"] <- NA
            kgrid.map$OldPred[kgrid.map$NrName == "Grassland"] <- NA
            
        }
        
        # If only soil
        if(file.exists(soil.path) & !file.exists(veg.path)) {
            
            kgrid.map <- merge.data.frame(kgrid, soil.pred, by = "LinkID")
            kgrid.map$NewPred <- ifelse(kgrid.map$NewSoil >= quantile(kgrid.map$NewSoil, 0.99),
                                        quantile(kgrid.map$NewSoil, 0.99),
                                        kgrid.map$NewSoil)
            kgrid.map$OldPred <- ifelse(kgrid.map$OldSoil >= quantile(kgrid.map$OldSoil, 0.99),
                                        quantile(kgrid.map$OldSoil, 0.99),
                                        kgrid.map$OldSoil)
            
            kgrid.map$NewPred[!(kgrid.map$NrName %in% c("Grassland", "Parkland"))] <- NA
            kgrid.map$OldPred[!(kgrid.map$NrName %in% c("Grassland", "Parkland"))] <- NA
            
        }
        
        
        # New prediction
        max.abundance <- max(kgrid.map$NewPred)
        landcover.new <- ggplot() +
            geom_sf(data = province.shapefile, aes(color = NRNAME, fill = NRNAME), show.legend = FALSE) +
            scale_fill_manual(values =  alpha(province.shapefile$Color, 0.2)) +
            scale_color_manual(values =  alpha(province.shapefile$Color, 0.1)) +
            new_scale_color() +
            new_scale_fill() +
            geom_raster(data = kgrid.map , aes(x = X, y = Y, fill = NewPred)) +
            scale_fill_gradientn(name = paste0("Relative\nAbundance"), colors = rev(met.brewer(name = "Hiroshige", n = 100, type = "continuous")), limits = c(0,max.abundance), guide = "colourbar") +
            scale_color_gradientn(colors = rev(met.brewer(name = "Hiroshige", n = 100, type = "continuous")), limits = c(0,max.abundance), guide = "none") +
            theme_light() +
            ggtitle("New Landcover Model") +
            theme(axis.title.x = element_blank(),
                  axis.title.y = element_blank(),
                  axis.text.x = element_text(size=18),
                  axis.text.y = element_text(size=18),
                  panel.grid.major.y = element_blank(),
                  legend.text = element_text(size=14),
                  legend.title = element_text(size=16),
                  legend.key.size = unit(1, "cm"),
                  axis.line = element_line(colour = "black"),
                  panel.border = element_rect(colour = "black", fill=NA, size=1),
                  legend.position = c(0.15, 0.15))
        
        max.abundance <- max(kgrid.map$OldPred)
        landcover.old <- ggplot() +
            geom_sf(data = province.shapefile, aes(color = NRNAME, fill = NRNAME), show.legend = FALSE) +
            scale_fill_manual(values =  alpha(province.shapefile$Color, 0.2)) +
            scale_color_manual(values =  alpha(province.shapefile$Color, 0.1)) +
            new_scale_color() +
            new_scale_fill() +
            geom_raster(data = kgrid.map , aes(x = X, y = Y, fill = OldPred)) +
            scale_fill_gradientn(name = paste0("Relative\nAbundance"), colors = rev(met.brewer(name = "Hiroshige", n = 100, type = "continuous")), limits = c(0,max.abundance), guide = "colourbar") +
            scale_color_gradientn(colors = rev(met.brewer(name = "Hiroshige", n = 100, type = "continuous")), limits = c(0,max.abundance), guide = "none") +
            theme_light() +
            ggtitle("Old Landcover Model") +
            theme(axis.title.x = element_blank(),
                  axis.title.y = element_blank(),
                  axis.text.x = element_text(size=18),
                  axis.text.y = element_text(size=18),
                  panel.grid.major.y = element_blank(),
                  legend.text = element_text(size=14),
                  legend.title = element_text(size=16),
                  legend.key.size = unit(1, "cm"),
                  axis.line = element_line(colour = "black"),
                  panel.border = element_rect(colour = "black", fill=NA, size=1),
                  legend.position = c(0.15, 0.15))
        
        ggsave(filename = paste0("3_output/figures/", taxon, "/", species, "/landcover.jpeg"),
               plot = ggarrange(landcover.new, landcover.old, ncol = 2),
               height = 900,
               width = 1200,
               dpi = 72,
               quality = 100,
               units = "px", 
               create.dir = TRUE)
        
        print(species)
        rm(veg.pred, soil.pred, climate.pred)
        
    }
    
}

rm(list=ls())
gc()
