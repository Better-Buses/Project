#!/bin/bash
# First argument:   <worker-index>
# Second argument:  <master-token>
# 
# To get <master-token>, go to master VM and run
#   sudo cat /var/lib/rancher/k3s/server/node-token

ZONE="${1:?Usage: $0 <worker-index> <master-token>}"
MASTER_TOKEN="${2:?Usage: $0 <worker-index> <master-token>}"

# Rename the node (k3s uses hostname as node identity by default)
sudo hostnamectl set-hostname worker-$ZONE
echo "127.0.1.1 worker-$ZONE" | sudo tee -a /etc/hosts

# Install k3s in agent mode and join the VM to the cluster
curl -sfL https://get.k3s.io | K3S_URL=https://172.16.100.2:6443 K3S_TOKEN=$MASTER_TOKEN sh -

sudo reboot
