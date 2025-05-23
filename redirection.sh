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
    local error_message="$3"
    local input
    while true; do
        read -p "$prompt" input
        if $validation_fn "$input"; then
            echo "$input"
            return 0
        else
            echo "$error_message"
        fi
    done
}

# Check if arguments are provided or ask for input
if [[ "$#" -eq 3 ]]; then
    # Validate provided arguments
    if valid_ip "$1"; then
        middle_ip="$1"
    else
        echo "Error: Invalid middle IP address: $1"
        middle_ip=$(get_valid_input "Enter middle IP address: " valid_ip "Invalid middle IP address. Please try again.")
    fi

    if valid_ip "$2"; then
        destination_ip="$2"
    else
        echo "Error: Invalid destination IP address: $2"
        destination_ip=$(get_valid_input "Enter destination IP address: " valid_ip "Invalid destination IP address. Please try again.")
    fi

    if valid_port "$3"; then
        port="$3"
    else
        echo "Error: Invalid port number: $3"
        port=$(get_valid_input "Enter port (1-65535): " valid_port "Invalid port number. Please try again.")
    fi
else
    # Prompt for inputs interactively
    echo "Please enter the required values:"
    middle_ip=$(get_valid_input "Enter middle IP address: " valid_ip "Invalid middle IP address. Please try again.")
    destination_ip=$(get_valid_input "Enter destination IP address: " valid_ip "Invalid destination IP address. Please try again.")
    port=$(get_valid_input "Enter port (1-65535): " valid_port "Invalid port number. Please try again.")
fi

# Download and install Xray
curl -L https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh | bash

# Configuration file
cat <<EOF > /etc/xray/config.json
{
  "inbounds": [
    {
      "port": $port,
      "protocol": "dokodemo-door",
      "settings": {
        "address": "$destination_ip",
        "port": 0,
        "network": "tcp,udp",
        "timeout": 0,
        "followRedirect": false
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
EOF

# Start Xray service
systemctl restart xray

echo
echo -e "\033[0;32mIptables rules applied successfully with the following settings:\033[0m"
echo "Middle IP: $middle_ip"
echo "Destination IP: $destination_ip"
echo "Port: $port"



# sudo wget https://raw.githubusercontent.com/arkh91/public_script_files/refs/heads/main/redirection.sh && chmod u+x redirection.sh && ./redirection.sh
# bash <(curl -Ls https://raw.githubusercontent.com/arkh91/public_script_files/refs/heads/main/redirection.sh)
# bash <(curl -Ls https://bit.ly/arkh91_VPN)
