# Gridded sources through geodata and chirps; one raster read serves a batch.

# Where geodata keeps its downloads between sessions.
.terroir_cache_dir <- function() {
  getOption("terroir.cache_dir", tools::R_user_dir("terroir", which = "cache"))
}

# Point coordinates of a list of requests, as a two-column matrix.
.request_xy <- function(requests) {
  cbind(
    vapply(requests, function(r) r$lon, numeric(1L)),
    vapply(requests, function(r) r$lat, numeric(1L))
  )
}

# One static (dateless) series per request from a table of extracted values,
# one column per variable, one row per request.
.static_series <- function(values, units, requests, source, source_version,
                           license, retrieved_at, call) {
  out <- vector("list", length(requests))
  for (i1 in seq_along(requests)) {
    req <- requests[[i1]]
    long <- data.table::data.table(
      date = as.Date(NA),
      variable = names(values),
      value = as.numeric(unlist(values[i1, ], use.names = FALSE)),
      unit = unname(units[names(values)])
    )
    long <- long[is.finite(long$value), ]
    if (nrow(long) == 0L) {
      out[[i1]] <- .refuse(
        sprintf("%s has no value at (%g, %g)", source, req$lon, req$lat),
        source, warn = FALSE
      )
      next
    }
    out[[i1]] <- new_geo_point_series(
      long, lon = req$lon, lat = req$lat, source = source,
      source_version = source_version, license = license,
      retrieved_at = retrieved_at, call = call
    )
  } # ends i1, over requests
  out
}

# Every request in a batch refused with the same reason.
.refuse_all <- function(requests, reason, source) {
  lapply(requests, function(r) .refuse(reason, source, warn = FALSE))
}

# WorldClim 2.1 bioclimatic variables -----------------------------------------

# Units from WorldClim's definitions: temperature in degrees C, precipitation in
# mm; BIO3 and BIO15 are percentages and BIO4 is a standard deviation x 100.
.WORLDCLIM_UNITS <- c(
  bio_1 = "degC", bio_2 = "degC", bio_3 = "percent", bio_4 = "degC x 100",
  bio_5 = "degC", bio_6 = "degC", bio_7 = "degC", bio_8 = "degC",
  bio_9 = "degC", bio_10 = "degC", bio_11 = "degC", bio_12 = "mm",
  bio_13 = "mm", bio_14 = "mm", bio_15 = "percent", bio_16 = "mm",
  bio_17 = "mm", bio_18 = "mm", bio_19 = "mm"
)

.batch_worldclim <- function(requests, retrieved_at) {
  want <- requests[[1L]]$variables %||% names(.WORLDCLIM_UNITS)
  unknown <- setdiff(want, names(.WORLDCLIM_UNITS))
  if (length(unknown) > 0L) {
    return(.refuse_all(
      requests,
      sprintf("worldclim serves bio_1 to bio_19, not %s",
              paste(unknown, collapse = ", ")),
      "worldclim"
    ))
  }
  xy <- .request_xy(requests)

  # Read one 30-degree tile per group of points ------------------------------
  tile_vec <- paste(floor(xy[, 1] / 30), floor(xy[, 2] / 30))
  values <- data.table::data.table(row = seq_len(nrow(xy)))
  for (tile_local in unique(tile_vec)) {
    jj <- which(tile_vec == tile_local)
    ras <- tryCatch(
      geodata::worldclim_tile(
        var = "bio", lon = xy[jj[1L], 1], lat = xy[jj[1L], 2],
        path = .terroir_cache_dir()
      ),
      error = function(e) e
    )
    if (inherits(ras, "error") || is.null(ras)) {
      return(.refuse_all(
        requests, "geodata::worldclim_tile() returned no raster", "worldclim"
      ))
    }
    if (terra::nlyr(ras) != 19L) {
      return(.refuse_all(
        requests,
        sprintf("WorldClim bio tile has %d layers, not 19", terra::nlyr(ras)),
        "worldclim"
      ))
    }
    names(ras) <- names(.WORLDCLIM_UNITS)
    v <- terra::extract(ras[[want]], xy[jj, , drop = FALSE])
    for (col in want) values[jj, (col) := v[[col]]]
  } # ends tile_local, over the WorldClim tiles
  values[, row := NULL]

  .static_series(
    values, .WORLDCLIM_UNITS, requests, source = "worldclim",
    source_version = paste0("WorldClim 2.1 via geodata ",
                            utils::packageVersion("geodata")),
    license = paste("WorldClim 2.1: free for academic and non-commercial use;",
                    "no redistribution or commercial use without permission"),
    retrieved_at = retrieved_at,
    call = "geodata::worldclim_tile(var = 'bio') |> terra::extract(points)"
  )
}

.adapter_worldclim <- function(request, retrieved_at) {
  .batch_worldclim(list(request), retrieved_at)[[1L]]
}

# Elevation and slope from SRTM 90 m ------------------------------------------

.ELEVATION_UNITS <- c(elevation = "m", slope = "degree")

.batch_elevation <- function(requests, retrieved_at) {
  xy <- .request_xy(requests)
  if (any(abs(xy[, 2]) > 60)) {
    return(.refuse_all(
      requests, "SRTM covers 60 S to 60 N only", "elevation"
    ))
  }

  # Read one 5-degree SRTM tile per group of points --------------------------
  tile_vec <- paste(floor(xy[, 1] / 5), floor(xy[, 2] / 5))
  values <- data.table::data.table(
    elevation = rep(NA_real_, nrow(xy)), slope = rep(NA_real_, nrow(xy))
  )
  for (tile_local in unique(tile_vec)) {
    jj <- which(tile_vec == tile_local)
    ras <- tryCatch(
      geodata::elevation_3s(
        lon = xy[jj[1L], 1], lat = xy[jj[1L], 2], path = .terroir_cache_dir()
      ),
      error = function(e) e
    )
    # an ocean-only tile does not exist upstream; its points stay NA
    if (inherits(ras, "error") || is.null(ras)) next
    # named apart from the slope column, which a data.table j would read first
    ras_slope <- terra::terrain(ras, v = "slope", unit = "degrees")
    pts <- xy[jj, , drop = FALSE]
    elevation_vec <- terra::extract(ras, pts)[[1L]]
    slope_vec <- terra::extract(ras_slope, pts)[[1L]]
    values[jj, elevation := elevation_vec]
    values[jj, slope := slope_vec]
  } # ends tile_local, over the SRTM tiles

  .static_series(
    values, .ELEVATION_UNITS, requests, source = "elevation",
    source_version = paste0("CGIAR-CSI SRTM 90 m v4.1 via geodata ",
                            utils::packageVersion("geodata")),
    license = paste("CGIAR-CSI SRTM: free for non-commercial use with",
                    "attribution to CIAT; no resale or redistribution"),
    retrieved_at = retrieved_at,
    call = "geodata::elevation_3s() |> terra::terrain('slope') |> terra::extract(points)"
  )
}

.adapter_elevation <- function(request, retrieved_at) {
  .batch_elevation(list(request), retrieved_at)[[1L]]
}

# SoilGrids 2.0 aggregated to 30 arc-seconds -----------------------------------

# geodata variable name, the name terroir writes, and the unit geodata states.
.SOILGRIDS_VARS <- data.table::data.table(
  var = c("bdod", "cfvo", "clay", "nitrogen", "ocd", "phh2o", "sand", "silt",
          "soc"),
  name = c("bd", "cfvo", "clay", "nitrogen", "ocd", "ph_h2o", "sand", "silt",
           "soc"),
  unit = c("kg/dm3", "%", "%", "g/kg", "kg/m3", "pH", "%", "%", "g/kg")
)

# The four depths geodata serves at 30 arc-seconds (upper bound, cm).
.SOILGRIDS_DEPTHS <- c("0_5cm" = 5, "5_15cm" = 15, "15_30cm" = 30,
                       "30_60cm" = 60)

.batch_soilgrids <- function(requests, retrieved_at) {
  want <- requests[[1L]]$variables %||% .SOILGRIDS_VARS$name
  unknown <- setdiff(want, .SOILGRIDS_VARS$name)
  if (length(unknown) > 0L) {
    return(.refuse_all(
      requests,
      sprintf("soilgrids serves %s, not %s",
              paste(.SOILGRIDS_VARS$name, collapse = ", "),
              paste(unknown, collapse = ", ")),
      "soilgrids"
    ))
  }
  xy <- .request_xy(requests)
  box <- terra::ext(
    floor(min(xy[, 1])) - 1, ceiling(max(xy[, 1])) + 1,
    floor(min(xy[, 2])) - 1, ceiling(max(xy[, 2])) + 1
  )

  # Crop each variable and depth to the points' extent, then extract ---------
  vars <- .SOILGRIDS_VARS[.SOILGRIDS_VARS$name %in% want, ]
  values <- data.table::data.table(row = seq_len(nrow(xy)))
  units <- character()
  for (i1 in seq_len(nrow(vars))) {
    for (i2 in seq_along(.SOILGRIDS_DEPTHS)) {
      col <- paste0(vars$name[i1], "_", names(.SOILGRIDS_DEPTHS)[i2])
      ras <- tryCatch(
        geodata::soil_world(
          var = vars$var[i1], depth = .SOILGRIDS_DEPTHS[[i2]], stat = "mean",
          path = .terroir_cache_dir(), vsi = TRUE
        ),
        error = function(e) e
      )
      if (inherits(ras, "error") || is.null(ras)) {
        return(.refuse_all(
          requests,
          sprintf("geodata::soil_world() failed for %s", col),
          "soilgrids"
        ))
      }
      ras <- terra::crop(ras, box)
      values[, (col) := terra::extract(ras, xy)[[1L]]]
      units[col] <- vars$unit[i1]
    } # ends i2, over depths
  } # ends i1, over variables
  values[, row := NULL]

  .static_series(
    values, units, requests, source = "soilgrids",
    source_version = paste0("SoilGrids 2.0 at 30 arc-seconds via geodata ",
                            utils::packageVersion("geodata")),
    license = "ISRIC SoilGrids (CC BY 4.0)",
    retrieved_at = retrieved_at,
    call = "geodata::soil_world(stat = 'mean', vsi = TRUE) |> terra::crop() |> terra::extract(points)"
  )
}

.adapter_soilgrids <- function(request, retrieved_at) {
  .batch_soilgrids(list(request), retrieved_at)[[1L]]
}

# CHIRPS daily rainfall ---------------------------------------------------------

.batch_chirps <- function(requests, retrieved_at) {
  starts <- vapply(requests, function(r) as.character(r$start %||% NA), character(1L))
  ends <- vapply(requests, function(r) as.character(r$end %||% NA), character(1L))
  if (anyNA(starts) || anyNA(ends)) {
    return(.refuse_all(requests, "chirps needs start and end dates", "chirps"))
  }
  xy <- .request_xy(requests)
  pts <- unique(data.frame(lon = xy[, 1], lat = xy[, 2]))
  first <- min(as.Date(starts))
  last <- max(as.Date(ends))

  # One call per calendar year keeps each upstream answer small -------------
  year_vec <- seq(as.integer(format(first, "%Y")), as.integer(format(last, "%Y")))
  pieces <- vector("list", length(year_vec))
  for (i1 in seq_along(year_vec)) {
    from <- max(first, as.Date(paste0(year_vec[i1], "-01-01")))
    to <- min(last, as.Date(paste0(year_vec[i1], "-12-31")))
    got <- tryCatch(
      chirps::get_chirps(pts, dates = as.character(c(from, to)), server = "CHC"),
      error = function(e) e
    )
    if (inherits(got, "error")) {
      return(.refuse_all(
        requests,
        paste("chirps::get_chirps() failed:", conditionMessage(got)),
        "chirps"
      ))
    }
    pieces[[i1]] <- data.table::as.data.table(got)
  } # ends i1, over years
  rain <- data.table::rbindlist(pieces)
  rain[, date := as.Date(date)]

  # Split the shared answer back into one series per request -----------------
  out <- vector("list", length(requests))
  for (i1 in seq_along(requests)) {
    req <- requests[[i1]]
    jj <- rain$lon == req$lon & rain$lat == req$lat &
      rain$date >= as.Date(req$start) & rain$date <= as.Date(req$end)
    long <- rain[jj, list(date, variable = "chirps_rain", value = chirps,
                          unit = "mm")]
    long <- long[is.finite(long$value) & long$value >= 0, ]
    if (nrow(long) == 0L) {
      out[[i1]] <- .refuse(
        sprintf("chirps has no value at (%g, %g)", req$lon, req$lat),
        "chirps", warn = FALSE
      )
      next
    }
    out[[i1]] <- new_geo_point_series(
      long, lon = req$lon, lat = req$lat, source = "chirps",
      source_version = paste0("CHIRPS 2.0 via chirps ",
                              utils::packageVersion("chirps")),
      license = "CHIRPS: public domain (copyright waived)",
      retrieved_at = retrieved_at,
      call = sprintf("chirps::get_chirps(server = 'CHC', dates = c('%s', '%s'))",
                     req$start, req$end)
    )
  } # ends i1, over requests
  out
}

.adapter_chirps <- function(request, retrieved_at) {
  .batch_chirps(list(request), retrieved_at)[[1L]]
}
