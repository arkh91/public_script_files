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
else
  #Download the IP lists file
  wget https://raw.githubusercontent.com/arkh91/public_script_files/main/firewall/iran-firewall-range2.txt
  if [ "$?" -eq 0 ]; then
    echo "Download successful."
  else
    echo "Download failed."
  fi

  # Check if the file is readable
  if [ -r iran-firewall-range2.txt ]; then
    echo "The file is readable."
  else
    echo "The file is not readable or does not exist."
  fi

  # Your code that uses the file_path argument goes here
  file_path="iran-firewall-range2.txt"
  echo "Using file path argument: $file_path"

  # Iterate through each line in the file
  while IFS=$'\t' read -r start_ip end_ip; do
    # Check if the line contains two IP addresses (assuming they are separated by a tab)
    if [[ "$start_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ && "$end_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        # Block the IP range using iptables
        echo "Blocking IP range: $start_ip - $end_ip"
        sudo iptables -A INPUT -m iprange --src-range "$start_ip"-"$end_ip" -j DROP
    fi
  done < "$file_path"


  filename="iran-firewall-range2.txt"  # Replace 'yourfile.txt' with your actual file name

  rm -f "$filename"  # Attempt to remove the file
  if [ ! -f "$filename" ]; then
      echo "The file was successfully removed."
  else
      echo "The file removal was unsuccessful."
  fi
  

#bash <(curl -Ls https://raw.githubusercontent.com/arkh91/public_script_files/main/Restrict_IP_range_Integrated_file.sh)

