#!/bin/bash
# swiftaio_install.sh: create all-in-one swift install per the SAIO docs
# http://http://docs.openstack.org/developer/swift/development_saio.html
# usage
# create a user to run swift as (non-root)
# grant NOPASSWD:ALL privs in sudoers
# [username]	ALL=NOPASSWD:ALL
# become the user
# run the script with bash
# profit

# tested on Ubuntu 12.04, probably won't work on anything else 

if [[ `whoami` == "root" ]]; then
    echo "Script must be run as non-root user (with sudo privs)"
    exit
fi

if [[ $1 == "-h" || $1 == "--help" ]]; then
    echo "To use, run the script as a user that has NOPASSWD sudo privileges"
    echo "This user will be your swift user"
fi

SWIFT_USER=`id -un`
SWIFT_GROUP=`id -gn`

sudo apt-get update
sudo apt-get install -y curl gcc memcached rsync sqlite3 xfsprogs git-core libffi-dev python-setuptools
sudo apt-get install -y python-coverage python-dev python-nose python-simplejson python-xattr python-eventlet python-greenlet python-pastedeploy python-netifaces python-pip python-dnspython python-mock
sudo mkdir /srv
sudo dd if=/dev/zero of=/srv/swift-disk bs=1024 count=0 seek=2000000
sudo mkfs.xfs -i size=1024 /srv/swift-disk
cat <<EOF |sudo tee -a /etc/fstab
/srv/swift-disk /mnt/sdb1 xfs loop,noatime,nodiratime,nobarrier,logbufs=8 0 0
EOF
sudo mkdir /mnt/sdb1
sudo mount -a
sudo mkdir /mnt/sdb1/1 /mnt/sdb1/2 /mnt/sdb1/3 /mnt/sdb1/4
sudo chown -R $SWIFT_USER:$SWIFT_GROUP /mnt/sdb1
sudo ln -s /mnt/sdb1/1 /srv/1
sudo ln -s /mnt/sdb1/2 /srv/2
sudo ln -s /mnt/sdb1/3 /srv/3
sudo ln -s /mnt/sdb1/4 /srv/4
sudo mkdir -p /etc/swift/object-server /etc/swift/container-server /etc/swift/account-server /srv/1/node/sdb1 /srv/2/node/sdb2 /srv/3/node/sdb3 /srv/4/node/sdb4 /var/run/swift
sudo chown -R $SWIFT_USER:$SWIFT_GROUP /etc/swift /srv/[1-4]/ /var/run/swift

# rc.local
cat << EOF|sudo tee -a /etc/rc.local
mkdir -p /var/cache/swift /var/cache/swift2 /var/cache/swift3 /var/cache/swift4
chown $SWIFT_USER:$SWIFT_GROUP /var/cache/swift*
mkdir -p /var/run/swift
chown $SWIFT_USER:$SWIFT_GROUP /var/run/swift
EOF

# rsync.d
cat << EOF|sudo tee /etc/rsyncd.conf
uid = $SWIFT_USER
gid = $SWIFT_GROUP
log file = /var/log/rsyncd.log
pid file = /var/run/rsyncd.pid
address = 127.0.0.1

[account6012]
max connections = 25
path = /srv/1/node/
read only = false
lock file = /var/lock/account6012.lock

[account6022]
max connections = 25
path = /srv/2/node/
read only = false
lock file = /var/lock/account6022.lock

[account6032]
max connections = 25
path = /srv/3/node/
read only = false
lock file = /var/lock/account6032.lock

[account6042]
max connections = 25
path = /srv/4/node/
read only = false
lock file = /var/lock/account6042.lock


[container6011]
max connections = 25
path = /srv/1/node/
read only = false
lock file = /var/lock/container6011.lock

[container6021]
max connections = 25
path = /srv/2/node/
read only = false
lock file = /var/lock/container6021.lock

[container6031]
max connections = 25
path = /srv/3/node/
read only = false
lock file = /var/lock/container6031.lock

[container6041]
max connections = 25
path = /srv/4/node/
read only = false
lock file = /var/lock/container6041.lock


[object6010]
max connections = 25
path = /srv/1/node/
read only = false
lock file = /var/lock/object6010.lock

[object6020]
max connections = 25
path = /srv/2/node/
read only = false
lock file = /var/lock/object6020.lock

[object6030]
max connections = 25
path = /srv/3/node/
read only = false
lock file = /var/lock/object6030.lock

[object6040]
max connections = 25
path = /srv/4/node/
read only = false
lock file = /var/lock/object6040.lock
EOF

sudo sed -i "s/RSYNC_ENABLE=false/RSYNC_ENABLE=true/" /etc/default/rsync 
sudo service rsync restart

# swift rsyslog config
cat <<EOF|sudo tee /etc/rsyslog.d/10-swift.conf
# Uncomment the following to have a log containing all logs together
#local1,local2,local3,local4,local5.*   /var/log/swift/all.log

# Uncomment the following to have hourly proxy logs for stats processing
#$template HourlyProxyLog,"/var/log/swift/hourly/%$YEAR%%$MONTH%%$DAY%%$HOUR%"
#local1.*;local1.!notice ?HourlyProxyLog

local1.*;local1.!notice /var/log/swift/proxy.log
local1.notice           /var/log/swift/proxy.error
local1.*                ~

local2.*;local2.!notice /var/log/swift/storage1.log
local2.notice           /var/log/swift/storage1.error
local2.*                ~

local3.*;local3.!notice /var/log/swift/storage2.log
local3.notice           /var/log/swift/storage2.error
local3.*                ~

local4.*;local4.!notice /var/log/swift/storage3.log
local4.notice           /var/log/swift/storage3.error
local4.*                ~

local5.*;local5.!notice /var/log/swift/storage4.log
local5.notice           /var/log/swift/storage4.error
local5.*                ~
EOF

sudo sed -i "s/\$PrivDropToGroup syslog/\$PrivDropToGroup adm/" /etc/rsyslog.conf
sudo mkdir -p /var/log/swift/hourly
sudo chown -R $SWIFT_USER.adm /var/log/swift
sudo chmod -R g+w /var/log/swift
sudo service rsyslog restart
sudo mkdir -p /var/cache/swift
sudo chown $SWIFT_USER:$SWIFT_GROUP /var/cache/swift

mkdir ~/bin
git clone https://github.com/openstack/swift.git
cd ~/swift
sudo python setup.py install
cd ..
git clone https://github.com/openstack/python-swiftclient.git
cd ~/python-swiftclient
sudo python setup.py install
cd ..
sudo pip install -r swift/test-requirements.txt
cd /
sudo pip install --upgrade pbr

# .bashrc
cat >> ~/.bashrc <<EOF
export SWIFT_TEST_CONFIG_FILE=/etc/swift/test.conf
export PATH=\$PATH:~/bin
EOF

export SWIFT_TEST_CONFIG_FILE=/etc/swift/test.conf
export PATH=${PATH}:~/bin

# swift proxy server config
cat >/etc/swift/proxy-server.conf <<EOF
[DEFAULT]
bind_port = 8080
user = $SWIFT_USER
log_facility = LOG_LOCAL1

[pipeline:main]
pipeline = healthcheck cache tempauth proxy-logging proxy-server

[app:proxy-server]
use = egg:swift#proxy
allow_account_management = true
account_autocreate = true

[filter:tempauth]
use = egg:swift#tempauth
user_admin_admin = admin .admin .reseller_admin
user_test_tester = testing .admin
user_test2_tester2 = testing2 .admin
user_test_tester3 = testing3

[filter:healthcheck]
use = egg:swift#healthcheck

[filter:cache]
use = egg:swift#memcache

[filter:proxy-logging]
use = egg:swift#proxy_logging
EOF

# swift config
cat >/etc/swift/swift.conf <<EOF
[swift-hash]
# random unique string that can never change (DO NOT LOSE)
swift_hash_path_suffix = swiftftw
EOF

# account server configs
cat >/etc/swift/account-server/1.conf <<EOF
[DEFAULT]
devices = /srv/1/node
mount_check = false
disable_fallocate = true
bind_port = 6012
user = $SWIFT_USER
log_facility = LOG_LOCAL2
recon_cache_path = /var/cache/swift

[pipeline:main]
pipeline = recon account-server

[app:account-server]
use = egg:swift#account

[filter:recon]
use = egg:swift#recon

[account-replicator]
vm_test_mode = yes

[account-auditor]

[account-reaper]
EOF

cd /etc/swift/account-server
for i in 2 3 4;do cp 1.conf $i.conf;done;

# fix devices
sed -i "s/srv\/1/srv\/2/" 2.conf
sed -i "s/srv\/1/srv\/3/" 3.conf
sed -i "s/srv\/1/srv\/4/" 4.conf

# fix ports
sed -i "s/6012/6022/" 2.conf
sed -i "s/6012/6032/" 3.conf
sed -i "s/6012/6042/" 4.conf

# fix log facility
sed -i "s/LOCAL2/LOCAL3/" 2.conf
sed -i "s/LOCAL2/LOCAL4/" 3.conf
sed -i "s/LOCAL2/LOCAL5/" 4.conf

# fix cache path
sed -i "s/cache\/swift/cache\/swift2/" 2.conf
sed -i "s/cache\/swift/cache\/swift3/" 3.conf
sed -i "s/cache\/swift/cache\/swift4/" 4.conf

# container server configs
cd -
cd /etc/swift/container-server

cat >/etc/swift/container-server/1.conf <<EOF
[DEFAULT]
devices = /srv/1/node
mount_check = false
disable_fallocate = true
bind_port = 6011
user = $SWIFT_USER
log_facility = LOG_LOCAL2
recon_cache_path = /var/cache/swift

[pipeline:main]
pipeline = recon container-server

[app:container-server]
use = egg:swift#container

[filter:recon]
use = egg:swift#recon

[container-replicator]
vm_test_mode = yes

[container-updater]

[container-auditor]

[container-sync]
EOF

for i in 2 3 4;do cp 1.conf $i.conf;done;
# fix devices
sed -i "s/srv\/1/srv\/2/" 2.conf
sed -i "s/srv\/1/srv\/3/" 3.conf
sed -i "s/srv\/1/srv\/4/" 4.conf

# fix ports
sed -i "s/6011/6021/" 2.conf
sed -i "s/6011/6031/" 3.conf
sed -i "s/6011/6041/" 4.conf

# fix log facility
sed -i "s/LOCAL2/LOCAL3/" 2.conf
sed -i "s/LOCAL2/LOCAL4/" 3.conf
sed -i "s/LOCAL2/LOCAL5/" 4.conf

# object server config
cd -
cd /etc/swift/object-server
cat >/etc/swift/object-server/1.conf <<EOF
[DEFAULT]
devices = /srv/1/node
mount_check = false
disable_fallocate = true
bind_port = 6010
user = $SWIFT_USER
log_facility = LOG_LOCAL2
recon_cache_path = /var/cache/swift

[pipeline:main]
pipeline = recon object-server

[app:object-server]
use = egg:swift#object

[filter:recon]
use = egg:swift#recon

[object-replicator]
vm_test_mode = yes

[object-updater]

[object-auditor]
EOF

for i in 2 3 4;do cp 1.conf $i.conf;done;
# fix devices
sed -i "s/srv\/1/srv\/2/" 2.conf
sed -i "s/srv\/1/srv\/3/" 3.conf
sed -i "s/srv\/1/srv\/4/" 4.conf

# fix ports
sed -i "s/6010/6020/" 2.conf
sed -i "s/6010/6030/" 3.conf
sed -i "s/6010/6040/" 4.conf

# fix log facility
sed -i "s/LOCAL2/LOCAL3/" 2.conf
sed -i "s/LOCAL2/LOCAL4/" 3.conf
sed -i "s/LOCAL2/LOCAL5/" 4.conf

cd -

# scripts
# resetswift
# mkdir was missing
cat >~/bin/resetswift << EOF
#!/bin/bash

swift-init all stop
find /var/log/swift -type f -exec rm -f {} \;
sudo umount /srv/swift-disk
sudo mkfs.xfs -f -i size=1024 /srv/swift-disk
sudo mount /srv/swift-disk
sudo mkdir /mnt/sdb1/1 /mnt/sdb1/2 /mnt/sdb1/3 /mnt/sdb1/4
sudo chown $SWIFT_USER:$SWIFT_GROUP /mnt/sdb1/*
mkdir -p /srv/1/node/sdb1 /srv/2/node/sdb2 /srv/3/node/sdb3 /srv/4/node/sdb4
sudo rm -f /var/log/debug /var/log/messages /var/log/rsyncd.log /var/log/syslog
find /var/cache/swift* -type f -name *.recon -exec rm -f {} \;
sudo service rsyslog restart
sudo service memcached restart
EOF

# remakerings
cat >~/bin/remakerings << EOF
#!/bin/bash

cd /etc/swift

rm -f *.builder *.ring.gz backups/*.builder backups/*.ring.gz

swift-ring-builder object.builder create 18 3 1
swift-ring-builder object.builder add z1-127.0.0.1:6010/sdb1 1
swift-ring-builder object.builder add z2-127.0.0.1:6020/sdb2 1
swift-ring-builder object.builder add z3-127.0.0.1:6030/sdb3 1
swift-ring-builder object.builder add z4-127.0.0.1:6040/sdb4 1
swift-ring-builder object.builder rebalance
swift-ring-builder container.builder create 18 3 1
swift-ring-builder container.builder add z1-127.0.0.1:6011/sdb1 1
swift-ring-builder container.builder add z2-127.0.0.1:6021/sdb2 1
swift-ring-builder container.builder add z3-127.0.0.1:6031/sdb3 1
swift-ring-builder container.builder add z4-127.0.0.1:6041/sdb4 1
swift-ring-builder container.builder rebalance
swift-ring-builder account.builder create 18 3 1
swift-ring-builder account.builder add z1-127.0.0.1:6012/sdb1 1
swift-ring-builder account.builder add z2-127.0.0.1:6022/sdb2 1
swift-ring-builder account.builder add z3-127.0.0.1:6032/sdb3 1
swift-ring-builder account.builder add z4-127.0.0.1:6042/sdb4 1
swift-ring-builder account.builder rebalance
EOF

# startmain
cat >~/bin/startmain <<EOF
#!/bin/bash

swift-init main start
EOF

# startrest
cat >~/bin/startrest <<EOF
#!/bin/bash

swift-init rest start
EOF

chmod +x ~/bin/*

~/bin/remakerings

echo "Running unit tests"
cd ~/swift
./.unittests

echo "Starting Swift"
~/bin/startmain

echo "Test auth: "
curl -v -H 'X-Storage-User: test:tester' -H 'X-Storage-Pass: testing' http://127.0.0.1:8080/auth/v1.0 &>/tmp/authtest.swift
cat /tmp/authtest.swift

authurl=`grep X-Storage-Url /tmp/authtest.swift|cut -d' ' -f3-`

authtoken=`grep X-Auth-Token /tmp/authtest.swift|cut -d' ' -f2-`
rm -f /tmp/authtest.swift

echo "Test get: "
curl -v -H "$authtoken" $authurl

cp ~/swift/test/sample.conf /etc/swift/test.conf



