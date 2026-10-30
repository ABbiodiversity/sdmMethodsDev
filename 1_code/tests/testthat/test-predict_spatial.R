# ---
# title: Tests - Spatial Prediction Rules
# author: Brendan Casey
# created: 2026-10-27
# inputs: none; the loaded framework
# outputs: none; testthat results
# notes:
#   - The rules of harness/predict_spatial.R that do not need the
#     grid: settings checks, the class-map lookup, v2's links, the
#     single-region rules and the season pooling. The full port is
#     checked against v2's scripts by exp_000's
#     04_compare_predictions.R.
#   - Run through 1_code/tests/run_tests.R.
# ---

test_that("prediction_config() checks its settings", {
  expect_false(prediction_config()$enabled)
  expect_equal(prediction_config(draws = c(3, 1, 1))$draws, c(1L, 3L))
  expect_error(prediction_config(draws = "mean"), "draws")
  expect_error(prediction_config(scenarios = "future"), "scenarios")
  expect_error(prediction_config(caps_from = "grid"), "caps_from")
  expect_error(prediction_config(extent = list("a")), "extent")
  expect_equal(prediction_config(extent = "parity_test")$extent,
               "parity_test")
  expect_match(prediction_label(prediction_config()), "off")
})

test_that("every mapped spec's spatial settings validate", {
  for (key in names(standard_specs())) {
    spatial <- standard_specs()[[key]]$spatial
    expect_false(is.null(spatial))
    expect_length(check_spatial_spec(spatial), 0)
  }

  bad <- bird_spec()$spatial
  bad$link <- "probit"
  expect_match(check_spatial_spec(bad), "link")
})

test_that("class values follow the map, averaging and fixing", {
  map <- data.frame(
    region = "north",
    grid_class = c("A", "B", "C", "D"),
    model_class = c("a", "b1;b2", "", "missing"),
    engine_class = "",
    fixed_value = c(NA, NA, -10000, NA)
  )
  values <- class_values(map, c("A", "B", "C", "D", "E"),
                         c(a = 1, b1 = 2, b2 = 4))

  # Mean of the listed terms; a fixed value; dropped otherwise
  expect_equal(unname(values), c(1, 3, -10000, NA, NA))
})

test_that("the logit inverse is v2's binomial()$linkinv", {
  inv <- inverse_link("logit")
  eps <- .Machine$double.eps
  expect_equal(inv(-50), eps / (1 + eps))
  expect_equal(inv(0.3), stats::plogis(0.3))
  expect_equal(inverse_link("log")(-1e6), .Machine$double.eps)
})

test_that("single-region species follow each taxon's rule", {
  ctx <- list(cells = data.frame(
    wN = c(1, 0.5, 0), wS = c(0, 0.5, 1),
    NrName = c("Boreal", "Parkland", "Grassland")
  ))
  north <- c(1, 2, 3)

  # Birds: the missing region is zero, then blended
  zero <- combine_regions(north, NULL, ctx,
                          list(single_region = "zero"), NA)
  expect_equal(zero, c(1, 1, 0))

  # Mammals: unblended, NA where the weight is zero
  na <- combine_regions(north, NULL, ctx,
                        list(single_region = "na"), NA)
  expect_equal(na, c(1, 2, NA))

  # Plants: unblended, NA outside the region's natural regions
  mask <- combine_regions(
    north, NULL, ctx,
    list(single_region = "na_by_nr",
         region_mask = list(north = ~ NrName != "Grassland")),
    NA
  )
  expect_equal(mask, c(1, 2, NA))
})

test_that("seasons pool as v2 averages its .all tables", {
  one <- function(pa, aspen, clim) {
    list("1" = list(
      boot = 1L,
      climate = data.frame(term = "MAP", estimate = clim),
      regions = list(south = list(
        presence = c(Climate = pa, pAspen = aspen),
        total = c(Loamy = 2 * pa)
      )),
      models = list()
    ))
  }
  pooled <- pool_seasons(list(one(0.2, 0.6, 1), one(0.4, 0.8, 3)))
  presence <- pooled[["1"]]$regions$south$presence

  expect_equal(presence[["Climate"]], 0.3)
  expect_equal(
    presence[["pAspen"]],
    stats::plogis(mean(stats::qlogis(c(0.6, 0.8))))
  )
  expect_equal(pooled[["1"]]$climate$estimate, 2)
})

test_that("an extent names its cells", {
  cells <- data.frame(Col = 1:5, Easting = 1:5 * 10,
                      Northing = 1:5 * 10, LufName = "x")
  expect_equal(extent_cells(cells, list(Col = 2:3)), 2:3)
  expect_equal(extent_cells(cells, list(bbox = c(0, 25, 0, 100))),
               1:2)
  expect_error(extent_cells(cells, list(Foo = 1)), "not a grid")
  expect_equal(extent_label(list(Col = 300:400)), "Col=300:400")
})

# End of script ----
