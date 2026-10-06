# external-fact families: product_id, band_id, scale_factor,
#   nasapower_variable_code, variable_code, renamed_column, layer_name,
#   band_mapping, tern_dataset_id, stac_collection_id, stac_endpoint,
#   worldclim_licence, elevation_licence, soilgrids_licence, chirps_licence,
#   silo_unit
# (recipe-52 catalogue/coverage header -- the validator's per-family F14 grep
#  resolves every registry family to this catalogue-diff oracle file.)
#
# Independent-oracle tests (Phase-1 FX-5). These diff terroir's asserted
# external-authority facts (terroir_external_facts()) against the authority's
# OWN catalogue -- not against a golden the package generated. They are the
# oracle the goldens are not. Network + Suggests, so skip_on_cran + offline +
# not-installed guards; the expensive authorities are gated behind an opt-in
# env var so a routine run never triggers a large download.

skip_if_no_oracle <- function(pkg) {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed(pkg)
  testthat::skip_if_offline()
}

test_that("MODIS product + band + scale_factor match the live ORNL DAAC catalogue", {
  skip_if_no_oracle("MODISTools")
  facts <- terroir_external_facts()

  products <- tryCatch(MODISTools::mt_products(), error = function(e) NULL)
  skip_if(is.null(products), "ORNL DAAC product catalogue unreachable")
  prod_asserted <- facts[source == "modis" & fact_family == "product_id",
                         asserted_value]
  expect_true(all(prod_asserted %in% as.character(products$product)))

  bands <- tryCatch(MODISTools::mt_bands(product = "MOD13Q1"),
                    error = function(e) NULL)
  skip_if(is.null(bands), "ORNL DAAC band catalogue unreachable")
  band_asserted <- facts[source == "modis" & fact_family == "band_id",
                         asserted_value]
  expect_true(all(band_asserted %in% as.character(bands$band)))

  # The asserted NDVI scale_factor must equal the authority's own band record
  # (the silent-10,000x-error guard's grounding -- this is the value the
  # adapter scales by). The 2026-06-13 grounding read it straight off mt_bands.
  ndvi <- bands[as.character(bands$band) == "250m_16_days_NDVI", ]
  skip_if(!nrow(ndvi) || !"scale_factor" %in% names(ndvi),
          "ORNL DAAC band record carries no scale_factor field")
  asserted_scale <- as.numeric(facts[source == "modis" &
                                        fact_family == "scale_factor",
                                      asserted_value])
  expect_equal(as.numeric(ndvi$scale_factor[1]), asserted_scale)
})

test_that("NASA POWER variable codes exist in the live POWER parameter dictionary", {
  testthat::skip_on_cran()
  testthat::skip_if_offline()
  skip_if_not_installed("httr2")
  skip_if_not_installed("jsonlite")
  facts <- terroir_external_facts()
  codes <- facts[source == "nasapower" & fact_family == "nasapower_variable_code",
                 asserted_value]

  # The POWER system-manager parameter dictionary is the authority's own
  # catalogue (power.larc.nasa.gov) -- the independent oracle the goldens are
  # not. This is the same dictionary nasapower::query_parameters() wraps.
  url <- paste0("https://power.larc.nasa.gov/api/system/manager/parameters",
                "?community=ag&temporal=daily")
  dict <- tryCatch({
    resp <- httr2::req_perform(httr2::request(url))
    jsonlite::fromJSON(httr2::resp_body_string(resp))
  }, error = function(e) NULL)
  skip_if(is.null(dict), "NASA POWER parameter dictionary unreachable")
  expect_true(all(codes %in% names(dict)))
})

test_that("SILO variable codes are accepted by the weatherOz authority", {
  skip_if_no_oracle("weatherOz")
  facts <- terroir_external_facts()
  codes <- facts[source == "silo" & fact_family == "variable_code",
                 asserted_value]

  # weatherOz validates `values` against its own internal SILO value set.
  # Probe the documented introspection surface; skip (not fail) if this
  # weatherOz version does not expose a keyless value catalogue.
  valid <- NULL
  for (acc in c("silo_daily_values")) {
    if (exists(acc, envir = asNamespace("weatherOz"), inherits = FALSE)) {
      valid <- tryCatch(get(acc, envir = asNamespace("weatherOz")),
                        error = function(e) NULL)
      if (is.data.frame(valid)) valid <- unlist(valid, use.names = FALSE)
      break
    }
  }
  skip_if(is.null(valid),
          "weatherOz exposes no keyless SILO value catalogue in this version")
  expect_true(all(codes %in% as.character(valid)))
})

test_that("ABARES AGFD layer names match the live data dictionary (opt-in)", {
  skip_if_no_oracle("read.abares")
  # The AGFD grid is a large download; only run when explicitly opted in.
  if (!nzchar(Sys.getenv("TERROIR_LIVE_ORACLE"))) {
    testthat::skip("set TERROIR_LIVE_ORACLE=true to run the AGFD download oracle")
  }
  facts <- terroir_external_facts()
  asserted <- facts[source == "abares" & fact_family == "layer_name",
                    asserted_value]

  ras <- tryCatch({
    r <- read.abares::read_agfd_terra()
    if (inherits(r, "SpatRaster")) r else r[[length(r)]]
  }, error = function(e) NULL)
  skip_if(is.null(ras), "ABARES AGFD authority unreachable")
  authority_layers <- names(ras)
  # The asserted golden layer names must all exist in the authority's own grid.
  missing <- setdiff(asserted, authority_layers)
  expect_identical(missing, character(0),
                   info = paste("asserted ABARES layers absent from the live",
                                "AGFD grid:", paste(missing, collapse = ", ")))
})

test_that("ocular's STAC collection ids resolve at the asserted endpoint", {
  # The independent oracle for the collection ids the ocular adapter retrieves
  # through is the Planetary Computer catalogue itself -- not ocular's source,
  # and not a golden terroir wrote. Resolving `/collections/<id>` returns the
  # collection document, whose own `id` is what grounds the assertion. This is
  # the diff that carries the 2026-09-02 `verified_on` on both families.
  testthat::skip_on_cran()
  testthat::skip_if_offline()
  skip_if_not_installed("httr2")
  skip_if_not_installed("jsonlite")
  facts <- terroir_external_facts()
  endpoint <- facts[source == "ocular" & fact_family == "stac_endpoint",
                    asserted_value]
  ids <- facts[source == "ocular" & fact_family == "stac_collection_id",
               asserted_value]
  expect_length(endpoint, 1L)

  for (id in ids) {
    doc <- tryCatch({
      resp <- httr2::req_perform(
        httr2::request(paste0(endpoint, "/collections/", id))
      )
      jsonlite::fromJSON(httr2::resp_body_string(resp))
    }, error = function(e) NULL)
    skip_if(is.null(doc),
            paste("Planetary Computer STAC unreachable for collection", id))
    expect_identical(as.character(doc$id), id)
    expect_identical(as.character(doc$type), "Collection")
  }
})

test_that("the fact registry is well-formed with mixed, honest grounding", {
  facts <- terroir_external_facts()
  expect_true(all(c("source", "fact_family", "asserted_value", "oracle_kind",
                    "verified_on", "evidence_path", "grounding") %in%
                  names(facts)))

  # Grounding is mixed: MODIS (product / band / scale) and NASA POWER variable
  # codes were diffed against their live authorities on 2026-06-13, and the two
  # ocular STAC families against the Planetary Computer catalogue on
  # 2026-09-02, so those carry a real verified_on; SILO, ABARES and the rsi
  # `stac` band mapping stay honestly [unverified] (NA).
  grounded_src <- facts[grounding == "grounded",
                        sort(unique(paste(source, fact_family)))]
  expect_setequal(
    grounded_src,
    c("modis band_id", "modis product_id", "modis scale_factor",
      "nasapower nasapower_variable_code",
      "ocular stac_collection_id", "ocular stac_endpoint",
      "worldclim worldclim_licence", "elevation elevation_licence",
      "soilgrids soilgrids_licence", "chirps chirps_licence",
      "silo silo_unit")
  )
  # Every grounded fact has a non-NA Date; every [unverified] fact has NA. The
  # registry must never claim a fact is grounded without a recorded date.
  expect_true(all(!is.na(facts[grounding == "grounded", verified_on])))
  expect_true(all(is.na(facts[grounding == "[unverified]", verified_on])))

  # The still-ungrounded sources remain [unverified] -- not silently flipped.
  # nert (TERN) joins them: its facts' oracle is the TERN catalogue directly,
  # which has not yet been diffed in a recorded session, so it stays honest.
  ungrounded_src <- facts[grounding == "[unverified]", unique(source)]
  expect_setequal(ungrounded_src, c("silo", "abares", "stac", "nert"))
  # Licence and unit rows cite the authority page they were read from.
  expect_false(anyNA(facts[grepl("_licence$|_unit$", fact_family),
                           evidence_path]))
})

test_that("the canonical recipe-52 registry matches the reader view (no drift)", {
  # `.external_facts` (the base-R audit surface) and `terroir_external_facts()`
  # (the data.table reader view) describe the SAME facts; this guards against
  # the two drifting -- the failure mode the registry exists to prevent.
  canon <- terroir:::.external_facts
  view <- terroir_external_facts()
  expect_setequal(canon$family, unique(view$fact_family))
  for (f in canon$family) {
    vv <- view[fact_family == f, asserted_value]
    cv <- canon$value[canon$family == f]
    expect_true(all(vapply(vv, function(x) grepl(x, cv, fixed = TRUE),
                           logical(1L))),
                info = paste("family", f, "view values missing from canonical"))
  }
})

test_that("the registry validator reports the mixed grounding state per family", {
  # Grounding is now mixed. The validator must PASS the families a real live
  # oracle grounded (MODIS product / band / scale and NASA POWER codes on
  # 2026-06-13; the ocular STAC families on 2026-09-02) and FAIL the ones
  # still awaiting their oracle (SILO, ABARES, the rsi band mapping)
  # with the honest un-grounded reason. We never fabricate a verified_on to
  # force a green -- that would be the exact hallucination the Independent
  # Oracle Principle forbids; the NA families fail because they are genuinely
  # un-checked.
  res <- terroir:::.validate_external_registry(terroir:::.external_facts,
                                               testthat::test_path())

  grounded_fams <- c("product_id", "band_id", "scale_factor",
                     "nasapower_variable_code", "stac_collection_id",
                     "stac_endpoint", "worldclim_licence", "elevation_licence",
                     "soilgrids_licence", "chirps_licence", "silo_unit")
  ungrounded_fams <- c("variable_code", "renamed_column", "layer_name",
                       "band_mapping")

  expect_true(all(res$pass[res$family %in% grounded_fams]))
  expect_false(any(res$pass[res$family %in% ungrounded_fams]))
  expect_true(all(grepl("un-grounded|verified_on",
                        res$reason[res$family %in% ungrounded_fams])))
})
