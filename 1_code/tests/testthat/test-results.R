# Result stores, shards and seeds behave as a parallel run relies
# on them to.

test_that("merged shards equal a store written in one pass", {
  root <- file.path(tempdir(), "shard_test")
  unlink(root, recursive = TRUE)
  on.exit(unlink(root, recursive = TRUE))

  rows <- function(species) {
    data.frame(term = c("a", "b"), estimate = c(0.1, 0.2),
               se = c(0.01, 0.02))
  }

  # Serial: one store, appended in order
  serial <- result_store(file.path(root, "serial"))
  for (sp in c("sp1", "sp2")) {
    for (boot in 1:2) {
      write_coefficients(serial, sp, "north", boot, rows(sp), "s")
    }
  }

  # Parallel: a header-less shard per species, merged after
  shards <- file.path(root, "shards", c("sp1", "sp2"))
  for (i in 1:2) {
    shard <- result_store(shards[i], header = FALSE)
    for (boot in 1:2) {
      write_coefficients(
        shard, c("sp1", "sp2")[i], "north", boot, rows(), "s"
      )
    }
  }
  merged <- result_store(file.path(root, "merged"))
  merge_result_shards(merged, shards)

  expect_identical(
    readBin(file.path(root, "serial", "coefficients.csv"),
            "raw", 1e6),
    readBin(file.path(root, "merged", "coefficients.csv"),
            "raw", 1e6)
  )
})

test_that("unit predictions are written only when asked", {
  root <- file.path(tempdir(), "unit_test")
  unlink(root, recursive = TRUE)
  on.exit(unlink(root, recursive = TRUE))

  for (mode in c("none", "oob", "all")) {
    store <- result_store(file.path(root, mode),
                          unit_predictions = mode)
    write_unit_predictions(
      store, "sp", "north", 1, c("u1", "u2", "u3"),
      c(0.1, 0.2, 0.3), c(0, 1, 0),
      in_bag = c(TRUE, FALSE, TRUE)
    )
  }

  expect_null(read_results(file.path(root, "none"),
                           "unit_predictions"))
  expect_equal(
    read_results(
      file.path(root, "oob"), "unit_predictions"
    )$survey_unit_id,
    "u2"
  )
  expect_equal(
    nrow(read_results(file.path(root, "all"), "unit_predictions")), 3
  )
})

test_that("a seed gives the same draws whatever the generator", {
  default <- with_seed(42, sample(100, 5))

  old <- RNGkind()
  RNGkind("L'Ecuyer-CMRG")
  switched <- with_seed(42, sample(100, 5))
  after <- RNGkind()[1]
  do.call(RNGkind, as.list(old))

  expect_identical(default, switched)
  # And the caller's generator is left as it was
  expect_equal(after, "L'Ecuyer-CMRG")
})

test_that("species seeds do not depend on the other species", {
  expect_identical(
    species_seed(20260909L, "lichen", "Physcia.adscendens"),
    species_seed(20260909L, "lichen", "Physcia.adscendens")
  )
  expect_false(identical(
    species_seed(20260909L, "lichen", "Physcia.adscendens"),
    species_seed(20260909L, "lichen", "Cladonia.chlorophaea")
  ))
})

test_that("spatial cross-validation holds out whole folds", {
  frame <- data.frame(
    survey_unit_id = paste0("u", 1:400),
    long = stats::runif(400, -120, -110),
    lat = stats::runif(400, 49, 60)
  )
  draws <- resampler_spatial_cv(
    frame, 1:3, seed = 1L, context = list()
  )

  expect_length(draws, 3)
  # Every unit is held out by exactly one fold
  held_out <- lapply(
    draws, function(d) setdiff(frame$survey_unit_id, d)
  )
  expect_equal(sum(lengths(held_out)), 400)
})
