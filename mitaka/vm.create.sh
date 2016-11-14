#!/bin/bash

openstack flavor create --id 0 --vcpus 1 --ram 64 --disk 1 m1.nano
openstack keypair create --public-key ~/.ssh/id_rsa.pub mykey
openstack security group rule create --proto icmp default
openstack security group rule create --proto tcp --dst-port 22 default
openstack image list
openstack flavor list
openstack network list
openstack security group list
openstack server list

SELFSERVICE_NET_ID="471a6e9a-ca0a-472a-a71b-fbd58790e6c6"
openstack server create --flavor m1.nano --image cirros \
  --nic net-id=$SELFSERVICE_NET_ID --security-group default \
  --key-name mykey testvm

