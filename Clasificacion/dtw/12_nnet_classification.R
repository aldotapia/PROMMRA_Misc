library(terra)
library(tidyverse)
library(caret)
library(RColorBrewer)
library(caret)
library(NeuralNetTools)

set.seed(123)

s_mosaic <- rast('~/Documents/1_dtw/scenes/Spline mosaic/spline_mosaic.tif')

v <- vect('~/Documents/1_dtw/vectors/training_areas/initial_training.shp')

v$id <- v$id + 1

df_samples <- terra::extract(x = s_mosaic,
                             y = v,
                             weights = T)

v <- as.data.frame(v)

dictionary <- data.frame(crop = unique(v$crop[order(v$crop)]),
                         class = seq_along(unique(v$crop)))

v %>%
  sample_frac(0.70) -> train

v %>% 
  .[-train$id,] -> test

df_samples %>% 
  .[df_samples$ID %in% train$id[order(train$id)],] %>%
  left_join(v,
            by = c('ID' = 'id')) %>%
  left_join(dictionary,
            by = 'crop') %>% 
  filter(weight >= 0.75) %>% 
  select(-weight,
         -ID,
         -crop) %>% 
  select(class,
         starts_with('lyr')) %>% 
  mutate(class = as.factor(class)) -> for_training

df_samples %>% 
  .[df_samples$ID %in% test$id[order(test$id)],] %>%
  left_join(v,
            by = c('ID' = 'id')) %>%
  left_join(dictionary,
            by = 'crop') %>% 
  filter(weight >= 0.75) %>% 
  select(-weight,
         -ID,
         -crop) %>% 
  select(class,
         starts_with('lyr')) %>% 
  mutate(class = as.factor(class)) -> for_testing

names(for_training) <- c('class',
                         tolower(month.abb[c(5:12,
                                             1:4)]),
                         'pencrit')

names(for_testing) <- c('class',
                        tolower(month.abb[c(5:12,
                                            1:4)]),
                        'pencrit')

for_training %>%
  group_by(class) %>% 
  summarise(total = n()) %>%
  ungroup() %>% 
  summarise(sample_size = min(total)) %>% 
  unlist() -> sample_size
  
for_training %>%
  group_by(class) %>% 
  sample_n(sample_size) %>% 
  ungroup() -> for_training

tunegrid <- expand.grid(.decay = c(0.5,
                                   0.1,
                                   1e-2,
                                   1e-3),
                        .size = c(5,
                                  10,
                                  15,
                                  20))

control <- trainControl(method = "repeatedcv",
                        number = 10,
                        repeats = 3,
                        search = "grid",
                        allowParallel = TRUE)

model <- train(class~.,
               data = for_training,
               method = "nnet",
               metric = "Kappa",
               tuneGrid = tunegrid,
               trControl = control,
               preProcess = c('center',
                              'scale'),
               verbose = FALSE,
               trace = FALSE)

plot(model)

plotnet(model$finalModel,
        y_names = dictionary$crop,
        x_names = c(paste0(tolower(month.abb[c(5:12,
                                               1:4)]),
                           ', ',
                           rep(c(2021,
                                 2022),
                               times = c(8,
                                         4))),
                    'pencrit'),
        pos_col = "dodgerblue",
        neg_col = "firebrick")


model_testing_raw <- predict(model,
                             newdata = for_testing[,-1],
                             'raw')
model_testing_prob <- predict(model,
                              newdata = for_testing[,-1],
                              'prob')
model_testing_max <- apply(model_testing_prob,
                           MARGIN = 1,
                           FUN = function(x) max(x, na.rm = T))

model_sum <- data.frame(observed = for_testing[,1],
                        modeled = model_testing_raw,
                        probability = model_testing_max)

model_sum %>%
  group_by(observed,
           modeled) %>% 
  summarise(total = n(),
            mean_prob = round(mean(probability),
                              2)) %>% 
  ungroup() %>% 
  group_by(observed) %>% 
  mutate(frac = round(total/sum(total),3)) %>% 
  ungroup() %>% 
  mutate(observed = as.numeric(observed),
         modeled = as.numeric(modeled)) -> model_sum

write.csv(x = model_sum,
          file = '~/Documents/1_dtw/results/nnet_sum.csv',
          row.names = F)

cols <- colorRampPalette(brewer.pal(11, "Spectral"))(11)

levelplot(mean_prob ~ observed * modeled,
          data = model_sum,
          ylim = c(13,
                   0),
          col.regions = cols,
          at = do.breaks(range(0,
                               1),
                         11),
          scales = list(x = list(at = dictionary$class, 
                                 labels = dictionary$crop,
                                 rot = 90),
                        y = list(at = dictionary$class,
                                 labels = dictionary$crop)))

levelplot(frac ~ observed * modeled,
          data = model_sum,
          ylim = c(13,
                   0),
          col.regions = cols,
          at = do.breaks(range(0,
                               1),
                         11),
          scales = list(x = list(at = dictionary$class, 
                                 labels = dictionary$crop,
                                 rot = 90),
                        y = list(at = dictionary$class,
                                 labels = dictionary$crop)))

spls <- list.files(path = '~/Documents/1_dtw/scenes/Spline/',
                   pattern = '.tif$',
                   full.names = T)

fnames <- gsub(pattern = '.*/',
               replacement = '',
               x = spls)

for(i in seq_along(spls)){
  r_temp <- rast(spls[i])
  
  fname <- paste0('~/Documents/1_dtw/scenes/nnet/nnet_',
                  fnames[i])
  
  names(r_temp) <- c(tolower(month.abb[c(5:12,
                                         1:4)]),
                     'pencrit')
  clss_temp <- predict(model,
                       r_temp,
                       type = 'raw')
  prob_temp <- predict(model,
                       r_temp,
                       type = 'prob')
  prob_max <- apply(prob_temp,
                    MARGIN = 1,
                    FUN = function(x) max(x, na.rm = T))
  r_template <- r_temp[[1]]
  r1 <- setValues(r_template, clss_temp)
  r2 <- setValues(r_template, prob_max)
  r <- c(r1,
         r2)
  names(r) <- c('class',
                'prob')
  writeRaster(x = r,
              filename = fname,
              gdal=c("COMPRESS=LZW"),
              overwrite = TRUE)
  print(paste0('ID ',i,' done'))
}