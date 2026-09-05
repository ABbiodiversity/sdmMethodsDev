# ---
# title: Species Vectors for Experiment 000
# author: Brendan Casey
# created: 2026-09-05
# inputs: none
# outputs: none
# notes:
#   - Defines the species each taxon is modelled on. Sourced by
#     run.R and passed to stage_v2_inputs(), which narrows the
#     staged species queue to these names.
#   - NULL models every species in the source data. A short
#     vector is the smoke test - the v2 scripts hard-code 100
#     bootstrap iterations, so species count is the only run
#     length that can be varied without touching v2 code.
#   - Names must match the species columns in the v2 data
#     exactly. stage_v2_inputs() stops and lists any name it
#     cannot find, so a typo fails before modelling starts.
#   - The placeholder vectors below are illustrative. Replace
#     them with real species codes before running.
# ---

# 1. Species vectors ----

## 1.1 Bryophytes ----
# NULL runs every bryophyte in the data.
bryophyte_species <- NULL

## 1.2 Lichens ----
lichen_species <- NULL

## 1.3 Soil mites ----
# Placeholder - replace with species codes from the v2 mite data.
mite_species <- c(
  "species_code_1",
  "species_code_2",
  "species_code_3"
)

## 1.4 Vascular plants ----
vascular_plant_species <- NULL

# End of script ----
