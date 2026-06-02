# ---------------------------------------------------------------------------
# geo_point_series -- the tidy response half of contract C6, plus its verifier.
# ---------------------------------------------------------------------------

# The fixed C6 response schema (column order is part of the contract).
.geo_point_cols <- c(
  "lon", "lat", "date", "variable", "value", "unit",
  "source", "source_version", "retrieved_at", "license"
)

# Required provenance fields on every series.
.geo_point_prov <- c("source", "source_version", "retrieved_at", "license", "call")

#' Build a `geo_point_series` from a long-format table
#'
#' Adapter-facing constructor. Coerces a long table to the fixed C6 schema,
#' attaches mandatory provenance, and stamps the `geo_point_series` class. Most
#' users call [collect_point()] rather than this directly.
#'
#' @param dt A `data.frame`/`data.table` with at least `date`, `variable`,
#'   `value` columns (plus optional `unit`).
#' @param lon,lat Numeric scalars echoed onto every row.
#' @param source,source_version,license Character scalars (provenance).
#' @param retrieved_at Character scalar retrieval timestamp.
#' @param call Character scalar describing the upstream call (provenance).
#' @return A `geo_point_series` (a `data.table`) with provenance attached.
#' @export
new_geo_point_series <- function(dt, lon, lat, source, source_version,
                                 license, retrieved_at, call) {
  dt <- data.table::as.data.table(dt)
  if (!all(c("date", "variable", "value") %in% names(dt))) {
    cli::cli_abort("A series table needs at least {.field date}, {.field variable}, {.field value}.")
  }
  dt[, lon := lon]
  dt[, lat := lat]
  if (!"unit" %in% names(dt)) dt[, unit := NA_character_]
  dt[, source := source]
  dt[, source_version := as.character(source_version)]
  dt[, retrieved_at := as.character(retrieved_at)]
  dt[, license := license]
  data.table::setcolorder(dt, .geo_point_cols)

  prov <- list(
    source = source, source_version = as.character(source_version),
    retrieved_at = as.character(retrieved_at), license = license, call = call
  )
  data.table::setattr(dt, "provenance", prov)
  data.table::setattr(dt, "class", c("geo_point_series", class(dt)))
  dt
}

#' Verify a `geo_point_series` against contract C6
#'
#' Checks the fixed schema, units column, and mandatory provenance. Fails loudly
#' (the constellation never silently accepts a malformed series).
#'
#' @param x An object to verify.
#' @return Invisibly `TRUE` on success; otherwise an error.
#' @export
verify_geo_series <- function(x) {
  if (!inherits(x, "geo_point_series")) {
    cli::cli_abort("Not a {.cls geo_point_series}.")
  }
  miss <- setdiff(.geo_point_cols, names(x))
  if (length(miss)) {
    cols <- paste(miss, collapse = ", ")
    cli::cli_abort("Series is missing contract columns: {cols}.")
  }
  if (!is.numeric(x$value)) {
    cli::cli_abort("{.field value} must be numeric.")
  }
  prov <- attr(x, "provenance")
  if (is.null(prov) || !all(.geo_point_prov %in% names(prov))) {
    flds <- paste(.geo_point_prov, collapse = ", ")
    cli::cli_abort("Series is missing mandatory provenance: {flds}.")
  }
  invisible(TRUE)
}

#' @export
print.geo_point_series <- function(x, ...) {
  prov <- attr(x, "provenance")
  cli::cli_text("<geo_point_series> {nrow(x)} row{?s} from {.val {prov$source}} (v{prov$source_version})")
  cli::cli_text("  variables: {.val {unique(x$variable)}}  licence: {prov$license}")
  NextMethod()
}
