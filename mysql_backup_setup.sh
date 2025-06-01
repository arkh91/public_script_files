#!/bin/bash

# ----------------------------
# MySQL Auto Backup Setup Script
# ----------------------------

# ANSI colors
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
RESET="\e[0m"

# Variables
BACKUP_DIR="/var/backups/mysql"
SCRIPT_PATH="/root/mysql_backup.sh"
CRON_LOG="/var/log/mysql_backup.log"
MY_CNF="/root/.my.cnf"

# Step 1: Get MySQL credentials
read -p "Enter MySQL username [root]: " DB_USER
DB_USER=${DB_USER:-root}

read -s -p "Enter MySQL password: " DB_PASS
echo

# Step 2: Create .my.cnf
cat <<EOF > "$MY_CNF"
[client]
user=$DB_USER
password=$DB_PASS
EOF

chmod 600 "$MY_CNF"
echo -e "${GREEN}Created /root/.my.cnf with provided credentials.${RESET}"

# Step 3: Create backup script
mkdir -p "$BACKUP_DIR"
cat << 'EOF' > "$SCRIPT_PATH"
#!/bin/bash

BACKUP_DIR="/var/backups/mysql"
TIMESTAMP=$(date +%m%d%Y_%H%M%S)
TEMP_SQL_FILE="/tmp/mysql-$TIMESTAMP.sql"
BACKUP_FILE="$BACKUP_DIR/mysql-$TIMESTAMP.sql.gz"
LOG_FILE="/var/log/mysql_backup.log"

mkdir -p "$BACKUP_DIR"

# List all non-system databases
DBS=$(mysql --defaults-file=/root/.my.cnf -e 'SHOW DATABASES;' | grep -Ev "(Database|information_schema|performance_schema|mysql|sys)")

# Dump all user databases to a temp file
if mysqldump --defaults-file=/root/.my.cnf --databases $DBS > "$TEMP_SQL_FILE"; then
    gzip "$TEMP_SQL_FILE"
    mv "$TEMP_SQL_FILE.gz" "$BACKUP_FILE"
    echo -e "$(date '+%F %T') - Backup successful: $BACKUP_FILE" >> "$LOG_FILE"
else
    echo -e "$(date '+%F %T') - Backup FAILED." >> "$LOG_FILE"
    rm -f "$TEMP_SQL_FILE"
fi

# Remove backups older than 7 days
find "$BACKUP_DIR" -type f -name "mysql-*.sql.gz" -mtime +7 -delete
EOF

chmod +x "$SCRIPT_PATH"
echo -e "${GREEN}Backup script created at $SCRIPT_PATH.${RESET}"

# Step 4: Check if a cron job already exists
EXISTING_CRON=$(crontab -l 2>/dev/null | grep "$SCRIPT_PATH")

if [[ -n "$EXISTING_CRON" ]]; then
    echo -e "${YELLOW}An existing backup cron job was found:${RESET}"
    echo "$EXISTING_CRON"
    read -p "Do you want to REPLACE this scheduled backup? [y/N]: " replace_choice
    replace_choice=${replace_choice,,}  # to lowercase

    if [[ "$replace_choice" != "y" ]]; then
        echo -e "${GREEN}Keeping the current schedule. No changes made.${RESET}"
        exit 0
    else
        # Remove existing job
        crontab -l 2>/dev/null | grep -v "$SCRIPT_PATH" | crontab -
        echo -e "${YELLOW}Old schedule removed. Proceeding to set a new one.${RESET}"
    fi
else
    read -p "No scheduled backup found. Do you want to schedule one now? [y/N]: " new_schedule
    new_schedule=${new_schedule,,}
    if [[ "$new_schedule" != "y" ]]; then
        echo -e "${YELLOW}No schedule set. You can run the backup manually with:${RESET}"
        echo "  bash $SCRIPT_PATH"
        exit 0
    fi
fi

# Step 5: Ensure crontab is installed
if ! command -v crontab &> /dev/null; then
  echo -e "${YELLOW}crontab not found. Installing...${RESET}"
  sudo apt update && sudo apt install -y cron
  sudo systemctl enable cron
  sudo systemctl start cron
fi

# Step 6: Ask user how often to run the backup
echo
echo "Choose the new schedule for MySQL backup:"
echo "  [1] Every hour"
echo "  [2] Every day at 2:00 AM"
echo "  [3] Every Sunday at 2:00 AM"
read -p "Choose [1-3]: " schedule

case $schedule in
  1)
    (crontab -l 2>/dev/null; echo "0 * * * * $SCRIPT_PATH >> $CRON_LOG 2>&1") | crontab -
    echo -e "${GREEN}Scheduled: Backup will run every hour.${RESET}"
    ;;
  2)
    (crontab -l 2>/dev/null; echo "0 2 * * * $SCRIPT_PATH >> $CRON_LOG 2>&1") | crontab -
    echo -e "${GREEN}Scheduled: Backup will run daily at 2:00 AM.${RESET}"
    ;;
  3)
    (crontab -l 2>/dev/null; echo "0 2 * * 0 $SCRIPT_PATH >> $CRON_LOG 2>&1") | crontab -
    echo -e "${GREEN}Scheduled: Backup will run every Sunday at 2:00 AM.${RESET}"
    ;;
  *)
    echo -e "${RED}Invalid selection. No schedule set. Run manually using:${RESET}"
    echo "  bash $SCRIPT_PATH"
    ;;
esac
