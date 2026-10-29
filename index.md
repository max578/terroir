# terroir

**Geo-point environmental and agricultural-economics data collector.**
Hand `terroir` a coordinate and a date range and get back a tidy,
provenance-stamped series of climate, weather, vegetation-index, soil,
elevation or agricultural-economics data, pulled from many **free**
sources behind one contract.

`terroir` is the **data-collector member** of the ORCHESTRA – a producer
that supplies covariates and forcings to `flexyBayes`, `kernR` and
`PESTO`. See `../CONSTELLATION_MEMBER.md` and the contract spec
`inst/geo_point_contract.md` (C6).

## Related packages

- [geodata](https://CRAN.R-project.org/package=geodata) downloads
  geographic data for spatial analysis and mapping, including climate,
  crops, elevation, land use and soil.
- [nasapower](https://CRAN.R-project.org/package=nasapower) is a client
  for the NASA POWER global meteorology, solar energy and climatology
  API.
- [weatherOz](https://CRAN.R-project.org/package=weatherOz) downloads
  and formats Australian weather and climate data, including SILO.

terroir calls these packages, among others, as optional sources. It adds
one request for a point and a date range, one table layout for every
source, a provenance record on each result, offline replay from recorded
data, and optional coarsening of exact coordinates before any request
leaves the machine.

## Installation

``` r

# install.packages("remotes")
remotes::install_github("max578/terroir")
```

## Minimal example

``` r

library(terroir)

req <- geo_point_request(
  lon = 138.6, lat = -34.92,        # Adelaide
  start = "2020-01-01", end = "2020-01-10",
  variables = c("T2M", "PRECTOTCORR"),
  source = "nasapower"
)

# offline = TRUE answers from a shipped fixture -- no network egress,
# no source package required. Drop it (or set offline = FALSE) for a live pull.
series <- collect_point(req, offline = TRUE)
series
```

## Design

- **One contract (C6).**
  [`geo_point_request()`](https://max578.github.io/terroir/reference/geo_point_request.md)
  -\>
  [`collect_point()`](https://max578.github.io/terroir/reference/collect_point.md)
  -\> `geo_point_series` (a tidy `data.table` with a fixed schema +
  mandatory provenance, validated by
  [`verify_geo_series()`](https://max578.github.io/terroir/reference/verify_geo_series.md)).
- **Sources are optional adapters.** Each source package is in
  `Suggests`; terroir builds and `R CMD check`s clean with none
  installed. A missing source returns a structured refusal, never an
  error
  ([`is_refusal()`](https://max578.github.io/terroir/reference/is_refusal.md)).
- **Free-only.**
  [`register_source()`](https://max578.github.io/terroir/reference/register_source.md)
  refuses any adapter that is not free.
- **Offline replay.** `offline = TRUE` answers from a recorded fixture
  with zero network egress – reproducible pipelines, continuous
  integration, and sovereign coordinates that must never reach an
  upstream service.
- **Sovereign coordinates.** `sovereign = TRUE` coarsens an exact GPS
  point to roughly a one-kilometre cell before any upstream call; both
  the raw and the coarsened point are kept in provenance.

## Sources

Twelve adapters are registered;
[`list_sources()`](https://max578.github.io/terroir/reference/list_sources.md)
shows them.

| id | what it returns | key |
|----|----|----|
| `nasapower` | global daily climate and solar radiation | none |
| `silo` | SILO 5 km daily weather, Australia (via weatherOz) | free email key |
| `abares` | gridded farm economics (read.abares) | none |
| `modis` | MODIS NDVI/EVI, 16-day (MODISTools) | none |
| `stac` | Sentinel-2 NDVI via Planetary Computer (rsi) | none |
| `ocular` | Sentinel-2 / Landsat index series over a 500 m window, cloud-masked | none |
| `nert` | TERN soil, soil moisture, evapotranspiration, canopy height, Australia | free TERN key |
| `isric` | SoilGrids soil profile by depth layer (apsimx) | none |
| `soilgrids` | SoilGrids 2.0 means, nine properties at four depths to 60 cm (geodata) | none |
| `worldclim` | WorldClim 2.1 bioclimatic variables bio_1 to bio_19 (geodata) | none |
| `elevation` | SRTM 90 m elevation and slope (geodata) | none |
| `chirps` | CHIRPS 2.0 daily rainfall, 50 S to 50 N | none |

`worldclim` and `elevation` are free for non-commercial use only, and
the licence is recorded in each series. `soilgrids` is CC BY 4.0 and
`chirps` is public domain. GSODR is enrolled and not yet registered.

[`collect_points()`](https://max578.github.io/terroir/reference/collect_points.md)
takes many requests at once. The gridded sources and `nert` answer a
whole set of sites in one upstream call, and the result has a `call`
column holding that call. Downloaded rasters go to the directory in
`options(terroir.cache_dir = )`, by default the user cache directory for
terroir.

## Status

The contract machinery, offline replay and coordinate coarsening are
complete and tested; `nasapower`, `modis`, `abares` and `stac` are
verified end-to-end against recorded goldens, and `ocular` against a
live two-sensor regression pilot. Live golden fixtures for the
network/key adapters are regenerated by `data-raw/regenerate_golden.R`.

## Contributing

Bug reports and suggestions are welcome as [GitHub
issues](https://github.com/max578/terroir/issues).

## Citation

``` r

citation("terroir")
```

## Licence

MIT + file LICENSE. See
[LICENSE](https://max578.github.io/terroir/LICENSE) /
[LICENSE.md](https://max578.github.io/terroir/LICENSE.md).
