#!/bin/bash
# First argument:   <worker-index>
# Second argument:  <master-ip>
# Third argument:   <master-token>
# 
# To get <master-token>, go to master VM and run
#   sudo cat /var/lib/rancher/k3s/server/node-token

ZONE="${1:?Usage: $0 <worker-index> <master-ip> <master-token>}"
MASTER_IP="${2:?Usage: $0 <worker-index> <master-ip> <master-token>}"
MASTER_TOKEN="${3:?Usage: $0 <worker-index> <master-ip> <master-token>}"

# # Enable connection

# echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf

# Rename the node (k3s uses hostname as node identity by default)
sudo hostnamectl set-hostname worker-$ZONE
echo "127.0.1.1 worker-$ZONE" | sudo tee -a /etc/hosts

# Install k3s in agent mode and join the VM to the cluster
curl -sfL https://get.k3s.io | K3S_URL=https://$MASTER_IP:6443 K3S_TOKEN=$MASTER_TOKEN sh -
