.onLoad <- function(libname, pkgname) {
  register_source("nasapower", .adapter_nasapower, "nasapower", TRUE,
                  "Global daily climate + solar (NASA POWER); point, no key")
  register_source("silo", .adapter_silo, "weatherOz", TRUE,
                  "SILO 5 km grid (Australia) point drill; free email key")
  register_source("abares", .adapter_abares, "read.abares", TRUE,
                  "Australian Gridded Farm Data (ABARES); point extract")
  register_source("modis", .adapter_modis, "MODISTools", TRUE,
                  "MODIS NDVI/EVI 16-day (ORNL DAAC); point pixel")
  register_source("stac", .adapter_rsi, "rsi", TRUE,
                  "Sentinel-2 NDVI via Planetary Computer; point")
  invisible()
}
