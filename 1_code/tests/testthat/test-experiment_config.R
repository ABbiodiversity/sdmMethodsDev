# ---
# title: Tests - Experiment-Local Configuration
# author: Brendan Casey
# created: 2026-10-12
# inputs: the published test dataset (`data_dir`), for the
#   experiment_config() checks; those are skipped without it
# outputs: none; testthat results
# notes:
#   - What an experiment changes from its own folder: hooks,
#     species.csv, spec changes (modify_*()), block cut points,
#     metric direction, and the problems experiment_config()
#     reports before anything is fitted.
#   - Hook files are written under tempfile() and every method
#     they register is removed again.
#   - Run through 1_code/tests/run_tests.R, which loads the
#     framework and sets `data_dir`.
# ---

# A hook file holding the given lines
hook_file <- function(lines, name = "hook.R") {
  dir <- tempfile("hooks_")
  dir.create(dir)
  path <- file.path(dir, name)
  writeLines(lines, path)
  path
}

test_that("a hook registers a method and records its file", {
  path <- hook_file(c(
    "register_metric('test_hook_mae',",
    "  function(observed, predicted) {",
    "    mean(abs(observed - predicted))",
    "  },",
    "  'Test only', direction = 'lower')"
  ))
  on.exit({
    unregister_method("metric", "test_hook_mae")
    options(sdm.hook_files = NULL)
  })

  load_hooks(dirname(path), environment())

  expect_true("test_hook_mae" %in% registered_names("metric"))
  expect_equal(getOption("sdm.hook_files"),
               normalizePath(path, winslash = "/"))
  # The registered direction wins over the built-in table
  expect_equal(better_direction("oob_test_hook_mae"), "lower")
  expect_equal(better_direction(c("oob_auc", "oob_rmse")),
               c("higher", "lower"))

  # Re-sourcing the same file re-registers its own name
  expect_silent(load_hooks(path, environment()))
})

test_that("a hook may not replace a built-in or another hook's", {
  clash <- hook_file(
    "register_engine(get_engine('glm'))"
  )
  on.exit(options(sdm.hook_files = NULL))

  expect_error(load_hooks(clash, environment()), "is built in")

  first <- hook_file(
    "register_metric('test_hook_twice',
      function(observed, predicted) 1, 'Test only',
      direction = 'none')", "first.R"
  )
  second <- hook_file(
    "register_metric('test_hook_twice',
      function(observed, predicted) 2, 'Test only',
      direction = 'none')", "second.R"
  )
  on.exit(unregister_method("metric", "test_hook_twice"), add = TRUE)

  load_hooks(first, environment())
  expect_error(load_hooks(second, environment()),
               "already registered")
})

test_that("a hook metric without a direction warns", {
  path <- hook_file(
    "register_metric('test_hook_nodir',
      function(observed, predicted) 1, 'Test only')"
  )
  on.exit({
    unregister_method("metric", "test_hook_nodir")
    options(sdm.hook_files = NULL)
  })

  expect_warning(load_hooks(path, environment()), "no `direction`")
})

test_that("a missing hook file is an error", {
  expect_error(load_hooks("no/such/hook.R"), "not found")
})

test_that("species.csv is read, and its mistakes are caught", {
  path <- tempfile(fileext = ".csv")
  writeLines(c("taxon,species,note", "lichen,Physcia.adscendens,a",
               "mite,Oppiella.nova,"), path)

  expect_equal(
    read_species_file(path),
    c(lichen = "Physcia.adscendens", mite = "Oppiella.nova")
  )

  expect_error(read_species_file("no/such/species.csv"), "not found")

  writeLines(c("taxon,name", "lichen,Physcia.adscendens"), path)
  expect_error(read_species_file(path), "no `species` column")

  writeLines(c("taxon,species", "lichen,a", "lichen,a"), path)
  expect_error(read_species_file(path), "repeats")

  writeLines(c("taxon,species", "lichen,"), path)
  expect_error(read_species_file(path), "blank")
})

test_that("the template lists every species, with empty notes", {
  template <- file.path(
    getOption("sdm.project_root", "."), "1_code", "experiments",
    "_template", "species.csv"
  )
  rows <- data.table::fread(template, colClasses = "character",
                            na.strings = "")

  expect_equal(names(rows), c("taxon", "species", "note"))
  expect_true(all(is.na(rows$note)))
  expect_false(anyDuplicated(paste(rows$taxon, rows$species)) > 0)
  expect_length(read_species_file(template), nrow(rows))
})

test_that("modify_stage() changes, records and validates", {
  spec <- modify_stage(lichen_spec(), "habitat", min_detections = 10L)
  habitat <- spec$stages[[2]]

  expect_equal(habitat$min_detections, 10L)
  expect_match(
    spec$models_overridden, "habitat: min_detections = 10L",
    fixed = TRUE, all = FALSE
  )
  expect_equal(spec$v2_coverage$habitat$status, "not reproduced")

  # A second change to the same stage keeps the first in the note
  spec <- modify_stage(spec, "habitat", ic = "AIC")
  expect_match(spec$v2_coverage$habitat$note, "min_detections")
  expect_match(spec$v2_coverage$habitat$note, "ic")

  # NULL removes a field
  spec <- modify_stage(spec, "habitat", min_detections = NULL)
  expect_null(spec$stages[[2]]$min_detections)

  expect_error(modify_stage(lichen_spec(), "habitt", ic = "AIC"),
               "no stage `habitt`")
  expect_error(modify_stage(lichen_spec(), "habitat", min_detect = 1),
               "unknown field")
  expect_error(
    modify_stage(lichen_spec(), "habitat", engine = "nope"),
    "Unknown fitting engine"
  )
  expect_error(modify_stage(lichen_spec(), "habitat", 10L), "named")
})

test_that("modify_region() and modify_resample() change and record", {
  spec <- modify_region(lichen_spec(), "north",
                        filter = ~ nr == "Boreal")
  expect_equal(spec$regions$north$filter, ~ nr == "Boreal")
  expect_match(spec$models_overridden, "region north: filter",
               all = FALSE)
  expect_error(modify_region(lichen_spec(), "east", grid = "veg"),
               "no region `east`")

  # Switching scheme drops the old settings but keeps the scope
  spec <- modify_resample(
    lichen_spec(), scheme = "spatial_cv", replace = TRUE,
    lat_breaks = c(48, 52, 56, 61)
  )
  expect_equal(
    spec$resample,
    list(scope = "province", scheme = "spatial_cv",
         lat_breaks = c(48, 52, 56, 61))
  )
  expect_equal(spec$v2_coverage$resampling$status, "not reproduced")

  # Without replace, the old scheme's settings stay and are refused
  expect_error(
    modify_resample(bird_spec(), scheme = "spatial_cv"),
    "unknown field"
  )
})

test_that("drop_candidates() and strip_terms() reduce a set", {
  models <- c(". ~ .", ". ~ . + a", ". ~ . + a + b",
              ". ~ . + b + I(b^2)", ". ~ . + a:b + c")

  # Dropping removes every candidate that names the term
  expect_equal(drop_candidates(models, "b"), c(". ~ .", ". ~ . + a"))

  # Stripping keeps each candidate, less the term, and merges
  # the duplicates it makes
  expect_equal(
    strip_terms(models, "b"),
    c(". ~ .", ". ~ . + a", ". ~ . + c")
  )

  # Staged sets keep their groups
  staged <- list(c(". ~ . + a", ". ~ . + b"), ". ~ . + c")
  expect_equal(drop_candidates(staged, "b"),
               list(". ~ . + a", ". ~ . + c"))

  # A v2 set by name: no spatial term survives, the null stays
  spatial <- c("Easting", "Northing", "Easting2", "Northing2",
               "EastingNorthing")
  reduced <- drop_candidates("climate_plant_v2_full", spatial)
  expect_false(any(grepl("Easting|Northing", reduced)))
  expect_true(". ~ ." %in% reduced)
  expect_lt(length(reduced), length(get_model_set(
    "climate_plant_v2_full"
  )))
})

test_that("block cut points can be set and default to v2's", {
  long <- c(-120, -118, -114, -110)
  lat <- c(49, 52, 55, 58)

  expect_identical(
    spatial_blocks(long, lat),
    spatial_blocks(long, lat, v2_block_breaks()$long,
                   v2_block_breaks()$lat)
  )
  # One longitude band: the four units fall in one column of
  # latitude blocks
  expect_length(
    unique(spatial_blocks(long, lat, long_breaks = c(-121, -109))),
    4L
  )
  expect_length(
    unique(spatial_blocks(long, lat, long_breaks = c(-121, -109),
                          lat_breaks = c(48, 61))),
    1L
  )
})

# The checks below read the dataset's lookups
skip_if_not(dir.exists(data_dir), "No test dataset")

test_that("misspelt species are caught with a suggestion", {
  problems <- check_species_names(
    c(lichen = "Physcia.adscendns", nothing = "x"), data_dir
  )

  expect_match(problems, "Unknown taxon slug.*nothing", all = FALSE)
  expect_match(problems, "did you mean Physcia.adscendens",
               all = FALSE, fixed = TRUE)
  expect_length(
    check_species_names(c(lichen = "Physcia.adscendens"), data_dir),
    0L
  )
})

test_that("experiment_config() lists every problem at once", {
  species <- tempfile(fileext = ".csv")
  writeLines(c("taxon,species", "lichen,Physcia.adscendns"), species)

  specs <- list(lichen = modify_stage(
    lichen_spec(), "habitat", min_detections = 5L
  ))
  specs$lichen$stages[[2]]$engine <- "no_such_engine"

  err <- tryCatch(
    experiment_config(
      "exp_999_test", taxa = "lichen", specs = specs,
      species = species, n_bootstraps = 2,
      regions = "east", metrics = "no_such_metric",
      compare_metrics = "oob_nothing",
      data_dir = data_dir
    ),
    error = conditionMessage
  )

  expect_match(err, "did you mean Physcia.adscendens", fixed = TRUE)
  expect_match(err, "has no region(s) east", fixed = TRUE)
  expect_match(err, "Unknown metric(s): no_such_metric", fixed = TRUE)
  expect_match(err, "Unknown compare_metrics: oob_nothing",
               fixed = TRUE)
  expect_match(err, "Unknown fitting engine `no_such_engine`",
               fixed = TRUE)
})

test_that("every species in the template can be fitted", {
  template <- file.path(
    getOption("sdm.project_root", "."), "1_code", "experiments",
    "_template", "species.csv"
  )

  expect_length(
    check_species_names(read_species_file(template), data_dir), 0L
  )
  # Every row is fitted by some run, and the unedited template
  # configures every run
  config <- experiment_config(
    "exp_999_test", species = template, n_bootstraps = 2,
    data_dir = data_dir
  )
  expect_setequal(config$taxa, names(standard_specs()))
})

test_that("experiment_config() catches a missing species file", {
  expect_error(
    experiment_config("exp_999_test", taxa = "lichen",
                      species = "no/such/species.csv",
                      n_bootstraps = 2, data_dir = data_dir),
    "Species file not found"
  )
})

test_that("experiment_config() catches a misspelt covariate", {
  err <- tryCatch(
    experiment_config(
      "exp_999_test", taxa = "lichen", n_bootstraps = 2,
      species = c(lichen = "Physcia.adscendens"),
      stage_models = list(
        climate = extend_models("climate_plant_v2_full", "bio155")
      ),
      data_dir = data_dir
    ),
    error = conditionMessage
  )

  expect_match(err, "covariate `bio155` is not in the dataset",
               fixed = TRUE)
  expect_match(err, "did you mean bio15", fixed = TRUE)
})

test_that("without `taxa`, the species list sets the runs", {
  config <- experiment_config(
    "exp_999_test", n_bootstraps = 2,
    species = c(lichen = "Physcia.adscendens",
                mammal = "Moose_Summer"),
    data_dir = data_dir
  )

  # Moose_Summer is in the summer queue only
  expect_equal(config$taxa, c("lichen", "mammal_summer"))
  expect_equal(names(config$specs), config$taxa)

  # Given `taxa` wins, as before
  config <- experiment_config(
    "exp_999_test", taxa = "lichen", n_bootstraps = 2,
    species = c(lichen = "Physcia.adscendens"), data_dir = data_dir
  )
  expect_equal(config$taxa, "lichen")
})

test_that("a listed species no run fits is reported", {
  queue <- species_catalogue(data_dir)
  mammals <- queue[queue$taxon == "mammal", ]
  # A mammal never in a modelled tier, if the queue has one
  never <- setdiff(mammals$species,
                   mammals$species[mammals$tier == "modelled"])
  skip_if(length(never) == 0, "Every mammal is modelled somewhere")

  expect_error(
    experiment_config(
      "exp_999_test", n_bootstraps = 2,
      species = c(lichen = "Physcia.adscendens", mammal = never[1]),
      data_dir = data_dir
    ),
    paste("No run fits mammal", never[1]), fixed = TRUE
  )
})

test_that("a valid configuration passes, with today's defaults", {
  config <- experiment_config(
    "exp_999_test", taxa = c("lichen", "bird"), n_bootstraps = 2,
    species = c(lichen = "Physcia.adscendens", bird = "AMRO"),
    data_dir = data_dir
  )

  expect_null(config$regions)
  expect_null(config$metrics)
  expect_equal(record_config(config)$compare_metrics,
               default_compare_metrics())
  expect_equal(record_config(config)$species_file, "inline")
})
