# ---
# title: Species hierarchical model functions
# author: Brandon Allen
# created: 2025-02-11
# notes: Define functions that are used for performing the hierarchical modeling process.
# ---

#' [Climate-space models]
#'
#' [Climate and spatial models that uses the spatially thinned data.]
#'
#' @param [species] [Focal species of interest.]
#' @param [data] [Cleaned species, climate, and landcover data.]
#' @param [boot.data] [List of site codes to be included for each species and bootstrap iteration.]
#' @param [climate.models] [List of climate model formulas to be assessed.]
#' @param [bioclim.models] [List of bioclim model formulas to be assessed.]
#' @param [space.models] [List of spatial model formulas to be assessed.]
#' @param [boot] [Defines bootstrap iteration.]
#' @return [Outputs vector of model coefficients defined in climate.models, bioclim.models, and space.models.]
#' 

climate_models <- function(species, data, boot.data, climate.models, bioclim.models, space.models, boot) {
            
            #
            # 1.0 Data standardization 
            #
            
            # Since we are treating each recording individually, we fix visit to 1 as we no longer need to apply this weight.
            data["nQuadrant"] <- 1
            data$visit <- 1 
            
            # Create new column which is the observed count data (used for weighting in the age relationships), one for the converted probabilities
            data["Count"] <- as.integer(ifelse(data[, species] > 0, 1, 0))
            data["pcount"] <- as.integer(ifelse(data[, species] > 0, 1, 0) / data$nQuadrant)
            data["TotalNoOfQU"] <- rep (1, nrow(data)) #Just add 1
            data["wt"] <- rep (1, nrow(data)) #Just add 1
            wt1<-data$TotalNoOfQU*data$wt  # Kept for legacy purposes
            
            # 2.0 Bootstrap Selection
            boot.data <- boot.data[[species]]
            site.id <- boot.data[, paste0("Boot_", boot)]
            data <- data[site.id, ]

            #
            # 3.0 Climate Models 
            #
            
            space.climate.store <- list(NULL) 
            
            for (model in 1:length(climate.models)) {
                        
                        space.climate.store[[model]] <- try(bayesglm(climate.models[[model]], 
                                                                     family = "binomial", 
                                                                     data = data, 
                                                                     maxit = 250))
                        
            }
            
            # Need to make sure all climate models get an update for these two variables
            if(!is.null(bioclim.models)) {
                
                for (model.bioclim in 1:length(bioclim.models)) {
                    
                    # Calculate the length of the current model object and add to it
                    model.list.length <- length(climate.models)
                    
                    for (model.clim in 1:length(climate.models)) {
                        
                        # Define modifier for storing
                        space.climate.store[[model.clim + model.list.length]] <- try(update(space.climate.store[[model.clim]], bioclim.models[[model.bioclim]]))
                        
                    }
                    
                }
                
            }
            
            #
            # 4.0 Spatial Models
            #
            
            if(!is.null(space.models)) {
                
                # Only add spatial updates for models without MAT, TD, PET (keep 1,3,5,6,7,17,19,20,21)
                model.update.id <- c(1, 3, 5, 6, 7, 15, 17, 19, 20, 21)
                
                for (model.clim in model.update.id) {
                    
                    # Calculate the length of the current model object and add to it
                    model.list.length <- length(space.climate.store)
                    
                    for (model.space in 1:length(space.models)) {
                        
                        # Define modifier for storing
                        space.climate.store[[model.space + model.list.length]] <- try(update(space.climate.store[[model.clim]], space.models[[model.space]]))
                        
                    }
                    
                }
                
            }
            
            # 
            # 5.0 Create ensemble and store
            #
            
            modavg.sc <- model.avg(space.climate.store , rank = "AICc")
            aicWtd.sc <- modavg.sc$coefficients["full", ]
            
            # Formatting to align variable names and keep intercept first
            intercept.only <- aicWtd.sc[1]
            names(intercept.only) <- "Intercept"
            aicWtd.sc <- aicWtd.sc[-1]
            aicWtd.sc <- aicWtd.sc[order(names(aicWtd.sc))]
            aicWtd.sc <- c(intercept.only, aicWtd.sc)
            
            return(aicWtd.sc)

}

#' [Vegetation models]
#'
#' [Vegetation models that uses the spatially thinned data.]
#'
#' @param [species] [Focal species of interest.]
#' @param [data] [Cleaned species, climate, and landcover data.]
#' @param [boot.data] [List of site codes to be included for each species and bootstrap iteration.]
#' @param [habitat.models] [List of habitat model formulas to be assessed.]
#' @param [prediction.matrix] [Prediction matrix used for converting model coefficients to standardized habitat classes.]
#' @param [climate.coef] [List of climate coefficients calculated from the detection_models function.]
#' @param [weight.method] [Method used for weighting model coefficients. Inverse variance weighted is the only available method currently.]
#' @param [coef.template] [Vector template used to define valid model coefficients]
#' @param [protocol.flag] [Flag that determines if we need to account for differences in sample protocols]
#' @param [coef.adjust] [Flag used to determine if poorly sampled human footprint coefficients are adjusted based on similar feature types.]
#' @param [boot] [Defines bootstrap iteration.]
#' @return [Outputs vector of model coefficients defined in habitat.models.]
#' 

vegetation_models <- function(species, data, boot.data, habitat.models, prediction.matrix, 
                              climate.coef, weight.method = "IVW", coef.template, 
                              protocol.flag, coef.adjust = TRUE, boot) {
            
            #
            # 1.0 Data standardization 
            #
            
            # Since we are treating each recording individually, we fix visit to 1 as we no longer need to apply this weight.
            data["nQuadrant"] <- 1
            data$visit <- 1 
            
            # Create new column which is the observed count data (used for weighting in the age relationships), one for the converted probabilities
            data["Count"] <- as.integer(ifelse(data[, species] > 0, 1, 0))
            data["pcount"] <- as.integer(ifelse(data[, species] > 0, 1, 0) / data$nQuadrant)
            
            # 1.1 Bootstrap Selection
            boot.data <- boot.data[[species]]
            site.id <- boot.data[, paste0("Boot_", boot)]
            data <- data[site.id, ]
            
            # 1.2 Regional filter
            data <- data[!(data$NR %in% c("Grassland")), ]
            
            # If the number of detections for the species is less than 20, skip
            if(sum(data$Count) < 20) {
                
                coef.results <- coef.template
                coef.se.results <- coef.results
                names(coef.se.results) <- paste0(names(coef.se.results), ".SE")
                coef.results <- c(coef.results, coef.se.results)
                return(coef.results)
                
            }
            
            # 1.3 Define the templates for coefficients
            coef.results <- coef.template
            coef.se.results <- coef.template
            
            #
            # 3.0 Climate Predictions
            #
            
            # Using the matching climate model, create the prediction that will be used
            # Add the intercept and extract climate coefficients
            data$Intercept <- 1
            climate.dect.coef <- climate.coef[[species]][boot, ]
            climate.veg <- as.matrix(data[, names(climate.dect.coef)])
            
            # Predict space/climate component (Probability scale)
            data$Climate <- plogis(drop(climate.veg %*% climate.dect.coef))
            
            #
            # 4.0 Vegetation Model
            #
            
            # Loop through the models
            landscape.store <- list(NULL) 
            
            for (model in 1:length(habitat.models)) {
                        
                        landscape.store[[model]] <- try(bayesglm(habitat.models[[model]], family = "binomial", 
                                                                 data = data, 
                                                                 maxit = 250))
                        
            }
            
            #
            # 5.0 Store the coefficients
            #
            
            nModels <- length(habitat.models)
            p1 <- p1.se <- array(0, c(length(habitat.models), nrow(prediction.matrix))) # Predictions for each model for each soil and HF type type.  These are the main coefficients
            colnames(p1) <- colnames(p1.se) <- rownames(prediction.matrix)
            p.site1 <- p.site1.se <- array(0, c(nModels, nrow(data)))  # Predictions for each model and each site.  These are used as the offsets in the next stage
            
            # If there is a protocol coefficient, add it to the list, otherwise only store the climate coefficient
            if(protocol.flag == TRUE) {
                
                p1.climate <- p1.climate.se <- array(0, c(length(habitat.models), 3))
                colnames(p1.climate) <- colnames(p1.climate.se) <- c("Intercept", "Climate", "Protocol")
                
            } else {
                
                p1.climate <- p1.climate.se <- array(0, c(length(habitat.models), 2))
                colnames(p1.climate) <- colnames(p1.climate.se) <- c("Intercept", "Climate")
                
            }
            
            for (i in 1:nModels) {
                        
                        if (class(landscape.store[[i]])[1] != "try-error") {   # Prediction is 0 if model failed, but this is not used because AIC wt would equal 0
                                    
                            if(protocol.flag == TRUE) {
                                
                                plot.data <- data.frame(prediction.matrix,
                                                        Climate = 0,
                                                        Protocol = as.factor("New"))
                                
                            } else {
                                
                                plot.data <- data.frame(prediction.matrix,
                                                        Climate = 0)
                                
                            }
                            
                                    p <- predict(landscape.store[[i]], newdata = plot.data, se.fit = TRUE)  # For each type.  Predictions made at 0% Aspen.  All predictions made with new protocol.  Aspen effect added later, and plotted as separate points
                                    p1[i,] <- p$fit
                                    p1.se[i,] <- p$se.fit
                                    
                                    model.fit <- predict(landscape.store[[i]], se.fit = TRUE)
                                    p.site1[i,] <- model.fit$fit  # For each site (using the original d.sp data frame)
                                    p.site1.se[i,] <- model.fit$se.fit  # For each site SE
                                    
                                    # Extract the climate and intercept coefficients
                                    # We weight them separately, but then add them together to create the final coefficient
                                    
                                    # Coef storage (Extracts only the number of coefficients equal to object)
                                    p <- summary(landscape.store[[i]])$coefficients[1:ncol(p1.climate),1]  # For each type.
                                    names(p)[1] <- "Intercept"
                                    p1.climate[i, ] <- p
                                    
                                    # Standard error storage
                                    p <- summary(landscape.store[[i]])$coefficients[1:ncol(p1.climate),2]  # For each type.  
                                    names(p)[1] <- "Intercept"
                                    p1.climate.se[i, ] <- p
                                    
                        }
                        
            }
            
            #
            # 6.0 Weight the models
            #
            
            if (weight.method == "IVW") {
                        
                        #
                        # Landcover
                        #
                        
                        tTypeMean <- tTypeVar <- NULL   # Logit-scaled IVW for each veg type
                        
                        mod.converged <- NULL
                        for (i in 1:nModels) {mod.converged[i] <- landscape.store[[i]]$converged}
                        
                        # If there SE is 0 for a coefficient, fix it to a small value to avoid INF 
                        p1.se[p1.se == 0] <- 0.0001
                        
                        for (i in 1:nrow(prediction.matrix)) {
                                    
                                    # Note for me, the SE should be the mean not the sum. Otherwise the SE will converge to 0
                                    tTypeMean[i] <- sum(p1[mod.converged ,i] / p1.se[mod.converged ,i]^2)  / sum(1/p1.se[mod.converged ,i]^2)# IVW mean of  nModels for each veg type, on transformed scale
                                    # Double check this tTypeVar[i]<-  1/mean(1/p1.se[mod.converged ,i]^2 ) # IVW variance of mean...
                                    tTypeVar[i]<-  1/sum(1/p1.se[mod.converged ,i]^2 ) # IVW variance of mean...
                                    
                        }
                        
                        # Weight the site level predictions
                        data$prediction <- colSums(p.site1/ p.site1.se^2) / colSums(1/p.site1.se^2) # Add logit-scaled model average prediction to data frame
                        
                        # Add names
                        names(tTypeMean) <- names(tTypeVar) <- rownames(prediction.matrix)
                        
                        # Put coefficients in Coef matrix (and SE's)
                        coef.results[na.omit(match(names(tTypeMean), names(coef.results)))] <- tTypeMean[names(coef.results)[na.omit(match(names(tTypeMean), names(coef.results)))]] # On logit scale
                        coef.se.results[na.omit(match(names(tTypeVar), names(coef.se.results)))] <- sqrt(tTypeVar[names(coef.se.results)[na.omit(match(names(tTypeVar), names(coef.se.results)))]])  # On logit scale
                        
                        #
                        # Climate
                        #
                        
                        tClimateMean <- tClimateVar <- NULL   # Logit-scaled IVW for each climate
                        
                        mod.converged <- NULL
                        for (i in 1:nModels) {mod.converged[i] <- landscape.store[[i]]$converged}
                        
                        # If there SE is 0 for a coefficient, fix it to a small value to avoid INF 
                        p1.climate.se[p1.climate.se == 0] <- 0.0001
                        
                        for (i in 1:ncol(p1.climate)) {
                                    
                                    # Note for me, the SE should be the mean not the sum. Otherwise the SE will converge to 0
                                    tClimateMean[i] <- sum(p1.climate[mod.converged ,i] / p1.climate.se[mod.converged ,i]^2)  / sum(1/p1.climate.se[mod.converged ,i]^2)# IVW mean of  nModels for each veg type, on transformed scale
                                    # Double check this tTypeVar[i]<-  1/mean(1/p1.se[mod.converged ,i]^2 ) # IVW variance of mean...
                                    tClimateVar[i]<-  1/sum(1/p1.climate.se[mod.converged ,i]^2 ) # IVW variance of mean...
                                    
                        }
                        

                        # Add the intercept coefficient to the table
                        coef.results["Intercept"] <- tClimateMean[1] # On logit scale
                        coef.se.results["Intercept"] <- tClimateVar[1]  # On logit scale
                        
                        # Add the climate coefficient to the table
                        coef.results["Climate"] <- tClimateMean[2] # On logit scale
                        coef.se.results["Climate"] <- tClimateVar[2]  # On logit scale
                        
                        # Store protocol coefficient if modeled
                        if (protocol.flag == TRUE) {
                            
                            coef.results["Protocol"] <- tClimateMean[3] # On logit scale
                            coef.se.results["Protocol"] <- tClimateVar[3]  # On logit scale
                            
                        }

                        
            } 
            
            # # Currently only implement the IWV
            # if (weight.method == "AIC") {
            #             
            #             # AIC calculation  (I'm using AIC here, because this is primarily for prediction, rather than finding a minimial best model)
            #             aic.ta <- rep(999999999, (nModels))
            #             
            #             for (i in 1:(nModels)) {
            #                         
            #                         if (!is.null(landscape.store[[i]]) & class(landscape.store[[i]])[1] != "try-error") {  # last part is to not used non-converged models, unless none converged
            #                                     aic.ta[i] <- AICc(landscape.store[[i]])
            #                         }
            #                         
            #             }
            #             
            #             aic.delta <- aic.ta - min(aic.ta)
            #             aic.exp <- exp(-1 / 2 * aic.delta)
            #             aic.wt.ta <- aic.exp / sum(aic.exp)
            #             
            #             tTypeMean <- tTypeVar <- NULL  # Logit-scaled model averages for each veg type
            #             
            #             aic.wt.ta.adj <- ifelse(aic.wt.ta < 0.01, 0, aic.wt.ta)  # Use adjusted weight to avoid poor fitting models with extreme values for certain types (usually numerically equivalent to 0's or 1's)
            #             aic.wt.ta.adj <- aic.wt.ta.adj / sum(aic.wt.ta.adj)
            #             
            #             # Add the site level prediction based on the ensemble
            #             # Convert to probabilities for the age estimation
            #             data$prediction <- colSums(p.site1 * aic.wt.ta.adj)
            #             
            #             for (i in 1:nrow(prediction.matrix)) {
            #                         
            #                         tTypeMean[i] <- sum(aic.wt.ta.adj * p1[, i])  # Mean of nModels for each veg type, on transformed scale
            #                         #tTypeVar[i] <- sum(aic.wt.ta.adj * sqrt(p1.se[, i]^2 + (rep(tTypeMean[i], nModels) - p1[, i])^2))^2  # AIC-weighted variance of mean...
            #                         
            #             }
            #             
            #             names(tTypeMean) <- rownames(prediction.matrix) # Rename the final intercept coefficient to productive
            #             
            #             # Put coefficients in Coef matrix (and SE's)
            #             coef.results[na.omit(match(names(tTypeMean), names(coef.results)))] <- tTypeMean[names(coef.results)[na.omit(match(names(tTypeMean), names(coef.results)))]] # On logit scale
            #             coef.se.results[na.omit(match(names(tTypeVar), names(coef.se.results)))] <- sqrt(tTypeVar[names(coef.se.results)[na.omit(match(names(tTypeVar), names(coef.se.results)))]])  # On logit scale
            #             
            #             
            # }
            
            #
            # 7.0 Create the forest age relationships
            #
            
            # 7.1 Set up separate dataframes for sites containing a minimum amount of each broad stand type
            stand.data <- list(WhiteSpruce = NULL, Pine = NULL, 
                               Deciduous = NULL, Mixedwood = NULL, 
                               BlackSpruce = NULL)
            
            cutoff.pc.for.age <- 0.1  # Set the cut-off for the minimum proportion of a stand type for a site to be included in the age analysis for a stand type
            pSoftLin <- c(0.049, 0.0893, 0.434, 0.396)  # Values based on overlap of softlin and the stand types in the 1km summary file.  Lowland spruce includes other wetlands. Updated proportions 2020-11-17
            pSoftLin <- pSoftLin / sum(pSoftLin)  # Make sure they sum to zero
            aic.age <- array(NA, c(1, 4)) 
            stand.name <- c("WhiteSpruce", "Pine", "Deciduous", "Mixedwood", "BlackSpruce")
            
            for (i in 0:8) {  # Add sites with each age class of the stand type to a separate data frames for each stand type
                        
                        i1 <- ifelse(i == 0, "R", i)  # For variable name
                        i2 <- ifelse(i == 0, 0.5, i)  # For twenty-year age
                        
                        for (stand.id in 1:length(stand.name)) {
                                    
                                    temp.name <- paste(stand.name[stand.id], i1, sep = "")  # Col name
                                    if (sum(data[ ,temp.name] > cutoff.pc.for.age) > 0) {
                                                
                                                stand.data[[stand.name[stand.id]]] <- rbind(stand.data[[stand.name[stand.id]]], 
                                                                                            data.frame(pCount = data[data[, temp.name] > cutoff.pc.for.age, "Count"] / data$nQuadrant[data[, temp.name] > cutoff.pc.for.age], 
                                                                                                       age = i2, 
                                                                                                       wt1 = data[data[, temp.name] > cutoff.pc.for.age, temp.name]*data$visit[data[, temp.name] > cutoff.pc.for.age]*data$nQuadrant[data[, temp.name] > cutoff.pc.for.age],  
                                                                                                       p = data$prediction[data[, temp.name] > cutoff.pc.for.age]))  # Weight is the proportion of the site of that age class and stand type, multiplied by the original weight (which accounts for revisited sites) and the number of binomial trials
                                                
                                    }
                                    
                        }
                        
            }
            
            rm(stand.name)
            
            # For upland forests, add grass sites as age 1, but with half the normal weight
            d.grass <- data[data[, "Grass"] > cutoff.pc.for.age, ]  # Select sites with grass (to make lines below less unruly)
            pWhiteSpruce <- d.grass$WhiteSpruce / (d.grass$WhiteSpruce + d.grass$Pine + d.grass$Deciduous + d.grass$Mixedwood + d.grass$BlackSpruce + 0.01)
            pPine <- d.grass$Pine / (d.grass$WhiteSpruce + d.grass$Pine + d.grass$Deciduous + d.grass$Mixedwood + d.grass$BlackSpruce + 0.01)
            pDeciduous <- d.grass$Deciduous / (d.grass$WhiteSpruce + d.grass$Pine + d.grass$Deciduous + d.grass$Mixedwood + d.grass$BlackSpruce + 0.01)
            pMixedwood <- d.grass$WhiteSpruce / (d.grass$WhiteSpruce + d.grass$Pine + d.grass$Deciduous + d.grass$Mixedwood + d.grass$BlackSpruce + 0.01)
            
            # If there are no sites to add, don't bind
            if(sum(pWhiteSpruce) != 0) {stand.data$WhiteSpruce <- rbind(stand.data$WhiteSpruce, data.frame(pCount = d.grass[pWhiteSpruce > 0, "Count"] / d.grass$nQuadrant[pWhiteSpruce > 0], age = 0.5, wt1 = d.grass[pWhiteSpruce > 0, "Grass"]/2*d.grass$visit[pWhiteSpruce > 0]*d.grass$nQuadrant[pWhiteSpruce > 0]*pWhiteSpruce[pWhiteSpruce > 0], p = d.grass$prediction[pWhiteSpruce > 0]))}
            if(sum(pPine) != 0) {stand.data$Pine <- rbind(stand.data$Pine, data.frame(pCount = d.grass[pPine > 0, "Count"] / d.grass$nQuadrant[pPine>0], age = 0.5, wt1 = d.grass[pPine>0,"Grass"]/2*d.grass$visit[pPine>0]*d.grass$nQuadrant[pPine>0]*pPine[pPine>0], p = d.grass$prediction[pPine>0]))}
            if(sum(pDeciduous) != 0) {stand.data$Deciduous <- rbind(stand.data$Deciduous, data.frame(pCount = d.grass[pDeciduous > 0, "Count"] / d.grass$nQuadrant[pDeciduous > 0], age = 0.5, wt1 = d.grass[pDeciduous > 0, "Grass"] / 2*d.grass$visit[pDeciduous > 0]*d.grass$nQuadrant[pDeciduous > 0]*pDeciduous[pDeciduous > 0], p = d.grass$prediction[pDeciduous > 0]))}
            if(sum(pMixedwood) != 0) {stand.data$Mixedwood <- rbind(stand.data$Mixedwood, data.frame(pCount = d.grass[pMixedwood > 0, "Count"] / d.grass$nQuadrant[pMixedwood > 0], age = 0.5, wt1 = d.grass[pMixedwood > 0, "Grass"] / 2*d.grass$visit[pMixedwood > 0]*d.grass$nQuadrant[pMixedwood > 0]*pMixedwood[pMixedwood > 0], p = d.grass$prediction[pMixedwood > 0]))}
            
            # And same for sites with shrubs
            d.shrub <- data[data[, "Shrub"] > cutoff.pc.for.age,]  # Select sites with shrubs (to make lines below less unruly)
            pWhiteSpruce <- d.shrub$WhiteSpruce / (d.shrub$WhiteSpruce + d.shrub$Pine + d.shrub$Deciduous + d.shrub$Mixedwood + d.shrub$BlackSpruce + 0.01)
            pPine <- d.shrub$Pine / (d.shrub$WhiteSpruce + d.shrub$Pine + d.shrub$Deciduous + d.shrub$Mixedwood + d.shrub$BlackSpruce + 0.01)
            pDeciduous <- d.shrub$Deciduous / (d.shrub$WhiteSpruce + d.shrub$Pine + d.shrub$Deciduous + d.shrub$Mixedwood + d.shrub$BlackSpruce + 0.01)
            pMixedwood <- d.shrub$WhiteSpruce / (d.shrub$WhiteSpruce + d.shrub$Pine + d.shrub$Deciduous + d.shrub$Mixedwood + d.shrub$BlackSpruce + 0.01)
            
            if(sum(pWhiteSpruce) != 0) {stand.data$WhiteSpruce <- rbind(stand.data$WhiteSpruce, data.frame(pCount = d.shrub[pWhiteSpruce > 0 , "Count"] / d.shrub$nQuadrant[pWhiteSpruce > 0], age = 1, wt1 = d.shrub[pWhiteSpruce > 0, "Shrub"] / 2*d.shrub$visit[pWhiteSpruce > 0]*d.shrub$nQuadrant[pWhiteSpruce > 0]*pWhiteSpruce[pWhiteSpruce > 0], p = d.shrub$prediction[pWhiteSpruce > 0]))}
            if(sum(pPine) != 0) {stand.data$Pine <- rbind(stand.data$Pine, data.frame(pCount = d.shrub[pPine > 0, "Count"] / d.shrub$nQuadrant[pPine > 0], age = 1, wt1 = d.shrub[pPine > 0, "Shrub"] / 2*d.shrub$visit[pPine > 0]*d.shrub$nQuadrant[pPine > 0]*pPine[pPine > 0], p = d.shrub$prediction[pPine > 0]))}
            if(sum(pDeciduous) != 0) {stand.data$Deciduous <- rbind(stand.data$Deciduous, data.frame(pCount = d.shrub[pDeciduous > 0, "Count"] / d.shrub$nQuadrant[pDeciduous > 0], age = 1, wt1 = d.shrub[pDeciduous > 0, "Shrub"] / 2*d.shrub$visit[pDeciduous > 0]*d.shrub$nQuadrant[pDeciduous > 0]*pDeciduous[pDeciduous > 0], p = d.shrub$prediction[pDeciduous > 0]))}
            if(sum(pMixedwood) != 0) {stand.data$Mixedwood <- rbind(stand.data$Mixedwood, data.frame(pCount = d.shrub[pMixedwood > 0, "Count"] / d.shrub$nQuadrant[pMixedwood > 0], age = 1, wt1 = d.shrub[pMixedwood > 0, "Shrub"] / 2*d.shrub$visit[pMixedwood > 0]*d.shrub$nQuadrant[pMixedwood > 0]*pMixedwood[pMixedwood > 0], p = d.shrub$prediction[pMixedwood > 0]))}
            
            # Combined data frames for models using more than one stand type
            stand.data$Conifpine <- rbind(cbind(stand.data$WhiteSpruce, Sp = "WhiteSpruce"), cbind(stand.data$Pine, Sp = "Pine"))
            stand.data$Decidmixed <- rbind(cbind(stand.data$Deciduous, Sp = "Decid"), cbind(stand.data$Mixedwood, Sp = "Mixed"))
            stand.data$All <- rbind(cbind(stand.data$WhiteSpruce, Sp = "WhiteSpruce"), cbind(stand.data$Pine, Sp = "Pine"), cbind(stand.data$Deciduous, Sp = "Decid"), cbind(stand.data$Mixedwood, Sp = "Mixed"), cbind(stand.data$BlackSpruce, Sp = "BlackSpruce"))
            
            # 6.2 Then fit models of age functions
            ndet <- 8
            m.age <- list(NULL)  # Age models for each of the 5 stand types plus 3 combinations
            if (sum(sign(stand.data$WhiteSpruce$pCount)) > ndet) {
                        m.age[[1]] <- gam(pCount~s(sqrt(age),k = 3,m = 2) + offset(p), data = stand.data$WhiteSpruce, family = "binomial", weights = wt1)  # Fit spline through age data for that stand type if enough records
            } else {
                        m.age[[1]] <- gam(pCount~1 + offset(p), data = stand.data$WhiteSpruce, family = "binomial", weights = wt1)  # Fit constant only if too few records in that stand type
            }
            if (sum(sign(stand.data$Pine$pCount)) > ndet) {
                        m.age[[2]] <- gam(pCount~s(sqrt(age),k = 3,m = 2) + offset(p), data = stand.data$Pine, family = "binomial", weights = wt1)
            } else {
                        m.age[[2]] <- gam(pCount~1 + offset(p), data = stand.data$Pine, family = "binomial", weights = wt1)
            }
            if (sum(sign(stand.data$Deciduous$pCount)) > ndet) {
                        m.age[[3]] <- gam(pCount~s(sqrt(age),k = 3,m = 2) + offset(p), data = stand.data$Deciduous, family = "binomial", weights = wt1)
            } else {
                        m.age[[3]] <- gam(pCount~1 + offset(p), data = stand.data$Deciduous, family = "binomial", weights = wt1)
            }
            if (sum(sign(stand.data$Mixedwood$pCount)) > ndet) {
                        m.age[[4]] <- gam(pCount~s(sqrt(age),k = 3,m = 2) + offset(p), data = stand.data$Mixedwood, family = "binomial", weights = wt1)
            } else {
                        m.age[[4]] <- gam(pCount~1 + offset(p), data = stand.data$Mixedwood, family = "binomial", weights = wt1)
            }
            if (sum(sign(stand.data$BlackSpruce$pCount)) > ndet) {
                        m.age[[5]] <- gam(pCount~s(sqrt(age),k = 3,m = 2) + offset(p), data = stand.data$BlackSpruce, family = "binomial", weights = wt1)
            } else {
                        m.age[[5]] <- gam(pCount~1 + offset(p), data = stand.data$BlackSpruce, family = "binomial", weights = wt1)
            }
            if (sum(sign(stand.data$Conifpine$pCount)) > ndet) {
                        m.age[[6]] <- gam(pCount~s(sqrt(age),k = 3,m = 2) + offset(p), data = stand.data$Conifpine, family = "binomial", weights = wt1)
            } else {
                        m.age[[6]] <- gam(pCount~1 + offset(p), data = stand.data$Conifpine, family = "binomial", weights = wt1)
            }
            if (sum(sign(stand.data$Decidmixed$pCount)) > ndet) {
                        m.age[[7]] <- gam(pCount~s(sqrt(age),k = 3,m = 2) + offset(p), data = stand.data$Decidmixed, family = "binomial", weights = wt1)
            } else {
                        m.age[[7]] <- gam(pCount~1 + offset(p), data = stand.data$Decidmixed, family = "binomial", weights = wt1)
            }
            if (sum(sign(stand.data$All$pCount)) > ndet) {
                        m.age[[8]] <- gam(pCount~s(sqrt(age),k = 3,m = 2) + offset(p), data = stand.data$All, family = "binomial", weights = wt1)
            } else {
                        m.age[[8]] <- gam(pCount~1 + offset(p), data = stand.data$All, family = "binomial", weights = wt1)
            }
            
            # Added an intercept only model. Prevents the simple model 8 from producing curves
            # when we effectively have no age relationships. Even if we have enough data to attempt a curve. 
            m.age[[9]] <- gam(pCount~1 + offset(p), data = stand.data$All, family = "binomial", weights = wt1)
            
            # AIC for options - each separate, pairwise combinations, combine all
            aic.age[1,1] <- AIC(m.age[[1]]) + AIC(m.age[[2]]) + AIC(m.age[[3]]) + AIC(m.age[[4]]) + AIC(m.age[[5]])-4  # Minus 4 for the 4 extra variances
            aic.age[1,2] <- AIC(m.age[[5]]) + AIC(m.age[[6]]) + AIC(m.age[[7]])-2
            aic.age[1,3] <- AIC(m.age[[8]])
            aic.age[1,4] <- AIC(m.age[[9]])
            
            # 7.3. Predict coefficients (and logit-scale SE) for each age class for each stand type
            if (which.min(aic.age[1, ]) == 1) {
                        
                        p3 <- predict(m.age[[1]], newdata = data.frame(age = c(0.5,1:8), p = tTypeMean["WhiteSpruce"]), se.fit = T)
                        coef.results[which(names(coef.results) == "WhiteSpruceR"):which(names(coef.results) == "WhiteSpruce8")] <- p3$fit  # Coefficient on logit scale
                        coef.se.results[which(names(coef.results) == "WhiteSpruceR"):which(names(coef.results) == "WhiteSpruce8")] <- p3$se.fit  # SE still on the logit scale
                        
                        p3 <- predict(m.age[[2]], newdata = data.frame(age = c(0.5,1:8), p = tTypeMean["Pine"]), se.fit = T)
                        coef.results[which(names(coef.results) == "PineR"):which(names(coef.results) == "Pine8")] <- p3$fit  # Coefficient on logit scale
                        coef.se.results[which(names(coef.results) == "PineR"):which(names(coef.results) == "Pine8")] <- p3$se.fit  # SE still on the logit scale
                        
                        p3 <- predict(m.age[[3]], newdata = data.frame(age = c(0.5,1:8), p = tTypeMean["Deciduous"]), se.fit = T)
                        coef.results[which(names(coef.results) == "DeciduousR"):which(names(coef.results) == "Deciduous8")] <- p3$fit # Coefficient on logit scale
                        coef.se.results[which(names(coef.results) == "DeciduousR"):which(names(coef.results) == "Deciduous8")] <- p3$se.fit  # SE still on the logit scale
                        
                        p3 <- predict(m.age[[4]], newdata = data.frame(age = c(0.5,1:8), p = tTypeMean["Mixedwood"]), se.fit = T)
                        coef.results[which(names(coef.results) == "MixedwoodR"):which(names(coef.results) == "Mixedwood8")] <- p3$fit  # Coefficient on logit scale
                        coef.se.results[which(names(coef.results) == "MixedwoodR"):which(names(coef.results) == "Mixedwood8")] <- p3$se.fit  # SE still on the logit scale
                        
                        p3 <- predict(m.age[[5]], newdata = data.frame(age = c(0.5,1:8), p = tTypeMean["BlackSpruce"]), se.fit = T)
                        coef.results[which(names(coef.results) == "BlackSpruceR"):which(names(coef.results) == "BlackSpruce8")] <- p3$fit  # Coefficient on logit scale
                        coef.se.results[which(names(coef.results) == "BlackSpruceR"):which(names(coef.results) == "BlackSpruce8")] <- p3$se.fit  # SE still on the logit scale
                        
            }
            
            if (which.min(aic.age[1, ]) == 2) {
                        
                        p3 <- predict(m.age[[6]], newdata = data.frame(age = c(0.5,1:8), p = tTypeMean["WhiteSpruce"]), se.fit = T)
                        coef.results[which(names(coef.results) == "WhiteSpruceR"):which(names(coef.results) == "WhiteSpruce8")] <- p3$fit # Coefficient on logit scale
                        coef.se.results[which(names(coef.results) == "WhiteSpruceR"):which(names(coef.results) == "WhiteSpruce8")] <- p3$se.fit  # SE still on the logit scale
                        
                        p3 <- predict(m.age[[6]], newdata = data.frame(age = c(0.5,1:8), p = tTypeMean["Pine"]), se.fit = T)
                        coef.results[which(names(coef.results) == "PineR"):which(names(coef.results) == "Pine8")] <- p3$fit  # Coefficient on logit scale
                        coef.se.results[which(names(coef.results) == "PineR"):which(names(coef.results) == "Pine8")] <- p3$se.fit  # SE still on the logit scale
                        
                        p3 <- predict(m.age[[7]], newdata = data.frame(age = c(0.5,1:8), p = tTypeMean["Deciduous"]), se.fit = T)
                        coef.results[which(names(coef.results) == "DeciduousR"):which(names(coef.results) == "Deciduous8")] <- p3$fit  # Coefficient on logit scale
                        coef.se.results[which(names(coef.results) == "DeciduousR"):which(names(coef.results) == "Deciduous8")] <- p3$se.fit  # SE still on the logit scale
                        
                        p3 <- predict(m.age[[7]], newdata = data.frame(age = c(0.5,1:8), p = tTypeMean["Mixedwood"]), se.fit = T)
                        coef.results[which(names(coef.results) == "MixedwoodR"):which(names(coef.results) == "Mixedwood8")] <- p3$fit  # Coefficient on logit scale
                        coef.se.results[which(names(coef.results) == "MixedwoodR"):which(names(coef.results) == "Mixedwood8")] <- p3$se.fit  # SE still on the logit scale
                        
                        p3 <- predict(m.age[[5]], newdata = data.frame(age = c(0.5,1:8), p = tTypeMean["BlackSpruce"]), se.fit = T)
                        coef.results[which(names(coef.results) == "BlackSpruceR"):which(names(coef.results) == "BlackSpruce8")] <- p3$fit # Coefficient on logit scale
                        coef.se.results[which(names(coef.results) == "BlackSpruceR"):which(names(coef.results) == "BlackSpruce8")] <- p3$se.fit  # SE still on the logit scale
                        
            }
            
            if (which.min(aic.age[1, ]) == 3) {
                        
                        p3 <- predict(m.age[[8]], newdata = data.frame(age = c(0.5,1:8),  p = tTypeMean["WhiteSpruce"]),  se.fit = T)
                        coef.results[which(names(coef.results) == "WhiteSpruceR"):which(names(coef.results) == "WhiteSpruce8")] <- p3$fit  # Coefficient on logit scale
                        coef.se.results[which(names(coef.results) == "WhiteSpruceR"):which(names(coef.results) == "WhiteSpruce8")] <- p3$se.fit  # SE still on the logit scale
                        
                        p3 <- predict(m.age[[8]], newdata = data.frame(age = c(0.5,1:8),  p = tTypeMean["Pine"]),  se.fit = T)
                        coef.results[which(names(coef.results) == "PineR"):which(names(coef.results) == "Pine8")] <- p3$fit # Coefficient on logit scale
                        coef.se.results[which(names(coef.results) == "PineR"):which(names(coef.results) == "Pine8")] <- p3$se.fit  # SE still on the logit scale
                        
                        p3 <- predict(m.age[[8]], newdata = data.frame(age = c(0.5,1:8),  p = tTypeMean["Deciduous"]),  se.fit = T)
                        coef.results[which(names(coef.results) == "DeciduousR"):which(names(coef.results) == "Deciduous8")] <- p3$fit  # Coefficient on logit scale
                        coef.se.results[which(names(coef.results) == "DeciduousR"):which(names(coef.results) == "Deciduous8")] <- p3$se.fit  # SE still on the logit scale
                        
                        p3 <- predict(m.age[[8]], newdata = data.frame(age = c(0.5,1:8),  p = tTypeMean["Mixedwood"]),  se.fit = T)
                        coef.results[which(names(coef.results) == "MixedwoodR"):which(names(coef.results) == "Mixedwood8")] <- p3$fit  # Coefficient on logit scale
                        coef.se.results[which(names(coef.results) == "MixedwoodR"):which(names(coef.results) == "Mixedwood8")] <- p3$se.fit  # SE still on the logit scale
                        
                        p3 <- predict(m.age[[8]], newdata = data.frame(age = c(0.5,1:8),  p = tTypeMean["BlackSpruce"]),  se.fit = T)
                        coef.results[which(names(coef.results) == "BlackSpruceR"):which(names(coef.results) == "BlackSpruce8")] <- p3$fit  # Coefficient on logit scale
                        coef.se.results[which(names(coef.results) == "BlackSpruceR"):which(names(coef.results) == "BlackSpruce8")] <- p3$se.fit  # SE still on the logit scale
                        
            }
            
            
            if (which.min(aic.age[1, ]) == 4) {
                        
                        p3 <- predict(m.age[[9]], newdata = data.frame(age = c(0.5,1:8),  p = tTypeMean["WhiteSpruce"]),  se.fit = T)
                        coef.results[which(names(coef.results) == "WhiteSpruceR"):which(names(coef.results) == "WhiteSpruce8")] <- p3$fit  # Coefficient on logit scale
                        coef.se.results[which(names(coef.results) == "WhiteSpruceR"):which(names(coef.results) == "WhiteSpruce8")] <- p3$se.fit  # SE still on the logit scale
                        
                        p3 <- predict(m.age[[9]], newdata = data.frame(age = c(0.5,1:8),  p = tTypeMean["Pine"]),  se.fit = T)
                        coef.results[which(names(coef.results) == "PineR"):which(names(coef.results) == "Pine8")] <- p3$fit # Coefficient on logit scale
                        coef.se.results[which(names(coef.results) == "PineR"):which(names(coef.results) == "Pine8")] <- p3$se.fit  # SE still on the logit scale
                        
                        p3 <- predict(m.age[[9]], newdata = data.frame(age = c(0.5,1:8),  p = tTypeMean["Deciduous"]),  se.fit = T)
                        coef.results[which(names(coef.results) == "DeciduousR"):which(names(coef.results) == "Deciduous8")] <- p3$fit  # Coefficient on logit scale
                        coef.se.results[which(names(coef.results) == "DeciduousR"):which(names(coef.results) == "Deciduous8")] <- p3$se.fit  # SE still on the logit scale
                        
                        p3 <- predict(m.age[[9]], newdata = data.frame(age = c(0.5,1:8),  p = tTypeMean["Mixedwood"]),  se.fit = T)
                        coef.results[which(names(coef.results) == "MixedwoodR"):which(names(coef.results) == "Mixedwood8")] <- p3$fit  # Coefficient on logit scale
                        coef.se.results[which(names(coef.results) == "MixedwoodR"):which(names(coef.results) == "Mixedwood8")] <- p3$se.fit  # SE still on the logit scale
                        
                        p3 <- predict(m.age[[9]], newdata = data.frame(age = c(0.5,1:8),  p = tTypeMean["BlackSpruce"]),  se.fit = T)
                        coef.results[which(names(coef.results) == "BlackSpruceR"):which(names(coef.results) == "BlackSpruce8")] <- p3$fit  # Coefficient on logit scale
                        coef.se.results[which(names(coef.results) == "BlackSpruceR"):which(names(coef.results) == "BlackSpruce8")] <- p3$se.fit  # SE still on the logit scale
                        
            }
            
            # Will need to think of something else
            # # 7.4 Adjust SE for estimates that are numerically equivalent to 0 - use exact binomial CI
            # i4 <- which(is.na(coef.results) | coef.results < 0.0001)
            # coef.results[i4] <- 0.0001
            # ntrials <- (colSums(data[, match(names(coef.results), names(data), nomatch = 0)])*2) + 1  # *2 because many rare types (which have the 0's are estimated from groups of types),  + 1 to avoid failure for old cutblocks, 
            # for (i5 in i4) coef.se.results[i5] <-  (qlogis(binom.confint(0, ntrials[i5], conf.level = 0.9)[5,6]) - qlogis(0.0001)) / 1.65 # That conf/level gives 1SE.  Value is on logit scale, assuming estimate of 0.0001.  This is set up so that when 90% CI's are ploted below, they will return the exact 90% binom confints
            
            # 7.5 Converge CC to natural trajectory
            # Weighting is done on the probabilities
            # Smooth CC trajectories into natural ones
            coef.results["CCWhiteSpruce2"] <- qlogis(plogis(coef.results["WhiteSpruce2"])*0.50 + plogis(coef.results["CCWhiteSpruce2"])*(1-0.50))  # WhiteSpruce CC 20-40yr is 50% of way to 20-40yr natural forest - see document on convergence rates
            coef.results["CCWhiteSpruce3"] <- qlogis(plogis(coef.results["WhiteSpruce3"])*0.849 + plogis(coef.results["CCWhiteSpruce3"])*(1-0.849))  # WhiteSpruce CC 40-60yr is 84.9% of way to 40-60yr natural forest
            coef.results["CCWhiteSpruce4"] <- qlogis(plogis(coef.results["WhiteSpruce4"])*0.96 + plogis(coef.results["CCWhiteSpruce4"])*(1-0.96))  # WhiteSpruce CC 60-80yr is 96% of way to 60-80yr natural forest
            coef.results["CCPine2"] <- qlogis(plogis(coef.results["Pine2"])*0.50 + plogis(coef.results["CCPine2"])*(1-0.50))  # Pine CC 20-40 is 50% of way to 20-40yr natural forest - see document on convergence rates
            coef.results["CCPine3"] <- qlogis(plogis(coef.results["Pine3"])*0.849 + plogis(coef.results["CCPine3"])*(1-0.849))  # Pine CC 40-60 is 84.9% of way to 40-60yr natural forest
            coef.results["CCPine4"] <- qlogis(plogis(coef.results["Pine4"])*0.96 + plogis(coef.results["CCPine4"])*(1-0.96))  # Pine CC 60-80 is 96% of way to 60-80yr natural forest
            coef.results["CCDeciduous2"] <- qlogis(plogis(coef.results["Deciduous2"])*0.705 + plogis(coef.results["CCDeciduous2"])*(1-0.705))  # Decid CC 20-40yr is 70.5% of way to 20-40yr natural forest - see document on convergence rates
            coef.results["CCDeciduous3"] <- qlogis(plogis(coef.results["Deciduous3"])*0.912 + plogis(coef.results["CCDeciduous3"])*(1-0.912))  # Decid CC 40-60yr is 91.2% of way to 40-60yr natural forest
            coef.results["CCDeciduous4"] <- qlogis(plogis(coef.results["Deciduous4"])*0.97 + plogis(coef.results["CCDeciduous4"])*(1-0.97)) # Decid CC 60-80yr is 97% of way to 60-80yr natural forest
            coef.results["CCMixedwood2"] <- qlogis(plogis(coef.results["Mixedwood2"])*0.705 + plogis(coef.results["CCMixedwood2"])*(1-0.705))  # Mixedwood CC 20-40yr is 70.5% of way to 20-40yr natural forest - see document on convergence rates
            coef.results["CCMixedwood3"] <- qlogis(plogis(coef.results["Mixedwood3"])*0.912 + plogis(coef.results["CCMixedwood3"])*(1-0.912))  # Mixedwood CC 40-60yr is 91.2% of way to 40-60yr natural forest
            coef.results["CCMixedwood4"] <- qlogis(plogis(coef.results["Mixedwood4"])*0.97 + plogis(coef.results["CCMixedwood4"])*(1-0.97))  # Mixedwood CC 60-80yr is 97% of way to 60-80yr natural forest
            
            # And same for SE's
            coef.se.results["CCWhiteSpruce2"] <- coef.se.results["WhiteSpruce2"]*0.50 + coef.se.results["CCWhiteSpruce2"]*(1-0.50)  
            coef.se.results["CCWhiteSpruce3"] <- coef.se.results["WhiteSpruce3"]*0.849 + coef.se.results["CCWhiteSpruce3"]*(1-0.849)
            coef.se.results["CCWhiteSpruce4"] <- coef.se.results["WhiteSpruce4"]*0.96 + coef.se.results["CCWhiteSpruce4"]*(1-0.96) 
            coef.se.results["CCPine2"] <- coef.se.results["Pine2"]*0.50 + coef.se.results["CCPine2"]*(1-0.50)
            coef.se.results["CCPine3"] <- coef.se.results["Pine3"]*0.849 + coef.se.results["CCPine3"]*(1-0.849)
            coef.se.results["CCPine4"] <- coef.se.results["Pine4"]*0.96 + coef.se.results["CCPine4"]*(1-0.96)
            coef.se.results["CCDeciduous2"] <- coef.se.results["Deciduous2"]*0.705 + coef.se.results["CCDeciduous2"]*(1-0.705)
            coef.se.results["CCDeciduous3"] <- coef.se.results["Deciduous3"]*0.912 + coef.se.results["CCDeciduous3"]*(1-0.912)
            coef.se.results["CCDeciduous4"] <- coef.se.results["Deciduous4"]*0.97 + coef.se.results["CCDeciduous4"]*(1-0.97)
            coef.se.results["CCMixedwood2"] <- coef.se.results["Mixedwood2"]*0.705 + coef.se.results["CCMixedwood2"]*(1-0.705)
            coef.se.results["CCMixedwood3"] <- coef.se.results["Mixedwood3"]*0.912 + coef.se.results["CCMixedwood3"]*(1-0.912)
            coef.se.results["CCMixedwood4"] <- coef.se.results["Mixedwood4"]*0.97 + coef.se.results["CCMixedwood4"]*(1-0.97)                
            
            #
            # 8.0 Adjust coefficients that are often estimated poorly.
            # 
            
            if (coef.adjust == TRUE) { # If true, adjust coefficients, otherwise leave as is. Can help to determine how much the adjustment is needed
                        
                        coef.results["HardLin"] <- (coef.results["HardLin"] / coef.se.results["HardLin"]^2 + coef.results["UrbInd"]/coef.se.results["UrbInd"]^2) / (1 / coef.se.results["HardLin"]^2 + 1 / coef.se.results["UrbInd"]^2)   # Inverse-variance weighted, done on logit scale
                        coef.se.results["HardLin"] <- sqrt(1 / (1 / coef.se.results["HardLin"]^2 + 1 / coef.se.results["UrbInd"]^2))
                        
                        young <- (pSoftLin[1]*coef.results["CCWhiteSpruceR"] + pSoftLin[2]*coef.results["CCPineR"] + pSoftLin[3]*coef.results["CCDeciduousR"] + pSoftLin[4]*coef.results["BlackSpruce1"]) / sum(pSoftLin)  
                        young.se <- sqrt( ( pSoftLin[1]*coef.se.results["CCWhiteSpruceR"]^2 + pSoftLin[2]*coef.se.results["CCPineR"]^2 + pSoftLin[3]*coef.se.results["CCDeciduousR"]^2 + pSoftLin[4]*coef.se.results["BlackSpruce1"]^2 ) / sum(pSoftLin) )  # Weighted se (on logit scale) - does not include component of variance among types, because fixed weighting
                        
                        # Adjust for the three soft linear type coefficients (EnSoftLin, EnSeismic, TrSoftLin)
                        coef.results["EnSoftLin"] <- (coef.results["EnSoftLin"]/coef.se.results["EnSoftLin"]^2 + young / young.se^2) / (1 / coef.se.results["EnSoftLin"]^2 + 1 / young.se^2)  # Inverse-variance weighted
                        coef.se.results["EnSoftLin"] <- sqrt(1 / (1 / coef.se.results["EnSoftLin"]^2 + 1 / young.se^2))
                        
                        coef.results["EnSeismic"] <- (coef.results["EnSeismic"]/coef.se.results["EnSeismic"]^2 + young / young.se^2) / (1 / coef.se.results["EnSeismic"]^2 + 1 / young.se^2)  # Inverse-variance weighted
                        coef.se.results["EnSeismic"] <- sqrt(1 / (1 / coef.se.results["EnSeismic"]^2 + 1 / young.se^2))
                        
                        coef.results["TrSoftLin"] <- (coef.results["TrSoftLin"]/coef.se.results["TrSoftLin"]^2 + young / young.se^2) / (1 / coef.se.results["TrSoftLin"]^2 + 1 / young.se^2)  # Inverse-variance weighted
                        coef.se.results["TrSoftLin"] <- sqrt(1 / (1 / coef.se.results["TrSoftLin"]^2 + 1 / young.se^2))
                        
                        rm(young, young.se)
                        
            } 
            
            # Store the coefficients as a single object
            names(coef.se.results) <- paste0(names(coef.se.results), ".SE")
            coef.results <- c(coef.results, coef.se.results)
            return(coef.results)
            
            
}

#' [Soil models]
#'
#' [soil models that uses the spatially thinned data.]
#'
#' @param [species] [Focal species of interest.]
#' @param [data] [Cleaned species, climate, and landcover data.]
#' @param [boot.data] [List of site codes to be included for each species and bootstrap iteration.]
#' @param [habitat.models] [List of habitat model formulas to be assessed.]
#' @param [prediction.matrix] [Prediction matrix used for converting model coefficients to standardized habitat classes.]
#' @param [climate.coef] [List of climate coefficients calculated from the detection_models function.]
#' @param [weight.method] [Method used for weighting model coefficients. Inverse variance weighted is the only available method currently.]
#' @param [coef.template] [Vector template used to define valid model coefficients]
#' @param [protocol.flag] [Flag that determines if we need to account for differences in sample protocols]
#' @param [coef.adjust] [Flag used to determine if poorly sampled human footprint coefficients are adjusted based on similar feature types.]
#' @param [boot] [Defines bootstrap iteration.]
#' @return [Outputs vector of model coefficients defined in habitat.models.]
#' 

soil_models <- function(species, data, boot.data, habitat.models, prediction.matrix, 
                        climate.coef, weight.method = "IVW", coef.template, 
                        protocol.flag, coef.adjust = TRUE, boot) {
            
            #
            # 1.0 Data standardization 
            #
            
            # Since we are treating each recording individually, we fix visit to 1 as we no longer need to apply this weight.
            data["nQuadrant"] <- 1
            data$visit <- 1 
            
            # Create new column which is the observed count data (used for weighting in the age relationships), one for the converted probabilities
            data["Count"] <- as.integer(ifelse(data[, species] > 0, 1, 0))
            data["pcount"] <- as.integer(ifelse(data[, species] > 0, 1, 0) / data$nQuadrant)
            
            # 1.1 Bootstrap Selection
            boot.data <- boot.data[[species]]
            site.id <- boot.data[, paste0("Boot_", boot)]
            data <- data[site.id, ]
            
            # 1.2 Regional filter
            data <- data[data$NR %in% c("Grassland", "Parkland"), ]
            
            # If the number of detections for the species is less than 20, return empty matrix
            if(sum(data$Count) < 20) {
                
                coef.results <- coef.template
                coef.se.results <- coef.results
                names(coef.se.results) <- paste0(names(coef.se.results), ".SE")
                coef.results <- c(coef.results, coef.se.results)
                return(coef.results)
                
                }
            
            # 1.3 Define the templates for coefficients
            coef.results <- coef.template
            coef.se.results <- coef.template
            
            #
            # 3.0 Climate Predictions
            #
            
            # Using the matching climate model, create the prediction that will be used
            # Add the intercept and extract climate coefficients
            data$Intercept <- 1
            climate.dect.coef <- climate.coef[[species]][boot, ]
            climate.veg <- as.matrix(data[, names(climate.dect.coef)])
            
            # Predict space/climate component (Probability scale)
            data$Climate <- plogis(drop(climate.veg %*% climate.dect.coef))
            
            #
            # 4.0 Soil Model
            #
            
            # Loop through the models
            landscape.store <- list(NULL) 
            
            for (model in 1:length(habitat.models)) {
                        
                        landscape.store[[model]] <- try(bayesglm(habitat.models[[model]], family = "binomial", 
                                                                 data = data, 
                                                                 maxit = 250))
                        
            }
            
            #
            # 4.0 Store the coefficients
            #
            
            # South model needs to account for the addition of the probability of aspen coefficient, otherwise the processes is similar. 
            nModels <- length(habitat.models)
            p1 <- p1.se <- array(0, c(length(habitat.models), nrow(prediction.matrix))) # Predictions for each model for each soil and HF type type.  These are the main coefficients
            colnames(p1) <- colnames(p1.se) <- rownames(prediction.matrix)
            p.site1 <- p.site1.se <- array(0, c(nModels, nrow(data)))  # Predictions for each model and each site.  These are used as the offsets in the next stage

            # If there is a protocol coefficient, add it to the list, otherwise only store the climate coefficient
            if(protocol.flag == TRUE) {
                
                p1.climate <- p1.climate.se <- array(0, c(length(habitat.models), 3))
                colnames(p1.climate) <- colnames(p1.climate.se) <- c("Intercept", "Climate", "Protocol")
                
            } else {
                
                p1.climate <- p1.climate.se <- array(0, c(length(habitat.models), 2))
                colnames(p1.climate) <- colnames(p1.climate.se) <- c("Intercept", "Climate")
                
            }
            
            p1.aspen <- p1.se.aspen <- rep(0, nModels)  # Predictions for each model for aspen coefficient
            
            for (i in 1:nModels) {
                        
                        if (class(landscape.store[[i]])[1] != "try-error") {   # Prediction is 0 if model failed, but this is not used because AIC wt would equal 0
                                    
                            if(protocol.flag == TRUE) {
                                
                                plot.data <- data.frame(prediction.matrix,
                                                        Climate = 0,
                                                        paspen = 0,
                                                        Protocol = as.factor("New"))
                                
                            } else {
                                
                                plot.data <- data.frame(prediction.matrix,
                                                        paspen = 0,
                                                        Climate = 0)
                                
                            }
                            
                                    p <- predict(landscape.store[[i]], newdata = plot.data, se.fit = TRUE)  # For each type.  Predictions made at 0% Aspen.  All predictions made with new protocol.  Aspen effect added later, and plotted as separate points
                                    p1[i,] <- p$fit
                                    p1.se[i,] <- p$se.fit
                                    
                                    model.fit <- predict(landscape.store[[i]], se.fit = TRUE)
                                    p.site1[i,] <- model.fit$fit  # For each site (using the original d.sp data frame)
                                    p.site1.se[i,] <- model.fit$se.fit  # For each site SE
                                    
                                    # Extract the climate and intercept coefficients
                                    # We weight them separately, but then add them together to create the final coefficient
                                    
                                    # Coef storage
                                    p <- summary(landscape.store[[i]])$coefficients[1:ncol(p1.climate),1]  # For each type.  Predictions made at 0% Aspen.  All predictions made with new protocol.  Aspen effect added later, and plotted as separate points
                                    names(p)[1] <- "Intercept"
                                    p1.climate[i, ] <- p
                                    
                                    # Standard error storage
                                    p <- summary(landscape.store[[i]])$coefficients[1:ncol(p1.climate),2]  # For each type.  Predictions made at 0% Aspen.  All predictions made with new protocol.  Aspen effect added later, and plotted as separate points
                                    names(p)[1] <- "Intercept"
                                    p1.climate.se[i, ] <- p
                                    
                                    # If pasen is present, store the coefficient
                                    if ("paspen" %in% names(coef(landscape.store[[i]]))) {
                                                p1.aspen[i] <- coefficients(summary(landscape.store[[i]]))["paspen","Estimate"]
                                                p1.se.aspen[i] <- coefficients(summary(landscape.store[[i]]))["paspen","Std. Error"]
                                    }
                                    
                        }
                        
            }
            
            #
            # 5.0 Weight the models
            #
            
            if (weight.method == "IVW") {
                        
                        #
                        # Landcover
                        #
                        
                        tTypeMean <- tTypeVar <- NULL   # Logit-scaled IVW for each veg type
                        
                        mod.converged <- NULL
                        for (i in 1:nModels) {mod.converged[i] <- landscape.store[[i]]$converged}
                        
                        for (i in 1:nrow(prediction.matrix)) {
                                    
                                    tTypeMean[i] <- sum(p1[mod.converged ,i] / p1.se[mod.converged ,i]^2)  / sum(1/p1.se[mod.converged ,i]^2)# IVW mean of  nModels for each veg type, on transformed scale
                                    tTypeVar[i]<-  1/sum(1/p1.se[mod.converged ,i]^2 ) # IVW variance of mean...
                                    
                        }
                        
                        # Add names
                        names(tTypeMean) <- names(tTypeVar) <- rownames(prediction.matrix)
                        
                        # If paspen coefficients / SE is 0, remove
                        p1.aspen <- p1.aspen[p1.aspen > 0]
                        p1.se.aspen <- p1.se.aspen[p1.se.aspen > 0]
                        
                        tTypeMean["paspen"] <- sum(p1.aspen / p1.se.aspen^2) / sum(1 / p1.se.aspen^2)
                        tTypeVar["paspen"] <-  1/sum(1/p1.se.aspen^2 ) # IVWvariance of mean...
                        
                        # Put coefficients in Coef matrix (and SE's)
                        coef.results[na.omit(match(names(tTypeMean), names(coef.results)))] <- tTypeMean[names(coef.results)[na.omit(match(names(tTypeMean), names(coef.results)))]] # On logit scale
                        coef.se.results[na.omit(match(names(tTypeVar), names(coef.se.results)))] <- sqrt(tTypeVar[names(coef.se.results)[na.omit(match(names(tTypeVar), names(coef.se.results)))]])  # On logit scale
                        
                        
                        #
                        # Climate
                        #
                        
                        tClimateMean <- tClimateVar <- NULL   # Logit-scaled IVW for each climate
                        
                        mod.converged <- NULL
                        for (i in 1:nModels) {mod.converged[i] <- landscape.store[[i]]$converged}
                        
                        # If there SE is 0 for a coefficient, fix it to a small value to avoid INF 
                        p1.climate.se[p1.climate.se == 0] <- 0.0001
                        
                        for (i in 1:ncol(p1.climate)) {
                                    
                                    # Note for me, the SE should be the mean not the sum. Otherwise the SE will converge to 0
                                    tClimateMean[i] <- sum(p1.climate[mod.converged ,i] / p1.climate.se[mod.converged ,i]^2)  / sum(1/p1.climate.se[mod.converged ,i]^2)# IVW mean of  nModels for each veg type, on transformed scale
                                    # Double check this tTypeVar[i]<-  1/mean(1/p1.se[mod.converged ,i]^2 ) # IVW variance of mean...
                                    tClimateVar[i]<-  1/sum(1/p1.climate.se[mod.converged ,i]^2 ) # IVW variance of mean...
                                    
                        }
                        
                        # Add the intercept coefficient to the table
                        coef.results["Intercept"] <- tClimateMean[1] # On logit scale
                        coef.se.results["Intercept"] <- tClimateVar[1]  # On logit scale
                        
                        # Add the climate coefficient to the table
                        coef.results["Climate"] <- tClimateMean[2] # On logit scale
                        coef.se.results["Climate"] <- tClimateVar[2]  # On logit scale
                        
                        # Store protocol coefficient if modeled
                        if (protocol.flag == TRUE) {
                            
                            coef.results["Protocol"] <- tClimateMean[3] # On logit scale
                            coef.se.results["Protocol"] <- tClimateVar[3]  # On logit scale
                            
                        }
                        
            } 
            
            # Don't currently use this method of weighting
            # if (weight.method == "AIC") { 
            #             
            #             
            #             # AIC calculation  (I'm using AIC here, because this is primarily for prediction, rather than finding a minimial best model)
            #             aic.ta <- rep(999999999, (nModels))
            #             
            #             for (i in 1:(nModels)) {
            #                         
            #                         if (!is.null(landscape.store[[i]]) & class(landscape.store[[i]])[1] != "try-error") {  # last part is to not used non-converged models, unless none converged
            #                                     aic.ta[i] <- AICc(landscape.store[[i]])
            #                         }
            #                         
            #             }
            #             
            #             aic.delta <- aic.ta - min(aic.ta)
            #             aic.exp <- exp(-1 / 2 * aic.delta)
            #             aic.wt.ta <- aic.exp / sum(aic.exp)
            #             
            #             tTypeMean <- tTypeVar <- NULL  # Logit-scaled model averages for each veg type
            #             
            #             aic.wt.ta.adj <- ifelse(aic.wt.ta < 0.01, 0, aic.wt.ta)  # Use adjusted weight to avoid poor fitting models with extreme values for certain types (usually numerically equivalent to 0's or 1's)
            #             aic.wt.ta.adj <- aic.wt.ta.adj / sum(aic.wt.ta.adj)
            #             
            #             for (i in 1:ncol(p1)) {
            #                         
            #                         tTypeMean[i] <- sum(aic.wt.ta.adj * p1[, i])  
            #                         tTypeVar[i] <- sum(aic.wt.ta.adj * p1.se[, i]) 
            #                         
            #             }
            #             
            #             # Add names
            #             names(tTypeMean) <- names(tTypeVar) <- rownames(prediction.matrix)
            #             
            #             # Adjust the paspen variable as it isn't in all of the models
            #             mod.converged[p1[, "paspen"] == 0] <- FALSE
            #             tTypeMean["paspen"] <- sum(p1[mod.converged ,"paspen"] / p1.se[mod.converged ,"paspen"]^2)  / sum(1/p1.se[mod.converged ,"paspen"]^2)# IVW mean of  nModels for each veg type, on transformed scale
            #             tTypeVar["paspen"] <-  1/sum(1/p1.se[mod.converged ,"paspen"]^2 ) # IVW variance of mean...
            #             
            #             # Put coefficients in Coef matrix (and SE's)
            #             coef.results[na.omit(match(names(tTypeMean), names(coef.results)))] <- tTypeMean[names(coef.results)[na.omit(match(names(tTypeMean), names(coef.results)))]] # On logit scale
            #             coef.se.results[na.omit(match(names(tTypeVar), names(coef.se.results)))] <- sqrt(tTypeVar[names(coef.se.results)[na.omit(match(names(tTypeVar), names(coef.se.results)))]])  # On logit scale
            #             
            #             
            #             }
            
            #
            # 7.0 Adjust coefficients that are often estimated poorly.
            # 
            
            if (coef.adjust == TRUE) { # If true, adjust coefficients, otherwise leave as is. Can help to determine how much the adjustment is needed
                        
                        coef.results["HardLin"] <- (coef.results["HardLin"] / coef.se.results["HardLin"]^2 + coef.results["UrbInd"]/coef.se.results["UrbInd"]^2) / (1 / coef.se.results["HardLin"]^2 + 1 / coef.se.results["UrbInd"]^2)   # Inverse-variance weighted, done on logit scale
                        coef.se.results["HardLin"] <- sqrt(1 / (1 / coef.se.results["HardLin"]^2 + 1 / coef.se.results["UrbInd"]^2))
                        
            } 
            
            # Store the coefficients as a single object
            names(coef.se.results) <- paste0(names(coef.se.results), ".SE")
            coef.results <- c(coef.results, coef.se.results)
            return(coef.results)
            
}
