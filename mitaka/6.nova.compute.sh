#!/bin/bash

export force="0"

export local_ip=$(ifconfig eth0 | grep "inet addr" | awk -F : '{print $2}' | awk '{print $1}')
export local_net=$(ipcalc -n $local_ip 255.255.255.0 | grep "Network" | awk '{print $2}')

TOPDIR=$(cd $(dirname "$0") && pwd)
cd $TOPDIR

[[ -e ./proxy ]] && . ./proxy


#----------------------------------------------------------------------------------------------
# Begin to setup nova-compute
#----------------------------------------------------------------------------------------------

if [[ ! -e /etc/nova/nova-compute.conf || $force -gt 0 ]]; then
    apt-get install -y nova-compute

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
crudini --set /etc/nova/nova.conf DEFAULT use_neutron True
crudini --set /etc/nova/nova.conf DEFAULT firewall_driver nova.virt.firewall.NoopFirewallDriver
crudini --set /etc/nova/nova.conf vnc enabled True
crudini --set /etc/nova/nova.conf vnc vncserver_listen 0.0.0.0
crudini --set /etc/nova/nova.conf vnc vncserver_proxyclient_address $local_ip
crudini --set /etc/nova/nova.conf vnc novncproxy_base_url http://controller:6080/vnc_auto.html
crudini --set /etc/nova/nova.conf glance api_servers http://controller:9292
crudini --set /etc/nova/nova.conf oslo_concurrency lock_path /var/lib/nova/tmp
crudini --set /etc/nova/nova.conf DEFAULT compute_driver libvirt.LibvirtDriver
    cat <<"EOF">/etc/nova/nova-compute.conf
[libvirt]
virt_type = qemu
EOF

service nova-compute restart
fi

