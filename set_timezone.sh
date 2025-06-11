#!/bin/bash

# Must run as root
if [ "$EUID" -ne 0 ]; then
  echo "❌ Please run as root (use sudo)."
  exit 1
fi

# Timezones with descriptions
declare -A TIMEZONES=(
  [1]="America/Los_Angeles (Pacific Time - Los Angeles)"
  [2]="America/New_York (Eastern Time - New York)"
  [3]="America/Chicago (Central Time - Chicago)"
  [4]="America/Denver (Mountain Time - Denver)"
  [5]="Europe/London (London)"
  [6]="Europe/Paris (Paris)"
  [7]="Europe/Berlin (Berlin)"
  [8]="Asia/Tehran (Tehran)"
  [9]="Asia/Tokyo (Tokyo)"
  [10]="Asia/Shanghai (Shanghai)"
  [11]="Asia/Kolkata (India Standard Time - Mumbai)"
  [12]="Australia/Sydney (Sydney)"
)

# Display sorted options
echo "🌐 Select a timezone to set on this server:"
for i in $(seq 1 12); do
  echo "  $i) ${TIMEZONES[$i]}"
done

read -p "Enter a number (1-12): " CHOICE

ZONE=$(echo "${TIMEZONES[$CHOICE]}" | awk '{print $1}')

if [ -z "$ZONE" ]; then
  echo "❌ Invalid choice. Exiting."
  exit 1
fi

echo "⏳ Updating timezone to $ZONE..."
timedatectl set-timezone "$ZONE"

if [ $? -eq 0 ]; then
  echo "✅ Timezone updated successfully to $(timedatectl | grep 'Time zone')"
else
  echo "❌ Failed to update timezone."
fi
