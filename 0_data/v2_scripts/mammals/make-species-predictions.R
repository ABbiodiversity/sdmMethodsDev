# ---
# title:   Habitat + Climate Predictions —
#          Full Province (North + South)
# author:  Marcus Becker
# created: 2025-06-01
# updated: 2026-05-26
#
# previous scripts:
#   north/03_basic-models.R
#     → Coef.pa.all, Coef.mean.all,
#       Coef.pa.se.all, Coef.agp.all,
#       Coef.agp.se.all, Coef.lci.all,
#       Coef.uci.all
#   south/03_basic-models.R
#     → Coef.pa.all, Coef.mean.all,
#       Coef.pa.se.all, Coef.agp.all,
#       Coef.agp.se.all, Coef.lci.all,
#       Coef.uci.all, paspen_pa_all,
#       paspen_agp_all
#   climate/02_run-models.R
#     → per-species climate coefficient files
#
# notes:
#   Predicts total abundance (TA = PA × AGP)
#   in animals/km² for each 1km² grid cell
#   across the province.
#
#   North predictions use veg+HF age-class
#   composition (veg.cur); south predictions
#   use soil+HF composition (soil.cur).
#   Cells in the transition zone are blended
#   using wN/wS weights from the kgrid.
#
#   Climate handling:
#     Climate enters PA only (AGP Climate = 1).
#     For each cell i and habitat type v:
#       PA_adj = plogis(climate_logit[i] +
#                       logit(PA_v))
#       TA_v   = PA_adj × AGP_v
#              = Coef.mean_v × (PA_adj / PA_v)
#     South also includes pAspen adjustments
#     to both PA (logit scale) and AGP (log
#     scale).
# ---

# ── 1. Setup ─────────────────────────────────────

rm(list = ls())
gc()

library(tidyverse)
library(Matrix)
library(sf)
library(terra)
library(tidyterra)
library(MetBrewer)

g_drive <- paste0(
  "G:/Shared drives/ABMI Mammals/",
  "Results/Habitat Modeling/2024/"
)

options(scipen = 9999)

# Link functions (for PA component)
logit    <- binomial()$linkfun
inv_logit <- binomial()$linkinv

# ── 2. File paths ────────────────────────────────

f_coefs_north <- paste0(
  g_drive,
  "Landcover/North/Coefficient Tables/",
  "2024 North Mammal Coefficients_",
  "2026-06-10.Rdata"
)

f_coefs_south <- paste0(
  g_drive,
  "Landcover/South/Coefficient Tables/",
  "2024 South Mammal Coefficients_",
  "2026-06-10.Rdata"
)

climate_coefs_folder <- paste0(
  g_drive, "Climate/Coefficients/"
)

predictions_map_folder <- paste0(
  g_drive, "Prediction Maps/"
)

# Update each cycle
f_out_results <- paste0(
  g_drive,
  "2024 Full Province Mammal ",
  "Coefficients and Predictions_",
  Sys.Date(),
  ".Rdata"
)

# ── 3. Load coefficients ────────────────────────

## 3.1 North ----
# Load into isolated environment to avoid
# name collision with south objects
e_n <- new.env()
load(f_coefs_north, envir = e_n)

north_mean    <- e_n$Coef.mean.all
north_mean_se <- e_n$Coef.mean.se.all
north_pa      <- e_n$Coef.pa.all
north_pa_se   <- e_n$Coef.pa.se.all
north_agp     <- e_n$Coef.agp.all
north_agp_se  <- e_n$Coef.agp.se.all
north_lci     <- e_n$Coef.lci.all
north_uci     <- e_n$Coef.uci.all
north_auc     <- e_n$AUC
north_auc_ta  <- e_n$AUC.ta

## 3.2 South ----
e_s <- new.env()
load(f_coefs_south, envir = e_s)

south_mean    <- e_s$Coef.mean.all
south_mean_se <- e_s$Coef.mean.se.all
south_pa      <- e_s$Coef.pa.all
south_pa_se   <- e_s$Coef.pa.se.all
south_agp     <- e_s$Coef.agp.all
south_agp_se  <- e_s$Coef.agp.se.all
south_lci     <- e_s$Coef.lci.all
south_uci     <- e_s$Coef.uci.all
south_auc     <- e_s$AUC
south_auc_ta  <- e_s$AUC.ta
south_paspen_pa     <- e_s$paspen_pa_all
south_paspen_agp    <- e_s$paspen_agp_all
south_paspen_pa_se  <- e_s$paspen_pa_se_all
south_paspen_agp_se <- e_s$paspen_agp_se_all

rm(e_n, e_s)

# Exclude "Deer" (combined category) from south;
# White-tailed Deer and Mule Deer are modeled
# separately.
south_mean <- south_mean[
  rownames(south_mean) != "Deer", , drop = FALSE
]
south_mean_se <- south_mean_se[
  rownames(south_mean_se) != "Deer", , drop = FALSE
]
south_pa <- south_pa[
  rownames(south_pa) != "Deer", , drop = FALSE
]
south_pa_se <- south_pa_se[
  rownames(south_pa_se) != "Deer", , drop = FALSE
]
south_agp <- south_agp[
  rownames(south_agp) != "Deer", , drop = FALSE
]
south_agp_se <- south_agp_se[
  rownames(south_agp_se) != "Deer", , drop = FALSE
]
south_lci <- south_lci[
  rownames(south_lci) != "Deer", , drop = FALSE
]
south_uci <- south_uci[
  rownames(south_uci) != "Deer", , drop = FALSE
]
south_paspen_pa     <- south_paspen_pa[
  names(south_paspen_pa) != "Deer"
]
south_paspen_agp    <- south_paspen_agp[
  names(south_paspen_agp) != "Deer"
]
south_paspen_pa_se  <- south_paspen_pa_se[
  names(south_paspen_pa_se) != "Deer"
]
south_paspen_agp_se <- south_paspen_agp_se[
  names(south_paspen_agp_se) != "Deer"
]

## 3.3 Rename columns to match kgrid ----

rename_north_cols <- function(m) {
  colnames(m) <- gsub(
    "Decid", "Deciduous", colnames(m)
  )
  colnames(m) <- gsub(
    "Spruce", "WhiteSpruce", colnames(m)
  )
  colnames(m) <- gsub(
    "TreedBog", "BlackSpruce", colnames(m)
  )
  colnames(m) <- gsub(
    "GrassHerb", "Grass", colnames(m)
  )
  colnames(m) <- gsub(
    "^Well$", "Wellsites", colnames(m)
  )
  m <- m[, colnames(m) != "Urban",
         drop = FALSE]
  colnames(m) <- gsub(
    "^Industrial$", "UrbInd", colnames(m)
  )
  m
}

rename_south_cols <- function(m) {
  colnames(m) <- gsub(
    "^Well$", "Wellsites", colnames(m)
  )
  m <- m[, colnames(m) != "Urban",
         drop = FALSE]
  colnames(m) <- gsub(
    "^Industrial$", "UrbInd", colnames(m)
  )
  m
}

north_mean    <- rename_north_cols(north_mean)
north_mean_se <- rename_north_cols(north_mean_se)
north_pa      <- rename_north_cols(north_pa)
north_pa_se   <- rename_north_cols(north_pa_se)
north_agp     <- rename_north_cols(north_agp)
north_agp_se  <- rename_north_cols(north_agp_se)
north_lci     <- rename_north_cols(north_lci)
north_uci     <- rename_north_cols(north_uci)

south_mean    <- rename_south_cols(south_mean)
south_mean_se <- rename_south_cols(south_mean_se)
south_pa      <- rename_south_cols(south_pa)
south_pa_se   <- rename_south_cols(south_pa_se)
south_agp     <- rename_south_cols(south_agp)
south_agp_se  <- rename_south_cols(south_agp_se)
south_lci     <- rename_south_cols(south_lci)
south_uci     <- rename_south_cols(south_uci)

## 3.4 Expand north AGP to match north PA ----

# AGP has simplified habitat names (e.g., WhiteSpruce),
# while PA has age-class variants (WhiteSpruceR, WhiteSpruce1-8).
# Build expanded AGP matrix matching PA structure by replicating
# coefficients across age-class columns.
expand_agp_to_pa <- function(agp, pa) {
  agp <- as.data.frame(agp)
  
  # Start with empty result matrix with PA column structure
  result <- matrix(NA_real_, nrow = nrow(agp), ncol = ncol(pa))
  rownames(result) <- rownames(agp)
  colnames(result) <- colnames(pa)
  
  # For each PA column, find the corresponding AGP value
  for (col in colnames(pa)) {
    # Check if column exists directly in AGP
    if (col %in% colnames(agp)) {
      result[, col] <- agp[, col]
    } else {
      # Strip age-class suffix (R or 1-8) to find base habitat type
      base_name <- sub("(R|[0-9]+)$", "", col)
      if (base_name %in% colnames(agp)) {
        result[, col] <- agp[, base_name]
      }
    }
  }
  
  as.matrix(result)
}

north_agp <- expand_agp_to_pa(north_agp, north_pa)
north_agp_se <- expand_agp_to_pa(north_agp_se, north_pa)

## 3.5 Set unmodelled cover types to zero ----

# North: Mine, SnowIce, HWater not in camera
# data; assume zero density
for (nm in c("Mine", "SnowIce", "HWater")) {
  north_mean  <- cbind(north_mean,
    setNames(data.frame(0), nm))
  north_mean_se <- cbind(north_mean_se,
    setNames(data.frame(NA_real_), nm))
  north_pa    <- cbind(north_pa,
    setNames(data.frame(0), nm))
  north_pa_se <- cbind(north_pa_se,
    setNames(data.frame(NA_real_), nm))
  north_lci   <- cbind(north_lci,
    setNames(data.frame(0), nm))
  north_uci   <- cbind(north_uci,
    setNames(data.frame(0), nm))
  north_agp   <- cbind(north_agp,
    setNames(data.frame(0), nm))
  north_agp_se <- cbind(north_agp_se,
    setNames(data.frame(NA_real_), nm))
}

# South: SoilUnknown, HWater, HFor not modeled
for (nm in c("SoilUnknown", "HWater", "HFor")) {
  south_mean  <- cbind(south_mean,
    setNames(data.frame(0), nm))
  south_mean_se <- cbind(south_mean_se,
    setNames(data.frame(NA_real_), nm))
  south_pa    <- cbind(south_pa,
    setNames(data.frame(0), nm))
  south_pa_se <- cbind(south_pa_se,
    setNames(data.frame(NA_real_), nm))
  south_agp   <- cbind(south_agp,
    setNames(data.frame(0), nm))
  south_agp_se <- cbind(south_agp_se,
    setNames(data.frame(NA_real_), nm))
  south_lci   <- cbind(south_lci,
    setNames(data.frame(0), nm))
  south_uci   <- cbind(south_uci,
    setNames(data.frame(0), nm))
}

# Coerce to matrix (cbind with data.frame columns
# above converts from matrix → data.frame, which
# breaks named-vector subsetting in the loop)
north_mean    <- as.matrix(north_mean)
north_mean_se <- as.matrix(north_mean_se)
north_pa      <- as.matrix(north_pa)
north_pa_se   <- as.matrix(north_pa_se)
north_agp     <- as.matrix(north_agp)
north_agp_se  <- as.matrix(north_agp_se)
north_lci     <- as.matrix(north_lci)
north_uci     <- as.matrix(north_uci)
south_mean    <- as.matrix(south_mean)
south_mean_se <- as.matrix(south_mean_se)
south_pa      <- as.matrix(south_pa)
south_pa_se   <- as.matrix(south_pa_se)
south_agp     <- as.matrix(south_agp)
south_agp_se  <- as.matrix(south_agp_se)
south_lci     <- as.matrix(south_lci)
south_uci     <- as.matrix(south_uci)

# ── 4. Species crosswalk ────────────────────────

# South coefficient row names are PascalCase;
# north and climate files use full names.
# Explicit mapping for south → canonical name.
south_to_canonical <- c(
  "Badger"                    = "Badger",
  "BlackBear"                 = "Black Bear",
  "Coyote"                    = "Coyote",
  "ElkWapiti"                 = "Elk (wapiti)",
  "Moose"                     = "Moose",
  "MuleDeer"                  = "Mule Deer",
  "Porcupine"                 = "Porcupine",
  "Pronghorn"                 = "Pronghorn",
  "RedFox"                    = "Red Fox",
  "RichardsonsGroundSquirrel" =
    "Richardson's Ground Squirrel",
  "SnowshoeHare"              = "Snowshoe Hare",
  "StripedSkunk"              = "Striped Skunk",
  "WhiteTailedDeer"           =
    "White-tailed Deer",
  "WhiteTailedJackRabbit"     =
    "White-tailed Jack Rabbit"
)

# Build full species list with region flags
sp_north <- rownames(north_mean)
sp_south_canonical <- south_to_canonical[
  rownames(south_mean)
]

all_species <- sort(unique(c(
  sp_north, sp_south_canonical
)))

sp_info <- tibble(
  canonical  = all_species,
  has_north  = canonical %in% sp_north,
  has_south  = canonical %in% sp_south_canonical,
  # Reverse lookup: canonical → south row name
  south_name = names(south_to_canonical)[
    match(canonical, south_to_canonical)
  ]
)

message(
  nrow(sp_info), " species: ",
  sum(sp_info$has_north & sp_info$has_south),
  " both, ",
  sum(sp_info$has_north & !sp_info$has_south),
  " north-only, ",
  sum(!sp_info$has_north & sp_info$has_south),
  " south-only"
)

# ── 5. Load spatial data ────────────────────────

# kgrid
load("S:/sc/AB_data_v2023/kgrid/kgrid_2.2.Rdata")

# Landcover
load(paste0(
  "S:/sc/AB_data_v2023/landcover/",
  "backfillV7_w2w_2021HFI.Rdata"
))

source("1_code/2_habitat-modeling/2024/00_functions.R")

veg_lookup <- read.csv(paste0(
  "G:/Shared drives/ABMI Mammals/",
  "Data/Habitat Models/",
  "lookup-veg-hf-age-v2020.csv"
))

soil_lookup <- read.csv(paste0(
  "G:/Shared drives/ABMI Mammals/",
  "Data/Habitat Models/",
  "lookup-soil-hf-v2020.csv"
))

# Kgrid auxiliary columns for climate models
kgrid$"(Intercept)"   <- 1
kgrid$Easting2        <- kgrid$Easting^2
kgrid$Northing2       <- kgrid$Northing^2
kgrid$EastingNorthing <-
  kgrid$Easting * kgrid$Northing

# ── 6. Build composition grids ──────────────────

## 6.1 Veg composition (north) ----
veg_cur_raw <- landscape_hf_summary(
  data.in = as.data.frame(
    as.matrix(d.wide$veg.current)
  ),
  landscape.lookup = veg_lookup,
  class.in  = "ID",
  class.out = "UseInAnalysis_Simplified"
)
veg_cur <- data.frame(
  veg_cur_raw / rowSums(veg_cur_raw)
) |>
  mutate(LinkID = row.names(veg_cur_raw)) |>
  left_join(kgrid, by = "LinkID")
row.names(veg_cur) <- veg_cur$LinkID

## 6.2 Soil composition (south) ----
soil_cur_raw <- landscape_hf_summary(
  data.in = as.data.frame(
    as.matrix(d.wide$soil.current)
  ),
  landscape.lookup = soil_lookup,
  class.in  = "ID",
  class.out = "UseInAnalysis_Simplified"
)
soil_cur <- data.frame(
  soil_cur_raw / rowSums(soil_cur_raw)
) |>
  mutate(LinkID = row.names(soil_cur_raw)) |>
  left_join(kgrid, by = "LinkID")
row.names(soil_cur) <- soil_cur$LinkID

## 6.3 Weights and pAspen ----
wN     <- veg_cur$wN
wS     <- veg_cur$wS
pAspen <- veg_cur$pAspen

# Provincial boundary for mapping
ab <- read_sf(paste0(
  "G:/Shared drives/ABMI Mammals/",
  "Data/Spatial/AB Provincial Boundary/",
  "lpr_000b21a_e.shp"
)) |>
  filter(PRNAME == "Alberta") |>
  st_transform(crs = 3400)

# ── 7. Predictions loop ─────────────────────────

results <- list()
n_cells <- nrow(veg_cur)

for (row in seq_len(nrow(sp_info))) {

  sp       <- sp_info$canonical[row]
  has_n    <- sp_info$has_north[row]
  has_s    <- sp_info$has_south[row]
  sp_south <- sp_info$south_name[row]

  message("Working on ", sp,
          " (N=", has_n, " S=", has_s, ")")

  # ── 7.1 Climate predictions ───────────────────

  load(paste0(
    climate_coefs_folder, sp,
    " Climate Coefficients.RData"
  ))
  # Climate pipeline saves avg_coef: a tibble
  # with columns `term` and `coef`.
  climate_coefs <- setNames(
    avg_coef$coef, avg_coef$term
  )

  use_climate <- kgrid |>
    select(all_of(names(climate_coefs))) |>
    as.matrix()
  rownames(use_climate) <- kgrid$LinkID

  # Pr(present | climate) per cell, capped at
  # 99th percentile. Climate is rarely the
  # source of extreme predictions; this cap
  # guards against numerical outliers only.
  raw_climate <- inv_logit(
    drop(use_climate %*% climate_coefs)
  )
  pred_climate <- pmin(
    raw_climate,
    quantile(raw_climate, 0.99)
  )

  # ── 7.2 North prediction ──────────────────────

  pred_north <- rep(0, n_cells)

  if (has_n) {

    sp_pa_n   <- north_pa[sp, ]
    sp_mean_n <- north_mean[sp, ]

    # beta_climate on logit scale
    beta_clim_n <- logit(sp_pa_n["Climate"])
    climate_logit_n <-
      pred_climate * beta_clim_n

    # Habitat-only coefficients (drop Climate)
    hab_names_n <- setdiff(
      names(sp_pa_n), "Climate"
    )
    hab_pa_n   <- sp_pa_n[hab_names_n]
    hab_mean_n <- sp_mean_n[hab_names_n]

    # Veg proportions for this species' types
    use_veg <- veg_cur |>
      select(any_of(names(hab_mean_n))) |>
      as.matrix()

    # Match coefficient order to grid columns
    matched_n <- colnames(use_veg)
    logit_pa_n <- logit(
      pmax(hab_pa_n[matched_n], 1e-300)
    )

    # Column-by-column prediction to limit
    # memory use (~665k cells × ~90 types)
    for (v in seq_along(matched_n)) {
      vn <- matched_n[v]
      pa_adj <- inv_logit(
        climate_logit_n + logit_pa_n[vn]
      )
      if (hab_pa_n[vn] > 0) {
        ta_v <- hab_mean_n[vn] *
          (pa_adj / hab_pa_n[vn])
      } else {
        ta_v <- 0
      }
      pred_north <- pred_north +
        use_veg[, vn] * ta_v
    }

  }

  # ── 7.3 South prediction ──────────────────────

  pred_south <- rep(0, n_cells)

  if (has_s) {

    sp_pa_s   <- south_pa[sp_south, ]
    sp_mean_s <- south_mean[sp_south, ]
    paspen_pa  <- south_paspen_pa[sp_south]
    paspen_agp <- south_paspen_agp[sp_south]

    # beta_climate on logit scale
    beta_clim_s <- logit(sp_pa_s["Climate"])
    climate_logit_s <-
      pred_climate * beta_clim_s

    # pAspen adjustments (cell-level)
    pa_paspen_logit <- paspen_pa * pAspen
    agp_paspen_mult <- exp(paspen_agp * pAspen)

    # Habitat-only coefficients
    hab_names_s <- setdiff(
      names(sp_pa_s), "Climate"
    )
    hab_pa_s   <- sp_pa_s[hab_names_s]
    hab_mean_s <- sp_mean_s[hab_names_s]

    # Soil proportions for this species' types
    use_soil <- soil_cur |>
      select(any_of(names(hab_mean_s))) |>
      as.matrix()

    matched_s <- colnames(use_soil)
    logit_pa_s <- logit(
      pmax(hab_pa_s[matched_s], 1e-300)
    )

    for (v in seq_along(matched_s)) {
      vn <- matched_s[v]
      # Climactic pAspen adjusted soil coefficient for each cell
      pa_adj <- inv_logit(
        climate_logit_s +
          pa_paspen_logit +
          logit_pa_s[vn]
      )
      if (hab_pa_s[vn] > 0) {
        ta_v <- hab_mean_s[vn] * (pa_adj / hab_pa_s[vn]) * agp_paspen_mult
      } else {
        ta_v <- 0
      }
      pred_south <- pred_south +
        use_soil[, vn] * ta_v
    }
  }

  # ── 7.4 Weighted combination ──────────────────

  # Both regions: blend with wN/wS weights.
  # One region only: use the full regional
  # prediction; cells outside that region
  # (wN == 0 for north-only, wS == 0 for
  # south-only) are set to NA and excluded
  # from mapping and truncation.
  if (has_n && has_s) {
    pred_combined <- pred_north * wN +
      pred_south * wS
  } else if (has_n) {
    pred_combined <- pred_north
    pred_combined[wN == 0] <- NA_real_
  } else {
    pred_combined <- pred_south
    pred_combined[wS == 0] <- NA_real_
  }

  # Cap at 99.9th percentile. NA cells are
  # excluded from the quantile calculation
  # (na.rm = TRUE) and are preserved by pmin
  # (which returns NA when either argument
  # is NA, by default).
  pred_combined <- pmin(
    pred_combined,
    quantile(pred_combined, 0.999, na.rm = TRUE)
  )

  # ── 7.5 Map ──────────────────────────────────

  sp_rast <- terra::rast(
    data.frame(
      X       = veg_cur$X,
      Y       = veg_cur$Y,
      Density = pred_combined
    ),
    type = "xyz",
    crs  = "EPSG:3400"
  )

  ggplot() +
    geom_spatraster(
      data    = sp_rast,
      maxcell = n_cells
    ) +
    scale_fill_gradientn(
      name   = "Density",
      colors = rev(met.brewer(
        name = "Hiroshige", n = 100,
        type = "continuous"
      )),
      guide    = "colourbar",
      na.value = NA
    ) +
    labs(title = paste0(sp, " (Density, Current)")) +
    theme_light() +
    theme(
      axis.title.x  = element_blank(),
      axis.title.y  = element_blank(),
      axis.text.x   = element_text(size = 18),
      axis.text.y   = element_text(size = 18),
      panel.grid.major.y = element_blank(),
      legend.text   = element_text(size = 14),
      legend.title  = element_text(size = 16),
      legend.key.size = unit(1, "cm"),
      axis.line     = element_line(colour = "black"),
      panel.border  = element_rect(
        colour = "black", fill = NA, linewidth = 1
      )
    )

  ggsave(
    paste0(
      predictions_map_folder, sp,
      " Density Predictions.png"
    ),
    dpi = 500, height = 7, width = 5
  )

  # ── 7.6 Store results ─────────────────────────

  res <- list(
    "Predictions" = cbind(
      Climate  = pred_climate,
      Combined = pred_combined
    ),
    "Climate Model Coefficients" = climate_coefs,
    "Has North" = has_n,
    "Has South" = has_s
  )

  if (has_n) {
    res[["North"]][["North TA Coefficients"]] <-
      north_mean[sp, ]
    res[["North"]][["North TA SEs"]] <-
      north_mean_se[sp, ]
    res[["North"]][["North TA LCI"]] <- north_lci[sp, ]
    res[["North"]][["North TA UCI"]] <- north_uci[sp, ]
    res[["North"]][["North PA Coefficients"]] <-
      north_pa[sp, ]
    res[["North"]][["North PA SEs"]] <-
      north_pa_se[sp, ]
    res[["North"]][["North AGP Coefficients"]] <-
      north_agp[sp, ]
    res[["North"]][["North AGP SEs"]] <-
      north_agp_se[sp, ]
    res[["North"]][["North PA AUC"]] <- north_auc[, sp]
    res[["North"]][["North TA AUC"]] <- north_auc_ta[, sp]
  }

  if (has_s) {
    # pAspen PA is a logit-scale slope; pAspen AGP
    # is a log-scale slope. Both are appended as
    # "pAspen" to their respective vectors,
    # consistent with how Climate is stored in
    # these tables (also a raw-scale coefficient).
    res[["South"]][["South TA Coefficients"]] <-
      c(south_mean[sp_south, ],
        pAspen = unname(paspen_agp))
    res[["South"]][["South TA SEs"]] <-
      c(south_mean_se[sp_south, ],
        pAspen = unname(
          south_paspen_agp_se[sp_south]
        ))
    res[["South"]][["South TA LCI"]] <-
      south_lci[sp_south, ]
    res[["South"]][["South TA UCI"]] <-
      south_uci[sp_south, ]
    res[["South"]][["South PA Coefficients"]] <-
      c(south_pa[sp_south, ],
        pAspen = unname(paspen_pa))
    res[["South"]][["South PA SEs"]] <-
      c(south_pa_se[sp_south, ],
        pAspen = unname(
          south_paspen_pa_se[sp_south]
        ))
    res[["South"]][["South AGP Coefficients"]] <-
      c(south_agp[sp_south, ],
        pAspen = unname(paspen_agp))
    res[["South"]][["South AGP SEs"]] <-
      c(south_agp_se[sp_south, ],
        pAspen = unname(
          south_paspen_agp_se[sp_south]
        ))
    res[["South"]][["South PA AUC"]] <- south_auc[, sp_south]
    res[["South"]][["South TA AUC"]] <- south_auc_ta[, sp_south]
  }

  results[[sp]] <- res

} # end species loop

# ── 8. Save ─────────────────────────────────────

save(results, file = f_out_results)

str(results, max.level = 2)

# ─────────────────────────────────────────────────
