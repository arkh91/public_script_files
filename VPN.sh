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
  echo "alias_vpn function running..."

  # Define the function directly as a multiline string
  function_definition='VPN() {
    bash <(curl -Ls https://raw.githubusercontent.com/arkh91/public_script_files/main/VPN.sh)
  }'

  # Check if the function definition already exists in .bashrc
  if ! grep -Fxq "$function_definition" ~/.bashrc; then
      # If the function doesn't exist, add it to the end of .bashrc
      echo "$function_definition" >> ~/.bashrc
      echo "Function VPN script added to .bashrc."
      
      # Verify if the function was successfully added
      if grep -Fxq "$function_definition" ~/.bashrc; then
          echo "Function successfully added to .bashrc."
      else
          echo -e "\e[31mFailed to add function to .bashrc. Please check file permissions.\e[0m"
      fi
      
      # Source the .bashrc to apply the changes
      source ~/.bashrc
      echo -e "\e[94m.bashrc sourced to apply changes.\e[0m"
  else
      echo -e "\e[31mFunction run_vpn_script already exists in .bashrc.\e[0m"
  fi  
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

xui() {
    while true; do
        clear
        echo "***********************************************************"
        echo "***********************************************************"
        echo "**   X-UI Installation and Management Script             **"
        echo "**                                                       **"
        echo "**1) x-ui Sanaei VPN                                     **"
        echo "**2) x-ui English VPN                                    **"
        echo "**3) Back                                                **"
        echo "**                                                       **"
        echo "***********************************************************"
        echo "***********************************************************"
        echo

        read -p "Choose an option: " xui_choice
        case $xui_choice in
            1)
                x-ui_English
                read -p "Press enter to continue"
                ;;
            2)
                x-ui_English
                read -p "Press enter to continue"
                ;;
            3)
                main
                ;;
            *)
                echo "Invalid option. Please enter a number between 1 and 3."
                ;;
        esac
    done
}

VPN_dependencies()  {
    sudo apt install -y speedtest-cli
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
    rm autoreboot
  fi

  # Auto .bashrc to block Iran IP's
  if [ ! -e "bashrc_bock.txt" ]; then
    echo "The file 'bashrc_bock.txt' is not present."
    #sudo wget https://raw.githubusercontent.com/arkh91/public_script_files/main/firewall/bashrc_block.txt && cat bashrc_block.txt >> /home/ubuntu/.bashrc
  fi
  
  #ssh remote access
  bash <(curl -Ls https://raw.githubusercontent.com/arkh91/public_script_files/refs/heads/main/ssh_access.sh)
  
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

# Enable BBR
#https://wiki.crowncloud.net/?How_to_enable_BBR_on_Ubuntu_20_04
enable_bbr() {
# Check the kernel version
    kernel_version=$(uname -r | awk -F '.' '{print $1 "." $2}')
    if (( $(echo "$kernel_version < 4.9" | bc -l) )); then
        echo -e "\e[91mKernel version is below 4.9. Please upgrade your kernel to use BBR.\e[0m"
        exit 1        
    elif ! grep -q "net.core.default_qdisc=fq" /etc/sysctl.conf || ! grep -q "net.ipv4.tcp_congestion_control=bbr" /etc/sysctl.conf; then
        echo "Enabling BBR."
        echo "net.core.default_qdisc=fq" | sudo tee -a /etc/sysctl.conf
        echo "net.ipv4.tcp_congestion_control=bbr" | sudo tee -a /etc/sysctl.conf
        sudo sysctl -p
        #echo -e "\nnet.core.default_qdisc=fq\nnet.ipv4.tcp_congestion_control=bbr" | sudo tee -a /etc/sysctl.conf

        # Check the current TCP congestion control setting
        #current_congestion_control=$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')
        #current_congestion_control=$(sysctl -n net.ipv4.tcp_congestion_control)
    fi
    # Verify if it's set to "bbr"
    # Check the current TCP congestion control setting
    current_congestion_control=$(sysctl -n net.ipv4.tcp_congestion_control)
    if [ "$current_congestion_control" = "bbr" ]; then
        echo -e "\e[92mBBR is already enabled.\e[0m"
    else
        echo -e "\e[91mBBR is not enabled. Please try again later.\e[0m"
    fi
}

# Disable BBR
disable_bbr() {
    # Check if BBR settings are present in /etc/sysctl.conf
    if ! grep -q "net.core.default_qdisc=fq" /etc/sysctl.conf || ! grep -q "net.ipv4.tcp_congestion_control=bbr" /etc/sysctl.conf; then
        echo -e "\e[91mBBR not detected.\e[0m"
        exit 1
    else
        echo "Disabling BBR..."
        
        # Temporarily set TCP congestion control to cubic and default qdisc to pfifo_fast
        sudo sysctl -w net.ipv4.tcp_congestion_control=cubic
        sudo sysctl -w net.core.default_qdisc=pfifo_fast

        #echo -e "\e[92mRemoving net.core.default_qdisc=pfifo_fast && net.ipv4.tcp_congestion_control=cubic\e[0m"
        # Remove BBR settings from /etc/sysctl.conf and replace with cubic and pfifo_fast for persistence
        sudo sed -i '/net.core.default_qdisc=fq/d' /etc/sysctl.conf
        sudo sed -i '/net.ipv4.tcp_congestion_control=bbr/d' /etc/sysctl.conf
        
        # net.core.default_qdisc=pfifo_fast && net.ipv4.tcp_congestion_control=cubic
        #echo "net.core.default_qdisc=pfifo_fast" | sudo tee -a /etc/sysctl.conf
        #echo "net.ipv4.tcp_congestion_control=cubic" | sudo tee -a /etc/sysctl.conf
        
        # Reload sysctl settings
        sudo sysctl -p

        echo -e "\e[91mBBR is disabled and cleared.\e[0m"
    fi
}


bbr_menu (){
    while true; do
        clear
        # Menu options
        echo "***********************************************************"
        echo "***********************************************************"
        echo "** BBR Installation and Management Script                **"
        echo "**                                                       **"
        echo "** 1) Enable BBR                                         **"  
        echo "** 2) Disable BBR                                        **"
        echo "** 3) Back                                               **"
        echo "**                                                       **"
        echo "***********************************************************"
        echo "***********************************************************"
        echo
        
        read -p "Choose an option: " bbr_option
        
        case $bbr_option in
            1)
                enable_bbr
                read -p "Press enter to continue"
                ;;
            2)
                disable_bbr
                read -p "Press enter to continue"
                ;;
            3)
                #if curl -s --head --request GET https://bit.ly/arkh91_VPN | grep "200 OK" > /dev/null; then
                    main
                #else
                    #echo -e "\e[91mFailed to access the URL. Please check your internet connection or the URL.\e[0m"
                #fi
                #exit 0
                ;;
            *)
                echo "Invalid option."
                ;;
        esac
      done
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
    echo "** 2) Set Up x-ui VPN                                    **"
    echo "** 3) Install VPN Dependencies                           **"
    echo "** 4) BBR Management                                     **"
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
    
    while true; do
        clear
        show_menu
        
        # Add a timeout of 30 seconds to the read command
        read -t 30 -p "Enter your choice (1-9): " choice
        
        # Check if a choice was entered, otherwise display "Still waiting..."
        if [ -z "$choice" ]; then
            echo -e "\nStill waiting for your command..."
            sleep 3  # Give a brief pause to allow the user to see the message
            continue  # Go back to the start of the loop to show the menu again
        fi

        case $choice in
            1)
                outline_vpn_menu
                read -p "Press enter to continue"
                ;;
            2)
                xui
                read -p "Press enter to continue"
                ;;
            3)
                VPN_dependencies
                read -p "Press enter to continue"
                ;;
            4)
                #BBR
                bbr_menu
                #bash <(curl -Ls https://raw.githubusercontent.com/arkh91/public_script_files/refs/heads/main/BBR_settings.sh)
                read -p "Press enter to continue"
                ;;
            5)
                Install_python
                read -p "Press enter to continue"
                ;;
            6)
                Install_NodeJS
                read -p "Press enter to continue"
                ;;
            7)
                New_sudo_user
                read -p "Press enter to continue"
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
echo "Executing alias_vpn ..."
alias_vpn
main


# sudo wget https://raw.githubusercontent.com/arkh91/public_script_files/main/VPN.sh && chmod u+x VPN.sh && ./VPN.sh
# bash <(curl -Ls https://raw.githubusercontent.com/arkh91/public_script_files/main/VPN.sh)
# bash <(curl -Ls https://bit.ly/arkh91_VPN)
