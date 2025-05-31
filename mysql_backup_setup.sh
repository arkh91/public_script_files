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
DBS=$(mysql --defaults-file=/root/.my.cnf -e 'SHOW DATABASES;' | grep -Ev "(Database|information_schema|performance_schema|mysql|sys)")

mkdir -p "$BACKUP_DIR"
BACKUP_FILE="$BACKUP_DIR/mysql-$TIMESTAMP.sql.gz"

for db in $DBS; do
  mysqldump --defaults-file=/root/.my.cnf "$db"
done | gzip > "$BACKUP_FILE"

find "$BACKUP_DIR" -type f -name "mysql-*.sql.gz" -mtime +7 -delete
EOF

chmod +x "$SCRIPT_PATH"
echo -e "${GREEN}Backup script created at $SCRIPT_PATH.${RESET}"

# Step 4: Ask user how often to run the backup
echo
echo "How often do you want to run the MySQL backup?"
echo "  [1] No schedule (manual run only)"
echo "  [2] Every hour"
echo "  [3] Every day"
echo "  [4] Every week"
read -p "Choose [1-4]: " schedule

# Step 5: Ensure crontab is installed
if ! command -v crontab &> /dev/null; then
  echo -e "${YELLOW}crontab not found. Installing...${RESET}"
  sudo apt update && sudo apt install -y cron
  sudo systemctl enable cron
  sudo systemctl start cron
fi

# Step 6: Set up the cron job
case $schedule in
  2)
    (crontab -l 2>/dev/null; echo "0 * * * * $SCRIPT_PATH >> $CRON_LOG 2>&1") | crontab -
    echo -e "${GREEN}Scheduled: Backup will run every hour.${RESET}"
    ;;
  3)
    (crontab -l 2>/dev/null; echo "0 2 * * * $SCRIPT_PATH >> $CRON_LOG 2>&1") | crontab -
    echo -e "${GREEN}Scheduled: Backup will run daily at 2:00 AM.${RESET}"
    ;;
  4)
    (crontab -l 2>/dev/null; echo "0 2 * * 0 $SCRIPT_PATH >> $CRON_LOG 2>&1") | crontab -
    echo -e "${GREEN}Scheduled: Backup will run every Sunday at 2:00 AM.${RESET}"
    ;;
  *)
    echo -e "${RED}No schedule set. You can run the script manually with:${RESET}"
    echo "  bash $SCRIPT_PATH"
    ;;
esac
