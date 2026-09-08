# ---
# title: Species Vectors for Experiment 000
# author: Brendan Casey
# created: 2026-09-05
# inputs: none
# outputs: none
# notes:
#   - Defines the species each taxon is modelled on. Sourced by
#     run.R and passed to the module scripts, which narrow the
#     work queue to these names.
#   - NULL models every species the snapshot declares as
#     modelled, which is the parity setting: exp_000 has to cover
#     what v2 covered.
#   - A short vector is the smoke test. Species count and
#     boot_iter are both adjustable now, but boot_iter has to
#     stay at the v2 value for a parity run, so the species
#     vector is what a trial run should shorten.
#   - Names must match the species columns exactly.
#     load_plant_model_data() stops and lists any name it cannot
#     find, so a typo fails before modelling starts.
#   - The names are those in lookup/modelled_species.csv, which
#     is written from the snapshot's own veg.species.list and
#     soil.species.list. To see the options for a taxon:
#
#     modelled <- read.csv(
#       "0_data/test_dataset/lookup/modelled_species.csv"
#     )
#     head(modelled[modelled$taxon == "mite", ])
# ---

# 1. Species vectors ----

## 1.1 Bryophytes ----
# 134 modelled species: 133 north, 32 south.
bryophyte_species <- NULL

## 1.2 Lichens ----
# 191 modelled species: 175 north, 55 south.
lichen_species <- NULL

## 1.3 Soil mites ----
# 125 modelled species: 116 north, 34 south.
mite_species <- NULL

## 1.4 Vascular plants ----
# 486 modelled species: 353 north, 269 south.
vascular_plant_species <- NULL

# End of script ----
