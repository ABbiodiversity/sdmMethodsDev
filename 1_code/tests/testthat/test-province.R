# ---
# title: Tests - Separate Province Tables
# author: Brendan Casey
# created: 2026-10-14
# inputs: none; the loaded framework, and the test dataset for
#   the last check (skipped when it has no province rows)
# outputs: none; testthat results
# notes:
#   - A taxon whose province-wide data are their own table (the
#     mammal climate stage): province draws map to region units
#     through a key, the province frame carries companion
#     responses, and the mammal climate response is v2's.
#   - Run through 1_code/tests/run_tests.R, which loads the
#     framework and sets `data_dir`.
# ---

test_that("province draws map to region units through the key", {
  province <- data.frame(
    survey_unit_id = c("p|a", "p|b", "p|c"),
    location_project = c("a", "b", "c")
  )
  # Region order differs; "d" has no province row
  region <- data.frame(
    survey_unit_id = c("r|c", "r|a", "r|d", "r|b"),
    location_project = c("c", "a", "d", "b")
  )

  draws <- list(
    province$survey_unit_id,
    c("p|a", "p|a", "p|c")
  )
  mapped <- map_province_draws(
    draws, province, region, "location_project"
  )

  # Draw 1: every mapped unit once, in region order, "d" dropped
  expect_equal(mapped[[1]], c("r|c", "r|a", "r|b"))
  # Repeats kept
  expect_equal(mapped[[2]], c("r|c", "r|a", "r|a"))
})

test_that("a duplicated province key maps to its first unit", {
  province <- data.frame(
    survey_unit_id = c("p|a__1", "p|a__2"),
    location_project = c("a", "a")
  )
  region <- data.frame(
    survey_unit_id = "r|a", location_project = "a"
  )

  mapped <- map_province_draws(
    list(province$survey_unit_id, "p|a__2"), province, region,
    "location_project"
  )

  expect_equal(mapped[[1]], "r|a")
  expect_length(mapped[[2]], 0)
})

test_that("model_frame attaches companion responses", {
  md <- list(
    taxon = "x",
    covariates = data.frame(survey_unit_id = c("u1", "u2")),
    response = data.frame(
      survey_unit_id = c("u1", "u2"),
      A_Summer = c(1, 0), A_Winter = c(0, 2)
    ),
    offset = NULL
  )

  frame <- model_frame(
    md, "A_Summer",
    companions = c(summer = "A_Summer", winter = "A_Winter")
  )
  expect_equal(frame$response_winter, c(0, 2))
  expect_error(
    model_frame(md, "A_Summer", companions = c(winter = "B_Winter")),
    "not a column"
  )
})

test_that("province_key needs province draws", {
  spec <- mammal_spec()
  expect_silent(validate_spec(spec))

  spec$resample$scope <- NULL
  expect_error(validate_spec(spec), "scope` must be \"province\"")
})

test_that("the climate response pools seasons as v2 does", {
  frame <- data.frame(
    survey_unit_id = c("p|a", "p|b", "p|c", "p|d", "p|e__1",
                       "p|e__2", "p|f", "p|a"),
    location_project = c("a", "b", "c", "d", "e", "e", "f", "a"),
    response_summer = c(0, NA, NA, 0, 0, 0, 1, 0),
    response_winter = c(2, 0, 0, NA, 0, 3, 0, 2),
    summer_days = c(50, 0, 30, 0, 40, 40, 20, 50),
    winter_days = c(60, 70, 60, 0, 40, 40, 20, 60),
    FFP = c(100, 100, 100, 100, 100, 100, NA, 100)
  )

  expected <- c(
    1L,          # a: winter density, mean above 0
    0L,          # b: NA summer with 0 days drops out (base R)
    NA_integer_, # c: NA summer with days gives NA
    NA_integer_, # d: no days in either season (NaN)
    1L,          # e: two units of one deployment, pooled
    NA_integer_, #    and counted once
    NA_integer_, # f: no camera climate
    1L           # a again: a bootstrap repeat, kept
  )

  expect_equal(mammal_climate_response(NULL, frame), expected)
  expect_equal(
    mammal_pooled_density(frame)$density[2],
    stats::weighted.mean(c(NA, 0), c(0, 70))
  )
})

test_that("the dataset's province rows load", {
  skip_if_not(dir.exists(data_dir), "No test dataset")
  skip_if(
    is.null(province_region(data_dir, "mammal")),
    "The test dataset has no mammal province rows"
  )

  md <- build_model_data(
    "mammal", data_dir, c("Moose_Summer", "Moose_Winter"),
    c("FFP", "location_project"), region = "province"
  )
  expect_true(all(startsWith(md$units, "mammal_province|")))
  expect_null(province_region(data_dir, "lichen"))
})

# End of script ----
