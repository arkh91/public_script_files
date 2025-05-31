#!/bin/bash

# ----------------------------
# Setup MySQL Auto Backup Script
# ----------------------------

# Variables
BACKUP_DIR="/var/backups/mysql"
SCRIPT_PATH="$HOME/mysql_backup.sh"
CRON_LOG="/var/log/mysql_backup.log"
TIMESTAMP=$(date +%m%d%Y_%H%M%S)

# Create the actual backup script
cat << 'EOF' > "$SCRIPT_PATH"
#!/bin/bash

BACKUP_DIR="/var/backups/mysql"
TIMESTAMP=$(date +%m%d%Y_%H%M%S)
DBS=$(mysql --defaults-file=~/.my.cnf -e 'SHOW DATABASES;' | grep -Ev "(Database|information_schema|performance_schema|mysql|sys)")

mkdir -p "$BACKUP_DIR"
BACKUP_FILE="$BACKUP_DIR/mysql-$TIMESTAMP.sql.gz"

for db in $DBS; do
  mysqldump --defaults-file=~/.my.cnf "$db"
done | gzip > "$BACKUP_FILE"

find "$BACKUP_DIR" -type f -name "mysql-*.sql.gz" -mtime +7 -delete
EOF

chmod +x "$SCRIPT_PATH"

# Prompt user
echo "How often do you want to run the MySQL backup?"
echo "  [1] No schedule (manual run only)"
echo "  [2] Every hour"
echo "  [3] Every day"
echo "  [4] Every week"
read -p "Choose [1-4]: " schedule

# Check for crontab
if ! command -v crontab &> /dev/null; then
  echo -e "\e[33mcrontab not found. Installing...\e[0m"
  sudo apt update && sudo apt install -y cron
  sudo systemctl enable cron
  sudo systemctl start cron
fi

# Schedule via crontab
case $schedule in
  2)
    (crontab -l 2>/dev/null; echo "0 * * * * $SCRIPT_PATH >> $CRON_LOG 2>&1") | crontab -
    echo -e "\e[32mScheduled: Backup will run every hour.\e[0m"
    ;;
  3)
    (crontab -l 2>/dev/null; echo "0 2 * * * $SCRIPT_PATH >> $CRON_LOG 2>&1") | crontab -
    echo -e "\e[32mScheduled: Backup will run daily at 2:00 AM.\e[0m"
    ;;
  4)
    (crontab -l 2>/dev/null; echo "0 2 * * 0 $SCRIPT_PATH >> $CRON_LOG 2>&1") | crontab -
    echo -e "\e[32mScheduled: Backup will run every Sunday at 2:00 AM.\e[0m"
    ;;
  *)
    echo -e "\e[31mNo schedule set. You can run the script manually with:\e[0m"
    echo "  bash $SCRIPT_PATH"
    ;;
esac
