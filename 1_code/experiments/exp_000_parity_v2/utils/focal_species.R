# ---
# title: Focal Species Sets for Experiment 000
# author: Brendan Casey
# created: 2026-09-11
# inputs: none
# outputs: none; returns objects in memory
# notes:
#   - Holds the species vectors run.R chooses between, so that
#     run.R stays a page of decisions rather than a page of
#     names. The sets grow; the run script should not.
#   - Every set uses the named-vector convention the harness
#     expects: names are taxa, values are species, names may
#     repeat, and an unnamed entry applies to every taxon. NULL
#     means every species the spec's queue declares, which is the
#     full parity run.
#   - Names are data slugs, not directory names. Soil mites key
#     on "mite". See 1_code/modules/soil_mites/spec.R.
#   - Species names must match the response columns exactly. The
#     loader stops and lists any name it cannot find, so a typo
#     fails before modelling starts rather than part-way through.
#   - To see what is available for a taxon:
#       head(list_species(data_dir, "mite", "north"), 20)
#   - A taxon a set does not name is unrestricted, not excluded.
#     Narrow run_taxa alongside a partial set; run.R warns if a
#     taxon would silently run its full species list.
#   - This mirrors model_sets() and get_model_set() in the
#     harness, so the two registries read the same way.
# ---

# 1. Setup ----

## 1.1 Load packages ----
# Base R only; the harness supplies everything else.

# 2. focal_species_sets() ----

#' Every Named Focal-Species Set
#'
#' @return A named list of species vectors, each in the harness's
#'   named-vector convention.
#'
#' @example # Example usage of the function
#' # names(focal_species_sets())
#' # focal_species_sets()$parity_check
focal_species_sets <- function() {
  list(

    ## 2.1 full ----
    # Every species each spec declares. The parity run.
    full = NULL,

    ## 2.2 parity_check ----
    # Two per taxon, for a first run that is meant to be read
    # rather than merely survived.
    #
    # These were not picked for being familiar. A rare species
    # has a wide bootstrap band, so the v2 value falls inside it
    # whatever the harness does and the parity test passes
    # without discriminating. These are the species whose bands
    # are tight enough for an in-band result to mean something.
    #
    # Each was chosen on four criteria: present in both regions
    # well above the 20-detection bootstrap threshold;
    # prevalence between roughly 5 and 45 per cent, so neither
    # floor nor ceiling; present in the v2 reference with all
    # 100 draws usable; and, across the pair, one balanced
    # between north and south so the southern model is genuinely
    # exercised.
    #
    # Birds are the exception. No v2 reference is reachable, so
    # AMRO and YEWA prove the run path works but cannot be
    # gated. Drop "bird" from run_taxa for a parity-only pass.
    #
    # Detections north / south, and prevalence north / south:
    #   Ceratodon.purpureus       2140 /  554   44.1 / 24.0
    #   Bryum.All                 1941 /  856   40.0 / 37.1
    #   Physcia.adscendens        2232 /  506   38.4 / 21.6
    #   Cladonia.chlorophaea      2236 /  218   38.5 /  9.3
    #   Ceratozetes.gracilis      1190 /  133   20.8 /  5.6
    #   Trhypochthonius.tectorum   546 /  197    9.6 /  8.3
    #   Galium.boreale            2875 /  588   41.8 / 22.2
    #   Vicia.americana           2596 /  700   37.8 / 26.4
    #   Moose_Summer              1585 /  225   31.2 / 17.8
    #   Coyote_Summer             1362 /  893   26.8 / 70.8
    #   AMRO                     41853 /23613   24.4 / 25.9
    #   YEWA                     22337 /15887   13.0 / 17.5
    parity_check = c(
      # Bryum.All is a genus-level aggregate rather than a
      # single species, and is here because it is the only
      # bryophyte with a strong south signal as well as a
      # strong north one. Swap in Pylaisia.polyantha for two
      # true species, at the cost of the southern test.
      bryophyte      = "Ceratodon.purpureus",
      bryophyte      = "Bryum.All",

      # The two best-detected lichens, so the tightest bands of
      # any plant-group taxon.
      lichen         = "Physcia.adscendens",
      lichen         = "Cladonia.chlorophaea",

      # Ceratozetes is the strongest mite in the north;
      # Trhypochthonius is the most even across the regions.
      mite           = "Ceratozetes.gracilis",
      mite           = "Trhypochthonius.tectorum",

      # Both common in both regions, which makes them the most
      # discriminating pair in the set.
      vascular_plant = "Galium.boreale",
      vascular_plant = "Vicia.americana",

      # Both have a published climate reference. Coyote carries
      # the south, where moose is thinner.
      mammal         = "Moose_Summer",
      mammal         = "Coyote_Summer",

      # Runnable, not gateable.
      bird           = "AMRO",
      bird           = "YEWA"
    ),

    ## 2.3 plants_only ----
    # The four plant-group taxa, for a run that skips the two
    # taxa with the slowest stages.
    #
    # Pair this with a narrowed run_taxa. A taxon that a set does
    # not name is unrestricted rather than excluded, so leaving
    # mammals and birds in run_taxa would run every species of
    # each and make this the longest run in the file. run.R warns
    # when that happens.
    plants_only = c(
      bryophyte      = "Ceratodon.purpureus",
      bryophyte      = "Bryum.All",
      lichen         = "Physcia.adscendens",
      lichen         = "Cladonia.chlorophaea",
      mite           = "Ceratozetes.gracilis",
      mite           = "Trhypochthonius.tectorum",
      vascular_plant = "Galium.boreale",
      vascular_plant = "Vicia.americana"
    ),

    ## 2.4 one_each ----
    # One species per taxon. The shortest run that still touches
    # every module, for checking plumbing after a change.
    one_each = c(
      bryophyte      = "Ceratodon.purpureus",
      lichen         = "Physcia.adscendens",
      mite           = "Ceratozetes.gracilis",
      vascular_plant = "Galium.boreale",
      mammal         = "Moose_Summer",
      bird           = "AMRO"
    )
  )
}

# 3. get_focal_species() ----

#' Look Up One Focal-Species Set by Name
#'
#' An unrecognized value is returned unchanged, so run.R can
#' hand this either a set name or a species vector written
#' inline and get the right thing back either way.
#'
#' @param name Character. A name from focal_species_sets(), or
#'   a species vector to pass through, or NULL for all species.
#' @param sets Named list. The registry to look in.
#' @return A named character vector, or NULL.
#'
#' @example # Example usage of the function
#' # get_focal_species("one_each")
#' # get_focal_species(c(mite = "Oppiella.nova"))
get_focal_species <- function(name,
                              sets = focal_species_sets()) {
  if (is.null(name) || length(name) == 0) {
    return(NULL)
  }

  if (length(name) > 1 || !name %in% names(sets)) {
    return(name)
  }

  sets[[name]]
}

# End of script ----
