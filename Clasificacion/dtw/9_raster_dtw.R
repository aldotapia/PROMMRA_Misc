library(TSdist)
library(terra)
library(purrr)
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
         Date,
         Median.NDVI) %>% 
  mutate(Date = as.numeric(as.Date(Date)))

samples %>%
  group_by(ID) %>% 
  group_map(~ smooth.spline(x = .x$Date,
                            y = .x$Median.NDVI)) -> spline_funs

newx <- seq(from = min(samples$Date), to = max(samples$Date), by=15)

newx <- round(newx)

lapply(spline_funs, FUN = function(y) predict(y, newx) %>%
         cbind.data.frame() %>% mutate(y = round(y))) -> smoothed_samples

samples %>%
  group_by(class,ID) %>%
  summarise() %>%
  ungroup() %>% 
  select(class) %>%
  unlist() %>% 
  as.vector() -> finalclass

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

dtw_irregular <- function(x, rasterdates, samplelist, fclass){
  
  rasterdates <- rasterdates[!is.na(x)]
  
  r_dates <- as.numeric(r_dates)
  
  x <- x[!is.na(x)]
  
  vals <- c(0,0)
  
  lapply(samplelist, FUN= function(z) TSDistances(x = x,
                                    y = z$y,
                                    tx = r_dates,
                                    ty = z$x,
                                    distance = 'dtw',
                                    step.pattern = asymmetric,
                                    window.type = 'itakura',
                                    open.end=T,
                                    open.begin=T,
                                    distance.only = T)) %>% 
    unlist() -> result
  
  vals[1] <- fclass[which.min(result)]
  vals[2] <- round(result[which.min(result)])
  
  vals
}

for(i in seq_along(id)){
  ix <- ids == id[i]
  r_files <- ndvi_files[ix]
  r_dates <- file_date[ix]
  
  fnm <-  paste0('~/Documents/1_dtw/scenes/dtw/',id[i],'.tif')
  
  r_stack <- rast(r_files)

  r_df <- as.data.frame(r_stack)
  
  r_ls <- split(r_df,seq(nrow(r_df)))
  
  s3b <- system.time({
    mn <- mclapply(r_ls, function(x) {
      dtw_irregular(x,r_dates,smoothed_samples,finalclass)
    }, mc.cores = 8)
  })
  
  print(s3b)
  
  result_df <- do.call(rbind.data.frame, mn)
  names(result_df) <- c('class','value')
  
  r_template <- r_stack[[1]]
  
  r_class <- setValues(r_template, result_df$class)
  r_value <- setValues(r_template, result_df$value)
  
  r_final <- c(r_class, r_value)
  
  names(r_final) <- c('class','value')
  
  writeRaster(r_final,
              fnm,
              gdal=c("COMPRESS=LZW"),
              overwrite = TRUE)
  
  tmpFiles(remove = T)
  print(paste0('Zone ', i, ' done!'))
}