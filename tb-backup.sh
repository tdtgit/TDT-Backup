#!/bin/bash

source .env

#!/bin/bash

if [ -z "$TB_TEMP_DIR" ]; then
    TB_TEMP_DIR=/tmp/tb-backup/
fi

if [ -z "$TB_GDRIVE_DIR" ]; then
    echo "Provide your backup directory in Google Drive"
    exit 1
fi

if [ -z "$TB_MYSQL_USER" ]; then
    echo "Provide your MySQL root username"
    exit 1
fi

if [ -z "$TB_MYSQL_PASSWORD" ]; then
    echo "Provide your MySQL root password"
    exit 1
fi

if [ -z "$TB_RCLONE_NAME" ]; then
    echo "Provide your Rclone remote drive name"
    exit 1
fi

################# Preparation ##################

TIMESTAMP=$(date +"%F-%H-%M")
TB_TEMP_DIR=$TB_TEMP_DIR/$TIMESTAMP

[ ! -z "$TB_ARCHIVE_PASSWORD" ] && TB_ARCHIVE_PASSWORD=-p"$TB_ARCHIVE_PASSWORD"

mkdir -p $TB_TEMP_DIR
cd $TB_TEMP_DIR || exit 1;

################# MySQL Backup #################
echo "Starting Backup Database";
databases=`mysql --user=$TB_MYSQL_USER -p$TB_MYSQL_PASSWORD -e "SHOW DATABASES;" | grep -Ev "(Database|information_schema|performance_schema|mysql)"`

for db in $databases; do
    mysqldump --force --opt --user=$TB_MYSQL_USER -p$TB_MYSQL_PASSWORD --databases $db | 7z a -si -m0=lzma -mx=1 $TB_ARCHIVE_PASSWORD $db.sql.7z && \
    rclone move $db.sql.7z "$TB_RCLONE_NAME:$TB_GDRIVE_DIR/$TIMESTAMP/databases"
done

echo "Finished Backup Database";
echo '-------------------------------------';