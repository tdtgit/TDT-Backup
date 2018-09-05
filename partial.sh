if [ -z "$BACKUP_DIR" ]; then
	echo "Wrong config! Please check again."
	exit 1
fi

################# MySQL Backup #################
mkdir -p "$BACKUP_DIR/databases"

echo "Starting Backup Database";
databases=`$MYSQL --user=$MYSQL_USER -p$MYSQL_PASSWORD -e "SHOW DATABASES;" | grep -Ev "(Database|information_schema|performance_schema|mysql)"`

for db in $databases; do
	$MYSQLDUMP --force --opt --user=$MYSQL_USER -p$MYSQL_PASSWORD --databases $db | 7z a -si -m0=lzma -mx=1 -p"$ARCHIVE_PASSWORD" $BACKUP_DIR/databases/$db.7z
	/usr/sbin/rclone move $BACKUP_DIR "$REMOTE:$SERVER_NAME/$TIMESTAMP" >> /var/log/rclone.log 2>&1
	rm $BACKUP_DIR/databases/$db.7z
done

echo "Finished Backup Database";
echo '-------------------------------------';

################# Website Backup #################
echo "Starting Backup Website";
for D in /var/www/*; do
	if [ -d "${D}" ]; then
		domain=${D##*/}
		echo "-- Starting backup "$domain;
		LC_ALL=en_US.UTF-8 7z a -m0=lzma -mx=1 -y -p"$ARCHIVE_PASSWORD" -r $BACKUP_DIR/$domain.7z /var/www/$domain/htdocs/*
    	        /usr/sbin/rclone move $BACKUP_DIR "$REMOTE:$SERVER_NAME/$TIMESTAMP" >> /var/log/rclone.log 2>&1
		rm $BACKUP_DIR/$domain.7z
		echo "-- Backup done "$domain;
	fi
done
echo "Finished Backup Website";
echo '-------------------------------------';

################# Nginx Configuration Backup #################
echo "Starting Backup Nginx Configuration";
rsync -zarv --exclude .git/ --exclude .gitignore --exclude TODO /etc/nginx/ $BACKUP_DIR/nginx/
/usr/sbin/rclone move $BACKUP_DIR "$REMOTE:$SERVER_NAME/$TIMESTAMP" >> /var/log/rclone.log 2>&1
echo "Finished Backup Nginx Configuration";
echo '-------------------------------------';

#/usr/sbin/rclone -q --min-age 6m delete "$REMOTE:$SERVER_NAME" #Remove all backups older than 2 week
#/usr/sbin/rclone -q --min-age 6m rmdirs "$REMOTE:$SERVER_NAME" #Remove all empty folders older than 2 week

rm -rf $BACKUP_DIR
