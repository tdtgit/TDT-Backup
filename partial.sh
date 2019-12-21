if [ -z "$BACKUP_DIR" ]; then
    echo "Wrong config! Please check again."
    exit 1
fi

################# MySQL Backup #################
mkdir -p "$BACKUP_DIR/databases"

echo "Starting Backup Database";
databases=`$MYSQL --user=$MYSQL_USER -p$MYSQL_PASSWORD -e "SHOW DATABASES;" | grep -Ev "(Database|information_schema|performance_schema|mysql)"`

for db in $databases; do
    $MYSQLDUMP --force --opt --user=$MYSQL_USER -p$MYSQL_PASSWORD --databases $db | 7z a -si -m0=lzma2 -mx=9 -mfb=64 -md=32m -ms=on -p"$ARCHIVE_PASSWORD" $BACKUP_DIR/databases/$db.7z
    /usr/sbin/rclone move $BACKUP_DIR "$REMOTE:$SERVER_NAME/$TIMESTAMP" >> /var/log/rclone.log 2>&1
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
        LC_ALL=en_US.UTF-8 7z a -m0=lzma2 -mx=2 -y -mfb=64 -md=32m -ms=on -p"$ARCHIVE_PASSWORD" -r $BACKUP_DIR/$domain.7z /var/www/$domain/* -xr0!backup -xr!cache -xr!*.webp -xr!node_modules
        /usr/sbin/rclone move $BACKUP_DIR "$REMOTE:$SERVER_NAME/$TIMESTAMP" >> /var/log/rclone.log 2>&1
        rm $BACKUP_DIR/$domain.7z
        echo "-- Backup done "$domain;
    fi
done
echo "Finished Backup Website";
echo '-------------------------------------';

################# Nginx Configuration Backup #################
echo "Starting Backup Nginx Configuration";
7z a -m0=lzma2 -mx=9 -y -mfb=64 -md=32m -ms=on -p"$ARCHIVE_PASSWORD" -r $BACKUP_DIR/nginx.7z /etc/nginx/* -xr!.git -xr!.gitignore
7z a -m0=lzma2 -mx=9 -y -mfb=64 -md=32m -ms=on -p"$ARCHIVE_PASSWORD" -r $BACKUP_DIR/php.7z /etc/php/*
7z a -m0=lzma2 -mx=9 -y -mfb=64 -md=32m -ms=on -p"$ARCHIVE_PASSWORD" -r $BACKUP_DIR/letsencrypt.7z /etc/letsencrypt/*
/usr/sbin/rclone move $BACKUP_DIR "$REMOTE:$SERVER_NAME/$TIMESTAMP/others" >> /var/log/rclone.log 2>&1
echo "Finished Backup Nginx Configuration";
echo '-------------------------------------';

#/usr/sbin/rclone -q --min-age 6m delete "$REMOTE:$SERVER_NAME" #Remove all backups older than 2 week
#/usr/sbin/rclone -q --min-age 6m rmdirs "$REMOTE:$SERVER_NAME" #Remove all empty folders older than 2 week

rm -rf $BACKUP_DIR
