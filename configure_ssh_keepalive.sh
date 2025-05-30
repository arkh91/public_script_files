#!/bin/bash

# Settings
CONFIG_FILE="/etc/ssh/sshd_config"
BACKUP_FILE="/etc/ssh/sshd_config.bak_$(date +%F_%T)"
ALIVE_INTERVAL="60"
ALIVE_COUNT="10"

# Check for root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run this script as root (sudo)."
    exit 1
fi

# Backup original config
echo "📦 Backing up $CONFIG_FILE to $BACKUP_FILE"
cp "$CONFIG_FILE" "$BACKUP_FILE"

# Update or append ClientAlive settings
echo "🛠️ Configuring SSH Keep-Alive settings..."
sed -i '/^ClientAliveInterval/d' "$CONFIG_FILE"
sed -i '/^ClientAliveCountMax/d' "$CONFIG_FILE"
echo "ClientAliveInterval $ALIVE_INTERVAL" >> "$CONFIG_FILE"
echo "ClientAliveCountMax $ALIVE_COUNT" >> "$CONFIG_FILE"

# Restart SSH service
echo "🔁 Restarting SSH service..."
if systemctl restart sshd; then
    echo "✅ SSH keep-alive settings applied and sshd restarted successfully."
else
    echo "❌ Failed to restart sshd. Check the configuration manually."
    exit 2
fi
