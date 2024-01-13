#!/bin/bash

filename="your_file.txt"

while IFS= read -r line; do
    # Ignore lines starting with #
    if [[ "$line" == \#* ]]; then
        continue
    fi

    # Accept connection with iptables for lines starting with $
    if [[ "$line" == \$* ]]; then
        ip=$(echo "$line" | awk '{print $2}')
        iptables -A INPUT -s "$ip" -j ACCEPT
        echo "Accepted connection from $ip"
        continue
    fi

    # For lines starting with a number, create a range to block all IP addresses
    if [[ "$line" =~ ^[0-9] ]]; then
        start_ip=$(echo "$line" | awk '{print $1}')
        end_ip=$(echo "$line" | awk '{print $2}')
        iptables -A INPUT -m iprange --src-range "$start_ip"-"$end_ip" -j DROP
        echo "Blocked IP range from $start_ip to $end_ip"
    fi

done < "$filename"
