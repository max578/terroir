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
#' @param sovereign Logical scalar. When `TRUE`, the point is treated as
#'   sensitive (a sovereign-data coordinate -- a grower's paddock, a trial site)
#'   and coarsening is applied by default so the exact GPS never leaves the host
#'   (see `coarsen`). Defaults to `FALSE`.
#' @param coarsen Coordinate-coarsening policy applied to `lon`/`lat` **before**
#'   any upstream call, so the exact coordinate is never transmitted. One of:
#'   `NULL` (no coarsening; the default for a non-sovereign point); a single
#'   positive number giving the rounding precision in degrees (for example
#'   `0.01` rounds to roughly a 1 km cell); or a `list(grid = <size>)` snapping
#'   each coordinate to the nearest multiple of `<size>` degrees. For a
#'   `sovereign = TRUE` point with `coarsen = NULL`, a default precision of
#'   `0.01` degrees is applied automatically. The request records **both** the
#'   raw-requested coordinate and the coarsened-sent coordinate.
#'
#' @return An object of class `geo_point_request`. When coarsening is applied,
#'   `lon`/`lat` hold the coarsened coordinate (what is sent upstream) and
#'   `lon_raw`/`lat_raw` hold the exact requested coordinate (kept on the host
#'   for provenance); `coarsen_policy` records the policy as a string.
#' @seealso [collect_point()], [list_sources()]
#' @export
#' @examples
#' geo_point_request(138.6, -34.92, "2020-01-01", "2020-01-31",
#'                   variables = c("T2M", "PRECTOTCORR"), source = "nasapower")
#'
#' # A sovereign point: the exact GPS is coarsened to ~1 km before any call.
#' geo_point_request(138.63124, -34.92871, "2020-01-01", "2020-01-31",
#'                   source = "nasapower", sovereign = TRUE)
geo_point_request <- function(lon, lat, start = NULL, end = NULL,
                              variables = NULL, source, radius = NULL,
                              sovereign = FALSE, coarsen = NULL) {
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
  if (!is.logical(sovereign) || length(sovereign) != 1L || is.na(sovereign)) {
    cli::cli_abort("{.arg sovereign} must be a single logical (TRUE or FALSE).")
  }

  # A sovereign point with no explicit policy gets the default ~1 km precision
  # automatically: the privacy primitive is on-by-default for sovereign points,
  # opt-in otherwise.
  if (isTRUE(sovereign) && is.null(coarsen)) coarsen <- .coarsen_default
  coarse <- .apply_coarsen(lon, lat, coarsen)

  structure(
    list(
      lon = coarse$lon, lat = coarse$lat,
      lon_raw = lon, lat_raw = lat,
      start = start, end = end,
      variables = variables,
      source = source,
      radius = radius,
      sovereign = sovereign,
      coarsen_policy = coarse$policy
    ),
    class = "geo_point_request"
  )
}

# The default coarsening precision for a sovereign point: 0.01 degrees, roughly
# a 1 km cell at mid-latitudes. Kept as a named constant so the request
# constructor and the documentation cannot drift.
.coarsen_default <- 0.01

# Apply a coarsening policy to a (lon, lat) pair. Returns a list with the
# coarsened `lon`/`lat` and a human-readable `policy` string for provenance.
# `coarsen = NULL` is a no-op (policy "none"); a single number rounds to that
# many degrees of precision; `list(grid = s)` snaps to the nearest multiple of
# `s` degrees. Validates the policy and aborts on a malformed one.
.apply_coarsen <- function(lon, lat, coarsen) {
  if (is.null(coarsen)) {
    return(list(lon = lon, lat = lat, policy = "none"))
  }
  if (is.list(coarsen)) {
    if (!identical(names(coarsen), "grid")) {
      cli::cli_abort(paste0("{.arg coarsen} list form must be ",
                            "{.code list(grid = <size>)}."))
    }
    size <- coarsen$grid
    if (!is.numeric(size) || length(size) != 1L || !is.finite(size) ||
        size <= 0) {
      cli::cli_abort("{.arg coarsen} grid size must be a single positive number.")
    }
    return(list(
      lon = round(lon / size) * size,
      lat = round(lat / size) * size,
      policy = sprintf("grid=%g", size)
    ))
  }
  if (is.numeric(coarsen) && length(coarsen) == 1L && is.finite(coarsen) &&
      coarsen > 0) {
    digits <- max(0L, as.integer(round(-log10(coarsen))))
    return(list(
      lon = round(lon, digits = digits),
      lat = round(lat, digits = digits),
      policy = sprintf("precision=%g", coarsen)
    ))
  }
  cli::cli_abort(paste0("{.arg coarsen} must be NULL, a single positive ",
                        "precision (degrees), or {.code list(grid = <size>)}."))
}

#' @export
print.geo_point_request <- function(x, ...) {
  cli::cli_text("<geo_point_request> source {.val {x$source}}")
  cli::cli_text("  point: ({x$lon}, {x$lat})  range: {x$start %||% 'NA'} .. {x$end %||% 'NA'}")
  vars <- if (is.null(x$variables)) "(adapter default)" else paste(x$variables, collapse = ", ")
  cli::cli_text("  variables: {vars}")
  if (!identical(x$coarsen_policy %||% "none", "none")) {
    flag <- if (isTRUE(x$sovereign)) " (sovereign)" else ""
    cli::cli_text(paste0("  coarsened{flag}: raw ({x$lon_raw}, {x$lat_raw}) ",
                         "-> sent ({x$lon}, {x$lat})  policy {.val {x$coarsen_policy}}"))
  }
  invisible(x)
}
