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
else
  #Install python
  sudo wget https://raw.githubusercontent.com/arkh91/public_script_files/main/python.sh && chmod u+x python.sh && ./python.sh

  #Install nodejs
  #sudo wget https://raw.githubusercontent.com/arkh91/public_script_files/main/nodejs.sh && chmod u+x nodejs.sh && ./nodejs.sh


  
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

  # Check if outline is installed
  if ! command -v outline-ss-server &> /dev/null; then
    echo "Outline is not installed. Installing..."
    
    # Install outline
    sudo bash -c "$(wget -qO- https://raw.githubusercontent.com/Jigsaw-Code/outline-server/master/src/server_manager/install_scripts/install_server.sh)" install_server.sh --api-port=11111 --keys-port=11000
    echo "Outline installed successfully."
    sleep 10s
    #read -p "Press enter to continue"
  else
    echo "Outline is already installed."
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
    sudo wget https://raw.githubusercontent.com/arkh91/public_script_files/main/firewall/bashrc_block.txt && cat bashrc_block.txt >> /home/ubuntu/.bashrc
  fi

  # Install x-ui
  if [ -d "/etc/3x-ui" ]; then
    echo "x-ui MHSanaei installed successfully."
  else
    echo "x-ui MHSanaei installation not found."
    bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
  fi
  
  ls
  read -p "Press enter to continue"
fi
# sudo wget https://raw.githubusercontent.com/arkh91/public_script_files/main/VPN.sh && chmod u+x VPN.sh #&& ./VPN.sh
