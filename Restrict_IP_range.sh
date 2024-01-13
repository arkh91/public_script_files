#!/bin/bash

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
while IFS= read -r line; do
    # Check if the line starts with $
    if [[ $line == \$* ]]; then
        # Extract the IP address from the line (assuming it's in the format $IP_ADDRESS)
        ip_address="${line#\$}"

        # Accept the connection using the extracted IP address
        echo "Accepting connection from IP: $ip_address"
        sudo iptables -A INPUT -s $ip_address -j ACCEPT
    fi
done < "$file_path"

# Iterate through each line in the file
while IFS=$'\t' read -r start_ip end_ip; do
    # Check if the line contains two IP addresses (assuming they are separated by a tab)
    if [[ "$start_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ && "$end_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        # Block the IP range using iptables
        echo "Blocking IP range: $start_ip - $end_ip"
        sudo iptables -A INPUT -m iprange --src-range "$start_ip"-"$end_ip" -j DROP
    fi
done < "$file_path"


# Check if the file exists
#if [ ! -f "$file_path" ]; then
#    echo "File not found: $file_path"
 #   exit 1
#fi

# Read each line from the file
#while IFS= read -r line; do
    # Ignore lines starting with '#' (comments)
 #   if [[ "$line" =~ ^[^#] ]]; then
        # Extract the IP address from the line
#        ip_address=$(echo "$line" | awk '{print $1}')
        
        # Perform your desired action with the IP address
        # For example, you can use iptables to accept the IP
#        iptables -A INPUT -s "$ip_address" -j ACCEPT
        
        # Print a message indicating the action
#        echo "Accepted IP: $ip_address"
#    fi
#done < "$file_path"

#sudo wget https://raw.githubusercontent.com/arkh91/public_script_files/main/Restrict_IP_range.sh && chmod +x Restrict_IP_range.sh 
