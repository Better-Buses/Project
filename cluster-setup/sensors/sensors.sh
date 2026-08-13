#!/bin/bash
# Assume the following structure in order to dynamically assign brokers' IPs and ports
# x.x.x.2 -> Master
# x.x.x.3 -> Sensors VM
# x.x.x.4 -> Worker-1
# x.x.x.5 -> Worker-2
# ...

# Install Python and MQTT dependencies
apk update
apk add python3 py3-pip
pip install paho-mqtt --break-system-packages

# Run the script
python3 sensors.py
