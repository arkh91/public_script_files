#!/bin/bash
#https://askubuntu.com/questions/859448/is-there-a-command-to-factory-reset-ubuntu

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
else
  sudo dpkg --configure -a
  echo -e "\033[36mUpdate the contents of the repositories\033[m" 

  sudo apt-get update

  echo -e "\033[36mTry to fix missing dependencies:\033[m"

  sudo apt-get -f install

  echo -e "\033[36m  Update all packages with new versions available:\033[m"

  sudo apt-get full-upgrade
  Reinstall Ubuntu desktop:
  echo -e "\033[36mPython is ready!\033[m"

  sudo apt-get install --reinstall ubuntu-desktop

  echo -e "\033[36mRemove unnecessary packages:\033[m"

  sudo apt-get autoremove

  echo -e "\033[36mDelete downloaded packages already installed:\033[m"

  sudo apt-get clean

  echo -e "\033[36mReboot the system to see if the issue was resolved:\033[m"
  read -p "Press enter to reboot your system."
  sudo reboot
fi

#sudo wget https://raw.githubusercontent.com/arkh91/public_script_files/main/newubuntu.sh && chmod u+x newubuntu.sh && ./newubuntu.sh
