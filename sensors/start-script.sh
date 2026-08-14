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

apk update
apk add git python3 py3-pip
pip install paho-mqtt --break-system-packages

mkdir -p /root/project
cd /root/project
git clone https://github.com/Better-Buses/Project.git . || echo "CLONE FAILED: $?"
cd project
git checkout sensors
cd ..
mv /root/project/* /root/ 2>/dev/null
rmdir /root/project
