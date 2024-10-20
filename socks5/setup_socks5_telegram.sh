#!/bin/bash

# 1. Check if Shadowsocks and jq are installed, then skip the installation if found
if ! command -v ss-server &> /dev/null || ! command -v jq &> /dev/null
then
    echo "Shadowsocks or jq is not installed. Installing now..."
    sudo apt update
    sudo apt install -y shadowsocks-libev jq
else
    echo "Shadowsocks and jq are already installed. Skipping installation."
fi

# 2. Get the server's public IP address
PUBLIC_IP=$(curl -s http://checkip.amazonaws.com)

# 3. Generate a random password
PASSWORD=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 16)

# 4. Set the port to 20000
SERVER_PORT=20000

# 5. Configure Shadowsocks config file
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

# 6. Restart the Shadowsocks service
sudo systemctl restart shadowsocks-libev
sudo systemctl enable shadowsocks-libev

# 7. Generate a unique user link for the Telegram SOCKS5 Proxy
DATE=$(date +"%m%d%Y-%H%M%S")
USER_LINK="tg://socks?server=$PUBLIC_IP&port=$SERVER_PORT&user=$DATE&pass=$PASSWORD"

# 8. Display the result
echo "Shadowsocks SOCKS5 server is set up."
echo "Configuration:"
echo "Server IP: $PUBLIC_IP"
echo "Port: $SERVER_PORT"
echo "Password: $PASSWORD"
echo "Unique User Telegram Proxy Link: $USER_LINK"


#wget https://raw.githubusercontent.com/arkh91/public_script_files/refs/heads/main/socks5/setup_socks5_telegram.sh && chmod +x setup_socks5_telegram.sh
