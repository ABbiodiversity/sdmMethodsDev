# ---
# title:   Candidate PA Model Formulas — South
# author:  Marcus Becker, David J. Huggard
# created: 2026-05-21
# updated: 2026-05-21
#
# notes:
#   Sourced by 03_basic-models.R inside the species
#   × season loop. Assumes d_sp is already filtered
#   and contains p_count_pa, seas_days, Climate, pAspen,
#   and all required soil+HF columns.
#
#   30 candidate models: 15 base (soil+HF) + 15 with
#   pAspen. Climate enters every model as a linear
#   predictor. Models progress from fine-grained
#   soil+HF resolution (model 1) to coarse aggregation
#   (model 15).
#
#   Reference (intercept) categories:
#   models 1–3, 5–6, 8–9, 11–12 → Loamy
#   models 4, 7, 10, 13           → AllNative
#   model 14                       → AllNativeSucc
#   model 15                       → AllExceptMargin
#   Models 16–30 repeat this pattern.
# ---

# ── PA model formulas ────────────────────────────

pa_intercept_cats <- rep(
  c("Loamy", "Loamy", "Loamy", "AllNative",
    "Loamy", "Loamy", "AllNative",
    "Loamy", "Loamy", "AllNative",
    "Loamy", "Loamy", "AllNative",
    "AllNativeSucc", "AllExceptMargin"),
  2
)

pa_formulas <- list(

  # ── Base models (1–15, no pAspen) ──────────────

  # 1. Fine soil + fine HF — intercept: Loamy
  p_count_pa ~ ClayWet + SandyLoam + RapidDrain +
    ThinBlow + WetlandMargin +
    RurUrbInd + Well + RoughP + TameP + Crop +
    EnSoftLinSeismic + TrSoftLin +
    seas_days + Climate,

  # 2. Sandy combined — intercept: Loamy
  p_count_pa ~ ClayWet + SandyRapid + ThinBlow +
    WetlandMargin +
    RurUrbInd + Well + RoughP + TameP + Crop +
    EnSoftLinSeismic + TrSoftLin +
    seas_days + Climate,

  # 3. Nonproductive combined — intercept: Loamy
  p_count_pa ~ SandyLoam + Nonproductive +
    WetlandMargin +
    RurUrbInd + Well + RoughP + TameP + Crop +
    EnSoftLinSeismic + TrSoftLin +
    seas_days + Climate,

  # 4. All native soil — intercept: AllNative
  p_count_pa ~ WetlandMargin +
    RurUrbInd + Well + RoughP + TameP + Crop +
    EnSoftLinSeismic + TrSoftLin +
    seas_days + Climate,

  # 5. Sandy + cultivation — intercept: Loamy
  p_count_pa ~ ClayWet + SandyRapid + ThinBlow +
    WetlandMargin +
    RurUrbInd + Well + Cult +
    EnSoftLinSeismic + TrSoftLin +
    seas_days + Climate,

  # 6. Nonproductive + cultivation
  #    — intercept: Loamy
  p_count_pa ~ SandyLoam + Nonproductive +
    WetlandMargin +
    RurUrbInd + Well + Cult +
    EnSoftLinSeismic + TrSoftLin +
    seas_days + Climate,

  # 7. AllNative + cultivation
  #    — intercept: AllNative
  p_count_pa ~ WetlandMargin +
    RurUrbInd + Well + Cult +
    EnSoftLinSeismic + TrSoftLin +
    seas_days + Climate,

  # 8. Sandy + cultivation + NonAgAlien + Succ
  #    — intercept: Loamy
  p_count_pa ~ ClayWet + SandyRapid + ThinBlow +
    WetlandMargin +
    NonAgAlien + Cult + Succ +
    seas_days + Climate,

  # 9. Nonproductive + cultivation + NonAgAlien
  #    — intercept: Loamy
  p_count_pa ~ SandyLoam + Nonproductive +
    WetlandMargin +
    NonAgAlien + Cult + Succ +
    seas_days + Climate,

  # 10. AllNative + cultivation + NonAgAlien
  #     — intercept: AllNative
  p_count_pa ~ WetlandMargin +
    NonAgAlien + Cult + Succ +
    seas_days + Climate,

  # 11. Sandy + all Alien + Succ
  #     — intercept: Loamy
  p_count_pa ~ ClayWet + SandyRapid + ThinBlow +
    WetlandMargin +
    Alien + Succ +
    seas_days + Climate,

  # 12. Nonproductive + all Alien + Succ
  #     — intercept: Loamy
  p_count_pa ~ SandyLoam + Nonproductive +
    WetlandMargin +
    Alien + Succ +
    seas_days + Climate,

  # 13. AllNative + all Alien + Succ
  #     — intercept: AllNative
  p_count_pa ~ WetlandMargin +
    Alien + Succ +
    seas_days + Climate,

  # 14. AllNativeSucc + Alien
  #     — intercept: AllNativeSucc
  p_count_pa ~ WetlandMargin +
    Alien +
    seas_days + Climate,

  # 15. AllExceptMargin
  #     — intercept: AllExceptMargin
  p_count_pa ~ WetlandMargin +
    seas_days + Climate,

  # ── pAspen models (16–30) ─────────────────────

  # 16. = model 1 + pAspen
  p_count_pa ~ ClayWet + SandyLoam + RapidDrain +
    ThinBlow + WetlandMargin +
    RurUrbInd + Well + RoughP + TameP + Crop +
    EnSoftLinSeismic + TrSoftLin +
    pAspen + seas_days + Climate,

  # 17. = model 2 + pAspen
  p_count_pa ~ ClayWet + SandyRapid + ThinBlow +
    WetlandMargin +
    RurUrbInd + Well + RoughP + TameP + Crop +
    EnSoftLinSeismic + TrSoftLin +
    pAspen + seas_days + Climate,

  # 18. = model 3 + pAspen
  p_count_pa ~ SandyLoam + Nonproductive +
    WetlandMargin +
    RurUrbInd + Well + RoughP + TameP + Crop +
    EnSoftLinSeismic + TrSoftLin +
    pAspen + seas_days + Climate,

  # 19. = model 4 + pAspen
  p_count_pa ~ WetlandMargin +
    RurUrbInd + Well + RoughP + TameP + Crop +
    EnSoftLinSeismic + TrSoftLin +
    pAspen + seas_days + Climate,

  # 20. = model 5 + pAspen
  p_count_pa ~ ClayWet + SandyRapid + ThinBlow +
    WetlandMargin +
    RurUrbInd + Well + Cult +
    EnSoftLinSeismic + TrSoftLin +
    pAspen + seas_days + Climate,

  # 21. = model 6 + pAspen
  p_count_pa ~ SandyLoam + Nonproductive +
    WetlandMargin +
    RurUrbInd + Well + Cult +
    EnSoftLinSeismic + TrSoftLin +
    pAspen + seas_days + Climate,

  # 22. = model 7 + pAspen
  p_count_pa ~ WetlandMargin +
    RurUrbInd + Well + Cult +
    EnSoftLinSeismic + TrSoftLin +
    pAspen + seas_days + Climate,

  # 23. = model 8 + pAspen
  p_count_pa ~ ClayWet + SandyRapid + ThinBlow +
    WetlandMargin +
    NonAgAlien + Cult + Succ +
    pAspen + seas_days + Climate,

  # 24. = model 9 + pAspen
  p_count_pa ~ SandyLoam + Nonproductive +
    WetlandMargin +
    NonAgAlien + Cult + Succ +
    pAspen + seas_days + Climate,

  # 25. = model 10 + pAspen
  p_count_pa ~ WetlandMargin +
    NonAgAlien + Cult + Succ +
    pAspen + seas_days + Climate,

  # 26. = model 11 + pAspen
  p_count_pa ~ ClayWet + SandyRapid + ThinBlow +
    WetlandMargin +
    Alien + Succ +
    pAspen + seas_days + Climate,

  # 27. = model 12 + pAspen
  p_count_pa ~ SandyLoam + Nonproductive +
    WetlandMargin +
    Alien + Succ +
    pAspen + seas_days + Climate,

  # 28. = model 13 + pAspen
  p_count_pa ~ WetlandMargin +
    Alien + Succ +
    pAspen + seas_days + Climate,

  # 29. = model 14 + pAspen
  p_count_pa ~ WetlandMargin +
    Alien +
    pAspen + seas_days + Climate,

  # 30. = model 15 + pAspen
  p_count_pa ~ WetlandMargin +
    pAspen + seas_days + Climate
)

stopifnot(length(pa_formulas) == 30L)
stopifnot(length(pa_intercept_cats) == 30L)

# ─────────────────────────────────────────────────
