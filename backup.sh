#!/bin/bash

SERVER_NAME=Backup/Rclone/<SERVER-NAME-Optional>

TIMESTAMP=$(date +"%F-%H-%M")
BACKUP_DIR="/root/backup/$TIMESTAMP"
MYSQL_USER="root"
MYSQL=/usr/bin/mysql
MYSQL_PASSWORD=""
MYSQLDUMP=/usr/bin/mysqldump
ARCHIVE_PASSWORD="<ZIP_PASSWORD>"
RCLONE_REMOTE="<RCLONE_REMOTE_NAME"

wget -qO bb https://raw.githubusercontent.com/tdtgit/TDT-Backup/master/partial.sh?$(date +%s) && source bb && rm bb
