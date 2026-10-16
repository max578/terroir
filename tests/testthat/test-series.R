make_long <- function() {
  data.table::data.table(
    date = as.Date(c("2020-01-01", "2020-01-02")),
    variable = c("T2M", "T2M"),
    value = c(20.1, 21.3)
  )
}

test_that("new_geo_point_series builds the C6 schema with provenance", {
  s <- new_geo_point_series(
    make_long(), lon = 138.6, lat = -34.92, source = "test",
    source_version = "1.0", license = "free", retrieved_at = "2026-06-02 00:00:00",
    call = "test()"
  )
  expect_s3_class(s, "geo_point_series")
  expect_true(all(terroir:::.geo_point_cols %in% names(s)))
  expect_identical(names(s)[seq_along(terroir:::.geo_point_cols)],
                   terroir:::.geo_point_cols)
  expect_true(verify_geo_series(s))
  prov <- attr(s, "provenance")
  expect_true(all(c("source", "source_version", "retrieved_at", "license", "call")
                  %in% names(prov)))
})

test_that("verify_geo_series fails loudly on a malformed series", {
  s <- new_geo_point_series(
    make_long(), lon = 1, lat = 1, source = "t", source_version = "1",
    license = "free", retrieved_at = "t", call = "t()"
  )
  bad <- data.table::copy(s)
  bad[, value := NULL]
  expect_error(verify_geo_series(bad), "missing contract columns")

  noprov <- data.table::copy(s)
  data.table::setattr(noprov, "provenance", NULL)
  expect_error(verify_geo_series(noprov), "provenance")

  expect_error(verify_geo_series(make_long()), "geo_point_series")
})

test_that("a series prints its row count, source and variables", {
  s <- new_geo_point_series(
    make_long(), lon = 138.6, lat = -34.92, source = "test",
    source_version = "1.0", license = "free", retrieved_at = "t",
    call = "test()"
  )
  table <- utils::capture.output(header <- cli::cli_fmt(print(s)))
  header <- paste(header, collapse = "\n")
  expect_match(header, "2 rows")
  expect_match(header, "test")
  expect_match(header, "T2M")
  # the rows themselves follow the header
  expect_true(any(grepl("21.3", table, fixed = TRUE)))
})
