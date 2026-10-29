# List registered data sources

List registered data sources

## Usage

``` r
list_sources()
```

## Value

A `data.table` with one row per registered source.

## Examples

``` r
list_sources()
#>            id     package   free  batch
#>        <char>      <char> <lgcl> <lgcl>
#>  1:    abares read.abares   TRUE  FALSE
#>  2:    chirps      chirps   TRUE   TRUE
#>  3: elevation     geodata   TRUE   TRUE
#>  4:     isric      apsimx   TRUE  FALSE
#>  5:     modis  MODISTools   TRUE  FALSE
#>  6: nasapower   nasapower   TRUE  FALSE
#>  7:      nert        nert   TRUE   TRUE
#>  8:    ocular      ocular   TRUE  FALSE
#>  9:      silo   weatherOz   TRUE  FALSE
#> 10: soilgrids     geodata   TRUE   TRUE
#> 11:      stac         rsi   TRUE  FALSE
#> 12: worldclim     geodata   TRUE   TRUE
#>                                                                                                                                            description
#>                                                                                                                                                 <char>
#>  1:                                                                                               Australian Gridded Farm Data (ABARES); point extract
#>  2:                                                                                       CHIRPS 2.0 daily rainfall, 0.05 degree, 50 S to 50 N, no key
#>  3:                                                                               Elevation and slope from CGIAR-CSI SRTM 90 m; non-commercial licence
#>  4: ISRIC SoilGrids point profile (global, no key): texture, carbon, pH, bulk density, CEC, nitrogen and the water limits LL15/DUL/SAT, by depth layer
#>  5:                                                                                                     MODIS NDVI/EVI 16-day (ORNL DAAC); point pixel
#>  6:                                                                                           Global daily climate + solar (NASA POWER); point, no key
#>  7:                      TERN soil / soil-moisture (SMIPS) / AET / canopy / phenology (Australia) point extract via nert (AAGI-AUS); free TERN API key
#>  8:     Sentinel-2 / Landsat spectral-index series over a 500 m window (Microsoft Planetary Computer STAC) via ocular (AAGI-AUS); cloud-masked, no key
#>  9:                                                                                             SILO 5 km grid (Australia) point drill; free email key
#> 10:                                                  SoilGrids 2.0 means at 30 arc-seconds, 0-60 cm in four depths; read from the cloud raster, no key
#> 11:                                                                                                      Sentinel-2 NDVI via Planetary Computer; point
#> 12:                                            WorldClim 2.1 bioclimatic variables bio_1 to bio_19 (1970-2000), 30 arc-seconds; non-commercial licence
```
