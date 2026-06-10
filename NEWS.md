# terroir 0.0.0.9000

* **Independent Oracle Principle (Phase-1 grounding).** External-authority
  facts are no longer grounded only against package-generated goldens.
  - `terroir_external_facts()` / `terroir_fact_status()`: a provenance registry
    enumerating every asserted fact (MODIS product/band/scale, SILO variable
    codes, ABARES AGFD layer names, Sentinel-2 band mapping) with the oracle
    that grounds it and a `verified_on` date; seeds ship all `[unverified]`.
  - `test-catalogue-diff.R`: independent-oracle tests that diff the asserted
    codes against each authority's *own* catalogue (`MODISTools::mt_products()`
    / `mt_bands()`, weatherOz SILO values, the AGFD data dictionary).
  - The MODIS adapter now **refuses** when the authoritative NDVI scale is
    absent rather than defaulting to `1` (a silent 10,000x error).
  - `verify_geo_series()` gained a value-plausibility conformer (NDVI in
    `[-1, 1]`, physical temperature bounds), and `register_source()` /
    `collect_point()` gained a per-source spatial `extent` so an
    Australia-only source is refused when queried outside its coverage.

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
