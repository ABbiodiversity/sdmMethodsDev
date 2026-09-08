# ---
# title: Model validation functions
# author: Brandon Allen
# created: 2025-02-11
# notes: Define functions that are used for model validation.
# ---

#' [Model validation]
#'
#' [Calculation of AUC statistics based on the final hierachical model. Implements two prediction approaches and climate truncation.]
#'
#' @param [species] [Focal species of interest.]
#' @param [data] [Cleaned species, climate, and landcover data.]
#' @param [boot.data] [List of site codes to be included for each species and bootstrap iteration.]
#' @param [climate.coef] [List of space-climate coefficients calculated from the detection_models function.]
#' @param [landcover.coef] [List of landcover coefficients calculated from the detection_models function.]
#' @param [landcover.type] [Defines if the provided landcover coefficients are Vegetation or Soil models.]
#' @param [protocol.flag] [Flag that determines if we need to account for differences in sample protocols]
#' @param [boot] [Defines bootstrap iteration.]
#' @return [Outputs vector of model coefficients defined in climate.models and space.models.]
#' 

model_validation <- function(species, data, boot.data,
                              climate.coef, landcover.coef,
                              landcover.type, protocol.flag, boot) {
            
            #
            # 1.0 Libraries
            #
            
            require(pROC)
            
            #
            # 2.0 Data standardization 
            #
            
            # Since we are treating each recording individually, we fix visit to 1 as we no longer need to apply this weight.
            data["nQuadrant"] <- 1
            data$visit <- 1 
            
            # Create new column which is the observed count data (used for weighting in the age relationships), one for the converted probabilities
            data["Count"] <- as.integer(ifelse(data[, species] > 0, 1, 0))
            data["pcount"] <- as.integer(ifelse(data[, species] > 0, 1, 0) / data$nQuadrant)
            
            # 3.0 Bootstrap Selection
            boot.data <- boot.data[[species]]
            site.id <- boot.data[, paste0("Boot_", boot)]
            data <- data[data$SiteYearQu %in% site.id, ]
            
            #
            # 4.0 Climate Predictions
            #
            
            # Using the matching climate model, create the prediction that will be used
            # Add the intercept and extract climate coefficients
            data$Intercept <- 1
            climate.dect.coef <- climate.coef[[species]][boot, ]
            climate.veg <- as.matrix(data[, names(climate.dect.coef)])
            
            # Predict space/climate component (Probability scale)
            climate.prediction <- plogis(drop(climate.veg %*% climate.dect.coef))
            climate.prediction.truncated <- ifelse(climate.prediction >= quantile(climate.prediction, 0.99),
                                                   quantile(climate.prediction, 0.99),
                                                   climate.prediction)
                
            #
            # 5.0 Landcover Predictions and statistics
            #
            
            if(landcover.type == "Vegetation") {
                
                #
                # Evaluation using landcover + climate
                #
                
                veg.dect.coef <- vegetation.coef[[species]][boot, ]

                # If protocol flag is present, subtract protocol coefficient from the values
                # for "Old" surveys. This is done because the coefficients are based on the
                # "New" protocol.
                if(protocol.flag == TRUE) {
                    
                    # Align the vegetation information and coefficients
                    column.remove <- -(1:3)
                    veg.in <- as.matrix(data[, names(veg.dect.coef)[column.remove]])
                    
                    # Predict without space climate component
                    data$Vegetation <- drop(veg.in %*% plogis(veg.dect.coef[column.remove]))
                    
                    # If protocol == "old" remove the protocol coefficient
                    data$Vegetation[data$Protocol == "Old"] <- data$Vegetation[data$Protocol == "Old"] - as.numeric(veg.dect.coef["Protocol"])
                    
                } else {
                    
                    # Align the vegetation information and coefficients
                    column.remove <- -(1:2)
                    veg.in <- as.matrix(data[, names(veg.dect.coef)[column.remove]])
                    
                    # Predict without space climate component
                    data$Vegetation <- drop(veg.in %*% plogis(veg.dect.coef[column.remove]))
                    
                }
                
                # Predict with space climate component
                climate.component <- climate.prediction * veg.dect.coef["Climate"]
                climate.component.truncated <- climate.prediction.truncated * veg.dect.coef["Climate"]
                data$VegetationClim <- plogis(qlogis(drop(veg.in %*% plogis(veg.dect.coef[column.remove]))) + climate.component)
                data$VegetationClimTrunc <- plogis(qlogis(drop(veg.in %*% plogis(veg.dect.coef[column.remove]))) + climate.component.truncated)
                
                # Statistics
                # Climate uses the entire grid
                climate.auc <- auc(data$pcount, climate.prediction)
                climate.truncated.auc <- auc(data$pcount, climate.prediction.truncated)
                
                # Landcover only uses the section included in the model
                data.region <- data[!(data$NR %in% c("Grassland")), ]
                landcover.auc <- auc(data.region$pcount, data.region$Vegetation)
                full.auc <- auc(data.region$pcount, data.region$VegetationClim)
                full.truncated.auc <- auc(data.region$pcount, data.region$VegetationClimTrunc)
                
                #
                # Evaluation using modified climate + landcover coefficients
                #
                
                # Convert climate component to a climate matrix with same dimentions as the landcover
                climate.component <- matrix(climate.component, nrow = nrow(veg.in), ncol = ncol(veg.in))
                climate.component.truncated <- matrix(climate.component.truncated, nrow = nrow(veg.in), ncol = ncol(veg.in))
                
                # Isolate the landcover coefficients
                veg.dect.coef <- veg.dect.coef[column.remove]
                
                # Joint landcover and climate prediction
                veg.joint.coef <- t(t(climate.component) + veg.dect.coef)
                veg.joint.truncated.coef <- t(t(climate.component.truncated) + veg.dect.coef)
                
                data$VegetationClimJoint <- rowSums(veg.in * plogis(veg.joint.coef))
                data$VegetationClimJointTrunc <- rowSums(veg.in * plogis(veg.joint.truncated.coef))
                
                # Evaluation in the focal region
                data.region <- data[!(data$NR %in% c("Grassland")), ]
                full.joint.auc <- auc(data.region$pcount, data.region$VegetationClimJoint)
                full.joint.truncated.auc <- auc(data.region$pcount, data.region$VegetationClimJointTrunc)
                
            }
            
            if(landcover.type == "Soil") {
                
                #
                # Evaluation using landcover + climate
                #
                
                soil.dect.coef <- soil.coef[[species]][boot, ]
                
                # If protocol flag is present, subtract protocol coefficient from the values
                # for "Old" surveys. This is done because the coefficients are based on the
                # "New" protocol.
                if(protocol.flag == TRUE) {
                    
                    # Align the vegetation information and coefficients
                    column.remove <- -(1:4)
                    soil.in <- as.matrix(data[, names(soil.dect.coef)[column.remove]])
                    
                    # Predict without space climate component
                    data$Soil <- drop(soil.in %*% plogis(soil.dect.coef[column.remove]))
                    
                    # If protocol == "old" remove the protocol coefficient
                    data$Soil[data$Protocol == "Old"] <- data$Soil[data$Protocol == "Old"] - as.numeric(soil.dect.coef["Protocol"])
                    
                } else {
                    
                    # Align the vegetation information and coefficients
                    column.remove <- -(1:3)
                    soil.in <- as.matrix(data[, names(soil.dect.coef)[column.remove]])
                    
                    # Predict without space climate component
                    data$Soil <- drop(soil.in %*% plogis(soil.dect.coef[column.remove]))
                    
                }
                
                # Predict the pAspen and climate components
                paspen.component <- data$paspen * soil.dect.coef["paspen"]
                climate.component <- climate.prediction * soil.dect.coef["Climate"]
                climate.component.truncated <- climate.prediction.truncated * soil.dect.coef["Climate"]
                
                # Predict with space climate component
                data$SoilClim <- plogis(qlogis(drop(soil.in %*% plogis(soil.dect.coef[column.remove]))) + paspen.component + climate.component)
                data$SoilClimTrunc <- plogis(qlogis(drop(soil.in %*% plogis(soil.dect.coef[column.remove]))) + paspen.component + climate.component.truncated)
                
                # Statistics
                # Climate uses the entire grid
                climate.auc <- auc(data$pcount, climate.prediction)
                climate.truncated.auc <- auc(data$pcount, climate.prediction.truncated)
                
                # Landcover only uses the section included in the model
                data.region <- data[data$NR %in% c("Grassland", "Parkland"), ]
                landcover.auc <- auc(data.region$pcount, data.region$Soil)
                full.auc <- auc(data.region$pcount, data.region$SoilClim)
                full.truncated.auc <- auc(data.region$pcount, data.region$SoilClimTrunc)
                
                #
                # Evaluation using modified climate + landcover coefficients
                #
                
                # Convert climate component to a climate matrix with same dimentions as the landcover
                climate.component <- matrix((climate.component + paspen.component), nrow = nrow(soil.in), ncol = ncol(soil.in))
                climate.component.truncated <- matrix((climate.component.truncated + paspen.component), nrow = nrow(soil.in), ncol = ncol(soil.in))
                
                # soil.dect.coef the landcover coefficients
                soil.dect.coef <- soil.dect.coef[column.remove]
                
                # Joint landcover and climate prediction
                soil.joint.coef <- t(t(climate.component) + soil.dect.coef)
                soil.joint.truncated.coef <- t(t(climate.component.truncated) + soil.dect.coef)
                
                data$SoilClimJoint <- rowSums(soil.in * plogis(soil.joint.coef))
                data$SoilClimJointTrunc <- rowSums(soil.in * plogis(soil.joint.truncated.coef))
                
                # Evaluation in the focal region
                data.region <- data[data$NR %in% c("Grassland", "Parkland"), ]
                full.joint.auc <- auc(data.region$pcount, data.region$SoilClimJoint)
                full.joint.truncated.auc <- auc(data.region$pcount, data.region$SoilClimJointTrunc)
                
            }
            
            model.fit <- c(climate.auc, climate.truncated.auc, landcover.auc, 
                           full.auc, full.truncated.auc, full.joint.auc, full.joint.truncated.auc)
            names(model.fit) <- c("Climate", "Climate_Truncated", "Landcover", 
                                  "Full", "Full_Truncated", "Full_Joint", "Full_Joint_Truncated")
            return(model.fit)
            
}

