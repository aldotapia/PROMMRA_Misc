# value comparision from
# 2022-01-23 and
# 2022-01-28

pre <- c(108,
         177,
         167,
         113,
         171,
         157,
         143,
         188,
         192,
         192,
         190,
         161,
         116,
         127,
         188,
         144,
         106,
         122,
         193)

post <- c(106,
          146,
          144,
          108,
          140,
          139,
          124,
          156,
          158,
          164,
          161,
          139,
          110,
          119,
          159,
          125,
          105,
          114,
          166)

modl <- lm(post~pre)
cfs <- coefficients(modl)

plot(pre,post, ylim= c(100,200), xlim = c(100,200))
abline(a = cfs[1], b = cfs[2])

# overcomputation task (yeah, I know and I wanna do it easily, not efficient)

library(terra)

aim_path = '~/Documents/1_dtw/scenes/NDVI cropped fixed/'

ndvi_files <- list.files('~/Documents/1_dtw/scenes/NDVI cropped',
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

file_date <- as.Date(file_date,
                     format = '%Y-%m-%d')

# for adjunting raster
modl <- lm(pre~post)
cfs <- coefficients(modl)

for(i in seq_along(ndvi_files)){
  if(file_date[i] >= '2022-01-25'){
    r <- rast(ndvi_files[i])
    r <- r * cfs[2] + cfs[1]
    r[r > 200] <- 200
    r <- round(r)
    writeRaster(r,
                paste0(aim_path,
                       file_name[i]),
                gdal=c("COMPRESS=LZW"))
  }else{
    writeRaster(rast(ndvi_files[i]),
                paste0(aim_path,
                       file_name[i]),
                gdal=c("COMPRESS=LZW"))
  }
}