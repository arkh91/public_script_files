#!/bin/bash

# Enhanced ocserv setup script
# Supports re-use: adds users if already installed

set -e

CONFIG_FILE="/etc/ocserv/ocserv.conf"
PASSWD_FILE="/etc/ocserv/ocpasswd"
CERT_DIR="/etc/ssl/private"
CERT_DAYS=365
DOMAIN_DEFAULT="vpn.example.com"

# Function to create VPN user
create_user() {
    echo "🔐 Enter new VPN username:"
    read -rp "Username: " USERNAME

    while true; do
        read -rsp "Password: " PASSWORD
        echo
        read -rsp "Confirm Password: " PASSWORD2
        echo
        [[ "$PASSWORD" == "$PASSWORD2" ]] && break
        echo "❌ Passwords do not match. Try again."
    done

    echo "$USERNAME:$PASSWORD" | sudo ocpasswd -c "$PASSWD_FILE" "$USERNAME"
    echo "✅ User '$USERNAME' created successfully."
}

# Check if ocserv is already installed
if command -v ocserv >/dev/null 2>&1; then
    echo "✅ ocserv is already installed."

    if [[ -f "$PASSWD_FILE" ]]; then
        echo "👉 Do you want to add a new VPN user? (y/n)"
        read -r choice
        if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
            create_user
        fi
    else
        echo "⚠️ Password file not found. Skipping user creation."
    fi

    exit 0
fi

# ocserv is not installed - install and configure
echo "🚀 Installing ocserv and dependencies..."
sudo apt update && sudo apt install -y ocserv iptables-persistent

# Ask for domain or IP
read -rp "Enter your VPN domain or IP [default: $DOMAIN_DEFAULT]: " VPN_DOMAIN
VPN_DOMAIN="${VPN_DOMAIN:-$DOMAIN_DEFAULT}"

# Generate self-signed cert
echo "📜 Generating self-signed TLS certificate..."
mkdir -p "$CERT_DIR"
openssl req -x509 -newkey rsa:4096 -keyout "$CERT_DIR/server.key" -out "$CERT_DIR/server.crt" -days "$CERT_DAYS" -nodes -subj "/CN=$VPN_DOMAIN"

cp "$CERT_DIR/server.crt" /etc/ssl/certs/
cp "$CERT_DIR/server.key" /etc/ssl/private/

# Configure ocserv
echo "⚙️ Writing ocserv configuration..."
cat > "$CONFIG_FILE" <<EOF
auth = "plain[$PASSWD_FILE]"
tcp-port = 443
udp-port = 443
server-cert = /etc/ssl/certs/server.crt
server-key = /etc/ssl/private/server.key
default-domain = $VPN_DOMAIN
ipv4-network = 192.168.128.0
ipv4-netmask = 255.255.255.0
dns = 8.8.8.8
dns = 1.1.1.1
max-clients = 128
max-same-clients = 4
keepalive = 32400
try-mtu-discovery = true
compression = true
no-route = 10.0.0.0/8
no-route = 192.168.0.0/16
no-route = 172.16.0.0/12
EOF

# Enable IP forwarding
echo "🔄 Enabling IP forwarding..."
echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf
sysctl -p

# Setup NAT
echo "🛡️ Configuring NAT firewall rules..."
iptables -t nat -A POSTROUTING -j MASQUERADE
iptables-save > /etc/iptables/rules.v4

# Create user
echo "👤 Creating initial VPN user:"
create_user

# Start and enable service
echo "🚀 Starting ocserv service..."
systemctl enable ocserv
systemctl restart ocserv

echo
echo "🎉 AnyConnect-compatible VPN setup complete!"
echo "➡ Server: $VPN_DOMAIN"
