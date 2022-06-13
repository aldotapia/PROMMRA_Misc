library(terra)

ndvi_files <- list.files('~/Documents/1_dtw/scenes/NDVI cropped/',
                         full.names = T)

ids <- gsub(pattern = '.*/',
            replacement = '',
            x = ndvi_files)

ids <- gsub(pattern = '_.*',
            replacement = '',
            x = ids)

id <- unique(ids)

vlist <- list()
ndvi_list <- list()

for(i in seq_along(id)){
  temp_files <- ndvi_files[ids == id[i]]
  ndvi_list[[i]] <- temp_files
  r <- rast(temp_files)
  vals <- vector(mode = 'integer')
  for(j in 1:dim(r)[3]){
    vals <- append(vals,
                   sum(values(r[[j]])))
  }
  vlist[[i]] <- vals
  print(paste0('ID:',i,' done'))
}

files_deleted <- vector(mode = 'character')

# for checking manually
i <- 1

vals <- vlist[[i]]
fnames <- ndvi_list[[i]]

plot(vals)

{
  files_deleted <- append(files_deleted, fnames[which(vals == min(vals))])
  fnames <- fnames[which(vals != min(vals))]
  vals <- vals[which(vals != min(vals))]
  unlink(fnames[which(vals == min(vals))])
}