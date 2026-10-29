# Collect geo-point data for a batch of requests

Batch/panel form of
[`collect_point()`](https://max578.github.io/terroir/reference/collect_point.md).
Stacks the results of every request in `requests` into one long
`data.table`, one row per `(request x date x variable)` for a successful
collection or exactly one row for a refused request. Every per-request
refusal path of
[`collect_point()`](https://max578.github.io/terroir/reference/collect_point.md)
(unknown source, missing package, out-of-extent point, implausible
value) applies identically.

## Usage

``` r
collect_points(
  requests,
  retrieved_at = NULL,
  offline = getOption("terroir.offline", FALSE)
)
```

## Arguments

- requests:

  A non-empty list of `geo_point_request` objects (see
  [`geo_point_request()`](https://max578.github.io/terroir/reference/geo_point_request.md)).

- retrieved_at, offline:

  As for
  [`collect_point()`](https://max578.github.io/terroir/reference/collect_point.md);
  the same value is passed through to every request in the batch.

## Value

A `data.table` with a leading `request_index` (position in `requests`)
and `status` (`"ok"` or `"refused"`) column, a `reason` column
(`NA_character_` for an `"ok"` row, the refusal message otherwise),
followed by the fixed C6 `geo_point_series` columns. `lon`, `lat` and
`source` are populated on a refused row from the request itself (the
values known even when nothing was collected); the remaining C6 columns
are `NA` on a refused row. A final `call` column carries the upstream
call recorded in each series' provenance.

## Details

Requests are grouped by source. A source registered with a `batch`
function (see
[`register_source()`](https://max578.github.io/terroir/reference/register_source.md))
receives all of its requests in one call, so a raster is read once for
many points. Other sources are called one request at a time. Offline
mode always answers one request at a time from fixtures.

A refusal is never dropped from the stack: it contributes one row with
`status == "refused"` and `reason` set to the refusal's message, so a
40-site collection with two dead sources still returns 40 requests'
worth of accounting, not 38.

## See also

[`collect_point()`](https://max578.github.io/terroir/reference/collect_point.md),
[`geo_point_request()`](https://max578.github.io/terroir/reference/geo_point_request.md),
[`is_refusal()`](https://max578.github.io/terroir/reference/is_refusal.md)

## Examples

``` r
reqs <- list(
  geo_point_request(138.6, -34.9, "2020-01-01", "2020-01-31",
                    source = "nasapower"),
  geo_point_request(0, 0, source = "no_such_source")
)
out <- suppressWarnings(collect_points(reqs, offline = TRUE))
out$status
#> [1] "refused" "refused"
```
