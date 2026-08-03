#!bin/bash
# Parameters => master ip

sudo iptables -t nat -A PREROUTING -p tcp --dport 30000 -j DNAT --to-destination $1:30000
sudo iptables -t nat -A PREROUTING -p tcp --dport 30001 -j DNAT --to-destination $1:30001
sudo iptables -t nat -A POSTROUTING -j MASQUERADE
