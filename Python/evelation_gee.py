#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Wed May 25 08:54:57 2022

@author: aldotapia
"""

import pandas as pd
import geopandas as gpd
import ee
import collections
collections.Callable = collections.abc.Callable # necesario por problemas en esta versión de python
service_account = 'service@somevalue.iam.gserviceaccount.com'
credentials = ee.ServiceAccountCredentials(email = service_account,key_file = 'key.json')
ee.Initialize(credentials)

# read data
dem = ee.Image("NASA/NASADEM_HGT/001")
camels = ee.FeatureCollection("some/featurecollection")

# get mean elevation by polygon
camels_elev = dem.select("elevation").reduceRegions(
    reducer = ee.Reducer.mean(),
    collection = camels
)
# .getInfo() for extract json
camels_elev = camels_elev.getInfo()

# convert JSON to vector
gdf_elev = gpd.GeoDataFrame.from_features(camels_elev["features"])

# save shapefile
gdf_elev.to_file('path/to/elevation.shp')

# drop geometry column for converting to dataframe
df_elev = pd.DataFrame(gdf_elev.drop(columns='geometry'))

# save table
df_elev.to_csv('Documents/Fondef/gee_test/df_elev.csv')

# create altitude bands
def bands(image):
    return ee.ImageCollection.fromImages((
        image.gt(0),
        image.gt(500),
        image.gt(1000),
        image.gt(1500),
        image.gt(2000),
        image.gt(2500),
        image.gt(3000),
        image.gt(3500),
        image.gt(4000),
        image.gt(4500))).sum()

# reclass DEM by elevation bands
dem_ext = dem.select("elevation")
dem_reclass = bands(dem_ext)

# calculate area with `.pixelArea()`
areaSum = ee.Image.pixelArea().reduceRegions(
    reducer = ee.Reducer.sum(),
    collection = camels,
    scale = 30
)

# get data
areaSum = areaSum.getInfo()

# convert JSON to vector
gdf_areaSum = gpd.GeoDataFrame.from_features(areaSum["features"])

# save shapefile
gdf_areaSum.to_file('path/to/areaSum.shp')

# calculate area by elevation band
bandsOutput = ee.Image.pixelArea().addBands(dem_reclass).reduceRegions(
    reducer = ee.Reducer.sum().group(
        groupField = 1,
        groupName = 'code'
    ),
    collection = camels,
    scale = 30
)#.get('groups')
# get data
bandsOutput = bandsOutput.getInfo()

# convert JSON to vector
gdf_bandsOutput = gpd.GeoDataFrame.from_features(bandsOutput["features"])

# drop geometry column
df_bandsOutput = pd.DataFrame(gdf_bandsOutput.drop(columns='geometry'))

# since result it's in small dictionaries by band inside a nested list, explode it
# explode from list
df_ = df_bandsOutput.explode('groups') 
# take out from dict
df_ = pd.concat([df_bandsOutput['gauge_id'],df_['groups'].apply(pd.Series)], axis = 1)
# to int
df_['code'] = df_['code'].astype(int)
# pivot table
df_ = df_.pivot(index='gauge_id', columns='code', values='sum').add_prefix('code').reset_index()
# fill na values
df_ = df_.fillna(0)
# get columns in float
float_col = df_.select_dtypes(include=['float64'])
# iterate for converting from float to int
for col in float_col.columns.values:
    df_[col] = df_[col].astype('int64')
    
# save to disk
df_.to_csv('Documents/Fondef/gee_test/df_pisosAltitudinales.csv')    