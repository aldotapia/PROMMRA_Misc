#!/usr/bin/env python
# -*- coding: utf-8 -*-
#
# Copyright (c) 2022 Aldo Tapia.
#
# This program is free software: you can redistribute it and/or modify  
# it under the terms of the GNU General Public License as published by  
# the Free Software Foundation, version 3.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.
#

import time
import requests
import board
import busio
import adafruit_ads1x15.ads1115 as ADS
from adafruit_ads1x15.analog_in import AnalogIn
import math
import requests
import os

'''
Initial configuration
'''

# flow sensor gpio
FLOW_SENSOR_GPIO = 13

# configure GPIO 
GPIO.setmode(GPIO.BCM)
GPIO.setup(FLOW_SENSOR_GPIO, GPIO.IN, pull_up_down = GPIO.PUD_UP)

# set global variable for counting pulses
global count
count = 0
 
def countPulse(channel):
    '''count pulses from flowmeter'''
    global count
    if start_counter == 1:
        count = count+1

# add event for flowmeter
GPIO.add_event_detect(FLOW_SENSOR_GPIO, GPIO.FALLING, callback=countPulse)

# create the I2C bus
i2c = busio.I2C(board.SCL, board.SDA)

# create the ADC object using the I2C bus
ads = ADS.ADS1115(i2c, gain = 2/3)

# create single-ended input on channel 0
chan0 = AnalogIn(ads, ADS.P0)
chan1 = AnalogIn(ads, ADS.P1)
chan2 = AnalogIn(ads, ADS.P0)

'''
paths and values settings
'''

# piezometer deep from soil, in cm
piezometer_deep = 150 # test, change for real value
# water tank height, in cm
watertank_height = 168
# water tank diameter, in cm
watertank_diameter = 166
# US sensor distance from water tank bottom, in mm
maxdist = 1660
# seconds for flowmeter
seconds_fm = 10

# site for post
site = ''

# database path
database_path = '/home/aldo/Datalogger/database.txt'

'''
functions definition
'''

def piezometer(x,piezometer_deep):
    '''convert data from piezometer'''
    vg = x.voltage
    if vg <= 0.5:
        water_column = 0
    elif vg >= 4.5:
        water_column = 10
    else:
        water_column = (vg - 0.5) * 2.5
    well_depth = piezometer_deep - water_column*100
    return round(well_depth,2)
   
def flowmeter(x, seconds):
    '''convert data from flowmeter'''
    flow = (x / (5 * seconds)) 
    return round(flow,2)
   
def pressure_sensor(x):
    '''convert data from preasure sensor (in bar)'''
    vg = x.voltage
    if vg <= 0.5:
        pressure = 0
    elif vg >= 4.5:
        pressure = 12
    else:
        pressure = (vg - 0.5) * 3
    return round(pressure,2)
   
def watertank(x, maxdist, wtd):
    '''measure water level tank in mm'''
    vg = x.voltage
    distance = vg/(5/5120)
    level_mm = maxdist - distance
    level_cm = level_mm / 10
    storage_volume_cm = math.pi * ((wtd/2) ** 2) * level_cm
    storage_volume_l = int(storage_volume_cm / 1000)    
    return round(storage_volume_l)
   
def post_management(timevalue, site, pzv, fmv, psv, wtv):
    '''post into the database'''
    str_time = time.strftime("%Y-%m-%d %H:%M:%S", timevalue)
    data_upload = requests.post(site,
                            data={'station_id':'2','date':str_time,
                                  's1':{pzv},'s2':{fmv},
                                  's3':{psv},'s4':{wtv}})
    return print(data_upload)
   
def line_management(timevalue, database, pzv, fmv, psv, wtv):
    '''save data locally'''
    str_time = time.strftime("%Y-%m-%d %H:%M:%S", timevalue)
    line = f'{str_time},{pzv},{fmv},{psv},{wtv}\n'
    print(line)
    with open(database,'a') as the_file:
                the_file.write(line)
    print('data saved')
       
if __name__ == '__main__':
    # Calculate water tank volume
    tank_volume_cm = math.pi * ((watertank_diameter/2) ** 2) * watertank_height
    tank_volume_l = int(tank_volume_cm / 1000)
   
    # Check or create database    
    if os.path.exists(database_path):
        print('Database found, using ' + database_path)
    else:
        print('Database not found, creating it for ' + database_path)
        header_line  = 'date,well_depth,flow,pressure,tank_level\n'
        with open(database_path,'w') as the_file:
            the_file.write(header_line)    
   
    # get current time
    actualtime = time.localtime()
    minute_test = actualtime.tm_min

    print(f'Starting!. Current date: {time.strftime("%Y-%m-%d %H:%M:%S", actualtime)}')
   
    while True:
        try:
            if actualtime.tm_min != minute_test:
                # pull values
                start_counter = 1
                time.sleep(seconds_fm)
                start_counter = 0
                
                try:
                    pzv = piezometer(x = chan0,piezometer_deep = piezometer_deep)
                except:
                    pzv = -999
                try:
                    fmv = flowmeter(count, seconds_fm)
                except:
                    fmv = -999
                try:
                    psv = pressure_sensor(x = chan2)
                except:
                    psv = -999
                try:
                    wtv = watertank(x = chan1, maxdist = maxdist, wtd = watertank_diameter)
                except:
                    wtv = -999
               
                # post to database
                post_management(timevalue = actualtime,
                                site = site,
                                pzv = pzv,
                                fmv = fmv,
                                psv = psv,
                                wtv = wtv)
               
                # save to local
                line_management(timevalue = actualtime,
                                database = database_path,
                                pzv = pzv,
                                fmv = fmv,
                                psv = psv,
                                wtv = wtv)
               
                # reset count and save current minute
                count = 0
                minute_test = actualtime.tm_min
                actualtime = time.localtime()
            else:
                actualtime = time.localtime()
        except:
            continue