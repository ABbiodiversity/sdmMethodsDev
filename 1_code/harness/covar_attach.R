# ---
# title: Attach Covariates to Records
# author: Brendan Casey
# created: 2026-09-05
# inputs: none
# outputs: none
# notes:
#   - Placeholder. 0_data/covariates/catalogue_v1.csv holds
#     metadata and server paths only; the rasters live on the
#     ABMI server.
#   - The catalogue is extensible - a new catalogue version can
#     add covariates without invalidating the test dataset.
# ---

# 1. attach_covariates() ----

#' Attach Covariates to Records
#'
#' Attaches covariates from the versioned catalogue to records.
#'
#' @param data Data frame of response records with
#'   coordinates.
#' @param catalogue Character. Catalogue version, e.g.
#'   "catalogue_v1".
#' @param covariates Character vector of covariate names to
#'   attach, or NULL for every covariate in the catalogue.
#' @return `data` with one column per attached covariate.
#'
#' @example
#' # Example usage of the function
#' # attach_covariates()
attach_covariates <- function(
  data,
  catalogue = "catalogue_v1",
  covariates = NULL
) {
  # Step 1: Read the catalogue and resolve the layer paths
  # Step 2: Extract at the record coordinates and bind

  stop(
    "attach_covariates() is not implemented yet.",
    call. = FALSE
  )
}

# End of script ----
