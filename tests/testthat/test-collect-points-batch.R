# One answer per request, the same whether a source answers in a batch or one
# request at a time.
.toy_answer <- function(request, retrieved_at) {
  dates <- seq(as.Date(request$start), as.Date(request$end), by = "day")
  new_geo_point_series(
    data.table::data.table(
      date = rep(dates, each = length(request$variables)),
      variable = rep(request$variables, times = length(dates)),
      value = request$lon + seq_along(dates) / 10,
      unit = "mm"
    ),
    lon = request$lon, lat = request$lat, source = "toy",
    source_version = "0", license = "test", retrieved_at = retrieved_at,
    call = "toy()"
  )
}

.toy_requests <- function(source) {
  list(
    geo_point_request(138.6, -34.9, "2020-01-01", "2020-01-03",
                      variables = "rain", source = source),
    geo_point_request(117.0, -31.5, "2020-02-01", "2020-02-01",
                      variables = "rain", source = source),
    geo_point_request(10.0, 45.0, "2020-01-01", "2020-01-02",
                      variables = "rain", source = source),
    geo_point_request(149.1, -35.3, "2020-03-01", "2020-03-05",
                      variables = c("rain", "wind"), source = source)
  )
}

test_that("a batch source gives the same rows as the one-at-a-time path", {
  calls <- new.env()
  calls$n <- 0L
  au <- c(112, -44, 154, -10)
  register_source("toy_loop", .toy_answer, package = "utils", free = TRUE,
                  extent = au)
  register_source("toy_batch", .toy_answer, package = "utils", free = TRUE,
                  extent = au,
                  batch = function(requests, retrieved_at) {
                    calls$n <- calls$n + 1L
                    calls$vars <- c(calls$vars, length(unique(lapply(
                      requests, function(r) r$variables
                    ))))
                    calls$size <- c(calls$size, length(requests))
                    lapply(requests, .toy_answer, retrieved_at = retrieved_at)
                  })

  out_loop <- suppressWarnings(collect_points(.toy_requests("toy_loop"), retrieved_at = "t0"))
  out_batch <- suppressWarnings(collect_points(.toy_requests("toy_batch"), retrieved_at = "t0"))

  # the source id appears in the source column and in a refusal's reason
  out_loop[, source := NULL]
  out_batch[, source := NULL]
  out_loop[, reason := sub("toy_loop", "toy", reason, fixed = TRUE)]
  out_batch[, reason := sub("toy_batch", "toy", reason, fixed = TRUE)]
  expect_identical(out_batch, out_loop)
  expect_identical(
    out_batch[status == "refused", request_index], 3L
  )
  # one call per variable group, each with a single variable list, and the
  # out-of-extent request never reaches the batch
  expect_identical(calls$n, 2L)
  expect_identical(calls$vars, c(1L, 1L))
  expect_identical(sum(calls$size), 3L)
  expect_identical(nrow(out_batch[request_index == 4L]), 10L)
  expect_identical(unique(out_batch[status == "ok", call]), "toy()")
})

test_that("a batch adapter returning the wrong number of answers is an error", {
  register_source("toy_short", .toy_answer, package = "utils", free = TRUE,
                  batch = function(requests, retrieved_at) list())
  expect_error(
    collect_points(.toy_requests("toy_short")[1:2], retrieved_at = "t0"),
    "one answer per request"
  )
})

test_that("register_source rejects a batch that is not a function", {
  expect_error(
    register_source("toy_bad", .toy_answer, package = "utils", free = TRUE,
                    batch = "no"),
    "must be NULL or a function"
  )
})
