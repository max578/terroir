# Package index

## Request and collect

Build a point-keyed request and collect a provenance-stamped series (the
C6 geo_point_series contract). Offline replay reads recorded fixtures
with zero network egress.

- [`geo_point_request()`](https://max578.github.io/terroir/reference/geo_point_request.md)
  : Construct a geo-point data request
- [`collect_point()`](https://max578.github.io/terroir/reference/collect_point.md)
  : Collect geo-point data for one request
- [`collect_points()`](https://max578.github.io/terroir/reference/collect_points.md)
  : Collect geo-point data for a batch of requests
- [`is_replayed()`](https://max578.github.io/terroir/reference/is_replayed.md)
  : Is a series a replayed (offline) fixture?

## The series contract

Construct and verify a geo_point_series against the fixed C6 schema and
its mandatory provenance.

- [`new_geo_point_series()`](https://max578.github.io/terroir/reference/new_geo_point_series.md)
  :

  Build a `geo_point_series` from a long-format table

- [`verify_geo_series()`](https://max578.github.io/terroir/reference/verify_geo_series.md)
  :

  Verify a `geo_point_series` against contract C6

- [`geo_point_schema()`](https://max578.github.io/terroir/reference/geo_point_schema.md)
  : The fixed C6 response schema

## Source registry

The free-only source registry and its structured refusals.

- [`register_source()`](https://max578.github.io/terroir/reference/register_source.md)
  : Register a data-source adapter
- [`list_sources()`](https://max578.github.io/terroir/reference/list_sources.md)
  : List registered data sources
- [`is_refusal()`](https://max578.github.io/terroir/reference/is_refusal.md)
  : Is an object a terroir refusal?

## External-fact grounding

The Independent-Oracle-Principle registry: every asserted external fact,
the authority that grounds it, and the date it was last diffed.

- [`terroir_external_facts()`](https://max578.github.io/terroir/reference/terroir_external_facts.md)
  : terroir's external-authority fact registry
- [`terroir_fact_status()`](https://max578.github.io/terroir/reference/terroir_fact_status.md)
  : Grounding status summary for terroir's external facts
