#!/bin/bash
#######################################
#				                              #
#  This code has been written by:     #
#  https://github.com/arkh91/	        #			
#				                              #
#######################################
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
else
  docker rm -f shadowbox watchtower
  echo -e "\033[36mShadowbox removed\033[m" 
  docker system prune -a

  rm -r /opt/outline
  echo -e "\033[36mOutline Successfully removed!\033[m" 


  sudo bash -c "$(wget -qO- https://raw.githubusercontent.com/Jigsaw-Code/outline-server/master/src/server_manager/install_scripts/install_server.sh)" install_server.sh --api-port=70 --keys-port=8880
fi

#sudo wget https://raw.githubusercontent.com/arkh91/public_script_files/main/newubuntu.sh && chmod u+x outline_reinstaller.sh && ./outline_reinstaller.sh
