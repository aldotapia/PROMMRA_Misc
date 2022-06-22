library(TSdist)
library(dtw)
library(terra)
library(dplyr)
library(parallel)

samples <- read.csv('~/Documents/1_dtw/results/train_dtw2.csv')

dictionary <- data.frame(crop = unique(samples$crop),
                         class = seq_along(unique(samples$crop)))

samples <- samples %>%
  left_join(dictionary,
            by = c('crop')) %>%
  select(class,
         ID,
         crop,
         Date,
         Median.NDVI) %>% 
  mutate(Date = as.numeric(as.Date(Date)))

samples %>%
  group_by(crop,ID) %>% 
  group_map(~ smooth.spline(x = .x$Date,
                            y = .x$Median.NDVI)) -> spline_funs

samples %>%
  group_by(crop,ID) %>%
  summarise() -> cnames

names(spline_funs) <- cnames$crop

newx <- seq(from = as.numeric(as.Date('2021-05-01')),
            to = as.numeric(as.Date('2022-04-30')),
            by=15)

newx <- round(newx)

lapply(spline_funs, FUN = function(y) predict(y, newx) %>%
         cbind.data.frame() %>% mutate(y = round(y))) -> smoothed_samples

ndvi_files <- list.files('~/Documents/1_dtw/scenes/NDVI cropped fixed/',
                      pattern = '.tif$',
                      full.names = T)

file_name <- gsub(pattern = '.*/',
                  replacement = '',
                  x = ndvi_files)

ids <- substr(file_name,1,3)

id <- unique(ids)

file_date <- substr(file_name,
                    10,
                    19)

file_date <- as.Date(file_date,
                     format = '%Y-%m-%d')

dtw_irregular <- function(x, rasterdates, samplelist){
  
  vals <- rep(0, times = length(samplelist))
  
  try({
    result = lapply(samplelist,
                    FUN= function(z) TSdist::TSDistances(x = x,
                                                         y = z$y,
                                                         tx = rasterdates,
                                                         ty = z$x,
                                                         distance = 'dtw',
                                                         step.pattern = dtw::asymmetric,
                                                         window.type = 'none',
                                                         open.end=T,
                                                         open.begin=T,
                                                         distance.only = T))
    vals <- unlist(result)
    
  })
  
  vals
}


for(i in seq_along(id)){
  ix <- ids == id[i]
  r_files <- ndvi_files[ix]
  r_dates <- file_date[ix]
  
  fnm <-  paste0('~/Documents/1_dtw/scenes/dtw/',id[i],'.tif')
  
  r_stack <- rast(r_files)

  cl <- makeCluster(12, type = 'PSOCK')
  clusterExport(cl, "r_dates")
  clusterExport(cl, "smoothed_samples")
  s3b <- system.time({
    r_final <- app(x = r_stack,
                   fun = dtw_irregular,
                   rasterdates = r_dates,
                   samplelist = smoothed_samples,
                   cores = cl)
  })
  stopCluster(cl)
  
  print(s3b)
  
  names(r_final) <- paste0('lyr',1:24)
  
  writeRaster(r_final,
              fnm,
              gdal=c("COMPRESS=LZW"),
              overwrite = TRUE)
  
  tmpFiles(remove = T)
  print(paste0('Zone ', i, ' done!'))
}