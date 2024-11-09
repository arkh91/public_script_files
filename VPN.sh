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

alias_vpn() {
  echo "alias"
#: << 'alias'
  # Define the alias line to check
  alias_line="alias VPN='bash <(curl -Ls https://raw.githubusercontent.com/arkh91/public_script_files/main/VPN.sh)'"
  
  # Check if the alias already exists in .bashrc
  if ! grep -Fxq "$alias_line" ~/.bashrc; then
      # If alias doesn't exist, add it to the end of .bashrc
      echo "$alias_line" >> ~/.bashrc
      echo "Alias added to .bashrc."
      
      # Verify if the alias was successfully added
      if grep -Fxq "$alias_line" ~/.bashrc; then
          echo "Alias successfully added to .bashrc."
      else
          echo "Failed to add alias to .bashrc. Please check file permissions."
      fi
      
      # Source the .bashrc to apply the changes
      source ~/.bashrc
      echo ".bashrc sourced to apply changes."
  else
      echo "Alias already exists in .bashrc."
  fi
#alias  
}

# Install x-ui Sanaei
x-ui_Sanaei() {
  if [ -d "/etc/3x-ui" ]; then
    echo "x-ui MHSanaei installed successfully."
  else
    echo "x-ui MHSanaei installation not found."
    bash <(curl -Ls https://raw.githubusercontent.com/arkh91/3x-ui-sanaei/refs/heads/main/install.sh)
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

    # Check if cron is installed
  if ! dpkg -l | grep -q cron; then
      echo "Cron is not installed. Installing..."
      sudo apt update
      sudo apt install -y cron
      
      # Start and enable the cron service
      echo "Starting and enabling the cron service..."
      sudo systemctl start cron
      sudo systemctl enable cron
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

    rm install_webmin_nginx.sh
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
: << 'echo1'
    echo "@@@%%%%%%%%%%%##########*#*#######%%%##%%%%##%%**#%%##%%@@@"
    echo "@%%%%%%%#####*******+*###***++**###%%%%%%*+**++*#****#%%%%%"
    echo "@%##########%%#*#*+==========+++***###%#+=+*++++++*****#%%%"
    echo "%%##****+***####%%##**+----==+*****#**#######*+++++++**##%%"
    echo "%%%###**++==+*#########*#+==+=+*****==#*#%%%%%#+===++**#%%%"
    echo "@%%%%#**+=====****##%%######*+++*+=*+**#*#%%%%#++++++**#%%%"
    echo "%%%##*****++=--=+++++#%%%%#####**=+*+###*%%%%%**++++*#####%"
    echo "%%%######*#***+====+===*#%%%####*=***#%#%@%%%%*++++#####%%%"
    echo "%%%%#########+==+*###*+==+*#%%##+*##%%%%@@@%%*+++*#########"
    echo "%%%%%#######*++####%%%%%#*+**#**#%%%%%%@@@%#*+++###########"
    echo "######*#**##*+#%%#*#%%%%@@%###%%%%%%%@@@%%**++**###*###%#%%"
    echo "#************+-=+*#%%%@@@@@@%%%%%@@@@%%##****##*#*=*%%%%%%#"
    echo "%#*+++**+++**+--+#%%@@@@@@@@@@@@@@%##*********###+=#@@%####"
    echo "##**+===+++++++==+#%@@@@%%@@@%%%%%%%#*************+*#%%#**#"
    echo "#*+++++=++=--====-=+*##%%%@@%###%%%%@%%##%%#**++++***++#**#"
    echo "#**+++=+====------=***%%##*+===-*%%@%##%%%%%****+++++******"
    echo "*+++===---:::-=**##*++#*--------=+*##*+=+#%%%#*++++++++=+++"
    echo "++====---:::::=#%%%%@%%#**+++====++*#*=---==++#%#=====+++++"
    echo "#*****++++=-===+#%#%%%%%%@@%%%%%%%@@%###***+++*%@%*******##"
    echo "%#########%#####%%%%%%%%%%%%%%%%@@@@@@@@@%%@%%@@@@%%%%%%%%%"
echo1
    echo "***********************************************************"
    echo "***********************************************************"
    echo "** Welcome to the Arkh91 VPN Setup Hub!                  **"
    echo "**                                                       **"
    echo "** 1) Set Up Outline VPN                                 **"    
    echo "** 2) Set Up x-ui_Sanaei VPN                             **"
    echo "** 3) Set Up x-ui_English VPN                            **"
    echo "** 4) Install VPN Dependencies                           **"
    echo "** 5) Install Python                                     **"
    echo "** 6) Install NodeJS                                     **"
    echo "** 7) Create a New Sudo User                             **"
    echo "** 8) SSL setup                                          **"
    echo "** 9) Exit - Done for Now                                **"
    echo "**                                                       **"
    echo "**                                                       **"
    echo "***********************************************************"
    echo "***********************************************************"
    echo
}


# Main function to handle user input and call the appropriate function
main() {
    alias_vpn
    while true; do
        clear
        show_menu
        
        # Add a timeout of 30 seconds to the read command
        read -t 30 -p "Enter your choice (1-9): " choice
        
        # Check if a choice was entered, otherwise display "Still waiting..."
        if [ -z "$choice" ]; then
            echo -e "\nStill waiting for your command..."
            sleep 2  # Give a brief pause to allow the user to see the message
            continue  # Go back to the start of the loop to show the menu again
        fi

        case $choice in
            1)
                outline_vpn_menu
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
                bash <(curl -Ls https://raw.githubusercontent.com/arkh91/public_script_files/refs/heads/main/SSL_setup.sh)
                read -p "Press enter to continue"
                ;;
            9)
                echo
                echo -e "\033[0;35mExiting... Goodbye!\033[0m"
                echo
                exit 1
                ;;
            *)
                echo "Invalid option. Please enter a number between 1 and 9."
                sleep 2  # Give a brief pause before re-displaying the menu
                ;;
        esac
    done
}


# Outline VPN submenu
outline_vpn_menu() {
    while true; do
        clear
        echo "***********************************************************"
        echo "***********************************************************"
        echo "Outline VPN Menu:                                       ***"
        echo "**1) Install Outline VPN                                ***"
        echo "**2) Install Outline VPN with custom port and domain    ***"
        #echo "**3) Check Outline VPN Status                           ***"
        echo "**3) Return to Main Menu                                ***"
        echo "**                                                      ***"
        echo "***********************************************************"
        echo "***********************************************************"
        echo

        read -p "Choose an option: " outline_choice
        case $outline_choice in
            1)
                outline_vpn_install
                ;;
            2)
                outline_vpn_install_portAnddomain
                ;;
            #3)
                #check_outline_status
                #;;
            3)
                main
                ;;
            *)
                echo "Invalid option. Please enter a number between 1 and 4."
                ;;
        esac
    done
}

# Outline VPN setup
outline_vpn_install() {
    # Check if outline is installed
    if [ ! -d "/opt/outline" ]; then
        mkdir -p /opt/outline
        echo "Outline is not installed. Installing..."
        
        # Install outline
        #sudo bash -c "$(wget -qO- https://raw.githubusercontent.com/Jigsaw-Code/outline-server/master/src/server_manager/install_scripts/install_server.sh)" install_server.sh --api-port=11111 --keys-port=11000
        #sudo bash -c "$(wget -qO- https://raw.githubusercontent.com/arkh91/outline-server/refs/heads/master/src/server_manager/install_scripts/install_server.sh)" install_server.sh --api-port=11111
        #worked
        #sudo bash -c "$(wget -qO- https://raw.githubusercontent.com/arkh91/outline-server/refs/heads/master/src/server_manager/install_scripts/install_server.sh)" install_server.sh --api-port=11111 | tee /opt/outline/installed.txt
        filename="/opt/outline/installed.txt"
        counter=1
        
        # Find the next available filename
        while [ -e "$filename" ]; do
          filename="/opt/outline/installed$counter.txt"
          counter=$((counter + 1))
        done

        # Run the command and save output to the available filename
        sudo sh -c 'bash -c "$(wget -qO- https://raw.githubusercontent.com/arkh91/outline-server/refs/heads/master/src/server_manager/install_scripts/install_server.sh)" install_server.sh --api-port=11111 2>&1 | tee '"$filename"
        echo -e "\033[0;35mThe installation output is stored in $filename\033[0m"
        echo "Outline installed successfully."
        echo
        echo "Press Enter to continue..."
        read
        
    else
        echo "Outline is already installed."
        read -p "Would you like to reinstall it? (y/n): " outline
        if [[ "$outline" == "y" || "$outline" == "Y" ]]; then
            echo "Reinstalling Outline..."
            filename="/opt/outline/installed.txt"
        counter=1
        
        # Find the next available filename
        while [ -e "$filename" ]; do
          filename="/opt/outline/installed$counter.txt"
          counter=$((counter + 1))
        done

        # Run the command and save output to the available filename
        sudo sh -c 'bash -c "$(wget -qO- https://raw.githubusercontent.com/arkh91/outline-server/refs/heads/master/src/server_manager/install_scripts/install_server.sh)" install_server.sh --api-port=11111 2>&1 | tee '"$filename"
        echo -e "\033[0;35mThe installation output is stored in $filename\033[0m"
            echo "Outline reinstalled successfully."
        else
            echo "Skipping reinstallation."
        fi
    fi
}

outline_vpn_install_portAnddomain (){
  while true; do
    # Prompt for port number
    read -p "Please enter a port number (between 1024 and 65535): " port
    # Check if port is a valid number within range
    if [[ $port =~ ^[0-9]+$ ]] && ((port >= 1024 && port <= 65535)); then
        echo "Port $port is valid."
    else
        echo "Invalid port. Please enter a number between 1024 and 65535."
        read -p "Do you want to try again? (y/n)" portTry
        if [[ $portTry == "n" ]]; then
            echo "Operation cancelled."
            exit 1
        else
            continue
        fi
    fi

    # Prompt for domain
    read -p "Please enter your domain (e.g., example.com): " domain
    # Simple regex for a valid domain (basic format check)
    if [[ $domain =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        echo "Domain $domain is valid."
    else
        echo "Invalid domain format. Please enter a valid domain (e.g., example.com)."
        read -p "Do you want to try again? (y/n)" domainTry
        if [[ $domainTry == "n" ]]; then
            echo "Operation cancelled."
            exit 1
        else
            continue
        fi
    fi

    # If both port and domain are valid, break out of loop
    echo "Both port and domain are valid. Proceeding..."
    break
  done

  # Run Outline VPN installation command with valid arguments
  sudo bash -c "$(wget -qO- https://raw.githubusercontent.com/arkh91/outline-server/refs/heads/master/src/server_manager/install_scripts/install_server.sh)" install_server.sh --api-port=11111 --keys-port=$port --domain=$domain | tee /opt/outline/installed.txt
}



: << 'check_outline_status'
check_outline_status(){
  echo "Check_Outline_VPN_Status"
  
  # Capture uptime output and display it for debugging
  uptime_output=$(uptime)
  echo "Raw uptime output: $uptime_output"

  # Attempt to extract days; if none, set to 0
  if echo "$uptime_output" | grep -q "days"; then
    uptime_days=$(echo "$uptime_output" | awk '{for(i=1;i<=NF;i++) if ($i ~ /^[0-9]+$/ && $(i+1) == "days") print $i}')
  else
    uptime_days=0
  fi

  echo "Parsed uptime days: $uptime_days"  # Debugging output to verify parsing

  # Determine color based on uptime
  if (( uptime_days < 2 )); then
      color="\033[0;32m" # Green for less than 2 days
  elif (( uptime_days >= 2 && uptime_days <= 4 )); then
      color="\033[0;33m" # Yellow for 2-4 days
  else
      color="\033[0;31m" # Red for more than 4 days
  fi

  # Output uptime with color
  echo -e "${color}Uptime: $uptime_days days\033[0m"

}
check_outline_status







# Execute the main function
main


# sudo wget https://raw.githubusercontent.com/arkh91/public_script_files/main/VPN.sh && chmod u+x VPN.sh && ./VPN.sh
# bash <(curl -Ls https://raw.githubusercontent.com/arkh91/public_script_files/main/VPN.sh)
