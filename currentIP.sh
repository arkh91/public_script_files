#!/bin/bash

extaddr=$(curl -s ifconfig.me/ip)

echo "The external IP address is $extaddr (from cURL)"

#chmod +x currentIP.sh
#sudo wget https://raw.githubusercontent.com/arkh91/public_script_files/main/currentIP.sh 
