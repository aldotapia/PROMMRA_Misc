library(sf)
library(dplyr)

v <- read_sf('Documents/1_dtw/vectors/zones.shp')

files <- list.files('~/Documents/1_dtw/scenes/NDVI cropped fixed/',
                    pattern = '.tif$')

ids <- substr(files,
              1,
              3)

ids %>%
  as_tibble() %>% 
  mutate(ids = as.numeric(value)) %>%
  group_by(ids) %>% 
  summarise(scenes = n()) %>% 
  ungroup() %>% 
  arrange(ids) -> ids

v %>%
  left_join(ids,
            by = c('id' = 'ids')) %>% 
  write_sf('Documents/1_dtw/vectors/zones_with_scenes.shp')