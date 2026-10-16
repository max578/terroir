# The CORE adapters (nasapower, SILO, MODIS, ABARES, Sentinel-2 via rsi) with
# each upstream call mocked by a small table or raster of known values.

test_that("nasapower refuses a request without dates", {
  req <- geo_point_request(138.6, -34.92, source = "nasapower")
  out <- .adapter_nasapower(req, retrieved_at = "t0")
  expect_true(is_refusal(out))
  expect_match(out$reason, "start and end")
})

test_that("nasapower reshapes the daily table into one row per day and variable", {
  skip_if_not_installed("nasapower")
  testthat::local_mocked_bindings(
    get_power = function(community, lonlat, pars, dates, temporal_api, ...) {
      data.frame(
        LON = lonlat[1], LAT = lonlat[2], YEAR = 2020, MM = 1, DD = 1:2,
        DOY = 1:2, YYYYMMDD = as.Date(c("2020-01-01", "2020-01-02")),
        T2M = c(20.5, 21.5), PRECTOTCORR = c(0, 3.2)
      )
    },
    .package = "nasapower"
  )
  req <- geo_point_request(138.6, -34.92, "2020-01-01", "2020-01-02",
                           variables = c("T2M", "PRECTOTCORR"),
                           source = "nasapower")
  out <- .adapter_nasapower(req, retrieved_at = "t0")
  expect_s3_class(out, "geo_point_series")
  expect_true(verify_geo_series(out))
  expect_identical(nrow(out), 4L)
  expect_setequal(unique(out$variable), c("T2M", "PRECTOTCORR"))
  expect_identical(out$value[out$variable == "T2M" & out$date == as.Date("2020-01-02")],
                   21.5)
  expect_identical(attr(out, "provenance")$source, "nasapower")
})

test_that("nasapower turns an upstream error into a refusal", {
  skip_if_not_installed("nasapower")
  testthat::local_mocked_bindings(
    get_power = function(...) stop("HTTP 503"),
    .package = "nasapower"
  )
  req <- geo_point_request(138.6, -34.92, "2020-01-01", "2020-01-02",
                           source = "nasapower")
  out <- .adapter_nasapower(req, retrieved_at = "t0")
  expect_true(is_refusal(out))
  expect_match(out$reason, "HTTP 503")
})

test_that("SILO refuses without an API key", {
  withr::local_envvar(SILO_API_KEY = "", WEATHEROZ_SILO_KEY = "")
  req <- geo_point_request(138.6, -34.92, "2020-01-01", "2020-01-02",
                           source = "silo")
  out <- .adapter_silo(req, retrieved_at = "t0")
  expect_true(is_refusal(out))
  expect_match(out$reason, "API key")
})

test_that("SILO keeps measurements with their units and drops the source flags", {
  skip_if_not_installed("weatherOz")
  withr::local_envvar(SILO_API_KEY = "someone@example.org")
  testthat::local_mocked_bindings(
    get_data_drill = function(longitude, latitude, start_date, end_date,
                              values, api_key, ...) {
      data.frame(
        longitude = longitude, latitude = latitude, year = 2020, month = 1,
        day = 1:2, date = as.Date(c("2020-01-01", "2020-01-02")),
        extracted = as.Date("2026-01-01"),
        air_tmax = c(31.0, 33.5), air_tmax_source = c(25, 25),
        rainfall = c(0, 2.4), rainfall_source = c(25, 25)
      )
    },
    .package = "weatherOz"
  )
  req <- geo_point_request(138.6, -34.92, "2020-01-01", "2020-01-02",
                           source = "silo")
  out <- .adapter_silo(req, retrieved_at = "t0")
  expect_s3_class(out, "geo_point_series")
  expect_setequal(unique(out$variable), c("air_tmax", "rainfall"))
  expect_identical(unique(out$unit[out$variable == "air_tmax"]), "degC")
  expect_identical(unique(out$unit[out$variable == "rainfall"]), "mm")
  expect_identical(out$value[out$variable == "rainfall"], c(0, 2.4))
})

test_that("SILO refuses a return with no date column", {
  skip_if_not_installed("weatherOz")
  withr::local_envvar(SILO_API_KEY = "someone@example.org")
  testthat::local_mocked_bindings(
    get_data_drill = function(...) data.frame(air_tmax = 30),
    .package = "weatherOz"
  )
  req <- geo_point_request(138.6, -34.92, "2020-01-01", "2020-01-02",
                           source = "silo")
  out <- .adapter_silo(req, retrieved_at = "t0")
  expect_true(is_refusal(out))
  expect_match(out$reason, "no date column")
})

test_that("MODIS NDVI is multiplied by the scale factor the upstream reports", {
  skip_if_not_installed("MODISTools")
  testthat::local_mocked_bindings(
    mt_subset = function(product, lat, lon, band, start, end, ...) {
      data.frame(calendar_date = c("2020-01-01", "2020-01-17"), band = band,
                 value = c(5000L, 7342L), scale = "0.0001")
    },
    .package = "MODISTools"
  )
  req <- geo_point_request(138.6, -34.92, "2020-01-01", "2020-01-31",
                           source = "modis")
  out <- .adapter_modis(req, retrieved_at = "t0")
  expect_s3_class(out, "geo_point_series")
  # MOD13Q1 NDVI is stored as an integer times 10,000
  expect_equal(out$value, c(0.5, 0.7342))
  expect_identical(out$date, as.Date(c("2020-01-01", "2020-01-17")))
  expect_identical(unique(out$variable), "250m_16_days_NDVI")
  expect_identical(unique(out$unit), "index")
})

test_that("MODIS refuses rather than guess a missing scale factor", {
  skip_if_not_installed("MODISTools")
  testthat::local_mocked_bindings(
    mt_subset = function(...) {
      data.frame(calendar_date = "2020-01-01", value = 5000L)
    },
    .package = "MODISTools"
  )
  req <- geo_point_request(138.6, -34.92, "2020-01-01", "2020-01-31",
                           source = "modis")
  out <- .adapter_modis(req, retrieved_at = "t0")
  expect_true(is_refusal(out))
  expect_match(out$reason, "scale factor")
})

test_that("MODIS refuses a return with no value column", {
  skip_if_not_installed("MODISTools")
  testthat::local_mocked_bindings(
    mt_subset = function(...) data.frame(calendar_date = "2020-01-01"),
    .package = "MODISTools"
  )
  req <- geo_point_request(138.6, -34.92, "2020-01-01", "2020-01-31",
                           source = "modis")
  out <- .adapter_modis(req, retrieved_at = "t0")
  expect_true(is_refusal(out))
  expect_match(out$reason, "unexpected shape")
})

test_that("ABARES extracts every layer of the most recent raster at the point", {
  skip_if_not_installed("read.abares")
  skip_if_not_installed("terra")
  layer_raster <- function(values) {
    r <- terra::rast(nrows = 4, ncols = 4, nlyrs = 2, xmin = 140, xmax = 142,
                     ymin = -36, ymax = -34)
    terra::values(r[[1L]]) <- values[1L]
    terra::values(r[[2L]]) <- values[2L]
    names(r) <- c("farm_receipts", "farm_costs")
    r
  }
  testthat::local_mocked_bindings(
    read_agfd_terra = function(...) list(layer_raster(c(1, 2)),
                                         layer_raster(c(150000, 90000))),
    .package = "read.abares"
  )
  req <- geo_point_request(140.7, -35.3, source = "abares")
  out <- .adapter_abares(req, retrieved_at = "t0")
  expect_s3_class(out, "geo_point_series")
  expect_identical(out$variable, c("farm_receipts", "farm_costs"))
  expect_identical(out$value, c(150000, 90000))
  expect_true(all(is.na(out$date)))
})

test_that("ABARES turns an upstream error into a refusal", {
  skip_if_not_installed("read.abares")
  skip_if_not_installed("terra")
  testthat::local_mocked_bindings(
    read_agfd_terra = function(...) stop("download interrupted"),
    .package = "read.abares"
  )
  req <- geo_point_request(140.7, -35.3, source = "abares")
  out <- .adapter_abares(req, retrieved_at = "t0")
  expect_true(is_refusal(out))
  expect_match(out$reason, "download interrupted")
})

test_that("Sentinel-2 NDVI is (NIR - red) / (NIR + red) at the point", {
  skip_if_not_installed("rsi")
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")
  testthat::local_mocked_bindings(
    get_sentinel2_imagery = function(aoi, start_date, end_date,
                                     output_filename, ...) {
      bb <- sf::st_bbox(aoi)
      r <- terra::rast(nrows = 4, ncols = 4, nlyrs = 2,
                       xmin = bb[["xmin"]], xmax = bb[["xmax"]],
                       ymin = bb[["ymin"]], ymax = bb[["ymax"]],
                       crs = "EPSG:3857")
      terra::values(r[[1L]]) <- 0.5
      terra::values(r[[2L]]) <- 0.1
      names(r) <- c("N", "R")
      terra::writeRaster(r, output_filename)
      output_filename
    },
    .package = "rsi"
  )
  req <- geo_point_request(138.6, -34.92, "2020-01-01", "2020-01-31",
                           source = "stac")
  out <- .adapter_rsi(req, retrieved_at = "t0")
  expect_s3_class(out, "geo_point_series")
  expect_equal(out$value, (0.5 - 0.1) / (0.5 + 0.1), tolerance = 1e-6)
  expect_identical(out$variable, "NDVI")
  expect_identical(out$date, as.Date("2020-01-31"))
})

test_that("Sentinel-2 turns an upstream error into a refusal", {
  skip_if_not_installed("rsi")
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")
  testthat::local_mocked_bindings(
    get_sentinel2_imagery = function(...) stop("no scenes"),
    .package = "rsi"
  )
  req <- geo_point_request(138.6, -34.92, "2020-01-01", "2020-01-31",
                           source = "stac")
  out <- .adapter_rsi(req, retrieved_at = "t0")
  expect_true(is_refusal(out))
  expect_match(out$reason, "no scenes")
})
