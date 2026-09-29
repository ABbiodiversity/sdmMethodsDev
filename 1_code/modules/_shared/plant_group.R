# ---
# title: Shared Builder for the Plant-Group Taxon Specs
# author: Brendan Casey
# created: 2026-09-10
# inputs: none
# outputs: none; returns objects in memory
# notes:
#   - Bryophytes, lichens, soil mites and vascular plants each
#     have their own module directory, because each is free to
#     diverge and a taxon-specific quirk should have one obvious
#     home. What they still share is the v2 pipeline shape, and
#     that lives here so four copies cannot drift apart.
#   - "Plant group" names a survey design rather than a taxonomy.
#     Soil mites are animals; they are here because v2 fits them
#     with the plant scripts, on the plant survey design.
#   - Each taxon module states its own facts and calls this
#     builder. Nothing in here looks a taxon up in a table, so
#     adding a quirk means editing that taxon's file rather than
#     adding a branch to a shared one.
#   - The underscore prefix marks this as shared machinery rather
#     than a taxon, matching _setup/ and _deprecated/.
#   - What this spec reproduces of v2 is stated once, in
#     `v2_coverage` below. The report is generated from it, so
#     change it here when the harness changes, and nowhere else.
#     Per-quirk detail is in docs/taxon_quirks.md.
# ---

# 1. Setup ----

## 1.1 Load packages ----
# Base R only; the harness supplies everything else.

# 2. plant_group_spec() ----

#' Build a v2 Spec for One Plant-Group Taxon
#'
#' The v2 pipeline shape shared by bryophytes, lichens, soil
#' mites and vascular plants. Called by each taxon module rather
#' than directly.
#'
#' @param taxon Character. The data slug, which keys the response
#'   file, the species catalogue and the covariate catalogue.
#'   Note that soil mites carry the slug "mite".
#' @param protocol_in_v2 Logical. Whether v2 fits Protocol for
#'   this taxon. Recorded so a run can say whether it followed v2
#'   or overrode it.
#' @param use_protocol Logical, or NULL to take the v2 value.
#'   Setting it equalizes a term v2 applies inconsistently, which
#'   is what a cross-taxa experiment wants.
#' @param reference_note Character, or NULL. One clause on where
#'   this taxon's v2 reference comes from, appended to the spec
#'   notes. Bryophytes differ from the other three.
#' @param bootstrap Character. "spatial_block" draws v2's
#'   spatially blocked bootstrap afresh; "v2_ids" replays the
#'   draws v2 itself made, stored per species by
#'   _setup/07_harmonize_v2_plant_bootstrap_ids.R, which makes
#'   parity numerical draw by draw.
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

  # The habitat sets are spliced from the mite script, which
  # fits no Protocol. In the bryophyte and lichen scripts the
  # same formulas carry the term directly after Climate and
  # nowhere else, so inserting it there reproduces them. The
  # climate set carries no Protocol in any variant.
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

    # Plant-group responses are cover or abundance values; v2
    # models presence, so anything above zero is a detection.
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
        # Fitted once per draw on every unit, as v2's
        # climate_models() is, and shared by both regions.
        scope = "province",
        # The habitat stage takes this stage's prediction as a
        # term called Climate, which is how v2 composes them.
        carry_as = "Climate"
      ),
      list(
        name = "habitat",
        # Set per region below, because north fits vegetation
        # types and south fits soil types.
        models = NULL,
        engine = "bayesglm",
        selection = "ivw_grid",
        ic = "AICc",
        control = list(maxit = 250),
        carry_from = "climate",
        carry_from_as = "Climate",
        # v2 predicts each candidate onto the grid holding
        # Climate at zero, and at the new protocol where Protocol
        # is fitted, so the habitat effects are read at an
        # average climate under one protocol.
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
        # v2's stand-age splines, then its cutblock convergence,
        # both before the footprint pooling (coef_adjust). The
        # splines read the aged stand-cover columns, which no
        # formula names. Both leave the south unchanged.
        post_process = list(
          plant_age_splines, plant_cutblock_convergence, plant_paspen
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
        coef_adjust = TRUE,
        # v2 skips the habitat model when the draw, after the
        # region filter, holds fewer than 20 detections.
        min_detections = 20L
      )
    ),

    # One draw per species for the whole province, as v2's
    # bootstrap_data() makes it, filtered to each region's units
    # when the habitat stage is fitted.
    #
    # No seed here. The experiment sets one base seed, `boot_seed`
    # in run.R, and each species derives its own from it. Without
    # one the fresh draws are unseeded, as in v2.
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

    # What this spec reproduces of v2, per stage. The single
    # source of truth for coverage: the report reads it.
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

    use_protocol = use_protocol,
    protocol_is_v2 = identical(use_protocol, protocol_in_v2),

    # Facts about this taxon's configuration. Coverage is in
    # v2_coverage, not here.
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
# in v2's order: the stand-age splines (section 7), then the
# cutblock convergence (7.5). The footprint pooling (8.0) follows
# in the harness, as coef_adjust. Each takes and returns the
# selection result, so the habitat stage runs them as
# `post_process` steps.

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
#'   carrying `site_prediction`.
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

  if (is.null(selected$site_prediction) ||
        length(selected$site_prediction) != nrow(data)) {
    stop("The age splines need the site-level IVW prediction.",
         call. = FALSE)
  }

  cutoff <- 0.1
  count <- data$response
  prediction <- selected$site_prediction

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
  weights <- list(
    WhiteSpruce = c(0.50, 0.849, 0.96),
    Pine = c(0.50, 0.849, 0.96),
    Deciduous = c(0.705, 0.912, 0.97),
    Mixedwood = c(0.705, 0.912, 0.97)
  )

  for (type in names(weights)) {
    for (k in seq_along(2:4)) {
      age <- (2:4)[k]
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

## 4.6 plant_v2_validation() ----

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
#' Reproduced as written: the protocol coefficient, a logit, is
#' subtracted from an "Old" survey's landcover prediction on the
#' probability scale.
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

  climate_prediction <- function(data) {
    stats::plogis(predict_from_coefficients(climate, data, "link"))
  }

  truncate <- function(x) {
    cap <- stats::quantile(x, 0.99, names = FALSE)
    ifelse(x >= cap, cap, x)
  }

  estimate <- stats::setNames(habitat$estimate, habitat$term)
  head <- c("Intercept", "Climate", "Protocol", "paspen")

  # The cover terms are the published effects, less the unaged
  # stand types, which v2 publishes only by age class. A term's
  # column may carry the block suffix the harmonizer gave columns
  # in more than one block (UrbInd_veg, UrbInd_soil).
  column_of <- function(term) {
    candidates <- c(term, paste0(term, c("_veg", "_soil")))
    hit <- candidates[candidates %in% names(frame)]
    if (length(hit) == 0) NA_character_ else hit[1]
  }

  cover <- setdiff(names(estimate), c(head, plant_stand_types()))
  cover <- cover[is.finite(estimate[cover])]
  cover_columns <- vapply(cover, column_of, character(1))
  cover <- cover[!is.na(cover_columns)]
  cover_columns <- cover_columns[!is.na(cover_columns)]

  score <- function(in_units) {
    all_units <- province_frame[
      province_frame$survey_unit_id %in% in_units, , drop = FALSE
    ]
    region <- frame[frame$survey_unit_id %in% in_units, , drop = FALSE]

    if (nrow(region) == 0 || nrow(all_units) == 0) {
      return(rep(NA_real_, 7))
    }

    climate_all <- climate_prediction(all_units)
    climate_region <- climate_prediction(region)
    cap <- stats::quantile(climate_all, 0.99, names = FALSE)
    climate_region_trunc <- ifelse(climate_region >= cap, cap,
                                   climate_region)

    x <- as.matrix(region[, cover_columns, drop = FALSE])
    effect <- stats::plogis(estimate[cover])
    landcover <- drop(x %*% effect)

    if ("Protocol" %in% names(estimate) && "Protocol" %in% names(region)) {
      old <- as.character(region$Protocol) == "Old"
      landcover[old] <- landcover[old] - estimate[["Protocol"]]
    }

    slope <- estimate[["Climate"]]
    aspen <- if ("paspen" %in% names(estimate) &&
                   "paspen" %in% names(region)) {
      region$paspen * estimate[["paspen"]]
    } else {
      0
    }

    raw <- drop(x %*% effect)
    component <- climate_region * slope + aspen
    component_trunc <- climate_region_trunc * slope + aspen

    joint <- function(shift) {
      rowSums(x * stats::plogis(outer(shift, estimate[cover], `+`)))
    }

    observed <- as.integer(region$response > 0)
    observed_all <- as.integer(all_units$response > 0)

    c(
      Climate = auc(observed_all, climate_all),
      Climate_Truncated = auc(observed_all, truncate(climate_all)),
      Landcover = auc(observed, landcover),
      Full = auc(observed, stats::plogis(stats::qlogis(raw) + component)),
      Full_Truncated = auc(
        observed, stats::plogis(stats::qlogis(raw) + component_trunc)
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

  names_out <- c("Climate", "Climate_Truncated", "Landcover", "Full",
                 "Full_Truncated", "Full_Joint", "Full_Joint_Truncated")

  data.frame(
    metric = c(paste0("v2val_", names_out),
               paste0("oob_v2val_", names_out)),
    value = c(unname(in_scores), unname(out_scores)),
    stringsAsFactors = FALSE
  )
}

# 5. plant_group_specs() ----

#' Every Plant-Group Spec
#'
#' A convenience for running all four at once. Each taxon module
#' must already be sourced.
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
