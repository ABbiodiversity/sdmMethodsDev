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

test_that("an experiment is compared with its baseline by key", {
  root <- file.path(tempdir(), "compare_test")
  unlink(root, recursive = TRUE)
  on.exit(unlink(root, recursive = TRUE))

  write_summary <- function(dir, auc, draws) {
    dir.create(file.path(dir, "tables"), recursive = TRUE)
    data.table::fwrite(
      data.frame(
        taxon = "lichen", run = c("lichen", "lichen"),
        region = "north", season = NA, part = NA,
        species = c("sp1", "sp2"), metric = "oob_auc",
        n = draws, median = auc, p10 = auc - 0.05,
        p90 = auc + 0.05, boot1 = NA
      ),
      file.path(dir, "tables", "metric_summary.csv")
    )
  }

  write_summary(file.path(root, "base"), c(0.70, 0.80), 100)
  write_summary(file.path(root, "same"), c(0.75, 0.78), 100)
  write_summary(file.path(root, "short"), c(0.75, 0.78), 5)

  out <- compare_experiments(
    file.path(root, "same"), file.path(root, "base")
  )
  expect_equal(out$summary$share_better, 0.5)
  expect_equal(out$summary$draws_baseline, 100)
  expect_true(file.exists(
    file.path(root, "same", "tables", "comparison_metrics.csv")
  ))
  expect_false(file.exists(
    file.path(root, "same", "tables", "comparison_summary.csv")
  ))

  # A trial against a full run is warned about
  expect_warning(
    compare_experiments(
      file.path(root, "short"), file.path(root, "base")
    ),
    "different numbers of draws"
  )
})

test_that("the baseline does not compare with itself", {
  expect_null(experiment_config("exp_000_parity_v2")$baseline)
  expect_equal(
    experiment_config("exp_009_test")$baseline, "exp_000_parity_v2"
  )
})

test_that("draw summaries carry the mean and standard deviation", {
  rows <- data.frame(
    species = "sp", metric = "oob_auc", boot = 1:4,
    value = c(0.6, 0.7, 0.8, NA)
  )
  out <- summarise_draws(rows, "value", c("species", "metric"))

  expect_equal(out$n, 3)
  expect_equal(out$mean, 0.7)
  expect_equal(out$sd, 0.1)
  # Appended, so earlier columns keep their positions
  expect_equal(
    names(out),
    c("species", "metric", "n", "median", "p10", "p90", "boot1",
      "mean", "sd")
  )
})
