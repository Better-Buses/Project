#!bin/bash

echo "127.0.0.1 master" >> /etc/hosts
sudo hostnamectl set-hostname master
echo "127.0.1.1 master" | sudo tee -a /etc/hosts
sudo reboot
