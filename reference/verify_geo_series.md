# Verify a `geo_point_series` against contract C6

Checks the fixed schema, units column, and mandatory provenance. Fails
loudly (the constellation never silently accepts a malformed series).

## Usage

``` r
verify_geo_series(x)
```

## Arguments

- x:

  An object to verify.

## Value

Invisibly `TRUE` on success; otherwise an error.

## Examples

``` r
req <- geo_point_request(
  lon = 138.6, lat = -34.92,
  start = "2020-01-01", end = "2020-01-10",
  variables = c("T2M", "PRECTOTCORR"),
  source = "nasapower"
)
series <- collect_point(req, offline = TRUE)
verify_geo_series(series)
```
