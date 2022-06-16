library(terra)

# main function definition
raster_spline_monthly <- function(x,times) {
  
  times <- times[!is.na(x)]
  
  x <- x[!is.na(x)]
  
  if(length(x) <= 4){
    vals <- rep(0, length.out = 12 + 1) # months plus score
  }else{
    sp <- smooth.spline(x = times,
                        y = x,
                        spar = 0.4)
    vals <- predict(sp, seq(from = 18748,
                            to = 19112,
                            by = 5))
    vals <- aggregate(vals$y,
                      list(format(as.Date(seq(from = 18748,
                                              to = 19112,
                                              by = 5),
                                          origin = "1970-01-01"),
                                  "%Y-%m")),
                      mean)[,'x']
    vals[which(vals < 0)] <- -10
    vals <- round(c(vals,
                    sp$pen.crit * 10 / length(x)))
  }
  vals
}


ndvi_files <- list.files('~/Documents/1_dtw/scenes/NDVI cropped fixed/',
                         pattern = '.tif$',
                         full.names = T)

file_name <- gsub(pattern = '.*/',
                  replacement = '',
                  x = ndvi_files)

file_date <- substr(file_name,
                    10,
                    19)

file_date <- as.Date(file_date,
                     format = '%Y-%m-%d')

ndvi_files <- ndvi_files[order(file_date)]

file_name <- file_name[order(file_date)]

file_date <- file_date[order(file_date)]

ids <- substr(file_name,1,3)

id <- unique(ids)

id <- id[order(id)]

for(i in seq_along(id)){
  ix <- ids == id[i]
  r_files <- ndvi_files[ix]
  r_dates <- file_date[ix]
  
  fnm <-  paste0('~/Documents/1_dtw/scenes/Spline/',id[i],'.tif')
  
  r_stack <- rast(r_files)
  
  result_ <- app(r_stack,
                 raster_spline_monthly,
                 times = as.numeric(r_dates),
                 cores = 15)
  
  writeRaster(x = result_,
              filename = fnm,
              datatype = 'INT4S',
              gdal=c("COMPRESS=LZW"),
              overwrite = T)
  
  tmpFiles(remove = T)
  print(paste0('Zone ', i, ' done!'))
}