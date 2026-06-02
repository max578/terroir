# Per-adapter golden-file round-trip. Goldens are small cached responses (see
# data-raw/regenerate_golden.R) so these run offline and pin the C6 schema.
# A source without a golden yet is skipped -- live-fixture generation needs
# network/keys (Phase 2b). nasapower ships a golden, so it does NOT skip.

check_golden <- function(id) {
  f <- file.path(testthat::test_path("_golden"), paste0(id, ".rds"))
  skip_if_not(file.exists(f), paste("no golden fixture for", id, "(Phase 2b)"))
  s <- readRDS(f)
  expect_s3_class(s, "geo_point_series")
  expect_true(verify_geo_series(s))
  expect_true(all(.geo_point_cols %in% names(s)))
  expect_gt(nrow(s), 0L)
}

test_that("golden round-trip: nasapower", {
  check_golden("nasapower")
})

test_that("golden round-trip: silo", {
  check_golden("silo")
})

test_that("golden round-trip: abares", {
  check_golden("abares")
})

test_that("golden round-trip: modis", {
  check_golden("modis")
})

test_that("golden round-trip: stac", {
  check_golden("stac")
})
