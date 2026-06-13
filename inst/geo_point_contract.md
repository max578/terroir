# terroir geo-point data contract (C6, v1)

<!-- constellation-contract: machine-readable header; charter at flexyBayes_dev/CONSTELLATION.md -->
```yaml
contract: geo_point_series
id: C6
version: 1
kind: data
owner: terroir
object_system: S3
consumers: [flexyBayes, kernR, PESTO]
conformance_test: "verify_geo_series() (schema + units + provenance) + per-adapter golden-file round-trip + free-source assertion"
charter: flexyBayes_dev/CONSTELLATION.md
status: stable (v0.1.0 dev). The C6 machinery (request / series / verify /
  registry / offline replay / coarsening) and the response schema are stable.
  Adapter grounding is mixed and recorded in terroir_external_facts(): the
  nasapower (variable codes) and modis (product / band / NDVI scale) adapters
  are live-verified against their authorities (2026-06-13); the silo, abares and
  stac adapters remain draft (their authoritative oracle has not yet been run in
  a recorded session -- honestly [unverified], not silently asserted).
```

**Object system: S3 (deliberate).** terroir is a C6 *producer* -- a classed
`data.table` (`geo_point_series`) plus an attribute-carried provenance record
and an optional-manifest pattern, the same shape as `masque`. S3 is the right
fit for a producer of a tabular contract: it is transparent to a consumer
(`inherits(x, "geo_point_series")` + the fixed columns), needs no formal class
machinery for what is fundamentally a tagged table, and keeps the dependency
surface minimal. An S7 migration is **out of scope** -- it would buy nothing for
a producer and would add ceremony the contract does not need. The inference-hub
members (PESTO, flexyBayes) own the S7 manifest contract; a data collector does
not need to.

The contract terroir exposes so the constellation can pull climate, weather,
vegetation-index, soil, elevation and agricultural-economics data **for a
geographic point** from many free sources behind one uniform surface --- without
any consumer depending on a source package's internals.

## Role: data collector

terroir is the constellation's **data-collector** member. It wraps named external
data packages as **adapters** behind a single point-keyed request/response
contract. It is a *producer*: data flows terroir -> flexyBayes / kernR / PESTO
(covariates, validation series, calibration forcings). It never models.

## Request

```r
geo_point_request(
  lon, lat,                 # WGS84 decimal degrees (EPSG:4326)
  start, end,               # ISO-8601 dates; ignored by static layers
  variables,                # character vector of canonical variable names
  source,                   # one registered adapter id (see registry)
  radius = NULL             # optional: nearest-station / buffer for grid/station sources
)
```

## Response: `geo_point_series`

A tidy `data.table`, one row per (date x variable), with a fixed schema:

| column | meaning |
|---|---|
| `lon`, `lat` | the requested point (and, for station sources, the resolved station coords) |
| `date` | observation date (`NA` for static layers, e.g. soil, elevation) |
| `variable` | canonical variable name |
| `value` | numeric |
| `unit` | units string |
| `source` | adapter id |
| `source_version` | upstream package version |
| `retrieved_at` | retrieval timestamp (passed in / stamped by caller; never `Sys.time()` inside pure code) |
| `license` | licence string for the returned data |

Provenance (source, version, retrieval, licence, the exact upstream call) is
carried as an attribute and is **mandatory** --- a series with missing provenance
fails conformance.

## Free-only rule (data-collector role invariant)

**Every registered adapter must reach a free data source** --- no purchased data,
no paid API tier. Adapters needing a key use a *free* key, documented in the
adapter. Each adapter declares `free = TRUE`; the registry refuses a non-free
adapter. (Charter Security: no off-machine routing of restricted data; these are
all public/open sources, tier-1.)

## Adapter registry (mirrors the C5 `ensemble_source` pattern)

One adapter per source, each in `Suggests:` + `check_installed()` so terroir is
**standalone-functional** (it builds and checks with no source installed; a missing
source yields a structured refusal, never a break). Registered sources:

| adapter id | upstream package | domain | point access | free |
|---|---|---|---|---|
| `nasapower` | nasapower (ropensci) | global climate + solar, daily/monthly | lon/lat, no key | yes |
| `silo` / `bom` / `dpird` | weatherOz (ropensci) | SILO 5 km grid + BOM + DPIRD (Australia) | grid cell / nearest station | yes |
| `gsod` | GSODR (ropensci) | global daily station weather | nearest station | yes |
| `abares` | read.abares (ropensci) | Australian agric. economics / land-use / soil / trade | gridded + regional | yes (CC) |
| `modis` | MODISTools (ropensci) | MODIS NDVI/EVI time series (ORNL) | lat/lon pixel | yes |
| `stac` | rsi (+ rstac) | Sentinel-2 / Landsat indices via Planetary Computer | AOI/point extract | yes |
| `worldclim` / `soilgrids` / `elevation` | geodata | WorldClim normals + SoilGrids + elevation, global | extract at point | yes |
| `chirps` | chirps (ropensci) | CHIRPS rainfall, global | point | yes |
| `tern` | nert (**AAGI-AUS**) | TERN ecosystem (flux/soil/ecology), Australia | point | yes |

**Derived index (transform, not a source):** `spi` via SPIChanges --- computes the
Standardized Precipitation Index + trend changes from a precipitation series the
collector already fetched (e.g. CHIRPS / SILO). Lives as a post-fetch transform,
not an adapter.

**Excluded:** suwo (biodiversity *media* --- off-domain; non-commercial-only
restriction conflicts with the business arm).

## Conformance

An adapter honours C6 by: accepting the canonical request, returning the fixed
schema with units, attaching mandatory provenance, declaring `free = TRUE`, and
passing a recorded **golden-file round-trip** test (a cached small response so the
test runs offline and pins the schema). `verify_geo_series()` checks schema +
units + provenance presence.

## Notes

- terroir is a **Max-owned personal package** (`max578`, MIT-track). The AAGI-AUS
  canon does **not** apply to it. `nert` is AAGI-AUS but is consumed only as a
  named external upstream (an adapter calling a published package), so no canon
  crosses into terroir.
- All registered sources are **named external upstreams, not constellation
  members** (the `apsimx` precedent). terroir is the single member that fronts them.
