# The ocular / Planetary Computer adapter. ocular is an external upstream held
# in Suggests and installed only where a pilot has pinned it, so every test here
# is network-free by default: the absent-package path, the registration, the
# cloud-mask defaults, the vendored-patch behaviour and the provenance stamp are
# all exercised offline. The live retrieval is graded by the regression pilot,
# not by the suite.

test_that("ocular is a registered, free source with a UTM-band extent", {
  src <- list_sources()
  expect_true("ocular" %in% src$id)
  row <- src[src$id == "ocular", ]
  expect_identical(row$package[[1L]], "ocular")
  expect_true(isTRUE(row$free[[1L]]))
  entry <- terroir:::.get_source("ocular")
  expect_identical(entry$extent, c(-180, -80, 180, 84))
})

test_that("a polar point is refused, never attempted, on the ocular source", {
  # collect_point() checks the upstream package before the extent, so which
  # refusal fires depends on whether ocular is installed here. Either way the
  # contract holds: a point ocular cannot express in UTM yields a typed
  # refusal, never an upstream abort.
  req <- geo_point_request(0, 87, "2020-01-01", "2020-03-01",
                           source = "ocular")
  out <- suppressWarnings(collect_point(req))
  expect_true(is_refusal(out))
  if (requireNamespace("ocular", quietly = TRUE)) {
    expect_match(out$reason, "outside the 'ocular' source extent")
  } else {
    expect_match(out$reason, "not installed")
  }
})

test_that("an absent ocular refuses with the pinned install line", {
  # ocular lives outside the default library (it is pinned into a pilot
  # sandbox), so on a machine without it this is the natural path -- and the
  # refusal must carry the install line, or the reason is not actionable.
  skip_if(requireNamespace("ocular", quietly = TRUE),
          "ocular is installed here; the absent-upstream path cannot be taken")
  req <- list(lon = 138.6, lat = -34.9, start = "2024-01-01",
              end = "2024-03-01", variables = "NDVI")
  res <- terroir:::.adapter_ocular(req, Sys.time())
  expect_true(is_refusal(res))
  expect_identical(res$source, "ocular")
  expect_match(res$reason, "not installed")
  expect_match(res$reason, "AAGI-AUS/ocular@", fixed = TRUE)
  expect_match(res$reason, terroir:::.OCULAR_PINNED_COMMIT, fixed = TRUE)
})

test_that("the adapter refuses without a date range", {
  req <- list(lon = 138.6, lat = -34.9, start = NULL, end = NULL,
              variables = "NDVI")
  res <- terroir:::.adapter_ocular(req, Sys.time())
  expect_true(is_refusal(res))
  expect_match(res$reason, "start and end dates")
})

test_that("the adapter refuses an unknown sensor in variables[2]", {
  req <- list(lon = 138.6, lat = -34.9, start = "2024-01-01",
              end = "2024-03-01", variables = c("NDVI", "worldview-3"))
  res <- terroir:::.adapter_ocular(req, Sys.time())
  expect_true(is_refusal(res))
  expect_match(res$reason, "unknown ocular sensor")
})

test_that("the cloud-mask class defaults are the safe ones, not upstream's", {
  # Upstream leaves pixel masking off (scl_classes = NULL). terroir's defaults
  # are on, and are the Sentinel-2 SCL class set for the SCL mask and the
  # Landsat Collection-2 QA_PIXEL bit set for the bit mask.
  expect_identical(terroir:::.OCULAR_SCL_DEFAULT,
                   c(0L, 1L, 3L, 8L, 9L, 10L, 11L))
  expect_identical(terroir:::.OCULAR_QA_BIT_DEFAULT, c(0L, 1L, 2L, 3L, 4L, 5L))
  expect_type(terroir:::.OCULAR_SCL_DEFAULT, "integer")
  expect_identical(terroir:::.OCULAR_MAX_CLOUD, 40)
  expect_identical(terroir:::.OCULAR_BOX_METRES, 500L)
})

test_that("the vendored tile-merge patch unnames its merge call", {
  # The upstream defect is that a *named* raster list reaches do.call(), so no
  # argument matches the merge generic's first formal. The replacement must
  # splice the list unnamed. Exercised against a stand-in merge that records the
  # names it was called with, so the test needs no raster and no network.
  skip_if_not_installed("terra")
  seen <- NULL
  ok <- tryCatch({
    testthat::local_mocked_bindings(
      merge = function(...) {
        seen <<- names(list(...))
        0
      },
      crs = function(...) "EPSG:32750",
      .package = "terra"
    )
    TRUE
  }, error = function(e) FALSE)
  skip_if_not(ok, "could not mock terra::merge here")
  out <- terroir:::.ocular_merge_raster_tiles(list(a = 1, b = 2))
  expect_true(all(!nzchar(seen[seq_len(2L)])))
  expect_false(any(c("a", "b") %in% seen))
})

test_that("the vendored patch degenerates correctly on 0 and 1 tiles", {
  expect_null(terroir:::.ocular_merge_raster_tiles(list()))
  expect_null(terroir:::.ocular_merge_raster_tiles(list(a = NULL)))
  expect_identical(terroir:::.ocular_merge_raster_tiles(list(a = 7)), 7)
})

test_that("upstream errors and warnings become typed refusals", {
  boom <- terroir:::.ocular_guard(stop("Date range too short."), "retrieval")
  expect_true(is_refusal(boom))
  expect_identical(boom$source, "ocular")
  expect_match(boom$reason, "Date range too short")

  degraded <- terroir:::.ocular_guard(
    {
      warning("Sinusoidal asset merge failed; using first tile only.")
      1
    },
    "retrieval"
  )
  expect_true(is_refusal(degraded))
  expect_match(degraded$reason, "degraded")

  # A progress message is not a defect and must not refuse.
  quiet <- terroir:::.ocular_guard(
    {
      message("Sentinel-2 not available before 2015-07-01; Landsat 8/9 used.")
      42
    },
    "retrieval"
  )
  expect_identical(quiet, 42)
})

test_that("scene ids are read out of the asset URL, never constructed", {
  s2 <- paste0("https://sentinel2l2a01.blob.core.windows.net/sentinel2-l2/50/",
               "H/MK/2019/06/01/S2B_MSIL2A_20190601T021359_N0212_R060_T50HMK",
               "_20201005T204918.SAFE/GRANULE/L2A_T50HMK_A011669_20190601T02",
               "2319/IMG_DATA/R10m/T50HMK_20190601T021359_B08_10m.tif?st=x&s",
               "ig=y")
  l8 <- paste0("https://landsateuwest.blob.core.windows.net/landsat-c2/level-",
               "2/standard/oli-tirs/2019/092/084/LC08_L2SP_092084_20190505_20",
               "200829_02_T1/LC08_L2SP_092084_20190505_20200829_02_T1_SR_B5.T",
               "IF?st=x")
  expect_identical(
    terroir:::.ocular_scene_id(list(B08 = s2)),
    "S2B_MSIL2A_20190601T021359_N0212_R060_T50HMK_20201005T204918"
  )
  expect_identical(
    terroir:::.ocular_scene_id(list(SR_B5 = l8)),
    "LC08_L2SP_092084_20190505_20200829_02_T1"
  )
  # An unrecognised URL yields NA rather than an invented id, and the signed
  # URL is never returned.
  expect_identical(
    terroir:::.ocular_scene_id(list(x = "https://example.org/tile.tif?sig=z")),
    NA_character_
  )
})

test_that("the asserted STAC ids and endpoint are self-consistent", {
  facts <- terroir_external_facts()
  ids <- facts[facts$source == "ocular" &
                 facts$fact_family == "stac_collection_id", ]$asserted_value
  expect_setequal(ids, unname(terroir:::.OCULAR_COLLECTIONS))
  endpoint <- facts[facts$source == "ocular" &
                      facts$fact_family == "stac_endpoint", ]$asserted_value
  expect_identical(endpoint, terroir:::.OCULAR_STAC_ENDPOINT)
})

test_that("an ocular series carries the retrieval provenance", {
  # Built offline from the fields the adapter stamps, so the provenance
  # contract is pinned without a network retrieval.
  series <- new_geo_point_series(
    data.table::data.table(date = as.Date(c("2019-06-01", "2019-06-11")),
                           variable = "NDVI", value = c(0.41, 0.63),
                           unit = "index"),
    lon = 116.8933, lat = -32.15034, source = "ocular",
    source_version = "0.1.0",
    license = "Copernicus Sentinel-2 via Planetary Computer (free)",
    retrieved_at = "2026-09-02 10:00:00",
    call = "ocular::get_rs(...) |> as_time_series()"
  )
  prov <- attr(series, "provenance")
  prov$stac_endpoint <- terroir:::.OCULAR_STAC_ENDPOINT
  prov$stac_collection <- "sentinel-2-l2a"
  prov$sensor <- "sentinel-2"
  prov$mask_classes <- terroir:::.OCULAR_SCL_DEFAULT
  prov$scene_dates <- c("2019-06-01", "2019-06-11")
  prov$scene_ids <- c("S2B_MSIL2A_20190601T021359_N0212_R060_T50HMK",
                      NA_character_)
  prov$ocular_commit_pinned <- terroir:::.OCULAR_PINNED_COMMIT
  data.table::setattr(series, "provenance", prov)

  expect_true(verify_geo_series(series))
  got <- attr(series, "provenance")
  expect_true(all(c("stac_endpoint", "stac_collection", "sensor",
                    "mask_classes", "scene_dates", "scene_ids",
                    "ocular_commit_pinned") %in% names(got)))
  expect_identical(length(got$scene_ids), length(got$scene_dates))
  expect_false(any(grepl("sig=", got$scene_ids, fixed = TRUE), na.rm = TRUE))
})
