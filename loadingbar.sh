#!/bin/bash

# Function to display loading bar
loading_bar() {
    local steps=50     # Total length of the loading bar
    local delay=0.05   # Delay between updates (in seconds)

    # Loading bar loop
    for ((i = 1; i <= steps; i++)); do
        # Calculate the progress percentage
        local percent=$((i * 100 / steps))
        # Create the loading bar with "#" for filled sections and spaces for remaining
        local bar=$(printf "%-${steps}s" "#" | tr ' ' '#')
        # Display the loading bar with percentage and overwrite the line
        printf "\r[%-${steps}s] %d%%" "${bar:0:i}" "$percent"
        # Delay for smooth animation
        sleep "$delay"
    done

    # Final message after completion
    echo -e "\nLoading complete!"
}

# Call the loading bar function
loading_bar

# bash <(curl -Ls https://raw.githubusercontent.com/arkh91/public_script_files/refs/heads/main/loadingbar.sh)
