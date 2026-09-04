# ---
# title: Bootstrapping functions
# author: Brandon Allen
# created: 2025-02-11
# notes: Define functions that are used generating the bootstrap site list
# ---

#' [Bootstrap data]
#'
#' [Creates a vector of site codes after thinning the recording data and performing a spatially explicate bootstrap sample.]
#'
#' @param [data] [Cleaned species and landcover data.]
#' @param [species] [Species code.]
#' @param [threshold] [Number of unique sites required to be considered sufficient for modeling.]
#' @param [boot] [Bootstrap iteration.]
#' @return [Creates a vector of site codes.]
#' 

bootstrap_data <- function(data, species, threshold = 20, boot) {
            
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
            
            # Check if there are at least 20 detections in each modeling region.
            veg.detect <- sum(data$pcount[data$NR != "Grassland"])
            soil.detect <- sum(data$pcount[data$NR %in% c("Grassland", "Parkland")])
            
            if (boot != 1) {
                        
                        unique.blocks <- unique(data$Block)
                        veg.site <- 0
                        soil.site <- 0
                        
                        # If both models are viable originally
                        if(veg.detect >= threshold & soil.detect >= threshold) {
                                    
                                    while (veg.site < threshold | soil.site < threshold) {
                                                
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
                        if(veg.detect >= threshold & soil.detect < threshold) {
                                    
                                    while (veg.site < threshold) {
                                                
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
                        if(veg.detect < threshold & soil.detect >= threshold) {
                                    
                                    while (soil.site < threshold) {
                                                
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
            boot.id <- data.frame(Boot = data.in$SiteYearQu)
            colnames(boot.id)[1] <- paste0("Boot_", boot)
            
            return(boot.id)
            
}
