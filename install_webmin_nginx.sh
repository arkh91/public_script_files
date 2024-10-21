#!/bin/bash

# Step 1: Fix any broken dependencies
echo "Fixing broken dependencies..."
sudo apt --fix-broken install -y

# Step 2: Install required dependencies
echo "Installing required dependencies for Webmin..."
sudo apt-get install -y libnet-ssleay-perl libauthen-pam-perl libio-pty-perl unzip

# Step 3: Download Webmin (replace version number with the latest if needed)
WEBMIN_VERSION="2.100"
echo "Downloading Webmin version $WEBMIN_VERSION..."
wget http://prdownloads.sourceforge.net/webadmin/webmin_${WEBMIN_VERSION}_all.deb

# Step 4: Install Webmin
echo "Installing Webmin..."
sudo dpkg -i webmin_${WEBMIN_VERSION}_all.deb

# Step 5: Fix any remaining dependencies
echo "Fixing remaining dependencies..."
sudo apt-get install -f -y

# Step 6: Start Webmin
echo "Starting Webmin..."
sudo systemctl start webmin

# Step 7: Enable Webmin on boot
echo "Enabling Webmin on boot..."
sudo systemctl enable webmin

echo "Webmin installation complete. You can access Webmin via https://<your-server-ip>:10000"

#
