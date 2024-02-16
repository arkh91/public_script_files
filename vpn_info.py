#!/usr/bin/env python3

#######################################
#                                     #
#  This code has been written by:     #
#  https://github.com/arkh91/         #                        
#                                     #
#######################################
#sudo wget https://raw.githubusercontent.com/arkh91/public_script_files/main/vpn_info.py && chmod a+x vpn_info.py
import subprocess

def get_outline_executable_path():
    try:
        # Use the find command to locate the outline executable
        result = subprocess.run(["which", "outline"], capture_output=True, text=True)
        outline_path = result.stdout.strip()

        return outline_path
    except subprocess.CalledProcessError as e:
        print(f"Error: {e}")
        return None

def get_vpn_info(key):
    outline_executable_path = get_outline_executable_path()

    if not outline_executable_path:
        print("Failed to find the outline executable. Make sure it is in the system's PATH.")
        return None

    try:
        # Run the command to get VPN information
        command = [outline_executable_path, "show", key]
        
        result = subprocess.run(command, check=True, capture_output=True, text=True)

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

# Remove any trailing slashes or query parameters from the access key
access_key = access_key.rstrip('/?')

# Get VPN information
vpn_info = get_vpn_info(access_key)

if vpn_info:
    print("\nVPN Information:")
    print(f"Access Key Name: {vpn_info['access_key_name']}")
    print(f"Usage: {vpn_info['usage']}")
    print(f"Limit: {vpn_info['limit']}")
else:
    print("Failed to retrieve VPN information.")
