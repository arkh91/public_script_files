#!/bin/bash

# Function to install BIND if it's not already installed
install_bind() {
    if ! command -v named > /dev/null; then
        echo "BIND is not installed. Installing BIND..."
        sudo apt update
        sudo apt install -y bind9 bind9utils bind9-doc
        echo "BIND installed successfully."
    else
        echo "BIND is already installed."
    fi
}

# Function to configure DNSSEC for the domain
configure_dnssec() {
    DOMAIN="shahrivargan.info"
    ZONE_DIR="/etc/bind/zones"
    KEY_DIR="/etc/bind/keys"
    
    sudo mkdir -p $ZONE_DIR
    sudo mkdir -p $KEY_DIR

    # Generate DNSSEC keys
    sudo dnssec-keygen -a RSASHA256 -b 2048 -n ZONE $DOMAIN
    sudo dnssec-keygen -f KSK -a RSASHA256 -b 2048 -n ZONE $DOMAIN

    # Move the keys to the key directory
    sudo mv K$DOMAIN*.key $KEY_DIR/
    sudo mv K$DOMAIN*.private $KEY_DIR/

    # Sign the zone file
    sudo dnssec-signzone -o $DOMAIN -t $ZONE_DIR/db.$DOMAIN

    # Update named.conf.local to include the DNSSEC keys
    echo "
zone \"$DOMAIN\" {
    type master;
    file \"$ZONE_DIR/db.$DOMAIN\";
    allow-transfer { any; };
    inline-signing yes;
    auto-dnssec maintain;
    key-directory \"$KEY_DIR\";
};
" | sudo tee -a /etc/bind/named.conf.local

    # Restart BIND service
    sudo systemctl restart bind9

    echo "DNSSEC configuration complete for $DOMAIN."
}

# Main script execution
install_bind
configure_dnssec

#sudo wget https://raw.githubusercontent.com/arkh91/public_script_files/main/DNS/setup_dnssec.sh && chmod u+x setup_dnssec.sh

#DNSSEC keys: The script generates both a Zone Signing Key (ZSK) and a Key Signing Key (KSK) using RSA-SHA256.
#Zone File: Make sure you have a valid zone file for your domain at /etc/bind/zones/db.shahrivargan.info.
#DNSSEC Signatures: The script uses dnssec-signzone to sign the zone file with the generated keys.
