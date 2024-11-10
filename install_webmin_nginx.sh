#!/bin/bash

#######################################
#                                     #
#  This code has been written by:     #
#  https://github.com/arkh91/         #                        
#                                     #
#######################################

# Step 1: Fix any broken dependencies
echo "Fixing broken dependencies..."
sudo apt --fix-broken install -y

# Step 2: Install required dependencies
echo "Installing required dependencies for Webmin..."
sudo apt-get install -y libnet-ssleay-perl libauthen-pam-perl libio-pty-perl unzip

# Step 3: Download Webmin (replace version number with the latest if needed)
: << 'step3'
# https://sourceforge.net/projects/webadmin/files/webmin/
WEBMIN_VERSION="2.202"
echo "Downloading Webmin version $WEBMIN_VERSION..."
wget http://prdownloads.sourceforge.net/webadmin/webmin_${WEBMIN_VERSION}_all.deb
step3
# Fetch the latest release information from GitHub's API
latest_release=$(curl -s https://api.github.com/repos/webmin/webmin/releases/latest)

# Extract the tag name, which corresponds to the version number
WEBMIN_VERSION=$(echo $latest_release | grep -oP '"tag_name": "\K(.*?)(?=")')

# Check if version number was successfully fetched
if [ -z "$WEBMIN_VERSION" ]; then
    echo "Error: Unable to retrieve the latest Webmin version."
    exit 1
fi
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

echo -e "\e[32mWebmin installation complete.\e[0m"
echo -e "\e[32mYou can access Webmin via https://<your-server-ip>:10000\e[0m"

# Step 8: Removing the file
sudo rm webmin_${WEBMIN_VERSION}_all.deb

#wget https://raw.githubusercontent.com/arkh91/public_script_files/refs/heads/main/install_webmin_nginx.sh && chmod +x install_webmin_nginx.sh
