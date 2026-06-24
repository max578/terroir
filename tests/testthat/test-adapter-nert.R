# The nert / TERN adapter. nert is the flagship co-hallucinated-oracle case, so
# these tests pin the IOP discipline: it refuses keyless (no fabricated data), it
# parses a real-shaped return into a contract series, and the facts it asserts
# about TERN's catalogue stay honestly `[unverified]` (its oracle is TERN, not
# nert's own grounding).

test_that("nert is a registered, free, Australia-extent source", {
  src <- list_sources()
  expect_true("nert" %in% src$id)
  row <- src[src$id == "nert", ]
  expect_identical(row$package[[1L]], "nert")
  expect_true(isTRUE(row$free[[1L]]))
})

test_that("the nert adapter refuses cleanly without a TERN API key", {
  withr::local_envvar(TERN_API_KEY = "")
  req <- list(lon = 138.6, lat = -34.9, start = "2024-01-01",
              end = "2024-01-02", variables = "SMIPS")
  res <- terroir:::.adapter_nert(req, Sys.time())
  expect_true(is_refusal(res))
  expect_match(res$reason, "TERN", ignore.case = TRUE)
})

test_that("the nert adapter parses a TERN return into a contract series", {
  skip_if_not_installed("nert")
  withr::local_envvar(TERN_API_KEY = "test-key")
  fake <- function(date_range, lon, lat, datasets, api_key, verbose, na.rm, ...) {
    data.table::data.table(
      date = as.Date("2024-01-01"), lon = lon, lat = lat,
      SMIPS_totalbucket = 0.42, SMIPS_SMindex = 0.31,
      ASC = "Vertosol"            # a character layer -> must be dropped, not coerced
    )
  }
  ok <- tryCatch({
    testthat::local_mocked_bindings(collect_tern_data = fake, .package = "nert")
    TRUE
  }, error = function(e) FALSE)
  skip_if_not(ok, "could not mock nert::collect_tern_data here")
  req <- list(lon = 138.6, lat = -34.9, start = "2024-01-01",
              end = "2024-01-01", variables = "SMIPS")
  res <- terroir:::.adapter_nert(req, Sys.time())
  expect_s3_class(res, "geo_point_series")
  expect_true(all(c("SMIPS_totalbucket", "SMIPS_SMindex") %in% res$variable))
  expect_false("ASC" %in% res$variable)          # character layer dropped (IOP)
  expect_true(all(is.finite(res$value)))
  expect_identical(unique(res$source), "nert")
})

test_that("nert's TERN-catalogue facts are honestly [unverified]", {
  facts <- terroir_external_facts()
  nert_rows <- facts[facts$source == "nert", ]
  expect_true(nrow(nert_rows) >= 1L)
  # not grounded by trusting the source: its verified_on is NA
  expect_true(all(is.na(nert_rows$verified_on)))
  st <- terroir_fact_status()
  nert_st <- st[st$source == "nert", ]
  expect_true(all(nert_st$status == "[unverified]"))
})
