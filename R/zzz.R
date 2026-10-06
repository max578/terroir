.onLoad <- function(libname, pkgname) {
  # Australia mainland + Tasmania bounding box (WGS84), generous margin. Used to
  # refuse an Australia-only source queried outside its coverage (IOP / FX-6).
  au_bbox <- c(112, -44, 154, -10)
  register_source("nasapower", .adapter_nasapower, "nasapower", TRUE,
                  "Global daily climate + solar (NASA POWER); point, no key")
  register_source("silo", .adapter_silo, "weatherOz", TRUE,
                  "SILO 5 km grid (Australia) point drill; free email key",
                  extent = au_bbox)
  register_source("abares", .adapter_abares, "read.abares", TRUE,
                  "Australian Gridded Farm Data (ABARES); point extract",
                  extent = au_bbox)
  register_source("modis", .adapter_modis, "MODISTools", TRUE,
                  "MODIS NDVI/EVI 16-day (ORNL DAAC); point pixel")
  register_source("stac", .adapter_rsi, "rsi", TRUE,
                  "Sentinel-2 NDVI via Planetary Computer; point")
  register_source("nert", .adapter_nert, "nert", TRUE,
                  paste("TERN soil / soil-moisture (SMIPS) / AET / canopy /",
                        "phenology (Australia) point extract via nert (AAGI-AUS);",
                        "free TERN API key"),
                  extent = au_bbox, batch = .batch_nert)
  # Global and keyless, so it complements nert's Australia-only keyed TERN soil
  # rather than duplicating it. No extent: SoilGrids is defined worldwide.
  register_source("isric", .adapter_isric, "apsimx", TRUE,
                  paste("ISRIC SoilGrids point profile (global, no key):",
                        "texture, carbon, pH, bulk density, CEC, nitrogen and",
                        "the water limits LL15/DUL/SAT, by depth layer"))
  # ocular retrieves global Sentinel-2 / Landsat imagery, but its bounding box
  # is built in UTM, so it is defined only on the UTM latitude band -- refuse a
  # polar point here rather than let the upstream abort (IOP / FX-6).
  register_source("ocular", .adapter_ocular, "ocular", TRUE,
                  paste("Sentinel-2 / Landsat spectral-index series over a",
                        "500 m window (Microsoft Planetary Computer STAC) via",
                        "ocular (AAGI-AUS); cloud-masked, no key"),
                  extent = c(-180, -80, 180, 84))
  register_source("worldclim", .adapter_worldclim, "geodata", TRUE,
                  paste("WorldClim 2.1 bioclimatic variables bio_1 to bio_19",
                        "(1970-2000), 30 arc-seconds; non-commercial licence"),
                  batch = .batch_worldclim)
  register_source("elevation", .adapter_elevation, "geodata", TRUE,
                  paste("Elevation and slope from CGIAR-CSI SRTM 90 m;",
                        "non-commercial licence"),
                  extent = c(-180, -60, 180, 60), batch = .batch_elevation)
  register_source("soilgrids", .adapter_soilgrids, "geodata", TRUE,
                  paste("SoilGrids 2.0 means at 30 arc-seconds, 0-60 cm in",
                        "four depths; read from the cloud raster, no key"),
                  extent = c(-180, -60, 180, 90), batch = .batch_soilgrids)
  register_source("chirps", .adapter_chirps, "chirps", TRUE,
                  "CHIRPS 2.0 daily rainfall, 0.05 degree, 50 S to 50 N, no key",
                  extent = c(-180, -50, 180, 50), batch = .batch_chirps)
  invisible()
}
