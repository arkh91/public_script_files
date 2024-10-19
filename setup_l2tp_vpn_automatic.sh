#!/bin/bash

# Function to generate a random string for username, password, and PSK
generate_random_string() {
    local length=$1
    tr -dc 'a-zA-Z0-9' </dev/urandom | head -c $length
}

# Function to get the public IP address
get_public_ip() {
    curl -s http://checkip.amazonaws.com
}

# Allow the script to be rerun and reconfigure the VPN
FORCE_SETUP=false

# Check if the argument "--force" is passed to force setup
if [[ "$1" == "--force" ]]; then
    FORCE_SETUP=true
fi

# Check if strongSwan and xl2tpd are already installed
if dpkg -l | grep -q strongswan && dpkg -l | grep -q xl2tpd; then
    if [ "$FORCE_SETUP" = false ]; then
        echo "L2TP/IPsec VPN is already installed."
        exit 0
    else
        echo "Forcing VPN reconfiguration..."
    fi
else
    echo "Installing necessary packages..."
    sudo apt-get update -y
    sudo apt-get install strongswan strongswan-pki xl2tpd ppp lsof ufw curl -y
fi

# Verify that strongSwan was installed properly
if ! dpkg -l | grep -q strongswan; then
    echo "strongSwan package is missing. Reinstalling strongSwan..."
    sudo apt-get install --reinstall strongswan -y
fi

# Generate random VPN credentials
VPN_IPSEC_PSK=$(generate_random_string 16)
VPN_USER=$(generate_random_string 8)
VPN_PASSWORD=$(generate_random_string 12)
VPN_NETWORK='192.168.42.0/24'

# Automatically get the public IP address
PUBLIC_IP=$(get_public_ip)

# Check if public IP was successfully retrieved
if [[ -z "$PUBLIC_IP" ]]; then
    echo "Failed to retrieve the public IP address. Please check network connectivity."
    exit 1
fi

# Configure IPsec
echo "Configuring IPsec..."
cat <<EOF | sudo tee /etc/ipsec.conf
config setup
    charondebug="ike 2, knl 2, cfg 2"
    uniqueids=no

conn %default
    keyexchange=ikev1
    authby=secret
    ike=aes128-sha1-modp1024!
    esp=aes128-sha1!
    keyingtries=1
    ikelifetime=24h
    lifetime=24h
    rekey=no
    keyexchange=ikev1

conn L2TP-PSK
    keyexchange=ikev1
    authby=secret
    ike=aes128-sha1-modp1024!
    esp=aes128-sha1!
    dpdaction=clear
    dpddelay=35s
    dpdtimeout=200s
    rekey=no
    left=$PUBLIC_IP
    leftprotoport=17/1701
    right=%any
    rightprotoport=17/%any
    auto=add
EOF

# Configure IPsec secrets
echo "Configuring IPsec secrets..."
cat <<EOF | sudo tee /etc/ipsec.secrets
$PUBLIC_IP : PSK "$VPN_IPSEC_PSK"
EOF

# Configure xl2tpd
echo "Configuring xl2tpd..."
cat <<EOF | sudo tee /etc/xl2tpd/xl2tpd.conf
[global]
ipsec saref = yes
listen-addr = $PUBLIC_IP

[lns default]
ip range = 192.168.42.10-192.168.42.100
local ip = 192.168.42.1
require chap = yes
refuse pap = yes
require authentication = yes
ppp debug = yes
pppoptfile = /etc/ppp/options.xl2tpd
length bit = yes
EOF

# Configure PPP options for xl2tpd
echo "Configuring PPP options..."
cat <<EOF | sudo tee /etc/ppp/options.xl2tpd
require-mschap-v2
ms-dns 8.8.8.8
ms-dns 8.8.4.4
asyncmap 0
auth
crtscts
lock
hide-password
modem
debug
name l2tpd
proxyarp
lcp-echo-interval 30
lcp-echo-failure 4
EOF

# Set VPN username and password
echo "Setting up VPN credentials..."
cat <<EOF | sudo tee /etc/ppp/chap-secrets
# Secrets for authentication using CHAP
# client    server      secret      IP addresses
$VPN_USER  l2tpd   $VPN_PASSWORD   *
EOF

# Enable packet forwarding
echo "Enabling IP forwarding..."
sudo sysctl -w net.ipv4.ip_forward=1
sudo sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf

# Configure UFW firewall
echo "Configuring firewall rules..."
sudo ufw allow OpenSSH
sudo ufw allow 500,4500/udp
sudo ufw allow 1701/udp

echo "Enabling UFW firewall..."
sudo ufw --force enable

# Restart services and check for correct service name
echo "Restarting IPsec and xl2tpd services..."
if sudo systemctl restart strongswan; then
    echo "strongSwan service restarted successfully."
else
    echo "strongSwan service not found, trying strongswan-starter..."
    if sudo systemctl restart strongswan-starter; then
        echo "strongSwan-starter service restarted successfully."
    else
        echo "Failed to restart any strongSwan services. Please check logs."
        journalctl -xe | grep strongswan
    fi
fi

sudo systemctl restart xl2tpd

# Output VPN connection details
echo "VPN setup is complete!"
echo "Use the following details to connect:"
echo "Public IP: $PUBLIC_IP"
echo "IPsec PSK: $VPN_IPSEC_PSK"
echo "Username: $VPN_USER"
echo "Password: $VPN_PASSWORD"




#sudo wget https://raw.githubusercontent.com/arkh91/public_script_files/refs/heads/main/setup_l2tp_vpn_automatic.sh && chmod +x setup_l2tp_vpn_automatic.sh
