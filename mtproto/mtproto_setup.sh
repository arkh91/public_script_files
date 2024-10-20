#!/bin/bash

# Function to generate and start MTProto proxy
generate_and_start_proxy() {
    # Generate a new secret key
    echo "Generating secret key..."
    SECRET_KEY=$(head -c 16 /dev/urandom | xxd -ps)
    echo "Your new secret key is: $SECRET_KEY"

    # Ask for the port number
    read -rp "Enter the port number to run the proxy on (default 8888): " PORT
    PORT=${PORT:-8888}

    # Run the MTProto proxy
    echo "Starting the MTProto Proxy..."
    ./mtproto-proxy -u nobody -p "$PORT" -H 443 -S "$SECRET_KEY" --aes-pwd proxy-secret proxy-multi.conf --http-ports 80 &

    # Get the server IP address
    SERVER_IP=$(curl -s http://checkip.amazonaws.com)

    # Output the proxy link
    PROXY_LINK="tg://proxy?server=$SERVER_IP&port=$PORT&secret=$SECRET_KEY"
    echo "Your MTProto Proxy is running."
    echo "Proxy link for Telegram: $PROXY_LINK"

    # Option to create systemd service
    read -rp "Do you want to create a systemd service for the proxy? (y/n): " CREATE_SERVICE
    if [[ $CREATE_SERVICE == "y" || $CREATE_SERVICE == "Y" ]]; then
        sudo bash -c "cat > /etc/systemd/system/mtproxy.service" <<EOF
[Unit]
Description=MTProto Proxy for Telegram
After=network.target

[Service]
Type=simple
WorkingDirectory=$(pwd)
ExecStart=$(pwd)/mtproto-proxy -u nobody -p $PORT -H 443 -S $SECRET_KEY --aes-pwd proxy-secret proxy-multi.conf --http-ports 80
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

        # Enable and start the service
        sudo systemctl daemon-reload
        sudo systemctl start mtproxy
        sudo systemctl enable mtproxy

        echo "MTProto Proxy service created and enabled."
    fi

    # Configure the firewall
    echo "Configuring the firewall..."
    sudo ufw allow "$PORT"/tcp
    sudo ufw allow 443/tcp
    sudo ufw reload

    echo "Setup complete!"
}

# Check if MTProto is already installed
if [ ! -d "MTProxy" ]; then
    # Update and upgrade the system
    echo "Updating the system..."
    sudo apt update && sudo apt upgrade -y

    # Install necessary dependencies if not already installed
    echo "Installing dependencies..."
    sudo apt install git build-essential openssl libssl-dev zlib1g-dev -y

    # Clone the MTProto repository
    echo "Cloning MTProto repository..."
    git clone https://github.com/TelegramMessenger/MTProxy.git
    cd MTProxy || exit

    # Build the proxy
    echo "Building MTProto Proxy..."
    make

    # Download proxy secret and config
    echo "Downloading proxy-secret and proxy-multi.conf..."
    curl -s https://core.telegram.org/getProxySecret -o proxy-secret
    curl -s https://core.telegram.org/getProxyConfig -o proxy-multi.conf
else
    # If MTProto is already installed, navigate to the directory
    cd MTProxy || exit
    echo "MTProto already installed. Skipping system update and dependency installation."
fi

# Generate and start the proxy
generate_and_start_proxy
