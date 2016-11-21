#!/bin/bash

export force="0"

export local_ip=$(ifconfig eth1 | grep "inet addr" | awk -F : '{print $2}' | awk '{print $1}')
export local_net=$(ipcalc -n $local_ip 255.255.255.0 | grep "Network" | awk '{print $2}')

TOPDIR=$(cd $(dirname "$0") && pwd)
cd $TOPDIR

[[ -e ./proxy ]] && . ./proxy


#----------------------------------------------------------------------------------------------
# Begin to setup keystone
#----------------------------------------------------------------------------------------------

if [[ ! -e /etc/keystone/keystone.conf || $force -gt 0 ]]; then
    mysql -uroot -proot -e "drop database keystone;"

    cat <<"EOF"> ~/keystone.sql
CREATE DATABASE keystone;
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY 'KEYSTONE_DBPASS';
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY 'KEYSTONE_DBPASS';
EOF

    mysql -uroot -proot < ~/keystone.sql
    apt install -y keystone
    crudini --set /etc/keystone/keystone.conf DEFAULT admin_token ADMIN_TOKEN
    crudini --set /etc/keystone/keystone.conf database connection mysql://keystone:KEYSTONE_DBPASS@controller/keystone
    crudini --set /etc/keystone/keystone.conf memcache servers localhost:11211
    crudini --set /etc/keystone/keystone.conf token provider keystone.token.providers.uuid.Provider
    crudini --set /etc/keystone/keystone.conf token driver keystone.token.persistence.backends.memcache.Token
    crudini --set /etc/keystone/keystone.conf revoke driver keystone.contrib.revoke.backends.sql.Revoke
    crudini --set /etc/keystone/keystone.conf DEFAULT verbose True
    crudini --set /etc/keystone/keystone.conf DEFAULT public_workers 1
    crudini --set /etc/keystone/keystone.conf DEFAULT admin_workers 1
    su -s /bin/sh -c "keystone-manage db_sync" keystone
    keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
    keystone-manage credential_setup --keystone-user keystone --keystone-group keystone

    keystone-manage bootstrap --bootstrap-password admin \
      --bootstrap-admin-url http://controller:35357/v3/ \
      --bootstrap-internal-url http://controller:35357/v3/ \
      --bootstrap-public-url http://controller:5000/v3/ \
      --bootstrap-region-id RegionOne

    service keystone restart

cat <<"EOF">~/adminrc
unset OS_USERNAME
unset OS_PASSWORD
unset OS_PROJECT_NAME
unset OS_USER_DOMAIN_NAME
unset OS_PROJECT_DOMAIN_NAME
unset OS_AUTH_URL
unset OS_IDENTITY_API_VERSION
unset OS_TOKEN
unset OS_URL

export OS_USERNAME=admin
export OS_PASSWORD=admin
export OS_PROJECT_NAME=admin
export OS_USER_DOMAIN_NAME=default
export OS_PROJECT_DOMAIN_NAME=default
export OS_AUTH_URL=http://controller:35357/v3
export OS_IDENTITY_API_VERSION=3
export PS1="adminrc\u@\h:\w\$ "
EOF

cat <<"EOF">~/rootrc
unset OS_USERNAME
unset OS_PASSWORD
unset OS_PROJECT_NAME
unset OS_USER_DOMAIN_NAME
unset OS_PROJECT_DOMAIN_NAME
unset OS_AUTH_URL
unset OS_IDENTITY_API_VERSION
unset OS_TOKEN
unset OS_URL

export OS_TOKEN=ADMIN_TOKEN
export OS_URL=http://controller:35357/v3
export OS_IDENTITY_API_VERSION=3
export PS1="rootrc\u@\h:\w\$ "
EOF

cat <<"EOF">~/demorc
unset OS_USERNAME
unset OS_PASSWORD
unset OS_PROJECT_NAME
unset OS_USER_DOMAIN_NAME
unset OS_PROJECT_DOMAIN_NAME
unset OS_AUTH_URL
unset OS_IDENTITY_API_VERSION
unset OS_TOKEN
unset OS_URL

export OS_USERNAME=demo
export OS_PASSWORD=demo
export OS_PROJECT_NAME=demo
export OS_USER_DOMAIN_NAME=default
export OS_PROJECT_DOMAIN_NAME=default
export OS_AUTH_URL=http://controller:35357/v3
export OS_IDENTITY_API_VERSION=3
export PS1="demorc\u@\h:\w\$ "
EOF

    # begin to initial the keystone settings.
    . ~/adminrc

    openstack project create --domain default \
  --description "Service Project" service

    openstack project create --domain default \
  --description "Demo Project" demo
    openstack user create --domain default \
  --password demo demo

    openstack role create user
    openstack role add --project demo --user demo user

fi
