# ---
# title: Candidate Model Sets
# author: Brendan Casey
# created: 2026-09-09
# inputs: none
# outputs: none; returns objects in memory
# notes:
#   - The candidate formulas each v2 pipeline chooses among, as
#     text, so a spec names a set rather than carrying 40 lines of
#     formulas. Text rather than formula objects, because a
#     formula captures the environment it was built in, and these
#     are evaluated against whatever frame the run assembles.
#   - Candidates are updates - `. ~ . + MAP` - applied to a base
#     formula by the selection layer. The base supplies the
#     response, so one set serves any taxon whose response column
#     is named the same way.
#   - The climate set is shared by birds and mammals. Their two v2
#     pipelines were written separately by different authors and
#     arrived at the same eight combinations of the same four
#     variables; the mammal script adds an explicit null, which
#     here is the base formula. That is why one set covers both.
#   - The plant climate formulas are spliced verbatim from
#     0_data/v2_scripts/plants/, not retyped.
#   - Habitat model sets are not here. They are large, taxon
#     specific and bound up with a prediction grid, so they belong
#     with the taxon specs.
# ---

# 1. Setup ----

## 1.1 Load packages ----
# Base R only; the selection layer turns these into formulas.

# 2. model_sets() ----

#' Named Candidate Model Sets
#'
#' @return A named list of character vectors of model formulas.
#'
#' @example # Example usage of the function
#' # names(model_sets())
#' # model_sets()$climate_bird_mammal_v2
model_sets <- function() {
  # The bird and mammal climate set. Four variables - frost free
  # period, mean annual precipitation, climatic moisture deficit
  # and continentality - in eight combinations.
  #
  # Mammals do not store CMD or TD. TD is derived on load from
  # MWMT and MCMT; CMD has to be sourced before a mammal climate
  # stage can run this set in full. See the parity ledger.
  # The null is a candidate, not just the base: v2 averages over
  # `climate.list` including the intercept-only model it starts
  # from, so leaving it out would shift every weight.
  climate_bird_mammal_v2 <- c(
    ". ~ .",
    ". ~ . + FFP",
    ". ~ . + MAP",
    ". ~ . + CMD",
    ". ~ . + TD",
    ". ~ . + TD + FFP",
    ". ~ . + MAP + CMD",
    ". ~ . + TD + FFP + CMD",
    ". ~ . + MAP + FFP + TD + CMD"
  )

  # The subset of the above that mammals can fit today, without
  # CMD. Five of the nine v2 models, the null included.
  climate_mammal_available <- c(
    ". ~ .",
    ". ~ . + FFP",
    ". ~ . + MAP",
    ". ~ . + TD",
    ". ~ . + TD + FFP"
  )

  # The plant climate set, spliced from the v2 source. Wider
  # than the bird and mammal one, and includes interaction and
  # squared terms the other two do not use.
  climate_plant_v2 <- c(
    ". ~ .",
    ". ~ . + PET",
    ". ~ . + CMD",
    ". ~ . + MAT",
    ". ~ . + FFP",
    ". ~ . + MAP + FFP",
    ". ~ . + MAP + FFP + CMD",
    ". ~ . + MAP + PET + CMD + MAPPET",
    ". ~ . + MAT + MAP + CMD + CMDMAT",
    ". ~ . + MAT + MAP",
    ". ~ . + MWMT + TD",
    ". ~ . + CMD + PET",
    ". ~ . + MAT + MAT2 + MWMT + MWMT2",
    ". ~ . + TD + FFP + MAT"
  )

  # Applied on top of a chosen climate model, not instead of it.
  bioclim_plant_v2 <- c(
    ".~.+ bio9 + bio15"
  )

  # Spatial trend terms, likewise applied on top.
  space_plant_v2 <- c(
    ".~.+ Easting + Northing",
    ".~.+ Easting + Northing + EastingNorthing",
    ".~.+ Easting + Northing + Easting2 + Northing2 + EastingNorthing"
  )

  # The plant climate candidate set as v2 actually assembles it.
  # v2 does not fit these 14 alone: it appends a bioclim version
  # of every one, then spatial versions of ten of them, and
  # averages over all 58 at once. Fitting only the base 14 makes
  # a different model, and its coefficients are not comparable
  # with the published ones.
  #
  # The ten that take spatial terms are the models carrying
  # neither MAT, TD nor PET - v2's `model.update.id`, which
  # indexes the base models and their bioclim counterparts.
  spatial_targets <- c(1, 3, 5, 6, 7)

  bioclim_plant <- paste0(
    climate_plant_v2, " + bio9 + bio15"
  )

  space_terms <- c(
    "Easting + Northing",
    "Easting + Northing + EastingNorthing",
    paste(
      "Easting + Northing + Easting2 + Northing2 +",
      "EastingNorthing"
    )
  )

  spatial_bases <- c(
    climate_plant_v2[spatial_targets],
    bioclim_plant[spatial_targets]
  )

  climate_plant_v2_full <- c(
    climate_plant_v2,
    bioclim_plant,
    as.vector(outer(
      spatial_bases, space_terms,
      function(model, space) paste0(model, " + ", space)
    ))
  )

  # The v2 plant habitat sets, spliced from the source. These
  # are fitted with the ivw_grid rule, which predicts each
  # candidate onto the prediction matrix and combines those
  # predictions by precision - so a "coefficient" here is an
  # effect per habitat type, not a regression coefficient.
  #
  # Protocol appears in the bryophyte and lichen variants
  # only; plant_group_spec() adds it, matching v2.
  habitat_veg_plant_v2 <- c(
    ". ~ . + Climate + WhiteSpruce + Pine + Deciduous + Mixedwood + BlackSpruce + TreedFen + TreedSwamp + GraminoidFen + ShrubbyFen + ShrubbyBog + ShrubbySwamp + Marsh + Grass + Shrub + CCWhiteSpruceR + CCWhiteSpruce1 + CCWhiteSpruce234 + CCPineR + CCPine1234 + CCDecidMixedR + CCDecidMixed1 + CCDecidMixed234 + HardLin + EnSeismic + EnSoftLin + TrSoftLin + UrbInd + Wellsites + Crop + RoughP + TameP",
    ". ~ . + Climate + WhiteSpruce + Pine + Deciduous + Mixedwood + Peatland + Mineral + Grass + Shrub + CCWhiteSpruceR + CCWhiteSpruce1 + CCWhiteSpruce234 + CCPineR + CCPine1234 + CCDecidMixedR + CCDecidMixed1 + CCDecidMixed234 + HardLin + EnSeismic + EnSoftLin + TrSoftLin + UrbInd + Wellsites + Crop + RoughP + TameP",
    ". ~ . + Climate + WhiteSpruce + Pine + Deciduous + Mixedwood + Bog + TreedFen + + NonTreedFen + TreedSwamp + ShrubbySwamp + Marsh + Grass + Shrub + CCWhiteSpruceR + CCWhiteSpruce1 + CCWhiteSpruce234 + CCPineR + CCPine1234 + CCDecidMixedR + CCDecidMixed1 + CCDecidMixed234 + HardLin + EnSeismic + EnSoftLin + TrSoftLin + UrbInd + Wellsites + Crop + RoughP + TameP",
    ". ~ . + Climate + WhiteSpruce + Pine + Deciduous + Mixedwood + Bog + Fen + TreedSwamp + ShrubbySwamp + Marsh + Grass + Shrub + CCWhiteSpruceR + CCWhiteSpruce1 + CCWhiteSpruce234 + CCPineR + CCPine1234 + CCDecidMixedR + CCDecidMixed1 + CCDecidMixed234 + HardLin + EnSeismic + EnSoftLin + TrSoftLin + UrbInd + Wellsites + Crop + RoughP + TameP",
    ". ~ . + Climate + WhiteSpruce + Pine + Deciduous + Mixedwood + Bog + Fen + Swamp + Marsh + GrassShrub + CCWhiteSprucePineR + CCWhiteSprucePine1 + CCWhiteSprucePine234 + CCDecidMixedR + CCDecidMixed1 + CCDecidMixed234 + HardLin + SoftLin + UrbInd + Wellsites + Crop + RoughP + TameP",
    ". ~ . + Climate + WhiteSpruce + Pine + Deciduous + Mixedwood + Peatland + Mineral + GrassShrub + CCWhiteSprucePineR1234 + CCDecidMixedR1234 + HardLin + SoftLin + UrbIndWellsites + Crop + Pasture",
    ". ~ . + Climate + WhiteSpruce + Pine + Deciduous + Mixedwood + Lowland + GrassShrub + CCWhiteSprucePineR1234 + CCDecidMixedR1234 + SoftLin + Alien",
    ". ~ . + Climate + Upland + BlackSpruce + TreedFen + TreedSwamp + GraminoidFen + ShrubbyFen + ShrubbyBog + ShrubbySwamp + Marsh + Grass + Shrub + CCR1234 + HardLin + EnSeismic + EnSoftLin + TrSoftLin + UrbInd + Wellsites + Crop + RoughP + TameP",
    ". ~ . + Climate + Upland + Bog + Fen + Swamp + Marsh + Grass + Shrub + CCR1234 + HardLin + EnSeismic + EnSoftLin + TrSoftLin + UrbInd + Wellsites + Crop + RoughP + TameP",
    ". ~ . + Climate + Upland + Peatland + Swamp + Marsh + GrassShrub + CCR1234 + HardLin + SoftLin + UrbInd + Wellsites + Crop + RoughP + TameP",
    ". ~ . + Climate + Upland + Peatland + Mineral + GrassShrub + CCR1234 + HardLin + SoftLin + UrbIndWellsites + Crop + Pasture",
    ". ~ . + Climate + Upland + Lowland + GrassShrub + CCR1234 + SoftLin + Alien"
  )

  # The south set. paspen enters half of these, which is why
  # the south prediction grid carries no column for it.
  habitat_soil_plant_v2 <- c(
    ". ~ . + Climate + Blowout + ClaySub + Loamy + RapidDrain + SandyLoam + ThinBreak + Other + UrbInd + Wellsites + Crop + TameP + RoughP + EnSoftLin + EnSeismic + TrSoftLin + HardLin",
    ". ~ . + Climate + Blowout + ClaySubThin + Loamy + SandyRapid + Other +  UrbInd+ Wellsites + Crop + TameP + RoughP + EnSoftLin + EnSeismic + TrSoftLin + HardLin",
    ". ~ . + Climate + Productive + Nonproductive + Other + UrbInd + Wellsites + Crop + TameP + RoughP + EnSoftLin + EnSeismic + TrSoftLin + HardLin",
    ". ~ . + Climate + Blowout + ClaySub + Loamy + RapidDrain + SandyLoam + ThinBreak  + Other + UrbIndWellsites + Crop + Pasture + SoftLin + HardLin",
    ". ~ . + Climate + Blowout + ClaySubThin + Loamy + SandyRapid + Other + UrbIndWellsites + Crop + Pasture + SoftLin + HardLin",
    ". ~ . + Climate + Productive + Nonproductive + Other + UrbIndWellsites + Crop + Pasture + SoftLin + HardLin",
    ". ~ . + Climate + Productive + Nonproductive + Other + UrbIndWellsites + Cult + SoftLin + HardLin",
    ". ~ . + Climate + Productive + Nonproductive + Other + Alien + SoftLin",
    ". ~ . + Climate + Blowout + ClaySub + Loamy + RapidDrain + SandyLoam + ThinBreak  + Other + UrbInd + Wellsites + Crop + TameP + RoughP + EnSoftLin + EnSeismic + TrSoftLin + HardLin + paspen",
    ". ~ . + Climate + Blowout + ClaySubThin + Loamy + SandyRapid +  Other +  UrbInd + Wellsites + Crop + TameP + RoughP + EnSoftLin + EnSeismic + TrSoftLin + HardLin + paspen",
    ". ~ . + Climate + Productive + Nonproductive + Other + UrbInd + Wellsites + Crop + TameP + RoughP + EnSoftLin + EnSeismic + TrSoftLin + HardLin + paspen",
    ". ~ . + Climate + Blowout + ClaySub + Loamy +RapidDrain + SandyLoam + ThinBreak  + Other + UrbIndWellsites + Crop + Pasture + SoftLin + HardLin + paspen",
    ". ~ . + Climate + Blowout + ClaySubThin + Loamy + SandyRapid + Other + UrbIndWellsites + Crop + Pasture + SoftLin + HardLin + paspen",
    ". ~ . + Climate + Productive + Nonproductive + Other + UrbIndWellsites + Crop + Pasture + SoftLin + HardLin + paspen",
    ". ~ . + Climate + Productive + Nonproductive + Other + UrbIndWellsites + Cult + SoftLin + HardLin + paspen",
    ". ~ . + Climate + Productive + Nonproductive + Other + Alien + SoftLin + paspen"
  )

  # The bird landcover sets, as groups. staged_bic walks them in
  # order, fitting each group as an update to the previous
  # group's winner, so the groups are a claim about the order the
  # questions are asked in: habitat type first, then stand age,
  # then cutblocks, then contrasts, then survey method and water.
  #
  # Terms name the source columns; the harness rewrites them to
  # the block-suffixed names the dataset uses. See term_map().
  landcover_bird_north_v2 <- list(
    Hab = c(
      ". ~ . + vegc"
    ),
    Age = c(
      ". ~ . + wtAge",
      ". ~ . + wtAge + wtAge2",
      ". ~ . + wtAge + wtAge2 + wtAge:isCon + wtAge2:isCon",
      ". ~ . + wtAge + wtAge2 + wtAge:isUpCon + wtAge:isBogFen + wtAge2:isUpCon + wtAge2:isBogFen",
      ". ~ . + wtAge + wtAge2 + wtAge:isMix + wtAge:isPine + wtAge:isWSpruce + wtAge:isBogFen + wtAge2:isMix + wtAge2:isPine + wtAge2:isWSpruce + wtAge2:isBogFen",
      ". ~ . + wtAge05",
      ". ~ . + wtAge05 + wtAge05:isCon",
      ". ~ . + wtAge05 + wtAge05:isUpCon + wtAge05:isBogFen",
      ". ~ . + wtAge05 + wtAge05:isMix + wtAge05:isPine + wtAge05:isWSpruce + wtAge05:isBogFen",
      ". ~ . + wtAge05 + wtAge",
      ". ~ . + wtAge05 + wtAge + wtAge05:isCon + wtAge:isCon",
      ". ~ . + wtAge05 + wtAge + wtAge05:isUpCon + wtAge05:isBogFen + wtAge:isUpCon + wtAge:isBogFen",
      ". ~ . + wtAge05 + wtAge + wtAge05:isMix + wtAge05:isPine + wtAge05:isWSpruce + wtAge05:isBogFen + wtAge:isMix + wtAge:isPine + wtAge:isWSpruce + wtAge:isBogFen"
    ),
    CC = c(
      ". ~ . + fcc2"
    ),
    Contrast = c(
      ". ~ . + road",
      ". ~ . + road + mWell",
      ". ~ . + road + mWell + mSoft",
      ". ~ . + road + mWell + mEnSft + mTrSft",
      ". ~ . + road + mWell + mEnSft + mTrSft + mSeism"
    ),
    ARU = c(
      ". ~ . + method"
    ),
    Water = c(
      ". ~ . + pWater_KM",
      ". ~ . + pWater_KM + pWater2_KM"
    )
  )

  landcover_bird_south_v2 <- list(
    Hab = c(
      ". ~ . + soilc",
      ". ~ . + soilc + paspen"
    ),
    Contrast = c(
      ". ~ . + road",
      ". ~ . + road + mWell",
      ". ~ . + road + mWell + mSoft"
    ),
    ARU = c(
      ". ~ . + method"
    ),
    Water = c(
      ". ~ . + pWater_KM",
      ". ~ . + pWater_KM + pWater2_KM"
    )
  )

  # The mammal north presence/absence set. Seventeen candidates
  # running from fine vegetation and footprint resolution to
  # coarse aggregation, selected on AICc.
  #
  # Each carries a reference category rather than a factor: the
  # land cover type left out of the formula, whose effect the
  # intercept absorbs. Models 1, 2 and 10 omit Crop, the rest
  # omit Alien, and a coefficient table has to name it to be
  # read. The two vectors are parallel and must stay so.
  #
  # This is the presence half of a hurdle model; v2 fits a Gamma
  # abundance-given-presence part alongside it and multiplies
  # the two. Only the presence half is reproduced here.
  habitat_mammal_north_pa_v2 <- c(
    ". ~ . + Decid + Mixedwood + Pine + Spruce + TreedBog + TreedFen + TreedSwamp + GrassHerb + Shrub + Marsh + ShrubbySwamp + ShrubbyBogFen + CCDecidR + CCDecid1 + CCDecid2 + CCMixedwoodR + CCMixedwood1 + CCMixedwood2 + CCPineR + CCPine1 + CCSpruceR + CCSpruce1 + CCSpruce2 + EnSoftLin + EnSeismic + TrSoftLin + TameP + RoughP + Well + RurUrbInd + seas_days + Climate",
    ". ~ . + Decid + Mixedwood + Pine + Spruce + TreedBog + TreedFen + TreedSwamp + GrassHerb + Shrub + Marsh + ShrubbySwamp + ShrubbyBogFen + CCDecidMixed + CCPine + CCSpruce + EnSoftLin + EnSeismic + TrSoftLin + TameP + RoughP + Well + RurUrbInd + seas_days + Climate",
    ". ~ . + Decid + Mixedwood + Pine + Spruce + TreedBog + TreedFen + TreedSwamp + GrassHerb + Shrub + Marsh + ShrubbySwamp + ShrubbyBogFen + CCDecidMixed + CCPine + CCSpruce + EnSoftLin + EnSeismic + TrSoftLin + seas_days + Climate",
    ". ~ . + Decid + Mixedwood + Pine + Spruce + TreedBog + TreedFen + TreedSwamp + GrassHerb + Shrub + Marsh + ShrubbySwamp + ShrubbyBogFen + CCDecidMixed + CCPine + CCSpruce + SoftLin + seas_days + Climate",
    ". ~ . + Decid + Mixedwood + Pine + Spruce + TreedBog + TreedFen + TreedSwamp + GrassHerb + Shrub + Marsh + ShrubbySwamp + ShrubbyBogFen + CCAll + SoftLin + seas_days + Climate",
    ". ~ . + Decid + Mixedwood + Pine + Spruce + TreedBogFen + TreedSwamp + GrassHerb + Shrub + OpenWet + CCAll + SoftLin + seas_days + Climate",
    ". ~ . + Decid + Mixedwood + Pine + Spruce + TreedWet + GrassShrub + OpenWet + CCDecidR + CCDecid1 + CCDecid2 + CCMixedwoodR + CCMixedwood1 + CCMixedwood2 + CCPineR + CCPine1 + CCSpruceR + CCSpruce1 + CCSpruce2 + SoftLin + seas_days + Climate",
    ". ~ . + Decid + Mixedwood + Pine + Spruce + TreedWet + GrassShrub + OpenWet + CCDecidMixed + CCConif + SoftLin + seas_days + Climate",
    ". ~ . + DecidMixed + UpCon + TreedWet + GrassShrub + OpenWet + CCDecidMixed + CCConif + SoftLin + seas_days + Climate",
    ". ~ . + DecidMixed + UpCon + TreedWet + GrassShrub + OpenWet + CCAll + SoftLin + TameP + RoughP + Well + RurUrbInd + seas_days + Climate",
    ". ~ . + DecidMixed + UpCon + TreedWet + GrassShrub + OpenWet + CCAll + SoftLin + seas_days + Climate",
    ". ~ . + DecidMixed + UpCon + TreedWet + GrassShrub + OpenWet + Succ + seas_days + Climate",
    ". ~ . + Upland + Lowland + CCAll + SoftLin + seas_days + Climate",
    ". ~ . + TreedAll + OpenAll + Succ + seas_days + Climate",
    ". ~ . + UplandForest + Lowland + GrassShrub + Succ + seas_days + Climate",
    ". ~ . + Upland + Lowland + Succ + seas_days + Climate",
    ". ~ . + Boreal + GrassShrub + Succ + seas_days + Climate"
  )

  intercept_mammal_north_pa_v2 <- c(
    "Crop", "Crop", "Alien", "Alien", "Alien", "Alien", "Alien", "Alien", "Alien", "Crop", "Alien", "Alien", "Alien", "Alien", "Alien", "Alien", "Alien"
  )

  list(
    climate_bird_mammal_v2 = climate_bird_mammal_v2,
    climate_plant_v2_full = climate_plant_v2_full,
    climate_mammal_available = climate_mammal_available,
    climate_plant_v2 = climate_plant_v2,
    habitat_mammal_north_pa_v2 = habitat_mammal_north_pa_v2,
    intercept_mammal_north_pa_v2 =
      intercept_mammal_north_pa_v2,
    landcover_bird_north_v2 = landcover_bird_north_v2,
    landcover_bird_south_v2 = landcover_bird_south_v2,
    habitat_veg_plant_v2 = habitat_veg_plant_v2,
    habitat_soil_plant_v2 = habitat_soil_plant_v2,
    bioclim_plant_v2 = bioclim_plant_v2,
    space_plant_v2 = space_plant_v2
  )
}

# 3. Building model sets ----
# A stage's `models` may be a name in model_sets() or a character
# vector of formulas given directly, so an experiment defines its
# own candidate set without editing a spec. The covariates a run
# loads are read off whatever formulas it ends up with, so a set
# defined here needs no matching covariate declaration - naming a
# term is what loads it.

## 3.1 extend_models() ----

#' Add Terms to Every Candidate in a Set
#'
#' The include/exclude comparison: take a v2 candidate set and
#' put the same extra terms in all of it, so the only difference
#' between two runs is those terms.
#'
#' @param models Character vector of formulas, or a name in
#'   model_sets().
#' @param terms Character vector of terms to add.
#' @param sets Named list of model sets.
#' @return A character vector of formulas.
#'
#' @example # Example usage of the function
#' # extend_models("climate_bird_mammal_v2",
#' #               c("elevation", "slope"))
extend_models <- function(models, terms, sets = model_sets()) {
  models <- get_model_set(models, sets)

  if (length(terms) == 0) {
    return(models)
  }

  paste0(models, " + ", paste(terms, collapse = " + "))
}

## 3.2 models_from_covariates() ----

#' Build a Candidate Set from a List of Covariates
#'
#' For an experiment asking which covariates matter rather than
#' reproducing a v2 set. `form` decides the shape of the
#' comparison, and the choice is a modelling decision rather than
#' a convenience:
#'
#' - `single` fits one model holding every covariate. Use when
#'   the question is about the whole set, not its members.
#' - `each` fits one model per covariate, so they compete singly.
#' - `ladder` adds them cumulatively in the order given, which
#'   asks whether each one earns its place given the ones before
#'   it. Order therefore matters and is the user's claim.
#' - `all_subsets` fits every combination. Honest but explosive:
#'   ten covariates is 1,023 models per species per draw, so it
#'   is capped rather than left to run away.
#'
#' @param covariates Character vector of covariate names.
#' @param form Character. One of the shapes above.
#' @param include_null Logical. Prepend the intercept-only model.
#' @param max_subsets Integer. Refuse `all_subsets` beyond this
#'   many candidates.
#' @return A character vector of formulas.
#'
#' @example # Example usage of the function
#' # models_from_covariates(c("MAP", "FFP"), form = "ladder")
models_from_covariates <- function(
  covariates,
  form = c("single", "each", "ladder", "all_subsets"),
  include_null = TRUE,
  max_subsets = 256L
) {
  form <- match.arg(form)

  if (length(covariates) == 0) {
    stop("No covariates given.", call. = FALSE)
  }

  combine <- function(terms) {
    paste0(". ~ . + ", paste(terms, collapse = " + "))
  }

  models <- switch(
    form,
    single = combine(covariates),
    each = vapply(covariates, combine, character(1)),
    ladder = vapply(
      seq_along(covariates),
      function(i) combine(covariates[seq_len(i)]),
      character(1)
    ),
    all_subsets = {
      n <- length(covariates)
      total <- 2^n - 1

      if (total > max_subsets) {
        stop(
          n, " covariates make ", total, " subsets, past the cap ",
          "of ", max_subsets, ". Every one is fitted for every ",
          "species and every draw, so raise max_subsets ",
          "deliberately or use a smaller set.",
          call. = FALSE
        )
      }

      unlist(lapply(seq_len(n), function(k) {
        apply(
          utils::combn(covariates, k), 2, combine
        )
      }))
    }
  )

  models <- unname(models)

  if (include_null) {
    models <- c(". ~ .", models)
  }

  unique(models)
}

# 4. get_model_set() ----

#' Look Up One Model Set
#'
#' @param name Character. A name in model_sets(), or a character
#'   vector of formulas to use as given.
#' @param sets Named list of model sets.
#' @return A character vector of model formulas.
#'
#' @example # Example usage of the function
#' # get_model_set("climate_bird_mammal_v2")
get_model_set <- function(name, sets = model_sets()) {
  # A stage that declares no set at all - most stages have no
  # intercept categories - asks for nothing rather than for a
  # set called NULL.
  if (is.null(name) || length(name) == 0) {
    return(NULL)
  }

  if (length(name) > 1 || !name %in% names(sets)) {
    return(name)
  }

  sets[[name]]
}

# End of script ----
