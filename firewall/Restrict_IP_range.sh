#!/bin/bash

#######################################
#                                     #
#  This code has been written by:     #
#  https://github.com/arkh91/         #                        
#                                     #
#######################################

# Check if the correct number of arguments is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <file_path>"
    exit 1
fi

file_path="$1"

# Check if the file exists
if [ ! -e "$file_path" ]; then
    echo "Error: File $file_path does not exist."
    exit 1
fi

# Check if the file is readable
if [ ! -r "$file_path" ]; then
    echo "Error: File $file_path is not readable."
    exit 1
fi

# Your code that uses the file_path argument goes here
echo "Using file path argument: $file_path"

# Iterate through each line in the file
while read -r start_ip end_ip _; do
    # Check if the line contains two IP addresses
    if [[ "$start_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ && "$end_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        # Block the IP range using iptables
        echo "Blocking IP range: $start_ip - $end_ip"
        sudo iptables -A INPUT -m iprange --src-range "$start_ip"-"$end_ip" -j DROP
        #sudo iptables -A INPUT -m iprange --src-range "$start_ip"-"$end_ip" -j ACCEPT
    fi
done < "$file_path"

#sudo wget https://raw.githubusercontent.com/arkh91/public_script_files/main/firewall/Restrict_IP_range.sh && chmod +x Restrict_IP_range.sh 
