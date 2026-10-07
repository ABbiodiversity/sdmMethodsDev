# ---
# title: Scaffold a New Experiment
# author: Brendan Casey
# created: 2026-10-06
# inputs:
#   - 1_code/experiments/_template/, the run.R and README.md every
#     experiment starts from
#   - the exp_NNN_* folders already in 1_code/experiments/,
#     2_pipeline/ and 3_output/, which set the next number
# outputs:
#   - 1_code/experiments/<id>/: run.R and README.md, from the
#     template with the id, title, author and date filled in
#   - 2_pipeline/<id>/ and its logs/, for the gitignored
#     intermediates
#   - 3_output/<id>/: figures/, tables/ and a stub report.md
# notes:
#   - Usage:
#       source("1_code/harness/new_experiment.R")
#       new_experiment("covariate scale")
#   - The number is one past the highest exp_NNN in any of the
#     three folders, and gaps are not reused, so a new experiment
#     never shares stores with a removed one.
#   - Base R only, so it runs without load_framework(). Empty
#     folders get a .gitkeep so the structure is committed.
# ---

# 1. Setup ----
# Base R only; no packages to load.

# 2. experiment_slug() ----

#' Turn an Experiment Description into its Folder-Name Slug
#'
#' @param description Character. A short description, e.g.
#'   "Covariate scale".
#' @return Character. The snake_case slug, e.g. "covariate_scale".
#'
#' @example # Example usage of the function
#' # experiment_slug("SoilGrids 0-5 cm")
#' # #> "soilgrids_0_5_cm"
experiment_slug <- function(description) {
  if (!is.character(description) || length(description) != 1L ||
        is.na(description)) {
    stop("description must be a single string.", call. = FALSE)
  }

  slug <- tolower(trimws(description))
  slug <- gsub("[^a-z0-9]+", "_", slug)
  slug <- gsub("^_+|_+$", "", slug)

  if (!nzchar(slug)) {
    stop(
      "description has no letters or digits to name a folder.",
      call. = FALSE
    )
  }

  # The number is assigned here, so a user-supplied one would be
  # doubled or contradicted
  if (grepl("^exp_[0-9]{3}_", slug)) {
    stop(
      "Give the description without the exp_NNN_ prefix; ",
      "the number is assigned for you.",
      call. = FALSE
    )
  }

  slug
}

# 3. next_experiment_number() ----

#' Find the Next Free Experiment Number
#'
#' @param project_root Character. The repository root.
#' @return Integer. One past the highest exp_NNN folder in
#'   1_code/experiments/, 2_pipeline/ or 3_output/; 0 if there is
#'   none.
#'
#' @example # Example usage of the function
#' # next_experiment_number(".")
#' # #> 3
next_experiment_number <- function(project_root = ".") {
  roots <- file.path(
    project_root, c("1_code/experiments", "2_pipeline", "3_output")
  )

  folders <- unlist(lapply(roots[dir.exists(roots)], function(root) {
    list.dirs(root, recursive = FALSE, full.names = FALSE)
  }))
  folders <- folders[grepl("^exp_[0-9]{3}_", folders)]

  if (length(folders) == 0) {
    return(0L)
  }

  number <- max(as.integer(substr(folders, 5, 7))) + 1L

  if (number > 999L) {
    stop(
      "Experiment numbers are three digits; 999 is taken.",
      call. = FALSE
    )
  }

  number
}

# 4. new_experiment() ----

#' Scaffold a New Experiment's Folders
#'
#' Creates 1_code/experiments/<id>/ from the template,
#' 2_pipeline/<id>/ with logs/, and 3_output/<id>/ with figures/,
#' tables/ and a stub report.md, where <id> is
#' exp_<NNN>_<slug> and NNN is the next free number.
#'
#' @param description Character. A short description of the
#'   question; becomes the id's slug and the run.R title.
#' @param author Character or NULL. For the run.R header; NULL
#'   reads `git config user.name`, then the system user.
#' @param project_root Character. The repository root.
#' @param template_dir Character or NULL. The template folder;
#'   NULL for 1_code/experiments/_template.
#' @param dry_run Logical. TRUE reports the id and paths without
#'   writing anything.
#' @param open Logical. Open the new run.R for editing.
#' @return A list, invisibly: `id`, `number`, `code_dir`,
#'   `pipeline_dir` and `out_dir`.
#'
#' @example # Example usage of the function
#' # source("1_code/harness/new_experiment.R")
#' # new_experiment("covariate scale", dry_run = TRUE)
#' # #> exp_003_covariate_scale (dry run; nothing written)
new_experiment <- function(
  description,
  author = NULL,
  project_root = getOption("sdm.project_root", "."),
  template_dir = NULL,
  dry_run = FALSE,
  open = interactive()
) {
  # Step 1: The id and where it goes
  slug <- experiment_slug(description)
  number <- next_experiment_number(project_root)
  id <- sprintf("exp_%03d_%s", number, slug)

  template_dir <- template_dir %||%
    file.path(project_root, "1_code", "experiments", "_template")
  dirs <- c(
    code_dir = file.path(project_root, "1_code", "experiments", id),
    pipeline_dir = file.path(project_root, "2_pipeline", id),
    out_dir = file.path(project_root, "3_output", id)
  )
  out <- c(list(id = id, number = number), as.list(dirs))

  # Step 2: Check everything before writing anything
  if (!dir.exists(template_dir)) {
    stop("Template folder not found: ", template_dir, call. = FALSE)
  }

  taken <- dirs[dir.exists(dirs)]

  if (length(taken) > 0) {
    stop(
      "Already exists, so ", id, " cannot be created:\n  ",
      paste(taken, collapse = "\n  "),
      call. = FALSE
    )
  }

  if (dry_run) {
    cat(id, " (dry run; nothing written)\n  ",
        paste(dirs, collapse = "\n  "), "\n", sep = "")
    return(invisible(out))
  }

  author <- author %||% git_user_name(project_root)

  # Step 3: Remove what this call made if a later step fails, so
  # a half-built experiment does not hold the number
  created <- character(0)
  done <- FALSE
  on.exit(
    if (!done) unlink(created, recursive = TRUE),
    add = TRUE
  )

  for (dir in dirs) {
    dir.create(dir, recursive = TRUE)
    created <- c(created, dir)
  }

  # Step 4: The code, from the template with its placeholders
  # filled in
  fill_template(
    template_dir, dirs[["code_dir"]],
    id = id, number = number, slug = slug, author = author
  )

  # Step 5: The pipeline and output structure
  for (sub in c(
    dirs[["pipeline_dir"]],
    file.path(dirs[["pipeline_dir"]], "logs"),
    file.path(dirs[["out_dir"]], "figures"),
    file.path(dirs[["out_dir"]], "tables")
  )) {
    dir.create(sub, recursive = TRUE, showWarnings = FALSE)
    file.create(file.path(sub, ".gitkeep"))
  }

  writeLines(
    c(
      paste("#", id),
      "",
      "_Not yet run._ The question and design are in",
      paste0("`1_code/experiments/", id, "/README.md`."),
      "Write the result here, or replace this file with a report",
      "step; `run_record.md` is written beside it on every run."
    ),
    file.path(dirs[["out_dir"]], "report.md")
  )

  done <- TRUE

  cat(
    "Created ", id, "\n  ",
    paste(dirs, collapse = "\n  "), "\n",
    "Next:\n",
    "  1. State the question and design in its README.md.\n",
    "  2. Set the one change in its run.R.\n",
    "  3. Run it at 5 draws to check it works, then at 100.\n",
    sep = ""
  )

  if (open) {
    utils::file.edit(file.path(dirs[["code_dir"]], "run.R"))
  }

  invisible(out)
}

## 4.1 fill_template() ----

#' Copy the Template, Filling its Placeholders
#'
#' Also drops the template run.R's note on starting an
#' experiment.
#'
#' @param template_dir Character. The template folder.
#' @param code_dir Character. The new experiment's code folder.
#' @param id,slug,author Character. The experiment's values.
#' @param number Integer. The experiment's number.
#' @return The files written, invisibly.
#'
#' @example # Example usage of the function
#' # fill_template("1_code/experiments/_template",
#' #               "1_code/experiments/exp_003_covariate_scale",
#' #               id = "exp_003_covariate_scale", number = 3L,
#' #               slug = "covariate_scale", author = "B. Casey")
fill_template <- function(template_dir, code_dir, id, number, slug,
                          author) {
  # "covariate_scale" -> "Covariate Scale"
  words <- strsplit(slug, "_", fixed = TRUE)[[1]]
  title <- paste0(
    "Experiment ", sprintf("%03d", number), " - ",
    paste0(toupper(substr(words, 1, 1)), substring(words, 2),
           collapse = " ")
  )

  placeholders <- c(
    "exp_NNN_short_description" = id,
    "Experiment NNN - [Short Description]" = title,
    "[Your Name]" = author,
    "[YYYY-MM-DD]" = format(Sys.Date(), "%Y-%m-%d")
  )

  files <- list.files(template_dir, recursive = TRUE)

  for (file in files) {
    text <- readLines(file.path(template_dir, file), warn = FALSE)

    for (key in names(placeholders)) {
      text <- gsub(key, placeholders[[key]], text, fixed = TRUE)
    }

    # The note bullet and its continuation lines
    start <- grep("^#   - Start an experiment with new_experiment",
                  text)

    if (length(start) == 1L) {
      end <- start
      while (end < length(text) && grepl("^#     ", text[end + 1])) {
        end <- end + 1L
      }
      text <- text[-(start:end)]
    }

    target <- file.path(code_dir, file)
    dir.create(dirname(target), recursive = TRUE,
               showWarnings = FALSE)
    writeLines(text, target)
  }

  invisible(file.path(code_dir, files))
}

## 4.2 git_user_name() ----

#' The Author for a New Script's Header
#'
#' @param project_root Character. The repository root.
#' @return Character. `git config user.name`, or the system user
#'   when git is unavailable or has no name set.
#'
#' @example # Example usage of the function
#' # git_user_name(".")
git_user_name <- function(project_root = ".") {
  name <- tryCatch(
    suppressWarnings(system2(
      "git", c("-C", shQuote(project_root), "config", "user.name"),
      stdout = TRUE, stderr = FALSE
    )),
    error = function(e) character(0)
  )

  if (length(name) == 1L && nzchar(trimws(name))) {
    trimws(name)
  } else {
    Sys.info()[["user"]]
  }
}

## 4.3 %||% ----
# Defined here only when missing, so the file can be sourced on
# its own; R >= 4.4 and the harness both provide it.
if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
}

# End of script ----
