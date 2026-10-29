# Collect geo-point data for one request

The single entry point of the C6 contract. Dispatches a
[`geo_point_request()`](https://max578.github.io/terroir/reference/geo_point_request.md)
to its registered source adapter and returns a verified
[geo_point_series](https://max578.github.io/terroir/reference/new_geo_point_series.md),
or a structured
[refusal](https://max578.github.io/terroir/reference/is_refusal.md) when
the source is unknown or its package is not installed.

## Usage

``` r
collect_point(
  request,
  retrieved_at = NULL,
  offline = getOption("terroir.offline", FALSE)
)
```

## Arguments

- request:

  A `geo_point_request` from
  [`geo_point_request()`](https://max578.github.io/terroir/reference/geo_point_request.md).

- retrieved_at:

  Optional character scalar timestamp (provenance). Defaults to the
  current time. Ignored in offline mode (a replayed series keeps the
  fixture's recorded timestamp).

- offline:

  Logical scalar. When `TRUE`, answer from a recorded fixture with zero
  network egress (see Details). Defaults to the `terroir.offline`
  option, otherwise `FALSE`.

## Value

A `geo_point_series`, or a `terroir_refusal` – including when the
returned values fail the value-plausibility conformer (an implausible
NDVI/EVI or temperature reading), which is refused rather than aborted
so one bad cell does not stop a multi-site collection.

## Details

`collect_point()` performs network input/output, so it stamps
`retrieved_at` with the current time by default; pass `retrieved_at` for
reproducible runs.

In **offline mode** (`offline = TRUE`, or globally via
`options(terroir.offline = TRUE)`) the request is answered from a
recorded fixture with no network egress at all: the matching cached
series is replayed with its provenance marked `replayed = TRUE` and its
original `retrieved_at` preserved (see
[`is_replayed()`](https://max578.github.io/terroir/reference/is_replayed.md)).
This lets a sovereign-coordinate trial run with zero upstream contact,
and makes a pipeline reproducible bit-for-bit. When no recorded fixture
answers the request, offline mode returns a structured refusal rather
than silently falling back to the network. The fixture directory is the
`terroir.fixture_dir` option if set, otherwise the installed package's
`fixtures/` directory.

## See also

[`geo_point_request()`](https://max578.github.io/terroir/reference/geo_point_request.md),
[`list_sources()`](https://max578.github.io/terroir/reference/list_sources.md),
[`verify_geo_series()`](https://max578.github.io/terroir/reference/verify_geo_series.md),
[`is_replayed()`](https://max578.github.io/terroir/reference/is_replayed.md)

## Examples

``` r
req <- geo_point_request(
  lon = 138.6, lat = -34.92,
  start = "2020-01-01", end = "2020-01-10",
  variables = c("T2M", "PRECTOTCORR"),
  source = "nasapower"
)
# offline = TRUE answers from the shipped fixture -- no network egress
series <- collect_point(req, offline = TRUE)
series
#> <geo_point_series> 20 rows from "nasapower" (v4.2.5)
#> variables: "T2M" and "PRECTOTCORR" licence: NASA POWER (free, public)
#>       lon    lat       date    variable value   unit    source source_version
#>     <num>  <num>     <Date>      <char> <num> <char>    <char>         <char>
#>  1: 138.6 -34.92 2020-01-01         T2M 20.10   <NA> nasapower          4.2.5
#>  2: 138.6 -34.92 2020-01-02         T2M 23.73   <NA> nasapower          4.2.5
#>  3: 138.6 -34.92 2020-01-03         T2M 29.87   <NA> nasapower          4.2.5
#>  4: 138.6 -34.92 2020-01-04         T2M 19.48   <NA> nasapower          4.2.5
#>  5: 138.6 -34.92 2020-01-05         T2M 15.50   <NA> nasapower          4.2.5
#>  6: 138.6 -34.92 2020-01-06         T2M 19.54   <NA> nasapower          4.2.5
#>  7: 138.6 -34.92 2020-01-07         T2M 23.00   <NA> nasapower          4.2.5
#>  8: 138.6 -34.92 2020-01-08         T2M 26.74   <NA> nasapower          4.2.5
#>  9: 138.6 -34.92 2020-01-09         T2M 31.06   <NA> nasapower          4.2.5
#> 10: 138.6 -34.92 2020-01-10         T2M 20.32   <NA> nasapower          4.2.5
#> 11: 138.6 -34.92 2020-01-01 PRECTOTCORR  0.00   <NA> nasapower          4.2.5
#> 12: 138.6 -34.92 2020-01-02 PRECTOTCORR  0.00   <NA> nasapower          4.2.5
#> 13: 138.6 -34.92 2020-01-03 PRECTOTCORR  0.00   <NA> nasapower          4.2.5
#> 14: 138.6 -34.92 2020-01-04 PRECTOTCORR  0.00   <NA> nasapower          4.2.5
#> 15: 138.6 -34.92 2020-01-05 PRECTOTCORR  0.03   <NA> nasapower          4.2.5
#> 16: 138.6 -34.92 2020-01-06 PRECTOTCORR  0.00   <NA> nasapower          4.2.5
#> 17: 138.6 -34.92 2020-01-07 PRECTOTCORR  0.00   <NA> nasapower          4.2.5
#> 18: 138.6 -34.92 2020-01-08 PRECTOTCORR  0.00   <NA> nasapower          4.2.5
#> 19: 138.6 -34.92 2020-01-09 PRECTOTCORR  0.00   <NA> nasapower          4.2.5
#> 20: 138.6 -34.92 2020-01-10 PRECTOTCORR  0.06   <NA> nasapower          4.2.5
#>       lon    lat       date    variable value   unit    source source_version
#>     <num>  <num>     <Date>      <char> <num> <char>    <char>         <char>
#>            retrieved_at                   license
#>                  <char>                    <char>
#>  1: 2026-06-02 00:00:00 NASA POWER (free, public)
#>  2: 2026-06-02 00:00:00 NASA POWER (free, public)
#>  3: 2026-06-02 00:00:00 NASA POWER (free, public)
#>  4: 2026-06-02 00:00:00 NASA POWER (free, public)
#>  5: 2026-06-02 00:00:00 NASA POWER (free, public)
#>  6: 2026-06-02 00:00:00 NASA POWER (free, public)
#>  7: 2026-06-02 00:00:00 NASA POWER (free, public)
#>  8: 2026-06-02 00:00:00 NASA POWER (free, public)
#>  9: 2026-06-02 00:00:00 NASA POWER (free, public)
#> 10: 2026-06-02 00:00:00 NASA POWER (free, public)
#> 11: 2026-06-02 00:00:00 NASA POWER (free, public)
#> 12: 2026-06-02 00:00:00 NASA POWER (free, public)
#> 13: 2026-06-02 00:00:00 NASA POWER (free, public)
#> 14: 2026-06-02 00:00:00 NASA POWER (free, public)
#> 15: 2026-06-02 00:00:00 NASA POWER (free, public)
#> 16: 2026-06-02 00:00:00 NASA POWER (free, public)
#> 17: 2026-06-02 00:00:00 NASA POWER (free, public)
#> 18: 2026-06-02 00:00:00 NASA POWER (free, public)
#> 19: 2026-06-02 00:00:00 NASA POWER (free, public)
#> 20: 2026-06-02 00:00:00 NASA POWER (free, public)
#>            retrieved_at                   license
#>                  <char>                    <char>
is_replayed(series)
#> [1] TRUE

# an unknown source returns a structured refusal, never an error
out <- collect_point(geo_point_request(0, 0, source = "not_a_source"))
#> Warning: terroir refused: unknown source 'not_a_source' (see list_sources())
is_refusal(out)
#> [1] TRUE
```
