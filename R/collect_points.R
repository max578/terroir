# ---------------------------------------------------------------------------
# collect_points -- the batch/panel form of the C6 verb (T-11). A0/B0-shaped
# studies need many sites x many seasons x several sources in one call, with
# a per-site cache-friendly provenance ledger and refusals kept as rows
# (never silently dropped) so a caller can see exactly which requests did not
# return data.
# ---------------------------------------------------------------------------

#' Collect geo-point data for a batch of requests
#'
#' Batch/panel form of [collect_point()]. Stacks the results of every request
#' in `requests` into one long `data.table`, one row per `(request x date x
#' variable)` for a successful collection or exactly one row for a refused
#' request. Every per-request refusal path of [collect_point()] (unknown
#' source, missing package, out-of-extent point, implausible value) applies
#' identically.
#'
#' Requests are grouped by source. A source registered with a `batch` function
#' (see [register_source()]) receives all of its requests in one call, so a
#' raster is read once for many points. Other sources are called one request at
#' a time. Offline mode always answers one request at a time from fixtures.
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
#'   columns are `NA` on a refused row. A final `call` column carries the
#'   upstream call recorded in each series' provenance.
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
  s1 <- length(requests)
  if (!isTRUE(offline)) retrieved_at <- retrieved_at %||% as.character(Sys.time())
  answers <- vector("list", s1)

  # sources with a batch function take all of their requests at once
  src_vec <- vapply(requests, function(r) as.character(r$source), character(1L))
  batch_vec <- character()
  if (!isTRUE(offline)) {
    for (src_local in unique(src_vec)) {
      entry <- .get_source(src_local)
      if (!is.null(entry) && is.function(entry$batch)) {
        batch_vec <- c(batch_vec, src_local)
      }
    } # ends src_local, over the requested sources
  }

  # a batch call shares one variable list, so split each source by it
  var_vec <- vapply(requests, function(r) paste(r$variables, collapse = ","),
                    character(1L))
  for (group_local in unique(paste(src_vec, var_vec)[src_vec %in% batch_vec])) {
    idx_vec <- which(paste(src_vec, var_vec) == group_local)
    src_local <- src_vec[idx_vec[1L]]
    checks <- lapply(requests[idx_vec], .check_request_online)
    ok_vec <- !vapply(checks, is_refusal, logical(1L))
    answers[idx_vec[!ok_vec]] <- checks[!ok_vec]
    if (any(ok_vec)) {
      idx_ok <- idx_vec[ok_vec]
      entry <- .get_source(src_local)
      out <- entry$batch(requests[idx_ok], retrieved_at = retrieved_at)
      if (!is.list(out) || length(out) != length(idx_ok)) {
        cli::cli_abort(
          "The batch adapter for {.val {src_local}} must return one answer per request."
        )
      }
      for (i1 in seq_along(idx_ok)) {
        answers[[idx_ok[i1]]] <- .finish_series(out[[i1]], requests[[idx_ok[i1]]])
      } # ends i1, over the batch answers
    }
  } # ends group_local, over source and variable groups

  rows <- vector("list", s1)
  for (i1 in seq_len(s1)) {
    req <- requests[[i1]]
    out <- answers[[i1]]
    if (is.null(out)) {
      out <- collect_point(req, retrieved_at = retrieved_at, offline = offline)
    }
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
    license = NA_character_, call = NA_character_
  )
}

# One row per (date x variable) of a successful collection, tagged with the
# request index and an "ok" status / NA reason.
.series_rows <- function(idx, series) {
  dt <- data.table::as.data.table(series)
  dt[, request_index := idx]
  dt[, status := "ok"]
  dt[, reason := NA_character_]
  dt[, call := attr(series, "provenance")$call]
  data.table::setcolorder(
    dt, c("request_index", "status", "reason", .geo_point_cols, "call")
  )
  dt
}
