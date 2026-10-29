# Construct a geo-point data request

Build a request for environmental or agricultural-economics data at a
single geographic point. The request is the input half of the
constellation's C6 `geo_point_series` contract; pass it to
[`collect_point()`](https://max578.github.io/terroir/reference/collect_point.md).

## Usage

``` r
geo_point_request(
  lon,
  lat,
  start = NULL,
  end = NULL,
  variables = NULL,
  source,
  sovereign = FALSE,
  coarsen = NULL
)
```

## Arguments

- lon, lat:

  Numeric scalars. Longitude and latitude in WGS84 decimal degrees
  (EPSG:4326). `lon` in `[-180, 180]`, `lat` in `[-90, 90]`.

- start, end:

  Character scalars (ISO-8601 `"YYYY-MM-DD"`) or `NULL`. The inclusive
  date range. Ignored by static layers (for example soil or elevation).

- variables:

  Character vector of source-native variable names, or `NULL` to let the
  adapter choose sensible defaults.

- source:

  Character scalar. The id of one registered source adapter (see
  [`list_sources()`](https://max578.github.io/terroir/reference/list_sources.md)).

- sovereign:

  Logical scalar. When `TRUE`, the point is treated as sensitive (a
  sovereign-data coordinate – a grower's paddock, a trial site) and
  coarsening is applied by default so the exact GPS never leaves the
  host (see `coarsen`). Defaults to `FALSE`.

- coarsen:

  Coordinate-coarsening policy applied to `lon`/`lat` **before** any
  upstream call, so the exact coordinate is never transmitted. One of:
  `NULL` (no coarsening; the default for a non-sovereign point); a
  single positive number giving the rounding precision in degrees (for
  example `0.01` rounds to roughly a 1 km cell); or a
  `list(grid = <size>)` snapping each coordinate to the nearest multiple
  of `<size>` degrees. For a `sovereign = TRUE` point with
  `coarsen = NULL`, a default precision of `0.01` degrees is applied
  automatically. The request records **both** the raw-requested
  coordinate and the coarsened-sent coordinate.

## Value

An object of class `geo_point_request`. When coarsening is applied,
`lon`/`lat` hold the coarsened coordinate (what is sent upstream) and
`lon_raw`/`lat_raw` hold the exact requested coordinate (kept on the
host for provenance); `coarsen_policy` records the policy as a string.

## See also

[`collect_point()`](https://max578.github.io/terroir/reference/collect_point.md),
[`list_sources()`](https://max578.github.io/terroir/reference/list_sources.md)

## Examples

``` r
geo_point_request(138.6, -34.92, "2020-01-01", "2020-01-31",
                  variables = c("T2M", "PRECTOTCORR"), source = "nasapower")
#> <geo_point_request> source "nasapower"
#> point: (138.6, -34.92) range: 2020-01-01 .. 2020-01-31
#> variables: T2M, PRECTOTCORR

# A sovereign point: the exact GPS is coarsened to ~1 km before any call.
geo_point_request(138.63124, -34.92871, "2020-01-01", "2020-01-31",
                  source = "nasapower", sovereign = TRUE)
#> <geo_point_request> source "nasapower"
#> point: (138.63, -34.93) range: 2020-01-01 .. 2020-01-31
#> variables: (adapter default)
#> coarsened (sovereign): raw (138.63124, -34.92871) -> sent (138.63, -34.93)
#> policy "precision=0.01"
```
