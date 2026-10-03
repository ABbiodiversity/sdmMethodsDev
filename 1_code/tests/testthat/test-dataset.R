# The harmonized lookups agree with each other and with the files
# they describe. Skipped when the dataset is not present.

skip_if_not(dir.exists(data_dir), "No test dataset")

test_that("the manifest names files that exist", {
  manifest <- dataset_manifest(data_dir)

  expect_true(all(file.exists(
    file.path(data_dir, manifest$response_file)
  )))
  expect_true(all(file.exists(file.path(
    data_dir, "lookup",
    paste0(manifest$grid, "_prediction_matrix.csv")
  ))))
})

test_that("every taxon in the queue is in the manifest", {
  expect_setequal(
    unique(species_catalogue(data_dir)$taxon),
    unique(dataset_manifest(data_dir)$taxon)
  )
})

test_that("the species queue matches the source lookups", {
  # The counts the three source schemas give, checked against
  # the one queue _setup/09 wrote from them
  plants <- data.table::fread(
    file.path(data_dir, "lookup", "modelled_species.csv")
  )
  expect_equal(
    length(list_species(data_dir, "lichen", "north")),
    sum(plants$taxon == "lichen" & plants$in_veg_models)
  )

  birds <- data.table::fread(
    file.path(data_dir, "lookup", "bird_modelled_species.csv")
  )
  expect_equal(
    list_species(data_dir, "bird", "south"),
    birds$species[birds$region == "south"]
  )

  expect_equal(
    species_source_name(data_dir, "mammal", "BlackBear_Summer"),
    "Black BearSummer"
  )
})

test_that("covariate keys come from the manifest", {
  expect_equal(covariate_key("mammal", "north", data_dir),
               "mammal_north")
  expect_equal(covariate_key("lichen", "south", data_dir), "lichen")
})

test_that("the bird north grid reproduces v2's translation matrix", {
  grid <- load_prediction_grid(data_dir, "bird_north")
  age <- as.data.frame(data.table::fread(
    file.path(data_dir, "lookup", "bird_veg_age_matrix.csv")
  ))

  expect_equal(rownames(grid), age$type)
  expect_equal(grid$wtAge, age$wtAge)
  expect_equal(
    grid$isCon * grid$wtAge, age[["isCon:wtAge"]], tolerance = 1e-12
  )
})

test_that("the covariate cache returns what a fresh read does", {
  clear_cache()
  first <- load_covariates("lichen", data_dir, c("MAP", "FFP"))
  wider <- load_covariates("lichen", data_dir, c("MAP", "CMD"))
  clear_cache()
  fresh <- load_covariates("lichen", data_dir, c("MAP", "CMD"))

  expect_identical(wider, fresh)
  expect_identical(first$MAP, fresh$MAP)
})
