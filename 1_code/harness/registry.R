# ---
# title: Method Registry
# author: Brendan Casey
# created: 2026-10-03
# inputs: none
# outputs: none; holds the registered methods in memory
# notes:
#   - Engines, selection rules, resamplers and metrics register
#     here by name, so adding a method is one new file in
#     1_code/methods/ with no harness change. Re-sourcing a method
#     file replaces its entry.
#   - Selection rules declare the engine capabilities they need;
#     validate_spec() (spec.R) checks them before any data is read.
# ---

# 1. Setup ----

## 1.1 Load packages ----
# Base R only.

## 1.2 The registry ----
# Created only if absent, so re-sourcing this file keeps
# registered methods
if (!exists(".sdm_registry", inherits = FALSE)) {
  .sdm_registry <- new.env(parent = emptyenv())
}

for (.kind in c("engine", "selection", "resampler", "metric")) {
  if (!exists(.kind, envir = .sdm_registry, inherits = FALSE)) {
    assign(.kind, list(), envir = .sdm_registry)
  }
}
rm(.kind)

# 2. Registering ----

## 2.1 method_kinds() ----

#' The Kinds of Method the Registry Holds
#'
#' @return A named character vector: kind to a readable label.
#'
#' @example # Example usage of the function
#' # method_kinds()
method_kinds <- function() {
  c(
    engine = "fitting engine",
    selection = "selection rule",
    resampler = "resampling scheme",
    metric = "metric"
  )
}

## 2.2 engine_capabilities() ----

#' The Capabilities an Engine Can Declare
#'
#' - `coefficients`: the engine returns a table of term, estimate
#'   and standard error. Needed by rules that average or read
#'   coefficients, and by a stage carried forward through them.
#' - `ic`: the engine scores a fit with AIC, AICc or BIC. Needed
#'   by every rule that ranks or weights candidates.
#' - `se`: the engine's predict() returns standard errors. Needed
#'   by inverse-variance averaging.
#' - `converged`: the engine reports whether a fit converged.
#'   Optional; a fit is assumed converged when it cannot say.
#'
#' @return A character vector.
#'
#' @example # Example usage of the function
#' # engine_capabilities()
engine_capabilities <- function() {
  c("coefficients", "ic", "se", "converged")
}

## 2.3 register_method() ----

#' Add One Method to the Registry
#'
#' @param kind Character. One of names(method_kinds()).
#' @param name Character. The name a spec uses.
#' @param value The method: a function, or for an engine a list.
#' @param description Character. One line on what it does.
#' @param requires Character vector of engine capabilities the
#'   method needs. Used by selection rules.
#' @return The name, invisibly.
#'
#' @example # Example usage of the function
#' # register_method("metric", "auc", metric_auc, "Area under ROC")
register_method <- function(
  kind,
  name,
  value,
  description,
  requires = character(0)
) {
  if (!kind %in% names(method_kinds())) {
    stop(
      "Unknown method kind `", kind, "`. Kinds: ",
      paste(names(method_kinds()), collapse = ", "),
      call. = FALSE
    )
  }

  if (!is.character(name) || length(name) != 1L || !nzchar(name)) {
    stop("A method name must be one non-empty string.", call. = FALSE)
  }

  if (!is.character(description) || length(description) != 1L) {
    stop(
      "Method `", name, "` needs a one-line description.",
      call. = FALSE
    )
  }

  unknown <- setdiff(requires, engine_capabilities())

  if (length(unknown) > 0) {
    stop(
      "Method `", name, "` requires unknown capabilities: ",
      paste(unknown, collapse = ", "), ". Known: ",
      paste(engine_capabilities(), collapse = ", "),
      call. = FALSE
    )
  }

  entries <- get(kind, envir = .sdm_registry)
  entries[[name]] <- list(
    name = name,
    value = value,
    description = description,
    requires = requires
  )
  assign(kind, entries, envir = .sdm_registry)

  invisible(name)
}

## 2.4 register_engine() ----

#' Register a Fitting Engine
#'
#' See 1_code/methods/README.md for the contract.
#'
#' @param engine A list with `name`, `description`,
#'   `capabilities`, `fit`, `predict`, and `coef`/`ic` where
#'   declared.
#' @return The engine name, invisibly.
#'
#' @example # Example usage of the function
#' # register_engine(engine_glm())
register_engine <- function(engine) {
  required <- c("name", "description", "capabilities", "fit",
                "predict")
  absent <- setdiff(required, names(engine))

  if (length(absent) > 0) {
    stop(
      "An engine needs ", paste(absent, collapse = ", "), ".",
      call. = FALSE
    )
  }

  if ("coefficients" %in% engine$capabilities &&
        !is.function(engine$coef)) {
    stop(
      "Engine `", engine$name, "` declares `coefficients` but has ",
      "no coef() function.",
      call. = FALSE
    )
  }

  if ("ic" %in% engine$capabilities && !is.function(engine$ic)) {
    stop(
      "Engine `", engine$name, "` declares `ic` but has no ic() ",
      "function.",
      call. = FALSE
    )
  }

  register_method(
    "engine", engine$name, engine, engine$description
  )
}

## 2.5 register_selection() ----

#' Register a Selection Rule
#'
#' Rules take `models`, `base`, `data`, `engine`, `family`,
#' `weights`, `offset`, `ic` and `control` and return
#' selection_result(). Further arguments are filled from the
#' stage field of the same name.
#'
#' @param name Character. The name a spec uses.
#' @param fn The rule function.
#' @param description Character. One line.
#' @param requires Character vector of engine capabilities.
#' @return The name, invisibly.
#'
#' @example # Example usage of the function
#' # register_selection("aic_best", select_aic_best,
#' #                    "Lowest-scoring candidate", "ic")
register_selection <- function(name, fn, description,
                               requires = character(0)) {
  core <- c("models", "base", "data", "engine", "family")
  absent <- setdiff(core, names(formals(fn)))

  if (length(absent) > 0) {
    stop(
      "Selection rule `", name, "` must take ",
      paste(absent, collapse = ", "), ".",
      call. = FALSE
    )
  }

  register_method("selection", name, fn, description, requires)
}

## 2.6 register_resampler() ----

#' Register a Resampling Scheme
#'
#' Resamplers take `frame`, `iterations`, `seed`, `context` and
#' any settings from `spec$resample`, and return one vector of
#' survey unit ids per iteration. Units left out are scored
#' out-of-bag.
#'
#' @param name Character. The name a spec's `resample$scheme`
#'   uses.
#' @param fn The resampler function.
#' @param description Character. One line.
#' @return The name, invisibly.
#'
#' @example # Example usage of the function
#' # register_resampler("spatial_block", resampler_spatial_block,
#' #                    "Bootstrap within spatial blocks")
register_resampler <- function(name, fn, description) {
  core <- c("frame", "iterations", "seed", "context")
  absent <- setdiff(core, names(formals(fn)))

  if (length(absent) > 0) {
    stop(
      "Resampler `", name, "` must take ",
      paste(absent, collapse = ", "), ".",
      call. = FALSE
    )
  }

  register_method("resampler", name, fn, description)
}

## 2.7 register_metric() ----

#' Register a Metric
#'
#' Metrics take response-scale `observed` and `predicted` and
#' return one number.
#'
#' @param name Character. The name metrics are reported under.
#' @param fn The metric function.
#' @param description Character. One line.
#' @return The name, invisibly.
#'
#' @example # Example usage of the function
#' # register_metric("rmse", metric_rmse, "Root mean squared error")
register_metric <- function(name, fn, description) {
  if (!all(c("observed", "predicted") %in% names(formals(fn)))) {
    stop(
      "Metric `", name, "` must take `observed` and `predicted`.",
      call. = FALSE
    )
  }

  register_method("metric", name, fn, description)
}

## 2.8 unregister_method() ----

#' Remove One Method from the Registry
#'
#' For tests and interactive development; a run never needs it.
#'
#' @param kind Character. One of names(method_kinds()).
#' @param name Character. The registered name.
#' @return The name, invisibly.
#'
#' @example # Example usage of the function
#' # unregister_method("metric", "my_test_metric")
unregister_method <- function(kind, name) {
  entries <- get(kind, envir = .sdm_registry)
  entries[[name]] <- NULL
  assign(kind, entries, envir = .sdm_registry)

  invisible(name)
}

# 3. Looking up ----

## 3.1 get_method() ----

#' Look Up One Registered Method
#'
#' @param kind Character. One of names(method_kinds()).
#' @param name Character. The registered name.
#' @param entry Logical. Return the whole entry (value,
#'   description, requires) rather than the method itself.
#' @return The method, or its entry.
#'
#' @example # Example usage of the function
#' # get_method("selection", "aic_average")
get_method <- function(kind, name, entry = FALSE) {
  entries <- get(kind, envir = .sdm_registry)

  if (!is.character(name) || length(name) != 1L ||
        !name %in% names(entries)) {
    stop(
      "Unknown ", method_kinds()[[kind]], " `",
      paste(format(name), collapse = " "), "`. Registered: ",
      if (length(entries) == 0) {
        "none - has 1_code/methods/ been loaded?"
      } else {
        paste(names(entries), collapse = ", ")
      },
      call. = FALSE
    )
  }

  if (entry) entries[[name]] else entries[[name]]$value
}

## 3.2 registered_names() ----

#' Names Registered for One Kind of Method
#'
#' @param kind Character. One of names(method_kinds()).
#' @return A character vector.
#'
#' @example # Example usage of the function
#' # registered_names("engine")
registered_names <- function(kind) {
  names(get(kind, envir = .sdm_registry))
}

## 3.3 list_methods() ----

#' Show Every Registered Method
#'
#' @param kind Character, or NULL for every kind.
#' @return A data frame of kind, name, requires and description,
#'   printed and returned invisibly.
#'
#' @example # Example usage of the function
#' # list_methods()
#' # list_methods("engine")
list_methods <- function(kind = NULL) {
  kinds <- if (is.null(kind)) names(method_kinds()) else kind

  rows <- lapply(kinds, function(one) {
    entries <- get(one, envir = .sdm_registry)

    if (length(entries) == 0) {
      return(NULL)
    }

    data.frame(
      kind = one,
      name = names(entries),
      requires = vapply(
        entries,
        function(e) {
          capabilities <- if (one == "engine") {
            e$value$capabilities
          } else {
            e$requires
          }
          paste(capabilities, collapse = ", ")
        },
        character(1)
      ),
      description = vapply(
        entries, `[[`, character(1), "description"
      ),
      stringsAsFactors = FALSE,
      row.names = NULL
    )
  })

  table <- do.call(rbind, rows)
  print(table, row.names = FALSE, right = FALSE)

  invisible(table)
}

# End of script ----
