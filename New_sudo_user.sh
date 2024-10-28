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


# Create a new user called 'arkh91' if it doesn't already exist
if id "arkh91" &>/dev/null; then
    echo -e "${PURPLE}User 'arkh91' already exists.${NO_COLOR}"
else
    sudo useradd -m -s /bin/bash arkh91
    if [ $? -eq 0 ]; then
        echo -e "${LIGHT_GREEN}User 'arkh91' created successfully.${NO_COLOR}"
    else
        #echo "Failed to create user 'arkh91'."
        echo -e "${RED}Failed to create user 'arkh91'.${NO_COLOR}"
        exit 1
    fi
fi

# Grant sudo privileges to the new user
sudo usermod -aG sudo arkh91
if [ $? -eq 0 ]; then
    #echo "User 'arkh91' has been granted sudo privileges."
    echo -e "${LIGHT_GREEN}User 'arkh91' has been granted sudo privileges.${NO_COLOR}"
else
    #echo "Failed to grant sudo privileges to user 'arkh91'."
    echo -e "${RED}Failed to grant sudo privileges to user 'arkh91'.${NO_COLOR}"
    exit 1
fi

# Loop to ensure passwords match
while true; do
    # Prompt for the new password
    read -sp "Enter new password for user 'arkh91': " NEW_PASSWORD
    echo
    read -sp "Confirm new password: " CONFIRM_PASSWORD
    echo

    # Check if passwords match
    if [ "$NEW_PASSWORD" == "$CONFIRM_PASSWORD" ]; then
        break
    else
        #echo "Passwords do not match. Please try again."
        echo -e "${RED}Passwords do not match. Please try again.${NO_COLOR}"
    fi
done

# Set password for arkh91
echo "arkh91:$NEW_PASSWORD" | sudo chpasswd
if [ $? -eq 0 ]; then
    #echo "Password for user 'arkh91' has been set successfully."
    echo -e "${LIGHT_GREEN}Password for user 'arkh91' has been set successfully.${NO_COLOR}"
else
    #echo "Failed to set password for user 'arkh91'."
    echo -e "${RED}Failed to set password for user 'arkh91'.${NO_COLOR}"
    exit 1
fi

echo "All tasks completed successfully."

