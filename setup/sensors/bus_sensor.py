#!/usr/bin/env python3

import time
import threading
import paho.mqtt.client as mqtt
from bus_stop_sensor import BusStopSensor

class BusSensor:
    def __init__(self, zone: int, stops: list[BusStopSensor]):
        self.__zone = zone
        self.__stops = stops

        # Assume
        # x.x.x.2 -> Master
        # x.x.x.3 -> Sensors VM
        # x.x.x.4 -> Worker-1
        # x.x.x.5 -> Worker-2
        # ...
        host_id = 3 + zone
        self.__broker_ip = "172.16.100." + str(host_id)
        self.__broker_port = 30183 + zone
        self.__topic = f"zone-{zone}/bus"  # Only 1 bus per zone
        self.__interval = 5

        self.__client = mqtt.Client()
        self.__client.connect(self.__broker_ip, self.__broker_port, keepalive=60)
        self.__client.loop_start()

        print(f"Bus in zone {zone} publishing to {self.__broker_ip}:{self.__broker_port} on topic '{self.__topic}' every {self.__interval}s")

        self.__stop_event = threading.Event()
        self.__thread = threading.Thread(target=self.__move, daemon=True)
        self.__thread.start()

    def stop(self):
        self.__stop_event.set()

    def f():
        return 1.0, 5.0

    def __interpolate_route(self, stops: list[BusStopSensor], steps: int = 5):
        if len(stops) < 2:
            return [(stops[0].x, stops[0].y)]

        stops_coords = [(s.x, s.y) for s in stops]
        path = [stops_coords[0]]
        for (x0, y0), (x1, y1) in zip(stops_coords, stops_coords[1:]):
            for i in range(1, steps + 1):
                t = i / steps
                x = x0 + (x1 - x0) * t
                y = y0 + (y1 - y0) * t
                path.append((x, y))

        return path

    def __move(self):
        try:
            steps_per_route = 5
            path = self.__interpolate_route(self.__stops, steps_per_route)

            for i in range(len(path)):
                if self.__stop_event.is_set():
                    break

                if i % steps_per_route == 0:
                    # The bus reached the bus stop
                    self.__stops[int(i / steps_per_route)].send_bus_arrival_time()

                pos = path[i]
                self.__client.publish(self.__topic, json.dumps({"x": pos[0], "y": pos[1]}))

                print(f"Bus {self.__zone} sent: {pos}")
                
                time.sleep(self.__interval)
        except KeyboardInterrupt:
            print("Stopping")
            self.__client.loop_stop()
            self.__client.disconnect()
