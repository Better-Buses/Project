#!bin/bash

sudo hostnamectl set-hostname master
echo "127.0.1.1 master" | sudo tee -a /etc/hosts
