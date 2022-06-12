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

def get_scl(image):
    date_ = image.date().format('y-D')
    scl = (image
            .select('SCL')
            .toUint8())
    scl = scl.set('yearDOY', date_)
    return scl

scl = collection.map(get_scl)

dates = ee.List(scl.aggregate_array('yearDOY')).distinct()

def by_date(lst):
    scl_temp = scl.filterMetadata('yearDOY','equals',lst)
    temp_name = scl_temp.first().get('yearDOY')
    scl_temp = scl_temp.mosaic().unmask(0)
    return scl_temp.set('system:index', ee.String('scl_').cat(temp_name))
    

scl_mosaic = ee.ImageCollection(dates.map(by_date))

test = batch.Export.imagecollection.toDrive(
            collection=scl_mosaic,
            folder='SCL Limari',
            region=limari,
            scale=20,
            dataType='int',
            crs= 'EPSG:32719',
            maxPixels=10000000000000
        )