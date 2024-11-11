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
    # Check if BBR settings are present in /etc/sysctl.conf
    if ! grep -q "net.core.default_qdisc=fq" /etc/sysctl.conf || ! grep -q "net.ipv4.tcp_congestion_control=bbr" /etc/sysctl.conf; then
        echo -e "\e[91mBBR not detected.\e[0m"
        exit 1
    else
        echo "Disabling BBR..."
        
        # Temporarily set TCP congestion control to cubic and default qdisc to pfifo_fast
        sudo sysctl -w net.ipv4.tcp_congestion_control=cubic
        sudo sysctl -w net.core.default_qdisc=pfifo_fast

        # Remove BBR settings from /etc/sysctl.conf and replace with cubic and pfifo_fast for persistence
        sudo sed -i '/net.core.default_qdisc=fq/d' /etc/sysctl.conf
        sudo sed -i '/net.ipv4.tcp_congestion_control=bbr/d' /etc/sysctl.conf
        echo "net.core.default_qdisc=pfifo_fast" | sudo tee -a /etc/sysctl.conf
        echo "net.ipv4.tcp_congestion_control=cubic" | sudo tee -a /etc/sysctl.conf
        
        # Reload sysctl settings
        sudo sysctl -p

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
