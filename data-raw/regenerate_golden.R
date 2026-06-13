# Regenerate the golden fixtures for terroir's source adapters.
#
# These call the live external services (some need a free API key or network),
# so they are NOT run during R CMD check -- the cached fixtures are what the
# offline golden tests AND the user-facing offline replay path read. The same
# fixtures are written to two places:
#   tests/testthat/_golden/  -- the offline golden round-trip tests;
#   inst/fixtures/           -- the shipped, user-invokable replay fixtures
#                               (collect_point(req, offline = TRUE)) plus a
#                               manifest.rds recording the request each answers.
# Re-run this (with the relevant packages installed + keys set) when an upstream
# API changes.
#
#   SILO_API_KEY=you@example.com Rscript data-raw/regenerate_golden.R

devtools::load_all(".")
`%||%` <- function(x, y) if (is.null(x)) y else x
out_dir <- "tests/testthat/_golden"
ship_dir <- "inst/fixtures"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(ship_dir, showWarnings = FALSE, recursive = TRUE)
stamp <- "2026-06-02 00:00:00"  # fixed for reproducible fixtures

# Records, per saved fixture, the request signature the offline replay path
# matches against (source, coords, range, variables) -- collected into the
# shipped manifest below.
.manifest_rows <- list()

save_golden <- function(id, req) {
  message("regenerating golden: ", id)
  s <- collect_point(req, retrieved_at = stamp)
  if (terroir::is_refusal(s)) {
    message("  refused: ", s$reason, " (skipping)")
    return(invisible(NULL))
  }
  # keep fixtures small
  if (nrow(s) > 20L) s <- s[1:20]
  saveRDS(s, file.path(out_dir, paste0(id, ".rds")))
  saveRDS(s, file.path(ship_dir, paste0(id, ".rds")))
  vars <- if (is.null(req$variables)) NA_character_ else
    paste(req$variables, collapse = ",")
  .manifest_rows[[length(.manifest_rows) + 1L]] <<- data.frame(
    source = req$source, file = paste0(id, ".rds"),
    lon = req$lon, lat = req$lat,
    start = req$start %||% NA_character_, end = req$end %||% NA_character_,
    variables = vars, retrieved_at = stamp, stringsAsFactors = FALSE)
}

adelaide <- c(lon = 138.6, lat = -34.92)

save_golden("nasapower", geo_point_request(
  adelaide["lon"], adelaide["lat"], "2020-01-01", "2020-01-10",
  variables = c("T2M", "PRECTOTCORR"), source = "nasapower"))

save_golden("silo", geo_point_request(
  adelaide["lon"], adelaide["lat"], "2020-01-01", "2020-01-10",
  source = "silo"))

save_golden("modis", geo_point_request(
  adelaide["lon"], adelaide["lat"], "2020-01-01", "2020-02-28",
  source = "modis"))

# ABARES gridded farm data covers agricultural land; the Adelaide CBD point is
# all-NA, so the abares golden uses a rural South Australian cropping point.
abares_point <- c(lon = 140.7, lat = -35.3)
save_golden("abares", geo_point_request(
  abares_point["lon"], abares_point["lat"], source = "abares"))

save_golden("stac", geo_point_request(
  adelaide["lon"], adelaide["lat"], "2020-01-01", "2020-01-31",
  source = "stac"))

# Write the shipped offline-replay manifest from whatever fixtures were saved.
if (length(.manifest_rows)) {
  manifest <- do.call(rbind, .manifest_rows)
  saveRDS(manifest, file.path(ship_dir, "manifest.rds"))
  message("wrote offline manifest: ", nrow(manifest), " fixture(s)")
}
