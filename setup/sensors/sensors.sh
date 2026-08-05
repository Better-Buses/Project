#!/bin/bash
# First argument:   <master-ip>
# Second argument:  <broker-port>

# Install Python and MQTT dependencies
apk update
apk add python3 py3-pip
pip install paho-mqtt --break-system-packages

# Run the script
python3 sensors.sh $1 $2
