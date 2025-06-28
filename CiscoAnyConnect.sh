#!/bin/bash

# CiscoAnyConnect.sh
# Installs or manages an OpenConnect-compatible VPN (ocserv) on Ubuntu
# Supports: install, add user, uninstall, help

set -e

CONFIG_FILE="/etc/ocserv/ocserv.conf"
PASSWD_FILE="/etc/ocserv/ocpasswd"
CERT_DIR="/etc/ssl/private"
DOMAIN_DEFAULT="vpn.example.com"
CERT_DAYS=365

# Colors
GREEN="\e[32m"
RED="\e[31m"
NC="\e[0m"

# --- HELP OPTION ---
if [[ "$1" == "-help" || "$1" == "--help" ]]; then
    echo -e "${GREEN}CiscoAnyConnect.sh - OpenConnect VPN Manager${NC}"
    echo -e "\nUsage:"
    echo -e "  ./CiscoAnyConnect.sh              Install or add VPN user"
    echo -e "  ./CiscoAnyConnect.sh -uninstall   Uninstall ocserv and remove all configs"
    echo -e "  ./CiscoAnyConnect.sh -help        Show this help message"
    exit 0
fi

# --- UNINSTALL OPTION ---
if [[ "$1" == "-uninstall" ]]; then
    echo -e "${RED}⚠️ Uninstalling ocserv and cleaning up...${NC}"
    
    systemctl stop ocserv || true
    systemctl disable ocserv || true
    apt remove --purge -y ocserv iptables-persistent
    rm -f "$CONFIG_FILE" "$PASSWD_FILE"
    rm -f /etc/ssl/certs/server.crt /etc/ssl/private/server.key
    rm -rf /etc/ocserv
    iptables -t nat -F
    iptables-save > /etc/iptables/rules.v4
    
    echo -e "${GREEN}✅ ocserv has been fully uninstalled.${NC}"
    exit 0
fi

# --- CREATE USER FUNCTION ---
create_user() {
    echo -e "\n🔐 Enter new VPN username:"
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
    echo -e "${GREEN}✅ User '$USERNAME' created successfully.${NC}"
}

# --- IF INSTALLED ---
if command -v ocserv >/dev/null 2>&1; then
    echo -e "${GREEN}✔ ocserv is already installed.${NC}"

    echo "👉 Do you want to add a new VPN user? (y/n)"
    read -r choice
    if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
        create_user
    fi

    exit 0
fi

# --- INSTALLATION ---
echo -e "${GREEN}🚀 Installing ocserv VPN...${NC}"
apt update && apt install -y ocserv iptables-persistent

# Ask for domain or IP
read -rp "Enter your VPN domain or public IP [default: $DOMAIN_DEFAULT]: " VPN_DOMAIN
VPN_DOMAIN="${VPN_DOMAIN:-$DOMAIN_DEFAULT}"

# Generate self-signed cert
echo "📜 Generating TLS certificate..."
mkdir -p "$CERT_DIR"
openssl req -x509 -newkey rsa:4096 -keyout "$CERT_DIR/server.key" -out "$CERT_DIR/server.crt" -days "$CERT_DAYS" -nodes -subj "/CN=$VPN_DOMAIN"

cp "$CERT_DIR/server.crt" /etc/ssl/certs/
cp "$CERT_DIR/server.key" /etc/ssl/private/

# Write config
echo "⚙️ Writing ocserv config..."
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

# Enable forwarding
echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf
sysctl -p

# Setup firewall
iptables -t nat -A POSTROUTING -j MASQUERADE
iptables-save > /etc/iptables/rules.v4

# Create first user
echo "👤 Let's create your first VPN user:"
create_user

# Start and enable
systemctl enable ocserv
systemctl restart ocserv

echo
echo -e "${GREEN}🎉 VPN server installed successfully!${NC}"
echo "➡ Server: $VPN_DOMAIN (port 443)"
