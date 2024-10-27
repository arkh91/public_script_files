#!/bin/bash

#######################################
#                                     #
#  This code has been written by:     #
#  https://github.com/arkh91/         #                        
#                                     #
#######################################

# Create a new user called 'arkh91' if it doesn't already exist
if id "arkh91" &>/dev/null; then
    echo "User 'arkh91' already exists."
else
    sudo useradd -m -s /bin/bash arkh91
    if [ $? -eq 0 ]; then
        echo "User 'arkh91' created successfully."
    else
        echo "Failed to create user 'arkh91'."
        exit 1
    fi
fi

# Grant sudo privileges to the new user
sudo usermod -aG sudo arkh91
if [ $? -eq 0 ]; then
    echo "User 'arkh91' has been granted sudo privileges."
else
    echo "Failed to grant sudo privileges to user 'arkh91'."
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
        echo "Passwords do not match. Please try again."
    fi
done

# Set password for arkh91
echo "arkh91:$NEW_PASSWORD" | sudo chpasswd
if [ $? -eq 0 ]; then
    echo "Password for user 'arkh91' has been set successfully."
else
    echo "Failed to set password for user 'arkh91'."
    exit 1
fi

echo "All tasks completed successfully."

