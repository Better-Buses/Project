#!/bin/bash
# Convert to base64 and place in the template.one
#   base64 -w0 start-script.sh

exec > /var/log/my-context.log 2>&1
set -x

network_ready=false
for i in $(seq 1 30); do
  if timeout 2 bash -c "echo > /dev/tcp/8.8.8.8/53" 2>/dev/null; then
    network_ready=true
    break
  fi
  sleep 2
done

if [ "$network_ready" = false ]; then
  echo "NETWORK NEVER CAME UP - aborting"
  exit 1
fi

echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf > /dev/null

apt update
apt install -y git

mkdir -p /root/project
cd /root/project
git clone https://github.com/Better-Buses/Project.git . || echo "CLONE FAILED: $?"
cd project
git checkout master-node
setsid nohup bash /root/project/master/setup.sh > /var/log/provision.log 2>&1 < /dev/null &
