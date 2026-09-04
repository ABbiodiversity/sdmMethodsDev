# ---
# title: "Coefficient Comparison"
# author: "Brandon Allen"
# created: "2025-01-24"
# inputs: ["3_output/coefficients/COEFS.RData";
#          "0_data/previous-version/COEFS.RData";
#          "0_data/lookup/labels/vegetation-model-labels_2024.csv";
#          "0_data/lookup/labels/soil-model-labels_2024.csv"]
# outputs: ["Coefficient Comparison Figures"]
# notes: 
#   "This script compares the update species models to the previous versions. 
#    For species with similar results, and that have been previously reviewed,
#    we accept for the current version. When discrepancies occur, we reach out to the PC for review."
# ---

# 1.0 Clear memory ----
rm(list=ls())
gc()

# 1.1 Import data and libraries ----
library(ggpubr)
library(ggplot2)

load("3_output/coefficients/COEFS.RData")
COEFS.new <- COEFS
load("0_data/previous-coefficients/COEFS.RData")
COEFS.old <- COEFS

rm(COEFS)

# 1.2 Load the coefficient templates ----
vegetation.template <- read.csv("0_data/lookup/labels/vegetation-model-labels_2024.csv")
soil.template <- read.csv("0_data/lookup/labels/soil-model-labels_2024.csv")

# 2.0 Coefficient Comparison ---- 
# This section handles the comparison between versions of the coefficients
# If a new species model is available, no previous version comparison is performed

# 2.1 Vegetation coefficients ----
# Create the template for storing correlation information
veg.correlation <- NULL

for(taxon in names(COEFS.new)) {
    
    # Subset taxonomic group
    new.veg.coef <- COEFS.new[[taxon]]$vegetation
    old.veg.coef <- COEFS.old[[taxon]]$vegetation
    
    # Set up the template
    temp.correlation <- data.frame(Species = rownames(new.veg.coef),
                                   Taxon = taxon,
                                   Correlation = NA)
    rownames(temp.correlation) <- temp.correlation$Species
    
    for (species in rownames(new.veg.coef)) {
        
        # Define relevant coefficients
        coef.names <- vegetation.template$Variable
        coef.names <- coef.names[!(coef.names %in% c("Mine", "MineV", "Water", "Bare", "SnowIce", "Climate", "HWater", "Protocol"))]
        
        # Define the link function
        invlink <- binomial()$linkinv
        
        # If species is present in both coefficient sets, assess coefficient correlation
        if(species %in% rownames(old.veg.coef)) {
            
            temp.correlation[species, "Correlation"] <- cor(invlink(new.veg.coef[species, coef.names, 1]), 
                                                            invlink(old.veg.coef[species, coef.names, 1]))
            
        }
        
        # If the species isn't present in both versions, define OLD as NA
        if(species %in% rownames(old.veg.coef)) {
            
            main.coef <- data.frame(Name = names(new.veg.coef[species, coef.names, 1]),
                                    New = invlink(new.veg.coef[species, coef.names, 1]),
                                    Old = invlink(old.veg.coef[species, coef.names, 1]),
                                    Label = factor(names(new.veg.coef[species, coef.names, 1]),
                                                   levels = names(new.veg.coef[species, coef.names, 1])))
            
        } else {
            
            main.coef <- data.frame(Name = names(new.veg.coef[species, coef.names, 1]),
                                    New = invlink(new.veg.coef[species, coef.names, 1]),
                                    Old = NA,
                                    Label = factor(names(new.veg.coef[species, coef.names, 1]),
                                                   levels = names(new.veg.coef[species, coef.names, 1])))
            
        }
            
        # Define the colors
        main.coef$Color <- vegetation.template$Color[match(main.coef$Name, vegetation.template$Name)]
        
        # Get the maxmimum values based on the entire coefficient set
        max.value.new <- max(c(main.coef$New))
        max.value.old <- max(c(main.coef$Old))
        
        # Isolate the harvest coefficients
        cc.coef <- main.coef[grep("CC", main.coef$Name), ]
        cc.coef$Name <- gsub("CC", "", cc.coef$Name)
        cc.coef$Label <- factor(cc.coef$Label, levels = cc.coef$Label)  
        main.coef <- main.coef[-grep("CC", main.coef$Name), ]
        main.coef <- droplevels(main.coef)
    
        cc.coef <- data.frame(Class = c(rep("WhiteSpruce", 5), rep(NA, 4),
                                        rep("Pine", 5), rep(NA, 4),
                                        rep("Deciduous", 5), rep(NA, 4),
                                        rep("Mixedwood", 5), rep(NA, 4),
                                        rep(NA, 37)),
                              New = c(cc.coef$New[1:5], rep(NA, 4),
                                      cc.coef$New[6:10], rep(NA, 4),
                                      cc.coef$New[11:15], rep(NA, 4),
                                      cc.coef$New[16:20], rep(NA, 4),
                                      rep(NA, 37)),
                              Old = c(cc.coef$Old[1:5], rep(NA, 4),
                                      cc.coef$Old[6:10], rep(NA, 4),
                                      cc.coef$Old[11:15], rep(NA, 4),
                                      cc.coef$Old[16:20], rep(NA, 4),
                                      rep(NA, 37)))
        
        # Create the new coefficient plot
        new.coef <- ggplot(data = main.coef, aes(x = Label, y = New, fill = Color)) +
            geom_bar(stat = "identity", fill = main.coef$Color) +
            scale_x_discrete(labels = main.coef$Label) +
            geom_point(aes(x = main.coef$Name, y = cc.coef$New), show.legend = FALSE) +
            geom_line(aes(x = main.coef$Name, y = cc.coef$New, 
                          group = cc.coef$Class, linetype = "dotted"), 
                      size = 1, show.legend = FALSE) +
            scale_linetype_manual(values=c("dotted")) +
            guides(scale = "none") + 
            labs(x = "Coefficient", y = "Relative Abundance") +
            ggtitle(paste0("New Coefficient; Correlation = ", round(temp.correlation[species, "Correlation"], 3))) +
            theme_light() +
            coord_cartesian(ylim = c(0, max.value.new), clip = "off") +
            theme(axis.title = element_text(size=16),
                  axis.text.x = element_text(size=16, angle = 45, hjust = 1, vjust = 1),
                  axis.text.y = element_text(size=16),
                  title = element_text(size=12),
                  legend.text = element_text(size=16),
                  legend.title = element_blank(),
                  axis.line = element_line(colour = "black"),
                  panel.border = element_rect(colour = "black", fill=NA, size=1))
        
        # Create the old coefficient plot if possible
        if(species %in% rownames(old.veg.coef)) {
            
            old.coef <- ggplot(data = main.coef, aes(x = Label, y = Old, fill = Color)) +
                geom_bar(stat = "identity", fill = main.coef$Color) +
                scale_x_discrete(labels = main.coef$Label) +
                geom_point(aes(x = main.coef$Name, y = cc.coef$Old), show.legend = FALSE) +
                geom_line(aes(x = main.coef$Name, y = cc.coef$Old, 
                              group = cc.coef$Class, linetype = "dotted"), 
                          size = 1, show.legend = FALSE) +
                scale_linetype_manual(values=c("dotted")) +
                guides(scale = "none") + 
                labs(x = "Coefficient", y = "Relative Abundance") +
                ggtitle("Old Coefficient") +
                theme_light() +
                coord_cartesian(ylim = c(0, max.value.old), clip = "off") +
                theme(axis.title = element_text(size=16),
                      axis.text.x = element_text(size=16, angle = 45, hjust = 1, vjust = 1),
                      axis.text.y = element_text(size=16),
                      title = element_text(size=12),
                      legend.text = element_text(size=16),
                      legend.title = element_blank(),
                      axis.line = element_line(colour = "black"),
                      panel.border = element_rect(colour = "black", fill=NA, size=1))
            
            # Save
            ggsave(filename = paste0("3_output/figures/", taxon, "/", species, "/vegetation-model.jpeg"),
                   plot = ggarrange(new.coef, old.coef, nrow = 2),
                   height = 1200,
                   width = 1800,
                   dpi = 72,
                   quality = 50,
                   units = "px",
                   create.dir = TRUE)
            
        } else {
            
            # Save only the new coefficient plot
            ggsave(filename = paste0("3_output/figures/", taxon, "/", species, "/vegetation-model.jpeg"),
                   plot = new.coef,
                   height = 600,
                   width = 1800, 
                   dpi = 72,
                   quality = 50,
                   units = "px",
                   create.dir = TRUE)
            
        }
        
    }
    
    print(taxon)
    
    veg.correlation <- rbind(veg.correlation, temp.correlation)
    
}

# 2.2 Soil coefficients
# Create the template for storing correlation information
soil.correlation <- NULL

for(taxon in names(COEFS.new)) {
    
    # Subset taxonomic group
    new.soil.coef <- COEFS.new[[taxon]]$soil
    old.soil.coef <- COEFS.old[[taxon]]$soil
    
    # Set up the template
    temp.correlation <- data.frame(Species = rownames(new.soil.coef),
                                   Taxon = taxon,
                                   Correlation = NA)
    rownames(temp.correlation) <- temp.correlation$Species
    
    for (species in rownames(new.soil.coef)) {
        
        # Define relevant coefficients
        coef.names <- soil.template$Name
        coef.names <- coef.names[!(coef.names %in% c("Mine", "MineV", "Water", "Bare", "SnowIce", "Climate", "HWater", "Protocol", "SoilUnknown"))]
        
        # Define the link function
        invlink <- binomial()$linkinv
        
        # If species is present in both coefficient sets, assess coefficient correlation
        if(species %in% rownames(old.soil.coef)) {
            
            temp.correlation[species, "Correlation"] <- cor(invlink(new.soil.coef[species, coef.names, 1]), 
                                                            invlink(old.soil.coef[species, coef.names, 1]))
            
        }
        
        # Create the data frame for plotting
        if(species %in% rownames(old.soil.coef)) {
            
            main.coef <- data.frame(Name = names(new.soil.coef[species, coef.names, 1]),
                                    New = plogis(new.soil.coef[species, coef.names, 1]),
                                    Old = plogis(old.soil.coef[species, coef.names, 1]),
                                    Label = factor(names(new.soil.coef[species, coef.names, 1]),
                                                   levels = names(new.soil.coef[species, coef.names, 1])))
        
        } else {
                
            main.coef <- data.frame(Name = names(new.soil.coef[species, coef.names, 1]),
                                    New = plogis(new.soil.coef[species, coef.names, 1]),
                                    Old = NA,
                                    Label = factor(names(new.soil.coef[species, coef.names, 1]),
                                                   levels = names(new.soil.coef[species, coef.names, 1])))
            
        }
        
        main.coef$Color <- soil.template$Color[match(main.coef$Name, soil.template$Name)]
        
        # Subset the paspen information
        paspen.new <- round(main.coef[main.coef$Name == "pAspen", "New"],3)
        paspen.old <- round(main.coef[main.coef$Name == "pAspen", "Old"],3)
        
        main.coef <- main.coef[main.coef$Name != "pAspen", ]
        max.value.new <- max(c(main.coef$New))
        max.value.old <- max(c(main.coef$Old))
        
        # Create the new coefficient plot
        new.coef <- ggplot(data = main.coef, aes(x = Label, y = New, fill = Color)) +
            geom_bar(stat = "identity", fill = main.coef$Color) +
            scale_x_discrete(labels = main.coef$Label) +
            guides(scale = "none") + 
            labs(x = "Coefficient", y = "Relative Abundance") +
            ggtitle(paste0("New Coefficient; Correlation = ", round(temp.correlation[species, "Correlation"], 3), "; pAspen = ", paspen.new)) +
            theme_light() +
            coord_cartesian(ylim = c(0, max.value.new), clip = "off") +
            theme(axis.title = element_text(size=16),
                  axis.text.x = element_text(size=16, angle = 45, hjust = 1, vjust = 1),
                  axis.text.y = element_text(size=16),
                  title = element_text(size=12),
                  legend.text = element_text(size=16),
                  legend.title = element_blank(),
                  axis.line = element_line(colour = "black"),
                  panel.border = element_rect(colour = "black", fill=NA, size=1))
        
        # If possible, create the old coefficient plot
        if(species %in% rownames(old.soil.coef)) {
            
            old.coef <- ggplot(data = main.coef, aes(x = Label, y = Old, fill = Color)) +
                geom_bar(stat = "identity", fill = main.coef$Color) +
                scale_x_discrete(labels = main.coef$Label) +
                guides(scale = "none") + 
                labs(x = "Coefficient", y = "Relative Abundance") +
                ggtitle(paste0("Old Coefficient; pAspen = ", paspen.old)) +
                theme_light() +
                coord_cartesian(ylim = c(0, max.value.old), clip = "off") +
                theme(axis.title = element_text(size=16),
                      axis.text.x = element_text(size=16, angle = 45, hjust = 1, vjust = 1),
                      axis.text.y = element_text(size=16),
                      title = element_text(size=12),
                      legend.text = element_text(size=16),
                      legend.title = element_blank(),
                      axis.line = element_line(colour = "black"),
                      panel.border = element_rect(colour = "black", fill=NA, size=1))
            
            # Save
            ggsave(filename = paste0("3_output/figures/", taxon, "/", species, "/soil-model.jpeg"), 
                   plot = ggarrange(new.coef, old.coef, nrow = 2),
                   height = 1200,
                   width = 1800, 
                   dpi = 72,
                   quality = 50,
                   units = "px", 
                   create.dir = TRUE)
            
        } else {
            
            # Save
            ggsave(filename = paste0("3_output/figures/", taxon, "/", species, "/soil-model.jpeg"), 
                   plot = new.coef,
                   height = 600,
                   width = 1800, 
                   dpi = 72,
                   quality = 50,
                   units = "px", 
                   create.dir = TRUE)
            
        }
        
    }
    
    print(taxon)
    
    soil.correlation <- rbind(soil.correlation, temp.correlation)
    
}

save(soil.correlation, veg.correlation, file = "3_output/validation/version-validation.Rdata")

rm(list=ls())
gc()
