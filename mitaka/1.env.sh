#!/bin/bash

export force="0"


TOPDIR=$(cd $(dirname "$0") && pwd)
cd $TOPDIR

[[ -e ./proxy ]] && . ./proxy

#----------------------------------------------------------------------------------------------
# Begin to setup ntp
#----------------------------------------------------------------------------------------------

conf_key="/etc/chrony/chrony.keys"
if [[ `cat $conf_key | grep "YOB0kNkh" | wc -l` -eq 0 || $force -gt 0 ]]; then
    apt-get update
    apt install -y chrony
    conf_file="/etc/chrony/chrony.conf"

    cat <<"EOF"> $conf_file
keyfile /etc/chrony/chrony.keys
commandkey 1
driftfile /var/lib/chrony/chrony.drift
log tracking measurements statistics
logdir /var/log/chrony
maxupdateskew 100.0
dumponexit
dumpdir /var/lib/chrony
local stratum 10
allow 10/8
allow 192.168/16
allow 172.16/12
allow 10.0.3.0/24
logchange 0.5
rtconutc
EOF

    echo "1 YOB0kNkh" > $conf_key
    service chrony restart
fi


#----------------------------------------------------------------------------------------------
# Begin to setup package
#----------------------------------------------------------------------------------------------

if [[ ! -e /etc/apt/sources.list.d/cloudarchive-mitaka.list || $force -gt 0 ]]; then
    apt-get -y update
    apt-get install -y software-properties-common
    add-apt-repository -y cloud-archive:mitaka
    apt-get -y update && apt-get -y dist-upgrade
    apt-get install -y python-openstackclient crudini ipcalc
    sed -i "/sleep/d" /etc/init/failsafe.conf
fi
export local_ip=$(ifconfig eth0 | grep "inet addr" | awk -F : '{print $2}' | awk '{print $1}')
export local_net=$(ipcalc -n $local_ip 255.255.255.0 | grep "Network" | awk '{print $2}')

#----------------------------------------------------------------------------------------------
# Begin to setup package
#----------------------------------------------------------------------------------------------


conf_file="/etc/mysql/my.cnf"

if [[ ! -e $conf_file || $force -gt 0 ]]; then
    apt install -y mariadb-server python-pymysql
    cd /etc/mysql
    find . -name "*.cnf" | xargs -i sed -i "s,utf8mb4,utf8,g" {}
    cp -rf $TOPDIR/my.conf $conf_file
    sed -i "s,127.0.0.1,0.0.0.0,g" $conf_file
    service mysql restart
fi

#----------------------------------------------------------------------------------------------
# Begin to setup memcached
#----------------------------------------------------------------------------------------------

conf_file="/etc/memcached.conf"
if [[ ! -e $conf_file || $force -gt 0 ]]; then
    apt install -y memcached python-memcache
    conf_file="/etc/memcached.conf"
    sed -i "s,127.0.0.1,0.0.0.0,g" $conf_file
    service memcached restart
fi


#----------------------------------------------------------------------------------------------
# Begin to setup rabbitmq
#----------------------------------------------------------------------------------------------

if [[ ! -e /etc/init.d/rabbitmq-server || $force -gt 0 ]]; then
    apt install -y rabbitmq-server
    rabbitmqctl add_user openstack RABBIT_PASS
    rabbitmqctl set_permissions openstack ".*" ".*" ".*"
fi


