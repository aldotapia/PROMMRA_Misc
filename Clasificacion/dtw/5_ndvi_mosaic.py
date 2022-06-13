#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script for downloading Sentinel-2 SR images from GEE

@author: aldotapia
"""

import rioxarray as rioxr
import os
from rioxarray.merge import merge_arrays

mainpath = '/Users/aldotapia/Documents/1_dtw/scenes/NDVI cropped/'
finalpath = '/Users/aldotapia/Documents/1_dtw/scenes/NDVI mosaic/'

files = os.listdir(mainpath)

rasters = [value.split('_')[-1] for value in files if value.endswith('.tif')]

patterns = list(set(rasters))

for pattern in patterns:
    rs_temp = [value for value in files if value.endswith(test)]
    r_single = []
    for r_temp in rs_temp:
        rpath = os.path.join(mainpath, r_temp)
        with rioxr.open_rasterio(rpath) as src:
            r_single.append(src)
    r_mosaic = merge_arrays(r_single)
    fname = os.path.join(finalpath, 'ndvi_' + pattern)
    r_mosaic.rio.to_raster(fname, compress='LZW')
    print(f"{'ndvi_' + pattern} done")