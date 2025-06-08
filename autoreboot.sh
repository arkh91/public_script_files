#!/bin/bash

# Colors
GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
RESET="\e[0m"

echo -e "${YELLOW}Checking for crontab installation...${RESET}"
if ! command -v crontab &> /dev/null; then
    echo -e "${RED}crontab is not installed. Installing...${RESET}"
    apt update && apt install -y cron
    systemctl enable cron
    systemctl start cron
else
    echo -e "${GREEN}crontab is installed.${RESET}"
fi

echo -e "${YELLOW}Checking existing auto-reboot schedule...${RESET}"
CRONTAB_CONTENT=$(sudo crontab -l 2>/dev/null)
if echo "$CRONTAB_CONTENT" | grep -q "/sbin/reboot"; then
    echo -e "${RED}An auto-reboot is already scheduled:${RESET}"
    echo "$CRONTAB_CONTENT" | grep "/sbin/reboot"
    read -p "Do you want to remove this existing reboot schedule? (y/n): " REMOVE
    if [[ "$REMOVE" =~ ^[Yy]$ ]]; then
        CRONTAB_CONTENT=$(echo "$CRONTAB_CONTENT" | grep -v "/sbin/reboot")
        echo "$CRONTAB_CONTENT" | sudo crontab -
        echo -e "${GREEN}Existing reboot schedule removed.${RESET}"
    else
        echo -e "${YELLOW}Keeping existing schedule. Exiting.${RESET}"
        exit 0
    fi
fi

echo -e "\n${YELLOW}Select how often to auto-reboot:${RESET}"
echo "1) Every hour"
echo "2) Every day"
echo "3) Every week"
echo "4) Every month"
read -p "Enter choice [1-4]: " CHOICE

case "$CHOICE" in
    1) SCHEDULE="0 * * * *" ;;
    2) SCHEDULE="0 3 * * *" ;;       # 3:00 AM daily
    3) SCHEDULE="0 3 * * 0" ;;       # 3:00 AM Sundays
    4) SCHEDULE="0 3 1 * *" ;;       # 3:00 AM on 1st of month
    *) echo -e "${RED}Invalid option. Exiting.${RESET}"; exit 1 ;;
esac

# Create new crontab content
(
    echo "$SCHEDULE /sbin/reboot"
    echo "@reboot sleep 300 && /root/Restrict_IP_range.sh /root/iran-firewall-range2.txt"
) | sudo crontab -

echo -e "${GREEN}✅ Auto-reboot scheduled with post-reboot script:${RESET}"
echo -e "${YELLOW}- Reboot: $SCHEDULE${RESET}"
echo -e "${YELLOW}- Post-reboot: Restrict_IP_range.sh will run after 5 minutes${RESET}"
