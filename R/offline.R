# ---------------------------------------------------------------------------
# Offline / fixture-replay mode. Promotes the recorded golden fixtures to a
# first-class, user-invokable replay path so a request can be answered with a
# cached `geo_point_series` and ZERO network egress -- the sovereign-coordinate
# use case (run a trial on a private point with no upstream call at all) and
# the reproducible-pipeline use case (re-run yesterday's collection bit-for-bit).
#
# A replayed series is marked in provenance with `replayed = TRUE` and keeps the
# fixture's own `retrieved_at` (never re-stamped to now), so a consumer can tell
# a cached series from a live one. Offline mode needs no Suggests package
# installed: it reads `.rds` fixtures and never touches an adapter.
# ---------------------------------------------------------------------------

# Resolve the directory holding the shipped fixtures. Resolution order:
#   1. the `terroir.fixture_dir` option, if set (user override);
#   2. the installed package's `inst/fixtures` (via system.file);
#   3. the source-tree `inst/fixtures` (devtools::load_all during development).
# Returns "" when no fixture directory can be found.
.fixture_dir <- function() {
  opt <- getOption("terroir.fixture_dir", default = NULL)
  if (!is.null(opt) && nzchar(opt) && dir.exists(opt)) return(opt)
  installed <- system.file("fixtures", package = "terroir")
  if (nzchar(installed) && dir.exists(installed)) return(installed)
  ""
}

# Load the fixture manifest (one row per shipped fixture, recording the request
# signature it answers). Returns NULL when no manifest is present.
.fixture_manifest <- function(dir = .fixture_dir()) {
  if (!nzchar(dir)) return(NULL)
  path <- file.path(dir, "manifest.rds")
  if (!file.exists(path)) return(NULL)
  tryCatch(readRDS(path), error = function(e) NULL)
}

# Match a request against the manifest. The fixture lookup key is
# (source, lon, lat, start, end, variables). Coordinates match within a small
# tolerance (fixtures are recorded at finite precision); a `NULL`/`NA` request
# field matches the fixture's recorded value for that field (so a default-
# variable request matches a default-variable fixture). Returns the matching
# manifest row (a one-row `data.frame`) or NULL when nothing matches.
.match_fixture <- function(request, manifest, tol = 1e-06) {
  if (is.null(manifest) || !nrow(manifest)) return(NULL)
  same_source <- manifest$source == request$source
  if (!any(same_source)) return(NULL)
  cand <- manifest[same_source, , drop = FALSE]

  req_vars <- if (is.null(request$variables)) {
    NA_character_
  } else {
    paste(request$variables, collapse = ",")
  }
  req_start <- request$start %||% NA_character_
  req_end <- request$end %||% NA_character_

  hit <- vapply(seq_len(nrow(cand)), function(i) {
    row <- cand[i, , drop = FALSE]
    coords_ok <- abs(row$lon - request$lon) <= tol &&
      abs(row$lat - request$lat) <= tol
    start_ok <- .field_match(req_start, row$start)
    end_ok <- .field_match(req_end, row$end)
    vars_ok <- .field_match(req_vars, row$variables)
    isTRUE(coords_ok && start_ok && end_ok && vars_ok)
  }, logical(1L))

  if (!any(hit)) return(NULL)
  cand[which(hit)[1L], , drop = FALSE]
}

# A request field matches a fixture field when they are equal, or when both are
# absent (`NA`). An absent request field does NOT match a present fixture field
# (a defaulted request must replay against a defaulted fixture, not a specific
# one), keeping the match exact.
.field_match <- function(req_value, fix_value) {
  if (is.na(req_value) && is.na(fix_value)) return(TRUE)
  if (is.na(req_value) || is.na(fix_value)) return(FALSE)
  identical(as.character(req_value), as.character(fix_value))
}

# Replay a request from a matched fixture. Reads the recorded series, re-stamps
# the requested point onto it (so the lon/lat columns echo what the caller
# asked for -- relevant when a coarsened point was recorded), and marks the
# provenance `replayed = TRUE` while preserving the fixture's `retrieved_at`.
.replay_fixture <- function(request, manifest_row, dir = .fixture_dir()) {
  path <- file.path(dir, manifest_row$file)
  if (!file.exists(path)) {
    return(.refuse(
      sprintf("offline: fixture file '%s' is missing from '%s'",
              manifest_row$file, dir),
      source = request$source, warn = FALSE
    ))
  }
  series <- tryCatch(readRDS(path), error = function(e) e)
  if (inherits(series, "error")) {
    return(.refuse(
      sprintf("offline: could not read fixture '%s': %s",
              manifest_row$file, conditionMessage(series)),
      source = request$source, warn = FALSE
    ))
  }
  if (!inherits(series, "geo_point_series")) {
    return(.refuse(
      sprintf("offline: fixture '%s' is not a geo_point_series",
              manifest_row$file),
      source = request$source, warn = FALSE
    ))
  }
  prov <- attr(series, "provenance")
  prov$replayed <- TRUE
  data.table::setattr(series, "provenance", prov)
  series
}

# The offline branch of collect_point(). Looks the request up in the fixture
# manifest and replays the matching fixture, or returns a structured refusal
# when no fixture answers the request -- it NEVER falls back to the network
# (that would defeat the zero-egress guarantee). `retrieved_at` is ignored in
# offline mode: a replayed series keeps the fixture's recorded timestamp.
.collect_offline <- function(request) {
  dir <- .fixture_dir()
  if (!nzchar(dir)) {
    return(.refuse(
      paste0("offline: no fixture directory found (set ",
             "options(terroir.fixture_dir=) to a directory of recorded ",
             "fixtures)"),
      source = request$source, warn = FALSE
    ))
  }
  manifest <- .fixture_manifest(dir)
  if (is.null(manifest)) {
    return(.refuse(
      sprintf("offline: no fixture manifest in '%s'", dir),
      source = request$source, warn = FALSE
    ))
  }
  row <- .match_fixture(request, manifest)
  if (is.null(row)) {
    return(.refuse(
      sprintf(paste0("offline: no recorded fixture answers this request ",
                     "(source '%s', point (%g, %g), range %s..%s); offline ",
                     "mode never falls back to the network"),
              request$source, request$lon, request$lat,
              request$start %||% "NA", request$end %||% "NA"),
      source = request$source, warn = FALSE
    ))
  }
  .replay_fixture(request, row, dir)
}

#' Is a series a replayed (offline) fixture?
#'
#' Reports whether a [geo_point_series][new_geo_point_series] was produced by
#' the offline replay path (`collect_point(request, offline = TRUE)`) rather
#' than a live upstream call. A replayed series carries `replayed = TRUE` in its
#' provenance and keeps the recording's `retrieved_at` rather than a fresh
#' timestamp, so a consumer can always tell a cached series from a live one.
#'
#' @param x A `geo_point_series` (or any object).
#' @return Logical scalar; `TRUE` only for a replayed series.
#' @seealso [collect_point()]
#' @export
is_replayed <- function(x) {
  if (!inherits(x, "geo_point_series")) return(FALSE)
  prov <- attr(x, "provenance")
  isTRUE(prov$replayed)
}
