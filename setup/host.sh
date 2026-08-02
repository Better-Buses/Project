#!/bin/bash

# OpenNebula installation

USER="bbox"

sudo apt-get install -y augeas-tools apt-transport-https iptables-persistent netfilter-persistent unzip
wget 'https://github.com/OpenNebula/minione/releases/download/v7.0.1/minione'
chmod +x minione
sudo ./minione | tee $HOME/minione.log

sudo usermod -aG libvirt,kvm,oneadmin $USER
sudo setfacl -R -m u:oneadmin:rwx /home/$USER
sudo usermod -a -G $USER oneadmin
newgrp libvirt
newgrp oneadmin

# SSH public key generation

ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa
