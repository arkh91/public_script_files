#!/bin/bash

# Variables
DOMAIN="shahrivargan.info"
ZONE_FILE="/etc/bind/zones/db.$DOMAIN"

# Get the server's IP address (you might need to adjust this command depending on your network setup)
IP_ADDRESS=$(hostname -I | awk '{print $1}')

# Extract the first three octets and reverse them
REVERSE_IP=$(echo $IP_ADDRESS | awk -F. '{print $3"."$2"."$1}')

REV_ZONE_FILE="/etc/bind/zones/db.$REVERSE_IP"
REVERSE_IP_PTR=$(echo $IP_ADDRESS | awk -F. '{print $4}')

# Update system
apt update && apt upgrade -y

# Install BIND
apt install bind9 bind9utils bind9-doc -y

# Create zone directory
mkdir -p /etc/bind/zones

# Configure named.conf.local
cat <<EOL >> /etc/bind/named.conf.local

zone "$DOMAIN" {
    type master;
    file "$ZONE_FILE";
};

zone "$REVERSE_IP.in-addr.arpa" {
    type master;
    file "$REV_ZONE_FILE";
};
EOL

# Create forward zone file
cat <<EOL > $ZONE_FILE
\$TTL    604800
@       IN      SOA     ns1.$DOMAIN. admin.$DOMAIN. (
                              2         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS      ns1.$DOMAIN.
@       IN      A       $IP_ADDRESS
ns1     IN      A       $IP_ADDRESS
www     IN      A       $IP_ADDRESS
EOL

# Create reverse zone file
cat <<EOL > $REV_ZONE_FILE
\$TTL    604800
@       IN      SOA     ns1.$DOMAIN. admin.$DOMAIN. (
                              2         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS      ns1.$DOMAIN.
$REVERSE_IP_PTR    IN      PTR     $DOMAIN.
EOL

# Check BIND configuration
named-checkconf

# Check zone files
named-checkzone $DOMAIN $ZONE_FILE
named-checkzone $REVERSE_IP.in-addr.arpa $REV_ZONE_FILE

# Restart BIND service
systemctl restart bind9

# Enable the underlying BIND service to start on boot
systemctl enable named.service
echo "DNS server setup complete. Make sure to update your domain registrar with the new nameserver information."



#sudo wget https://raw.githubusercontent.com/arkh91/public_script_files/main/DNS/setup-dns-server.sh && chmod u+x setup-dns-server.sh
