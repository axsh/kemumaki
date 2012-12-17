#!/bin/bash
#
# requires:
#  bash
#  chroot
#
set -x
set -e

echo "doing execscript.sh: $1"

cat <<'EOS' | chroot $1 bash -c "cat | bash"
## change root passwd
echo root:root | chpasswd

## yum repositories
yum install -y http://ftp.riken.jp/Linux/fedora/epel/6/x86_64/epel-release-6-7.noarch.rpm

yum clean metadata --disablerepo=* --enablerepo=wakame-vdc-rhel6
yum update  -y --disablerepo=* --enablerepo=wakame-vdc-rhel6
yum install -y wakame-vdc-dcmgr-vmapp-config
yum install -y wakame-vdc-admin-vmapp-config
yum install -y wakame-vdc-vdcsh

## instlall package
distro_pkgs="
 vim-minimal
 screen
 git
 make
 sudo
"
yum install -y ${distro_pkgs}


## configure wakame-vdc

mkdir -p /etc/wakame-vdc
mkdir -p /etc/wakame-vdc/convert_specs
mkdir -p /etc/wakame-vdc/dcmgr_gui
mkdir -p /etc/wakame-vdc/admin

nodes="
 admin
 auth
 collector
 dcmgr
 metadata
 proxy
 webui
"
for node in ${nodes}; do
  sed -i -e 's/^#\(RUN=yes\)/\1/' /etc/default/vdc-${node}
done


/sbin/chkconfig       ntpd on
/sbin/chkconfig       ntpdate on
/sbin/chkconfig --add mysqld
/sbin/chkconfig       mysqld on
/sbin/chkconfig --add rabbitmq-server
/sbin/chkconfig       rabbitmq-server on

cp -f /opt/axsh/wakame-vdc/dcmgr/config/dcmgr.conf.example /etc/wakame-vdc/dcmgr.conf
cp -f /opt/axsh/wakame-vdc/frontend/dcmgr_gui/config/database.yml.example /etc/wakame-vdc/dcmgr_gui/database.yml
cp -f /opt/axsh/wakame-vdc/frontend/dcmgr_gui/config/dcmgr_gui.yml.example /etc/wakame-vdc/dcmgr_gui/dcmgr_gui.yml
cp -f /opt/axsh/wakame-vdc/frontend/dcmgr_gui/config/instance_spec.yml.example /etc/wakame-vdc/dcmgr_gui/instance_spec.yml
cp -f /opt/axsh/wakame-vdc/frontend/dcmgr_gui/config/load_balancer_spec.yml.example /etc/wakame-vdc/dcmgr_gui/load_balancer_spec.yml
cp -f /opt/axsh/wakame-vdc/dcmgr/config/convert_specs/load_balancer.yml.example /etc/wakame-vdc/convert_specs/load_balancer.yml
cp -f /opt/axsh/wakame-vdc/frontend/admin/config/admin.yml.example /etc/wakame-vdc/admin/admin.yml
echo "$(eval "echo \"$(cat /opt/axsh/wakame-vdc/tests/vdc.sh.d/proxy.conf.tmpl)\"")" > /etc/wakame-vdc/proxy.conf

# data initialization
#echo "vdc_data=/opt/axsh/wakame-vdc /opt/axsh/wakame-vdc/tests/vdc.sh init" >> /etc/rc.local

# notification
(cd /opt/axsh; git clone https://github.com/caquino/redis-bash.git)
echo "/opt/axsh/redis-bash/redis-bash-cli -h redis-server publish \$(hostname) ready" >> /etc/rc.local

# change proxy path
# TODO prepare webdav server for vdc-proxy
sed -i -e "s/localhost/amqp-server/" /opt/axsh/wakame-vdc/tests/vdc.sh.d/demodata_images.sh

EOS
