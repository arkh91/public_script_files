#!/bin/bash

# Run as root
if [ "$EUID" -ne 0 ]; then
  echo "❌ Please run as root (use sudo)."
  exit 1
fi

# Declare timezones
declare -A TIMEZONES=(
  ["1"]="America/Los_Angeles (Pacific Time - Los Angeles)"
  ["2"]="America/New_York (Eastern Time - New York)"
  ["3"]="America/Chicago (Central Time - Chicago)"
  ["4"]="America/Denver (Mountain Time - Denver)"
  ["5"]="Europe/London (London)"
  ["6"]="Europe/Paris (Paris)"
  ["7"]="Europe/Berlin (Berlin)"
  ["8"]="Asia/Tehran (Tehran)"
  ["9"]="Asia/Tokyo (Tokyo)"
  ["10"]="Asia/Shanghai (Shanghai)"
  ["11"]="Asia/Kolkata (India Standard Time - Mumbai)"
  ["12"]="Australia/Sydney (Sydney)"
)

echo "🌐 Select a timezone to set on this server:"
for i in "${!TIMEZONES[@]}"; do
  echo "  $i) ${TIMEZONES[$i]}"
done

read -p "Enter a number (1-12): " CHOICE

# Get timezone key
case $CHOICE in
  1) ZONE="America/Los_Angeles" ;;
  2) ZONE="America/New_York" ;;
  3) ZONE="America/Chicago" ;;
  4) ZONE="America/Denver" ;;
  5) ZONE="Europe/London" ;;
  6) ZONE="Europe/Paris" ;;
  7) ZONE="Europe/Berlin" ;;
  8) ZONE="Asia/Tehran" ;;
  9) ZONE="Asia/Tokyo" ;;
 10) ZONE="Asia/Shanghai" ;;
 11) ZONE="Asia/Kolkata" ;;
 12) ZONE="Australia/Sydney" ;;
  *) echo "❌ Invalid choice. Exiting."; exit 1 ;;
esac

echo "⏳ Updating timezone to $ZONE..."
timedatectl set-timezone "$ZONE"

if [ $? -eq 0 ]; then
  echo "✅ Timezone updated successfully to $(timedatectl | grep 'Time zone')"
else
  echo "❌ Failed to update timezone."
fi
