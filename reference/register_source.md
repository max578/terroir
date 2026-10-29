# Register a data-source adapter

Adds a source adapter to the registry. Enforces the data-collector
role's **free-only** rule: an adapter that does not reach a free source
is refused.

## Usage

``` r
register_source(
  id,
  fun,
  package,
  free,
  description = "",
  extent = NULL,
  batch = NULL
)
```

## Arguments

- id:

  Character scalar. Unique source id (used as `source` in
  [`geo_point_request()`](https://max578.github.io/terroir/reference/geo_point_request.md)).

- fun:

  A function `function(request, retrieved_at)` returning a
  [geo_point_series](https://max578.github.io/terroir/reference/new_geo_point_series.md).

- package:

  Character scalar. The upstream package the adapter needs (declared in
  `Suggests`; checked at collect time).

- free:

  Logical scalar. Must be `TRUE` – the free-only role rule.

- description:

  Character scalar. One-line description.

- extent:

  Optional numeric `c(xmin, ymin, xmax, ymax)` in WGS84 giving the
  source's valid spatial extent, or `NULL` for a global source. A
  request outside a declared extent is refused by
  [`collect_point()`](https://max578.github.io/terroir/reference/collect_point.md)
  rather than silently returning an out-of-coverage value (Independent
  Oracle Principle: an Australia-only source must not be queried over
  Argentina).

- batch:

  Optional function `function(requests, retrieved_at)` that answers many
  requests for this source in one upstream call. It returns a list of
  the same length as `requests`, each element a
  [geo_point_series](https://max578.github.io/terroir/reference/new_geo_point_series.md)
  or a refusal.
  [`collect_points()`](https://max578.github.io/terroir/reference/collect_points.md)
  uses it for raster sources, where one file read serves every point.
  `NULL` (the default) means requests are answered one at a time by
  `fun`.

## Value

Invisibly, the registered `id`.

## Examples

``` r
toy_adapter <- function(request, retrieved_at) {
  dt <- data.frame(date = request$start, variable = "toy", value = 1)
  new_geo_point_series(
    dt, lon = request$lon, lat = request$lat,
    source = "toy", source_version = "1.0", license = "CC0",
    retrieved_at = retrieved_at, call = "toy_adapter()"
  )
}
register_source("toy", toy_adapter, package = "base", free = TRUE,
                 description = "Illustrative in-memory adapter")
"toy" %in% list_sources()$id
#> [1] TRUE
```
