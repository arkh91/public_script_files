#!/bin/bash

sudo apt-get update && apt upgrade -y 
#https://stackoverflow.com/questions/5947742/how-to-change-the-output-color-of-echo-in-linux

echo -e "\033[32mSystem updated.\033[m"

sudo apt-get install libssl1.1  
wget http://archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2_amd64.deb
echo -e "\033[35mlibssl1.1_1.1.1f-1ubuntu2_amd64.deb is downloaded.\033[m"
sudo dpkg -i libssl1.1_1.1.1f-1ubuntu2_amd64.deb
echo -e "\033[32mlibssl1.1_1.1.1f-1ubuntu2_amd64.deb is installed.\033[m"

read -p "Press enter to continue"

sudo wget https://github.com/korn-sudo/Project-Fog/raw/main/files/installer/ubv301b && chmod +x ./ubv301b && ./ubv301b -y

echo -e "\033[36mInstallation is finished.\033[m"

#https://www.youtube.com/watch?v=BGIHEAd35do
#sudo wget https://github.com/arkh91/public_script_files/blob/main/v2ray.sh && chmod +x ./v2ray.sh -y
