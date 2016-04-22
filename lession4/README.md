# Keystone安装步骤

# 安装
echo "manual" > /etc/init/keystone.override
apt-get install keystone apache2 libapache2-mod-wsgi

# 修改配置
/etc/keystone/keystone.conf
admin_token = ADMIN_TOKEN
connection = mysql+pymysql://keystone:keystone@10.149.240.44/keystone?charset=utf8
provider = fernet

# 初始化数据库

su -s /bin/sh -c "keystone-manage db_sync" keystone

# 初始化fernet
keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone

# 修改Aapche
配置文件位于：/etc/apache2/sites-available/wsgi-keystone.conf

```
Listen 5000
Listen 35357

<VirtualHost *:5000>
    WSGIDaemonProcess keystone-public processes=5 threads=1 user=keystone group=keystone display-name=%{GROUP}
    WSGIProcessGroup keystone-public
    WSGIScriptAlias / /usr/bin/keystone-wsgi-public
    WSGIApplicationGroup %{GLOBAL}
    WSGIPassAuthorization On
    ErrorLogFormat "%{cu}t %M"
    ErrorLog /var/log/apache2/keystone.log
    CustomLog /var/log/apache2/keystone_access.log combined

    <Directory /usr/bin>
        Require all granted
    </Directory>
</VirtualHost>

<VirtualHost *:35357>
    WSGIDaemonProcess keystone-admin processes=5 threads=1 user=keystone group=keystone display-name=%{GROUP}
    WSGIProcessGroup keystone-admin
    WSGIScriptAlias / /usr/bin/keystone-wsgi-admin
    WSGIApplicationGroup %{GLOBAL}
    WSGIPassAuthorization On
    ErrorLogFormat "%{cu}t %M"
    ErrorLog /var/log/apache2/keystone.log
    CustomLog /var/log/apache2/keystone_access.log combined

    <Directory /usr/bin>
        Require all granted
    </Directory>
</VirtualHost>
```

## 设置软链接
```
ln -s /etc/apache2/sites-available/wsgi-keystone.conf /etc/apache2/sites-enabled
```

## 启动服务

```
service keystone stop
service apache2 restart
```

