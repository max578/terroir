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
#' @param request A `geo_point_request` from [geo_point_request()].
#' @param retrieved_at Optional character scalar timestamp (provenance). Defaults
#'   to the current time.
#' @return A `geo_point_series`, or a `terroir_refusal`.
#' @seealso [geo_point_request()], [list_sources()], [verify_geo_series()]
#' @export
collect_point <- function(request, retrieved_at = NULL) {
  if (!inherits(request, "geo_point_request")) {
    cli::cli_abort("{.arg request} must be a {.cls geo_point_request}.")
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

  series <- entry$fun(request, retrieved_at = retrieved_at)
  if (is_refusal(series)) return(series)
  verify_geo_series(series)
  series
}
