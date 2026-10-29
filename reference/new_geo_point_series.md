# Build a `geo_point_series` from a long-format table

Adapter-facing constructor. Coerces a long table to the fixed C6 schema,
attaches mandatory provenance, and stamps the `geo_point_series` class.
Most users call
[`collect_point()`](https://max578.github.io/terroir/reference/collect_point.md)
rather than this directly.

## Usage

``` r
new_geo_point_series(
  dt,
  lon,
  lat,
  source,
  source_version,
  license,
  retrieved_at,
  call
)
```

## Arguments

- dt:

  A `data.frame`/`data.table` with at least `date`, `variable`, `value`
  columns (plus optional `unit`).

- lon, lat:

  Numeric scalars echoed onto every row.

- source, source_version, license:

  Character scalars (provenance).

- retrieved_at:

  Character scalar retrieval timestamp.

- call:

  Character scalar describing the upstream call (provenance).

## Value

A `geo_point_series` (a `data.table`) with provenance attached.
