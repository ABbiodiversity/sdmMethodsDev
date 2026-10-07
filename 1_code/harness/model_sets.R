# ---
# title: Candidate Model Sets
# author: Brendan Casey
# created: 2026-09-09
# inputs: none
# outputs: none; returns objects in memory
# notes:
#   - v2's candidate formulas, named so a spec can refer to a set.
#     Stored as text, not formula objects, so no environment is
#     captured. Candidates are updates (`. ~ . + MAP`) applied to a
#     base formula that supplies the response.
#   - Plant and mammal formulas are spliced verbatim from
#     0_data/v2_scripts/, not retyped; long lines are kept so they
#     match v2 line for line.
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
  # Shared by the v2 bird and mammal climate stages. The null is
  # a candidate because v2 averages over it too; dropping it
  # would shift every weight.
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

  # As 06.ModelClimate.R assembles it: 25 candidates (null, 8
  # climate, 8 + linear space, 8 + quadratic space). Spatial terms
  # are in metres, as in v2, hence coefficients near 1e-12.
  spatial_linear <- "Easting + Northing + Easting:Northing"
  spatial_quadratic <- "I(Easting^2) + I(Northing^2)"

  climate_bird_v2 <- c(
    climate_bird_mammal_v2,
    paste(climate_bird_mammal_v2[-1], "+", spatial_linear),
    paste(
      climate_bird_mammal_v2[-1], "+", spatial_linear, "+",
      spatial_quadratic
    )
  )

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

  # v2 averages over 58 candidates, not the 14 above: each with
  # and without bioclim, plus spatial versions of the ten
  # (five base, five bioclim) without MAT, TD or PET (v2's
  # `model.update.id`). The 14 alone give coefficients not
  # comparable with the published ones.
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

  # Fitted with ivw_grid, so a "coefficient" is an effect per
  # habitat type, not a regression coefficient. Protocol (in the
  # bryophyte and lichen variants only) is added by
  # plant_group_spec().
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

  # staged_bic walks the groups in order, each updating the
  # previous group's winner, so group order is part of the model.
  # Terms are source names; term_map() rewrites them to the
  # dataset's block-suffixed names.
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

  # Presence half of the v2 mammal hurdle (see
  # modules/mammals/hurdle.R), 17 candidates selected on AICc.
  # intercept_mammal_north_pa_v2 names each model's omitted
  # reference category, which the intercept absorbs; the two
  # vectors are parallel and must stay so.
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

  # The mammal south presence set, spliced from
  # south-models/00_models.R: 15 soil and footprint models, then
  # the same 15 with pAspen. Each names the category it leaves
  # out, which the one-hot rule reports alongside.
  mammal_south_base <- c(
    "ClayWet + SandyLoam + RapidDrain + ThinBlow + WetlandMargin + RurUrbInd + Well + RoughP + TameP + Crop + EnSoftLinSeismic + TrSoftLin",
    "ClayWet + SandyRapid + ThinBlow + WetlandMargin + RurUrbInd + Well + RoughP + TameP + Crop + EnSoftLinSeismic + TrSoftLin",
    "SandyLoam + Nonproductive + WetlandMargin + RurUrbInd + Well + RoughP + TameP + Crop + EnSoftLinSeismic + TrSoftLin",
    "WetlandMargin + RurUrbInd + Well + RoughP + TameP + Crop + EnSoftLinSeismic + TrSoftLin",
    "ClayWet + SandyRapid + ThinBlow + WetlandMargin + RurUrbInd + Well + Cult + EnSoftLinSeismic + TrSoftLin",
    "SandyLoam + Nonproductive + WetlandMargin + RurUrbInd + Well + Cult + EnSoftLinSeismic + TrSoftLin",
    "WetlandMargin + RurUrbInd + Well + Cult + EnSoftLinSeismic + TrSoftLin",
    "ClayWet + SandyRapid + ThinBlow + WetlandMargin + NonAgAlien + Cult + Succ",
    "SandyLoam + Nonproductive + WetlandMargin + NonAgAlien + Cult + Succ",
    "WetlandMargin + NonAgAlien + Cult + Succ",
    "ClayWet + SandyRapid + ThinBlow + WetlandMargin + Alien + Succ",
    "SandyLoam + Nonproductive + WetlandMargin + Alien + Succ",
    "WetlandMargin + Alien + Succ",
    "WetlandMargin + Alien",
    "WetlandMargin"
  )

  habitat_mammal_south_pa_v2 <- c(
    paste0(". ~ . + ", mammal_south_base, " + seas_days + Climate"),
    paste0(
      ". ~ . + ", mammal_south_base, " + pAspen + seas_days + Climate"
    )
  )

  intercept_mammal_south_pa_v2 <- rep(
    c("Loamy", "Loamy", "Loamy", "AllNative", "Loamy", "Loamy",
      "AllNative", "Loamy", "Loamy", "AllNative", "Loamy", "Loamy",
      "AllNative", "AllNativeSucc", "AllExceptMargin"),
    2
  )

  list(
    climate_bird_mammal_v2 = climate_bird_mammal_v2,
    climate_bird_v2 = climate_bird_v2,
    climate_plant_v2_full = climate_plant_v2_full,
    climate_plant_v2 = climate_plant_v2,
    habitat_mammal_north_pa_v2 = habitat_mammal_north_pa_v2,
    intercept_mammal_north_pa_v2 =
      intercept_mammal_north_pa_v2,
    habitat_mammal_south_pa_v2 = habitat_mammal_south_pa_v2,
    intercept_mammal_south_pa_v2 =
      intercept_mammal_south_pa_v2,
    landcover_bird_north_v2 = landcover_bird_north_v2,
    landcover_bird_south_v2 = landcover_bird_south_v2,
    habitat_veg_plant_v2 = habitat_veg_plant_v2,
    habitat_soil_plant_v2 = habitat_soil_plant_v2
  )
}

# 3. Building model sets ----
# A stage's `models` is a model_sets() name or a vector of
# formulas. Covariates are loaded from the terms the formulas
# name, so no separate declaration is needed.

## 3.1 extend_models() ----

#' Add Terms to Every Candidate in a Set
#'
#' For include/exclude comparisons: two runs then differ only by
#' these terms.
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
#' `form` is a modelling choice:
#'
#' - `single`: one model with every covariate.
#' - `each`: one model per covariate.
#' - `ladder`: cumulative, in the order given (order matters).
#' - `all_subsets`: every combination, capped by `max_subsets`
#'   (ten covariates is 1,023 models per species per draw).
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

## 3.3 models_union() ----

#' One Formula Holding Every Covariate a Candidate Set Uses
#'
#' For engines that find their own variables, curvature and
#' interactions (e.g. boosted trees). `I(x^2)` and `a:b`
#' contribute x, a and b as main effects.
#'
#' @param models Character vector of formulas, a list of groups of
#'   them (a staged set), or a name in model_sets().
#' @param sets Named list of model sets.
#' @return One formula, as text, in update form (". ~ . + ...").
#'
#' @example # Example usage of the function
#' # models_union("climate_bird_v2")
models_union <- function(models, sets = model_sets()) {
  formulas <- unlist(get_model_set(models, sets), use.names = FALSE)

  terms <- unique(unlist(lapply(formulas, function(one) {
    all.vars(stats::as.formula(one))
  })))
  terms <- setdiff(terms, c(".", "response", "offset", "weight"))

  if (length(terms) == 0) {
    return(". ~ .")
  }

  paste0(". ~ . + ", paste(terms, collapse = " + "))
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
  # Most stages declare no intercept-category set
  if (is.null(name) || length(name) == 0) {
    return(NULL)
  }

  if (length(name) > 1 || !name %in% names(sets)) {
    return(name)
  }

  sets[[name]]
}

# End of script ----
