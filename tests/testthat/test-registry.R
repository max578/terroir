test_that("the CORE adapters are registered on load", {
  src <- list_sources()
  expect_true(all(c("nasapower", "silo", "abares", "modis", "stac") %in% src$id))
  expect_true(all(src$free))
})

test_that("register_source enforces the free-only role rule", {
  expect_error(
    register_source("paid", function(request, retrieved_at) NULL,
                    package = "x", free = FALSE),
    "free-only"
  )
  expect_error(register_source("", function() NULL, "x", TRUE), "non-empty")
})
