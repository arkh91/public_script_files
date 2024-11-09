#!/bin/bash

#######################################
#                                     #
#  This code has been written by:     #
#  https://github.com/arkh91/         #                        
#                                     #
#######################################

# Generate SSH key pair
ssh-keygen -t rsa -f ~/.ssh/id_rsa -N ""

# Display fingerprint of the public key
ssh-keygen -lf ~/.ssh/id_rsa.pub

#uncomment the line #PasswordAuthentication yes
sudo sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Restart SSH service
sudo service ssh restart

echo -e "\e[32mSSH key generated, fingerprint displayed, and SSH service restarted.\e[0m"

#bash <(curl -Ls https://raw.githubusercontent.com/arkh91/public_script_files/refs/heads/main/ssh_access.sh)
