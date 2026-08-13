#!/bin/bash

cat > /tmp/vnet-update.txt << 'EOF'
BRIDGE="minionebr"
BRIDGE_TYPE="linux"
DNS="172.16.100.1"
FILTER_IP_SPOOFING="NO"
FILTER_MAC_SPOOFING="NO"
GATEWAY="172.16.100.1"
OUTER_VLAN_ID=""
PHYDEV=""
SECURITY_GROUPS=""
VLAN_ID=""
VN_MAD="fw"
EOF

sudo -iu oneadmin onevnet update 0 /tmp/vnet-update.txt
