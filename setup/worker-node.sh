#!/bin/bash
# First argument:   <worker_index>
# Second argument:  <master_vm_ip>
# Third argument:   <master_node_token>
# 
# To get <master_node_token>, go to master VM and run
#   sudo cat /var/lib/rancher/k3s/server/node-token

# Enable connection

echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf

# Rename the node (k3s uses hostname as node identity by default)

sudo hostnamectl set-hostname worker-$1
echo "127.0.1.1 worker-$1" | sudo tee -a /etc/hosts

# Install k3s in agent mode and join the VM to the cluster

curl -sfL https://get.k3s.io | K3S_URL=https://$2:6443 K3S_TOKEN=$3 sh -
