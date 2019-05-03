#!/bin/bash

if [ -z "$BACKUP_DIR" ]; then
    echo "Provide your backup directory in Drive"
    exit 1
fi

if [ -z "$MYSQL_USER" ]; then
    echo "Provide your MySQL root username"
    exit 1
fi

if [ -z "$MYSQL_PASSWORD" ]; then
    echo "Provide your MySQL root password"
    exit 1
fi

if [ -z "$RCLONE_REMOTE" ]; then
    echo "Provide your Rclone remote drive name"
    exit 1
fi

################# MySQL Backup #################
mkdir -p "$BACKUP_DIR/databases"

echo "Starting Backup Database";
databases=`mysql --user=$MYSQL_USER -p$MYSQL_PASSWORD -e "SHOW DATABASES;" | grep -Ev "(Database|information_schema|performance_schema|mysql)"`

for db in $databases; do
    mysqldump --force --opt --user=$MYSQL_USER -p$MYSQL_PASSWORD --databases $db | 7z a -si -m0=lzma -mx=1 -p"$ARCHIVE_PASSWORD" $BACKUP_DIR/databases/$db.7z
    rclone move $BACKUP_DIR "$RCLONE_REMOTE:$SERVER_NAME/$TIMESTAMP" >> /var/log/rclone.log 2>&1
    rm $BACKUP_DIR/databases/$db.7z
done

echo "Finished Backup Database";
echo '-------------------------------------';

################# Website Backup #################
echo "Starting Backup Website";
for D in /var/www/*; do
    [[ $(basename $D) =~ ^(22222|html)$ ]] && continue
    if [ -d "${D}" ]; then
        domain=${D##*/}
        echo "-- Starting backup "$domain;
        LC_ALL=en_US.UTF-8 7z a -m0=lzma -mx=1 -y -p"$ARCHIVE_PASSWORD" -r $BACKUP_DIR/$domain.7z /var/www/$domain/* -xr0!backup
        rclone move $BACKUP_DIR "$RCLONE_REMOTE:$SERVER_NAME/$TIMESTAMP" >> /var/log/rclone.log 2>&1
        rm $BACKUP_DIR/$domain.7z
        echo "-- Backup done "$domain;
    fi
done
echo "Finished Backup Website";
echo '-------------------------------------';

################# Nginx Configuration Backup #################
echo "Starting Backup Nginx Configuration";
rsync -zarv --exclude .git/ --exclude .gitignore --exclude TODO /etc/nginx/ $BACKUP_DIR/nginx/
rclone move $BACKUP_DIR "$RCLONE_REMOTE:$SERVER_NAME/$TIMESTAMP" >> /var/log/rclone.log 2>&1
echo "Finished Backup Nginx Configuration";
echo '-------------------------------------';

rm -rf $BACKUP_DIR
