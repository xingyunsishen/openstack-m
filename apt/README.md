# OpenStack开源云M版实战

# 制作离线源命令
安装了所有需要的各种安装包:

```
apt-get install dpkg-dev
```

再安装需要打包的离线源的包，比如glance。

```
apt-get install glance
```

制作离线包
```
cd /var/cache/apt/
mkdir -p /opt/mitaka/debian
find . -name “*.deb” | xargs -i cp -rf {} /opt/mitaka/debian/
cd /opt/mitaka
dpkg-scanpackages debian /dev/null | gzip > debian/Packages.gz
```

# 使用离线源
目录位于/opt/mitaka

修改源文件为：

```
deb file:///opt/mitaka debian/
```

运行

```
apt-get update
```

# 公有源的包
如果是想使用公有源的包：

```
apt-get install software-properties-common
add-apt-repository cloud-archive:mitaka
apt-get update && apt-get dist-upgrade
更新完成之后，reboot

```
