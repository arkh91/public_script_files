#!/usr/bin/env python3

#######################################
#                                     #
#  This code has been written by:     #
#  https://github.com/arkh91/         #                        
#                                     #
#######################################
#sudo wget https://raw.githubusercontent.com/arkh91/public_script_files/main/vpn_info.py && chmod a+x vpn_info.py
import subprocess

def get_vpn_info(key):
    try:
        # Run the command to get VPN information
        command = "/var/lib/docker/overlay2/1b6e0233aac4f11ea5cee0acbc085d71090027b35a95b2202cf991f525e8f283/merged/opt/outline/outline"
        args = [command, "show", key]
        
        result = subprocess.run(args, check=True, capture_output=True, text=True)

        # Parse the output to extract the required information
        output_lines = result.stdout.split('\n')
        
        access_key_name = output_lines[0].split(': ')[1]
        usage = output_lines[1].split(': ')[1]
        limit = output_lines[2].split(': ')[1]

        return {
            'access_key_name': access_key_name,
            'usage': usage,
            'limit': limit
        }
    except subprocess.CalledProcessError as e:
        print(f"Error: {e}")
        return None

# Ask user for the access key
access_key = input("Enter the access key: ")

# Get VPN information
vpn_info = get_vpn_info(access_key)

if vpn_info:
    print("\nVPN Information:")
    print(f"Access Key Name: {vpn_info['access_key_name']}")
    print(f"Usage: {vpn_info['usage']}")
    print(f"Limit: {vpn_info['limit']}")
else:
    print("Failed to retrieve VPN information.")
