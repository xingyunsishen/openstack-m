#!/bin/bash
TOPDIR=$(cd $(dirname "$0") && pwd)
TEMP=`mktemp`; rm -rfv $TEMP >/dev/null; mkdir -p $TEMP;
export MYSQL_ROOT_PASSWORD="mysqlpassword"
DEBIAN_FRONTEND=noninteractive \
apt-get --option "Dpkg::Options::=--force-confold" --assume-yes \
install -y --force-yes openssh-server mysql-server
if [[ `cat /etc/mysql/my.cnf | grep "0.0.0.0" | wc -l` -eq 0 ]]; then
    mysqladmin -uroot password $MYSQL_ROOT_PASSWORD
fi
sed -i 's/127.0.0.1/0.0.0.0/g' /etc/mysql/my.cnf
service mysql restart

for n in `hostname -I`; do
        mysql -uroot -p$MYSQL_ROOT_PASSWORD  -e "use mysql; insert into user (Host,User,Password) values ('$n','root',Password('$MYSQL_ROOT_PASSWORD'));"
done

host_name=`hostname -s`
mysql -uroot -p$MYSQL_ROOT_PASSWORD  -e "use mysql; insert into user (Host,User,Password) values ('$host_name','root',Password('$MYSQL_ROOT_PASSWORD'));"


mysql -uroot -p$MYSQL_ROOT_PASSWORD  -e "use mysql; delete from user where user=''; flush privileges;"
mysql -uroot -p$MYSQL_ROOT_PASSWORD  -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' identified by '$MYSQL_ROOT_PASSWORD'; FLUSH PRIVILEGES;"
mysql -uroot -p$MYSQL_ROOT_PASSWORD  -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' identified by '$MYSQL_ROOT_PASSWORD'  WITH GRANT OPTION; FLUSH PRIVILEGES;"
mysql -uroot -p$MYSQL_ROOT_PASSWORD -e  "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' identified by '$MYSQL_ROOT_PASSWORD'; FLUSH PRIVILEGES;"
mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' identified by '$MYSQL_ROOT_PASSWORD'  WITH GRANT OPTION; FLUSH PRIVILEGES;"
mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "flush privileges;"
service mysql restart
