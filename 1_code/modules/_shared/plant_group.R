# ---
# title: Shared Builder for the Plant-Group Taxon Specs
# author: Brendan Casey
# created: 2026-09-10
# inputs: none
# outputs: none; returns objects in memory
# notes:
#   - The v2 pipeline shape shared by the four plant-group taxa
#     (a survey design, not a taxonomy). Taxon quirks live in each
#     taxon's module, which calls this builder.
#   - `v2_coverage` below is the single statement of what is
#     reproduced; the report reads it. Detail is in
#     docs/taxon_quirks.md.
# ---

# 1. Setup ----

## 1.1 Load packages ----
# Base R only; the harness supplies everything else.

# 2. plant_group_spec() ----

#' Build a v2 Spec for One Plant-Group Taxon
#'
#' Called by each taxon module rather than directly.
#'
#' @param taxon Character. The data slug ("mite" for soil mites).
#' @param protocol_in_v2 Logical. Whether v2 fits Protocol for
#'   this taxon.
#' @param use_protocol Logical, or NULL to take the v2 value.
#' @param reference_note Character, or NULL. One clause on where
#'   this taxon's v2 reference comes from, appended to the spec
#'   notes. Bryophytes differ from the other three.
#' @param bootstrap Character. "spatial_block" draws afresh;
#'   "v2_ids" replays v2's stored draws (_setup/07), making
#'   parity numerical.
#' @return A spec list, as run_spec() consumes.
#'
#' @example # Example usage of the function
#' # spec <- plant_group_spec("lichen", protocol_in_v2 = TRUE)
#' # spec$stages[[1]]$engine
plant_group_spec <- function(
  taxon,
  protocol_in_v2,
  use_protocol = NULL,
  reference_note = NULL,
  bootstrap = c("spatial_block", "v2_ids")
) {
  bootstrap <- match.arg(bootstrap)

  if (!is.character(taxon) || length(taxon) != 1L) {
    stop("`taxon` must be a single character slug.", call. = FALSE)
  }

  if (!is.logical(protocol_in_v2) ||
        length(protocol_in_v2) != 1L ||
        is.na(protocol_in_v2)) {
    stop(
      "`protocol_in_v2` must be TRUE or FALSE.",
      call. = FALSE
    )
  }

  if (is.null(use_protocol)) {
    use_protocol <- protocol_in_v2
  }

  # The habitat sets come from the mite script (no Protocol); the
  # bryophyte and lichen scripts differ only by Protocol directly
  # after Climate. No climate set carries Protocol.
  with_protocol <- function(set) {
    models <- get_model_set(set)

    if (!use_protocol) {
      return(models)
    }

    sub(
      ". ~ . + Climate", ". ~ . + Climate + Protocol",
      models, fixed = TRUE
    )
  }

  list(
    taxon = taxon,
    response_name = "response",
    # The stage a methods experiment replaces by default
    habitat_stage = "habitat",

    # v2 models presence: any value above zero is a detection
    response_transform = "detection",
    family = "binomial",
    weight_column = NULL,
    tier = NULL,

    regions = list(
      north = list(
        filter = ~ nr != "Grassland",
        grid = "veg",
        term_block = "veg",
        habitat_models = with_protocol("habitat_veg_plant_v2")
      ),
      south = list(
        filter = ~ nr %in% c("Grassland", "Parkland"),
        grid = "soil",
        term_block = "soil",
        habitat_models = with_protocol("habitat_soil_plant_v2"),
        # v2 predicts the south candidates at pAspen = 0
        grid_constants = list(paspen = 0)
      )
    ),

    stages = list(
      list(
        name = "climate",
        models = "climate_plant_v2_full",
        engine = "bayesglm",
        selection = "aic_average",
        ic = "AICc",
        control = list(maxit = 250),
        # Province-wide, as v2's climate_models()
        scope = "province",
        # Carried into the habitat stage as `Climate`, as in v2
        carry_as = "Climate"
      ),
      list(
        name = "habitat",
        # Per region below: veg in the north, soil in the south
        models = NULL,
        engine = "bayesglm",
        selection = "ivw_grid",
        ic = "AICc",
        control = list(maxit = 250),
        carry_from = "climate",
        carry_from_as = "Climate",
        # v2 predicts the grid at Climate = 0 and the new protocol
        grid_constants = if (use_protocol) {
          list(
            Climate = 0,
            Protocol = factor("New", levels = c("New", "Old"))
          )
        } else {
          list(Climate = 0)
        },
        head_terms = if (use_protocol) {
          c("Intercept", "Climate", "Protocol")
        } else {
          c("Intercept", "Climate")
        },
        # v2's post-averaging steps, in v2's order (pooling
        # borrows from a spline-fitted age class). The splines
        # read aged stand-cover columns no formula names.
        post_process = list(
          plant_age_splines, plant_cutblock_convergence,
          plant_paspen, plant_footprint_pooling
        ),
        # The validation also weights each fine cutblock class by
        # its own effect, and the formulas name only lumped ones.
        extra_covariates = c(
          plant_age_columns(),
          as.vector(t(outer(
            paste0("CC", c("WhiteSpruce", "Pine", "Deciduous",
                           "Mixedwood")),
            c("R", 1:4), paste0
          )))
        ),
        min_detections = 20L
      )
    ),

    # One province-wide draw per species, as v2's
    # bootstrap_data(). No seed here: the experiment's seed is
    # used.
    resample = if (bootstrap == "v2_ids") {
      list(
        scheme = "precomputed",
        per_species = TRUE,
        scope = "province"
      )
    } else {
      list(
        scheme = "spatial_block",
        min_detections = 20L,
        scope = "province"
      )
    },

    v2_coverage = list(
      climate = v2_status(
        "reproduced",
        paste(
          "The v2 58-model set, bayesglm, full AICc averaging,",
          "fitted once per draw on every unit and shared by both",
          "regions, as v2 fits it."
        )
      ),
      habitat = v2_status(
        "reproduced",
        paste(
          "IVW on the prediction grid, the stand-age splines,",
          "cutblock convergence, footprint pooling, the south",
          "pAspen and the 20-detection skip. Matches v2 to 2e-12",
          "on the full-data draw, north and south."
        )
      ),
      validation = v2_status(
        "reproduced",
        paste(
          "v2's seven validation AUCs, in-bag as v2 scores them",
          "and out-of-bag as well. South exact; north within 2e-4,",
          "a residual v2's own coefficients show too."
        )
      ),
      resampling = if (bootstrap == "v2_ids") {
        v2_status(
          "reproduced",
          "v2's own stored draws, replayed per species."
        )
      } else {
        v2_status(
          "reproduced",
          paste(
            "v2's spatial-block bootstrap, drawn once per species",
            "across the province with its 20-detection redraw rule.",
            "The same method, not the same draws: v2 is unseeded."
          )
        )
      }
    ),

    # v2's seven validation AUCs, scored in-bag as v2 does and
    # out-of-bag as well; see plant_v2_validation().
    validate = plant_v2_validation,

    # The final model the harness scores and reports: v2's own
    # prediction from the published coefficient tables
    final_prediction = plant_v2_full_prediction,

    use_protocol = use_protocol,
    protocol_is_v2 = identical(use_protocol, protocol_in_v2),

    notes = paste0(
      "Protocol ", if (use_protocol) "fitted" else "not fitted",
      if (identical(use_protocol, protocol_in_v2)) {
        " (the v2 setting for this taxon)."
      } else {
        " (overridden; v2 does the opposite for this taxon)."
      },
      if (is.null(reference_note)) "" else paste0(" ", reference_note)
    )
  )
}

# 3. plant_v2_term_labels() ----

#' Relabel Plant Habitat Terms as v2's Published Coefficients Are
#'
#' v2 does not publish its habitat coefficients under the names
#' it fits them with. 04a_coefficient_standardization.R relabels
#' them for cross-taxa use before they reach COEFS.RData, which
#' is what 0_data/v2_results/v2_results.csv is built from:
#'
#' - `BlackSpruce` becomes `TreedBog`, and `Grass` `GrassHerb`.
#' - `UrbInd` is copied to `Urban`, `Industrial` and `Rural`.
#' - `TreedFen` is copied to each age class, `TreedFenR` to
#'   `TreedFen8`, as it is not fitted by age.
#' - In the south, `paspen` becomes `pAspen`.
#'
#' A copied term appears once per copy, each compared against
#' v2's copy.
#'
#' @param terms Character vector of harness habitat terms.
#' @return A data frame of `term` (as fitted) and `v2_term`, one
#'   row per published label.
#'
#' @example # Example usage of the function
#' # plant_v2_term_labels(c("BlackSpruce", "UrbInd", "Crop"))
plant_v2_term_labels <- function(terms) {
  renamed <- c(
    BlackSpruce = "TreedBog",
    Grass = "GrassHerb",
    paspen = "pAspen"
  )

  copied <- list(
    UrbInd = c("Urban", "Industrial", "Rural"),
    TreedFen = paste0("TreedFen", c("R", 1:8))
  )

  rows <- lapply(unique(terms), function(one) {
    v2 <- if (one %in% names(copied)) {
      copied[[one]]
    } else if (one %in% names(renamed)) {
      renamed[[one]]
    } else if (startsWith(one, "BlackSpruce")) {
      # 04a relabels by substitution, so the spline-fitted age
      # classes BlackSpruceR to BlackSpruce8 become TreedBogR to
      # TreedBog8
      sub("^BlackSpruce", "TreedBog", one)
    } else {
      one
    }

    data.frame(term = one, v2_term = v2, stringsAsFactors = FALSE)
  })

  do.call(rbind, rows)
}

# 4. v2 habitat machinery ----
# Ports of the steps v2's vegetation_models() applies after the
# inverse-variance weighting (hierarchical-model_functions.R),
# in v2's order: the stand-age splines (section 7), the cutblock
# convergence (7.5), and the footprint pooling (8.0). Each takes
# and returns the selection result, so the habitat stage runs
# them as `post_process` steps.

## 4.1 plant_stand_types() ----

#' The Five Aged Stand Types v2 Models with Splines
#'
#' @return Character vector.
#'
#' @example # Example usage of the function
#' # plant_stand_types()
plant_stand_types <- function() {
  c("WhiteSpruce", "Pine", "Deciduous", "Mixedwood", "BlackSpruce")
}

## 4.2 plant_age_columns() ----

#' The Aged Stand-Cover Columns the Splines Read
#'
#' @return Character vector, R and 1 to 8 per stand type.
#'
#' @example # Example usage of the function
#' # head(plant_age_columns())
plant_age_columns <- function() {
  as.vector(t(outer(plant_stand_types(), c("R", 1:8), paste0)))
}

## 4.3 plant_age_splines() ----

#' Replace the Aged Stand Effects with v2's Stand-Age Splines
#'
#' v2 fits the unaged stand types by inverse-variance weighting,
#' then models detection against stand age within each type and
#' writes the result over the 45 aged effects, R and 1 to 8 for
#' five types:
#'
#' 1. One frame per type from units where an age class covers
#'    more than 10%, each carrying detection, age (0.5 for R),
#'    the cover as weight, and the site-level IVW prediction as
#'    an offset. Grassy units join the four upland types at age
#'    0.5 and shrubby units at age 1, at half weight, in
#'    proportion to the type's share of the stand. v2 computes the
#'    mixedwood share from white spruce; that is reproduced.
#' 2. A binomial GAM, `s(sqrt(age), k = 3, m = 2)` with the
#'    offset, per type, per pair (white spruce with pine,
#'    deciduous with mixedwood) and for all five together;
#'    intercept-only where there are 8 or fewer detections. A
#'    ninth, intercept-only over all five.
#' 3. The grouping with the lowest summed AIC, less one per extra
#'    variance: separate (-4), paired (-2), all, or none.
#' 4. Predictions at ages 0.5 and 1 to 8, with the type's IVW
#'    effect as offset.
#'
#' A region with no aged stand types - the south - is returned
#' unchanged.
#'
#' @param selected A selection result from the ivw_grid rule,
#'   whose `predict()` gives the site-level IVW prediction.
#' @param data The stage's data: detection in `response`, and the
#'   unaged and aged stand-cover columns, `Grass` and `Shrub`.
#' @return The selection result with the 45 aged effects added.
#'
#' @example # Example usage of the function
#' # selected <- plant_age_splines(selected, stage_data)
plant_age_splines <- function(selected, data) {
  types <- plant_stand_types()
  estimate <- stats::setNames(
    selected$coefficients$estimate, selected$coefficients$term
  )

  if (!all(types %in% names(estimate))) {
    return(selected)
  }

  # Site-level IVW prediction (link scale), computed only where
  # aged stand types exist
  prediction <- if (is.function(selected$predict)) {
    selected$predict(data, "link")
  } else {
    NULL
  }

  if (is.null(prediction) || length(prediction) != nrow(data)) {
    stop("The age splines need the site-level IVW prediction.",
         call. = FALSE)
  }

  cutoff <- 0.1
  count <- data$response

  # Step 1: One frame per stand type
  stand <- stats::setNames(vector("list", length(types)), types)

  for (i in 0:8) {
    label <- if (i == 0) "R" else i
    age <- if (i == 0) 0.5 else i

    for (type in types) {
      cover <- data[[paste0(type, label)]]
      rows <- which(cover > cutoff)

      if (length(rows) > 0) {
        stand[[type]] <- rbind(stand[[type]], data.frame(
          pCount = count[rows], age = age, wt1 = cover[rows],
          p = prediction[rows]
        ))
      }
    }
  }

  # Grassy (age 0.5) and shrubby (age 1) units join the upland
  # types at half weight, by the type's share of the stand
  open_join <- function(column, age) {
    rows <- which(data[[column]] > cutoff)
    total <- data$WhiteSpruce[rows] + data$Pine[rows] +
      data$Deciduous[rows] + data$Mixedwood[rows] +
      data$BlackSpruce[rows] + 0.01

    share <- list(
      WhiteSpruce = data$WhiteSpruce[rows] / total,
      Pine = data$Pine[rows] / total,
      Deciduous = data$Deciduous[rows] / total,
      # v2 divides white spruce here, not mixedwood
      Mixedwood = data$WhiteSpruce[rows] / total
    )

    for (type in names(share)) {
      p_type <- share[[type]]

      if (sum(p_type) != 0) {
        keep <- p_type > 0
        stand[[type]] <<- rbind(stand[[type]], data.frame(
          pCount = count[rows][keep], age = age,
          wt1 = data[[column]][rows][keep] / 2 * p_type[keep],
          p = prediction[rows][keep]
        ))
      }
    }
  }

  open_join("Grass", 0.5)
  open_join("Shrub", 1)

  frames <- c(
    stand,
    list(
      Conifpine = rbind(stand$WhiteSpruce, stand$Pine),
      Decidmixed = rbind(stand$Deciduous, stand$Mixedwood),
      All = do.call(rbind, stand)
    )
  )

  # Step 2: The nine fits
  fit_age <- function(frame, spline = TRUE) {
    formula <- if (spline && sum(sign(frame$pCount)) > 8) {
      pCount ~ s(sqrt(age), k = 3, m = 2) + offset(p)
    } else {
      pCount ~ 1 + offset(p)
    }

    suppressWarnings(mgcv::gam(
      formula, data = frame, family = "binomial", weights = frame$wt1
    ))
  }

  models <- lapply(frames, fit_age)
  models$None <- fit_age(frames$All, spline = FALSE)

  aic <- vapply(models, stats::AIC, numeric(1))

  # Step 3: Choose the grouping
  grouping <- which.min(c(
    separate = sum(aic[types]) - 4,
    paired = aic[["BlackSpruce"]] + aic[["Conifpine"]] +
      aic[["Decidmixed"]] - 2,
    all = aic[["All"]],
    none = aic[["None"]]
  ))

  model_for <- switch(
    names(grouping),
    separate = stats::setNames(types, types),
    paired = c(
      WhiteSpruce = "Conifpine", Pine = "Conifpine",
      Deciduous = "Decidmixed", Mixedwood = "Decidmixed",
      BlackSpruce = "BlackSpruce"
    ),
    all = stats::setNames(rep("All", 5), types),
    none = stats::setNames(rep("None", 5), types)
  )

  # Step 4: Predict each type's age classes, offset by its IVW
  # effect
  aged <- do.call(rbind, lapply(types, function(type) {
    predicted <- stats::predict(
      models[[model_for[[type]]]],
      newdata = data.frame(age = c(0.5, 1:8), p = estimate[[type]]),
      se.fit = TRUE
    )

    data.frame(
      term = paste0(type, c("R", 1:8)),
      estimate = as.numeric(predicted$fit),
      se = as.numeric(predicted$se.fit),
      stringsAsFactors = FALSE
    )
  }))

  selected$coefficients <- rbind(
    selected$coefficients[
      !selected$coefficients$term %in% aged$term,
    ],
    aged
  )
  selected$age_grouping <- names(grouping)

  selected
}

## 4.4 plant_cutblock_convergence() ----

#' Move Older Cutblocks Toward the Natural Stand of the Same Age
#'
#' v2's section 7.5. Cutblock classes 2, 3 and 4 are replaced by
#' a weighted average, on the probability scale, of themselves
#' and the natural stand of the same age class, with fixed
#' recovery weights. Standard errors are averaged linearly, as v2
#' does. Needs the age splines to have run first, for the
#' natural age classes.
#'
#' @param selected A selection result.
#' @param data Unused; the post_process signature.
#' @return The selection result with the 12 cutblock effects
#'   converged.
#'
#' @example # Example usage of the function
#' # selected <- plant_cutblock_convergence(selected, stage_data)
plant_cutblock_convergence <- function(selected, data = NULL) {
  coefficients <- selected$coefficients
  recovery <- cutblock_recovery_weights()
  weights <- list(
    WhiteSpruce = recovery$conifer,
    Pine = recovery$conifer,
    Deciduous = recovery$deciduous,
    Mixedwood = recovery$deciduous
  )

  for (type in names(weights)) {
    for (k in 1:3) {
      age <- k + 1
      w <- weights[[type]][k]
      cc <- match(paste0("CC", type, age), coefficients$term)
      natural <- match(paste0(type, age), coefficients$term)

      if (is.na(cc) || is.na(natural)) {
        next
      }

      coefficients$estimate[cc] <- stats::qlogis(
        stats::plogis(coefficients$estimate[natural]) * w +
          stats::plogis(coefficients$estimate[cc]) * (1 - w)
      )
      coefficients$se[cc] <- coefficients$se[natural] * w +
        coefficients$se[cc] * (1 - w)
    }
  }

  selected$coefficients <- coefficients

  selected
}

## 4.5 plant_paspen() ----

#' Add v2's Averaged pAspen Effect to a South Habitat Result
#'
#' v2's soil_models() predicts every candidate at pAspen = 0 and
#' reports pAspen separately: an inverse-variance average of the
#' coefficient over the candidates that carry it. It keeps only
#' positive estimates and positive standard errors, filtering the
#' two separately, so a negative estimate shifts which error it
#' is paired with. Reproduced as written.
#'
#' @param selected A selection result from the ivw_grid rule,
#'   carrying `candidate_coefficients`.
#' @param data Unused; the post_process signature.
#' @return The selection result with a `paspen` term, or
#'   unchanged when no candidate fits pAspen.
#'
#' @example # Example usage of the function
#' # selected <- plant_paspen(selected, stage_data)
plant_paspen <- function(selected, data = NULL) {
  candidates <- selected$candidate_coefficients

  estimate <- vapply(candidates, function(cf) {
    row <- match("paspen", cf$term)
    if (is.na(row)) 0 else cf$estimate[row]
  }, numeric(1))
  se <- vapply(candidates, function(cf) {
    row <- match("paspen", cf$term)
    if (is.na(row)) 0 else cf$se[row]
  }, numeric(1))

  if (all(estimate == 0)) {
    return(selected)
  }

  estimate <- estimate[estimate > 0]
  se <- se[se > 0]

  mean_paspen <- suppressWarnings(
    sum(estimate / se^2) / sum(1 / se^2)
  )

  selected$coefficients <- rbind(
    selected$coefficients[selected$coefficients$term != "paspen", ],
    data.frame(
      term = "paspen", estimate = mean_paspen,
      se = sqrt(1 / sum(1 / se^2)), stringsAsFactors = FALSE
    )
  )

  selected
}

## 4.6 plant_footprint_pooling() ----

#' Pool Poorly Sampled Footprint Effects, as a Post-Process Step
#'
#' v2's section 8.0, applied after the stand-age splines and the
#' cutblock convergence because it borrows from a spline-fitted
#' age class. See coef_adjust_plant_veg() for what is pooled.
#'
#' @param selected A selection result.
#' @param data Unused; the post_process signature.
#' @return The selection result with the four footprint effects
#'   pooled.
#'
#' @example # Example usage of the function
#' # selected <- plant_footprint_pooling(selected, stage_data)
plant_footprint_pooling <- function(selected, data = NULL) {
  selected$coefficients <- coef_adjust_plant_veg(
    selected$coefficients
  )

  selected
}

## 4.7 coef_adjust_plant_veg() ----

#' Borrow Strength for Poorly Sampled Footprint Types
#'
#' v2's `coef.adjust`. Some human footprint types are rarely the
#' dominant cover at a survey unit, so their effect is estimated
#' from little data. v2 pools each with a type it is assumed to
#' resemble, by inverse-variance weight:
#'
#' - `HardLin` borrows from `UrbInd`.
#' - The three soft linear types - `EnSoftLin`, `EnSeismic` and
#'   `TrSoftLin` - each borrow from a composite of young
#'   regenerating stands, weighted by how much those stand types
#'   overlap soft linear features in the provincial summary.
#'
#' The weights are v2's, measured from a 1 km summary and fixed
#' since 2020-11-17. They are an assumption about which habitats
#' resemble which, not an estimate, so they are stated here
#' rather than derived.
#'
#' @param coefficients A data frame of term, estimate and se.
#' @param overlap Numeric vector of four proportions, for
#'   white spruce, pine, deciduous and black spruce regeneration.
#' @return The coefficients, with the four terms adjusted.
#'
#' @example # Example usage of the function
#' # coef_adjust_plant_veg(selected$coefficients)
coef_adjust_plant_veg <- function(
  coefficients,
  overlap = c(0.049, 0.0893, 0.434, 0.396)
) {
  if (is.null(coefficients)) {
    return(NULL)
  }

  value <- stats::setNames(
    coefficients$estimate, coefficients$term
  )
  error <- stats::setNames(coefficients$se, coefficients$term)

  # Pool two estimates by precision.
  pool <- function(a, a_se, b, b_se) {
    precision <- 1 / a_se^2 + 1 / b_se^2

    list(
      estimate = (a / a_se^2 + b / b_se^2) / precision,
      se = sqrt(1 / precision)
    )
  }

  present <- function(...) {
    all(c(...) %in% names(value)) &&
      all(is.finite(value[c(...)])) &&
      all(is.finite(error[c(...)]))
  }

  # Step 1: Hard linear features borrow from urban and industrial
  if (present("HardLin", "UrbInd")) {
    pooled <- pool(
      value["HardLin"], error["HardLin"],
      value["UrbInd"], error["UrbInd"]
    )
    value["HardLin"] <- pooled$estimate
    error["HardLin"] <- pooled$se
  }

  # Step 2: Soft linear features borrow from young regeneration
  young_types <- c(
    "CCWhiteSpruceR", "CCPineR", "CCDeciduousR", "BlackSpruce1"
  )

  if (present(young_types)) {
    weights <- overlap / sum(overlap)

    young <- sum(weights * value[young_types])
    # The weighted variance carries no between-type component,
    # because the weights are fixed rather than estimated.
    young_se <- sqrt(sum(weights * error[young_types]^2))

    for (one in c("EnSoftLin", "EnSeismic", "TrSoftLin")) {
      if (!present(one)) {
        next
      }

      pooled <- pool(value[one], error[one], young, young_se)
      value[one] <- pooled$estimate
      error[one] <- pooled$se
    }
  }

  coefficients$estimate <- unname(value[coefficients$term])
  coefficients$se <- unname(error[coefficients$term])

  coefficients
}

## 4.8 plant_v2_parts() ----

#' The Pieces of v2's Plant Prediction at a Set of Units
#'
#' v2 predicts a plant from its coefficient tables, not from a
#' fitted model: the climate prediction, and a landcover
#' prediction that weights each habitat type's effect by its
#' cover at the unit. Shared by the validation AUCs and by the
#' final prediction, so the two cannot drift apart.
#'
#' The cover terms are the published effects, less the unaged
#' stand types, which v2 publishes only by age class. A term's
#' column may carry the block suffix the harmonizer gave columns
#' in more than one block (UrbInd_veg, UrbInd_soil).
#'
#' Reproduced as written: the protocol coefficient, a logit, is
#' subtracted from an "Old" survey's landcover prediction on the
#' probability scale.
#'
#' @param stage_coefficients Named list of data frames of term
#'   and estimate: `climate` and `habitat`.
#' @param data The units to predict at.
#' @return A list: `climate` (probability), `raw` (landcover,
#'   probability scale), `landcover` (`raw` with the protocol
#'   adjustment), `slope` (the Climate effect), `aspen`, the cover
#'   matrix `x` and the cover terms' `effects` (logit scale).
#'
#' @example # Example usage of the function
#' # parts <- plant_v2_parts(stage_coefficients, region_frame)
plant_v2_parts <- function(stage_coefficients, data) {
  climate <- stage_coefficients$climate
  habitat <- stage_coefficients$habitat

  estimate <- stats::setNames(habitat$estimate, habitat$term)
  head_terms <- c("Intercept", "Climate", "Protocol", "paspen")

  column_of <- function(term) {
    candidates <- c(term, paste0(term, c("_veg", "_soil")))
    hit <- candidates[candidates %in% names(data)]
    if (length(hit) == 0) NA_character_ else hit[1]
  }

  cover <- setdiff(
    names(estimate), c(head_terms, plant_stand_types())
  )
  cover <- cover[is.finite(estimate[cover])]
  cover_columns <- vapply(cover, column_of, character(1))
  cover <- cover[!is.na(cover_columns)]
  cover_columns <- cover_columns[!is.na(cover_columns)]

  x <- as.matrix(data[, cover_columns, drop = FALSE])
  raw <- drop(x %*% stats::plogis(estimate[cover]))
  landcover <- raw

  if ("Protocol" %in% names(estimate) &&
        "Protocol" %in% names(data)) {
    old <- as.character(data$Protocol) == "Old"
    landcover[old] <- landcover[old] - estimate[["Protocol"]]
  }

  list(
    climate = stats::plogis(
      predict_from_coefficients(climate, data, "link")
    ),
    raw = raw,
    landcover = landcover,
    slope = estimate[["Climate"]],
    aspen = if ("paspen" %in% names(estimate) &&
                  "paspen" %in% names(data)) {
      data$paspen * estimate[["paspen"]]
    } else {
      0
    },
    x = x,
    effects = estimate[cover]
  )
}

## 4.9 plant_v2_full_prediction() ----

#' v2's Final Plant Prediction: Landcover and Climate Together
#'
#' The prediction v2's "Full" validation AUC scores. The plant
#' specs name it as their `final_prediction`, so the harness's
#' own metrics score the model v2 reports, after its stand-age
#' splines, cutblock convergence and footprint pooling, rather
#' than any single fitted candidate.
#'
#' @param stage_coefficients Named list with `climate` and
#'   `habitat` coefficient tables.
#' @param frame The units to predict at.
#' @return A numeric vector of probabilities, one per row.
#'
#' @example # Example usage of the function
#' # plant_v2_full_prediction(stage_coefficients, frame)
plant_v2_full_prediction <- function(stage_coefficients, frame) {
  parts <- plant_v2_parts(stage_coefficients, frame)

  stats::plogis(
    stats::qlogis(parts$raw) + parts$climate * parts$slope +
      parts$aspen
  )
}

## 4.10 plant_v2_validation() ----

#' v2's Plant Validation AUCs, In-Bag and Out-of-Bag
#'
#' A port of model_validation() (model-validation_functions.R).
#' v2 scores each draw from its published coefficient tables,
#' not from a fitted model, with seven AUCs: climate alone, and
#' truncated at its 99th percentile; landcover alone; landcover
#' plus climate; and landcover and climate joined per habitat
#' type, each with and without the truncation. Climate is scored
#' over every unit in the draw, the others over the region's.
#'
#' v2 scores the units in the draw, once each (`%in%`), which is
#' in-sample. The same seven are also scored on the units the
#' draw left out, which is the held-out read v2 does not have.
#' Iteration 1 is the full data and has no out-of-bag units.
#'
#' @param stage_coefficients Named list of data frames of term
#'   and estimate: `climate` and `habitat`.
#' @param frame The region's frame.
#' @param province_frame The province-wide frame, for the climate
#'   AUCs; the region's frame when there is none.
#' @param draw Character vector of survey unit ids in the draw.
#' @return A data frame of metric and value.
#'
#' @example # Example usage of the function
#' # plant_v2_validation(coefs, frame, province, draw)
plant_v2_validation <- function(
  stage_coefficients, frame, province_frame, draw
) {
  climate <- stage_coefficients$climate
  habitat <- stage_coefficients$habitat

  if (is.null(climate) || is.null(habitat) ||
        !requireNamespace("pROC", quietly = TRUE)) {
    return(NULL)
  }

  auc <- function(observed, predicted) {
    tryCatch(
      as.numeric(suppressMessages(pROC::auc(observed, predicted))),
      error = function(e) NA_real_
    )
  }

  truncate <- function(x) {
    cap <- stats::quantile(x, 0.99, names = FALSE)
    ifelse(x >= cap, cap, x)
  }

  score <- function(in_units) {
    all_units <- province_frame[
      province_frame$survey_unit_id %in% in_units, , drop = FALSE
    ]
    region <- frame[
      frame$survey_unit_id %in% in_units, , drop = FALSE
    ]

    if (nrow(region) == 0 || nrow(all_units) == 0) {
      return(rep(NA_real_, 7))
    }

    parts <- plant_v2_parts(stage_coefficients, region)
    climate_all <- stats::plogis(
      predict_from_coefficients(climate, all_units, "link")
    )

    # The truncation caps the region's climate at the 99th
    # percentile over every unit in the draw
    cap <- stats::quantile(climate_all, 0.99, names = FALSE)
    climate_region_trunc <- ifelse(
      parts$climate >= cap, cap, parts$climate
    )

    component <- parts$climate * parts$slope + parts$aspen
    component_trunc <- climate_region_trunc * parts$slope +
      parts$aspen

    joint <- function(shift) {
      shifted <- outer(shift, parts$effects, `+`)
      rowSums(parts$x * stats::plogis(shifted))
    }

    observed <- as.integer(region$response > 0)
    observed_all <- as.integer(all_units$response > 0)

    c(
      Climate = auc(observed_all, climate_all),
      Climate_Truncated = auc(observed_all, truncate(climate_all)),
      Landcover = auc(observed, parts$landcover),
      Full = auc(
        observed, stats::plogis(stats::qlogis(parts$raw) + component)
      ),
      Full_Truncated = auc(
        observed,
        stats::plogis(stats::qlogis(parts$raw) + component_trunc)
      ),
      Full_Joint = auc(observed, joint(component)),
      Full_Joint_Truncated = auc(observed, joint(component_trunc))
    )
  }

  in_bag <- unique(draw)
  out_of_bag <- setdiff(
    union(province_frame$survey_unit_id, frame$survey_unit_id),
    in_bag
  )

  in_scores <- score(in_bag)
  out_scores <- if (length(out_of_bag) == 0) {
    rep(NA_real_, 7)
  } else {
    score(out_of_bag)
  }

  names_out <- c(
    "Climate", "Climate_Truncated", "Landcover", "Full",
    "Full_Truncated", "Full_Joint", "Full_Joint_Truncated"
  )

  data.frame(
    metric = c(paste0("v2val_", names_out),
               paste0("oob_v2val_", names_out)),
    value = c(unname(in_scores), unname(out_scores)),
    stringsAsFactors = FALSE
  )
}

# 5. cutblock_recovery_weights() ----

#' v2's Cutblock Recovery Weights
#'
#' How far a cutblock of age class 2, 3 and 4 has converged on the
#' natural stand of the same age, by stand group. Fixed in v2 and
#' shared by its plant (section 7.5) and mammal (section 6.11)
#' pipelines, so stated once for both modules.
#'
#' The two pipelines' stand-age splines are not shared: their
#' parameters differ (spline basis, detection threshold, model
#' choice), and merging them would put parity at risk.
#'
#' @return A list of `conifer` and `deciduous` weights, one per
#'   age class 2 to 4.
#'
#' @example # Example usage of the function
#' # cutblock_recovery_weights()$conifer
cutblock_recovery_weights <- function() {
  list(
    conifer = c(0.500, 0.849, 0.960),
    deciduous = c(0.705, 0.912, 0.970)
  )
}

# 6. plant_group_specs() ----

#' Every Plant-Group Spec
#'
#' Each taxon module must already be sourced.
#'
#' @param use_protocol Logical, or NULL for the v2 setting per
#'   taxon.
#' @return A named list of specs, keyed on the data slug.
#'
#' @example # Example usage of the function
#' # names(plant_group_specs())
plant_group_specs <- function(use_protocol = NULL) {
  list(
    bryophyte = bryophyte_spec(use_protocol = use_protocol),
    lichen = lichen_spec(use_protocol = use_protocol),
    mite = soil_mite_spec(use_protocol = use_protocol),
    vascular_plant = vascular_plant_spec(
      use_protocol = use_protocol
    )
  )
}

# End of script ----
