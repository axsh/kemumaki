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

# openvswitch
rpm -ql kmod-openvswitch-vzkernel >/dev/null || yum install -y http://dlc.wakame.axsh.jp/packages/rhel/6/master/20120912124632gitff83ce0/x86_64/kmod-openvswitch-vzkernel-1.6.1-1.el6.x86_64.rpm

## configure edge networking
case "${VDC_NETWORK}" in
openflow)
  /opt/axsh/wakame-vdc/rpmbuild/helpers/set-openvswitch-conf.sh
  ;;
netfilter|*)
  # default
  yum remove -y kmod-openvswitch-vzkernel
  ;;
esac

# libraries
mkdir -p /opt/caquino
(cd /opt/caquino; git clone https://github.com/caquino/redis-bash.git)

EOS
