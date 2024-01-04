#!/bin/bash

# Function to display usage information
function show_usage {
    echo "Usage: $0 [-h | -help] <port_number>"
}

# Check if any arguments are provided
if [ $# -eq 0 ]; then
    show_usage
    exit 1
fi

# Check for help options
if [ "$1" == "-h" ] || [ "$1" == "-help" ]; then
    show_usage
    exit 0
fi

# Extract the port number from the command-line argument
port_number=$1

# Run the netstat command
netstat -tn | grep ":$port_number.*ESTABLISHED"


#sudo wget https://raw.githubusercontent.com/arkh91/public_script_files/main/port.sh && chmod u+x port.sh
#This works fine
