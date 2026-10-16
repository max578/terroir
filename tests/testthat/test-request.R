test_that("geo_point_request validates its inputs", {
  expect_s3_class(
    geo_point_request(138.6, -34.92, "2020-01-01", "2020-01-31",
                      source = "nasapower"),
    "geo_point_request"
  )
  expect_error(geo_point_request(200, 0, source = "nasapower"), "lon")
  expect_error(geo_point_request(0, 100, source = "nasapower"), "lat")
  expect_error(geo_point_request(0, 0, source = ""), "source")
})

test_that("a request carries its fields", {
  r <- geo_point_request(138.6, -34.92, "2020-01-01", "2020-01-31",
                         variables = c("T2M"), source = "nasapower")
  expect_identical(r$source, "nasapower")
  expect_identical(r$variables, "T2M")
  expect_equal(r$lon, 138.6)
})

test_that("geo_point_request has no inert radius formal (T-04)", {
  # radius was documented, validated and stored, but read by no adapter.
  # Removed rather than wired, since no registered source implements a
  # nearest-station / buffer search today (see NEWS.md).
  expect_false("radius" %in% names(formals(geo_point_request)))
})

test_that("a request prints its source, point and coarsening", {
  r <- geo_point_request(138.63124, -34.92871, "2020-01-01", "2020-01-31",
                         source = "nasapower", sovereign = TRUE)
  out <- paste(cli::cli_fmt(print(r)), collapse = "\n")
  expect_match(out, "nasapower")
  expect_match(out, "2020-01-01 .. 2020-01-31")
  expect_match(out, "(adapter default)", fixed = TRUE)
  # a sovereign point is rounded to 0.01 degrees before it is sent
  expect_match(out, "sent (138.63, -34.93)", fixed = TRUE)
  expect_match(out, "sovereign")
})
