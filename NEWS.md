# terroir 0.0.0.9000

* Initial scaffold (constellation Phase 2). The data-collector member of the
  flexyBayes constellation.
* Contract C6 `geo_point_series`: `geo_point_request()`, `collect_point()`,
  `new_geo_point_series()`, `verify_geo_series()`, and the free-only source
  registry (`register_source()`, `list_sources()`).
* CORE adapters: `nasapower`, `silo` (weatherOz/SILO), `abares` (read.abares),
  `modis` (MODISTools), `stac` (rsi / Sentinel-2). `nasapower` is verified
  end-to-end; the network/key adapters ship with golden-file tests and a
  `data-raw/regenerate_golden.R` regeneration script.
* Structured refusals (`is_refusal()`) for unknown sources and missing source
  packages -- terroir builds and checks with no source package installed.
