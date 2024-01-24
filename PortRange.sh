#!/bin/bash

#######################################
#                                     #
#  This code has been written by:     #
#  https://github.com/arkh91/         #                        
#                                     #
#######################################

# Function to display usage information
function show_usage {
    echo "Usage: $0 [-h | -help] <port_number>"
}
# Check if any arguments are provided
if [ $# -eq 0 ]; then
    show_usage
    exit 1
fi

#Check if arg1 in not provided OR arg1 is not a number OR not a number between 0 and 65535
if [ -z "$1" ] || ! [[ "$1" =~ ^[0-9]+$ ]] || (( $1 < 0 )) || (( $1 > 65535 )); then
    echo "Error: Invalid arg1."
    exit 1
fi

#Check if arg2 in not provided OR arg1 is not a number OR not a number between 0 and 65535 OR arg2<arg1
if [ -z "$2" ] || ! [[ "$2" =~ ^[0-9]+$ ]] || (( $2 < 0 )) || (( $2 > 65535 )) || (( $2 < $1 )); then
    echo "Error: Invalid arg1."
    exit 1
fi

# Check for help options
if [ "$1" == "-h" ] || [ "$1" == "-help" ]; then
    show_usage
    exit 0
fi
# Extract the port number from the command-line argument
start_port=$1
end_port=$2

# Run the netstat command
netstat -tn | grep -E ":($start_port|$end_port).*ESTABLISHED"

#Sample: netstat -tn | grep ':18687.*ESTABLISHED'

#sudo wget https://raw.githubusercontent.com/arkh91/public_script_files/main/port.sh && chmod u+x port.sh
#sudo apt-get install net-tools -y
#This works fine