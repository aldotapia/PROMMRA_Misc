library(httr)
library(tidyverse)
library(purrr)
library(lubridate)
library(lattice)
library(hyfo)
library(sp)
library(automap)
library(terra)

stations <- GET('http://www.ceazamet.cl/ws/pop_ws.php?fn=GetListaEstaciones&p_cod=ceazamet')
stations <- strsplit(content(stations,
                             'parsed'),
                     split = "\n",
                     fixed=T,
                     useBytes = T)
station_names <- unlist(strsplit(stations[[1]][5],
                                 split = ",",
                                 fixed=T,
                                 useBytes = T))
stations <- do.call(rbind.data.frame,
                    strsplit(unlist(stations)[6:length(stations[[1]])],
                             split = ",",
                             fixed=T,
                             useBytes = T))

names(stations) <- station_names

stations <- stations[stations$e_cod_provincia %in% c("041",
                                                     "042",
                                                     "043"),]

data_list <- list()

for(i in 1:dim(stations)[1]){
  print(paste0('Starting ',
               stations$e_nombre[i]))
  temp <- GET(paste0('http://www.ceazamet.cl/ws/pop_ws.php?fn=GetListaSensores&p_cod=ceazamet&e_cod=',
                     stations$e_cod[i],
                     '&user=anon@host.com'))
  temp2 <- strsplit(content(temp,
                            'parsed'),
                    split = "\n",
                    fixed=T,
                    useBytes = T)
  temp_names <- unlist(strsplit(temp2[[1]][5],
                                split = ",",
                                fixed=T,
                                useBytes = T))
  temp3 <- do.call(rbind.data.frame,
                   strsplit(unlist(temp2)[6:length(temp2[[1]])],
                            split = ",",
                            fixed = T,
                            useBytes = T))
  names(temp3) <- temp_names
  
  if('Precipitación' %in% temp3$tf_nombre){
    idx <- which(temp3$tf_nombre == 'Precipitación')
    idx2 <- temp3$s_cod[idx]

    site <- "http://www.ceazamet.cl/ws/pop_ws.php?fn=GetSerieSensor&p_cod=ceazamet&s_cod="
    url <- GET(paste0(site,
                      idx2,
                      "&fecha_inicio=",
                      "2021-05-01",
                      "&fecha_fin=",
                      "2022-04-30",
                      "&user=anon@host.com",
                      "&interv=dia",
                      '&tipo_resp=json'))
    url2 <- content(url,
                    as = "parsed",
                    type = "application/json",
                    encoding = 'UTF-8')
    url2[[11]] %>%
      map_df(function(x) x %>%
               modify_if(is.null,is.numeric) %>%
               as_tibble()) -> register
    data_list[[i]] <- register
    
    remove(temp,temp2,temp3)
  }
}

dates <- data_list[[i]][,1]

tables <- list()

for(i in seq_along(data_list)){
  if(is.data.frame(data_list[[i]])){
    temp <-  data_list[[i]]
    temp$prom <- as.numeric(temp$prom)
    temp[temp$data_pc <100,'prom'] <- NA
    temp <- temp[,'prom']
    names(temp) <- stations$e_nombre[i]
    tables[[i]] <- temp
  }
}

df <- data.frame(dates,
                 do.call(cbind.data.frame,
                         tables[as.logical(lengths(tables))]))

df %>% summarise(across(everything(),
                        ~ sum(!is.na(.x)))) -> non_na

df_final <- df[,non_na >= 300]

df_filled <- fillGap(df_final,
                     corPeriod = 'daily')

st_names_b <- gsub(pattern = '.',
                   replacement = '',
                   x = names(df_filled),
                   fixed = T)

st_names_a <- gsub(pattern = '[',
                   replacement = '',
                   x = stations$e_nombre,
                   fixed = T)

st_names_a <- gsub(pattern = ']',
                   replacement = '',
                   x = st_names_a,
                   fixed = T)

st_names_a <- gsub(pattern = ' ',
                   replacement = '',
                   x = st_names_a,
                   fixed = T)

st_names_a <- gsub(pattern = '.',
                   replacement = '',
                   x = st_names_a,
                   fixed = T)

stations_meta <- stations[st_names_a %in% st_names_b,]

stations_meta %>%
  mutate(x = as.numeric(`#e_lat`),
         y = as.numeric(e_lon),
         z = NA) %>% 
  select(x,y,z)-> stations_sp

stations_sp <- SpatialPointsDataFrame(coords = stations_sp[,2:1],
                                      data = stations_sp)

raster_template <- rast('~/Documents/1_dtw/scenes/Spline mosaic/spline_mosaic.tif',
                        lyrs = 1)

raster_template <- terra::aggregate(raster_template,
                                    fact = 300)

raster_template <- setValues(raster_template,
                             values = 0)

grid_r <- as(raster::raster(raster_template),
             'SpatialGridDataFrame')

proj4string(stations_sp) <- '+proj=longlat +datum=WGS84 +no_defs '

stations_sp <- spTransform(stations_sp,
                           proj4string(grid_r))

for(i in 1:dim(df_filled)[1]){
  if(sum(df_filled[i,-1] >= 1) >= 3){
    v <- stations_sp
    
    v$z <- as.vector(unlist(df_filled[i,-1]))
    
    kg <- autoKrige(z~1,
                    v,
                    grid_r)
    
    r <- rast(kg$krige_output)
    r <- r[[1]]
    r[] <- round(r[],
                 1)
    r[r < 0] <- 0
    
    writeRaster(x = r,
                filename = paste0('~/Documents/1_dtw/scenes/pp/pp',
                                  df_filled[i,1],
                                  '.tif'),
                gdal=c("COMPRESS=LZW"),
                overwrite = TRUE)
  }
}