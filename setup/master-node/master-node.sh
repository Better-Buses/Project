#!/bin/bash
# Firstly copy prometheus-ingress.yaml, then execute this script

# Enable connection

echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf

# Install k3s in server mode

# TODO: when?
# # Rename the node (k3s uses hostname as node identity by default)

# sudo hostnamectl set-hostname master
# echo "127.0.1.1 master" | sudo tee -a /etc/hosts

# Create Mosquitto Deployment

kubectl apply -f mosquitto.yaml
