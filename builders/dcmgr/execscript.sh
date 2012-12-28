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
rpm -ivh http://dlc.wakame.axsh.jp.s3-website-us-east-1.amazonaws.com/epel-release

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

# openvswitch
rpm -ql kmod-openvswitch-vzkernel >/dev/null || yum install -y http://dlc.wakame.axsh.jp/packages/rhel/6/master/20120912124632gitff83ce0/${basearch}/kmod-openvswitch-vzkernel-1.6.1-1.el6.${arch}.rpm

## configure edge networking
case "${VDC_NETWORK}" in
openflow)
  /opt/axsh/wakame-vdc/rpmbuild/helpers/set-openvswitch-conf.sh
  cp -f /etc/rc.d/rc.local.openflow /etc/rc.d/rc.local
  ;;
netfilter|*)
  # default
  yum remove -y kmod-openvswitch-vzkernel
  chkconfig openvswitch off
  cp -f /etc/rc.d/rc.local.netfilter /etc/rc.d/rc.local
  ;;
esac

# notification
(cd /opt/axsh; git clone https://github.com/caquino/redis-bash.git)
echo "/opt/axsh/redis-bash/redis-bash-cli -h redis-server publish \$(hostname) ready" >> /etc/rc.local

EOS
