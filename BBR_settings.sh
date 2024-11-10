#!/bin/bash

# Function to check if BBR is already installed
check_bbr_installed() {
    if grep -q "tcp_bbr" /proc/sys/net/ipv4/tcp_available_congestion_control; then
        echo "BBR is already installed."
        return 0
    else
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

        echo "BBR has been installed, but it is not enabled."
    fi
}


# Enable BBR
enable_bbr() {
    echo "Enabling BBR..."
    sysctl -w net.core.default_qdisc=fq
    sysctl -w net.ipv4.tcp_congestion_control=bbr
    echo "BBR enabled."
}

# Disable BBR
disable_bbr() {
    echo "Disabling BBR..."
    sysctl -w net.ipv4.tcp_congestion_control=cubic  # Set to a default like 'cubic'
    sysctl -w net.core.default_qdisc=pfifo_fast
    echo "BBR disabled."
}
bbr_menu (){
  while true; do
    # Menu options
    echo "***********************************************************"
    echo "***********************************************************"
    echo "** BBR Installation and Management Script                **"
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
            ;;
        2)
            enable_bbr
            ;;
        3)
            disable_bbr
            ;;
        4)
            bash <(curl -Ls https://bit.ly/arkh91_VPN)
            ;;
        *)
            echo "Invalid option."
            ;;
    esac
  done
}


bbr_menu

# bash <(curl -Ls https://raw.githubusercontent.com/arkh91/public_script_files/refs/heads/main/BBR_settings.sh)
