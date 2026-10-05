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

test_that("one call swaps the habitat method of every run", {
  specs <- lapply(
    standard_specs(), replace_stage_method, engine = "xgboost"
  )

  for (key in names(specs)) {
    expect_silent(validate_spec(specs[[key]]))
  }

  # The mammal hurdle keeps its structure; both halves take the
  # new engine, and v2's GLM table-building is removed with them
  habitat <- specs$mammal_summer$stages[[1]]
  expect_equal(habitat$selection, "hurdle")
  expect_equal(habitat$part_selection, "single")
  expect_equal(habitat$engine, "xgboost")
  expect_null(habitat$post_process)
  expect_equal(specs$bird$stages[[2]]$engine, "xgboost")
})

test_that("a hurdle's inner rule is checked against its engine", {
  spec <- replace_stage_method(
    mammal_spec(), engine = "xgboost", selection = "aic_best"
  )

  expect_error(validate_spec(spec), "inner rule `aic_best` needs")
})

test_that("the hurdle fits both halves with any engine", {
  set.seed(1)
  n <- 300
  data <- data.frame(
    x = stats::runif(n), cover = stats::rbinom(n, 1, 0.5),
    seas_days = 100
  )
  data$response_raw <- stats::rbinom(n, 1, 0.4) *
    stats::rgamma(n, 2, 1)
  data$response <- sign(data$response_raw)
  grid <- data.frame(cover = c(0, 1), row.names = c("A", "B"))

  for (engine in c("glm", "xgboost")) {
    selected <- selection_run(
      "hurdle", list(stats::as.formula(". ~ . + x + cover")),
      response ~ 1, data, get_engine(engine), "binomial",
      grid = grid,
      constants = list(x = 0.5),
      # seas_days is constant here, so the effort-only null
      # candidate would be rank-deficient
      abundance_null = NULL,
      part_selection = if (engine == "glm") "aic_best" else "single"
    )

    expect_named(
      selected$outputs, c("presence", "abundance", "total")
    )
    expect_equal(
      selected$outputs$total$estimate,
      selected$outputs$presence$estimate *
        selected$outputs$abundance$estimate
    )
    expect_length(selected$predict(data, "response"), n)
  }
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
