#!/bin/bash

extaddr=$(curl -s ifconfig.me/ip)

echo "The external IP address is $extaddr (from cURL)"

#chmod +x currentIP.sh
