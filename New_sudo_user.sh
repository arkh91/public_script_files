#!/bin/bash

#######################################
#                                     #
#  This code has been written by:     #
#  https://github.com/arkh91/         #                        
#                                     #
#######################################


# Define light green color
LIGHT_GREEN='\033[1;32m'
RED='\033[1;31m'
PURPLE='\033[1;35m'
# Reset color
NO_COLOR='\033[0m'

# Prompt for the username
read -p "Enter the username you want to create and grant sudo access to: " USERNAME

# Create a new user if it doesn't already exist
if id "$USERNAME" &>/dev/null; then
    echo -e "${PURPLE}User '$USERNAME' already exists.${NO_COLOR}"
else
    sudo useradd -m -s /bin/bash "$USERNAME"
    if [ $? -eq 0 ]; then
        echo -e "${LIGHT_GREEN}User '$USERNAME' created successfully.${NO_COLOR}"
    else
        echo -e "${RED}Failed to create user '$USERNAME'.${NO_COLOR}"
        exit 1
    fi
fi

# Grant sudo privileges to the new user
sudo usermod -aG sudo "$USERNAME"
if [ $? -eq 0 ]; then
    echo -e "${LIGHT_GREEN}User '$USERNAME' has been granted sudo privileges.${NO_COLOR}"
else
    echo -e "${RED}Failed to grant sudo privileges to user '$USERNAME'.${NO_COLOR}"
    exit 1
fi

# Ask if the user wants to reset the password
read -p "Do you want to reset the password for user '$USERNAME'? (y/n): " response
response=${response,,} # Convert to lowercase

if [[ "$response" == "y" || "$response" == "yes" ]]; then
    # Loop to ensure passwords match
    while true; do
        # Prompt for the new password
        read -sp "Enter new password for user '$USERNAME': " NEW_PASSWORD
        echo
        read -sp "Confirm new password: " CONFIRM_PASSWORD
        echo

        # Check if passwords match
        if [ "$NEW_PASSWORD" == "$CONFIRM_PASSWORD" ]; then
            # Set the password for the user only if passwords match
            echo "$USERNAME:$NEW_PASSWORD" | sudo chpasswd
            if [ $? -eq 0 ]; then
                echo -e "${LIGHT_GREEN}Password successfully set for user '$USERNAME'.${NO_COLOR}"
            else
                echo -e "${RED}Failed to set password for user '$USERNAME'.${NO_COLOR}"
            fi
            break
        else
            echo -e "${RED}Passwords do not match. Please try again.${NO_COLOR}"
        fi
    done
else
    echo -e "${RED}Password reset aborted.${NO_COLOR}"
fi


echo "list users in the sudo group:"
getent group sudo | cut -d: -f4
echo
# bash <(curl -Ls https://raw.githubusercontent.com/arkh91/public_script_files/refs/heads/main/New_sudo_user.sh)
