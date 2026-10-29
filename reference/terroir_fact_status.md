# Grounding status summary for terroir's external facts

One row per `(source, fact_family)` with the count of grounded vs
unverified asserted values – a glance-able audit of how much of
terroir's external-fact surface has been checked against its
authorities.

## Usage

``` r
terroir_fact_status()
```

## Value

A `data.table` with `source`, `fact_family`, `n_facts`, `n_grounded`,
`n_unverified`.
