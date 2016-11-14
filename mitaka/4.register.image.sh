#!/bin/bash

TOPDIR=$(cd $(dirname "$0") && pwd)

    . ~/adminrc
    glance image-list
    openstack image create "cirros" \
  --file $TOPDIR/lib/cirros-git-disk.qcow2 \
  --disk-format qcow2 --container-format bare \
  --public
