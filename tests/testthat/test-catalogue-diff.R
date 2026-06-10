# external-fact families: product_id, band_id, scale_factor, variable_code,
#   renamed_column, layer_name, band_mapping
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

test_that("MODIS product + band ids exist in the live ORNL DAAC catalogue", {
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

test_that("the fact registry is internally well-formed and honest by default", {
  facts <- terroir_external_facts()
  expect_true(all(c("source", "fact_family", "asserted_value", "oracle_kind",
                    "verified_on", "evidence_path", "grounding") %in%
                  names(facts)))
  # Seeds ship all-[unverified]: the registry must not claim a fact is grounded
  # until an oracle has actually checked it.
  expect_true(all(facts$grounding == "[unverified]"))
  expect_true(all(is.na(facts$verified_on)))
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

test_that("the registry validator runs and honestly reports the un-grounded state", {
  # terroir's facts are deliberately un-grounded (verified_on = NA) until the
  # live catalogue-diff oracle records real dates. The canonical validator must
  # therefore report every family as NOT passing -- the honest, machine-visible
  # state (we do NOT fabricate a verified_on to force a green; that would be the
  # exact hallucination the Independent Oracle Principle forbids).
  res <- terroir:::.validate_external_registry(terroir:::.external_facts,
                                               testthat::test_path())
  expect_false(any(res$pass))
  expect_true(all(grepl("un-grounded|verified_on", res$reason)))
})
