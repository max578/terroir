# The fixed C6 response schema

Returns the ten column names every
[geo_point_series](https://max578.github.io/terroir/reference/new_geo_point_series.md)
carries, in contract order. Column order is part of contract C6, so a
sibling package typing against terroir's output should read the schema
from here rather than hard-coding it.

## Usage

``` r
geo_point_schema()
```

## Value

A character vector of column names.

## Examples

``` r
geo_point_schema()
#>  [1] "lon"            "lat"            "date"           "variable"      
#>  [5] "value"          "unit"           "source"         "source_version"
#>  [9] "retrieved_at"   "license"       
```
