#!/usr/bin/env python3

import csv
import time
from collections import defaultdict
from bus_stop_sensor import BusStopSensor
from bus_sensor import BusSensor

bus_stops_dict: dict[int, list[BusStopSensor]] = defaultdict(list)
schedule_dict: dict[int, list[str]] = defaultdict(list)

with open('setup/sensors/schedule.csv', newline='') as csvfile:
    reader = csv.DictReader(csvfile)
    for row in reader:
        zone = reader.line_num - 1
        for stop_col, expected_time in row.items():
            schedule_dict[zone].append(expected_time.strip())

with open('setup/sensors/bus-stops.csv', newline='') as csvfile:
    reader = csv.DictReader(csvfile)

    for row in reader:
        zone = reader.line_num - 1
        sensor_id = 1

        for coord in row.values():
            x = float(coord.split()[0])
            y = float(coord.split()[1])

            expected_time = schedule_dict[zone][sensor_id - 1]
            bus_stops_dict[zone].append(BusStopSensor(x, y, zone, sensor_id,expected_time))

            sensor_id += 1

buses_dict: dict[int, BusSensor] = defaultdict(list)

zone = 1
for stops in bus_stops_dict.values():
    buses_dict[zone] = BusSensor(zone, stops)

    zone += 1

# Keeps the main thread alive
try:
    while True:
        time.sleep(1)
except KeyboardInterrupt:
    print("Shutting down all buses...")
    for bus in buses_dict.values():
        bus.stop()
