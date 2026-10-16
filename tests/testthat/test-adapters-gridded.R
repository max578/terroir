# geodata and chirps are mocked with small in-memory rasters and tables.

.ramp_raster <- function(nlyr, xmin, xmax, ymin, ymax) {
  r <- terra::rast(nrows = 10, ncols = 10, nlyrs = nlyr,
                   xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax)
  for (i1 in seq_len(nlyr)) terra::values(r[[i1]]) <- i1 * 10 + seq_len(100) / 100
  r
}

test_that("worldclim names bio_1 to bio_19 with units and refuses an empty cell", {
  skip_if_not_installed("geodata")
  skip_if_not_installed("terra")
  testthat::local_mocked_bindings(
    worldclim_tile = function(var, lon, lat, path, ...) {
      r <- .ramp_raster(19, 120, 150, -40, -10)
      terra::values(r)[1, ] <- NA        # the top-left cell holds no data
      r
    },
    .package = "geodata"
  )
  reqs <- list(
    geo_point_request(135, -25, source = "worldclim"),
    geo_point_request(120.1, -10.1, source = "worldclim")
  )
  out <- .batch_worldclim(reqs, retrieved_at = "t0")
  expect_s3_class(out[[1L]], "geo_point_series")
  expect_identical(out[[1L]]$variable, paste0("bio_", 1:19))
  expect_identical(out[[1L]]$unit[c(1L, 4L, 12L)], c("degC", "degC x 100", "mm"))
  expect_true(is_refusal(out[[2L]]))
})

test_that("worldclim refuses an unknown variable for every request", {
  reqs <- list(geo_point_request(135, -25, variables = "bio_20",
                                 source = "worldclim"))
  out <- .batch_worldclim(reqs, retrieved_at = "t0")
  expect_true(is_refusal(out[[1L]]))
  expect_match(out[[1L]]$reason, "bio_20")
})

test_that("soilgrids writes one column per variable and depth, in stated units", {
  skip_if_not_installed("geodata")
  skip_if_not_installed("terra")
  seen <- new.env()
  seen$n <- 0L
  testthat::local_mocked_bindings(
    soil_world = function(var, depth, stat, path, vsi, ...) {
      seen$n <- seen$n + 1L
      .ramp_raster(1, 110, 160, -45, -5)
    },
    .package = "geodata"
  )
  reqs <- list(
    geo_point_request(138.6, -34.9, variables = c("clay", "ph_h2o"),
                      source = "soilgrids"),
    geo_point_request(117.0, -31.5, variables = c("clay", "ph_h2o"),
                      source = "soilgrids")
  )
  out <- .batch_soilgrids(reqs, retrieved_at = "t0")
  # one raster read per variable and depth, shared by both points
  expect_identical(seen$n, 8L)
  expect_identical(
    out[[1L]]$variable,
    c(paste0("clay_", names(.SOILGRIDS_DEPTHS)), paste0("ph_h2o_", names(.SOILGRIDS_DEPTHS)))
  )
  expect_identical(unique(out[[2L]]$unit), c("%", "pH"))
})

test_that("chirps splits one shared answer back into each request's window", {
  skip_if_not_installed("chirps")
  testthat::local_mocked_bindings(
    get_chirps = function(object, dates, server, ...) {
      days <- seq(as.Date(dates[1]), as.Date(dates[2]), by = "day")
      g <- expand.grid(i = seq_len(nrow(object)), date = days)
      data.frame(id = g$i, date = g$date, lon = object$lon[g$i],
                 lat = object$lat[g$i],
                 chirps = ifelse(g$i == 2L, -9999, as.numeric(format(g$date, "%d"))))
    },
    .package = "chirps"
  )
  reqs <- list(
    geo_point_request(138.6, -34.9, "2019-12-30", "2020-01-02", source = "chirps"),
    geo_point_request(117.0, -31.5, "2020-01-01", "2020-01-01", source = "chirps")
  )
  out <- .batch_chirps(reqs, retrieved_at = "t0")
  expect_equal(out[[1L]]$date, as.Date(c("2019-12-30", "2019-12-31",
                                             "2020-01-01", "2020-01-02")))
  expect_identical(out[[1L]]$value, c(30, 31, 1, 2))
  # the upstream missing-value code never becomes rainfall
  expect_true(is_refusal(out[[2L]]))
})

test_that("elevation reads height and slope; flat ground has zero slope", {
  skip_if_not_installed("geodata")
  skip_if_not_installed("terra")
  testthat::local_mocked_bindings(
    elevation_3s = function(lon, lat, path, ...) {
      r <- terra::rast(nrows = 20, ncols = 20, xmin = 135, xmax = 140,
                       ymin = -35, ymax = -30)
      terra::values(r) <- 250
      r
    },
    .package = "geodata"
  )
  reqs <- list(geo_point_request(137.5, -32.5, source = "elevation"))
  out <- .batch_elevation(reqs, retrieved_at = "t0")
  expect_s3_class(out[[1L]], "geo_point_series")
  expect_identical(out[[1L]]$variable, c("elevation", "slope"))
  expect_equal(out[[1L]]$value, c(250, 0))
  expect_identical(out[[1L]]$unit, c("m", "degree"))
})

test_that("elevation refuses beyond 60 degrees and where no tile exists", {
  reqs <- list(geo_point_request(20, 70, source = "elevation"))
  out <- .batch_elevation(reqs, retrieved_at = "t0")
  expect_true(is_refusal(out[[1L]]))
  expect_match(out[[1L]]$reason, "60 S to 60 N")

  skip_if_not_installed("geodata")
  skip_if_not_installed("terra")
  testthat::local_mocked_bindings(
    elevation_3s = function(...) stop("tile not found"),
    .package = "geodata"
  )
  out <- .adapter_elevation(geo_point_request(-30, 0, source = "elevation"),
                            retrieved_at = "t0")
  expect_true(is_refusal(out))
  expect_match(out$reason, "no value")
})
