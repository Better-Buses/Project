#!/bin/bash
# First argument: <zones>

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

ZONES="${1:?Usage: $0 <zones>}"
USER="bbus"

# OpenNebula installation
sudo apt update
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | sudo debconf-set-selections
sudo DEBIAN_FRONTEND=noninteractive apt install -y augeas-tools apt-transport-https iptables-persistent netfilter-persistent unzip
wget 'https://github.com/OpenNebula/minione/releases/download/v7.0.1/minione'
chmod +x minione
sudo ./minione --yes | tee $HOME/minione.log

echo ">>> Waiting for OpenNebula host to be monitored..."
until sudo -iu oneadmin onehost show 0 | grep -q "STATE *: MONITORED"; do
  sleep 5
done
echo ">>> Host is monitored."

sudo usermod -aG libvirt,kvm,oneadmin $USER
sudo setfacl -R -m u:oneadmin:rwx /home/$USER
sudo usermod -a -G $USER oneadmin

# SSH public key generation
ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
cat ~/.ssh/id_ed25519.pub

# Copy SSH public key to oneadmin settings
SSH_PUB_KEY=$(cat ~/.ssh/id_ed25519.pub)
echo "SSH_PUBLIC_KEY=\"$SSH_PUB_KEY\"" | sudo -iu oneadmin oneuser update oneadmin -a

# Remove Alpine VM template and import Ubuntu Minimal 24.04 image
sudo -iu oneadmin onetemplate delete 0

UBUNT_IMAGE_NAME="Ubuntu Minimal 24.04"
APP_ID=$(sudo -iu oneadmin onemarketapp list | grep -i "$UBUNT_IMAGE_NAME" | head -n1 | awk '{print $1}')

if [ -z "$APP_ID" ]; then
  echo "ERROR: Ubuntu Minimal 24.04 not found in marketplace"
  sudo -iu oneadmin onemarketapp list | grep -i "Ubuntu Minimal 24.04"
  exit 1
fi

sudo -iu oneadmin onemarketapp export "$APP_ID" "$UBUNT_IMAGE_NAME" --datastore 1

while true; do
  STATE=$(sudo -iu oneadmin oneimage show "$UBUNT_IMAGE_NAME" 2>/dev/null | grep "^STATE" | awk '{print $3}')
  echo "  State: $STATE"
  [ "$STATE" = "rdy" ] && break
  sleep 5
done

sudo -iu oneadmin onetemplate delete 1

# Remove default Security Group from vnet
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

rm /tmp/vnet-update.txt

# Create Security Groups
cat > /tmp/master-sg.txt << EOF
NAME = "Master-SG"
RULE = [PROTOCOL = "TCP", RULE_TYPE = "inbound", RANGE = "22", IP = "172.16.100.1", SIZE = "1"]
RULE = [PROTOCOL = "TCP", RULE_TYPE = "inbound", RANGE = "30000", IP = "172.16.100.1", SIZE = "1"]
RULE = [PROTOCOL = "TCP", RULE_TYPE = "inbound", RANGE = "30001", IP = "172.16.100.1", SIZE = "1"]
RULE = [PROTOCOL = "TCP", RULE_TYPE = "inbound", RANGE = "6443", IP = "172.16.100.4", SIZE = "47"]
RULE = [PROTOCOL = "TCP", RULE_TYPE = "inbound", RANGE = "10250", IP = "172.16.100.4", SIZE = "47"]
RULE = [PROTOCOL = "UDP", RULE_TYPE = "inbound", RANGE = "8472", IP = "172.16.100.4", SIZE = "47"]
RULE = [PROTOCOL = "ICMP", RULE_TYPE = "inbound", IP = "172.16.100.4", SIZE = "47"]
RULE = [PROTOCOL = "ALL", RULE_TYPE = "outbound"]
EOF

cat > /tmp/worker-sg.txt << EOF
NAME = "Worker-SG"
RULE = [PROTOCOL = "TCP", RULE_TYPE = "inbound", RANGE = "22", IP = "172.16.100.1", SIZE = "1"]
RULE = [PROTOCOL = "TCP", RULE_TYPE = "inbound", RANGE = "9273", IP = "172.16.100.2", SIZE = "1"]
RULE = [PROTOCOL = "TCP", RULE_TYPE = "inbound", RANGE = "9100", IP = "172.16.100.2", SIZE = "1"]
RULE = [PROTOCOL = "TCP", RULE_TYPE = "inbound", RANGE = "6443", IP = "172.16.100.2", SIZE = "1"]
RULE = [PROTOCOL = "TCP", RULE_TYPE = "inbound", RANGE = "10250", IP = "172.16.100.2", SIZE = "1"]
RULE = [PROTOCOL = "TCP", RULE_TYPE = "inbound", RANGE = "30184:30233", IP = "172.16.100.3", SIZE = "1"]
RULE = [PROTOCOL = "UDP", RULE_TYPE = "inbound", RANGE = "8472", IP = "172.16.100.2", SIZE = "1"]
RULE = [PROTOCOL = "ICMP", RULE_TYPE = "inbound", IP = "172.16.100.2", SIZE = "1"]
RULE = [PROTOCOL = "ALL", RULE_TYPE = "outbound"]
EOF

sudo -iu oneadmin onesecgroup create /tmp/master-sg.txt
sudo -iu oneadmin onesecgroup create /tmp/worker-sg.txt

rm /tmp/master-sg.txt /tmp/worker-sg.txt

# Create VMs
bash master/deploy.sh
bash sensors/deploy.sh
bash worker/deploy.sh $ZONES

# Expose Grafana and Prometheus (inside master node) to host's ports, letting them accessible from the physical machine
BRIDGE_IF="minionebr"
UPLINK_IF="eth0"
VM_SUBNET="172.16.100.0/24"
MASTER_VM_IP="172.16.100.2"
GRAFANA_PORT=30000
PROMETHEUS_PORT=30001

# Enable IP forwarding
sudo sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" | sudo tee /etc/sysctl.d/99-ip-forward.conf > /dev/null

# Allow forwarded traffic between VM bridge and uplink
sudo iptables -A FORWARD -i "$BRIDGE_IF" -o "$UPLINK_IF" -j ACCEPT
sudo iptables -A FORWARD -i "$UPLINK_IF" -o "$BRIDGE_IF" -m state --state RELATED,ESTABLISHED -j ACCEPT

# Masquerade outbound VM subnet traffic
sudo iptables -t nat -A POSTROUTING -s "$VM_SUBNET" ! -d "$VM_SUBNET" -j MASQUERADE

# Expose Grafana/Prometheus NodePorts on the physical host
sudo iptables -t nat -A PREROUTING -p tcp --dport "$GRAFANA_PORT" -j DNAT --to-destination "${MASTER_VM_IP}:${GRAFANA_PORT}"
sudo iptables -t nat -A PREROUTING -p tcp --dport "$PROMETHEUS_PORT" -j DNAT --to-destination "${MASTER_VM_IP}:${PROMETHEUS_PORT}"

# Persist only these static rules
sudo tee /etc/iptables/rules.v4 > /dev/null <<EOF
*nat
:PREROUTING ACCEPT [0:0]
:INPUT ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0]
-A PREROUTING -p tcp -m tcp --dport ${GRAFANA_PORT} -j DNAT --to-destination ${MASTER_VM_IP}:${GRAFANA_PORT}
-A PREROUTING -p tcp -m tcp --dport ${PROMETHEUS_PORT} -j DNAT --to-destination ${MASTER_VM_IP}:${PROMETHEUS_PORT}
-A POSTROUTING -s ${VM_SUBNET} ! -d ${VM_SUBNET} -j MASQUERADE
COMMIT
*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
-A FORWARD -i ${BRIDGE_IF} -o ${UPLINK_IF} -j ACCEPT
-A FORWARD -i ${UPLINK_IF} -o ${BRIDGE_IF} -m state --state RELATED,ESTABLISHED -j ACCEPT
COMMIT
EOF

sudo systemctl enable netfilter-persistent