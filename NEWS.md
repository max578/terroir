# terroir (development version)

## A global soil source

* **New source `isric`: ISRIC SoilGrids point profiles, global and keyless.**
  Texture, organic carbon, pH, bulk density, CEC, nitrogen and the water limits
  LL15/DUL/SAT, one value per property per depth layer, retrieved through
  `apsimx`. This closes the gap a running study had already routed around:
  `studies/A0/01_generate_belt.R` reached past terroir into `apsimx` for soil
  and left the uplift note behind, because a grain decision needs soil as much
  as it needs weather.

* **It does not intersect `nert`.** nert serves TERN soil, but over Australia
  only and only with a key. `isric` is global and keyless, so inside Australia a
  caller may prefer TERN's measured products and everywhere else this is the
  only soil terroir has.

* **Soil is dateless by design.** The `date` column is `NA` for a soil series
  rather than stamped with the retrieval time: a time-invariant property carrying
  a date invites a consumer to difference two retrievals as though something had
  changed.

* **Soil plausibility bounds join the value conformer.** Texture, pH, bulk
  density, carbon, CEC, nitrogen and the water limits are range-checked at the
  contract. SoilGrids' own service returns integers scaled by ten and `apsimx`
  unscales them, so the scale error is one upstream change away rather than
  impossible, and it is the same class the NDVI bound already guards.

* **The statistic is selectable, within an honest limit.** `mean` or `Q0.5`.
  ISRIC publishes Q0.05 and Q0.95 as well, which is what would let soil enter an
  analysis as a prior rather than a point value, but the upstream wrapper does
  not expose them; asking for one refuses typed rather than quietly returning the
  mean under a quantile's name.

# terroir (development version)

* Vignettes brought to the orchestra's vignette quality bar v1.

# terroir 0.3.0

* **New source: ocular / Microsoft Planetary Computer (`source = "ocular"`).**
  Sentinel-2 and Landsat spectral-index series (NDVI by default) over a 500 m
  square window centred on the point, retrieved through the `ocular` package
  (AAGI-AUS) from the Planetary Computer SpatioTemporal Asset Catalog. No key.
  `variables[1]` selects the index, `variables[2]` the sensor (`"auto"`,
  `"sentinel-2"`, `"landsat-8"`, `"landsat-5"`). ocular is an *upstream*, not
  an ORCHESTRA member: it sits in `Suggests`, is reached only through
  `requireNamespace()`, is commit-pinned in `Remotes:`, and every error or
  warning it raises is converted into a `terroir_refusal` -- no upstream
  condition reaches the caller untyped. The adapter registers a
  `[-180, -80] x [180, 84]` extent, because ocular builds its window in UTM and
  is undefined outside that latitude band.
* **Pixel cloud masking is on by default, and is terroir's own.** The series is
  masked against the Sentinel-2 Scene Classification Layer (classes 0, 1, 3, 8,
  9, 10, 11) or the Landsat Collection-2 `QA_PIXEL` bits (0-5); scene-level
  cloud filtering alone leaves cloudy pixels in the window and collapses the
  index on overcast dates. The mask is applied to the returned index rasters
  rather than through the upstream's own `scl_classes` argument, because at the
  pinned commit that argument silently drops every scene (its band list reaches
  `do.call()` named, so the mask branch operates on a plain list and errors into
  the per-scene handler). A date whose window is entirely masked is dropped from
  the series rather than returned as a spurious near-zero index.
* **Vendored upstream patch for ocular's tile merge.** `ocular:::.mergeRasterTiles()`
  splices a *named* raster list into `do.call()`, so every multi-tile date fails
  with `argument "x" is missing`. terroir installs a behaviourally identical
  replacement that unnames the list, into ocular's namespace, on first use of
  the adapter (never at package load) and once per session. It is declared in
  the returned provenance and is removed when the fix lands upstream.
* **Retrieval provenance on an ocular series.** Beyond the contract's five
  provenance fields, an ocular series carries the STAC endpoint and collection
  id, the resolved sensor, the index name, the window size, the scene-level
  cloud ceiling, the mask asset / kind / class set, the scene dates, the scene
  ids and the ocular commit actually installed (read from ocular's own
  `DESCRIPTION`, so a drifted install is visible rather than assumed). Scene ids
  are read verbatim out of the returned asset URLs -- ocular's scene records do
  not retain the STAC item id -- and are `NA` when no identifier is present; the
  signed URLs themselves are never recorded.
* **Unmaskable scene refuses.** A scene whose STAC item carries no SCL /
  `QA_PIXEL` asset cannot be cloud-masked; the adapter refuses (naming the scene
  date and the missing asset) rather than returning it unmasked inside a series
  advertised as cloud-masked.
* **Two external-fact families grounded.** `ocular.stac_collection_id`
  (`sentinel-2-l2a`, `landsat-c2-l2`) and `ocular.stac_endpoint` were resolved
  against the Planetary Computer STAC catalogue on 2026-09-02 -- each collection
  endpoint returned its own `id` -- and carry a real `verified_on`. The adapter
  additionally re-checks the asserted collection id against the one ocular
  configures for the resolved sensor at call time, and refuses on a mismatch
  rather than mislabelling the provenance.

* **`collect_points()`: batch/panel collection over a list of requests.** The
  fleet-audit-named batch verb (T-11): dispatches each request through
  [collect_point()] and stacks the results into one `data.table`, tagged with
  a `request_index` and a `status` (`"ok"`/`"refused"`) column. A refusal is
  kept as a row (with its reason recorded), never dropped from the stack, so
  a multi-site collection still accounts for every request it was given.
* **Refusal, not abort, on an implausible value.** `collect_point()`'s
  value-plausibility conformer (out-of-range NDVI/EVI or temperature) now
  returns a structured `terroir_refusal` instead of aborting the call, so one
  bad cell no longer stops a whole collection. `verify_geo_series()` called
  directly is unchanged and still aborts.
* **Removed the inert `radius` formal from `geo_point_request()`.** It was
  documented, validated and stored, but read by no adapter -- no registered
  source implements a nearest-station or buffer search today. Reintroduce it
  (on the SILO/GSOD nearest-station path) if/when such a source is added.
  Breaking for any caller passing `radius = `.
* **Continuous integration.** Added `R-CMD-check` (macOS / Windows / Ubuntu,
  release/devel/oldrel-1) -- the fixture-replay tests need no network and no
  keys, so the whole suite runs clean-room on every push/PR to `main`.
* **New `geo_point_schema()`.** Exports the fixed ten-column C6 response
  schema, so a sibling package can read the contract's column order instead
  of reaching into the internal `terroir:::.geo_point_cols`.
* **Documentation pass.** The vignette now gains a small-multiple figure of a
  replayed series (temperature and precipitation panels, captioned and
  interpreted), lists `nert` in the sources table, drops the stale
  "flexyBayes constellation" framing (now "the ORCHESTRA", also fixed in
  `DESCRIPTION` and `README.md`), and states plainly that `unit` is not yet
  populated for the `nasapower`/`silo`/`abares` adapters. README rewritten
  with an install section, a runnable offline example, and a corrected
  Status/Sources section (was stale at v0.0.0.9000). `collect_point()`,
  `verify_geo_series()` and `register_source()` gained `@examples`.

# terroir 0.2.0

* **New source: nert / TERN (`source = "nert"`).** Point-extracts TERN's
  Australian soil, soil-moisture (SMIPS), actual-evapotranspiration, canopy-height
  and phenology layers via the `nert` package (AAGI-AUS), behind the standard
  request/response contract (free TERN API key; Australia extent; refuses keyless
  or out-of-coverage). **Independent-Oracle discipline:** nert is the flagship
  co-hallucinated-oracle case, so terroir consumes the *reviewed* nert 1.1.0 and
  does not trust it blindly -- only finite COG values are emitted (an all-NA return
  is refused, never blanked; a character-class layer such as ASC soil-order is
  dropped, not coerced), and the TERN dataset-id facts terroir asserts are
  registered in `terroir_external_facts()` as honestly `[unverified]` (their oracle
  is the TERN catalogue directly -- not nert's own grounding -- and has not yet
  been diffed in a recorded session). `nert` is a `Suggests` (+ `Remotes:
  AAGI-AUS/nert`).

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
