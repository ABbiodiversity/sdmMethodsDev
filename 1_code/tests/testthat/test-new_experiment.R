# new_experiment() numbers an experiment from every folder that
# could hold one, and scaffolds all three of its folders or none.
# Each test builds a throwaway repository, so the real one is
# never touched.

# A minimal repository: the real template, and an exp_ folder in
# each of the given roots
fake_repo <- function(existing = list()) {
  root <- tempfile("repo_")
  template <- file.path(root, "1_code", "experiments", "_template")
  dir.create(template, recursive = TRUE)
  # testthat runs from the tests folder; the framework records
  # the repository root
  source_template <- file.path(
    getOption("sdm.project_root", "."), "1_code", "experiments",
    "_template"
  )
  file.copy(list.files(source_template, full.names = TRUE), template)

  for (where in names(existing)) {
    dir.create(file.path(root, where, existing[[where]]),
               recursive = TRUE)
  }

  root
}

test_that("a description becomes a snake_case slug", {
  expect_equal(experiment_slug("Covariate scale"), "covariate_scale")
  expect_equal(experiment_slug("  SoilGrids 0-5 cm! "),
               "soilgrids_0_5_cm")
  expect_error(experiment_slug(""), "no letters or digits")
  expect_error(experiment_slug("---"), "no letters or digits")
  expect_error(experiment_slug(NA_character_), "single string")
  expect_error(experiment_slug(c("a", "b")), "single string")
  expect_error(experiment_slug("exp_004_scale"), "exp_NNN_ prefix")
})

test_that("the number is one past the highest in any folder", {
  expect_equal(next_experiment_number(fake_repo()), 0L)

  # A pipeline-only folder, as a removed experiment leaves, still
  # holds its number
  root <- fake_repo(list(
    "1_code/experiments" = "exp_001_xgboost",
    "2_pipeline" = "exp_004_stale",
    "3_output" = "exp_002_soilgrids",
    "2_pipeline/_setup" = "exp_009_nested"
  ))
  expect_equal(next_experiment_number(root), 5L)
})

test_that("new_experiment() scaffolds all three folders", {
  root <- fake_repo(list("2_pipeline" = "exp_002_old"))
  out <- expect_output(
    new_experiment("Covariate scale", author = "Test Author",
                   project_root = root, open = FALSE),
    "Created exp_003_covariate_scale"
  )

  expect_equal(out$id, "exp_003_covariate_scale")

  code <- file.path(root, "1_code/experiments", out$id)
  expected <- c(
    file.path(code, c("run.R", "README.md")),
    file.path(root, "2_pipeline", out$id,
              c(".gitkeep", "logs/.gitkeep")),
    file.path(root, "3_output", out$id,
              c("figures/.gitkeep", "tables/.gitkeep", "report.md"))
  )
  expect_true(all(file.exists(expected)))

  run <- readLines(file.path(code, "run.R"))
  readme <- readLines(file.path(code, "README.md"))
  text <- c(run, readme)

  expect_false(any(grepl("exp_NNN|\\[Your Name\\]|\\[YYYY-MM-DD\\]",
                         text)))
  expect_true(any(grepl(
    'id = "exp_003_covariate_scale"', run, fixed = TRUE
  )))
  expect_true(any(grepl("Experiment 003 - Covariate Scale", run,
                        fixed = TRUE)))
  expect_true(any(grepl("author: Test Author", run, fixed = TRUE)))
  expect_false(any(grepl("new_experiment", run, fixed = TRUE)))
  expect_equal(readme[1], "# exp_003_covariate_scale")
  expect_silent(parse(file.path(code, "run.R")))
})

test_that("each call takes a new number; a failure leaves none", {
  root <- fake_repo(list("2_pipeline" = "exp_000_x"))

  # The same description twice: the second gets the next number
  scaffold <- function() {
    expect_output(
      new_experiment("scale", author = "a", project_root = root,
                     open = FALSE),
      "Created"
    )
  }
  scaffold()
  second <- scaffold()
  expect_equal(second$id, "exp_002_scale")

  # A missing template stops the call before any folder is made
  expect_error(
    new_experiment("other", author = "a", project_root = root,
                   template_dir = file.path(root, "missing"),
                   open = FALSE),
    "Template folder not found"
  )
  expect_equal(next_experiment_number(root), 3L)
})

test_that("a dry run writes nothing", {
  root <- fake_repo()
  before <- list.files(root, recursive = TRUE, include.dirs = TRUE)

  expect_output(
    new_experiment("scale", project_root = root, dry_run = TRUE),
    "dry run"
  )

  expect_equal(
    list.files(root, recursive = TRUE, include.dirs = TRUE), before
  )
})
