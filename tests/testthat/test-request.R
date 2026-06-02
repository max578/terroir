test_that("geo_point_request validates its inputs", {
  expect_s3_class(
    geo_point_request(138.6, -34.92, "2020-01-01", "2020-01-31",
                      source = "nasapower"),
    "geo_point_request"
  )
  expect_error(geo_point_request(200, 0, source = "nasapower"), "lon")
  expect_error(geo_point_request(0, 100, source = "nasapower"), "lat")
  expect_error(geo_point_request(0, 0, source = ""), "source")
  expect_error(geo_point_request(0, 0, source = "x", radius = -1), "radius")
})

test_that("a request carries its fields", {
  r <- geo_point_request(138.6, -34.92, "2020-01-01", "2020-01-31",
                         variables = c("T2M"), source = "nasapower")
  expect_identical(r$source, "nasapower")
  expect_identical(r$variables, "T2M")
  expect_equal(r$lon, 138.6)
})
