library(terra)
library(tidyverse)

ndvi_files <- list.files('~/Documents/1_dtw/scenes/NDVI normalized/',
                         full.names = T)

# for ndvi
file_date <- gsub(pattern = '.*ndvi_',
                 replacement = '',
                 x = ndvi_files)

file_date <- gsub(pattern = '.tif',
                  replacement = '',
                  x = file_date)

file_date <- as.Date(file_date,
                     format = '%Y-%m-%d')

pp_files <- list.files('~/Documents/1_dtw/scenes/pp/',
                       full.names = T)

# for pp
pp_date <- gsub(pattern = '.*pp',
                replacement = '',
                x = pp_files)

pp_date <- gsub(pattern = '.tif',
                replacement = '',
                x = pp_date)

pp_date <- as.Date(pp_date,
                    format = '%Y-%m-%d')

# extract
v <- vect('Documents/1_dtw/vectors/training_areas/points_sample.shp')

ndvi <- rast(ndvi_files)
names(ndvi) <- file_date

pp <- rast(pp_files)
names(pp) <- pp_date

ndvi_e <- terra::extract(ndvi,v)

pp_e <- terra::extract(pp,v)

ndvi_e %>%
  pivot_longer(-ID,
               names_to = 'date') %>% 
  na.omit() %>%
  mutate(date = as.Date(date)) -> ndvi_obs

pp_e %>%
  pivot_longer(-ID,
               names_to = 'date') %>% 
  na.omit() %>%
  mutate(date = as.Date(date)) -> pp_obs

for(i in unique(ndvi_e$ID)){
  ndvi_temp <- ndvi_obs[ndvi_obs$ID == i,]
  pp_temp <- pp_obs[pp_obs$ID == i,]
  
  png(filename = paste0('~/Documents/1_dtw/results/points/ps_',
                        i,
                        '.png'),width = 1500,height = 900,res = 200)
  par(mar=c(5, 4, 4, 6) + 0.1)
  print({
    plot(x = ndvi_temp$date,
         y = (ndvi_temp$value-100)/100,
         type = 'o',
         pch = 20,
         ylim = c(0,1),
         xlim = c(as.Date('2021-05-01'),
                  as.Date('2022-04-30')),
         col = 'gold',
         ylab = 'NDVI',
         xlab = NA)
    par(new = TRUE)
    plot(x = pp_temp$date, y = (pp_temp$value), type = 'h',
         xlim = c(as.Date('2021-05-01'),
                  as.Date('2022-04-30')),
         xlab = '', ylab = '',
         ylim = c(60,0),
         axes = F, col = 'dodgerblue',
         lwd = 2)
    axis(4, ylim=c(60,0),at=c(0,10,20),las=1)
    mtext("pp (mm)",side=4,line=3.5)
  })
  dev.off()
 }