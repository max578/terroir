# ---------------------------------------------------------------------------
# External-facts provenance registry (Independent Oracle Principle).
#
# terroir asserts facts about external authorities -- product ids, band codes,
# scale factors, variable names, layer names, band mappings. The orchestra-wide
# rpkg audit (2026-06-09) found these facts grounded only against goldens the
# package itself generated (a co-hallucinated oracle) -- the nert failure mode.
#
# This registry makes the gap AUDITABLE rather than invisible: every asserted
# fact is enumerated with the oracle that would ground it and the date it was
# last diffed against that authority. A fact is *grounded* iff `verified_on` is
# a non-NA Date (orchestra provenance vocabulary, token "grounded"); otherwise
# it is "[unverified]". Seeds ship all-[unverified]; the catalogue-diff oracle
# test (tests/testthat/test-catalogue-diff.R) is what flips them.
# ---------------------------------------------------------------------------

# Canonical grounding tokens (orchestra provenance vocabulary v1.0). terroir
# cannot source the contract layer, so the tokens are hardcoded identically.
.TERROIR_GROUNDED   <- "grounded"
.TERROIR_UNVERIFIED <- "[unverified]"

# ABARES AAGIS farm-data layer names terroir asserts. Hoisted to a file-level
# constant so the data.table seed (below) and the canonical recipe-52 registry
# (`.external_facts`) share ONE source for the list -- they cannot drift.
.TERROIR_ABARES_LAYERS <- c(
  "farmno", "R_total_hat_ha", "C_total_hat_ha", "FBP_fci_hat_ha",
  "FBP_fbp_hat_ha", "A_wheat_hat_ha", "H_wheat_dot_hat", "A_barley_hat_ha",
  "H_barley_dot_hat", "A_oilseeds_hat_ha", "H_oilseeds_dot_hat",
  "R_wheat_hat_ha", "R_oilseeds_hat_ha", "R_barley_hat_ha", "Q_wheat_hat_ha",
  "Q_barley_hat_ha", "Q_oilseeds_hat_ha", "S_wheat_cl_hat_ha",
  "S_sheep_cl_hat_ha", "S_sheep_births_hat_ha"
)

# The seed table. One row per asserted external-authority fact. `oracle_kind`
# names the authority that *would* ground the fact; `verified_on = NA` means it
# has not yet been diffed against that authority (the default, honest, state).
.terroir_fact_seed <- function() {
  abares_layers <- .TERROIR_ABARES_LAYERS
  rows <- list(
    data.frame(source = "modis", fact_family = "product_id",
               asserted_value = "MOD13Q1", oracle_kind = "live_catalogue",
               stringsAsFactors = FALSE),
    data.frame(source = "modis", fact_family = "band_id",
               asserted_value = "250m_16_days_NDVI",
               oracle_kind = "live_catalogue", stringsAsFactors = FALSE),
    data.frame(source = "modis", fact_family = "scale_factor",
               asserted_value = "0.0001", oracle_kind = "live_catalogue",
               stringsAsFactors = FALSE),
    data.frame(source = "silo", fact_family = "variable_code",
               asserted_value = c("max_temp", "min_temp", "rain"),
               oracle_kind = "upstream_package", stringsAsFactors = FALSE),
    data.frame(source = "silo", fact_family = "renamed_column",
               asserted_value = c("air_tmax", "air_tmin", "rainfall"),
               oracle_kind = "upstream_package", stringsAsFactors = FALSE),
    data.frame(source = "abares", fact_family = "layer_name",
               asserted_value = abares_layers, oracle_kind = "live_catalogue",
               stringsAsFactors = FALSE),
    data.frame(source = "stac", fact_family = "band_mapping",
               asserted_value = c("N=B08", "R=B04"),
               oracle_kind = "upstream_package", stringsAsFactors = FALSE)
  )
  out <- data.table::rbindlist(rows)
  out[, verified_on := as.Date(NA)]
  out[, evidence_path := NA_character_]
  out[]
}

#' terroir's external-authority fact registry
#'
#' Enumerates every fact terroir asserts about an external data authority (MODIS
#' product / band / scale, SILO variable codes, ABARES farm-data layer names,
#' Sentinel-2 band mapping) together with its grounding provenance. A fact is
#' *grounded* only when it has been diffed against the authority that owns it on
#' a recorded date; until then it is `[unverified]`. The catalogue-diff oracle
#' test grounds them at check time.
#'
#' @return A `data.table` keyed by `source`, `fact_family`, with columns
#'   `asserted_value`, `oracle_kind` (the authority that grounds the fact),
#'   `verified_on` (`Date` or `NA`), `evidence_path`, and a derived `grounding`
#'   token (`"grounded"` / `"[unverified]"`).
#' @seealso The orchestra provenance vocabulary
#'   (`ORCHESTRA_dev/integration/provenance_vocabulary.md`).
#' @export
#' @examples
#' facts <- terroir_external_facts()
#' facts[fact_family == "scale_factor"]
terroir_external_facts <- function() {
  dt <- .terroir_fact_seed()
  dt[, grounding := data.table::fifelse(is.na(verified_on),
                                        .TERROIR_UNVERIFIED, .TERROIR_GROUNDED)]
  data.table::setkey(dt, source, fact_family)
  dt[]
}

#' Grounding status summary for terroir's external facts
#'
#' One row per `(source, fact_family)` with the count of grounded vs unverified
#' asserted values -- a glance-able audit of how much of terroir's external-fact
#' surface has been checked against its authorities.
#'
#' @return A `data.table` with `source`, `fact_family`, `n_facts`,
#'   `n_grounded`, `n_unverified`.
#' @export
terroir_fact_status <- function() {
  dt <- terroir_external_facts()
  dt[, .(n_facts = .N,
         n_grounded = sum(grounding == .TERROIR_GROUNDED),
         n_unverified = sum(grounding == .TERROIR_UNVERIFIED)),
     by = .(source, fact_family)][]
}

# ---------------------------------------------------------------------------
# Canonical recipe-52 registry (the `/rpkg` audit's F13/F14 contract surface).
#
# Base R only -- no data.table -- so the audit driver can source this file in a
# vanilla session and run `.validate_external_registry()`. It is the canonical
# projection of the SAME facts the data.table view (`terroir_external_facts()`)
# carries; the drift-guard test (tests/testthat/test-catalogue-diff.R) asserts
# the two agree fact-for-fact.
#
# HONEST STATE: every `verified_on` is `NA` -- terroir's external-authority
# facts are *registered and enumerated* but NOT yet independently grounded. The
# live catalogue-diff oracle (the test in this package) is the grounding
# mechanism; it requires a network run not yet recorded. The validator THEREFORE
# reports every family as failing F13 ("unparseable `verified_on`") -- this is
# the true, machine-visible state, not a defect to paper over with a fabricated
# date (fabricating a `verified_on` we never checked would be the exact
# hallucination the Independent Oracle Principle forbids). Grounding is a
# release-cut gate: run the live catalogue-diff oracle, record real dates here.
# ---------------------------------------------------------------------------
.external_facts <- data.frame(
  family = c("product_id", "band_id", "scale_factor", "variable_code",
             "renamed_column", "layer_name", "band_mapping"),
  fact_id = c("modis.product_id", "modis.band_id", "modis.scale_factor",
              "silo.variable_code", "silo.renamed_column", "abares.layer_name",
              "stac.band_mapping"),
  kind = c("locator", "enum", "units", "enum", "enum", "enum", "enum"),
  value = c(
    "MOD13Q1", "250m_16_days_NDVI", "0.0001",
    "max_temp, min_temp, rain", "air_tmax, air_tmin, rainfall",
    paste(.TERROIR_ABARES_LAYERS, collapse = ", "), "N=B08, R=B04"),
  source = c(
    "NASA LP DAAC MODIS MOD13Q1 product (ORNL DAAC MODISTools::mt_products)",
    "NASA LP DAAC MOD13Q1 band list (ORNL DAAC MODISTools::mt_bands)",
    "NASA LP DAAC MOD13Q1 NDVI scale factor (MOD13 product user guide)",
    "SILO climate variable codes (Qld DES SILO API / upstream interface)",
    "SILO -> terroir column rename map (SILO variable documentation)",
    "ABARES AAGIS farm-data layer dictionary",
    "Sentinel-2 band designations (ESA/Copernicus; STAC asset keys)"),
  verified_on = NA_character_,            # honestly un-grounded; see header
  reverify_by = c("stable", "stable", "literature", "stable", "stable",
                  "stable", "literature"),
  oracle_types = c("A,B", "B,E", "A,D", "B,E", "B,E", "B,E", "B,E"),
  signoff = NA_character_,
  stringsAsFactors = FALSE)

.silent_fact_kinds <- c("enum", "crs", "units", "constant", "schema", "rule")

# NA-safe ISO date parse (never errors on bad input).
.parse_iso <- function(x) as.Date(as.character(x), format = "%Y-%m-%d")

#' Validate terroir's external-fact registry (gate F13/F14 contract)
#'
#' Pure base R, no network. Run by terroir's own tests and invoked by the
#' `/rpkg` audit driver. Returns one row per family with `pass` and, on failure,
#' a `reason`. Mirrors the recipe-52 canonical validator. With every fact
#' currently un-grounded (`verified_on = NA`) it correctly reports every family
#' as failing -- the honest, machine-visible state.
#'
#' @param registry The registry `data.frame` (default `.external_facts`).
#' @param test_dir Path to `tests/testthat` for the oracle-coverage check.
#' @returns A `data.frame`: `family`, `pass` (logical), `reason`.
#' @noRd
#' @keywords internal
.validate_external_registry <- function(registry = .external_facts,
                                        test_dir = "tests/testthat") {
  reasons <- character()
  fail <- function(msg) reasons[[length(reasons) + 1L]] <<- msg

  if (any(!nzchar(registry$source) | is.na(registry$source)))
    fail("row(s) with empty `source`")
  # Reason kept short (< 80 chars): the `/rpkg` audit driver prints validator
  # rows with cat(fill = TRUE), which line-wraps a long reason and mis-parses
  # the wrap as extra families. Full context is in this file's header.
  if (any(is.na(.parse_iso(registry$verified_on))))
    fail("un-grounded: verified_on is NA (awaiting live oracle)")

  window <- c(volatile = 90L, stable = 365L, literature = .Machine$integer.max)
  due <- vapply(seq_len(nrow(registry)), function(i) {
    pol <- registry$reverify_by[[i]]
    days <- if (pol %in% names(window)) window[[pol]] else NA_integer_
    if (is.na(days)) {
      due_by <- .parse_iso(pol)
      !is.na(due_by) && Sys.Date() > due_by
    } else {
      vd <- .parse_iso(registry$verified_on[[i]])
      !is.na(vd) && as.integer(Sys.Date() - vd) > days
    }
  }, logical(1L))
  if (any(due, na.rm = TRUE)) fail("row(s) past their re-grounding window")

  silent <- registry$kind %in% .silent_fact_kinds
  has_def <- grepl("[DEF]", registry$oracle_types)
  if (any(silent & !has_def))
    fail("silent-failure kind without a D/E/F oracle (recipe 52 §2)")

  is_rule <- registry$kind == "rule"
  bad_signoff <- is_rule & (is.na(registry$signoff) | !nzchar(registry$signoff))
  if (any(bad_signoff)) fail("`kind == 'rule'` row without a `signoff`")

  oracle_files <- list.files(
    test_dir,
    pattern = "test-(contract-live|catalogue-diff|properties-recorded)\\.R$",
    full.names = TRUE)
  oracle_blob <- if (length(oracle_files)) paste(
    vapply(oracle_files, function(f) paste(readLines(f, warn = FALSE),
                                           collapse = "\n"), character(1L)),
    collapse = "\n") else ""
  fams <- unique(registry$family)
  uncovered <- fams[!vapply(fams, function(f) {
    grepl(f, oracle_blob, fixed = TRUE) ||
      any(grepl(registry$fact_id[registry$family == f], oracle_blob,
                fixed = TRUE))
  }, logical(1L))]

  data.frame(
    family = fams,
    pass = !fams %in% uncovered & length(reasons) == 0L,
    reason = ifelse(
      fams %in% uncovered,
      "no independent-oracle test references this family (F14)",
      if (length(reasons)) paste(reasons, collapse = "; ") else NA_character_),
    stringsAsFactors = FALSE)
}
