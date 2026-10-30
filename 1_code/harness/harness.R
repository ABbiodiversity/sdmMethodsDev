# ---
# title: Load the Framework
# author: Brendan Casey
# created: 2026-09-09
# inputs:
#   - the files in 1_code/harness/
#   - the files in 1_code/methods/
#   - the files in 1_code/modules/
# outputs: none; defines the framework in the calling environment
# notes:
#   - Single entry point: experiments source this file and call
#     load_framework().
#   - Load order: harness/ (including the method registry),
#     methods/ (each file registers itself), modules/, any
#     experiments/_shared/ files, then the experiment's own
#     hooks/. Files or folders starting with "_" are shared
#     helpers and load first.
# ---

# 1. Setup ----

## 1.1 Load packages ----
library(data.table) # used throughout (version: 1.16.4)

# 2. load_harness() ----

#' Source Every Harness File
#'
#' @param harness_dir Character. Path to 1_code/harness.
#' @param envir Environment to source into.
#' @return Character vector of the files sourced, invisibly.
#'
#' @example # Example usage of the function
#' # load_harness("1_code/harness")
load_harness <- function(
  harness_dir = "1_code/harness",
  envir = parent.frame()
) {
  # The registry and cache come first: method files register into
  # the one, and loaders read through the other. run_model.R is
  # last because it calls most of the rest.
  files <- c(
    "registry.R",
    "cache.R",
    "data_source.R",
    "spec.R",
    "data_load.R",
    "covariate_sets.R",
    "species.R",
    "model_sets.R",
    "resample.R",
    "engines.R",
    "selection.R",
    "eval_metrics.R",
    "predict_grid.R",
    "predict_spatial.R",
    "result.R",
    "run_record.R",
    "run_model.R",
    "summarise.R",
    "compare.R",
    "experiment.R",
    "new_experiment.R"
  )

  source_all(file.path(harness_dir, files), envir)
}

# 3. load_methods() ----

#' Source and Register Every Method
#'
#' @param methods_dir Character. Path to 1_code/methods.
#' @param envir Environment to source into.
#' @return Character vector of the files sourced, invisibly.
#'
#' @example # Example usage of the function
#' # load_methods("1_code/methods")
load_methods <- function(
  methods_dir = "1_code/methods",
  envir = parent.frame()
) {
  kinds <- c("engines", "selection", "resampling", "metrics")

  paths <- unlist(lapply(kinds, function(kind) {
    files <- sort(list.files(
      file.path(methods_dir, kind), pattern = "\\.R$",
      full.names = TRUE
    ))
    shared <- startsWith(basename(files), "_")

    c(files[shared], files[!shared])
  }))

  source_all(paths, envir)
}

# 4. load_modules() ----

#' Source Every Taxon Module
#'
#' @param modules_dir Character. Path to 1_code/modules.
#' @param envir Environment to source into.
#' @return Character vector of the files sourced, invisibly.
#'
#' @example # Example usage of the function
#' # load_modules("1_code/modules")
load_modules <- function(
  modules_dir = "1_code/modules",
  envir = parent.frame()
) {
  folders <- sort(list.dirs(
    modules_dir, recursive = FALSE, full.names = TRUE
  ))
  shared <- startsWith(basename(folders), "_")

  paths <- unlist(lapply(
    c(folders[shared], folders[!shared]),
    function(folder) {
      sort(list.files(folder, pattern = "\\.R$", full.names = TRUE))
    }
  ))

  source_all(paths, envir)
}

# 5. load_framework() ----

#' Load the Harness, Methods, Taxon Modules and an Experiment's
#' Hooks
#'
#' What an experiment calls first. Everything is sourced into one
#' environment, the caller's by default.
#'
#' @param project_root Character. The repository root.
#' @param envir Environment to source into.
#' @param hooks Character or NULL. The experiment's `hooks/`
#'   folder, or a vector of `.R` files; see load_hooks().
#' @return The project root, invisibly.
#'
#' @example # Example usage of the function
#' # source("1_code/harness/harness.R")
#' # load_framework(hooks = "1_code/experiments/exp_003_x/hooks")
#' # list_methods()
load_framework <- function(
  project_root = ".",
  envir = parent.frame(),
  hooks = NULL
) {
  project_root <- normalizePath(project_root, winslash = "/")
  code_dir <- file.path(project_root, "1_code")

  load_harness(file.path(code_dir, "harness"), envir)
  load_methods(file.path(code_dir, "methods"), envir)
  load_modules(file.path(code_dir, "modules"), envir)

  # Optional; an absent folder sources nothing
  shared <- sort(list.files(
    file.path(code_dir, "experiments", "_shared"),
    pattern = "\\.R$", full.names = TRUE
  ))
  source_all(shared, envir)

  # Parallel workers load the framework from here themselves
  options(sdm.project_root = project_root)

  load_hooks(hooks, envir)

  invisible(project_root)
}

# 6. load_hooks() ----

#' Source an Experiment's Own Methods and Functions
#'
#' Hooks register methods with the register_*() functions, or
#' define functions a spec field names. A hook may not replace a
#' method already registered: that would change the name's meaning
#' for everything else in the session. Re-sourcing the same file
#' is allowed. The files are kept in `sdm.hook_files`, so parallel
#' workers source them too and the run record lists them.
#'
#' @param hooks Character or NULL. A folder (its `.R` files, in
#'   file-name order) or a vector of `.R` files.
#' @param envir Environment to source into.
#' @return The hook files, invisibly.
#'
#' @example # Example usage of the function
#' # load_hooks("1_code/experiments/exp_003_x/hooks")
load_hooks <- function(hooks, envir = parent.frame()) {
  if (is.null(hooks) || length(hooks) == 0) {
    options(sdm.hook_files = NULL)
    return(invisible(character(0)))
  }

  files <- unlist(lapply(hooks, function(one) {
    if (dir.exists(one)) {
      sort(list.files(one, pattern = "\\.R$", full.names = TRUE))
    } else {
      one
    }
  }))

  absent <- files[!file.exists(files)]

  if (length(absent) > 0) {
    stop(
      "Hook file(s) not found:\n  ",
      paste(absent, collapse = "\n  "),
      call. = FALSE
    )
  }

  files <- normalizePath(files, winslash = "/")

  # register_method() reads this to refuse a clash; see registry.R
  for (path in files) {
    options(sdm.hook_loading = path)
    tryCatch(
      source(path, local = envir),
      error = function(e) {
        message <- conditionMessage(e)

        # A clash already names the hook
        if (!startsWith(message, "Hook ")) {
          message <- paste0("Hook ", basename(path), " failed: ",
                            message)
        }

        stop(message, call. = FALSE)
      },
      finally = options(sdm.hook_loading = NULL)
    )
  }

  options(sdm.hook_files = files)

  invisible(files)
}

# 7. source_all() ----

#' Source Files in Order, Failing Clearly on a Missing One
#'
#' @param paths Character vector of files.
#' @param envir Environment to source into.
#' @return The paths, invisibly.
#'
#' @example # Example usage of the function
#' # source_all(c("a.R", "b.R"), globalenv())
source_all <- function(paths, envir) {
  absent <- paths[!file.exists(paths)]

  if (length(absent) > 0) {
    stop(
      "Framework files not found:\n  ",
      paste(absent, collapse = "\n  "),
      call. = FALSE
    )
  }

  for (path in paths) {
    source(path, local = envir)
  }

  invisible(paths)
}

# End of script ----
