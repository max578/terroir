# Network-free behaviour: collect_point must refuse (not crash) on an unknown
# source or a source whose package is not installed.

test_that("collect_point refuses an unknown source", {
  req <- geo_point_request(138.6, -34.92, source = "no_such_source")
  out <- suppressWarnings(collect_point(req))
  expect_true(is_refusal(out))
  expect_match(out$reason, "unknown source")
})

test_that("collect_point refuses when the source package is absent", {
  # Register a source pointing at a package that cannot be installed.
  register_source("dummy_absent", function(request, retrieved_at) NULL,
                  package = "this.package.does.not.exist", free = TRUE)
  req <- geo_point_request(0, 0, source = "dummy_absent")
  out <- suppressWarnings(collect_point(req))
  expect_true(is_refusal(out))
  expect_match(out$reason, "not installed")
})

test_that("a refusal is a first-class object", {
  out <- suppressWarnings(
    collect_point(geo_point_request(0, 0, source = "nope"))
  )
  expect_s3_class(out, "terroir_refusal")
  expect_invisible(print(out))
})

test_that("collect_point returns a typed refusal on an implausible value, not an abort (T-06)", {
  register_source("test_bad_ndvi", function(request, retrieved_at) {
    new_geo_point_series(
      data.table::data.table(date = as.Date("2020-01-01"),
                             variable = "250m_16_days_NDVI", value = 5400,
                             unit = "index"),
      lon = request$lon, lat = request$lat, source = "test_bad_ndvi",
      source_version = "0", license = "test", retrieved_at = retrieved_at,
      call = "test")
  }, package = "utils", free = TRUE, description = "test")

  out <- suppressWarnings(
    collect_point(geo_point_request(138.6, -34.9, source = "test_bad_ndvi"))
  )
  expect_true(is_refusal(out))
  expect_match(out$reason, "Implausible NDVI")
})
