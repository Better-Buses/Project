#!/bin/bash
# Install OpenNebula, setup its dependencies and permissions, and generate SSH keys to connect to VMs without password.
# TODO: The SSH public key must be copied to oneadmin settings.

# OpenNebula installation

USER="bbus"

sudo apt update
sudo apt install -y augeas-tools apt-transport-https iptables-persistent netfilter-persistent unzip
wget 'https://github.com/OpenNebula/minione/releases/download/v7.0.1/minione'
chmod +x minione
sudo ./minione | tee $HOME/minione.log

sudo usermod -aG libvirt,kvm,oneadmin $USER
sudo setfacl -R -m u:oneadmin:rwx /home/$USER
sudo usermod -a -G $USER oneadmin
newgrp libvirt
newgrp oneadmin

# SSH public key generation

ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
cat ~/.ssh/id_ed25519.pub
