#!/bin/bash

export force="0"

export local_ip=$(ifconfig eth0 | grep "inet addr" | awk -F : '{print $2}' | awk '{print $1}')
export local_net=$(ipcalc -n $local_ip 255.255.255.0 | grep "Network" | awk '{print $2}')

TOPDIR=$(cd $(dirname "$0") && pwd)
cd $TOPDIR

[[ -e ./proxy ]] && . ./proxy

#----------------------------------------------------------------------------------------------
# Begin to setup glance
#----------------------------------------------------------------------------------------------

if [[ ! -e /etc/glance/glance-api.conf || $force -gt 0 ]]; then

    mysql -uroot -proot -e "drop database glance;"

    cat <<"EOF"> ~/glance.sql
CREATE DATABASE glance;
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY 'GLANCE_DBPASS';
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY 'GLANCE_DBPASS';
EOF

    mysql -uroot -proot < ~/glance.sql
    . ~/adminrc
    openstack user create --domain default --password glance glance
    openstack role add --project service --user glance admin
    openstack service create --name glance \
      --description "OpenStack Image" image
    openstack endpoint create --region RegionOne \
      image public http://controller:9292
    openstack endpoint create --region RegionOne \
      image internal http://controller:9292
    openstack endpoint create --region RegionOne \
      image admin http://controller:9292

    apt-get install -y glance

crudini --set /etc/glance/glance-api.conf database connection mysql+pymysql://glance:GLANCE_DBPASS@controller/glance
crudini --set /etc/glance/glance-api.conf keystone_authtoken auth_uri http://controller:5000
crudini --set /etc/glance/glance-api.conf keystone_authtoken auth_url http://controller:35357
crudini --set /etc/glance/glance-api.conf keystone_authtoken memcached_servers controller:11211
crudini --set /etc/glance/glance-api.conf keystone_authtoken auth_type password
crudini --set /etc/glance/glance-api.conf keystone_authtoken project_domain_name default
crudini --set /etc/glance/glance-api.conf keystone_authtoken user_domain_name default
crudini --set /etc/glance/glance-api.conf keystone_authtoken project_name service
crudini --set /etc/glance/glance-api.conf keystone_authtoken username glance
crudini --set /etc/glance/glance-api.conf keystone_authtoken password glance
crudini --set /etc/glance/glance-api.conf paste_deploy flavor keystone
crudini --set /etc/glance/glance-api.conf glance_store stores file,http
crudini --set /etc/glance/glance-api.conf glance_store default_store file
crudini --set /etc/glance/glance-api.conf glance_store filesystem_store_datadir /var/lib/glance/images/
crudini --set /etc/glance/glance-api.conf DEFAULT workers 1

crudini --set /etc/glance/glance-registry.conf database connection mysql+pymysql://glance:GLANCE_DBPASS@controller/glance
crudini --set /etc/glance/glance-registry.conf keystone_authtoken auth_uri http://controller:5000
crudini --set /etc/glance/glance-registry.conf keystone_authtoken auth_url http://controller:35357
crudini --set /etc/glance/glance-registry.conf keystone_authtoken memcached_servers controller:11211
crudini --set /etc/glance/glance-registry.conf keystone_authtoken auth_type password
crudini --set /etc/glance/glance-registry.conf keystone_authtoken project_domain_name default
crudini --set /etc/glance/glance-registry.conf keystone_authtoken user_domain_name default
crudini --set /etc/glance/glance-registry.conf keystone_authtoken project_name service
crudini --set /etc/glance/glance-registry.conf keystone_authtoken username glance
crudini --set /etc/glance/glance-registry.conf keystone_authtoken password glance
crudini --set /etc/glance/glance-registry.conf paste_deploy flavor keystone
crudini --set /etc/glance/glance-registry.conf DEFAULT workers 1

    su -s /bin/sh -c "glance-manage db_sync" glance
    service glance-registry restart
    service glance-api restart

fi


