# test-adapter-isric.R -- the global soil profile.
#
# The gap a running study had to route around: a grain decision needs soil as
# much as weather, and terroir served none, so the A0 belt generator reached
# past terroir into apsimx and left an uplift note behind.

test_that("isric is registered and keyless", {
  srcs <- list_sources()
  expect_true("isric" %in% srcs$id)
  row <- srcs[srcs$id == "isric", ]
  expect_identical(row$package, "apsimx")
  expect_true(row$free)
})

test_that("isric does not intersect nert: it is global where nert is not", {
  # Tested behaviourally rather than by reading the registry. nert serves TERN
  # soil over Australia only and needs a key; isric is global and keyless, so a
  # point outside Australia must be refused by one and admitted by the other.
  # That is the whole reason both exist.
  kansas <- list(lon = -98.0, lat = 38.5)
  n_req <- geo_point_request(lon = kansas$lon, lat = kansas$lat, source = "nert")
  expect_true(is_refusal(collect_point(n_req, offline = TRUE)))
  i_req <- geo_point_request(lon = kansas$lon, lat = kansas$lat, source = "isric")
  out <- collect_point(i_req, offline = TRUE)
  # offline has no fixture for Kansas, so this refuses on the fixture, never on
  # an extent: the distinction is what proves isric is not extent-limited.
  if (is_refusal(out)) expect_match(out$reason, "offline|fixture")
})

test_that("an offline soil profile satisfies contract C6", {
  req <- geo_point_request(lon = 138.69, lat = -34.51, source = "isric",
                           variables = c("clay", "carbon", "ph", "dul", "ll15"))
  s <- collect_point(req, offline = TRUE)
  expect_false(is_refusal(s))
  expect_s3_class(s, "geo_point_series")
  expect_true(verify_geo_series(s))
  expect_true(all(c("lon", "lat", "date", "variable", "value", "unit",
                    "source", "source_version", "retrieved_at", "license")
                  %in% names(s)))
  # five properties over the profile's depth layers
  expect_identical(length(unique(sub("_[0-9].*$", "", s$variable))), 5L)
  expect_true(all(grepl("cm$", s$variable)))
  expect_true(is.numeric(s$value))
})

test_that("soil is dateless on purpose, not by omission", {
  req <- geo_point_request(lon = 138.69, lat = -34.51, source = "isric",
                           variables = c("clay", "carbon", "ph", "dul", "ll15"))
  s <- collect_point(req, offline = TRUE)
  expect_false(is_refusal(s))
  expect_gt(nrow(s), 0L)
  # Stamping the retrieval date on a time-invariant property would invite a
  # consumer to difference two retrievals as though something had changed.
  expect_true(all(is.na(s$date)))
})

test_that("units ride with the values", {
  req <- geo_point_request(lon = 138.69, lat = -34.51, source = "isric",
                           variables = c("clay", "carbon", "ph", "dul", "ll15"))
  s <- collect_point(req, offline = TRUE)
  expect_false(is_refusal(s))
  u <- unique(s$unit[grepl("^clay_", s$variable)])
  expect_identical(u, "%")
  u2 <- unique(s$unit[grepl("^ph_", s$variable)])
  if (length(u2)) expect_identical(u2, "pH")
})

test_that("a variable the source does not serve is refused typed", {
  req <- geo_point_request(lon = 138.69, lat = -34.51, source = "isric",
                           variables = c("clay", "unobtainium"))
  s <- terroir:::.adapter_isric(req, retrieved_at = Sys.time())
  expect_true(is_refusal(s))
  expect_match(s$reason, "unobtainium")
})

test_that("the plausibility conformer catches a soil scale error", {
  # SoilGrids' own service returns integers scaled by ten; apsimx unscales them,
  # so the error is one upstream change away rather than impossible.
  f <- terroir:::.check_value_ranges
  ok  <- data.frame(variable = "clay_0_5cm", value = 16.9, unit = "%")
  bad <- data.frame(variable = "clay_0_5cm", value = 169,  unit = "%")
  expect_null(f(ok))
  expect_match(f(bad), "Implausible soil value")
  expect_match(f(data.frame(variable = "ph_0_5cm", value = 77, unit = "pH")),
               "Implausible soil value")
  expect_null(f(data.frame(variable = "ph_0_5cm", value = 7.7, unit = "pH")))
})

test_that("the statistic is selectable, and an unavailable quantile is refused", {
  # ISRIC publishes Q0.05/Q0.5/Q0.95; the upstream wrapper exposes only mean and
  # median. Asking for a quantile it cannot serve must refuse, not silently
  # return the mean under a quantile's name.
  req <- geo_point_request(lon = 138.69, lat = -34.51, source = "isric",
                           variables = "clay")
  req$statistic <- "Q0.95"
  out <- terroir:::.adapter_isric(req, retrieved_at = Sys.time())
  expect_true(is_refusal(out))
  expect_match(out$reason, "Q0.95")
  expect_match(out$reason, "no other quantile")
})
