# ---
# title: "Coefficient Standardization"
# author: "Brandon Allen"
# created: "2025-01-24"
# inputs: ["0_data/lookup/labels/vegetation-model-labels_2024.csv";
#          "0_data/lookup/labels/soil-model-labels_2024.csv";
#          "0_data/lookup/labels/climate-model-labels_2024.csv";
#          "3_output/models/bryophyte-species-models.Rdata";
#          "3_output/models/lichen-species-models.Rdata";
#          "3_output/models/mite-species-models.Rdata";
#          "3_output/models/vascular-plant-species-models.Rdata"]
# outputs: ["3_output/coefficients/COEFS.RData"]
# notes: 
#   "This script standardizes the raw species coefficient tables provided
#    to allow for the checking of model coefficients between versions."
# ---

# 1.0 Initialize the environment ----

# 1.1 Clear memory ----
rm(list=ls())
gc()

# 1.2 Load the variable templates ----
vegetation.template <- read.csv("0_data/lookup/labels/vegetation-model-labels_2024.csv")
soil.template <- read.csv("0_data/lookup/labels/soil-model-labels_2024.csv")
climate.template <- read.csv("0_data/lookup/labels/climate-model-labels_2024.csv")

# 1.3 Create the object for storing results and looping through taxonomic groups ----
COEFS <- list()
taxon.template <- data.frame(path = list.files("3_output/models/", full.names = TRUE),
                             name = c("Bryophytes", "Lichens", "Mites", "VascularPlants"),
                             pseudonym = c("bryophyte", "lichen", "mite", "vascular-plant"))

# 2.0 Standardize species model coefficients ----

for (taxon in taxon.template$pseudonym) {
    
    # 2.1 Define species paths ----
    model.path <- taxon.template$path[taxon.template$pseudonym == taxon]
    model.name <- taxon.template$name[taxon.template$pseudonym == taxon]
    
    # Define species coefficients
    load(model.path)
    vegetation.coef <- vegetation.coef
    soil.coef <- soil.coef
    
    # Define the species list
    species.list <- names(climate.coef)
    
    # 2.2 Standardize the climate coefficients ----
    i <- 1
    for(species in species.list) {
        
        # Extract the climate variables
        temp.data <- climate.coef[[species]]
        
        # Transpose the table
        temp.data <- t(temp.data)
        
        if (i == 1) {
            
            coefs.climate <- array(temp.data, 
                                   dim = c(length(species.list),19,100),
                                   dimnames = list(c(species.list),
                                                   rownames(temp.data),
                                                   NULL))
            
            coefs.climate[species, , ] <- temp.data
            i <- i + 1
            
        } else {
            
            coefs.climate[species, , ] <- temp.data
            i <- i + 1
            
        }
        
        rm(temp.data)
        
    }
    
    # 2.3 Standardize the vegetation coefficients ----
    i <- 1
    for(species in names(vegetation.coef)) {
        
        # Pull out coefficients
        temp.data <- vegetation.coef[[species]]
        
        # Check if there are missing values
        
        # Remove standard error
        temp.data <- temp.data[, -grep(".SE", colnames(temp.data))]
        
        # Add any missing blank coefficients
        temp.data <- cbind(temp.data, matrix(data = -10000, 
                                             nrow = nrow(temp.data), 
                                             ncol = 3, dimnames = list(NULL, c("MineV", "Mine", "HWater"))))
        
        temp.data[, "Water"] <- -10000
        temp.data[, "Bare"] <- -10000
        temp.data[, "SnowIce"] <- -10000
        
        # Relabel habitat types to align across groups
        colnames(temp.data) <- gsub("BlackSpruce", "TreedBog", colnames(temp.data))
        colnames(temp.data) <- gsub("Grass", "GrassHerb", colnames(temp.data))
        
        # Create the additional coefficients
        # Expand UrbInd to Urban and Industrial
        temp.data <- cbind(temp.data, matrix(data = temp.data[, "UrbInd"], dimnames = list(rownames(temp.data), "Urban")))
        temp.data <- cbind(temp.data, matrix(data = temp.data[, "UrbInd"], dimnames = list(rownames(temp.data), "Industrial")))
        temp.data <- cbind(temp.data, matrix(data = temp.data[, "UrbInd"], dimnames = list(rownames(temp.data), "Rural")))
        
        # Expand TreedFen to ages
        temp.data <- cbind(temp.data, matrix(data = temp.data[, "TreedFen"], dimnames = list(rownames(temp.data), "TreedFenR")))
        temp.data <- cbind(temp.data, matrix(data = temp.data[, "TreedFen"], dimnames = list(rownames(temp.data), "TreedFen1")))
        temp.data <- cbind(temp.data, matrix(data = temp.data[, "TreedFen"], dimnames = list(rownames(temp.data), "TreedFen2")))
        temp.data <- cbind(temp.data, matrix(data = temp.data[, "TreedFen"], dimnames = list(rownames(temp.data), "TreedFen3")))
        temp.data <- cbind(temp.data, matrix(data = temp.data[, "TreedFen"], dimnames = list(rownames(temp.data), "TreedFen4")))
        temp.data <- cbind(temp.data, matrix(data = temp.data[, "TreedFen"], dimnames = list(rownames(temp.data), "TreedFen5")))
        temp.data <- cbind(temp.data, matrix(data = temp.data[, "TreedFen"], dimnames = list(rownames(temp.data), "TreedFen6")))
        temp.data <- cbind(temp.data, matrix(data = temp.data[, "TreedFen"], dimnames = list(rownames(temp.data), "TreedFen7")))
        temp.data <- cbind(temp.data, matrix(data = temp.data[, "TreedFen"], dimnames = list(rownames(temp.data), "TreedFen8")))
        
        temp.data <- temp.data[, vegetation.template$Variable]
        colnames(temp.data) <- vegetation.template$Name
        
        # Transpose the table
        temp.data <- t(temp.data)
        
        # Store in the new array
        
        if (i == 1) {
            
            coefs.vegetation <- array(temp.data, 
                                      dim = c(length(names(vegetation.coef)),100,100),
                                      dimnames = list(c(names(vegetation.coef)),
                                                      rownames(temp.data),
                                                      NULL))
            
            coefs.vegetation[species, , ] <- temp.data
            i <- i + 1
            
        } else {
            
            coefs.vegetation[species, , ] <- temp.data
            i <- i + 1
            
        }
        
        rm(temp.data)
        
    }
    
    # 2.4 Standardize the soil coefficients ----
    i <- 1
    for(species in names(soil.coef)) {
        
        # Pull out coefficients
        temp.data <- soil.coef[[species]]
        
        # Remove standard error
        temp.data <- temp.data[, -grep(".SE", colnames(temp.data))]
        
        # Add any missing blank coefficients
        temp.data <- cbind(temp.data, matrix(data =  -10000, 
                                             nrow = nrow(temp.data), 
                                             ncol = 5, dimnames = list(NULL, c("Mine", "MineV",
                                                                               "Water", "HWater",
                                                                               "SoilUnknown"))))
        
        # Create the additional coefficients
        # Expand UrbInd to Urban and Industrial
        temp.data <- cbind(temp.data, matrix(data = temp.data[, "UrbInd"], dimnames = list(rownames(temp.data), "Urban")))
        temp.data <- cbind(temp.data, matrix(data = temp.data[, "UrbInd"], dimnames = list(rownames(temp.data), "Industrial")))
        temp.data <- cbind(temp.data, matrix(data = temp.data[, "UrbInd"], dimnames = list(rownames(temp.data), "Rural")))
        
        temp.data <- temp.data[, soil.template$Variable]
        colnames(temp.data) <- soil.template$Name
        
        # Transpose the table
        temp.data <- t(temp.data)
        
        # Store in the new array
        if (i == 1) {
            
            coefs.soil <- array(temp.data, 
                                dim = c(length(names(soil.coef)),25,100),
                                dimnames = list(names(soil.coef),
                                                rownames(temp.data),
                                                NULL))
            
            coefs.soil[species, , ] <- temp.data
            i <- i + 1
            
        } else {
            
            coefs.soil[species, , ] <- temp.data
            i <- i + 1
            
        }
        
        rm(temp.data)
        
    }
    
    
    # 2.5 Store the packaged coefficients ----
    COEFS[[model.name]] <- list(vegetation = coefs.vegetation,
                                soil = coefs.soil,
                                climate = coefs.climate)
    
    
}

# Save results
save(COEFS, file = "3_output/coefficients/COEFS.RData")

rm(list=ls())
gc()
