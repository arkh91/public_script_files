#!/bin/bash

# Common SSH password
PASSWORD="xxx"

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

read -p "Enter server name (in, ir, it, sp, fin, s84, tur, uk38, us08, ger27, UAE11): " name

if [[ -z "${SERVERS[$name]}" ]]; then
    echo "❌ Unknown server name: $name"
    exit 1
fi

echo "🛠️ Connecting to ${SERVERS[$name]}..."
sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "${SERVERS[$name]}"
