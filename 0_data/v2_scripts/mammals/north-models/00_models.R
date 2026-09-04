# ---
# title:   Candidate PA Model Formulas — North
# author:  Marcus Becker
# created: 2026-05-19
# updated: 2026-05-19
#
# notes:
#   Sourced by 03_basic-models.R inside the species
#   × season loop. Assumes d_sp is already filtered
#   and contains p_count_pa, seas_days, Climate, and
#   all required veg+HF columns.
#
#   17 candidate models progress from fine-grained
#   veg+HF resolution (model 1) to coarse aggregation
#   (model 17). Climate enters every model as a linear
#   predictor. Reference (intercept) category:
#   models 1, 2, 10 → Crop; models 3–9, 11–17 → Alien.
# ---

# ── PA model formulas ────────────────────────────

pa_intercept_cats <- c(
  "Crop", "Crop", rep("Alien", 7),
  "Crop",  rep("Alien", 7)
)

pa_formulas <- list(

  # 1. Fine CC (R/1/2) + fine HF — intercept: Crop
  p_count_pa ~ Decid + Mixedwood + Pine + Spruce +
    TreedBog + TreedFen + TreedSwamp + GrassHerb +
    Shrub + Marsh + ShrubbySwamp + ShrubbyBogFen +
    CCDecidR + CCDecid1 + CCDecid2 +
    CCMixedwoodR + CCMixedwood1 + CCMixedwood2 +
    CCPineR + CCPine1 + CCSpruceR + CCSpruce1 +
    CCSpruce2 +
    EnSoftLin + EnSeismic + TrSoftLin +
    TameP + RoughP + Well + RurUrbInd +
    seas_days + Climate,

  # 2. Grouped CC (DecidMixed/Pine/Spruce) + fine HF
  #    — intercept: Crop
  p_count_pa ~ Decid + Mixedwood + Pine + Spruce +
    TreedBog + TreedFen + TreedSwamp + GrassHerb +
    Shrub + Marsh + ShrubbySwamp + ShrubbyBogFen +
    CCDecidMixed + CCPine + CCSpruce +
    EnSoftLin + EnSeismic + TrSoftLin +
    TameP + RoughP + Well + RurUrbInd +
    seas_days + Climate,

  # 3. Grouped CC + split linear HF — intercept: Alien
  p_count_pa ~ Decid + Mixedwood + Pine + Spruce +
    TreedBog + TreedFen + TreedSwamp + GrassHerb +
    Shrub + Marsh + ShrubbySwamp + ShrubbyBogFen +
    CCDecidMixed + CCPine + CCSpruce +
    EnSoftLin + EnSeismic + TrSoftLin +
    seas_days + Climate,

  # 4. Grouped CC + combined SoftLin — intercept: Alien
  p_count_pa ~ Decid + Mixedwood + Pine + Spruce +
    TreedBog + TreedFen + TreedSwamp + GrassHerb +
    Shrub + Marsh + ShrubbySwamp + ShrubbyBogFen +
    CCDecidMixed + CCPine + CCSpruce +
    SoftLin + seas_days + Climate,

  # 5. Combined CCAll + SoftLin — intercept: Alien
  p_count_pa ~ Decid + Mixedwood + Pine + Spruce +
    TreedBog + TreedFen + TreedSwamp + GrassHerb +
    Shrub + Marsh + ShrubbySwamp + ShrubbyBogFen +
    CCAll + SoftLin + seas_days + Climate,

  # 6. TreedBogFen pooled + CCAll — intercept: Alien
  p_count_pa ~ Decid + Mixedwood + Pine + Spruce +
    TreedBogFen + TreedSwamp + GrassHerb + Shrub +
    OpenWet + CCAll + SoftLin + seas_days + Climate,

  # 7. Fine CC (R/1/2) + TreedWet + SoftLin
  #    — intercept: Alien
  p_count_pa ~ Decid + Mixedwood + Pine + Spruce +
    TreedWet + GrassShrub + OpenWet +
    CCDecidR + CCDecid1 + CCDecid2 +
    CCMixedwoodR + CCMixedwood1 + CCMixedwood2 +
    CCPineR + CCPine1 + CCSpruceR + CCSpruce1 +
    CCSpruce2 +
    SoftLin + seas_days + Climate,

  # 8. Grouped CC (DecidMixed/Conif) + TreedWet
  #    — intercept: Alien
  p_count_pa ~ Decid + Mixedwood + Pine + Spruce +
    TreedWet + GrassShrub + OpenWet +
    CCDecidMixed + CCConif + SoftLin +
    seas_days + Climate,

  # 9. DecidMixed + UpCon + CCDecidMixed/Conif
  #    — intercept: Alien
  p_count_pa ~ DecidMixed + UpCon + TreedWet +
    GrassShrub + OpenWet +
    CCDecidMixed + CCConif + SoftLin +
    seas_days + Climate,

  # 10. DecidMixed + UpCon + CCAll + fine HF
  #     — intercept: Crop
  p_count_pa ~ DecidMixed + UpCon + TreedWet +
    GrassShrub + OpenWet + CCAll + SoftLin +
    TameP + RoughP + Well + RurUrbInd +
    seas_days + Climate,

  # 11. DecidMixed + UpCon + CCAll + SoftLin
  #     — intercept: Alien
  p_count_pa ~ DecidMixed + UpCon + TreedWet +
    GrassShrub + OpenWet + CCAll + SoftLin +
    seas_days + Climate,

  # 12. DecidMixed + UpCon + Succ — intercept: Alien
  p_count_pa ~ DecidMixed + UpCon + TreedWet +
    GrassShrub + OpenWet + Succ +
    seas_days + Climate,

  # 13. Upland + Lowland + CCAll + SoftLin
  #     — intercept: Alien
  p_count_pa ~ Upland + Lowland + CCAll + SoftLin +
    seas_days + Climate,

  # 14. TreedAll + OpenAll + Succ — intercept: Alien
  p_count_pa ~ TreedAll + OpenAll + Succ +
    seas_days + Climate,

  # 15. UplandForest + Lowland + GrassShrub + Succ
  #     — intercept: Alien
  p_count_pa ~ UplandForest + Lowland + GrassShrub +
    Succ + seas_days + Climate,

  # 16. Upland + Lowland + Succ — intercept: Alien
  p_count_pa ~ Upland + Lowland + Succ +
    seas_days + Climate,

  # 17. Boreal + GrassShrub + Succ — intercept: Alien
  #     ("Boreal" = everything native except GrassShrub)
  p_count_pa ~ Boreal + GrassShrub + Succ +
    seas_days + Climate
)

stopifnot(length(pa_formulas) == 17L)
stopifnot(length(pa_intercept_cats) == 17L)

# ─────────────────────────────────────────────────
