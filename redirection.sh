#!/bin/bash

# Function to check if the provided IP address is valid
valid_ip() {
    local ip="$1"
    # Check if the IP address is in the correct format (x.x.x.x where x is between 0-255)
    if [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        IFS='.' read -r -a octets <<< "$ip"
        for octet in "${octets[@]}"; do
            if (( octet < 0 || octet > 255 )); then
                return 1
            fi
        done
        return 0
    else
        return 1
    fi
}

# Function to check if the provided port is valid
valid_port() {
    local port="$1"
    if [[ "$port" =~ ^[0-9]+$ ]] && (( port >= 1 && port <= 65535 )); then
        return 0
    else
        return 1
    fi
}

# Function to prompt for input and validate it
get_valid_input() {
    local prompt="$1"
    local validation_fn="$2"
    local input
    while true; do
        read -p "$prompt" input
        if $validation_fn "$input"; then
            echo "$input"
            return 0
        else
            echo "Invalid input. Please try again."
        fi
    done
}

# Get the arguments interactively if not provided
if [ "$#" -ne 3 ]; then
    echo -e "\033[0;31mArguments not provided or invalid. Please enter the following values.\033[0m"
    echo
    
    # Get middle IP, destination IP, and port interactively
    middle_ip=$(get_valid_input "Enter middle IP address: " valid_ip)
    destination_ip=$(get_valid_input "Enter destination IP address: " valid_ip)
    port=$(get_valid_input "Enter port (1-65535): " valid_port)
else
    # If arguments are provided, use them
    middle_ip="$1"
    destination_ip="$2"
    port="$3"
fi

# Enable IP forwarding
sysctl net.ipv4.ip_forward=1

# Apply the iptables rules
iptables -t nat -A PREROUTING -p tcp --dport "$port" -j DNAT --to-destination "$middle_ip"
iptables -t nat -A PREROUTING -p tcp --dport "$port" -j DNAT --to-destination "$destination_ip"
iptables -t nat -A POSTROUTING -j MASQUERADE

echo
echo -e "\033[0;32mIptables rules applied successfully.\033[0m"
read -p "Press enter to continue"
