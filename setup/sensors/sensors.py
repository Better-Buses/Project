#!/usr/bin/env python3
"""
Very simple sensor simulator: generates a random number every few seconds
and publishes it over MQTT to the broker running in the k3s cluster.

Usage:
    python3 sensor.py <broker_ip> <broker_port>

Example (using the master or worker node IP + NodePort):
    python3 sensor.py 172.16.100.3 30183
"""

import sys
import time
import random
import paho.mqtt.client as mqtt

BROKER_IP = sys.argv[1] if len(sys.argv) > 1 else "172.16.100.2"
BROKER_PORT = int(sys.argv[2]) if len(sys.argv) > 2 else 30183
TOPIC = "zone-1/sensor-1"
INTERVAL = 2  # seconds between readings

client = mqtt.Client()
client.connect(BROKER_IP, BROKER_PORT, keepalive=60)
client.loop_start()

print(f"Publishing to {BROKER_IP}:{BROKER_PORT} on topic '{TOPIC}' every {INTERVAL}s")

try:
    while True:
        value = round(random.uniform(0, 100), 2)
        client.publish(TOPIC, str(value))
        print(f"Sent: {value}")
        time.sleep(INTERVAL)
except KeyboardInterrupt:
    print("Stopping.")
    client.loop_stop()
    client.disconnect()
