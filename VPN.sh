#!/bin/bash

#######################################
#                                     #
#  This code has been written by:     #
#  https://github.com/arkh91/         #                        
#                                     #
#######################################

if [ "$EUID" -ne 0 ]; then
  echo -e "\033[31mPlease run as root\033[m"
  exit
fi



# Outline VPN setup
outline_vpn() {
    # Check if outline is installed
    if ! command -v outline-ss-server &> /dev/null; then
        echo "Outline is not installed. Installing..."
        
        # Install outline
        #sudo bash -c "$(wget -qO- https://raw.githubusercontent.com/Jigsaw-Code/outline-server/master/src/server_manager/install_scripts/install_server.sh)" install_server.sh --api-port=11111 --keys-port=11000
        sudo bash -c "$(wget -qO- https://raw.githubusercontent.com/arkh91/outline-server/refs/heads/master/src/server_manager/install_scripts/install_server.sh)" install_server.sh --api-port=11111
        echo "Outline installed successfully."
        echo
    else
        echo "Outline is already installed."
        read -p "Would you like to reinstall it? (y/n): " outline
        if [[ "$outline" == "y" || "$outline" == "Y" ]]; then
            echo "Reinstalling Outline..."
            # Reinstall outline
            sudo bash -c "$(wget -qO- https://raw.githubusercontent.com/Jigsaw-Code/outline-server/master/src/server_manager/install_scripts/install_server.sh)" install_server.sh --api-port=11111
            echo "Outline reinstalled successfully."
        else
            echo "Skipping reinstallation."
        fi
    fi
}


# Install x-ui Sanaei
x-ui_Sanaei() {
  if [ -d "/etc/3x-ui" ]; then
    echo "x-ui MHSanaei installed successfully."
  else
    echo "x-ui MHSanaei installation not found."
    bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
    docker restart shadowbox
  fi
}

x-ui_English() {
  if [ -d "/etc/3x-ui" ]; then
    echo "x-ui MHSanaei installed successfully."
  else
    echo "x-ui MHSanaei installation not found."
    bash <(curl -Ls https://raw.githubusercontent.com/NidukaAkalanka/x-ui-english/master/install.sh)
    docker restart shadowbox
  fi
}

VPN_dependencies()  {
 # Check if netstat is installed
  if ! command -v netstat &> /dev/null; then
    echo "netstat is not installed. Installing..."
    sudo apt update -y
    #sudo apt install docker-ce -y
    sudo apt install net-tools -y
  fi

  echo -e "\033[32mAdding iran-firewall-range2\033[m"
  # Check if the file "iran-firewall-range2.txt" is present
  if [ -e "iran-firewall-range2.txt" ]; then
    # Perform actions if the file is present
    echo "The file 'iran-firewall-range2.txt' is present. Removing ..."
    rm iran-firewall-range2.txt
  else
    echo "The file 'iran-firewall-range2.txt' is being redownloaded ..."
    sudo wget https://raw.githubusercontent.com/arkh91/public_script_files/main/firewall/iran-firewall-range2.txt
  fi

  echo -e "\033[32mAdding Port\033[m"
  if [ ! -e "port.sh" ]; then
    sudo wget https://raw.githubusercontent.com/arkh91/public_script_files/main/port.sh && chmod a+x port.sh
  fi

  echo -e "\033[32mAdding Restrict_IP_range\033[m"
  if [ ! -e "Restrict_IP_range.sh" ]; then
    sudo wget https://raw.githubusercontent.com/arkh91/public_script_files/main/firewall/Restrict_IP_range.sh && chmod a+x Restrict_IP_range.sh
    sleep 5s
  fi

  echo -e "\033[32mAdding PortRange\033[m"
  if [ ! -e "PortRange.sh" ]; then
    echo "The file 'PortRange.sh' is not present."
    sudo wget https://raw.githubusercontent.com/arkh91/public_script_files/main/PortRange.sh && chmod a+x PortRange.sh
    sleep 5s
  fi
  
  echo -e "\033[32mAdding Nginx Install file\033[m"
  if [ ! -e "install_webmin_nginx.sh" ]; then
    echo "The file 'install_webmin_nginx.sh' is not present."
    sudo wget https://raw.githubusercontent.com/arkh91/public_script_files/refs/heads/main/install_webmin_nginx.sh && chmod +x install_webmin_nginx.sh
    ./install_webmin_nginx.sh
    sleep 5s
  fi

  

  # Auto restart
  if [ ! -e "autoreboot" ]; then
    echo "The file 'autoreboot' is not present."
    sudo wget https://raw.githubusercontent.com/arkh91/public_script_files/main/autoreboot && cat autoreboot >> /etc/crontab
    sleep 5s
  fi

  # Auto .bashrc to block Iran IP's
  if [ ! -e "bashrc_bock.txt" ]; then
    echo "The file 'bashrc_bock.txt' is not present."
    #sudo wget https://raw.githubusercontent.com/arkh91/public_script_files/main/firewall/bashrc_block.txt && cat bashrc_block.txt >> /home/ubuntu/.bashrc
  fi
}

Install_python (){
  #sudo wget https://raw.githubusercontent.com/arkh91/public_script_files/main/python.sh && chmod u+x python.sh && ./python.sh
  bash <(curl -Ls https://raw.githubusercontent.com/arkh91/public_script_files/main/python.sh)
}


Install_NodeJS (){
  #sudo wget https://raw.githubusercontent.com/arkh91/public_script_files/main/nodejs.sh && chmod u+x nodejs.sh && ./nodejs.sh
  bash <(curl -Ls https://raw.githubusercontent.com/arkh91/public_script_files/main/nodejs.sh)

}

#7
New_sudo_user(){
  bash <(curl -Ls https://raw.githubusercontent.com/arkh91/public_script_files/refs/heads/main/New_sudo_user.sh)
}

# Function to display the current date and time
show_datetime() {
    echo "Current date and time: $(date)"
}


# Function to display the menu
show_menu() {
    echo "*************************************"
    echo "*************************************"
    echo "**Please choose an option:        ***"
    echo "**1. Outline VPN                  ***"    
    echo "**2. x-ui_Sanaei VPN              ***"
    echo "**3. x-ui_English VPN             ***"
    echo "**4. VPN dependencies             ***"
    echo "**5. Install Python               ***"
    echo "**6. Install NodeJS               ***"
    echo "**7. New sudo user                ***"
    echo "**8. Exit                         ***"
    echo "*************************************"
    echo "*************************************"
    echo
}

# Main function to handle user input and call the appropriate function
main() {
    while true; do
        show_menu
        read -p "Enter your choice (1-8): " choice

        case $choice in
            1)
                outline_vpn
                ;;
            2)
                x-ui_Sanaei
                ;;
            3)
                x-ui_English
                ;;

            4)
                VPN_dependencies
                ;;
            5)
                Install_python
                ;;
            6)
                Install_NodeJS
                ;;
            7)
                New_sudo_user
                ;;
            8)
                echo
                echo "Exiting... Goodbye!"
                break
                ;;
            *)
                echo "Invalid option. Please enter a number between 1 and 7."
                ;;
        esac
    done
}

# Execute the main function
main


# sudo wget https://raw.githubusercontent.com/arkh91/public_script_files/main/VPN.sh && chmod u+x VPN.sh #&& ./VPN.sh
# bash <(curl -Ls https://raw.githubusercontent.com/arkh91/public_script_files/main/VPN.sh)
