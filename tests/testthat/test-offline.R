# Offline / fixture-replay mode. These run with zero network and (because they
# read shipped .rds fixtures, not adapters) with no Suggests package installed.
# They point the fixture resolver at the source-tree inst/fixtures via the
# terroir.fixture_dir option, so the test is independent of install state.

fixture_dir <- function() {
  # Walk up from the test dir to the package root, then inst/fixtures. Under
  # devtools::test() the working directory is tests/testthat.
  candidates <- c(
    testthat::test_path("..", "..", "inst", "fixtures"),
    system.file("fixtures", package = "terroir")
  )
  for (d in candidates) if (nzchar(d) && dir.exists(d)) return(normalizePath(d))
  ""
}

with_fixtures <- function(code) {
  testthat::skip_if_not_installed("withr")
  d <- fixture_dir()
  testthat::skip_if(!nzchar(d), "no inst/fixtures directory available")
  withr::with_options(list(terroir.fixture_dir = d), code)
}

test_that("offline replay returns the matching fixture marked replayed", {
  with_fixtures({
    req <- geo_point_request(138.6, -34.92, "2020-01-01", "2020-01-10",
                             variables = c("T2M", "PRECTOTCORR"),
                             source = "nasapower")
    s <- collect_point(req, offline = TRUE)
    expect_s3_class(s, "geo_point_series")
    expect_true(is_replayed(s))
    # The replayed series keeps the fixture's recorded timestamp, never now.
    expect_identical(attr(s, "provenance")$retrieved_at, "2026-06-02 00:00:00")
    expect_gt(nrow(s), 0L)
    expect_true(verify_geo_series(s))
  })
})

test_that("the terroir.offline option drives offline mode globally", {
  with_fixtures({
    req <- geo_point_request(138.6, -34.92, "2020-01-01", "2020-01-10",
                             source = "silo")
    withr::with_options(list(terroir.offline = TRUE), {
      s <- collect_point(req)
    })
    expect_true(is_replayed(s))
    expect_identical(attr(s, "provenance")$source, "silo")
  })
})

test_that("offline mode never falls back to the network on a miss", {
  with_fixtures({
    # A point no fixture answers -> a structured refusal, not a network call.
    req <- geo_point_request(10, 50, "2020-01-01", "2020-01-10",
                             source = "nasapower")
    s <- collect_point(req, offline = TRUE)
    expect_true(is_refusal(s))
    expect_match(s$reason, "no recorded fixture answers")
    expect_match(s$reason, "never falls back to the network")
  })
})

test_that("offline mode refuses cleanly when no fixture directory is set", {
  skip_if_not_installed("withr")
  # An empty fixture-dir option and (in the installed-package case) no shipped
  # fixtures: the resolver finds nothing and refuses, never erroring.
  withr::with_options(list(terroir.fixture_dir = tempfile()), {
    req <- geo_point_request(138.6, -34.92, "2020-01-01", "2020-01-10",
                             source = "nasapower")
    s <- collect_point(req, offline = TRUE)
    expect_true(is_refusal(s))
  })
})

test_that("is_replayed is FALSE for a non-replayed series and a non-series", {
  s <- new_geo_point_series(
    data.table::data.table(date = as.Date("2020-01-01"), variable = "x",
                           value = 1, unit = NA_character_),
    lon = 138.6, lat = -34.9, source = "t", source_version = "0",
    license = "test", retrieved_at = "t", call = "t")
  expect_false(is_replayed(s))
  expect_false(is_replayed(list()))
  expect_false(is_replayed(NULL))
})

test_that("collect_point validates the offline argument", {
  req <- geo_point_request(138.6, -34.92, "2020-01-01", "2020-01-10",
                           source = "nasapower")
  expect_error(collect_point(req, offline = "yes"), "single logical")
  expect_error(collect_point(req, offline = NA), "single logical")
})
