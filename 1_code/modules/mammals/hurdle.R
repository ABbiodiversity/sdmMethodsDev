# ---
# title: The v2 Mammal Hurdle Tables
# author: Brendan Casey; model logic by Marcus Becker and David J.
#   Huggard (v2)
# created: 2026-09-29
# inputs:
#   in the test dataset's lookup/ (see data_source.R):
#     - mammal_climate_predictions.csv
#     - species_queue.csv (each species' v2 name)
# outputs: none; returns objects in memory
# notes:
#   - Ports how v2 turns the two hurdle GLMs into its published
#     tables: 03_basic-models.R after the fits, north sections
#     6.3-6.6 and 6.11, south 6.3-6.6. The hurdle itself is fitted
#     by methods/selection/hurdle.R.
#   - mammal_v2_habitat_tables() is a post_process step, removed
#     by replace_stage_method(); it stops if a half is not a GLM.
#   - Effects are reported on v2's full habitat set, not the
#     winning model's categories: each category is spread over
#     the fine types the prediction matrix assigns to it.
#   - Three outputs, one per v2 table: presence (Coef.pa, a
#     probability), abundance (Coef.agp, on the response scale)
#     and total (Coef.mean). Seasons are averaged later, by the
#     comparison, as v2 averages them into its `.all` tables.
#   - Cutblock convergence is applied per season. It is linear,
#     so converging each season and then averaging equals v2's
#     averaging and then converging.
#   - v2 quirks reproduced: the one-hot predictions are read at
#     seas_days = 100 and Climate = 0 whatever the candidate;
#     the abundance candidates are unweighted; the Mule Deer
#     adjustment to old pine (and, in winter, deciduous) stands.
# ---

# 1. Setup ----

## 1.1 Load packages ----
# mgcv for the age splines and MuMIn for AICc, both loaded
# lazily so a run without mammals does not need them.

# 2. Precomputed climate ----

## 2.1 mammal_precomputed_climate() ----

#' Attach v2's Precomputed Climate Prediction to a Mammal Frame
#'
#' As v2: drops deployments without a prediction, then recomputes
#' the response, since lure correction and scaling depend on the
#' rows kept.
#'
#' @param frame A one-species frame from model_frame().
#' @param species Character. The harness species name, e.g.
#'   "BlackBear_Summer".
#' @param data_dir Character.
#' @param spec The mammal spec.
#' @return The frame, with `Climate` and without rows lacking it.
#'
#' @example # Example usage of the function
#' # frame <- mammal_precomputed_climate(frame, sp, data_dir, spec)
mammal_precomputed_climate <- function(frame, species, data_dir,
                                       spec) {
  # The climate file names species as v2 did, without the season
  v2_name <- sub(
    "(Summer|Winter)$", "",
    species_source_name(data_dir, "mammal", species)
  )

  # Read whole once per session; every species reads a column
  climate <- cached_read(
    file.path(data_dir, "lookup", "mammal_climate_predictions.csv"),
    function(p) as.data.frame(data.table::fread(p))
  )

  if (!v2_name %in% names(climate)) {
    stop("No precomputed climate for mammal `", v2_name, "`.",
         call. = FALSE)
  }

  frame$Climate <- climate[[v2_name]][
    match(frame$survey_unit_id, climate$survey_unit_id)
  ]
  frame <- frame[!is.na(frame$Climate) & !is.na(frame$response_raw), ]

  frame$response <- apply_response_transform(
    frame$response_raw, spec$response_transform, frame
  )

  frame
}

# 3. Helpers ----

## 3.1 mammal_aicc() ----

#' AICc as v2 Computes It
#'
#' @param model A fitted glm or gam, or a try-error.
#' @return A number; Inf for a failed fit.
#'
#' @example # Example usage of the function
#' # mammal_aicc(fit)
mammal_aicc <- function(model) {
  if (is.null(model) || inherits(model, "try-error")) {
    return(Inf)
  }

  value <- tryCatch(MuMIn::AICc(model), error = function(e) Inf)
  if (is.finite(value)) value else Inf
}

## 3.2 mammal_lure_ratio() ----

#' v2's Lure Effect: Lured Mean over Unlured Mean on the Grid
#'
#' @param values Numeric vector.
#' @param lured Character vector, "Yes" or "No".
#' @param location Character vector.
#' @return A number, NA when either group is absent, as in v2.
#'
#' @example # Example usage of the function
#' # mammal_lure_ratio(sign(count), d$lured, d$location)
mammal_lure_ratio <- function(values, lured, location) {
  grid_site <- grepl("^[[:digit:]]+", location)
  q <- tapply(values[grid_site], lured[grid_site], mean)
  unname(q["Yes"] / q["No"])
}

## 3.3 mammal_held_constants() ----

#' The Values v2 Holds Fixed for Its One-Hot Predictions
#'
#' @param has_aspen Logical. Whether the region fits pAspen (the
#'   south).
#' @return A named list.
#'
#' @example # Example usage of the function
#' # mammal_held_constants(TRUE)
mammal_held_constants <- function(has_aspen) {
  constants <- list(seas_days = 100, Climate = 0)
  if (has_aspen) constants$pAspen <- 0
  constants
}

# 4. The v2 tables ----

## 4.1 mammal_v2_habitat_tables() ----

#' Turn the Fitted Hurdle into v2's Three Habitat Tables
#'
#' Replaces the `hurdle` rule's outputs with v2's presence,
#' abundance and total tables.
#'
#' @param selected The `hurdle` rule's selection result.
#' @param data The stage's data: `response` is the lure-scaled
#'   presence, `response_raw` the count, `weight` the season
#'   weight, and `lured`, `location`, `seas_days`, `Climate`, the
#'   habitat columns and, in the north, the aged stand-cover
#'   columns.
#' @param grid The prediction matrix, with v2's rows dropped.
#' @param species Character. The harness species name.
#' @return The selection result, with `coefficients` the presence
#'   table and `outputs` v2's three tables.
#'
#' @example # Example usage of the function
#' # selected <- mammal_v2_habitat_tables(selected, d, pm,
#' #                                      "MuleDeer_Summer")
mammal_v2_habitat_tables <- function(selected, data, grid,
                                     species = NA_character_) {
  if (!requireNamespace("MuMIn", quietly = TRUE) ||
        !requireNamespace("mgcv", quietly = TRUE)) {
    stop("The mammal v2 tables need MuMIn and mgcv.", call. = FALSE)
  }

  pa <- selected$parts$presence$fit$fit
  agp <- selected$parts$abundance$fit$fit

  # Needs GLM coefficients; other engines should not reach here
  if (!inherits(pa, "glm") || !inherits(agp, "glm")) {
    stop(
      "The mammal v2 tables read GLM fits, but this hurdle was ",
      "fitted with another engine. Replace the stage's method ",
      "with replace_stage_method(), which removes this step.",
      call. = FALSE
    )
  }

  if (is.null(grid)) {
    stop("The mammal v2 tables need the prediction matrix.",
         call. = FALSE)
  }

  # The north carries the aged stand-cover columns; the south,
  # which has no stand ages, does not
  ages <- "SpruceR" %in% names(data)
  has_aspen <- "pAspen" %in% names(data)
  count <- data$response_raw
  lure_pa <- mammal_lure_ratio(sign(count), data$lured, data$location)
  lure_agp <- mammal_lure_ratio(
    count[count > 0], data$lured[count > 0], data$location[count > 0]
  )

  # Step 1: Presence effects, one category at a time (6.3)
  presence <- mammal_presence_effects(
    pa, data, selected$reference_category, lure_pa, has_aspen
  )

  # Site-level logits: the age splines' offset
  data$p <- stats::predict(pa, newdata = data)

  # Step 2: Abundance effects on the prediction matrix (6.4)
  abundance <- mammal_abundance_effects(agp, grid, has_aspen)

  # Step 3: Stand-age splines, north only (6.5)
  aged <- if (ages) {
    mammal_age_splines(data, presence$coef, presence$terms)
  } else {
    list(p_age = list(), p_age_se = list())
  }

  # Step 4: Spread each category over its fine types (6.5)
  spread <- mammal_spread(
    presence, abundance$coef, aged, grid, ages
  )

  # Step 5: v2's Mule Deer adjustment
  spread$mean <- mammal_mule_deer(spread$mean, species)

  # Step 6: Calibrate total abundance to the observed mean (6.6)
  spread$mean <- spread$mean * mammal_total_calibration(
    pa, agp, data, presence$at_constants, lure_pa, lure_agp,
    has_aspen
  )

  # Step 7: Cutblock convergence, north only (6.11)
  if (ages) {
    spread$mean <- mammal_cutblock_convergence(spread$mean)
  }

  # v2 adds Bare and Water at zero to every table (7.1)
  coef_agp <- abundance$coef
  coef_agp_se <- abundance$se
  spread$pa[c("Bare", "Water")] <- 0
  spread$pa_se[c("Bare", "Water")] <- 0
  spread$mean[c("Bare", "Water")] <- 0
  coef_agp[c("Bare", "Water")] <- 0
  coef_agp_se[c("Bare", "Water")] <- 0

  table_of <- function(values, se = NA_real_) {
    data.frame(
      term = names(values), estimate = unname(values),
      se = if (length(se) == length(values)) unname(se) else NA_real_,
      stringsAsFactors = FALSE
    )
  }

  presence_table <- table_of(spread$pa, spread$pa_se)

  selected$coefficients <- presence_table
  selected$outputs <- list(
    presence = presence_table,
    abundance = table_of(coef_agp, coef_agp_se),
    total = table_of(spread$mean)
  )

  selected
}

## 4.2 mammal_presence_effects() ----

#' Presence per Habitat Category, Calibrated (v2 6.3)
#'
#' Every one-hot row is read at seas_days = 100, Climate = 0 and
#' pAspen = 0, including the rows for those terms themselves, as
#' v2's duplicated data-frame columns make it. The level is then
#' shifted on the logit scale so mean fitted presence matches mean
#' observed; Climate is a slope and keeps its own coefficient.
#'
#' @param pa The presence GLM.
#' @param data The stage's data.
#' @param reference Character. The category the winning presence
#'   candidate leaves out.
#' @param lure_pa Numeric. The presence lure ratio.
#' @param has_aspen Logical.
#' @return A list of `coef` and `se` (named by term), `terms`, and
#'   `at_constants` (the data at v2's held values).
#'
#' @example # Example usage of the function
#' # mammal_presence_effects(pa, d, "Shrub", 1.4, FALSE)
mammal_presence_effects <- function(pa, data, reference, lure_pa,
                                    has_aspen) {
  count <- data$response_raw
  terms_pa <- c(attr(pa$terms, "term.labels"), reference)
  constants <- mammal_held_constants(has_aspen)
  held <- names(constants)

  pa_link <- vapply(terms_pa, function(term) {
    onehot <- stats::setNames(
      as.list(as.numeric(terms_pa == term)), terms_pa
    )
    onehot[held] <- constants[held]
    predicted <- stats::predict(
      pa, newdata = as.data.frame(onehot), se.fit = TRUE
    )
    c(fit = unname(predicted$fit), se = unname(predicted$se.fit))
  }, c(fit = 0, se = 0))

  coef_pa <- stats::plogis(pa_link["fit", ])
  coef_pa_se <- pa_link["se", ]
  names(coef_pa) <- names(coef_pa_se) <- terms_pa

  coef_pa[["Climate"]] <- stats::plogis(stats::coef(pa)[["Climate"]])
  climate_se <- coef_pa_se[["Climate"]]

  # Calibrate the level: mean fitted presence to mean observed
  at_constants <- data
  at_constants$seas_days <- 100
  if (has_aspen) at_constants$pAspen <- 0

  p_obs <- sign(count) / ifelse(data$lured == "Yes", lure_pa, 1)
  p_obs <- p_obs / max(p_obs)
  adj <- stats::qlogis(mean(p_obs)) -
    stats::qlogis(mean(stats::plogis(
      stats::predict(pa, newdata = at_constants)
    )))

  climate_pa <- coef_pa[["Climate"]]
  coef_pa <- stats::plogis(stats::qlogis(coef_pa) + adj)
  coef_pa[["Climate"]] <- climate_pa
  coef_pa_se[["Climate"]] <- climate_se

  list(
    coef = coef_pa, se = coef_pa_se, terms = terms_pa,
    at_constants = at_constants
  )
}

## 4.3 mammal_abundance_effects() ----

#' Abundance Given Presence on the Prediction Matrix (v2 6.4)
#'
#' @param agp The abundance GLM.
#' @param grid The prediction matrix.
#' @param has_aspen Logical.
#' @return A list of `coef` and `se`, on the response scale, with
#'   Climate first at 1 (no effect on abundance).
#'
#' @example # Example usage of the function
#' # mammal_abundance_effects(agp, pm, FALSE)
mammal_abundance_effects <- function(agp, grid, has_aspen) {
  constants <- mammal_held_constants(has_aspen)
  newdata <- grid
  for (one in names(constants)) newdata[[one]] <- constants[[one]]

  agp_pred <- stats::predict(agp, newdata = newdata, se.fit = TRUE)
  t_mean_agp <- stats::setNames(
    as.numeric(agp_pred$fit), rownames(grid)
  )
  t_se_agp <- stats::setNames(
    as.numeric(agp_pred$se.fit), rownames(grid)
  )

  list(
    coef = c(Climate = 1, exp(t_mean_agp)),
    se = c(Climate = 0, t_se_agp)
  )
}

## 4.4 mammal_age_splines() ----

#' Presence by Stand Age, from v2's Splines (v2 6.5)
#'
#' One frame per stand type from units where an age class covers
#' more than 10%, a binomial GAM on sqrt(age) with the site-level
#' presence logit as offset, used where it beats the
#' intercept-only model by AICc weight.
#'
#' @param data The stage's data, with `p`, the site-level logits.
#' @param coef_pa Named numeric. Calibrated presence per term.
#' @param terms_pa Character. The presence terms.
#' @return A list of `p_age` and `p_age_se`, per term that took a
#'   spline: nine values, R and 1 to 8.
#'
#' @example # Example usage of the function
#' # mammal_age_splines(d, coef_pa, names(coef_pa))
mammal_age_splines <- function(data, coef_pa, terms_pa) {
  stand_types <- c("Spruce", "Pine", "Decid", "Mixedwood", "TreedBog")
  seas_wt <- data$weight
  p_age <- p_age_se <- list()
  stand <- stats::setNames(vector("list", 5), stand_types)

  for (i in 0:8) {
    label <- if (i == 0) "R" else i
    age <- if (i == 0) 0.5 else i

    for (type in stand_types) {
      column <- paste0(type, label)
      if (!column %in% names(data)) next
      rows <- which(data[[column]] > 0.1)
      if (length(rows) == 0) next

      stand[[type]] <- rbind(stand[[type]], data.frame(
        p_count = data$response[rows], age = age,
        wt1 = data[[column]][rows] * seas_wt[rows],
        p = data$p[rows]
      ))
    }
  }

  frames <- c(stand, list(
    UpCon = rbind(stand$Spruce, stand$Pine),
    DecidMixed = rbind(stand$Decid, stand$Mixedwood),
    TreedAll = do.call(rbind, stand)
  ))

  fit_gam <- function(df, spline) {
    f <- if (spline) {
      p_count ~ s(sqrt(age), k = 4, m = 2) + offset(p)
    } else {
      p_count ~ 1 + offset(p)
    }
    suppressWarnings(mgcv::gam(
      f, data = df, family = "binomial", weights = df$wt1
    ))
  }

  null_age <- lapply(frames, fit_gam, spline = FALSE)
  spline_age <- lapply(seq_along(frames), function(i) {
    if (sum(sign(frames[[i]]$p_count)) > 4) {
      fit_gam(frames[[i]], TRUE)
    } else {
      null_age[[i]]
    }
  })
  names(spline_age) <- names(frames)

  # The spline is used where it beats the null by AICc weight
  spline_weight <- vapply(names(frames), function(nm) {
    q <- c(mammal_aicc(spline_age[[nm]]), mammal_aicc(null_age[[nm]]))
    q <- q - min(q)
    exp(-0.5 * q[1]) / sum(exp(-0.5 * q))
  }, numeric(1))

  age_map <- list(
    Spruce = "Spruce", Pine = "Pine", Decid = "Decid",
    Mixedwood = "Mixedwood", TreedBog = "TreedBog",
    TreedWet = "TreedBog", UpCon = "UpCon",
    DecidMixed = "DecidMixed", UplandForest = "TreedAll",
    TreedAll = "TreedAll"
  )

  smooth <- function(y) {
    c(mean(y[1:2]), y[2:4], mean(y[4:6]), mean(y[5:7]),
      mean(y[6:8]), mean(y[7:9]), mean(y[8:9]))
  }

  for (term in names(age_map)) {
    model_key <- age_map[[term]]
    if (!term %in% terms_pa) next
    if (spline_weight[[model_key]] <= 0.5) next

    predicted <- stats::predict(
      spline_age[[model_key]],
      newdata = data.frame(
        age = c(0.5, 1:8), p = stats::qlogis(coef_pa[[term]])
      ),
      se.fit = TRUE
    )
    p_age[[term]] <- smooth(stats::plogis(as.numeric(predicted$fit)))
    p_age_se[[term]] <- smooth(as.numeric(predicted$se.fit))
  }

  list(p_age = p_age, p_age_se = p_age_se)
}

## 4.5 mammal_spread() ----

#' Spread Each Category over Its Fine Types (v2 6.5)
#'
#' @param presence A mammal_presence_effects() result.
#' @param coef_agp Named numeric. Abundance per fine type.
#' @param aged A mammal_age_splines() result.
#' @param grid The prediction matrix.
#' @param ages Logical. Whether the region has stand ages.
#' @return A list of `pa`, `pa_se` and `mean` (presence times
#'   abundance), each named by fine type.
#'
#' @example # Example usage of the function
#' # mammal_spread(presence, coef_agp, aged, pm, TRUE)
mammal_spread <- function(presence, coef_agp, aged, grid, ages) {
  stand_types <- c("Spruce", "Pine", "Decid", "Mixedwood", "TreedBog")
  coef_pa <- presence$coef
  coef_pa_se <- presence$se
  out_pa <- out_pa_se <- out_mean <- numeric(0)
  terms_pa1 <- setdiff(presence$terms, c("seas_days", "pAspen"))

  put <- function(names_in, pa_values, pa_se, agp_value) {
    out_pa[names_in] <<- pa_values
    out_pa_se[names_in] <<- pa_se
    out_mean[names_in] <<- pa_values * agp_value
  }

  for (term in terms_pa1) {
    if (term == "Climate") {
      put("Climate", coef_pa[["Climate"]], coef_pa_se[["Climate"]], 1)
      next
    }

    if (!term %in% names(grid)) next
    fine_types <- rownames(grid)[grid[[term]] == 1]

    for (fine in fine_types) {
      agp_value <- if (fine %in% names(coef_agp)) {
        coef_agp[[fine]]
      } else {
        0
      }

      if (ages && fine %in% stand_types) {
        age_names <- paste0(fine, c("R", 1:8))

        if (!is.null(aged$p_age[[term]])) {
          put(age_names, aged$p_age[[term]], aged$p_age_se[[term]],
              agp_value)
        } else {
          put(age_names, rep(coef_pa[[term]], 9),
              rep(coef_pa_se[[term]], 9), agp_value)
        }
      } else {
        put(fine, coef_pa[[term]], coef_pa_se[[term]], agp_value)
      }
    }
  }

  list(pa = out_pa, pa_se = out_pa_se, mean = out_mean)
}

## 4.6 mammal_mule_deer() ----

#' v2's Mule Deer Adjustment to Old Stands
#'
#' Old pine, and in winter old deciduous, stands are pulled
#' toward the 100-119 class.
#'
#' @param out_mean Named numeric. Total abundance per fine type.
#' @param species Character. The harness species name.
#' @return `out_mean`, adjusted for Mule Deer and unchanged
#'   otherwise.
#'
#' @example # Example usage of the function
#' # mammal_mule_deer(out_mean, "MuleDeer_Winter")
mammal_mule_deer <- function(out_mean, species) {
  base_species <- sub("_(Summer|Winter)$", "", species)

  if (!identical(base_species, "MuleDeer")) {
    return(out_mean)
  }

  types <- c("Pine", if (grepl("_Winter$", species)) "Decid")

  for (type in types) {
    old <- paste0(type, c("7", "8"))
    ref <- paste0(type, "6")
    if (all(c(old, ref) %in% names(out_mean))) {
      out_mean[old] <- (out_mean[old] + out_mean[[ref]]) / 2
    }
  }

  out_mean
}

## 4.7 mammal_total_calibration() ----

#' The Factor That Calibrates Total Abundance (v2 6.6)
#'
#' Mean observed lure-corrected count over mean predicted
#' presence times abundance, both at v2's held values with the
#' pAspen slopes added back.
#'
#' @param pa,agp The presence and abundance GLMs.
#' @param data The stage's data.
#' @param at_constants The data at v2's held values.
#' @param lure_pa,lure_agp Numeric. The two lure ratios.
#' @param has_aspen Logical.
#' @return A number.
#'
#' @example # Example usage of the function
#' # mammal_total_calibration(pa, agp, d, at, 1.4, 1.1, FALSE)
mammal_total_calibration <- function(pa, agp, data, at_constants,
                                     lure_pa, lure_agp, has_aspen) {
  slope <- function(model) {
    if ("pAspen" %in% names(stats::coef(model))) {
      stats::coef(model)[["pAspen"]]
    } else {
      0
    }
  }
  aspen <- if (has_aspen) data$pAspen else 0
  count <- data$response_raw

  t_p_pa <- stats::plogis(
    stats::predict(pa, newdata = at_constants) + slope(pa) * aspen
  )
  t_p_agp <- stats::predict(agp, newdata = at_constants) +
    slope(agp) * aspen
  p_obs_total <- ifelse(
    data$lured == "Yes", count / (lure_pa * lure_agp), count
  )

  mean(p_obs_total) / mean(t_p_pa * exp(t_p_agp))
}

## 4.8 mammal_cutblock_convergence() ----

#' Converge Young Cutblocks onto Natural Stands (v2 6.11)
#'
#' The same recovery weights as the plant pipeline, applied to
#' age classes 2 to 4.
#'
#' @param out_mean Named numeric. Total abundance per fine type.
#' @return `out_mean`, converged.
#'
#' @example # Example usage of the function
#' # mammal_cutblock_convergence(out_mean)
mammal_cutblock_convergence <- function(out_mean) {
  recovery <- cutblock_recovery_weights()
  convergence <- list(
    CCSpruce = list("Spruce", recovery$conifer),
    CCPine = list("Pine", recovery$conifer),
    CCMixedwood = list("Mixedwood", recovery$deciduous),
    CCDecid = list("Decid", recovery$deciduous)
  )

  for (cc in names(convergence)) {
    for (k in 1:3) {
      age <- k + 1
      w <- convergence[[cc]][[2]][k]
      cc_name <- paste0(cc, age)
      natural <- paste0(convergence[[cc]][[1]], age)

      if (all(c(cc_name, natural) %in% names(out_mean))) {
        out_mean[[cc_name]] <- out_mean[[cc_name]] * (1 - w) +
          out_mean[[natural]] * w
      }
    }
  }

  out_mean
}

# End of script ----
