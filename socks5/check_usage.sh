#!/bin/bash

# Maximum GB limit per user (change as needed)
MAX_GB=10  # 10 GB per user

# Directory to store user usage
USAGE_DIR="/var/log/shadowsocks_usage"
mkdir -p "$USAGE_DIR"

# Function to convert bytes to GB
bytes_to_gb() {
    echo "scale=2; $1 / 1073741824" | bc
}

# Function to check if the user has exceeded their limit
check_usage() {
    USER=$1
    USED_BYTES=$(iptables -nvxL | grep "$USER" | awk '{print $2}')
    if [ -z "$USED_BYTES" ]; then
        USED_BYTES=0
    fi
    USED_GB=$(bytes_to_gb "$USED_BYTES")
    if (( $(echo "$USED_GB >= $MAX_GB" | bc -l) )); then
        echo "User $USER has exceeded their $MAX_GB GB limit with $USED_GB GB used."
        return 1
    else
        echo "User $USER has used $USED_GB GB out of $MAX_GB GB."
        return 0
    fi
}

# Function to initialize traffic monitoring for a user
setup_traffic_monitoring() {
    USER=$1
    USER_IP=$2

    # Add iptables rule to track the traffic of the user based on IP address
    iptables -A INPUT -s "$USER_IP" -j ACCEPT
    iptables -A OUTPUT -d "$USER_IP" -j ACCEPT

    # Create a log file for the user's usage
    if [ ! -f "$USAGE_DIR/$USER" ]; then
        echo "0" > "$USAGE_DIR/$USER"
    fi
}

# Function to stop traffic monitoring and remove iptables rules
stop_traffic_monitoring() {
    USER=$1
    USER_IP=$2

    # Remove iptables rules for the user's IP address
    iptables -D INPUT -s "$USER_IP" -j ACCEPT
    iptables -D OUTPUT -d "$USER_IP" -j ACCEPT
}

# Install Shadowsocks if not already installed
sudo apt update
sudo apt install -y shadowsocks-libev jq iptables bc

# Get the server's public IP address
PUBLIC_IP=$(curl -s http://checkip.amazonaws.com)

# Generate a random password
PASSWORD=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 16)

# Set the port to 20000
SERVER_PORT=20000

# Configure Shadowsocks config file
CONFIG_FILE="/etc/shadowsocks-libev/config.json"

sudo bash -c "cat > $CONFIG_FILE" << EOL
{
    "server": "$PUBLIC_IP",
    "server_port": $SERVER_PORT,
    "password": "$PASSWORD",
    "method": "aes-256-gcm",
    "timeout": 300,
    "mode": "tcp_and_udp"
}
EOL

# Restart the Shadowsocks service
sudo systemctl restart shadowsocks-libev
sudo systemctl enable shadowsocks-libev

# Generate a unique user link for the Telegram SOCKS5 Proxy
DATE=$(date +"%m%d%Y-%H%M%S")
USER_LINK="tg://socks?server=$PUBLIC_IP&port=$SERVER_PORT&user=$DATE&pass=$PASSWORD"

# Ask the user for the IP address of the user being added
read -p "Enter the user's IP address to track usage: " USER_IP

# Set up traffic monitoring for the user
setup_traffic_monitoring "$DATE" "$USER_IP"

# Check if the user has exceeded their GB limit
if check_usage "$DATE"; then
    echo "User $DATE is within their data usage limit."
    echo "Unique User Telegram Proxy Link: $USER_LINK"
else
    echo "User $DATE has exceeded their data usage limit."
    stop_traffic_monitoring "$DATE" "$USER_IP"
fi
