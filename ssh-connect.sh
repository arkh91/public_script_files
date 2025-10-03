#!/bin/bash

# Common SSH password
PASSWORD="xxxx"

# Server list (alias => user@host)
declare -A SERVERS
SERVERS["in"]="root@in.in01dir.krp2025.online"
SERVERS["ir"]="arkh91@iran.krp2025.online"
SERVERS["it"]="root@it.krp2025.online"
SERVERS["sp"]="root@sp.krp2025.online"
SERVERS["s84"]="root@s84.krp2025.online"
SERVERS["tur"]="arkh91@tur.krp2025.online"
SERVERS["uk37"]="root@uk37dir.krp2025.online"
SERVERS["uk38"]="root@uk.uk38dir.krp2025.online"
SERVERS["us08"]="root@us08dir.krp2025.online"
SERVERS["uae11"]="root@uae11dir.krp2025.online"
SERVERS["ger27"]="arkh91@ger27dir.krp2025.online"
SERVERS["fin"]="root@fin.fin01dir.krp2025.online"

# Helper: print available servers
print_servers() {
    echo -n "Available servers: "
    local first=1
    for k in "${!SERVERS[@]}"; do
        if [[ $first -eq 1 ]]; then
            echo -n "$k"
            first=0
        else
            echo -n ", $k"
        fi
    done | sort -u
    echo
}

# If an argument was provided, try to use it; otherwise prompt
name="$1"

if [[ -n "$name" ]]; then
    if [[ -z "${SERVERS[$name]}" ]]; then
        echo "⚠️  Argument '$name' is not a known server."
        name=""
    fi
fi

# Prompt until a valid server name is provided
while [[ -z "$name" ]]; do
    print_servers
    read -p "Enter server name: " name
    name="${name// /}"   # trim spaces
    if [[ -z "${SERVERS[$name]}" ]]; then
        echo "❌ Unknown server name: '$name'. Please try again."
        name=""
    fi
done

echo "🛠️  Connecting to ${SERVERS[$name]}..."
sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "${SERVERS[$name]}"
