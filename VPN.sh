#!/bin/bash

#######################################
#                                     #
#  This code has been written by:     #
#  https://github.com/arkh91/         #                        
#                                     #
#######################################

echo -e "\033[32mAdding iran-firewall-range2\033[m"
sudo wget https://raw.githubusercontent.com/arkh91/public_script_files/main/firewall/iran-firewall-range2.txt

echo -e "\033[32mAdding Port\033[m"
sudo wget https://raw.githubusercontent.com/arkh91/public_script_files/main/port.sh && chmod u+x port.sh

echo -e "\033[32mAdding Restrict_IP_range\033[m"
sudo wget https://raw.githubusercontent.com/arkh91/public_script_files/main/firewall/Restrict_IP_range.sh && chmod +x Restrict_IP_range.sh

echo -e "\033[32mAdding PortRange\033[m"
sudo wget https://raw.githubusercontent.com/arkh91/public_script_files/main/PortRange.sh && chmod u+x PortRange.sh

#Install outline
sudo bash -c "$(wget -qO- https://raw.githubusercontent.com/Jigsaw-Code/outline-server/master/src/server_manager/install_scripts/install_server.sh)" install_server.sh --api-port=70 --keys-port=11000

#Auto restart
sudo wget https://raw.githubusercontent.com/arkh91/public_script_files/main/autoreboot && cat autoreboot >> /etc/crontab

read -p "Press enter to continue"

#sudo wget https://raw.githubusercontent.com/arkh91/public_script_files/main/VPN.sh && chmod u+x VPN.sh

