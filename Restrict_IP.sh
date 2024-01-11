#!/bin/bash

if [ $# -eq 0 ]; then
    echo "Usage: $0 <filename>"
    exit 1
fi

filename=$1

if [ ! -f "$filename" ]; then
    echo "Error: File $filename not found."
    exit 1
fi

while IFS= read -r line; do
    if [[ ! "$line" =~ ^\# ]]; then
        eval "$line"
    fi
done < "$filename"

#Reads a file and executes all lines that do not start with a # character in the file.
#./Restrict_IP.sh your_file.txt
#sudo wget https://raw.githubusercontent.com/arkh91/public_script_files/main/iran-firewall.txt
#sudo wget https://raw.githubusercontent.com/arkh91/public_script_files/main/Restrict_IP.sh && chmod +x Restrict_IP.sh && ./Restrict_IP.sh iran-firewall.txt
#OR
#sudo wget https://raw.githubusercontent.com/arkh91/public_script_files/main/Restrict_IP.sh && chmod +x Restrict_IP.sh && wget https://raw.githubusercontent.com/arkh91/public_script_files/main/iran-firewall.txt && ./Restrict_IP.sh iran-firewall.txt


