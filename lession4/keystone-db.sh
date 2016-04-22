#!/bin/bash

export MYSQL_ROOT_PASSWORD="mysqlpassword"
export MYSQL_HOST=`hostname -I`
export MYSQL_KEYSTONE_USER="keystone"
export MYSQL_KEYSTONE_PASSWORD="keystone"

function mysql_cmd() {
    set +o xtrace
    mysql -uroot -p$MYSQL_ROOT_PASSWORD -h$MYSQL_HOST -e "$@"
    set -o xtrace
}

# create database
cnt=`mysql_cmd "show databases;" | grep keystone | wc -l`
if [[ $cnt -eq 0 ]]; then
    mysql_cmd "create database keystone CHARACTER SET utf8;"
fi

# refresh rights
mysql_cmd "use mysql; delete from user where user=''; flush privileges;"
mysql_cmd "grant all privileges on keystone.* to '$MYSQL_KEYSTONE_USER'@'%' identified by '$MYSQL_KEYSTONE_PASSWORD';"
mysql_cmd "grant all privileges on keystone.* to '$MYSQL_KEYSTONE_USER'@'%' identified by '$MYSQL_KEYSTONE_PASSWORD';"
mysql_cmd "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' identified by '$MYSQL_ROOT_PASSWORD'; FLUSH PRIVILEGES;"
mysql_cmd "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' identified by '$MYSQL_ROOT_PASSWORD'  WITH GRANT OPTION; FLUSH PRIVILEGES;"
mysql_cmd "flush privileges;"
