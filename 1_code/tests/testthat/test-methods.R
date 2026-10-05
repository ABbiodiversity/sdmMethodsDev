# Every registered method meets its contract, and the registry
# behaves as a spec relies on it to.

test_that("every registered engine passes check_engine()", {
  for (name in registered_names("engine")) {
    checks <- check_engine(name, quiet = TRUE)
    expect_true(
      all(checks$pass),
      info = paste(name, ":", paste(
        checks$check[!checks$pass], collapse = "; "
      ))
    )
  }
})

test_that("the v2 methods are all registered", {
  expect_true(all(
    c("glm", "bayesglm", "xgboost") %in% registered_names("engine")
  ))
  expect_true(all(c(
    "single", "aic_best", "aic_average", "staged_bic", "ivw_grid",
    "hurdle"
  ) %in% registered_names("selection")))
  expect_true(all(c("precomputed", "spatial_block", "spatial_cv")
                  %in% registered_names("resampler")))
})

test_that("an unknown method fails with the registered names", {
  expect_error(get_engine("no_such_engine"), "Registered: .*glm")
  expect_error(get_method("selection", "best"), "aic_best")
})

test_that("a registered method can be looked up and removed", {
  register_metric(
    "test_mean_prediction",
    function(observed, predicted) mean(predicted),
    "Test only"
  )
  on.exit(unregister_method("metric", "test_mean_prediction"))

  expect_equal(
    get_method("metric", "test_mean_prediction")(0, c(1, 3)), 2
  )
  expect_true("test_mean_prediction" %in% default_metrics())
})

test_that("compute_metrics keeps its order and scores known cases", {
  scores <- compute_metrics(c(0, 0, 1, 1), c(0.1, 0.2, 0.8, 0.9))

  expect_equal(
    scores$metric[1:7],
    c("auc", "deviance_explained", "rmse", "spearman",
      "calibration_slope", "prevalence", "n")
  )
  expect_equal(scores$value[scores$metric == "auc"], 1)
  expect_equal(scores$value[scores$metric == "prevalence"], 0.5)
  # A draw with one class has no AUC, and that is not an error
  expect_true(is.na(
    compute_metrics(c(0, 0), c(0.1, 0.2), "auc")$value
  ))
})

test_that("an engine without coefficients can run the single rule", {
  # A stand-in for a boosted tree: predictions only
  glm <- get_engine("glm")
  register_engine(list(
    name = "test_predict_only",
    description = "Test only",
    capabilities = character(0),
    fit = glm$fit,
    predict = glm$predict
  ))
  on.exit(unregister_method("engine", "test_predict_only"))

  engine <- get_engine("test_predict_only")
  data <- data.frame(response = rep(c(0, 1), 50), x = 1:100)
  selected <- selection_run(
    "single", list(stats::as.formula(". ~ . + x")), response ~ 1,
    data, engine, "binomial"
  )

  expect_null(selected$coefficients)
  expect_length(selected$predict(data, "response"), 100)

  # And a rule that needs coefficients is refused before fitting
  spec <- lichen_spec()
  spec$stages[[1]]$engine <- "test_predict_only"
  problems <- validate_spec(spec, stop_on_error = FALSE)
  expect_true(any(grepl("aic_average.*needs", problems)))
})
