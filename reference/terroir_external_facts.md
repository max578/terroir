# terroir's external-authority fact registry

Enumerates every fact terroir asserts about an external data authority
(MODIS product / band / scale, SILO variable codes, ABARES farm-data
layer names, Sentinel-2 band mapping) together with its grounding
provenance. A fact is *grounded* only when it has been diffed against
the authority that owns it on a recorded date; until then it is
ungrounded. The catalogue-diff oracle test grounds them at check time.

## Usage

``` r
terroir_external_facts()
```

## Value

A `data.table` keyed by `source`, `fact_family`, with columns
`asserted_value`, `oracle_kind` (the authority that grounds the fact),
`verified_on` (`Date` or `NA`), `evidence_path`, and a derived
`grounding` token (`"grounded"` / `"ungrounded"`).

## Examples

``` r
facts <- terroir_external_facts()
facts[fact_family == "scale_factor"]
#> Key: <source, fact_family>
#>    source  fact_family asserted_value    oracle_kind verified_on evidence_path
#>    <char>       <char>         <char>         <char>      <Date>        <char>
#> 1:  modis scale_factor         0.0001 live_catalogue  2026-06-13          <NA>
#>    grounding
#>       <char>
#> 1:  grounded
```
