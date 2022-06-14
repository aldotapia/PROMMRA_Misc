library(terra)
library(sf)
library(tidyverse)

ndvi_files <- list.files('~/Documents/1_dtw/scenes/NDVI normalized',
                         full.names = T)

file_name <- gsub(pattern = '.*/',
                  replacement = '',
                  x = ndvi_files)

file_id <- gsub(pattern = '.*ndvi_',
                replacement = '',
                x = ndvi_files)

file_date <- gsub(pattern = '.tif',
                  replacement = '',
                  x = file_id)

polys <- vect('~/Documents/1_dtw/vectors/training_areas/initial_training.shp')

r_stack <- rast(ndvi_files)

names(r_stack) <- paste0('D',
                         gsub(pattern = '-',
                              replacement = '_',
                              x = file_date))

polys_ndvi <- terra::extract(x = r_stack,
                      y = polys,
                      exact = T)

polys$id <- polys$id+1

polys <- as.data.frame(polys)

polys_ndvi %>% left_join(polys,
                         by = c('ID' = 'id')) %>%
  filter(fraction >= 0.75) %>% 
  select(-fraction)-> ndvi_db

ndvi_db %>% 
  group_by(crop, ID) %>%
  summarise(across(everything(), list(median = median))) %>% 
  pivot_longer(cols = starts_with('D20'),
               names_to = 'Date',
               values_to = 'Median NDVI') %>% 
  mutate(Date = as.Date(Date, format = 'D%Y_%m_%d_median'),
         `Median NDVI` = round(`Median NDVI`)) %>% 
  na.omit -> train_dtw

write.csv(train_dtw,'~/Documents/1_dtw/results/train_dtw.csv',row.names = F)

# after checking values
train_dtw %>%
  filter(ID %in% c(78, 124,247,87,193,
                   224,274,344,149,249,
                   239,120, 117,32,42,
                   35,300, 335,281,136,
                   172,185,211,270)) -> train_dtw2

write.csv(train_dtw2,'~/Documents/1_dtw/results/train_dtw2.csv',row.names = F)