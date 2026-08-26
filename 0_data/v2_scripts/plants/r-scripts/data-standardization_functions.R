# ---
# title: Data cleaning functions
# author: Brandon Allen
# created: 2025-02-11
# notes: Define functions that are used standardizing the landcover data
# ---

#' [Landscape summaries]
#'
#' [Simplifies landcover data based on provided lookup tables.]
#'
#' @param [data.in] [Cleaned species and landcover data.]
#' @param [landscape.lookup] [Lookup table for vegetation or soil classes.]
#' @param [class.in] [Column code for current landcover classes.]
#' @param [class.out] [Column code for new landcover classes.]
#' @return [Outputs data frame of landcover summaries with the newly defined habitat groups.]
#' 

landscape_hf_summary <- function(data.in, landscape.lookup, class.in, class.out) {
        
        # Matching of lookup tables and merging native features
        landscape.lookup <- landscape.lookup[landscape.lookup[, class.in] %in% colnames(data.in), ]
        landscape.clean <- matrix(nrow = nrow(data.in), ncol = length(unique(landscape.lookup[, class.out])))
        
        for (abmi.coef in 1:length(unique(landscape.lookup[, class.out]))) {
                
                coef.temp <- as.character(landscape.lookup[landscape.lookup[, class.out] %in% as.character(unique(landscape.lookup[, class.out]))[abmi.coef], class.in])
                
                if(length(coef.temp) == 1) {
                        
                        landscape.clean[, abmi.coef] <- data.in[, coef.temp]
                        
                } else {
                        
                        landscape.clean[, abmi.coef] <- rowSums(data.in[, coef.temp])
                        
                }
                
        }
        
        colnames(landscape.clean) <- as.character(unique(landscape.lookup[, class.out]))
        rownames(landscape.clean) <- rownames(data.in)
        
        return(landscape.clean)
        
}
