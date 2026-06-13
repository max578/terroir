# terroir 0.1.0

* **User-facing offline / fixture-replay mode.** `collect_point(req, offline =
  TRUE)` (or `options(terroir.offline = TRUE)`) answers a request from a
  recorded fixture with **zero network egress** -- the sovereign-coordinate and
  reproducible-pipeline use cases. The fixtures (one per CORE source) ship in
  `inst/fixtures/` with a manifest keyed by `(source, lon, lat, date-range,
  variables)`; a matched series is replayed with provenance marked `replayed =
  TRUE` and the recording's original `retrieved_at` preserved (`is_replayed()`).
  When no fixture answers a request, offline mode returns a structured refusal
  rather than silently reaching the network. Offline mode needs no `Suggests`
  package installed. A custom fixture directory is set via
  `options(terroir.fixture_dir = )`.

* **Coarsened-coordinate (sovereign-GPS) mode.** `geo_point_request()` gains
  `sovereign` and `coarsen`. A point flagged `sovereign = TRUE` is coarsened to
  roughly a one-kilometre cell (precision `0.01` degrees) **before** any upstream
  call, so the exact GPS never leaves the host; `coarsen` also takes an explicit
  precision (a single number, degrees) or a grid snap (`list(grid = <size>)`)
  for a non-sovereign point. The request and the returned series' provenance
  record **both** the raw-requested and the coarsened-sent coordinates plus the
  policy. The privacy primitive is additive to C6: the fixed ten-column series
  schema is unchanged, so existing consumers are unaffected.

* **Live-grounded external facts (Independent Oracle Principle).** The MODIS
  (product `MOD13Q1`, band `250m_16_days_NDVI`, NDVI scale `0.0001`) and NASA
  POWER (`T2M`, `PRECTOTCORR`) fact families were diffed against their
  authorities' own catalogues -- the live ORNL DAAC `MODISTools::mt_products()`
  / `mt_bands()` records and the NASA POWER parameter dictionary -- and carry a
  real `verified_on` (2026-06-13) in `terroir_external_facts()`. A new
  `nasapower_variable_code` family is enumerated. The SILO, ABARES and
  Sentinel-2 STAC families stay honestly `[unverified]` (no fabricated date):
  their authoritative oracle has not yet been run in a recorded session. The
  registry validator now reports grounding **per family** rather than
  all-or-nothing, so a grounded family passes while an un-grounded one fails
  with the honest reason.

* **Object system: S3 is the deliberate choice.** As a C6 *producer* (a classed
  `data.table` plus attribute-carried provenance and an optional-manifest
  pattern, the `masque` shape), terroir stays S3. An S7 migration is out of
  scope -- it buys nothing for a producer of a tabular contract. The
  inference-hub members own the S7 manifest contract; a collector does not need
  to.

* Release ceremony: a hand-crafted `inst/CITATION`; a `pkgdown` site
  (`_pkgdown.yml`); the *Collecting geo-point data with terroir* vignette gains
  offline-replay, sovereign-coordinate and live-collect sections; the C6
  contract status is lifted from draft to stable for the C6 machinery and the
  live-verified adapters.

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
