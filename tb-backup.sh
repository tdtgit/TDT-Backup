#!/bin/bash

clear; echo -e "\n\n\e[37m
████████╗██████╗ ████████╗    ██████╗  █████╗  ██████╗██╗  ██╗██╗   ██╗██████╗
╚══██╔══╝██╔══██╗╚══██╔══╝    ██╔══██╗██╔══██╗██╔════╝██║ ██╔╝██║   ██║██╔══██╗
   ██║   ██║  ██║   ██║       ██████╔╝███████║██║     █████╔╝ ██║   ██║██████╔╝
   ██║   ██║  ██║   ██║       ██╔══██╗██╔══██║██║     ██╔═██╗ ██║   ██║██╔═══╝
   ██║   ██████╔╝   ██║       ██████╔╝██║  ██║╚██████╗██║  ██╗╚██████╔╝██║
   ╚═╝   ╚═════╝    ╚═╝       ╚═════╝ ╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝ ╚═════╝ ╚═╝ \e[0m"

function _e {
    case $2 in
        success) COLOR=32 ;;
        warning) COLOR=33 ;;
        error) COLOR=31 ;;
        *) COLOR="" ;;
    esac
    echo -e "\e[${COLOR}m  $1\e[0m"
}

function _en {
    case $2 in
        success) COLOR=32 ;;
        warning) COLOR=33 ;;
        error) COLOR=31 ;;
        *) COLOR="" ;;
    esac
    echo -ne "\e[${COLOR}m$1\e[0m"
}

function _p {
    eval $1 & PID=$!

    _en "  $2" "$3"
    while kill -0 $PID 2> /dev/null; do 
        _en "."
        sleep 1
    done
}

function setup {
    # TODO: advanced options: temporary backup dir,...
    source .env &>/dev/null || echo -e "\n\nNew setup detected. Please provide all information you can:"

    # If is first run
    if [ ! -f .env.default ]; then
        # Try to self-help
        echo \
"SOURCE_DIR=/var/www/
MYSQL_USER=root
MYSQL_PASSWORD=$(cat /etc/mysql/conf.d/my.cnf | awk 'BEGIN{a=1}{if($1=="password"){print $3}}')
ARCHIVE_PASSWORD=tbbackup
GDRIVE_DIR=Backup/Rclone/$(hostname)-$(ip route get 8.8.8.8| head -1 | awk '{print $7}')
RCLONE_NAME=gdrive
TEMP_DIR=/tmp/tb-backup" \
        > .env.default

        chmod 600 .env.default
    fi

    source .env.default

    [ -f .env ] && _e "\n\nCurrent settings exists. Please be careful when you config new settings.\n\n" "warning";

    function mysqlConnect {
        read -ep "Provide your MySQL username $([ ! -z "$TB_MYSQL_USER" ] && echo [$TB_MYSQL_USER] || echo [$MYSQL_USER]): " INPUT_MYSQL_USER;
        if [ -z "$INPUT_MYSQL_USER" ]; then
            [ ! -z "$TB_MYSQL_USER" ] && MYSQL_USER=$TB_MYSQL_USER
        else
            MYSQL_USER=$INPUT_MYSQL_USER
        fi

        read -p "Provide your MySQL password $([ ! -z "$TB_MYSQL_PASSWORD" ] && echo [$TB_MYSQL_PASSWORD] || echo [$MYSQL_PASSWORD]): " INPUT_MYSQL_PASSWORD;
        if [ -z "$INPUT_MYSQL_PASSWORD" ]; then
            [ ! -z "$TB_MYSQL_PASSWORD" ] && MYSQL_PASSWORD=$TB_MYSQL_PASSWORD
        else
            MYSQL_PASSWORD=$INPUT_MYSQL_PASSWORD
        fi
    }

    mysqlConnect

    until mysql -u $MYSQL_USER -p$MYSQL_PASSWORD -e ";" ; do
        _e "\n  Can not connect MySQL, please check your information.\n" "error";
        mysqlConnect
    done

    _e "\n  Connect to MySQL successfully.\n" "success";

    read -p "Provide your archive password (optional) $([ ! -z "$TB_ARCHIVE_PASSWORD" ] && echo [$TB_ARCHIVE_PASSWORD] || echo [$ARCHIVE_PASSWORD]): " INPUT_ARCHIVE_PASSWORD;
    if [ -z "$INPUT_ARCHIVE_PASSWORD" ]; then
        [ ! -z "$TB_ARCHIVE_PASSWORD" ] && ARCHIVE_PASSWORD=$TB_ARCHIVE_PASSWORD
    else
        ARCHIVE_PASSWORD=$INPUT_ARCHIVE_PASSWORD
    fi

    read -p "Provide your Google Drive backup directory $([ ! -z "$TB_GDRIVE_DIR" ] && echo [$TB_GDRIVE_DIR] || echo [$GDRIVE_DIR]): " INPUT_GDRIVE_DIR;
    if [ -z "$INPUT_GDRIVE_DIR" ]; then
        [ ! -z "$TB_GDRIVE_DIR" ] && GDRIVE_DIR=$TB_GDRIVE_DIR
    else
        GDRIVE_DIR=$INPUT_GDRIVE_DIR
    fi

    function rcloneConnect {
        read -p "Provide your Rclone remote name $([ ! -z "$TB_RCLONE_NAME" ] && echo [$TB_RCLONE_NAME] || echo [$RCLONE_NAME]): " INPUT_RCLONE_NAME;
        if [ -z "$INPUT_RCLONE_NAME" ]; then
            [ ! -z "$TB_RCLONE_NAME" ] && RCLONE_NAME=$TB_RCLONE_NAME
        else
            RCLONE_NAME=$INPUT_RCLONE_NAME
        fi
    }

    rcloneConnect

    until rclone ls $RCLONE_NAME: --max-depth 1; do
        _e "\n  Can not connect Google Drive, please check your information.\n" "error";
        rcloneConnect
    done

    _e "\n  Connect to Google Drive successfully\n" "success";

    read -p "Provide your temporary backup path $([ ! -z "$TB_TEMP_DIR" ] && echo [$TB_TEMP_DIR] || echo [$TEMP_DIR]): " INPUT_TEMP_DIR;
    if [ -z "$INPUT_TEMP_DIR" ]; then
        [ ! -z "$TB_TEMP_DIR" ] && TEMP_DIR=$TB_TEMP_DIR
    else
        TEMP_DIR=$INPUT_TEMP_DIR
    fi

    _e "\nAll done. Now you can run 'tbackup run' to see it in action.\n" "success";

    echo \
"$(echo TB_SOURCE_DIR)=$SOURCE_DIR
$(echo TB_MYSQL_USER)=$MYSQL_USER
$(echo TB_MYSQL_PASSWORD)=$MYSQL_PASSWORD
$(echo TB_ARCHIVE_PASSWORD)=$ARCHIVE_PASSWORD
$(echo TB_GDRIVE_DIR)=$GDRIVE_DIR
$(echo TB_RCLONE_NAME)=$RCLONE_NAME
$(echo TB_TEMP_DIR)=$TEMP_DIR" \
    > .env

    chmod 600 .env
}

function run {
    source .env

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
    echo -e '\n\n===================================';
    echo "Starting Backup Database";
    databases=`mysql --user=$TB_MYSQL_USER -p$TB_MYSQL_PASSWORD -e "SHOW DATABASES;" | grep -Ev "(Database|information_schema|performance_schema|mysql)"`

    for db in $databases; do
        # TODO progress bar
        _e "\n- $db: ";
        _p "mysqldump --force --opt --user=${TB_MYSQL_USER} -p${TB_MYSQL_PASSWORD} --databases ${db} | 7z a -si -m0=lzma -mx=1 ${TB_ARCHIVE_PASSWORD} ${db}.sql.7z > /dev/null" "Processing" "success"
        _p "rclone move $db.sql.7z $TB_RCLONE_NAME:$TB_GDRIVE_DIR/$TIMESTAMP/databases" "Uploading" "success"
        _en "  Done" "success"
    done

    echo -e "\n\nFinished Backup Database";
    echo -e '===================================';
}

case $1 in
    setup)
        setup
        ;;
    run)
        run
        ;;
esac