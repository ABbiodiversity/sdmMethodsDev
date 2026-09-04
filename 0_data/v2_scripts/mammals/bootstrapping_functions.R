#
# Title: Bootstrapping functions
# Created: June 4th, 2024
# Last Updated: July 5th 2024
# Author: Brandon Allen
# Objectives: Define the functions required for the bootstrapping process
# Keywords: Bootstrap
# Notes: 

#############
# Bootstrap # 
#############~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

bootstrap_data <- function(data, species, boot) {
            
            #
            # 1.0 Data standardization 
            #
            
            # Since we are treating each recording individually, we fix visit to 1 as we no longer need to apply this weight.
            data["nQuadrant"] <- 1
            data$visit <- 1 
            
            # Create new column which is the observed count data (used for weighting in the age relationships), one for the converted probabilities
            data["Count"] <- as.integer(ifelse(data[, species] > 0, 1, 0))
            data["pcount"] <- as.integer(ifelse(data[, species] > 0, 1, 0) / data$nQuadrant)
            
            #
            # 2.0 Bootstrap
            # If the boot index is 1, use the complete data set, 
            # otherwise perform subsampling with replacement based on block ID.
            #
            
            # Check if there are at least 50 detections in each modeling region.
            veg.detect <- sum(data$pcount[data$NrName != "Grassland"])
            soil.detect <- sum(data$pcount[data$NrName %in% c("Grassland", "Parkland")])
            
            if (boot != 1) {
                        
                        unique.blocks <- unique(data$Block)
                        veg.site <- 0
                        soil.site <- 0
                        
                        # If both models are viable originally
                        if(veg.detect >= 50 & soil.detect >= 50) {
                                    
                                    while (veg.site < 50 | soil.site < 50) {
                                                
                                                data.in <- NULL
                                                
                                                for (sample_block in 1:length(unique.blocks)) {
                                                            
                                                            data.block <- data[grep(unique.blocks[sample_block], data$Block), ]
                                                            data.block <- data.block[sample(1:nrow(data.block), 
                                                                                            nrow(data.block), replace=TRUE), ]
                                                            data.in <- rbind(data.in, data.block)
                                                            
                                                }
                                                
                                                veg.site <- sum(ifelse(data.in[, "Count"] > 0, 1, 0))
                                                soil.site <- sum(ifelse(data.in[, "Count"] > 0, 1, 0))
                                                
                                    }
                                    
                        }
                        
                        # If only veg model is viable
                        if(veg.detect >= 50 & soil.detect < 50) {
                                    
                                    while (veg.site < 50) {
                                                
                                                data.in <- NULL
                                                
                                                for (sample_block in 1:length(unique.blocks)) {
                                                            
                                                            data.block <- data[grep(unique.blocks[sample_block], data$Block), ]
                                                            data.block <- data.block[sample(1:nrow(data.block), 
                                                                                            nrow(data.block), replace=TRUE), ]
                                                            data.in <- rbind(data.in, data.block)
                                                            
                                                }
                                                
                                                veg.site <- sum(ifelse(data.in[, "Count"] > 0, 1, 0))
                                                
                                    }
                                    
                        }
                        
                        # If only soil model is viable
                        if(veg.detect < 50 & soil.detect >= 50) {
                                    
                                    while (soil.site < 50) {
                                                
                                                data.in <- NULL
                                                
                                                for (sample_block in 1:length(unique.blocks)) {
                                                            
                                                            data.block <- data[grep(unique.blocks[sample_block], data$Block), ]
                                                            data.block <- data.block[sample(1:nrow(data.block), 
                                                                                            nrow(data.block), replace=TRUE), ]
                                                            data.in <- rbind(data.in, data.block)
                                                            
                                                }
                                                
                                                soil.site <- sum(ifelse(data.in[, "Count"] > 0, 1, 0))
                                                
                                    }
                                    
                        }
                        

                        
            } else {
                        
                        data.in <- data
                        
            }
            
            # Return the unique IDs for the bootstrap iteration
            boot.id <- data.frame(Boot = data.in$UniqueID)
            colnames(boot.id)[1] <- paste0("Boot_", boot)
            
            return(boot.id)
            
}
