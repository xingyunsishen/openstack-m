#!/bin/bash

export force="0"

export local_ip=$(ifconfig eth0 | grep "inet addr" | awk -F : '{print $2}' | awk '{print $1}')
export local_net=$(ipcalc -n $local_ip 255.255.255.0 | grep "Network" | awk '{print $2}')

TOPDIR=$(cd $(dirname "$0") && pwd)
cd $TOPDIR

[[ -e ./proxy ]] && . ./proxy


#----------------------------------------------------------------------------------------------
# Begin to setup neutron
#----------------------------------------------------------------------------------------------


    mysql -uroot -proot -e "drop database neutron;"

    cat <<"EOF">~/neutron.sql
CREATE DATABASE neutron;
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost' \
  IDENTIFIED BY 'NEUTRON_DBPASS';
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' \
  IDENTIFIED BY 'NEUTRON_DBPASS';
EOF

    mysql -uroot -proot < ~/neutron.sql

    . ~/adminrc
    openstack user create --domain default --password neutron neutron
    openstack role add --project service --user neutron admin
    openstack service create --name neutron \
      --description "OpenStack Networking" network

    openstack endpoint create --region RegionOne \
      network public http://controller:9696

    openstack endpoint create --region RegionOne \
      network internal http://controller:9696

    openstack endpoint create --region RegionOne \
      network admin http://controller:9696

    apt-get install -y neutron-server \
        neutron-plugin-ml2 neutron-l3-agent \
        neutron-dhcp-agent neutron-metadata-agent \
        neutron-plugin-ml2 neutron-plugin-openvswitch-agent \
        neutron-l3-agent neutron-dhcp-agent


    echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
    echo 'net.ipv4.conf.all.rp_filter=0' >> /etc/sysctl.conf
    echo 'net.ipv4.conf.default.rp_filter=0' >> /etc/sysctl.conf


    # Change the interface file
    ovs-vsctl add-br br-ex
    ovs-vsctl add-port br-ex eth0
    ovs-vsctl add-br br-tun

    ifdown eth0
    ifdown br-ex
    ifup br-ex


crudini --set /etc/neutron/neutron.conf DEFAULT auth_strategy keystone
crudini --set /etc/neutron/neutron.conf DEFAULT core_plugin ml2
crudini --set /etc/neutron/neutron.conf DEFAULT service_plugins router
crudini --set /etc/neutron/neutron.conf DEFAULT allow_overlapping_ips True
crudini --set /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_status_changes true
crudini --set /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_data_changes true
crudini --set /etc/neutron/neutron.conf DEFAULT verbose true
crudini --set /etc/neutron/neutron.conf DEFAULT rpc_backend rabbit
crudini --set /etc/neutron/neutron.conf DEFAULT api_workers 1
crudini --set /etc/neutron/neutron.conf DEFAULT rpc_workers 1
crudini --set /etc/neutron/neutron.conf nova auth_url http://controller:35357
crudini --set /etc/neutron/neutron.conf nova auth_type password
crudini --set /etc/neutron/neutron.conf nova project_domain_name default
crudini --set /etc/neutron/neutron.conf nova user_domain_name default
crudini --set /etc/neutron/neutron.conf nova region_name RegionOne
crudini --set /etc/neutron/neutron.conf nova project_name service
crudini --set /etc/neutron/neutron.conf nova username nova
crudini --set /etc/neutron/neutron.conf nova password nova
crudini --set /etc/neutron/neutron.conf agent root_helper "sudo /usr/bin/neutron-rootwrap /etc/neutron/rootwrap.conf"
crudini --set /etc/neutron/neutron.conf database connection mysql+pymysql://neutron:NEUTRON_DBPASS@controller/neutron
crudini --set /etc/neutron/neutron.conf keystone_authtoken auth_uri http://controller:5000
crudini --set /etc/neutron/neutron.conf keystone_authtoken auth_url http://controller:35357
crudini --set /etc/neutron/neutron.conf keystone_authtoken memcached_servers controller:11211
crudini --set /etc/neutron/neutron.conf keystone_authtoken auth_type password
crudini --set /etc/neutron/neutron.conf keystone_authtoken project_domain_name default
crudini --set /etc/neutron/neutron.conf keystone_authtoken user_domain_name default
crudini --set /etc/neutron/neutron.conf keystone_authtoken project_name service
crudini --set /etc/neutron/neutron.conf keystone_authtoken username neutron
crudini --set /etc/neutron/neutron.conf keystone_authtoken password neutron
crudini --set /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_host controller
crudini --set /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_userid openstack
crudini --set /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_password RABBIT_PASS

echo "dhcp-option-force=26,1450" > /etc/neutron/dnsmasq-neutron.conf
crudini --set /etc/neutron/dhcp_agent.ini DEFAULT verbose True
crudini --set /etc/neutron/dhcp_agent.ini DEFAULT interface_driver neutron.agent.linux.interface.OVSInterfaceDriver
crudini --set /etc/neutron/dhcp_agent.ini DEFAULT dhcp_driver neutron.agent.linux.dhcp.Dnsmasq
crudini --set /etc/neutron/dhcp_agent.ini DEFAULT enable_isolated_metadata True
crudini --set /etc/neutron/dhcp_agent.ini DEFAULT dnsmasq_config_file /etc/neutron/dnsmasq-neutron.conf
crudini --set /etc/neutron/l3_agent.ini DEFAULT verbose True
crudini --set /etc/neutron/l3_agent.ini DEFAULT interface_driver neutron.agent.linux.interface.OVSInterfaceDriver
crudini --set /etc/neutron/l3_agent.ini DEFAULT use_namespaces True
crudini --set /etc/neutron/l3_agent.ini DEFAULT external_network_bridge br-ex
crudini --set /etc/neutron/l3_agent.ini DEFAULT api_workers 1
crudini --set /etc/neutron/l3_agent.ini DEFAULT rpc_workers 1

crudini --set /etc/neutron/metadata_agent.ini DEFAULT verbose True
crudini --set /etc/neutron/metadata_agent.ini DEFAULT nova_metadata_ip controller
crudini --set /etc/neutron/metadata_agent.ini DEFAULT metadata_proxy_shared_secret METADATA_SECRET
crudini --set /etc/neutron/metadata_agent.ini DEFAULT metadata_workers 1

crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 type_drivers flat,gre,vxlan
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 tenant_network_types gre,vxlan
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 mechanism_drivers openvswitch,l2population
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 extension_drivers port_security
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_flat flat_networks external
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_gre tunnel_id_ranges 1:4096
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_vxlan vni_ranges 1:4096
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_ipset True
crudini --set /etc/neutron/plugins/ml2/openvswitch_agent.ini ovs local_ip 10.0.3.10
crudini --set /etc/neutron/plugins/ml2/openvswitch_agent.ini ovs bridge_mappings external:br-ex
crudini --set /etc/neutron/plugins/ml2/openvswitch_agent.ini agent tunnel_types gre,vxlan
crudini --set /etc/neutron/plugins/ml2/openvswitch_agent.ini agent l2_population True
crudini --set /etc/neutron/plugins/ml2/openvswitch_agent.ini agent prevent_arp_spoofing True
crudini --set /etc/neutron/plugins/ml2/openvswitch_agent.ini securitygroup firewall_driver neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver
crudini --set /etc/neutron/plugins/ml2/openvswitch_agent.ini securitygroup enable_security_group True
crudini --set /etc/nova/nova.conf neutron url http://controller:9696
crudini --set /etc/nova/nova.conf neutron auth_url http://controller:35357
crudini --set /etc/nova/nova.conf neutron auth_type password
crudini --set /etc/nova/nova.conf neutron project_domain_name default
crudini --set /etc/nova/nova.conf neutron user_domain_name default
crudini --set /etc/nova/nova.conf neutron region_name RegionOne
crudini --set /etc/nova/nova.conf neutron project_name service
crudini --set /etc/nova/nova.conf neutron username neutron
crudini --set /etc/nova/nova.conf neutron password neutron
crudini --set /etc/nova/nova.conf neutron service_metadata_proxy True
crudini --set /etc/nova/nova.conf neutron metadata_proxy_shared_secret METADATA_SECRET


su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf \
  --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron

service nova-api restart
service nova-compute restart
for service in server openvswitch-agent dhcp-agent metadata-agent l3-agent; do
    service neutron-$service restart
done
