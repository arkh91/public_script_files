#!/bin/bash

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
        echo "BBR is enabled."
    else
        echo -e "\e[91mBBR is not enabled. Please try again later.\e[0m"
    fi
}

# Disable BBR
disable_bbr() {
    if ! check_bbr_installed; then
        echo -e "\e[91mBBR not detected. Please install it.\e[0m"
    else
        echo "Disabling BBR..."
        sysctl -w net.ipv4.tcp_congestion_control=cubic  # Set to a default like 'cubic'
        sysctl -w net.core.default_qdisc=pfifo_fast
        echo "BBR disabled."
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
                bash <(curl -Ls https://bit.ly/arkh91_VPN)
                exit 0
                ;;
            *)
                echo "Invalid option."
                ;;
        esac
      done
}


bbr_menu

# bash <(curl -Ls https://raw.githubusercontent.com/arkh91/public_script_files/refs/heads/main/BBR_settings.sh)
