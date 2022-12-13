#!/bin/bash

#https://docs.python-guide.org/starting/install3/linux/
sudo apt update
echo -e "\033[32mSystem updated.\033[m"

sudo apt install software-properties-common
echo -e "\033[32msoftware-properties-common installed.\033[m"

sudo add-apt-repository ppa:deadsnakes/ppa

sudo apt-get install python3.8
echo -e "\033[32mpython3.8.\033[m"

echo -e "\033[36mPython is ready!\033[m"

python3 --version
read -p "Press enter to continue"

#sudo wget https://raw.githubusercontent.com/arkh91/public_script_files/main/python.sh && chmod u+x python.sh && ./python.sh
