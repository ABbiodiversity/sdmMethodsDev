# ---
# title: Transcriptions of v2's Map Scripts, for the Port Check
# author: Brendan Casey; map logic by Elly Knight, Marcus Becker
#   and Brandon Allen (v2)
# created: 2026-10-27
# inputs:
#   - the prediction grid, as load_spatial_grid() reads it
#   - coefficients in each v2 script's own form, built from a
#     harness store by the v2_*_inputs() functions below
# outputs: none; returns objects in memory
# notes:
#   - Layer A of the prediction parity check
#     (docs/prediction_design.md section 4): the harness predict
#     step and these functions are given the same coefficients
#     and must agree to floating point.
#   - Written apart from harness/predict_spatial.R on purpose. Each
#     function follows its v2 script line by line: v2's renames,
#     its select-by-name of grid columns, its matrix arithmetic
#     and its caps. The class maps and pooling of the predict
#     step are not used here, so an error in them shows up as a
#     difference.
#     - Birds: 0_data/v2_scripts/birds/09.Predict.R:46-238.
#     - Mammals: 0_data/v2_scripts/mammals/
#       make-species-predictions.R:184-313, 415-647, and the
#       season averaging of north-models/03_basic-models.R:
#       1067-1100 and south-models/03_basic-models.R:883-915.
#     - Plants: 0_data/v2_scripts/plants/04c_prediction-
#       comparison.R:71-135, 213-253, 423-470.
#   - Plants: 04c reads COEFS.RData, whose vegetation names come
#     from vegetation-model-labels_2024.csv, which is not in the
#     repository. 04c selects grid columns by those names, so they
#     must be grid class names; the harness habitat terms are, and
#     04a's additions (UrbInd copied to Rural; Mine, MineV, HWater,
#     Water, Bare, SnowIce and SoilUnknown at -10000) are made
#     here as 04a makes them. TODO: confirm with plant lead.
# ---

# 1. Setup ----

## 1.1 Load packages ----
library(data.table) # reading stores (version: 1.18.0)
library(Matrix) # sparse land cover (version: 1.7.3)

# 2. v2_frames() ----

#' The Grid as v2's Scripts Hold It
#'
#' kgrid with v2's added columns, and veg.cur and soil.cur as
#' dense data frames of proportions, as 09.Predict.R:46-74 and
#' 04c:63-90 build them. The proportions themselves are the
#' grid's, which the grid QA showed equal v2's
#' landscape_hf_summary() to 1e-15.
#'
#' @param grid From load_spatial_grid().
#' @param rows Integer. The cells v2 would compute (all, or the
#'   extent when caps come from the extent).
#' @param scenario Character.
#' @return A list of `kgrid`, `veg.cur` and `soil.cur`.
#'
#' @example # Example usage of the function
#' # frames <- v2_frames(grid, seq_len(1000), "current")
v2_frames <- function(grid, rows, scenario) {
  cells <- grid$cells[rows, , drop = FALSE]
  kgrid <- data.frame(
    LinkID = cells$LinkID, Easting = cells$Easting,
    Northing = cells$Northing, NrName = cells$NrName,
    wN = cells$wN, wS = cells$wS, pAspen = cells$pAspen
  )

  for (v in c("MAT", "MWMT", "MCMT", "TD", "MAP", "MSP", "AHM",
              "SHM", "DD_0", "DD5", "DD_18", "DD18", "NFFD",
              "bFFP", "eFFP", "FFP", "PAS", "EMT", "EXT", "Eref",
              "CMD", "RH", "CMI", "DD1040", "bio9", "bio15",
              "HTV")) {
    kgrid[[v]] <- cells[[v]]
  }

  # 09.Predict.R:47-52, 04c:72-80, make-species-predictions.R:
  # 416-420
  kgrid$Intercept <- 1
  kgrid$"(Intercept)" <- 1
  kgrid$Easting2 <- kgrid$Easting^2
  kgrid$Northing2 <- kgrid$Northing^2
  kgrid$EastingNorthing <- kgrid$Easting * kgrid$Northing
  kgrid$PET <- kgrid$Eref
  kgrid$MAPPET <- kgrid$MAP * kgrid$PET
  kgrid$MAT2 <- kgrid$MAT * kgrid$MAT
  kgrid$CMDMAT <- kgrid$CMD * kgrid$MAT
  kgrid$MWMT2 <- kgrid$MWMT * kgrid$MWMT

  dense <- function(m) {
    out <- data.frame(as.matrix(m[rows, , drop = FALSE]))
    out$LinkID <- cells$LinkID
    cbind(out, kgrid[, c("wN", "wS", "pAspen", "NrName")])
  }

  list(
    kgrid = kgrid,
    veg.cur = dense(grid$landcover$north[[scenario]]),
    soil.cur = dense(grid$landcover$south[[scenario]])
  )
}

## 2.1 v2_climate_names() ----

#' Climate Terms Under the kgrid Names v2 Multiplies By
#'
#' @param coefficients Data frame of term and estimate.
#' @return A named numeric vector.
#'
#' @example # Example usage of the function
#' # v2_climate_names(set$climate)
v2_climate_names <- function(coefficients) {
  renamed <- c(
    "(Intercept)" = "Intercept", "I(Easting^2)" = "Easting2",
    "I(Northing^2)" = "Northing2",
    "Easting:Northing" = "EastingNorthing"
  )
  terms <- coefficients$term
  hit <- terms %in% names(renamed)
  terms[hit] <- renamed[terms[hit]]

  stats::setNames(coefficients$estimate, terms)
}

# 3. Birds ----

## 3.1 v2_bird_map() ----

#' 09.Predict.R for One Species and Draw
#'
#' @param climate.i Named numeric. v2's `marginal` row.
#' @param joint_n,joint_s Named numeric or NULL. The species'
#'   north and south `joint` rows (v2's standardized template,
#'   log scale), or NULL where the species is not modelled.
#' @param q Numeric. The species' PlotQuantile.
#' @param frames From v2_frames().
#' @return A data frame of Climate, Veg, Soil and Provincial.
#'
#' @example # Example usage of the function
#' # v2_bird_map(clim, jn, js, 0.995, frames)
v2_bird_map <- function(climate.i, joint_n, joint_s, q, frames) {
  kgrid <- frames$kgrid
  veg.cur <- frames$veg.cur
  soil.cur <- frames$soil.cur
  inv.link <- function(eta) {
    pmin(pmax(exp(eta), .Machine$double.eps), .Machine$double.xmax)
  }

  # WRANGLING 3-4 (09.Predict.R:76-115), for one species
  simplify <- function(joint, north) {
    if (north) {
      treedfen <- paste0("TreedFen", c("R", 1:8))
      out <- c(
        joint[!names(joint) %in% c(treedfen, "Urban", "Industrial",
                                   "MineV")],
        TreedFen = mean(joint[treedfen]),
        UrbInd = mean(joint[c("Urban", "Industrial")])
      )
    } else {
      out <- c(
        joint[!names(joint) %in% c("Urban", "Industrial", "MineV")],
        UrbInd = mean(joint[c("Urban", "Industrial")])
      )
    }
    names(out) <- gsub("GrassHerb", "Grass", names(out))
    out
  }

  mod.i <- if (!is.null(joint_n) && !is.null(joint_s)) {
    "both"
  } else if (!is.null(joint_n)) {
    "north"
  } else {
    "south"
  }

  # MAKE PREDICTIONS 5 (09.Predict.R:146-157)
  use.climate <- as.matrix(kgrid[, names(climate.i)])
  raw.climate <- matrix(inv.link(drop(use.climate %*% climate.i)),
                        ncol = 1)
  q99 <- quantile(raw.climate, 0.99)
  pred.climate <- ifelse(raw.climate > q99, q99, raw.climate)

  if (mod.i %in% c("both", "north")) {
    vegclim.i <- simplify(joint_n, TRUE)
    veg.i <- vegclim.i[names(vegclim.i) != "Climate"]
    use.veg <- as.matrix(veg.cur[, names(veg.i)])
    joint.climate.veg <- matrix(pred.climate * vegclim.i["Climate"],
                                ncol = ncol(use.veg),
                                nrow = nrow(use.veg))
    veg.coef <- t(t(joint.climate.veg) + veg.i)
    veg.cur$Veg <- rowSums(use.veg * inv.link(veg.coef))

    if (mod.i == "north") {
      soil.cur$Soil <- 0
    }
  }

  if (mod.i %in% c("both", "south")) {
    soilclim.i <- simplify(joint_s, FALSE)
    soil.i <- soilclim.i[!names(soilclim.i) %in% c("Climate",
                                                    "pAspen")]
    use.soil <- as.matrix(soil.cur[, names(soil.i)])
    paspen.pred <- kgrid$pAspen
    joint.climate.soil <- matrix(pred.climate * soilclim.i["Climate"],
                                 ncol = ncol(use.soil),
                                 nrow = nrow(use.soil))
    joint.paspen.soil <- matrix(paspen.pred * soilclim.i["pAspen"],
                                ncol = ncol(use.soil),
                                nrow = nrow(use.soil))
    joint.soil <- joint.climate.soil + joint.paspen.soil
    soil.coef <- t(t(joint.soil) + soil.i)
    soil.cur$Soil <- rowSums(use.soil * inv.link(soil.coef))

    if (mod.i == "south") {
      veg.cur$Veg <- 0
    }
  }

  # 6. Combine (09.Predict.R:223-238)
  out <- data.frame(
    Climate = pred.climate[, 1], Veg = veg.cur$Veg,
    Soil = soil.cur$Soil, wN = veg.cur$wN, wS = veg.cur$wS
  )
  out$Veg <- ifelse(is.infinite(out$Veg), median(out$Veg), out$Veg)
  out$Soil <- ifelse(is.infinite(out$Soil), median(out$Soil),
                     out$Soil)
  out$Provincial <- out$Veg * out$wN + out$Soil * out$wS
  out$Provincial <- ifelse(
    out$Provincial > quantile(out$Provincial, q),
    quantile(out$Provincial, q), out$Provincial
  )

  out
}

## 3.2 v2_bird_inputs() ----

#' One Bird Draw in 09.Predict.R's Form, from Harness Stores
#'
#' @param pipeline_dir Character. The experiment's stores.
#' @param data_dir Character. The test dataset.
#' @param species Character.
#' @param boot Integer.
#' @return A list of climate.i, joint_n and joint_s.
#'
#' @example # Example usage of the function
#' # v2_bird_inputs(pipeline_dir, data_dir, "AMRO", 46)
v2_bird_inputs <- function(pipeline_dir, data_dir, species, boot) {
  out <- list(climate.i = NULL, joint_n = NULL, joint_s = NULL)

  for (region in c("north", "south")) {
    rows <- as.data.frame(fread(file.path(
      pipeline_dir, "bird", region, "coefficients.csv"
    )))
    rows <- rows[rows$species == species & rows$boot == boot, ]

    if (nrow(rows) == 0) {
      next
    }

    # v2's marginal: the north one where there is one
    if (is.null(out$climate.i)) {
      climate <- rows[rows$stage == "climate", ]
      out$climate.i <- v2_climate_names(climate)
    }

    # v2's joint: the standardized template (08.PackageCoefficients)
    joint <- standardize_bird_coefficients(
      rows[rows$stage == "landcover", ], data_dir, region
    )
    out[[paste0("joint_", substr(region, 1, 1))]] <-
      stats::setNames(joint$estimate, joint$term)
  }

  out
}

# 4. Mammals ----

## 4.1 v2_mammal_map() ----

#' make-species-predictions.R for One Species
#'
#' @param climate_coefs Named numeric. avg_coef as a vector.
#' @param north,south Lists of `pa` and `mean` (v2's Coef.pa.all
#'   and Coef.mean.all rows, v2's column names) or NULL; south
#'   also `paspen_pa` and `paspen_agp`.
#' @param frames From v2_frames().
#' @return A data frame of Climate and Combined.
#'
#' @example # Example usage of the function
#' # v2_mammal_map(clim, north, south, frames)
v2_mammal_map <- function(climate_coefs, north, south, frames) {
  logit <- binomial()$linkfun
  inv_logit <- binomial()$linkinv
  kgrid <- frames$kgrid
  veg_cur <- frames$veg.cur
  soil_cur <- frames$soil.cur

  # 3.3 Rename columns to match kgrid (184-236)
  rename_north_cols <- function(m) {
    names(m) <- gsub("Decid", "Deciduous", names(m))
    names(m) <- gsub("Spruce", "WhiteSpruce", names(m))
    names(m) <- gsub("TreedBog", "BlackSpruce", names(m))
    names(m) <- gsub("GrassHerb", "Grass", names(m))
    names(m) <- gsub("^Well$", "Wellsites", names(m))
    m <- m[names(m) != "Urban"]
    names(m) <- gsub("^Industrial$", "UrbInd", names(m))
    m
  }
  rename_south_cols <- function(m) {
    names(m) <- gsub("^Well$", "Wellsites", names(m))
    m <- m[names(m) != "Urban"]
    names(m) <- gsub("^Industrial$", "UrbInd", names(m))
    m
  }

  # 3.5 Unmodelled cover types at zero (272-313)
  if (!is.null(north)) {
    north$pa <- c(rename_north_cols(north$pa), Mine = 0, SnowIce = 0,
                  HWater = 0)
    north$mean <- c(rename_north_cols(north$mean), Mine = 0,
                    SnowIce = 0, HWater = 0)
  }

  if (!is.null(south)) {
    south$pa <- c(rename_south_cols(south$pa), SoilUnknown = 0,
                  HWater = 0, HFor = 0)
    south$mean <- c(rename_south_cols(south$mean), SoilUnknown = 0,
                    HWater = 0, HFor = 0)
  }

  wN <- veg_cur$wN
  wS <- veg_cur$wS
  pAspen <- veg_cur$pAspen
  n_cells <- nrow(veg_cur)

  # 7.1 Climate (497-512)
  use_climate <- as.matrix(kgrid[, names(climate_coefs)])
  raw_climate <- inv_logit(drop(use_climate %*% climate_coefs))
  pred_climate <- pmin(raw_climate, quantile(raw_climate, 0.99))

  # 7.2 North (516-563)
  pred_north <- rep(0, n_cells)

  if (!is.null(north)) {
    sp_pa_n <- north$pa
    sp_mean_n <- north$mean
    beta_clim_n <- logit(sp_pa_n["Climate"])
    climate_logit_n <- pred_climate * beta_clim_n
    hab_names_n <- setdiff(names(sp_pa_n), "Climate")
    hab_pa_n <- sp_pa_n[hab_names_n]
    hab_mean_n <- sp_mean_n[hab_names_n]
    # select(any_of()): the coefficients' order, grid columns only
    keep_n <- names(hab_mean_n)[names(hab_mean_n) %in%
                                  colnames(veg_cur)]
    use_veg <- as.matrix(veg_cur[, keep_n, drop = FALSE])
    matched_n <- colnames(use_veg)
    logit_pa_n <- logit(pmax(hab_pa_n[matched_n], 1e-300))

    for (v in seq_along(matched_n)) {
      vn <- matched_n[v]
      pa_adj <- inv_logit(climate_logit_n + logit_pa_n[vn])
      ta_v <- if (hab_pa_n[vn] > 0) {
        hab_mean_n[vn] * (pa_adj / hab_pa_n[vn])
      } else {
        0
      }
      pred_north <- pred_north + use_veg[, vn] * ta_v
    }
  }

  # 7.3 South (567-618)
  pred_south <- rep(0, n_cells)

  if (!is.null(south)) {
    sp_pa_s <- south$pa
    sp_mean_s <- south$mean
    beta_clim_s <- logit(sp_pa_s["Climate"])
    climate_logit_s <- pred_climate * beta_clim_s
    pa_paspen_logit <- south$paspen_pa * pAspen
    agp_paspen_mult <- exp(south$paspen_agp * pAspen)
    hab_names_s <- setdiff(names(sp_pa_s), "Climate")
    hab_pa_s <- sp_pa_s[hab_names_s]
    hab_mean_s <- sp_mean_s[hab_names_s]
    keep_s <- names(hab_mean_s)[names(hab_mean_s) %in%
                                  colnames(soil_cur)]
    use_soil <- as.matrix(soil_cur[, keep_s, drop = FALSE])
    matched_s <- colnames(use_soil)
    logit_pa_s <- logit(pmax(hab_pa_s[matched_s], 1e-300))

    for (v in seq_along(matched_s)) {
      vn <- matched_s[v]
      pa_adj <- inv_logit(climate_logit_s + pa_paspen_logit +
                            logit_pa_s[vn])
      ta_v <- if (hab_pa_s[vn] > 0) {
        hab_mean_s[vn] * (pa_adj / hab_pa_s[vn]) * agp_paspen_mult
      } else {
        0
      }
      pred_south <- pred_south + use_soil[, vn] * ta_v
    }
  }

  # 7.4 Combination and cap (628-647)
  if (!is.null(north) && !is.null(south)) {
    pred_combined <- pred_north * wN + pred_south * wS
  } else if (!is.null(north)) {
    pred_combined <- pred_north
    pred_combined[wN == 0] <- NA_real_
  } else {
    pred_combined <- pred_south
    pred_combined[wS == 0] <- NA_real_
  }

  pred_combined <- pmin(
    pred_combined, quantile(pred_combined, 0.999, na.rm = TRUE)
  )

  data.frame(Climate = pred_climate, Combined = pred_combined)
}

## 4.2 v2_mammal_inputs() ----

#' One Mammal Draw in v2's Form, Seasons Averaged as v2 Does
#'
#' Coef.pa.all and Coef.mean.all are the season mean of each
#' column; the pAspen slopes are the season mean of the raw
#' slopes (south-models/03_basic-models.R:883-915). The climate
#' model is v2's single model; the harness fits it in each season
#' run, the same model at draw 1, so the seasons are averaged.
#'
#' @param pipeline_dir Character.
#' @param species Character. Without the season, e.g. "Moose".
#' @param boot Integer.
#' @return A list of climate_coefs, north and south.
#'
#' @example # Example usage of the function
#' # v2_mammal_inputs(pipeline_dir, "Moose", 1)
v2_mammal_inputs <- function(pipeline_dir, species, boot) {
  seasons <- list()

  for (season in c("Summer", "Winter")) {
    run <- paste0("mammal_", tolower(season))
    sp <- paste0(species, "_", season)
    one <- list()

    for (region in c("north", "south")) {
      path <- file.path(pipeline_dir, run, region, "coefficients.csv")

      if (!file.exists(path)) {
        next
      }

      rows <- as.data.frame(fread(path))
      rows <- rows[rows$species == sp & rows$boot == boot, ]

      if (nrow(rows) == 0) {
        next
      }

      vec <- function(stage) {
        r <- rows[rows$stage == stage, ]
        stats::setNames(r$estimate, r$term)
      }

      one$climate <- vec("climate")
      table <- list(pa = vec("habitat_presence"),
                    mean = vec("habitat_total"))

      if (region == "south") {
        table$paspen_pa <- stats::qlogis(table$pa[["pAspen"]])
        table$paspen_agp <- log(vec("habitat_abundance")[["pAspen"]])
        table$pa <- table$pa[names(table$pa) != "pAspen"]
      }

      one[[region]] <- table
    }

    if (length(one) > 0) {
      seasons[[season]] <- one
    }
  }

  average <- function(values) {
    keys <- unique(unlist(lapply(values, names)))
    vapply(keys, function(k) {
      mean(vapply(values, function(v) {
        if (k %in% names(v)) v[[k]] else NA_real_
      }, numeric(1)))
    }, numeric(1))
  }

  climate_coefs <- average(lapply(seasons, `[[`, "climate"))
  names(climate_coefs)[names(climate_coefs) == "Intercept"] <-
    "(Intercept)"

  region_of <- function(region) {
    tables <- Filter(Negate(is.null), lapply(seasons, `[[`, region))

    if (length(tables) == 0) {
      return(NULL)
    }

    out <- list(
      pa = average(lapply(tables, `[[`, "pa")),
      mean = average(lapply(tables, `[[`, "mean"))
    )

    if (region == "south") {
      out$paspen_pa <- mean(vapply(tables, `[[`, numeric(1),
                                   "paspen_pa"))
      out$paspen_agp <- mean(vapply(tables, `[[`, numeric(1),
                                    "paspen_agp"))
    }

    out
  }

  list(climate_coefs = climate_coefs, north = region_of("north"),
       south = region_of("south"))
}

# 5. Plants ----

## 5.1 v2_plant_map() ----

#' 04c for One Species: Climate, Landcover, and the Map
#'
#' @param spp.clim Named numeric. COEFS climate row.
#' @param spp.veg,spp.soil Named numeric or NULL. COEFS
#'   vegetation row (Climate first) and soil row (Climate and
#'   pAspen first).
#' @param frames From v2_frames().
#' @return A data frame of Climate and NewPred (the map).
#'
#' @example # Example usage of the function
#' # v2_plant_map(clim, veg, soil, frames)
v2_plant_map <- function(spp.clim, spp.veg, spp.soil, frames) {
  inv.link <- binomial()$linkinv
  veg.cur <- cbind(frames$veg.cur, frames$kgrid[, setdiff(
    names(frames$kgrid), names(frames$veg.cur)
  )])
  soil.cur <- cbind(frames$soil.cur, frames$kgrid[, setdiff(
    names(frames$kgrid), names(frames$soil.cur)
  )])
  veg.cur$MineV <- 0
  soil.cur$MineV <- 0

  climate_of <- function(frame) {
    climate.veg <- as.matrix(frame[, names(spp.clim)])
    climate.pred <- matrix(inv.link(drop(climate.veg %*% spp.clim)),
                           ncol = 1)
    ifelse(climate.pred >= quantile(climate.pred, 0.99),
           quantile(climate.pred, 0.99), climate.pred)
  }

  # 3.0 Vegetation (04c:104-135)
  veg.pred <- NULL
  climate.pred.og <- climate_of(veg.cur)

  if (!is.null(spp.veg)) {
    veg <- as.matrix(veg.cur[, names(spp.veg)[-1]])
    climate.pred <- climate.pred.og * spp.veg["Climate"]
    climate.matrix <- matrix(climate.pred, nrow = nrow(veg),
                             ncol = ncol(veg))
    veg.coef <- spp.veg[colnames(veg)]
    veg.coef <- t(t(climate.matrix) + veg.coef)
    veg.pred <- rowSums(veg * inv.link(veg.coef))
  }

  # 4.0 Soil (04c:222-253)
  soil.pred <- NULL

  if (!is.null(spp.soil)) {
    soil <- as.matrix(soil.cur[, names(spp.soil)[-c(1, 2)]])
    climate.pred <- (climate.pred.og * spp.soil["Climate"]) +
      (soil.cur$pAspen * spp.soil["pAspen"])
    climate.matrix <- matrix(climate.pred, nrow = nrow(soil),
                             ncol = ncol(soil))
    soil.coef <- spp.soil[colnames(soil)]
    soil.coef <- t(t(climate.matrix) + soil.coef)
    soil.pred <- rowSums(soil * inv.link(soil.coef))
  }

  # 5.2 Landcover map (04c:425-470)
  cap <- function(x) {
    ifelse(x >= quantile(x, 0.99), quantile(x, 0.99), x)
  }
  nr <- frames$kgrid$NrName

  NewPred <- if (!is.null(veg.pred) && !is.null(soil.pred)) {
    cap(veg.pred * frames$kgrid$wN + soil.pred * frames$kgrid$wS)
  } else if (!is.null(veg.pred)) {
    out <- cap(veg.pred)
    out[nr == "Grassland"] <- NA
    out
  } else {
    out <- cap(soil.pred)
    out[!(nr %in% c("Grassland", "Parkland"))] <- NA
    out
  }

  data.frame(Climate = climate.pred.og[, 1], NewPred = NewPred)
}

## 5.2 v2_plant_inputs() ----

#' One Plant Draw in COEFS Form, from a Harness Store
#'
#' The habitat terms less the intercept and the unaged stand
#' types (published by age class only), with 04a's additions:
#' UrbInd copied to Rural, and the unmodelled classes at -10000
#' (04a:96-101, 113-115, 158-165).
#'
#' @param pipeline_dir Character.
#' @param run Character. The plant run, e.g. "vascular_plant".
#' @param species Character.
#' @param boot Integer.
#' @return A list of spp.clim, spp.veg and spp.soil.
#'
#' @example # Example usage of the function
#' # v2_plant_inputs(pipeline_dir, "vascular_plant",
#' #                 "Galium.boreale", 1)
v2_plant_inputs <- function(pipeline_dir, run, species, boot) {
  out <- list(spp.clim = NULL, spp.veg = NULL, spp.soil = NULL)
  stand <- c("WhiteSpruce", "Pine", "Deciduous", "Mixedwood",
             "BlackSpruce")

  for (region in c("north", "south")) {
    rows <- as.data.frame(fread(file.path(
      pipeline_dir, run, region, "coefficients.csv"
    )))
    rows <- rows[rows$species == species & rows$boot == boot, ]

    if (nrow(rows) == 0) {
      next
    }

    if (is.null(out$spp.clim)) {
      climate <- rows[rows$stage == "climate", ]
      out$spp.clim <- v2_climate_names(climate)
    }

    h <- rows[rows$stage == "habitat", ]
    h <- stats::setNames(h$estimate, h$term)
    cover <- h[!names(h) %in% c("Intercept", "Climate", "Protocol",
                                "paspen", stand)]
    cover <- cover[is.finite(cover)]
    cover[["Rural"]] <- cover[["UrbInd"]]

    if (region == "north") {
      fixed <- c("MineV", "Mine", "HWater", "Water", "Bare",
                 "SnowIce")
      cover[fixed] <- -10000
      out$spp.veg <- c(Climate = h[["Climate"]], cover)
    } else {
      fixed <- c("Mine", "MineV", "Water", "HWater", "SoilUnknown")
      cover[fixed] <- -10000
      out$spp.soil <- c(
        Climate = h[["Climate"]],
        pAspen = if ("paspen" %in% names(h)) h[["paspen"]] else 0,
        cover
      )
    }
  }

  out
}

# End of script ----
