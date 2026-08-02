#!/bin/bash
# First argument:   <master_vm_ip>
# Second argument:  <node_port>

# Enable connection

echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf

# Install Python and MQTT dependencies

apk update
apk add python3 py3-pip
pip install paho-mqtt --break-system-packages

# Run the script

python3 sensors.sh $1 $2
