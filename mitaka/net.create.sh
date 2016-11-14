#!/bin/bash


neutron net-create ext-net --router:external True   --provider:physical_network external --provider:network_type flat
neutron subnet-create ext-net --name ext-subnet --allocation-pool \
  start=192.168.211.101,end=192.168.211.200 --disable-dhcp --dns-nameserver 114.114.114.114 \
  --gateway 192.168.211.1 192.168.211.0/24
neutron net-create demo-net  --provider:network_type gre

neutron subnet-create demo-net \
    --name demo-subnet \
    --dns-nameserver 114.114.114.114 \
    --gateway 192.168.1.1 192.168.1.0/24

neutron net-update ext-net --router:external
neutron router-create demo-router
neutron router-interface-add demo-router demo-subnet
neutron router-gateway-set demo-router ext-net
neutron router-port-list demo-router
