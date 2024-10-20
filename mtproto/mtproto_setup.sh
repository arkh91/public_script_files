#!/bin/bash

# Function to install MTProto Proxy and dependencies (runs once)
install_mtproto() {
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

    echo "MTProto Proxy installation completed."
}

# Function to generate new secret key and restart proxy
generate_and_start_proxy() {
    # Generate a new secret key
    echo "Generating secret key..."
    SECRET_KEY=$(head -c 16 /dev/urandom | xxd -ps)

    # Ask for the port number
    read -rp "Enter the port number to run the proxy on (default 8888): " PORT
    PORT=${PORT:-8888}

    # Run the MTProto proxy
    echo "Starting the MTProto Proxy..."
    ./mtproto-proxy -u nobody -p "$PORT" -H 443 -S "$SECRET_KEY" --aes-pwd proxy-secret proxy-multi.conf --http-ports 80 &

    # Get the server IP address
    SERVER_IP=$(curl -s http://checkip.amazonaws.com)

    # Output the proxy link at the end
    PROXY_LINK="tg://proxy?server=$SERVER_IP&port=$PORT&secret=$SECRET_KEY"
    
    echo ""
    echo "=================================================================="
    echo "Your MTProto Proxy is running."
    echo "Proxy link for Telegram: $PROXY_LINK"
    echo "Your generated secret key: $SECRET_KEY"
    echo "=================================================================="
}

# Check if MTProto is already installed
if [ ! -d "MTProxy" ]; then
    echo "MTProto not found, installing..."
    install_mtproto
else
    # If MTProto is already installed, navigate to the directory
    cd MTProxy || exit
    echo "MTProto already installed. Skipping installation."
fi

# Generate and start the proxy, key will be output at the end
generate_and_start_proxy


#wget https://raw.githubusercontent.com/arkh91/public_script_files/refs/heads/main/mtproto/mtproto_setup.sh && chmod +x mtproto_setup.sh

#
