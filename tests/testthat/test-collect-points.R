test_that("collect_points batches requests, keeps refusals as rows (T-11)", {
  register_source("test_batch_ok", function(request, retrieved_at) {
    new_geo_point_series(
      data.table::data.table(date = as.Date("2020-01-01"),
                             variable = "x", value = 1, unit = NA_character_),
      lon = request$lon, lat = request$lat, source = "test_batch_ok",
      source_version = "0", license = "test", retrieved_at = retrieved_at,
      call = "test")
  }, package = "utils", free = TRUE, description = "test")

  reqs <- list(
    geo_point_request(138.6, -34.9, source = "test_batch_ok"),
    geo_point_request(0, 0, source = "no_such_source")
  )
  out <- suppressWarnings(collect_points(reqs))
  expect_s3_class(out, "data.table")
  expect_identical(nrow(out), 2L)
  expect_true("status" %in% names(out))
  expect_identical(out$status, c("ok", "refused"))
  expect_true(any(out$status == "refused"))
})
