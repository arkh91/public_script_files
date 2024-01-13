#!/bin/bash

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <path_to_file>"
    exit 1
fi

file_path=$1

# Check if the file exists
if [ ! -f "$file_path" ]; then
    echo "File not found: $file_path"
    exit 1
fi

# Read each line from the file
while IFS= read -r line; do
    # Ignore lines starting with '#' (comments)
    if [[ "$line" =~ ^[^#] ]]; then
        # Extract the IP address from the line
        ip_address=$(echo "$line" | awk '{print $1}')
        
        # Perform your desired action with the IP address
        # For example, you can use iptables to accept the IP
        iptables -A INPUT -s "$ip_address" -j ACCEPT
        
        # Print a message indicating the action
        echo "Accepted IP: $ip_address"
    fi
done < "$file_path"

#sudo wget https://raw.githubusercontent.com/arkh91/public_script_files/main/Restrict_IP_range.sh && chmod +x Restrict_IP_range.sh 
