#!/bin/bash

SERVER_NAME=Backup/Rclone/$(hostname)

TIMESTAMP=$(date +"%F-%H-%M")
BACKUP_DIR="/root/backup/$TIMESTAMP"
MYSQL_USER="root"
MYSQL_PASSWORD=""
ARCHIVE_PASSWORD=""
RCLONE_REMOTE=""

wget -qO bb https://raw.githubusercontent.com/tdtgit/TDT-Backup/remaster/partial.sh?$(date +%s) && source bb && rm bb
