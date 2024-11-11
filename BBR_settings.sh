#!/bin/bash

# Function to check if BBR is already installed
check_bbr_installed() {
    if grep -qw "bbr" /proc/sys/net/ipv4/tcp_available_congestion_control; then
        echo "BBR is already installed."
        return 0
    else
        echo "BBR is not installed."
        return 1
    fi
}

# Install BBR if not already installed
install_bbr() {
    if check_bbr_installed; then
        echo "BBR is already installed. Skipping installation."
    else
        echo "Installing BBR..."
        
        # Check the kernel version
        kernel_version=$(uname -r | awk -F '.' '{print $1 "." $2}')
        if (( $(echo "$kernel_version < 4.9" | bc -l) )); then
            echo "Kernel version is below 4.9. Please upgrade your kernel to use BBR."
            exit 1
        fi

        # Load BBR module
        modprobe tcp_bbr

        # Persist the module for future reboots
        echo "tcp_bbr" | sudo tee -a /etc/modules-load.d/bbr.conf
        echo
        echo "BBR has been installed, but it is not enabled."
    fi
}


# Enable BBR
#https://wiki.crowncloud.net/?How_to_enable_BBR_on_Ubuntu_20_04
enable_bbr() {
    # If BBR is not installed, install and enable it
    if ! check_bbr_installed; then
        echo -e "\e[91mBBR not detected. Please install it.\e[0m"
    else
        echo "Enabling BBR..."
        echo -e "\nnet.core.default_qdisc=fq\nnet.ipv4.tcp_congestion_control=bbr" | sudo tee -a /etc/sysctl.conf
        sudo sysctl -p

        # Check the current TCP congestion control setting
        current_congestion_control=$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')
        #current_congestion_control=$(sysctl -n net.ipv4.tcp_congestion_control)
        
        # Verify if it's set to "bbr"
        if [ "$current_congestion_control" = "bbr" ]; then
            echo "BBR is enabled."
        else
            echo -e "\e[91mBBR is not enabled. Please try again later.\e[0m"
        fi
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
        echo "** 1) Install BBR                                        **"
        echo "** 2) Enable BBR                                         **"  
        echo "** 3) Disable BBR                                        **"
        echo "** 4) Back                                               **"
        echo "**                                                       **"
        echo "***********************************************************"
        echo "***********************************************************"
        echo
        
        read -p "Choose an option: " bbr_option
        
        case $bbr_option in
            1)
                install_bbr
                read -p "Press enter to continue"
                ;;
            2)
                enable_bbr
                read -p "Press enter to continue"
                ;;
            3)
                disable_bbr
                read -p "Press enter to continue"
                ;;
            4)
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
