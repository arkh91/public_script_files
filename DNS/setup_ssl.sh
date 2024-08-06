#!/bin/bash

# Function to install Apache if it's not already installed
install_apache() {
    if ! command -v apache2 > /dev/null; then
        echo "Apache is not installed. Installing Apache..."
        sudo apt update
        sudo apt install -y apache2
        echo "Apache installed successfully."
    else
        echo "Apache is already installed."
    fi
}

# Function to install Certbot and obtain SSL certificate
install_certbot_and_setup_ssl() {
    # Install Certbot and the Apache plugin
    sudo apt install -y certbot python3-certbot-apache

    # Obtain SSL certificate
    sudo certbot --apache -d shahrivargan.info -d www.shahrivargan.info

    # Set up automatic certificate renewal
    sudo systemctl enable certbot.timer
    sudo systemctl start certbot.timer

    # Test automatic renewal
    sudo certbot renew --dry-run

    echo "SSL setup complete. Your website should now be accessible over HTTPS."
}

# Main script execution
install_apache
install_certbot_and_setup_ssl


