# ---------------------------------------------------------------------------
# Source adapter registry. One entry per data source; the free-only role rule
# is enforced here (register_source refuses a non-free adapter).
# ---------------------------------------------------------------------------

.terroir_registry <- new.env(parent = emptyenv())

#' Register a data-source adapter
#'
#' Adds a source adapter to the registry. Enforces the data-collector role's
#' **free-only** rule: an adapter that does not reach a free source is refused.
#'
#' @param id Character scalar. Unique source id (used as `source` in
#'   [geo_point_request()]).
#' @param fun A function `function(request, retrieved_at)` returning a
#'   [geo_point_series][new_geo_point_series].
#' @param package Character scalar. The upstream package the adapter needs
#'   (declared in `Suggests`; checked at collect time).
#' @param free Logical scalar. Must be `TRUE` -- the free-only role rule.
#' @param description Character scalar. One-line description.
#' @param extent Optional numeric `c(xmin, ymin, xmax, ymax)` in WGS84 giving
#'   the source's valid spatial extent, or `NULL` for a global source. A
#'   request outside a declared extent is refused by [collect_point()] rather
#'   than silently returning an out-of-coverage value (Independent Oracle
#'   Principle: an Australia-only source must not be queried over Argentina).
#' @return Invisibly, the registered `id`.
#' @export
register_source <- function(id, fun, package, free, description = "",
                            extent = NULL) {
  if (!is.character(id) || length(id) != 1L || !nzchar(id)) {
    cli::cli_abort("{.arg id} must be a single non-empty string.")
  }
  if (!is.function(fun)) cli::cli_abort("{.arg fun} must be a function.")
  if (!isTRUE(free)) {
    cli::cli_abort(c(
      "Refusing to register {.val {id}}: the data-collector role is free-only.",
      "i" = "Every adapter must reach a free source ({.code free = TRUE})."
    ))
  }
  if (!is.null(extent) &&
      (!is.numeric(extent) || length(extent) != 4L || anyNA(extent))) {
    cli::cli_abort("{.arg extent} must be NULL or numeric c(xmin, ymin, xmax, ymax).")
  }
  assign(
    id,
    list(id = id, fun = fun, package = package, free = TRUE,
         description = description, extent = extent),
    envir = .terroir_registry
  )
  invisible(id)
}

#' List registered data sources
#'
#' @return A `data.table` with one row per registered source.
#' @export
#' @examples
#' list_sources()
list_sources <- function() {
  ids <- ls(envir = .terroir_registry)
  if (!length(ids)) {
    return(data.table::data.table(
      id = character(), package = character(),
      free = logical(), description = character()
    ))
  }
  rows <- lapply(ids, function(i) {
    e <- get(i, envir = .terroir_registry)
    data.table::data.table(
      id = e$id, package = e$package, free = e$free, description = e$description
    )
  })
  data.table::rbindlist(rows)
}

.get_source <- function(id) {
  if (!exists(id, envir = .terroir_registry, inherits = FALSE)) return(NULL)
  get(id, envir = .terroir_registry)
}
