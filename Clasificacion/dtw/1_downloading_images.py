#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script for downloading Sentinel-2 SR images from GEE

@author: aldotapia
"""

import ee, collections, time
from geetools import batch

collections.Callable = collections.abc.Callable # for python 3.10 compatibility issue (maybe for 3.9 as well)

ee.Authenticate()

ee.Initialize()

sentinel = ee.ImageCollection("COPERNICUS/S2_SR")

limari = ee.Geometry.Polygon(
    [[[-71.7049, -30.2619],
      [-71.7049, -31.3236],
      [-70.2657, -31.3236],
      [-70.2657, -30.2619]]]);

SrtDate = '2021-04-01'
EndDate = '2022-06-01'

collection = (sentinel
              .filterBounds(limari)
              .filterDate(SrtDate,EndDate)
              .filterMetadata('SENSING_ORBIT_NUMBER','equals', 96))

def NDVI_normalize(image):
    date_ = image.date().format('y-D')
    ndvi = (image
            .normalizedDifference(['B8', 'B4'])
            .rename('NDVI')
            .expression('b("NDVI") * 100 + 100')
            .rename('NDVI')
            .toUint8())
    ndvi = ndvi.set('yearDOY', date_)
    return ndvi

ndvi = collection.map(NDVI_normalize)

dates = ee.List(ndvi.aggregate_array('yearDOY')).distinct()

def by_date(lst):
    ndvi_temp = ndvi.filterMetadata('yearDOY','equals',lst)
    temp_name = ndvi_temp.first().get('yearDOY')
    ndvi_temp = ndvi_temp.mosaic().unmask(0)
    return ndvi_temp.set('system:index', ee.String('ndvi_').cat(temp_name))
    
ndvi_mosaic = ee.ImageCollection(dates.map(by_date))

test = batch.Export.imagecollection.toDrive(
            collection=ndvi_mosaic,
            folder='NDVI Limari',
            region=limari,
            scale=10,
            dataType='int',
            crs= 'EPSG:32719',
            maxPixels=10000000000000
        )