#!/bin/bash
# First argument: <zones>

ZONES="${1:?Usage: $0 <zones>}"
USER="bbus"

# # OpenNebula installation
# sudo apt update
# sudo apt install -y augeas-tools apt-transport-https iptables-persistent netfilter-persistent unzip
# wget 'https://github.com/OpenNebula/minione/releases/download/v7.0.1/minione'
# chmod +x minione
# sudo ./minione | tee $HOME/minione.log

# sudo usermod -aG libvirt,kvm,oneadmin $USER
# sudo setfacl -R -m u:oneadmin:rwx /home/$USER
# sudo usermod -a -G $USER oneadmin
# newgrp libvirt
# newgrp oneadmin

# # SSH public key generation
# ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
# cat ~/.ssh/id_ed25519.pub

# # Copy SSH public key to oneadmin settings

# # Remove default Security Group from vnet
# cat > /tmp/vnet-update.txt << 'EOF'
# BRIDGE="minionebr"
# BRIDGE_TYPE="linux"
# DNS="172.16.100.1"
# FILTER_IP_SPOOFING="NO"
# FILTER_MAC_SPOOFING="NO"
# GATEWAY="172.16.100.1"
# OUTER_VLAN_ID=""
# PHYDEV=""
# SECURITY_GROUPS=""
# VLAN_ID=""
# VN_MAD="fw"
# EOF

# sudo -iu oneadmin onevnet update 0 /tmp/vnet-update.txt

# # Create Security Groups

# # Assign Security Groups IDs to the VMs templates

# Create VMs
bash master/deploy.sh
bash sensors/deploy.sh
bash worker/deploy.sh $ZONES

# # Expose Grafana and Prometheus (inside master node) to host's ports, letting them accessible from the physical machine
# sudo iptables -t nat -A PREROUTING -p tcp --dport 30000 -j DNAT --to-destination 172.16.100.2:30000
# sudo iptables -t nat -A PREROUTING -p tcp --dport 30001 -j DNAT --to-destination 172.16.100.2:30001
# sudo iptables -t nat -A POSTROUTING -j MASQUERADE

# sudo iptables-save | sudo tee /etc/iptables/rules.v4