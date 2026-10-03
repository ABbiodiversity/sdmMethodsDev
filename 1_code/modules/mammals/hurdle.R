# ---
# title: The v2 Mammal Hurdle Model
# author: Brendan Casey; model logic by Marcus Becker and David J.
#   Huggard (v2)
# created: 2026-09-29
# inputs:
#   in 0_data/test_dataset/lookup/:
#     - mammal_climate_predictions.csv
#     - species_queue.csv (each species' v2 name)
# outputs: none; returns objects in memory
# notes:
#   - A port of the per-species, per-season body of v2's
#     03_basic-models.R, north (sections 6.1 to 6.6 and 6.11) and
#     south (6.1 to 6.6), for one species, season and region. It
#     is registered as the habitat stage's selection rule, so the
#     harness runs it once per draw.
#   - v2 couples the two halves of the hurdle, so they are fitted
#     together here: presence (binomial, best of the candidates by
#     AICc), abundance given presence (Gamma on the log scale, over
#     the presence candidates that leave some cover unaccounted
#     for, plus an effort-only null), their product as total
#     abundance, calibrated to the observed mean, and in the north
#     stand-age splines and cutblock convergence.
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
#' v2's habitat models do not fit climate; they read a
#' per-species prediction from a separate climate pipeline, and
#' drop the deployments that have none. This does the same, then
#' recomputes the response on the remaining rows, because the lure
#' correction and scaling depend on which rows are in.
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

# 3. The hurdle model ----

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

## 3.3 select_mammal_v2_hurdle() ----

#' Fit v2's Mammal Hurdle Model for One Species and Season
#'
#' Registered as the mammal habitat stage's selection rule. See
#' the header for the steps.
#'
#' @param models List of presence candidate formulas.
#' @param base,engine,family,weights,offset,ic,control As passed
#'   to every selection rule; `weights` is the season weight.
#' @param data The draw's rows: `response_raw` is the count, and
#'   `lured`, `location`, `seas_days`, `Climate`, the habitat
#'   columns and, in the north, the aged stand-cover columns.
#' @param grid The prediction matrix, with v2's rows dropped.
#' @param intercept_cats Character vector: each candidate's
#'   reference category.
#' @param species Character. The harness species name.
#' @param stage The stage definition. Unused; the stand-age steps
#'   run where the aged cover columns are present (the north).
#' @return A selection result: `fit` is the presence model,
#'   `coefficients` the presence table, and `outputs` the
#'   presence, abundance and total tables.
#'
#' @example # Example usage of the function
#' # select_mammal_v2_hurdle(models, response ~ 1, d, engine,
#' #                         "binomial", grid = pm, ...)
select_mammal_v2_hurdle <- function(
  models, base, data, engine, family,
  weights = NULL, offset = NULL, ic = "AICc", control = list(),
  grid = NULL, intercept_cats = NULL, species = NA_character_,
  stage = list()
) {
  if (!requireNamespace("MuMIn", quietly = TRUE) ||
        !requireNamespace("mgcv", quietly = TRUE)) {
    stop("The mammal hurdle model needs MuMIn and mgcv.",
         call. = FALSE)
  }

  # The north carries the aged stand-cover columns; the south,
  # which has no stand ages, does not
  ages <- "SpruceR" %in% names(data)
  has_aspen <- "pAspen" %in% names(data)
  count <- data$response_raw
  seas_wt <- weights
  fail <- function(message) {
    stop("mammal hurdle: ", message, call. = FALSE)
  }

  # Step 1: Presence (6.1)
  lure_pa <- mammal_lure_ratio(sign(count), data$lured, data$location)
  data$p_count_pa <- sign(count) / ifelse(data$lured == "Yes", lure_pa, 1)
  data$p_count_pa <- data$p_count_pa / max(data$p_count_pa)

  formulas <- lapply(models, function(m) {
    stats::update(p_count_pa ~ 1, m)
  })

  m_pa <- lapply(formulas, function(f) {
    try(stats::glm(f, family = "binomial", data = data,
                   weights = seas_wt), silent = TRUE)
  })
  aic_pa <- vapply(m_pa, mammal_aicc, numeric(1))

  if (!any(is.finite(aic_pa))) {
    fail("every presence model failed")
  }

  best_pa <- which.min(aic_pa)
  pa <- m_pa[[best_pa]]

  # Step 2: Abundance given presence (6.2)
  d_p <- data[count > 0, , drop = FALSE]
  count_p <- count[count > 0]
  lure_agp <- mammal_lure_ratio(count_p, d_p$lured, d_p$location)
  d_p$p_count_agp <- count_p /
    ifelse(d_p$lured == "Yes", lure_agp, 1)
  d_p$p_count_agp <- pmin(
    d_p$p_count_agp, stats::quantile(d_p$p_count_agp, 0.99)
  )
  agp_start <- rep(mean(d_p$p_count_agp), nrow(d_p))

  m_agp <- list()

  for (i in seq_along(m_pa)) {
    if (inherits(m_pa[[i]], "try-error")) {
      next
    }

    terms_i <- attr(m_pa[[i]]$terms, "term.labels")
    cover <- colSums(d_p[, terms_i, drop = FALSE])
    # pAspen is not cover; v2's south leaves it out of the sum
    # (the north has none)
    cover <- cover[
      !names(cover) %in% c("Climate", "seas_days", "pAspen")
    ]

    if ((nrow(d_p) - sum(cover)) > 0) {
      f <- stats::as.formula(paste(
        "p_count_agp ~", paste(setdiff(terms_i, "Climate"),
                               collapse = " + ")
      ))
      m_agp[[length(m_agp) + 1]] <- try(stats::glm(
        f, data = d_p, family = stats::Gamma(link = "log"),
        mustart = agp_start
      ), silent = TRUE)
    }
  }

  m_agp[[length(m_agp) + 1]] <- try(stats::glm(
    p_count_agp ~ seas_days, data = d_p,
    family = stats::Gamma(link = "log"), mustart = agp_start
  ), silent = TRUE)

  aic_agp <- vapply(m_agp, mammal_aicc, numeric(1))

  if (!any(is.finite(aic_agp))) {
    fail("every abundance model failed")
  }

  agp <- m_agp[[which.min(aic_agp)]]

  # Step 3: Presence effects, one category at a time (6.3)
  terms_pa <- c(attr(pa$terms, "term.labels"),
                intercept_cats[best_pa])
  held <- c("seas_days", "Climate", if (has_aspen) "pAspen")
  constants <- list(seas_days = 100, Climate = 0)
  if (has_aspen) constants$pAspen <- 0

  # Every one-hot row is read at seas_days = 100, Climate = 0 and
  # pAspen = 0, including the rows for those terms themselves,
  # as v2's duplicated data-frame columns make it
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

  # The pAspen slope, added back in the calibration (south)
  paspen_pa <- if ("pAspen" %in% names(stats::coef(pa))) {
    stats::coef(pa)[["pAspen"]]
  } else {
    0
  }

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

  # Site-level logits: the age splines' offset
  data$p <- stats::predict(pa, newdata = data)

  # Step 4: Abundance effects on the prediction matrix (6.4)
  pm <- grid
  newdata <- pm
  for (one in names(constants)) newdata[[one]] <- constants[[one]]

  agp_pred <- stats::predict(agp, newdata = newdata, se.fit = TRUE)
  t_mean_agp <- stats::setNames(as.numeric(agp_pred$fit), rownames(pm))
  t_se_agp <- stats::setNames(as.numeric(agp_pred$se.fit), rownames(pm))

  paspen_agp <- if ("pAspen" %in% names(stats::coef(agp))) {
    stats::coef(agp)[["pAspen"]]
  } else {
    0
  }

  coef_agp <- c(Climate = 1, exp(t_mean_agp))
  coef_agp_se <- c(Climate = 0, t_se_agp)

  # Step 5: Stand-age splines, north only (6.5)
  stand_types <- c("Spruce", "Pine", "Decid", "Mixedwood", "TreedBog")
  p_age <- p_age_se <- list()

  if (ages) {
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
          p_count = data$p_count_pa[rows], age = age,
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
  }

  # Step 6: Spread each category over its fine types (6.5)
  out_pa <- out_pa_se <- out_mean <- numeric(0)
  terms_pa1 <- setdiff(terms_pa, c("seas_days", "pAspen"))

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

    if (!term %in% names(pm)) next
    fine_types <- rownames(pm)[pm[[term]] == 1]

    for (fine in fine_types) {
      agp_value <- if (fine %in% names(coef_agp)) coef_agp[[fine]] else 0

      if (ages && fine %in% stand_types) {
        age_names <- paste0(fine, c("R", 1:8))

        if (!is.null(p_age[[term]])) {
          put(age_names, p_age[[term]], p_age_se[[term]], agp_value)
        } else {
          put(age_names, rep(coef_pa[[term]], 9),
              rep(coef_pa_se[[term]], 9), agp_value)
        }
      } else {
        put(fine, coef_pa[[term]], coef_pa_se[[term]], agp_value)
      }
    }
  }

  # v2's Mule Deer adjustment: old pine, and in winter old
  # deciduous, stands are pulled toward the 100-119 class
  base_species <- sub("_(Summer|Winter)$", "", species)

  if (identical(base_species, "MuleDeer")) {
    types <- c("Pine", if (grepl("_Winter$", species)) "Decid")
    for (type in types) {
      old <- paste0(type, c("7", "8"))
      ref <- paste0(type, "6")
      if (all(c(old, ref) %in% names(out_mean))) {
        out_mean[old] <- (out_mean[old] + out_mean[[ref]]) / 2
      }
    }
  }

  # Step 7: Calibrate total abundance to the observed mean (6.6)
  t_p_pa <- stats::plogis(
    stats::predict(pa, newdata = at_constants) +
      paspen_pa * (if (has_aspen) data$pAspen else 0)
  )
  t_p_agp <- stats::predict(agp, newdata = at_constants) +
    paspen_agp * (if (has_aspen) data$pAspen else 0)
  p_obs_total <- ifelse(
    data$lured == "Yes", count / (lure_pa * lure_agp), count
  )
  out_mean <- out_mean *
    (mean(p_obs_total) / mean(t_p_pa * exp(t_p_agp)))

  # Step 8: Cutblock convergence, north only (6.11)
  if (ages) {
    # The same recovery weights as the plant pipeline
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
  }

  # v2 adds Bare and Water at zero to every table (7.1)
  out_pa[c("Bare", "Water")] <- 0
  out_pa_se[c("Bare", "Water")] <- 0
  out_mean[c("Bare", "Water")] <- 0
  coef_agp[c("Bare", "Water")] <- 0
  coef_agp_se[c("Bare", "Water")] <- 0

  table_of <- function(values, se = NA_real_) {
    data.frame(
      term = names(values), estimate = unname(values),
      se = if (length(se) == length(values)) unname(se) else NA_real_,
      stringsAsFactors = FALSE
    )
  }

  presence <- table_of(out_pa, out_pa_se)
  abundance <- table_of(coef_agp, coef_agp_se)

  result <- selection_result(
    fit = list(fit = pa, ok = TRUE, message = NA_character_),
    coefficients = presence,
    ic_table = data.frame(
      model = paste0("pa_", seq_along(aic_pa)), ic = aic_pa,
      ok = is.finite(aic_pa), stringsAsFactors = FALSE
    )
  )

  result$outputs <- list(
    presence = presence,
    abundance = abundance,
    total = table_of(out_mean)
  )

  result
}

# End of script ----
