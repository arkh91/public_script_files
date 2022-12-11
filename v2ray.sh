#!/bin/bash

sudo apt-get update && apt upgrade -y 
sudo apt-get install libssl1.1  
wget http://archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2_amd64.deb
sudo dpkg -i libssl1.1_1.1.1f-1ubuntu2_amd64.deb


sudo wget https://github.com/korn-sudo/Project-Fog/raw/main/files/installer/ubv301b && chmod +x ./ubv301b && ./ubv301b
