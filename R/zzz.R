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
                  extent = au_bbox)
  invisible()
}
