# The v2 specs are valid, and validate_spec() catches the mistakes
# a user is likely to make.

test_that("every standard spec validates", {
  for (key in names(standard_specs())) {
    expect_silent(validate_spec(standard_specs()[[key]]))
  }
  expect_silent(validate_spec(
    mammal_spec(climate_source = "fitted", season = "summer")
  ))
})

test_that("a misspelt field is reported, not ignored", {
  spec <- bird_spec()
  spec$stages[[2]]$selction <- "staged_bic"

  expect_error(validate_spec(spec), "unknown field.*selction")
})

test_that("a misspelt model set is reported", {
  spec <- lichen_spec()
  spec$stages[[1]]$models <- "climate_plant_v2_ful"

  expect_error(validate_spec(spec), "not a model set")
})

test_that("every problem is reported at once", {
  spec <- bird_spec()
  spec$stages[[1]]$engine <- "no_such_engine"
  spec$stages[[1]]$ic <- "DIC"
  spec$resample$scheme <- "no_such_scheme"

  problems <- validate_spec(spec, stop_on_error = FALSE)
  expect_length(problems, 3)
})

test_that("a rule's settings come from stage fields by name", {
  # staged_bic's `threshold` is a setting no harness code names
  spec <- bird_spec()
  spec$stages[[2]]$threshold <- 4

  expect_silent(validate_spec(spec))
})

test_that("stage_models replaces a set and is recorded", {
  spec <- apply_stage_models(
    lichen_spec(),
    list(climate = models_from_covariates(c("MAP", "FFP")))
  )

  expect_equal(spec$models_overridden, "climate <- climate")
  expect_setequal(
    spec_covariates(spec, "climate"), c("MAP", "FFP")
  )
})
