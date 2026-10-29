# Is a series a replayed (offline) fixture?

Reports whether a
[geo_point_series](https://max578.github.io/terroir/reference/new_geo_point_series.md)
was produced by the offline replay path
(`collect_point(request, offline = TRUE)`) rather than a live upstream
call. A replayed series carries `replayed = TRUE` in its provenance and
keeps the recording's `retrieved_at` rather than a fresh timestamp, so a
consumer can always tell a cached series from a live one.

## Usage

``` r
is_replayed(x)
```

## Arguments

- x:

  A `geo_point_series` (or any object).

## Value

Logical scalar; `TRUE` only for a replayed series.

## See also

[`collect_point()`](https://max578.github.io/terroir/reference/collect_point.md)
