#!/bin/bash

# Must run as root
if [ "$EUID" -ne 0 ]; then
  echo "❌ Please run as root (use sudo)."
  exit 1
fi

# Indexed list of timezones and labels
TIMEZONE_OPTIONS=(
  "America/Los_Angeles (Pacific Time - Los Angeles)"
  "America/New_York (Eastern Time - New York)"
  "America/Chicago (Central Time - Chicago)"
  "America/Denver (Mountain Time - Denver)"
  "Europe/London (London)"
  "Europe/Paris (Paris)"
  "Europe/Berlin (Berlin)"
  "Asia/Tehran (Tehran)"
  "Asia/Tokyo (Tokyo)"
  "Asia/Shanghai (Shanghai)"
  "Asia/Kolkata (India Standard Time - Mumbai)"
  "Australia/Sydney (Sydney)"
)

echo "🌐 Select a timezone to set on this server:"
for i in "${!TIMEZONE_OPTIONS[@]}"; do
  index=$((i + 1))
  echo "  $index) ${TIMEZONE_OPTIONS[$i]}"
done

read -p "Enter a number (1-${#TIMEZONE_OPTIONS[@]}): " CHOICE

# Validate input
if ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || [ "$CHOICE" -lt 1 ] || [ "$CHOICE" -gt ${#TIMEZONE_OPTIONS[@]} ]; then
  echo "❌ Invalid choice. Exiting."
  exit 1
fi

# Extract timezone name (first word before space)
SELECTED="${TIMEZONE_OPTIONS[$((CHOICE - 1))]}"
ZONE="${SELECTED%% *}"

echo "⏳ Updating timezone to $ZONE..."
timedatectl set-timezone "$ZONE"

if [ $? -eq 0 ]; then
  echo "✅ Timezone updated successfully to $(timedatectl | grep 'Time zone')"
else
  echo "❌ Failed to update timezone."
fi
