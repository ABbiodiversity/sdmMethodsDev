# ---
# title: Generate Bootstrap Site Ids (Plant Groups)
# author: Brendan Casey
# created: 2026-09-08
# inputs:
#   set by the calling experiment, or defaulted in 1.2:
#     - taxon, data_dir, run_dir, species_subset, boot_iter,
#       n_clusters
#   in data_dir:
#     - <taxon>.csv, sites.csv, covariates/, lookup/
#   in this repository:
#     - 1_code/modules/plants/load_model_data.R
#     - 1_code/modules/plants/functions/bootstrapping_functions.R
# outputs:
#   in run_dir:
#     - bootstrap/<taxon>-bootstrap-ids.Rdata (bootstrap.ids)
# notes:
#   - Rewrite of the v2 script 01b_bootstrapping.R, which held
#     the same four blocks one after another in a single file and
#     wrote back over the model-data files. This one takes the
#     taxon as a parameter and writes only the bootstrap ids, so
#     nothing in 0_data/ is modified by a run.
#   - Each species gets its own set of ids because the thinning
#     depends on where that species was detected. Iteration 1 is
#     the complete data set by construction, and 2 onward
#     resample sites within spatial blocks with replacement.
#   - The block grid is the v2 grid: longitude cut at -121, -116,
#     -112 and -109, latitude at 48, 51, 54, 57 and 61, with the
#     interaction relabelled a, b, c and so on.
#   - The ids are SiteYearQu values, which is what the
#     hierarchical models and the validation both index on.
#   - Bootstrapping resamples, so a run is only reproducible if
#     the seed is fixed. v2 set none. `boot_seed` defaults to
#     NULL, which reproduces v2 exactly; set it to make a run
#     repeatable.
#   - The species selection is `species_subset`, not `species`.
#     The v2 code loops with `for (species in species.list)`,
#     which would otherwise overwrite the selection and leave the
#     next stage running on one species.
#   - Future improvement - ids are generated for every modelled
#     species even when a later stage runs on a subset, because
#     the v2 code reads them as boot.data[[species]] and ignores
#     extras. Passing `species` here narrows both.
# ---

# 1. Setup ----

## 1.1 Load packages ----
library(foreach) # sequential %dopar% loop, as in v2 (version: 1.5.2)
library(parallel) # species-level parallelism (version: 4.5.0)

## 1.2 Configure the run ----
# Values a calling experiment has already set are kept, so this
# script runs either from 1_code/experiments/ or on its own.
if (!exists("project_root", inherits = FALSE)) {
  project_root <- normalizePath(getwd(), winslash = "/")
}

if (!exists("taxon", inherits = FALSE)) {
  taxon <- "bryophyte"
}

if (!exists("data_dir", inherits = FALSE)) {
  data_dir <- file.path(project_root, "0_data/test_dataset")
}

if (!exists("run_dir", inherits = FALSE)) {
  run_dir <- file.path(project_root, "2_pipeline/plants")
}

# NULL generates ids for every species the snapshot declares as
# modelled.
if (!exists("species_subset", inherits = FALSE)) {
  species_subset <- NULL
}

# The v2 defaults. 01b used 16 cores where 02 used 14.
if (!exists("boot_iter", inherits = FALSE)) {
  boot_iter <- 1:100
}

if (!exists("n_clusters", inherits = FALSE)) {
  n_clusters <- 16
}

# Minimum detections for a region's model to be considered
# viable, as in v2.
if (!exists("boot_threshold", inherits = FALSE)) {
  boot_threshold <- 20
}

# NULL leaves the stream unseeded, which is what v2 did.
if (!exists("boot_seed", inherits = FALSE)) {
  boot_seed <- NULL
}

## 1.3 Load functions and data ----
source(file.path(
  project_root, "1_code/modules/plants/load_model_data.R"
))
source(file.path(
  project_root,
  "1_code/modules/plants/functions/bootstrapping_functions.R"
))

model_data <- load_plant_model_data(
  taxon = taxon,
  data_dir = data_dir,
  species = species_subset
)

climate.data <- model_data$climate.data

species.list <- unique(c(
  model_data$veg.species.list,
  model_data$soil.species.list
))

## 1.4 Create the output folder ----
# save() does not create a missing folder.
dir.create(
  file.path(run_dir, "bootstrap"),
  recursive = TRUE, showWarnings = FALSE
)

# 2. Define the bootstrap blocks ----
# Sites are resampled within coarse latitude and longitude
# blocks, so a bootstrap sample keeps the geographic spread of
# the original data rather than drifting toward whichever region
# happens to be best surveyed.

## 2.1 Cut the study area into blocks ----
site.block <- data.frame(
  LongBlock = cut(
    climate.data$Long, c(-121, -116, -112, -109)
  ),
  LatBlock = cut(
    climate.data$Lat, c(48, 51, 54, 57, 61)
  )
)

site.block$Block <- interaction(
  droplevels(site.block$LongBlock),
  droplevels(site.block$LatBlock),
  sep = "::",
  drop = TRUE
)

## 2.2 Relabel the blocks ----
# bootstrap_data() selects a block with grep(), so the labels
# have to be free of the regex metacharacters that the interval
# notation above is full of.
reclass.site <- data.frame(
  Orig = unique(site.block$Block),
  Update = letters[1:length(unique(site.block$Block))]
)

climate.data$Block <- reclass.site$Update[
  match(site.block$Block, reclass.site$Orig)
]

rm(site.block, reclass.site)

# 3. Generate the bootstrap ids ----
# One set of ids per species, because the viability checks inside
# bootstrap_data() depend on where that species was detected.

## 3.1 Define cores and objects for parallel processing ----
if (!is.null(boot_seed)) {
  set.seed(boot_seed)
}

core.input <- makeCluster(n_clusters)

if (!is.null(boot_seed)) {
  clusterSetRNGStream(core.input, boot_seed)
}

clusterExport(
  core.input,
  c("climate.data", "species.list", "boot_iter", "boot_threshold",
    "bootstrap_data")
)

cat(
  "Bootstrapping ", taxon, ": ", length(species.list),
  " species x ", length(boot_iter), " iterations on ",
  n_clusters, " cores\n",
  sep = ""
)

## 3.2 Loop through each species ----
bootstrap.list <- foreach(species = species.list) %dopar%

  parSapply(
    core.input,
    as.list(boot_iter),
    FUN = function(boot) {
      tryCatch(
        bootstrap_data(
          data = climate.data,
          species = species,
          threshold = boot_threshold,
          boot = boot
        ),
        error = function(e) e
      )
    }
  )

names(bootstrap.list) <- species.list

stopCluster(core.input)

## 3.3 Simplify to one array per species ----
bootstrap.ids <- list()

for (one_species in species.list) {
  bootstrap.ids[[one_species]] <- simplify2array(
    bootstrap.list[[one_species]]
  )
}

# 4. Save the results ----
bootstrap_path <- file.path(
  run_dir, "bootstrap", paste0(taxon, "-bootstrap-ids.Rdata")
)

save(bootstrap.ids, file = bootstrap_path)

cat("Wrote ", bootstrap_path, "\n", sep = "")

# End of script ----
