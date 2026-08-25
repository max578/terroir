# ---------------------------------------------------------------------------
# collect_points -- the batch/panel form of the C6 verb (T-11). A0/B0-shaped
# studies need many sites x many seasons x several sources in one call, with
# a per-site cache-friendly provenance ledger and refusals kept as rows
# (never silently dropped) so a caller can see exactly which requests did not
# return data.
# ---------------------------------------------------------------------------

#' Collect geo-point data for a batch of requests
#'
#' Batch/panel form of [collect_point()]. Dispatches each request in `requests`
#' in turn (via [collect_point()], so every per-request refusal path --
#' unknown source, missing package, out-of-extent point, implausible value --
#' applies identically) and stacks the results into one long `data.table`, one
#' row per `(request x variable)` for a successful collection or exactly one
#' row for a refused request.
#'
#' A refusal is never dropped from the stack: it contributes one row with
#' `status == "refused"` and `reason` set to the refusal's message, so a
#' 40-site collection with two dead sources still returns 40 requests' worth
#' of accounting, not 38.
#'
#' @param requests A non-empty list of `geo_point_request` objects (see
#'   [geo_point_request()]).
#' @param retrieved_at,offline As for [collect_point()]; the same value is
#'   passed through to every request in the batch.
#' @return A `data.table` with a leading `request_index` (position in
#'   `requests`) and `status` (`"ok"` or `"refused"`) column, a `reason`
#'   column (`NA_character_` for an `"ok"` row, the refusal message
#'   otherwise), followed by the fixed C6 `geo_point_series` columns. `lon`,
#'   `lat` and `source` are populated on a refused row from the request itself
#'   (the values known even when nothing was collected); the remaining C6
#'   columns are `NA` on a refused row.
#' @seealso [collect_point()], [geo_point_request()], [is_refusal()]
#' @export
#' @examples
#' reqs <- list(
#'   geo_point_request(138.6, -34.9, "2020-01-01", "2020-01-31",
#'                     source = "nasapower"),
#'   geo_point_request(0, 0, source = "no_such_source")
#' )
#' out <- suppressWarnings(collect_points(reqs, offline = TRUE))
#' out$status
collect_points <- function(requests, retrieved_at = NULL,
                           offline = getOption("terroir.offline", FALSE)) {
  if (!is.list(requests) || !length(requests) ||
      !all(vapply(requests, inherits, logical(1L), "geo_point_request"))) {
    cli::cli_abort(
      "{.arg requests} must be a non-empty list of {.cls geo_point_request} objects."
    )
  }
  rows <- vector("list", length(requests))
  for (i1 in seq_along(requests)) {
    req <- requests[[i1]]
    out <- collect_point(req, retrieved_at = retrieved_at, offline = offline)
    rows[[i1]] <- if (is_refusal(out)) {
      .refusal_row(i1, req, out)
    } else {
      .series_rows(i1, out)
    }
  } # ends i1, over requests
  data.table::rbindlist(rows, use.names = TRUE, fill = TRUE)
}

# One accounting row for a refused request: the request's own lon/lat/source
# are known even though nothing was collected, so they are populated; every
# other C6 column is NA.
.refusal_row <- function(idx, req, refusal) {
  data.table::data.table(
    request_index = idx, status = "refused", reason = refusal$reason,
    lon = req$lon, lat = req$lat, date = as.Date(NA_character_),
    variable = NA_character_, value = NA_real_, unit = NA_character_,
    source = req$source %||% refusal$source,
    source_version = NA_character_, retrieved_at = NA_character_,
    license = NA_character_
  )
}

# One row per (date x variable) of a successful collection, tagged with the
# request index and an "ok" status / NA reason.
.series_rows <- function(idx, series) {
  dt <- data.table::as.data.table(series)
  dt[, request_index := idx]
  dt[, status := "ok"]
  dt[, reason := NA_character_]
  data.table::setcolorder(dt, c("request_index", "status", "reason", .geo_point_cols))
  dt
}
