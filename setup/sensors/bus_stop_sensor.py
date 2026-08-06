#!/usr/bin/env python3

import random
import paho.mqtt.client as mqtt

class BusStopSensor:
    def __init__(self, x: float, y: float, zone: int, sensor_id: int):
        self.x = x
        self.y = y
        self.__zone = zone
        self.__sensor_id = sensor_id

        # Assume
        # x.x.x.2 -> Master
        # x.x.x.3 -> Sensors VM
        # x.x.x.4 -> Worker-1
        # x.x.x.5 -> Worker-2
        # ...
        host_id = 3 + zone
        self.__broker_ip = "172.16.100." + str(host_id)
        self.__broker_port = 30183 + zone
        self.__topic = f"zone-{zone}/stop-{sensor_id}"

        self.__client = mqtt.Client()
        self.__client.connect(self.__broker_ip, self.__broker_port, keepalive=60)
        self.__client.loop_start()

        print(f"Sensor {sensor_id} in zone {zone} publishes to {self.__broker_ip}:{self.__broker_port} on topic '{self.__topic}'")

    def send_bus_arrival_time(self):
        try:
            value = round(random.uniform(-5, 5))  # Simulate schedule offset
            self.__client.publish(self.__topic, str(value))

            print(f"Sensor {self.__sensor_id} in zone {self.__zone} sent: {value}")
        except KeyboardInterrupt:
            print("Stopping")
            self.__client.loop_stop()
            self.__client.disconnect()
