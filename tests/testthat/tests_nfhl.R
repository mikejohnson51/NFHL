# Load required libraries
library(AOI)
library(sf)

# Context for tests
# Test 1: nfhl_describe
test_that("nfhl_describe returns correct structure", {
  layer_id <- 14
  result <- nfhl_describe(layer_id)
  
  # Check the output type
  expect_type(result, "list")
  expect_named(result, c("Layer", "Description", "bbox"))
  
  # Check Layer name and Description are character
  expect_type(result$Layer, "character")
  expect_type(result$Description, "character")
  
  # Check bbox is an sf object
  expect_s3_class(result$bbox, "sfc")
})

# Test 2: nfhl_get
test_that("nfhl_get returns sf object for valid input", {
  # Define a test AOI around UCSB
  AOI_test <- AOI::aoi_ext("UCSB",
                           wh = 5,
                           units = "km",
                           bbox = TRUE) |> st_as_sf()
  
  # Extract data for Layer 28
  result <- nfhl_get(AOI_test, layer = 28)
  
  # Check the output is an sf object
  expect_s3_class(result, "sf")
  
  # Check that the sf object has a valid geometry column
  expect_true("geometry" %in% colnames(result))
  
  # Check that the LAYER column is correctly populated
  expect_true("LAYER" %in% colnames(result))
  expect_equal(unique(result$LAYER), 28)
})

# Test 3: nfhl_get with invalid layer ID
test_that("nfhl_get handles invalid layer IDs gracefully", {
  AOI_test <- AOI::aoi_ext("UCSB",
                           wh = 5,
                           units = "km",
                           bbox = TRUE) |> st_as_sf()
  
  # Invalid layer ID
  expect_error(nfhl_get(AOI_test, layer = 99999))
  
})

# Test 4: nfhl_describe with invalid layer ID
test_that("nfhl_describe handles invalid layer IDs gracefully", {
  # Invalid layer ID
  expect_error(nfhl_describe(layer = 99999))
})

# Test 5: Check for dependencies and correct package imports
test_that("dependencies are loaded", {
  expect_true(requireNamespace("sf", quietly = TRUE))
  expect_true(requireNamespace("httr", quietly = TRUE))
  expect_true(requireNamespace("dplyr", quietly = TRUE))
})

# Test 6: Test nfhl_meta data consistency
test_that("nfhl_meta object exists and has correct structure", {
  expect_true(exists("nfhl_meta"))
  expect_s3_class(nfhl_meta, "data.frame")
  expect_true(all(c("type", "layerID") %in% colnames(nfhl_meta)))
})

