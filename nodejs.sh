#!/bin/bash

#######################################
#                                     #
#  This code has been written by:     #
#  https://github.com/arkh91/         #                        
#                                     #
#######################################


# Check if Node.js and npm are installed and if they are the latest versions
if command -v node &> /dev/null && command -v npm &> /dev/null; then
    installed_node_version=$(node --version)
    installed_npm_version=$(npm --version)
    latest_node_version=$(curl -sL https://nodejs.org/dist/latest/ | grep -o -m 1 ">node-v.*-linux-x64.tar.gz<" | sed 's/[<>"]//g' | awk -F '[-/]' '{print $2}')
    latest_npm_version=$(npm view npm version)

    echo "Installed Node.js version: $installed_node_version"
    echo "Latest Node.js version: $latest_node_version"

    echo "Installed npm version: $installed_npm_version"
    echo "Latest npm version: $latest_npm_version"

    # Check if Node.js and npm are the latest versions
    if [ "$installed_node_version" = "$latest_node_version" ] && [ "$installed_npm_version" = "$latest_npm_version" ]; then
        echo "Node.js and npm are already the latest versions. Skipping installation."
    else
        # Install Node.js using NVM
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash
        source ~/.bashrc
        nvm install --lts
        nvm alias default lts
        #echo -e "\033[32mpython3.8.\033[m"
        echo -e "\033[32mAll installed\033[m"
        
        # Verify NVM and Node.js installation
        nvm --version
        node --version
        npm --version

        # Install Node.js using APT
        sudo apt update -y
        sudo apt install -y nodejs npm
        echo -e "\033[32msnodejs installed.\033[m"

        
        # Verify APT installation
        node --version
        npm --version
    fi
else
    # Install Node.js and npm if they are not installed
    echo "Node.js and npm are not installed. Installing..."
    # Install Node.js using NVM
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash
    source ~/.bashrc
    nvm install --lts
    nvm alias default lts

    # Verify NVM and Node.js installation
    nvm --version
    node --version
    npm --version
    echo -e "\033[36mReady!\033[m"
    
    # Install Node.js using APT
    sudo apt update -y
    echo -e "\033[32mSystem updated.\033[m"
    sudo apt install -y nodejs npm

    # Verify APT installation
    node --version
    npm --version
fi

read -p "Press enter to continue"




#sudo wget https://raw.githubusercontent.com/arkh91/public_script_files/main/nodejs.sh && chmod u+x nodejs.sh && ./nodejs.sh
#
