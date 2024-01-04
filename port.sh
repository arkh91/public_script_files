#!/bin/bash

# Check if a port number is provided as an argument
if [ $# -eq 0 ]; then
    echo "Usage: $0 <port_number>"
    exit 1
fi

# Extract the port number from the command-line argument
port_number=$1

# Run the netstat command
netstat -tn | grep ":$port_number.*ESTABLISHED"

#sudo wget https://raw.githubusercontent.com/arkh91/public_script_files/main/port.sh && chmod u+x port.sh
