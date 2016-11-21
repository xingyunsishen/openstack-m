#!/bin/bash

export force="0"

export local_ip=$(ifconfig eth1 | grep "inet addr" | awk -F : '{print $2}' | awk '{print $1}')
export local_net=$(ipcalc -n $local_ip 255.255.255.0 | grep "Network" | awk '{print $2}')

TOPDIR=$(cd $(dirname "$0") && pwd)
cd $TOPDIR

[[ -e ./proxy ]] && . ./proxy


#----------------------------------------------------------------------------------------------
# Begin to setup nova api
#----------------------------------------------------------------------------------------------

if [[ ! -e /etc/nova/nova.conf || $force -gt 0 ]]; then

    mysql -uroot -proot -e "drop database nova_api;"
    mysql -uroot -proot -e "drop database nova;"

    cat <<"EOF">~/nova.sql
CREATE DATABASE nova_api;
CREATE DATABASE nova;
GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'localhost' IDENTIFIED BY 'NOVA_DBPASS';
GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'%' IDENTIFIED BY 'NOVA_DBPASS';
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY 'NOVA_DBPASS';
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY 'NOVA_DBPASS';
EOF

    mysql -uroot -proot < ~/nova.sql

    . ~/adminrc
    openstack user create --domain default \
  --password nova nova
    openstack role add --project service --user nova admin
    openstack service create --name nova \
  --description "OpenStack Compute" compute

    openstack endpoint create --region RegionOne \
  compute public http://controller:8774/v2.1/%\(tenant_id\)s

    openstack endpoint create --region RegionOne \
  compute internal http://controller:8774/v2.1/%\(tenant_id\)s

    openstack endpoint create --region RegionOne \
  compute admin http://controller:8774/v2.1/%\(tenant_id\)s

    apt install -y nova-api nova-conductor nova-consoleauth \
  nova-novncproxy nova-scheduler

crudini --set /etc/nova/nova.conf DEFAULT enabled_apis osapi_compute,metadata
crudini --set /etc/nova/nova.conf api_database connection mysql+pymysql://nova:NOVA_DBPASS@controller/nova_api
crudini --set /etc/nova/nova.conf database connection mysql+pymysql://nova:NOVA_DBPASS@controller/nova
crudini --set /etc/nova/nova.conf DEFAULT rpc_backend rabbit
crudini --set /etc/nova/nova.conf oslo_messaging_rabbit rabbit_host controller
crudini --set /etc/nova/nova.conf oslo_messaging_rabbit rabbit_userid openstack
crudini --set /etc/nova/nova.conf oslo_messaging_rabbit rabbit_password RABBIT_PASS
crudini --set /etc/nova/nova.conf DEFAULT auth_strategy keystone
crudini --set /etc/nova/nova.conf keystone_authtoken auth_uri http://controller:5000
crudini --set /etc/nova/nova.conf keystone_authtoken auth_url http://controller:35357
crudini --set /etc/nova/nova.conf keystone_authtoken memcached_servers controller:11211
crudini --set /etc/nova/nova.conf keystone_authtoken auth_type password
crudini --set /etc/nova/nova.conf keystone_authtoken project_domain_name default
crudini --set /etc/nova/nova.conf keystone_authtoken user_domain_name default
crudini --set /etc/nova/nova.conf keystone_authtoken project_name service
crudini --set /etc/nova/nova.conf keystone_authtoken username nova
crudini --set /etc/nova/nova.conf keystone_authtoken password nova
crudini --set /etc/nova/nova.conf DEFAULT my_ip $local_ip
crudini --set /etc/nova/nova.conf DEFAULT use_neutron True
crudini --set /etc/nova/nova.conf DEFAULT firewall_driver nova.virt.firewall.NoopFirewallDriver
crudini --set /etc/nova/nova.conf vnc vncserver_listen $local_ip
crudini --set /etc/nova/nova.conf vnc vncserver_proxyclient_address $local_ip
crudini --set /etc/nova/nova.conf glance api_servers http://controller:9292
crudini --set /etc/nova/nova.conf oslo_concurrency lock_path /var/lib/nova/tmp

    su -s /bin/sh -c "nova-manage api_db sync" nova
    su -s /bin/sh -c "nova-manage db sync" nova

    service nova-api restart
    service nova-consoleauth restart
    service nova-scheduler restart
    service nova-conductor restart
    service nova-novncproxy restart
fi

