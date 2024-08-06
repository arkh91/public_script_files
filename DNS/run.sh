#!/bin/bash

LINKS_FILE="links.txt"

create_link() {
    # Generate a new link (this example simply generates a random link)
    NEW_LINK="http://example.com/$(date +%s%N | sha256sum | base64 | head -c 8)"
    
    # Store the new link in the file
    echo $NEW_LINK >> $LINKS_FILE
    
    echo "Generated link: $NEW_LINK"
}

remove_link() {
    if [[ -z "$2" ]]; then
        echo "Error: No URL provided for removal."
        exit 1
    fi
    
    URL_TO_REMOVE=$2
    
    # Check if the URL exists in the file
    if grep -q "$URL_TO_REMOVE" "$LINKS_FILE"; then
        # Remove the URL from the file
        grep -v "$URL_TO_REMOVE" "$LINKS_FILE" > temp.txt && mv temp.txt $LINKS_FILE
        echo "Removed link: $URL_TO_REMOVE"
    else
        echo "Error: URL not found in the list."
        exit 1
    fi
}

# Check for options
if [[ "$1" == "-c" ]]; then
    create_link
elif [[ "$1" == "-r" ]]; then
    remove_link $@
else
    echo "Usage:"
    echo "./run -c               Generate a new link"
    echo "./run -r <URL>         Remove an existing link"
    exit 1
fi

#./run.sh -c to generate a new link.
#./run.sh -r -URL to remove an existing link.

#sudo wget https://raw.githubusercontent.com/arkh91/public_script_files/main/DNS/run.sh && chmod u+x run.sh
