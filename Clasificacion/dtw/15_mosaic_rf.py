import rioxarray as rioxr
import os
from rioxarray.merge import merge_arrays

mainpath = '/Users/aldotapia/Documents/1_dtw/scenes/rf/'
finalpath = '/Users/aldotapia/Documents/1_dtw/scenes/class results/'

files = os.listdir(mainpath)

rasters = [value for value in files if value.endswith('.tif')]

all_rasters = []
for raster in rasters:
    raster_path = os.path.join(mainpath,raster)
    with rioxr.open_rasterio(raster_path) as rx:
        all_rasters.append(rx)

r_mosaic = merge_arrays(all_rasters)

fname = os.path.join(finalpath, 'rf_mosaic.tif')
r_mosaic.rio.to_raster(fname, compress='LZW')