# Coarsened-coordinate (sovereign-GPS) mode. All offline / network-free: these
# exercise the request-time coarsening policy and the provenance it records.

test_that("a sovereign point is coarsened to ~1 km by default", {
  raw_lon <- 138.63124
  raw_lat <- -34.92871
  r <- geo_point_request(raw_lon, raw_lat, "2020-01-01", "2020-01-31",
                         source = "nasapower", sovereign = TRUE)
  # The sent coordinate is rounded to 0.01 degrees; the raw coordinate is kept.
  expect_equal(r$lon, round(raw_lon, 2L))
  expect_equal(r$lat, round(raw_lat, 2L))
  expect_equal(r$lon_raw, raw_lon)
  expect_equal(r$lat_raw, raw_lat)
  expect_identical(r$coarsen_policy, "precision=0.01")
  expect_true(r$sovereign)
})

test_that("an explicit precision coarsens a non-sovereign point", {
  r <- geo_point_request(138.63124, -34.92871, source = "nasapower",
                         coarsen = 0.1)
  expect_equal(r$lon, round(138.63124, 1L))
  expect_equal(r$lat, round(-34.92871, 1L))
  expect_identical(r$coarsen_policy, "precision=0.1")
  expect_false(r$sovereign)
})

test_that("a grid policy snaps to the nearest grid node", {
  r <- geo_point_request(138.63124, -34.92871, source = "nasapower",
                         coarsen = list(grid = 0.25))
  expect_equal(r$lon, round(138.63124 / 0.25) * 0.25)
  expect_equal(r$lat, round(-34.92871 / 0.25) * 0.25)
  expect_identical(r$coarsen_policy, "grid=0.25")
})

test_that("a non-sovereign default request is not coarsened", {
  r <- geo_point_request(138.63124, -34.92871, source = "nasapower")
  expect_equal(r$lon, 138.63124)
  expect_equal(r$lat, -34.92871)
  expect_identical(r$coarsen_policy, "none")
  # Backward-compatibility: lon/lat still echo the requested point exactly.
  expect_equal(r$lon_raw, 138.63124)
})

test_that("geo_point_request validates sovereign and coarsen", {
  expect_error(geo_point_request(1, 1, source = "x", sovereign = "yes"),
               "single logical")
  expect_error(geo_point_request(1, 1, source = "x", coarsen = -1),
               "positive")
  expect_error(geo_point_request(1, 1, source = "x", coarsen = c(0.1, 0.2)),
               "positive")
  expect_error(geo_point_request(1, 1, source = "x", coarsen = list(foo = 1)),
               "grid")
  expect_error(geo_point_request(1, 1, source = "x", coarsen = list(grid = -1)),
               "positive")
})

test_that("coarsening provenance is stamped on a collected (replayed) series", {
  skip_if_not_installed("withr")
  d <- c(testthat::test_path("..", "..", "inst", "fixtures"),
         system.file("fixtures", package = "terroir"))
  d <- d[nzchar(d) & dir.exists(d)][1]
  skip_if(is.na(d) || !nzchar(d), "no inst/fixtures directory available")

  withr::with_options(list(terroir.fixture_dir = normalizePath(d)), {
    # A sovereign point near the nasapower fixture coord (138.6, -34.92): it
    # coarsens TO the fixture coord, so the replay matches and the provenance
    # records the raw-vs-sent coordinates.
    r <- geo_point_request(138.6012, -34.9241, "2020-01-01", "2020-01-10",
                           variables = c("T2M", "PRECTOTCORR"),
                           source = "nasapower", sovereign = TRUE)
    s <- collect_point(r, offline = TRUE)
    expect_s3_class(s, "geo_point_series")
    prov <- attr(s, "provenance")
    expect_true(prov$sovereign)
    expect_identical(prov$coarsen_policy, "precision=0.01")
    expect_equal(prov$lon_raw, 138.6012)
    expect_equal(prov$lon_sent, 138.6)
    # The fixed ten-column series schema is unchanged (additive provenance).
    expect_identical(ncol(s), 10L)
  })
})
