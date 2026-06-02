# ---------------------------------------------------------------------------
# geo_point_request -- the point-keyed request half of contract C6.
# ---------------------------------------------------------------------------

#' Construct a geo-point data request
#'
#' Build a request for environmental or agricultural-economics data at a single
#' geographic point. The request is the input half of the constellation's C6
#' `geo_point_series` contract; pass it to [collect_point()].
#'
#' @param lon,lat Numeric scalars. Longitude and latitude in WGS84 decimal
#'   degrees (EPSG:4326). `lon` in `[-180, 180]`, `lat` in `[-90, 90]`.
#' @param start,end Character scalars (ISO-8601 `"YYYY-MM-DD"`) or `NULL`. The
#'   inclusive date range. Ignored by static layers (for example soil or
#'   elevation).
#' @param variables Character vector of source-native variable names, or `NULL`
#'   to let the adapter choose sensible defaults.
#' @param source Character scalar. The id of one registered source adapter (see
#'   [list_sources()]).
#' @param radius Optional numeric. Search radius or buffer (kilometres) for
#'   nearest-station or grid sources; `NULL` for exact-point sources.
#'
#' @return An object of class `geo_point_request`.
#' @seealso [collect_point()], [list_sources()]
#' @export
#' @examples
#' geo_point_request(138.6, -34.92, "2020-01-01", "2020-01-31",
#'                   variables = c("T2M", "PRECTOTCORR"), source = "nasapower")
geo_point_request <- function(lon, lat, start = NULL, end = NULL,
                              variables = NULL, source, radius = NULL) {
  if (!is.numeric(lon) || length(lon) != 1L || !is.finite(lon) ||
      lon < -180 || lon > 180) {
    cli::cli_abort("{.arg lon} must be a finite number in [-180, 180].")
  }
  if (!is.numeric(lat) || length(lat) != 1L || !is.finite(lat) ||
      lat < -90 || lat > 90) {
    cli::cli_abort("{.arg lat} must be a finite number in [-90, 90].")
  }
  if (!is.character(source) || length(source) != 1L || !nzchar(source)) {
    cli::cli_abort("{.arg source} must be a single non-empty source id.")
  }
  if (!is.null(variables) && !is.character(variables)) {
    cli::cli_abort("{.arg variables} must be a character vector or NULL.")
  }
  if (!is.null(radius) &&
      (!is.numeric(radius) || length(radius) != 1L || radius < 0)) {
    cli::cli_abort("{.arg radius} must be a single non-negative number or NULL.")
  }

  structure(
    list(
      lon = lon, lat = lat,
      start = start, end = end,
      variables = variables,
      source = source,
      radius = radius
    ),
    class = "geo_point_request"
  )
}

#' @export
print.geo_point_request <- function(x, ...) {
  cli::cli_text("<geo_point_request> source {.val {x$source}}")
  cli::cli_text("  point: ({x$lon}, {x$lat})  range: {x$start %||% 'NA'} .. {x$end %||% 'NA'}")
  vars <- if (is.null(x$variables)) "(adapter default)" else paste(x$variables, collapse = ", ")
  cli::cli_text("  variables: {vars}")
  invisible(x)
}
