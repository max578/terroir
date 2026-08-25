# ---------------------------------------------------------------------------
# collect_point -- the C6 verb. Resolves the request's source to a registered
# adapter, checks the upstream package is installed (graceful refusal if not),
# runs the adapter, and self-verifies the returned series.
# ---------------------------------------------------------------------------

#' Collect geo-point data for one request
#'
#' The single entry point of the C6 contract. Dispatches a
#' [geo_point_request()] to its registered source adapter and returns a verified
#' [geo_point_series][new_geo_point_series], or a structured
#' [refusal][is_refusal] when the source is unknown or its package is not
#' installed.
#'
#' `collect_point()` performs network input/output, so it stamps `retrieved_at`
#' with the current time by default; pass `retrieved_at` for reproducible runs.
#'
#' In **offline mode** (`offline = TRUE`, or globally via
#' `options(terroir.offline = TRUE)`) the request is answered from a recorded
#' fixture with no network egress at all: the matching cached series is replayed
#' with its provenance marked `replayed = TRUE` and its original `retrieved_at`
#' preserved (see [is_replayed()]). This lets a sovereign-coordinate trial run
#' with zero upstream contact, and makes a pipeline reproducible bit-for-bit.
#' When no recorded fixture answers the request, offline mode returns a
#' structured refusal rather than silently falling back to the network. The
#' fixture directory is the `terroir.fixture_dir` option if set, otherwise the
#' installed package's `fixtures/` directory.
#'
#' @param request A `geo_point_request` from [geo_point_request()].
#' @param retrieved_at Optional character scalar timestamp (provenance). Defaults
#'   to the current time. Ignored in offline mode (a replayed series keeps the
#'   fixture's recorded timestamp).
#' @param offline Logical scalar. When `TRUE`, answer from a recorded fixture
#'   with zero network egress (see Details). Defaults to the `terroir.offline`
#'   option, otherwise `FALSE`.
#' @return A `geo_point_series`, or a `terroir_refusal` -- including when the
#'   returned values fail the value-plausibility conformer (an implausible
#'   NDVI/EVI or temperature reading), which is refused rather than aborted so
#'   one bad cell does not stop a multi-site collection.
#' @seealso [geo_point_request()], [list_sources()], [verify_geo_series()],
#'   [is_replayed()]
#' @export
collect_point <- function(request, retrieved_at = NULL,
                          offline = getOption("terroir.offline", FALSE)) {
  if (!inherits(request, "geo_point_request")) {
    cli::cli_abort("{.arg request} must be a {.cls geo_point_request}.")
  }
  if (!is.logical(offline) || length(offline) != 1L || is.na(offline)) {
    cli::cli_abort("{.arg offline} must be a single logical (TRUE or FALSE).")
  }
  if (isTRUE(offline)) {
    series <- .collect_offline(request)
    if (is_refusal(series)) return(series)
    series <- .stamp_coarsen_provenance(series, request)
    return(.verify_or_refuse(series, request$source))
  }
  retrieved_at <- retrieved_at %||% as.character(Sys.time())

  entry <- .get_source(request$source)
  if (is.null(entry)) {
    return(.refuse(
      sprintf("unknown source '%s' (see list_sources())", request$source),
      source = request$source
    ))
  }
  if (!requireNamespace(entry$package, quietly = TRUE)) {
    return(.refuse(
      sprintf("source package '%s' is not installed", entry$package),
      source = request$source
    ))
  }

  # IOP / FX-6: refuse a point outside a source's declared spatial extent rather
  # than silently returning an out-of-coverage (or wrong-cell) value -- this is
  # the lasrosas-Argentina vs SILO/ABARES-Australia mismatch the audit named.
  ext <- entry$extent
  if (!is.null(ext) &&
      (request$lon < ext[1] || request$lon > ext[3] ||
       request$lat < ext[2] || request$lat > ext[4])) {
    return(.refuse(
      sprintf(paste0("point (%g, %g) is outside the '%s' source extent ",
                     "[%g, %g] x [%g, %g]; this source does not cover it"),
              request$lon, request$lat, request$source,
              ext[1], ext[3], ext[2], ext[4]),
      source = request$source
    ))
  }

  series <- entry$fun(request, retrieved_at = retrieved_at)
  if (is_refusal(series)) return(series)
  series <- .stamp_coarsen_provenance(series, request)
  .verify_or_refuse(series, request$source)
}

# Verify a series against contract C6, but turn a value-plausibility failure
# into a typed `terroir_refusal` instead of letting it abort the call (T-06):
# one implausible cell in a multi-site collection must not abort the whole
# collection -- it is exactly the kind of "assumptions not met" outcome the
# constellation refusal pattern exists for. Schema and provenance defects stay
# hard aborts (they are internal contract violations, not upstream-data
# problems), and `verify_geo_series()` itself is unchanged for direct callers.
.verify_or_refuse <- function(series, source) {
  bad <- .check_value_ranges(series)
  if (!is.null(bad)) return(.refuse(bad, source = source))
  verify_geo_series(series)
  series
}

# Record the coarsening policy onto a returned series' provenance. The adapter
# sees only the (possibly coarsened) `lon`/`lat`, so the series itself never
# carries the exact GPS; here we attach the policy and the raw-vs-sent
# coordinates so the host keeps an auditable record of what was actually
# transmitted. Backward-compatible: it only adds provenance fields, leaving the
# 10-column C6 series schema untouched.
.stamp_coarsen_provenance <- function(series, request) {
  policy <- request$coarsen_policy %||% "none"
  if (identical(policy, "none") && !isTRUE(request$sovereign)) return(series)
  prov <- attr(series, "provenance")
  prov$sovereign <- isTRUE(request$sovereign)
  prov$coarsen_policy <- policy
  prov$lon_raw <- request$lon_raw %||% request$lon
  prov$lat_raw <- request$lat_raw %||% request$lat
  prov$lon_sent <- request$lon
  prov$lat_sent <- request$lat
  data.table::setattr(series, "provenance", prov)
  series
}
