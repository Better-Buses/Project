#!bin/bash
# First argument: <master_vm_ip>
# 
# Expose Grafana and Prometheus (inside master node) to host's ports, letting them accessible from the physical machine

MASTER_IP="${1:-172.16.100.2}"

sudo iptables -t nat -A PREROUTING -p tcp --dport 30000 -j DNAT --to-destination $MASTER_IP:30000
sudo iptables -t nat -A PREROUTING -p tcp --dport 30001 -j DNAT --to-destination $MASTER_IP:30001
sudo iptables -t nat -A POSTROUTING -j MASQUERADE

sudo iptables-save | sudo tee /etc/iptables/rules.v4
