# ---
# title: Focal Species Sets, Shared by Every Experiment
# author: Brendan Casey
# created: 2026-09-11
# inputs: none
# outputs: none; returns objects in memory
# notes:
#   - Named species sets shared by experiments, so a later
#     experiment can run exactly exp_000's species. Sets follow
#     taxon_values() (names are data slugs, e.g. "mite"); NULL
#     means every species.
#   - A taxon a set does not name is unrestricted, not excluded;
#     narrow `taxa` alongside a partial set.
#   - Available species: list_species(data_dir, "mite", "north").
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
    # The full parity run
    full = NULL,

    ## 2.2 parity_check ----
    # Two per taxon, chosen so the parity test discriminates: rare
    # species have bands wide enough to pass anything. Criteria:
    # well above 20 detections in both regions; prevalence ~5-45%;
    # all 100 v2 draws usable; and one of each pair balanced
    # between north and south.
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
      # the south, where moose is thinner. Both seasons, because
      # v2's mammal references average summer and winter; each
      # season's spec takes its own and skips the other.
      mammal         = "Moose_Summer",
      mammal         = "Moose_Winter",
      mammal         = "Coyote_Summer",
      mammal         = "Coyote_Winter",

      # Gated on climate, and on landcover once translated to
      # v2's standardized terms.
      bird           = "AMRO",
      bird           = "YEWA"
    ),

    ## 2.3 plants_only ----
    # Pair with a narrowed `taxa`, or mammals and birds run every
    # species (experiment_config() warns)
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
    # Shortest run touching every module, for plumbing checks
    one_each = c(
      bryophyte      = "Ceratodon.purpureus",
      lichen         = "Physcia.adscendens",
      mite           = "Ceratozetes.gracilis",
      vascular_plant = "Galium.boreale",
      mammal         = "Moose_Summer",
      mammal         = "Moose_Winter",
      bird           = "AMRO"
    )
  )
}

# 3. get_focal_species() ----

#' Look Up One Focal-Species Set by Name
#'
#' An unrecognized value (e.g. an inline species vector) is
#' returned unchanged.
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
