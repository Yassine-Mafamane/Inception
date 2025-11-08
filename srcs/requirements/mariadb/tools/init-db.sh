#!/bin/sh

set -e

mkdir -p /run/mysqld
chown -R mysql:mysql /run/mysqld

chown -R mysql:mysql /var/lib/mysql

start_mariadb_server() {

    mysqld_safe --user=mysql > /dev/null 2>&1 &

    export  BACKGROUND_MARIADB_PID=$!

    until mariadb-admin ping --silent; do
        echo "Waiting for MariaDB to start..."
        sleep 1
    done
}

if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "Initializing database..."
    mariadb-install-db --user=mysql --datadir=/var/lib/mysql

    start_mariadb_server

    mariadb -u root --execute="
    ALTER USER 'root'@'localhost' IDENTIFIED BY '${MARIADB_ROOT_PW}';

    GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY '${MARIADB_ROOT_PW}' WITH GRANT OPTION;

    CREATE DATABASE IF NOT EXISTS ${DB_NAME};

    DELETE FROM mysql.user WHERE user = '';
    FLUSH PRIVILEGES;"

    kill -SIGTERM $BACKGROUND_MARIADB_PID
    wait $BACKGROUND_MARIADB_PID
fi

exec mysqld_safe --user=mysql