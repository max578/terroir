# Offline unit tests for the Phase-1 FX-6 grounding guards: spatial-extent
# refusal, value-plausibility conformer, and registry extent validation.

test_that("collect_point refuses a point outside a source's declared extent", {
  au_bbox <- c(112, -44, 154, -10)
  register_source("test_au_only", function(request, retrieved_at) {
    new_geo_point_series(
      data.table::data.table(date = as.Date("2020-01-01"),
                             variable = "x", value = 1, unit = NA_character_),
      lon = request$lon, lat = request$lat, source = "test_au_only",
      source_version = "0", license = "test", retrieved_at = retrieved_at,
      call = "test")
  }, package = "utils", free = TRUE, description = "test", extent = au_bbox)

  # lasrosas, Argentina (~ -63.8, -33.9) -- outside the Australia bbox. The
  # refusal is visible (warns), matching terroir's other collect_point refusals.
  expect_warning(
    out <- collect_point(geo_point_request(-63.8, -33.9, source = "test_au_only")),
    "outside"
  )
  expect_true(is_refusal(out))
  expect_match(out$reason, "outside the 'test_au_only' source extent")

  # An in-extent point (Adelaide) passes the extent gate and returns a series.
  ok <- collect_point(geo_point_request(138.6, -34.9, source = "test_au_only"))
  expect_s3_class(ok, "geo_point_series")
})

test_that("register_source rejects a malformed extent", {
  expect_error(
    register_source("bad_extent", function(...) NULL, "utils", TRUE,
                    extent = c(1, 2, 3)),
    "must be NULL or numeric"
  )
})

test_that("verify_geo_series refuses an implausible NDVI value (scale error)", {
  # Un-scaled MOD13Q1 integers (~ thousands) instead of the 0.0001-scaled NDVI.
  s <- new_geo_point_series(
    data.table::data.table(date = as.Date("2020-01-01"),
                           variable = "250m_16_days_NDVI", value = 5400,
                           unit = "index"),
    lon = 138.6, lat = -34.9, source = "modis", source_version = "0",
    license = "test", retrieved_at = "t", call = "test")
  expect_error(verify_geo_series(s), "Implausible NDVI")
})

test_that("verify_geo_series accepts a plausible NDVI value", {
  s <- new_geo_point_series(
    data.table::data.table(date = as.Date("2020-01-01"),
                           variable = "250m_16_days_NDVI", value = 0.72,
                           unit = "index"),
    lon = 138.6, lat = -34.9, source = "modis", source_version = "0",
    license = "test", retrieved_at = "t", call = "test")
  expect_true(verify_geo_series(s))
})

test_that("verify_geo_series refuses an implausible temperature value", {
  s <- new_geo_point_series(
    data.table::data.table(date = as.Date("2020-01-01"),
                           variable = "air_tmax", value = 999, unit = "degC"),
    lon = 138.6, lat = -34.9, source = "silo", source_version = "0",
    license = "test", retrieved_at = "t", call = "test")
  expect_error(verify_geo_series(s), "Implausible temperature")
})
