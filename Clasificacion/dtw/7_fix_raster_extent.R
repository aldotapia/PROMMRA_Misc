library(sf)
library(terra)

zones <- read_sf('~/Documents/1_dtw/vectors/zones.shp')

ndvi_files <- list.files('~/Documents/1_dtw/scenes/NDVI mosaic/',
                         full.names = T)

file_name <- gsub(pattern = '.*/',
                  replacement = '',
                  x = ndvi_files)

for(i in seq_along(ndvi_files)){
  r <- rast(ndvi_files[i])
  r <- extend(r, zones)
  
  writeRaster(r,
              paste0('~/Documents/1_dtw/scenes/NDVI normalized/',
                     file_name[i]),
              gdal=c("COMPRESS=LZW"),
              overwrite = TRUE)
  
  print(paste0('Scene ',
               ndvi_files[i],
               ' done'))
}