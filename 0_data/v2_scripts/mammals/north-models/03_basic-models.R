# ---
# title:   Basic Habitat Models — North Region
# author:  Marcus Becker
# created: 2026-05-19
# updated: 2026-05-22
#
# previous scripts: 01_process-grid.R,
#                   02_process-data-files.R,
#                   climate/02_run-models.R
#
# inputs:
#   R Dataset SpTable for ABMI North mammal
#   coefficients 2026.RData
#     d, first_sp_col_summer, last_sp_col_summer,
#     first_sp_col_winter, last_sp_col_winter,
#     sp_table_summer, sp_table_winter,
#     sp_table_summer_ua, sp_table_winter_ua,
#     pred_matrix
#   All Species Climate Predictions.csv
#     Site-level Pr(present) from province-wide
#     climate models (climate/02_run-models.R)
#
# outputs:
#   2024 North Mammal Coefficients_<date>.Rdata
#     Coef.mean.all  total abundance coefficients
#     Coef.mean.se.all TA standard errors (density)
#     Coef.lci.all   lower 80% CI for TA
#     Coef.uci.all   upper 80% CI for TA
#     Coef.pa.all    presence/absence coefficients
#     Coef.pa.se.all PA standard errors (logit)
#     Coef.agp.all   abundance-given-presence coefs
#     Coef.agp.se.all AGP standard errors (log)
#   Lure effects North 2026.csv
#   Model weights Veg+HF North.csv
#   Model weights Age stand groupings.csv
#   Model weights Age spline versus null.csv
#
# notes:
#   Climate model predictions are joined as a
#   covariate in the PA models. The saved Climate
#   coefficient in Coef.pa.all is used downstream
#   to apply km2-level climate predictions during
#   grid prediction (Predictions.R).
#   WetlandMargin sites are excluded.
#   Bears excluded from winter (hibernation).
#   Space/climate residual modeling is deferred to
#   a future script; only veg+HF models are fit here.
#   Species excluded (data quality): Deer,
#   Red Squirrel, Weasels and Ermine, Porcupine,
#   White-tailed Jack Rabbit, Striped Skunk.
#   Paths marked !! need updating each cycle.
# ---

rm(list = ls())
gc()

# ── 1. Setup ─────────────────────────────────────

library(mgcv)
library(MuMIn)
library(tidyverse)

# Candidate PA model formulas (pa_formulas,
# pa_intercept_cats) defined in a separate script
# for clarity — sourced inside the species loop
f_models <- paste0(
  "1_code/2_habitat-modeling/2024/north-models/",
  "00_models.R"
)

g_drive <- paste0(
  "G:/Shared drives/ABMI Mammals/"
)

# Density file
f_data <- paste0(
  g_drive,
  "Data/Habitat Models/",
  "R Dataset SpTable for ABMI North ",
  "mammal coefficients 2024.RData"
)

f_climate_pred <- paste0(
  g_drive,
  "Results/Habitat Modeling/2024/",
  "Climate/Predictions/",
  "All Species Climate Predictions.csv"
)

# Output paths
f_out_dir <- paste0(
  g_drive,
  "Results/Habitat Modeling/2024/Landcover/North/"
)

# Coefficent tables
f_out_coefs <- paste0(
  f_out_dir, "Coefficient Tables/",
  "2024 North Mammal Coefficients_",
  Sys.Date(),
  ".Rdata"
)

f_out_lure <- paste0(
  g_drive, "Data/Lure/",
  "Lure effects North 2024.csv"
)

f_out_wts_veghf <- paste0(
  f_out_dir,
  "Model weights Veg+HF North.csv"
)

f_out_wts_age_group <- paste0(
  f_out_dir,
  "Model weights Age stand groupings.csv"
)

f_out_wts_age_spline <- paste0(
  f_out_dir,
  "Model weights Age spline versus null.csv"
)

# ── 2. Load data ─────────────────────────────────

load(f_data)

climate_pred <- read_csv(
  f_climate_pred, show_col_types = FALSE
)

# ── 3. Species table ─────────────────────────────

## 3.1 Exclude bears from winter models ----
# Bears hibernate; winter data are near-zero and
# not meaningful for habitat modeling.
sp_table_winter_model <- sp_table_winter[
  !grepl("Bear", sp_table_winter)
]

## 3.2 Combined species list (no season suffix) ----
sp_table <- sort(unique(c(
  gsub("Summer", "", sp_table_summer),
  gsub("Winter", "", sp_table_winter_model)
)))

# Remove species with unreliable data
sp_exclude <- c(
  "Deer", "Red Squirrel",
  "Weasels and Ermine", "Porcupine",
  "White-tailed Jack Rabbit", "Striped Skunk"
)
sp_table <- sp_table[!sp_table %in% sp_exclude]

seas_name <- c("Summer", "Winter")
n_sp      <- length(sp_table)

# ── 4. Coefficient storage arrays ────────────────

## 4.1 Coefficient variable names ----

# Fine veg+HF types used as coefficient names.
# Age classes (R, 1–8) stored separately for the
# five aged stand types. CC age classes 3–4 are
# filled by cutblock convergence post-hoc.
vnames_pa <- c(
  "Climate",
  paste0("Spruce", c("R", 1:8)),
  paste0("Pine", c("R", 1:8)),
  paste0("Decid", c("R", 1:8)),
  paste0("Mixedwood", c("R", 1:8)),
  paste0("TreedBog", c("R", 1:8)),
  "TreedFen", "TreedSwamp", "Shrub",
  "GrassHerb", "GraminoidFen", "Marsh",
  "ShrubbyBog", "ShrubbyFen", "ShrubbySwamp",
  paste0("CCSpruce", c("R", 1:4)),
  paste0("CCPine", c("R", 1:4)),
  paste0("CCDecid", c("R", 1:4)),
  paste0("CCMixedwood", c("R", 1:4)),
  "Crop", "TameP", "RoughP", "Urban", "Rural",
  "Industrial", "Well", "EnSoftLin", "EnSeismic",
  "TrSoftLin", "HardLin"
)

# AGP uses all-age totals for natural stands (no
# age suffix) but keeps CC age classes.
vnames_agp <- c(
  "Climate",
  "Spruce", "Pine", "Decid", "Mixedwood",
  "TreedBog", "TreedFen", "TreedSwamp",
  "Shrub", "GrassHerb", "GraminoidFen", "Marsh",
  "ShrubbyBog", "ShrubbyFen", "ShrubbySwamp",
  paste0("CCSpruce", c("R", 1:4)),
  paste0("CCPine", c("R", 1:4)),
  paste0("CCDecid", c("R", 1:4)),
  paste0("CCMixedwood", c("R", 1:4)),
  "Crop", "TameP", "RoughP", "Urban", "Rural",
  "Industrial", "Well", "EnSoftLin", "EnSeismic",
  "TrSoftLin", "HardLin"
)

## 4.2 Season × species × variable arrays ----

# Presence/absence
Coef.pa <- Coef.pa.se <-
  array(0, c(2, n_sp, length(vnames_pa)),
        dimnames = list(seas_name, sp_table,
                        vnames_pa))

# Abundance-given-presence
Coef.agp <- Coef.agp.se <-
  array(0, c(2, n_sp, length(vnames_agp)),
        dimnames = list(seas_name, sp_table,
                        vnames_agp))

# Total abundance (PA × AGP) with 80% CIs and SEs
Coef.mean <- Coef.mean.se <-
  Coef.lci <- Coef.uci <-
  array(0, c(2, n_sp, length(vnames_pa)),
        dimnames = list(seas_name, sp_table,
                        vnames_pa))

# AUC per season (PA and TA discrimination)
AUC <- AUC.ta <- matrix(
  NA_real_, nrow = 2, ncol = n_sp,
  dimnames = list(seas_name, sp_table)
)

# Season-averaged (species × variable)
Coef.pa.all <- Coef.pa.se.all <-
  Coef.mean.all <- Coef.mean.se.all <-
  Coef.lci.all <- Coef.uci.all <-
  array(0, c(n_sp, length(vnames_pa)),
        dimnames = list(sp_table, vnames_pa))

# AGP coefficients and SEs (use vnames_agp for dims)
Coef.agp.all <- Coef.agp.se.all <-
  array(0, c(n_sp, length(vnames_agp)),
        dimnames = list(sp_table, vnames_agp))

## 4.3 AIC weight and lure storage ----

aic.wt.pa.save <- array(
  NA, c(2, n_sp, 17),
  dimnames = list(seas_name, sp_table, NULL)
)
aic.wt.agp.save <- array(
  NA, c(2, n_sp, 18),
  dimnames = list(seas_name, sp_table, NULL)
)
aic.wt.age.save <- array(
  NA, c(2, n_sp, 3),
  dimnames = list(
    seas_name, sp_table,
    c("Separate", "Intermediate", "Combined")
  )
)
aic.wt.age.models.save <- array(
  NA, c(2, n_sp, 8),
  dimnames = list(
    seas_name, sp_table,
    c("Spruce", "Pine", "Decid", "Mixedwood",
      "TreedBog", "UpCon", "DecidMixed", "All")
  )
)
aic.age <- array(NA, c(2, n_sp, 3))

lure.pa  <- array(NA, c(2, n_sp))
lure.agp <- array(NA, c(2, n_sp))

# Minimum proportion for a site to contribute
# to age analysis for a given stand type
cutoff_pc_age <- 0.1

# ── 5. Data preparation ─────────────────────────

## 5.1 Remove WetlandMargin sites ----
d <- d |> filter(WetlandMargin != 1)

## 5.2 Prepare prediction matrix ----
# Remove WetlandMargin rows/columns and the
# Climate row (handled separately in the loop)
pm <- pred_matrix |>
  select(-WetlandMargin) |>
  filter(
    !VegType %in% c("WetlandMargin", "Climate")
  )

## 5.3 Pivot climate predictions to long ----
clim <- climate_pred |>
  pivot_longer(
    -location_project,
    names_to  = "Species",
    values_to = "Climate"
  )

## 5.4 Helper: confidence intervals ----
# PA × AGP combined CIs using z = 1.28 per
# component (10% tails each ≈ 5% combined,
# assuming independence)
compute_ci <- function(pa, pa_se, agp, agp_se) {
  lci <- plogis(qlogis(pa) - pa_se * 1.28) *
    exp(log(agp) - agp_se * 1.28)
  uci <- plogis(qlogis(pa) + pa_se * 1.28) *
    exp(log(agp) + agp_se * 1.28)
  list(lci = lci, uci = uci)
}

# Delta method SE for TA = PA × AGP:
#   pa, agp on natural scale; pa_se on logit
#   scale; agp_se on log scale.
compute_ta_se <- function(pa, pa_se, agp,
                          agp_se) {
  pa * agp * sqrt(
    ((1 - pa) * pa_se)^2 + agp_se^2
  )
}

# ── 6. Main modeling loop ────────────────────────

# For each species, fit candidate veg+HF models
# for presence/absence and abundance|presence,
# select the best by AICc, fit GAM age splines,
# and assemble total abundance coefficients.

for (sp in seq_along(sp_table)) {

  # Climate predictions for this species
  c_sp <- clim |>
    filter(Species == sp_table[sp]) |>
    select(location_project, Climate)

  for (seas in 1:2) {

    sp_seas <- paste0(sp_table[sp], seas_name[seas])

    # Only run if species qualifies this season
    run_season <- (
      (seas == 1 & sp_seas %in% sp_table_summer) |
      (seas == 2 & sp_seas %in% sp_table_winter_model)
    )
    if (!run_season) next

    message(
      sp, "/", n_sp, " ", sp_table[sp],
      " ", seas_name[seas], " ", Sys.time()
    )

    # ── Extract species data ──────────────────────

    # Non-species columns + target species count
    d_sp <- d[, c(
      names(d)[1:(first_sp_col_summer - 1)],
      names(d)[(last_sp_col_winter + 1):ncol(d)],
      sp_seas
    )]
    names(d_sp)[ncol(d_sp)] <- "Count"

    # Join site-level climate predictions
    d_sp <- d_sp |>
      inner_join(c_sp, by = "location_project") |>
      filter(!is.na(Climate), !is.na(Count))

    # Season-specific days and weights
    if (seas == 1) {
      d_sp$seas_days <- d_sp$SummerDays
    } else {
      d_sp$seas_days <- d_sp$WinterDays
    }

    # Filter: sufficient sampling days
    d_sp <- d_sp |> filter(seas_days > 10)

    # Season weight (free-standing vector for
    # the weights argument in glm)
    if (seas == 1) {
      seas_wt <- d_sp$wt_summer
    } else {
      seas_wt <- d_sp$wt_winter
    }

    # Lure-calibration: numbered ABMI grid sites
    use_lure <- grepl("^[[:digit:]]+", d_sp$location)

    # Lure effect on presence/absence
    q <- by(
      sign(d_sp$Count[use_lure]),
      d_sp$Lured[use_lure], mean
    )
    lure.pa[seas, sp] <- q["Yes"] / q["No"]

    # ── 6.1 Presence/absence (PA) models ──────────

    # Standardise to no-lure scale
    d_sp$p_count_pa <- sign(d_sp$Count) /
      ifelse(
        d_sp$Lured == "Yes",
        lure.pa[seas, sp], 1
      )
    d_sp$p_count_pa <- d_sp$p_count_pa /
      max(d_sp$p_count_pa)

    # Load 17 candidate formulas (pa_formulas,
    # pa_intercept_cats) from the companion script
    source(f_models, local = TRUE)
    n_models_pa <- length(pa_formulas)

    # Fit all candidate PA models; wrap each in
    # try() so a single convergence failure does not
    # abort the species loop
    m.pa <- lapply(pa_formulas, function(f) {
      try(
        glm(f, family = "binomial",
            data = d_sp, weights = seas_wt),
        silent = TRUE
      )
    })

    # AICc model selection
    aic_pa <- rep(Inf, n_models_pa)
    for (i in seq_len(n_models_pa)) {
      ok <- !is.null(m.pa[[i]]) &
        !inherits(m.pa[[i]], "try-error")
      if (ok) aic_pa[i] <- AICc(m.pa[[i]])
    }
    aic_delta  <- aic_pa - min(aic_pa)
    aic_wt_pa  <- exp(-0.5 * aic_delta) /
      sum(exp(-0.5 * aic_delta))
    best_pa    <- which.max(aic_wt_pa)
    aic.wt.pa.save[seas, sp, ] <- aic_wt_pa

    # ── 6.2 Abundance|presence (AGP) models ───────

    d_p <- d_sp |> filter(Count > 0)
    use_lure_p <- use_lure[d_sp$Count > 0]

    q <- by(
      d_p$Count[use_lure_p],
      d_p$Lured[use_lure_p], mean
    )
    lure.agp[seas, sp] <- q["Yes"] / q["No"]

    d_p$p_count_agp <- d_p$Count /
      ifelse(
        d_p$Lured == "Yes",
        lure.agp[seas, sp], 1
      )

    # Winsorize AGP response at the 99th percentile
    # of positive observations. Extreme density
    # estimates (valid but rare) exert outsized
    # leverage on Gamma GLM coefficients for sparse
    # habitat types.
    agp_cap <- quantile(d_p$p_count_agp, 0.99)
    d_p$p_count_agp <- pmin(
      d_p$p_count_agp, agp_cap
    )

    j_agp  <- 0
    m.agp  <- list(NULL)
    m_nums <- NULL

    # Stable starting values for Gamma(log): using
    # mustart = mean(y) avoids IWLS divergence that
    # occurs when mustart defaults to y itself
    # (which spans several orders of magnitude for
    # right-skewed density distributions)
    agp_start <- rep(
      mean(d_p$p_count_agp), nrow(d_p)
    )

    for (i in seq_len(n_models_pa)) {
      if (inherits(m.pa[[i]], "try-error")) next

      # Only require that the reference (intercept)
      # category is non-empty — a necessary condition
      # for model identification. The count threshold
      # previously used here (min(x) > 9) was
      # arbitrary; AICc + Gamma GLM correctly
      # penalise models with sparse habitat categories
      # without needing an explicit data filter.
      terms_i <- attr(
        m.pa[[i]]$terms, "term.labels"
      )
      x <- colSums(d_p[, terms_i])
      x <- x[
        !names(x) %in% c("Climate", "seas_days")
      ]

      if ((nrow(d_p) - sum(x)) > 0) {

        j_agp <- j_agp + 1

        # AGP drops Climate (climate effects on
        # abundance|presence are minimal)
        form_terms <- setdiff(terms_i, "Climate")
        new_formula <- as.formula(paste(
          "p_count_agp ~",
          paste(form_terms, collapse = " + ")
        ))

        m.agp[[j_agp]] <- try(glm(
          new_formula, data = d_p,
          family = Gamma(link = "log"),
          mustart = agp_start
        ))
        m_nums <- c(m_nums, i)
      }
    }

    # Null AGP model (seas_days only)
    m.agp[[j_agp + 1]] <- try(glm(
      p_count_agp ~ seas_days,
      data = d_p,
      family = Gamma(link = "log"),
      mustart = agp_start
    ))
    m_nums <- c(m_nums, n_models_pa + 1)

    n_models_agp <- length(m.agp)
    aic_agp <- rep(Inf, n_models_agp)
    for (i in seq_len(n_models_agp)) {
      ok <- !is.null(m.agp[[i]]) &
        !inherits(m.agp[[i]], "try-error")
      if (ok) aic_agp[i] <- AICc(m.agp[[i]])
    }
    aic_delta   <- aic_agp - min(aic_agp)
    aic_wt_agp  <- exp(-0.5 * aic_delta) /
      sum(exp(-0.5 * aic_delta))
    best_agp    <- which.max(aic_wt_agp)
    aic.wt.agp.save[seas, sp, m_nums] <- aic_wt_agp

    # Guard: if every AGP model failed, skip rather
    # than crash on m.agp[[integer(0)]]
    if (length(best_agp) == 0) {
      warning(
        "All AGP models failed for ",
        sp_table[sp], " ", seas_name[seas],
        " — skipping."
      )
      next
    }

    # ── 6.3 PA coefficient prediction ─────────────

    # Reference category for the best model
    # (pa_intercept_cats sourced from 00_models.R)
    intercept_cat <- pa_intercept_cats[best_pa]

    terms_pa <- c(
      attr(m.pa[[best_pa]]$terms, "term.labels"),
      intercept_cat
    )
    # Drop seas_days for coefficient extraction
    terms_pa1 <- terms_pa[terms_pa != "seas_days"]

    # Predict at 100% of each veg/HF type (all
    # others at 0, SeasDays = 100, Climate = 0)
    Coef1.pa    <- setNames(
      rep(NA_real_, length(terms_pa)), terms_pa
    )
    Coef1.pa.se <- Coef1.pa

    for (i in seq_along(terms_pa)) {
      pm1 <- setNames(
        rep(0, length(terms_pa)), terms_pa
      )
      pm1[i] <- 1
      p_pred <- predict(
        m.pa[[best_pa]],
        newdata = data.frame(
          seas_days = 100, Climate = 0,
          t(pm1)
        ),
        se.fit = TRUE
      )
      Coef1.pa[i]    <- plogis(p_pred$fit)
      Coef1.pa.se[i] <- p_pred$se.fit
    }

    # Override Climate with the actual fitted
    # coefficient on the probability scale
    Coef1.pa["Climate"] <- plogis(
      coef(m.pa[[best_pa]])[["Climate"]]
    )

    # Calibration: mean fitted PA = mean observed PA
    p_obs <- sign(d_sp$Count) /
      ifelse(
        d_sp$Lured == "Yes",
        lure.pa[seas, sp], 1
      )
    p_obs <- p_obs / max(p_obs)

    p_adj <- predict(
      m.pa[[best_pa]],
      newdata = d_sp |> mutate(seas_days = 100)
    )
    adj <- qlogis(mean(p_obs)) -
      qlogis(mean(plogis(p_adj)))

    # Exclude Climate from calibration: it is a
    # slope coefficient, not a habitat-type logit.
    # adj is an intercept shift that should only
    # apply to habitat types.
    climate_pa_raw <-
      Coef1.pa["Climate"]
    climate_se_raw <-
      Coef1.pa.se["Climate"]

    Coef1.pa <- plogis(qlogis(Coef1.pa) + adj)

    Coef1.pa["Climate"]    <- climate_pa_raw
    Coef1.pa.se["Climate"] <- climate_se_raw

    # Site-level logit predictions for age offsets
    d_sp$p <- predict(m.pa[[best_pa]])

    # ── 6.4 AGP coefficient prediction ────────────

    # Predict AGP for each fine VegType in pm
    p_agp_pred <- predict(
      m.agp[[best_agp]],
      newdata = data.frame(
        pm, seas_days = 100, Climate = 0
      ),
      se.fit = TRUE
    )
    t_mean_agp <- setNames(
      p_agp_pred$fit, pm$VegType
    )
    t_var_agp <- setNames(
      p_agp_pred$se.fit^2, pm$VegType
    )

    # No intermediate calibration here.
    # Raw log-scale predictions from the AGP model
    # are stored in Coef.agp; calibration of the
    # final product (PA × AGP = Coef.mean) is done
    # multiplicatively in section 6.6. An additive
    # shift here can produce log(negative) = NaN for
    # sparse habitat types when the model slightly
    # overestimates the mean, even though the type
    # is correctly covered by a lumped model term.

    # Climate multiplier for AGP = 1 (no climate
    # effect on abundance given presence)
    t_mean_agp <- c(Climate = 1, t_mean_agp)

    # Map broad model terms to fine VegType means
    Coef1.agp <- setNames(
      rep(NA_real_, length(terms_pa1)), terms_pa1
    )
    Coef1.agp.se <- Coef1.agp

    for (i in seq_along(terms_pa1)) {
      if (terms_pa1[i] == "Climate") {
        Coef1.agp["Climate"] <-
          t_mean_agp["Climate"]
        next
      }
      j_veg <- pm$VegType[pm[[terms_pa1[i]]] == 1]
      x_m   <- t_mean_agp[as.character(j_veg)]
      x_v   <- t_var_agp[as.character(j_veg)]
      Coef1.agp[i]    <- mean(x_m)
      Coef1.agp.se[i] <- sqrt(mean(x_v))
    }

    # Store in full AGP coefficient array by name
    # (avoids NA if any vnames_agp entry is absent
    # from t_mean_agp, and avoids off-by-one errors
    # since t_var_agp has no Climate entry)
    Coef.agp[seas, sp, "Climate"] <- 1
    matched_agp <- intersect(
      names(t_mean_agp), dimnames(Coef.agp)[[3]]
    ) |> setdiff("Climate")
    Coef.agp[seas, sp, matched_agp] <-
      exp(t_mean_agp[matched_agp])

    Coef.agp.se[seas, sp, ] <- 0
    matched_se <- intersect(
      names(t_var_agp), dimnames(Coef.agp)[[3]]
    )
    Coef.agp.se[seas, sp, matched_se] <-
      sqrt(t_var_agp[matched_se])

    # ── 6.5 Age models (GAM splines) ─────────────

    # Build per-stand-type data frames
    stand_types <- c(
      "Spruce", "Pine", "Decid",
      "Mixedwood", "TreedBog"
    )
    stand_dfs <- setNames(
      vector("list", 5), stand_types
    )

    for (i in 0:8) {
      age_lbl <- ifelse(i == 0, "R", as.character(i))
      age_yr  <- ifelse(i == 0, 0.5, i)

      for (st in stand_types) {
        cn <- paste0(st, age_lbl)
        if (!cn %in% names(d_sp)) next
        rows <- which(d_sp[[cn]] > cutoff_pc_age)
        if (length(rows) == 0) next

        row_df <- data.frame(
          p_count = d_sp$p_count_pa[rows],
          age     = age_yr,
          wt1     = d_sp[[cn]][rows] *
            seas_wt[rows],
          p       = d_sp$p[rows]
        )
        stand_dfs[[st]] <- rbind(
          stand_dfs[[st]], row_df
        )
      }
    }

    # Combined data frames
    d_upcon <- rbind(
      cbind(stand_dfs[["Spruce"]], Sp = "Spruce"),
      cbind(stand_dfs[["Pine"]],   Sp = "Pine")
    )
    d_decidmixed <- rbind(
      cbind(stand_dfs[["Decid"]],     Sp = "Decid"),
      cbind(stand_dfs[["Mixedwood"]], Sp = "Mixed")
    )
    d_all <- rbind(
      cbind(stand_dfs[["Spruce"]],    Sp = "Spruce"),
      cbind(stand_dfs[["Pine"]],      Sp = "Pine"),
      cbind(stand_dfs[["Decid"]],     Sp = "Decid"),
      cbind(stand_dfs[["Mixedwood"]], Sp = "Mixed"),
      cbind(stand_dfs[["TreedBog"]],  Sp = "TreedBog")
    )

    # All 8 stand groupings for the GAM fits
    all_stand_dfs <- list(
      stand_dfs[["Spruce"]],
      stand_dfs[["Pine"]],
      stand_dfs[["Decid"]],
      stand_dfs[["Mixedwood"]],
      stand_dfs[["TreedBog"]],
      d_upcon, d_decidmixed, d_all
    )

    # Fit spline and null GAM for each
    m.age      <- vector("list", 8)
    m.null.age <- vector("list", 8)

    for (i in seq_along(all_stand_dfs)) {
      df_i <- all_stand_dfs[[i]]
      m.null.age[[i]] <- gam(
        p_count ~ 1 + offset(p),
        data = df_i, family = "binomial",
        weights = df_i$wt1
      )
      if (sum(sign(df_i$p_count)) > 4) {
        m.age[[i]] <- gam(
          p_count ~ s(sqrt(age), k = 4, m = 2) +
            offset(p),
          data = df_i, family = "binomial",
          weights = df_i$wt1
        )
      } else {
        m.age[[i]] <- m.null.age[[i]]
      }
    }

    # AIC for three stand-grouping strategies:
    # 1) all 5 separate, 2) pairwise + TreedBog,
    # 3) all combined
    aic.age[seas, sp, 1] <-
      AIC(m.age[[1]]) + AIC(m.age[[2]]) +
      AIC(m.age[[3]]) + AIC(m.age[[4]]) +
      AIC(m.age[[5]]) - 8
    aic.age[seas, sp, 2] <-
      AIC(m.age[[5]]) + AIC(m.age[[6]]) +
      AIC(m.age[[7]]) - 4
    aic.age[seas, sp, 3] <- AIC(m.age[[8]])

    aic_d <- aic.age[seas, sp, ] -
      min(aic.age[seas, sp, ])
    aic.wt.age.save[seas, sp, ] <-
      exp(-0.5 * aic_d) / sum(exp(-0.5 * aic_d))

    # Per-stand-type: spline vs. null weight
    aic_wt_age_m <- numeric(8)
    for (i in 1:8) {
      q_i <- c(
        AICc(m.age[[i]]), AICc(m.null.age[[i]])
      )
      q_i <- q_i - min(q_i)
      aic_wt_age_m[i] <-
        exp(-0.5 * q_i[1]) / sum(exp(-0.5 * q_i))
    }
    names(aic_wt_age_m) <- c(
      "Spruce", "Pine", "Decid", "Mixedwood",
      "TreedBog", "UpCon", "DecidMixed", "TreedAll"
    )
    aic.wt.age.models.save[seas, sp, ] <-
      aic_wt_age_m

    # ── 6.6 Age predictions ──────────────────────

    age_flag <- setNames(
      rep(0L, 10),
      c("Spruce", "Pine", "Decid", "Mixedwood",
        "TreedBog", "TreedWet", "DecidMixed",
        "UpCon", "UplandForest", "TreedAll")
    )
    p_age <- p_age_se <-
      matrix(NA_real_, nrow = 10, ncol = 9,
             dimnames = list(names(age_flag), NULL))

    age_nd <- data.frame(age = c(0.5, 1:8))

    # Mapping: stand term → GAM index and AIC key
    age_map <- list(
      list("Spruce",       1, "Spruce"),
      list("Pine",         2, "Pine"),
      list("Decid",        3, "Decid"),
      list("Mixedwood",    4, "Mixedwood"),
      list("TreedBog",     5, "TreedBog"),
      list("TreedWet",     5, "TreedBog"),
      list("UpCon",        6, "UpCon"),
      list("DecidMixed",   7, "DecidMixed"),
      list("UplandForest", 8, "TreedAll"),
      list("TreedAll",     8, "TreedAll")
    )

    for (am in age_map) {
      term_i <- am[[1]]
      gam_i  <- am[[2]]
      wt_key <- am[[3]]

      if (!(term_i %in% terms_pa)) next
      if (aic_wt_age_m[wt_key] <= 0.5) next

      age_flag[term_i] <- 1L
      p_pred <- predict(
        m.age[[gam_i]],
        newdata = data.frame(
          age_nd,
          p = qlogis(Coef1.pa[term_i])
        ),
        se.fit = TRUE
      )
      p_age[term_i, ]    <- plogis(p_pred$fit)
      p_age_se[term_i, ] <- p_pred$se.fit
    }

    # Post-hoc smoothing of age curves to damp
    # extreme values from logit-scale extrapolation
    for (i in seq_len(nrow(p_age))) {
      y  <- p_age[i, ]
      ys <- p_age_se[i, ]
      if (all(is.na(y))) next
      p_age[i, ] <- c(
        mean(y[1:2]), y[2:4],
        mean(y[4:6]), mean(y[5:7]),
        mean(y[6:8]), mean(y[7:9]),
        mean(y[8:9])
      )
      p_age_se[i, ] <- c(
        mean(ys[1:2]), ys[2:4],
        mean(ys[4:6]), mean(ys[5:7]),
        mean(ys[6:8]), mean(ys[7:9]),
        mean(ys[8:9])
      )
    }

    # ── 6.7 Assemble total abundance coefficients ─

    for (i in seq_along(terms_pa1)) {

      # Climate: handled separately
      if (terms_pa1[i] == "Climate") {
        pa_v  <- Coef1.pa["Climate"]
        se_v  <- Coef1.pa.se["Climate"]
        agp_v <- Coef.agp[seas, sp, "Climate"]
        agp_se_v <- Coef.agp.se[seas, sp, "Climate"]

        Coef.pa[seas, sp, "Climate"]    <- pa_v
        Coef.pa.se[seas, sp, "Climate"] <- se_v
        Coef.mean[seas, sp, "Climate"]  <- pa_v * agp_v
        Coef.mean.se[seas, sp, "Climate"] <-
          compute_ta_se(pa_v, se_v, agp_v, agp_se_v)
        ci <- compute_ci(pa_v, se_v, agp_v, agp_se_v)
        Coef.lci[seas, sp, "Climate"] <- ci$lci
        Coef.uci[seas, sp, "Climate"] <- ci$uci
        next
      }

      # Fine VegTypes mapped to this broader term
      j_types <- as.character(
        pm$VegType[pm[[terms_pa1[i]]] == 1]
      )

      for (jt in j_types) {

        aged <- jt %in% c(
          "Spruce", "Pine", "Decid",
          "Mixedwood", "TreedBog"
        )

        if (aged) {
          # Stand types with age classes in the
          # coefficient arrays
          age_names <- paste0(
            jt, c("R", 1:8)
          )

          has_age <- !is.na(age_flag[terms_pa1[i]]) &
            age_flag[terms_pa1[i]] == 1

          if (has_age) {
            pa_vals <- p_age[terms_pa1[i], ]
            se_vals <- p_age_se[terms_pa1[i], ]
          } else {
            pa_vals <- rep(
              Coef1.pa[terms_pa1[i]], 9
            )
            se_vals <- rep(
              Coef1.pa.se[terms_pa1[i]], 9
            )
          }

          agp_v    <- Coef.agp[seas, sp, jt]
          agp_se_v <- Coef.agp.se[seas, sp, jt]

          Coef.pa[seas, sp, age_names]    <- pa_vals
          Coef.pa.se[seas, sp, age_names] <- se_vals
          Coef.mean[seas, sp, age_names]  <-
            pa_vals * agp_v
          Coef.mean.se[seas, sp, age_names] <-
            compute_ta_se(
              pa_vals, se_vals, agp_v, agp_se_v
            )
          ci <- compute_ci(
            pa_vals, se_vals, agp_v, agp_se_v
          )
          Coef.lci[seas, sp, age_names] <- ci$lci
          Coef.uci[seas, sp, age_names] <- ci$uci

        } else {
          # Non-aged types
          pa_v     <- Coef1.pa[terms_pa1[i]]
          se_v     <- Coef1.pa.se[terms_pa1[i]]
          agp_v    <- Coef.agp[seas, sp, jt]
          agp_se_v <- Coef.agp.se[seas, sp, jt]

          Coef.pa[seas, sp, jt]    <- pa_v
          Coef.pa.se[seas, sp, jt] <- se_v
          Coef.mean[seas, sp, jt]  <- pa_v * agp_v
          Coef.mean.se[seas, sp, jt] <-
            compute_ta_se(
              pa_v, se_v, agp_v, agp_se_v
            )
          ci <- compute_ci(
            pa_v, se_v, agp_v, agp_se_v
          )
          Coef.lci[seas, sp, jt] <- ci$lci
          Coef.uci[seas, sp, jt] <- ci$uci
        }
      }
    }

    # ── 6.8 Post-hoc species adjustments ──────────

    # Cap extreme old-growth extrapolations for
    # Mule Deer by averaging with next-younger class
    if (sp_table[sp] == "Mule Deer") {
      for (st in c("Pine")) {
        nms <- paste0(st, c("7", "8"))
        ref <- paste0(st, "6")
        for (arr in c("Coef.mean", "Coef.lci",
                       "Coef.uci")) {
          a <- get(arr)
          a[seas, sp, nms] <-
            (a[seas, sp, nms] + a[seas, sp, ref]) / 2
          assign(arr, a)
        }
      }
      if (seas == 2) {
        for (st in c("Decid")) {
          nms <- paste0(st, c("7", "8"))
          ref <- paste0(st, "6")
          for (arr in c("Coef.mean", "Coef.lci",
                         "Coef.uci")) {
            a <- get(arr)
            a[seas, sp, nms] <-
              (a[seas, sp, nms] +
                 a[seas, sp, ref]) / 2
            assign(arr, a)
          }
        }
      }
    }

    # ── 6.9 Calibration: scale Coef.mean ──────────

    # Use model predictions directly (logit/log
    # scale) rather than the probability-scale
    # colSums. The colSums approach adds
    # Coef1.pa["Climate"] × climate_value to a
    # habitat probability, which can exceed 1 →
    # NaN for common species at high-climate sites.
    t_p_pa <- plogis(
      predict(
        m.pa[[best_pa]],
        newdata = d_sp |>
          mutate(seas_days = 100)
      )
    )

    # AGP: Climate excluded from AGP formula
    t_p_agp <- predict(
      m.agp[[best_agp]],
      newdata = d_sp |>
        mutate(seas_days = 100)
    )
    p_ta <- t_p_pa * exp(t_p_agp)

    p_obs_total <- ifelse(
      d_sp$Lured == "Yes",
      d_sp$Count /
        (lure.pa[seas, sp] * lure.agp[seas, sp]),
      d_sp$Count
    )

    # Scale all Coef.mean values for this season
    scale_factor <- mean(p_obs_total) / mean(p_ta)
    Coef.mean[seas, sp, ] <-
      Coef.mean[seas, sp, ] * scale_factor
    Coef.mean.se[seas, sp, ] <-
      Coef.mean.se[seas, sp, ] * scale_factor
    Coef.lci[seas, sp, ] <-
      Coef.lci[seas, sp, ] * scale_factor
    Coef.uci[seas, sp, ] <-
      Coef.uci[seas, sp, ] * scale_factor

    # AUC (Wilcoxon/Mann-Whitney, no extra packages)
    # PA AUC: predicted PA probability vs observed
    # TA AUC: predicted TA density vs observed
    obs_pa <- as.integer(d_sp$Count > 0)
    pos_pa <- t_p_pa[obs_pa == 1]
    neg_pa <- t_p_pa[obs_pa == 0]
    AUC[seas, sp] <- tryCatch(
      mean(outer(pos_pa, neg_pa, ">")) +
        0.5 * mean(outer(pos_pa, neg_pa, "==")),
      error = function(e) NA_real_
    )

    p_ta_calibrated <- p_ta * scale_factor
    pos_ta <- p_ta_calibrated[obs_pa == 1]
    neg_ta <- p_ta_calibrated[obs_pa == 0]
    AUC.ta[seas, sp] <- tryCatch(
      mean(outer(pos_ta, neg_ta, ">")) +
        0.5 * mean(outer(pos_ta, neg_ta, "==")),
      error = function(e) NA_real_
    )

  } # end season loop

  # ── 6.10 Combine seasons ───────────────────────

  sp_summer <- paste0(sp_table[sp], "Summer")
  sp_winter <- paste0(sp_table[sp], "Winter")
  has_s <- sp_summer %in% sp_table_summer
  has_w <- sp_winter %in% sp_table_winter_model

  if (has_s & has_w) {
    Coef.pa.all[sp, ]      <- (Coef.pa[1, sp, ] +
                                  Coef.pa[2, sp, ]) / 2
    Coef.pa.se.all[sp, ]   <- (Coef.pa.se[1, sp, ] +
                                  Coef.pa.se[2, sp, ]) / 2
    Coef.agp.all[sp, ]      <- (Coef.agp[1, sp, ] +
                                 Coef.agp[2, sp, ]) / 2
    Coef.agp.se.all[sp, ]   <- (Coef.agp.se[1, sp, ] +
                                 Coef.agp.se[2, sp, ]) / 2
    Coef.mean.all[sp, ]    <- (Coef.mean[1, sp, ] +
                                  Coef.mean[2, sp, ]) / 2
    Coef.mean.se.all[sp, ] <- (Coef.mean.se[1, sp, ] +
                                  Coef.mean.se[2, sp, ]) / 2
    Coef.lci.all[sp, ]     <- (Coef.lci[1, sp, ] +
                                  Coef.lci[2, sp, ]) / 2
    Coef.uci.all[sp, ]     <- (Coef.uci[1, sp, ] +
                                  Coef.uci[2, sp, ]) / 2
  } else if (has_s) {
    Coef.pa.all[sp, ]      <- Coef.pa[1, sp, ]
    Coef.pa.se.all[sp, ]   <- Coef.pa.se[1, sp, ]
    Coef.agp.all[sp, ]      <- Coef.agp[1, sp, ]
    Coef.agp.se.all[sp, ]   <- Coef.agp.se[1, sp, ]
    Coef.mean.all[sp, ]    <- Coef.mean[1, sp, ]
    Coef.mean.se.all[sp, ] <- Coef.mean.se[1, sp, ]
    Coef.lci.all[sp, ]     <- Coef.lci[1, sp, ]
    Coef.uci.all[sp, ]     <- Coef.uci[1, sp, ]
  } else if (has_w) {
    Coef.pa.all[sp, ]      <- Coef.pa[2, sp, ]
    Coef.pa.se.all[sp, ]   <- Coef.pa.se[2, sp, ]
    Coef.agp.all[sp, ]      <- Coef.agp[2, sp, ]
    Coef.agp.se.all[sp, ]   <- Coef.agp.se[2, sp, ]
    Coef.mean.all[sp, ]    <- Coef.mean[2, sp, ]
    Coef.mean.se.all[sp, ] <- Coef.mean.se[2, sp, ]
    Coef.lci.all[sp, ]     <- Coef.lci[2, sp, ]
    Coef.uci.all[sp, ]     <- Coef.uci[2, sp, ]
  }

  # ── 6.11 Cutblock convergence ──────────────────

  # Older CC age classes converge toward natural
  # stand equivalents. Convergence weights are based
  # on the proportion of original veg recovered at
  # each CC age class.
  cc_conv <- list(
    list("CCSpruce",    "Spruce",    c(2, 3, 4),
         c(0.500, 0.849, 0.960)),
    list("CCPine",      "Pine",      c(2, 3, 4),
         c(0.500, 0.849, 0.960)),
    list("CCMixedwood", "Mixedwood", c(2, 3, 4),
         c(0.705, 0.912, 0.970)),
    list("CCDecid",     "Decid",     c(2, 3, 4),
         c(0.705, 0.912, 0.970))
  )

  for (cv in cc_conv) {
    cc_pre  <- cv[[1]]
    nat_pre <- cv[[2]]
    ages    <- cv[[3]]
    wts     <- cv[[4]]

    for (k in seq_along(ages)) {
      cc_nm  <- paste0(cc_pre,  ages[k])
      nat_nm <- paste0(nat_pre, ages[k])
      w      <- wts[k]

      for (arr_nm in c("Coef.mean.all",
                        "Coef.lci.all",
                        "Coef.uci.all")) {
        a <- get(arr_nm)
        a[sp, cc_nm] <-
          a[sp, cc_nm] * (1 - w) +
          a[sp, nat_nm] * w
        assign(arr_nm, a)
      }
    }
  }

} # end species loop

# ── 7. Finalize and save ─────────────────────────

## 7.1 Add Bare and Water columns ----
# Not modeled; assumed zero density
for (arr_nm in c("Coef.mean.all", "Coef.mean.se.all",
                 "Coef.lci.all", "Coef.uci.all",
                 "Coef.pa.all", "Coef.pa.se.all",
                 "Coef.agp.all", "Coef.agp.se.all")) {
  a <- get(arr_nm)
  a <- cbind(a, Bare = 0, Water = 0)
  assign(arr_nm, a)
}

## 7.2 Save coefficient tables ----
save(
  Coef.mean.all,
  Coef.mean.se.all,
  Coef.lci.all,
  Coef.uci.all,
  Coef.pa.all,
  Coef.pa.se.all,
  Coef.agp.all,
  Coef.agp.se.all,
  AUC,
  AUC.ta,
  file = f_out_coefs
)

## 7.3 Save lure effects ----
q_lure <- bind_rows(
  tibble(
    Season = "Summer", Measure = "PresAbs",
    as_tibble(t(lure.pa[1, ]),
              .name_repair = ~ sp_table)
  ),
  tibble(
    Season = "Summer", Measure = "AGP",
    as_tibble(t(lure.agp[1, ]),
              .name_repair = ~ sp_table)
  ),
  tibble(
    Season = "Winter", Measure = "PresAbs",
    as_tibble(t(lure.pa[2, ]),
              .name_repair = ~ sp_table)
  ),
  tibble(
    Season = "Winter", Measure = "AGP",
    as_tibble(t(lure.agp[2, ]),
              .name_repair = ~ sp_table)
  )
)
write_csv(q_lure, f_out_lure)

## 7.4 Save model weights ----

# Veg+HF PA and AGP weights
q_wts <- bind_rows(
  tibble(
    Season = "Summer", Measure = "PresAbs",
    Model = seq_len(ncol(aic.wt.pa.save[1, , ])),
    as_tibble(t(aic.wt.pa.save[1, , ]),
              .name_repair = ~ sp_table)
  ),
  tibble(
    Season = "Summer", Measure = "AGP",
    Model = seq_len(ncol(aic.wt.agp.save[1, , ])),
    as_tibble(t(aic.wt.agp.save[1, , ]),
              .name_repair = ~ sp_table)
  ),
  tibble(
    Season = "Winter", Measure = "PresAbs",
    Model = seq_len(ncol(aic.wt.pa.save[2, , ])),
    as_tibble(t(aic.wt.pa.save[2, , ]),
              .name_repair = ~ sp_table)
  ),
  tibble(
    Season = "Winter", Measure = "AGP",
    Model = seq_len(ncol(aic.wt.agp.save[2, , ])),
    as_tibble(t(aic.wt.agp.save[2, , ]),
              .name_repair = ~ sp_table)
  )
)
write_csv(q_wts, f_out_wts_veghf)

# Age stand-grouping weights
q_age <- bind_rows(
  tibble(
    Season = "Summer", Measure = "PresAbs",
    Grouping = c("Separate", "Intermediate",
                 "Combined"),
    as_tibble(t(aic.wt.age.save[1, , ]),
              .name_repair = ~ sp_table)
  ),
  tibble(
    Season = "Winter", Measure = "PresAbs",
    Grouping = c("Separate", "Intermediate",
                 "Combined"),
    as_tibble(t(aic.wt.age.save[2, , ]),
              .name_repair = ~ sp_table)
  )
)
write_csv(q_age, f_out_wts_age_group)

# Age spline vs. null weights
q_spline <- bind_rows(
  tibble(
    Season = "Summer", Measure = "PresAbs",
    VegType = c("Spruce", "Pine", "Decid",
                "Mixedwood", "TreedBog",
                "UpCon", "DecidMixed", "All"),
    as_tibble(
      t(aic.wt.age.models.save[1, , ]),
      .name_repair = ~ sp_table)
  ),
  tibble(
    Season = "Winter", Measure = "PresAbs",
    VegType = c("Spruce", "Pine", "Decid",
                "Mixedwood", "TreedBog",
                "UpCon", "DecidMixed", "All"),
    as_tibble(
      t(aic.wt.age.models.save[2, , ]),
      .name_repair = ~ sp_table)
  )
)
write_csv(q_spline, f_out_wts_age_spline)

message("Done: ", Sys.time())

# ─────────────────────────────────────────────────
