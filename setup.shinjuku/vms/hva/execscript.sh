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
curl -o /etc/yum.repos.d/openvz.repo     -R https://raw.github.com/axsh/wakame-vdc/master/rpmbuild/openvz.repo
rpm -ivh http://dlc.wakame.axsh.jp.s3-website-us-east-1.amazonaws.com/epel-release

yum clean metadata --disablerepo=* --enablerepo=wakame-vdc-rhel6
yum update  -y --disablerepo=* --enablerepo=wakame-vdc-rhel6
yum install -y wakame-vdc-hva-openvz-vmapp-config

## instlall package
distro_pkgs="
vim-minimal
screen
git
make
sudo
"
yum install -y ${distro_pkgs}

/sbin/chkconfig       ntpd on
/sbin/chkconfig       ntpdate on

# add vzkernel entry
/opt/axsh/wakame-vdc/rpmbuild/helpers/edit-grub4vz.sh add
# edit boot order to use vzkernel as default.
/opt/axsh/wakame-vdc/rpmbuild/helpers/edit-grub4vz.sh enable

# openvswitch
rpm -ql kmod-openvswitch-vzkernel >/dev/null || yum install -y http://dlc.wakame.axsh.jp/packages/rhel/6/master/20120912124632gitff83ce0/x86_64/kmod-openvswitch-vzkernel-1.6.1-1.el6.x86_64.rpm

## configure edge networking
case "${VDC_NETWORK}" in
openflow)
  /opt/axsh/wakame-vdc/rpmbuild/helpers/set-openvswitch-conf.sh
  cp -f /etc/wakame-vdc/hva.conf.openflow /etc/wakame-vdc/hva.conf
  ;;
netfilter|*)
  # default
  yum remove -y kmod-openvswitch-vzkernel
  cp -f /etc/wakame-vdc/hva.conf.netfilter /etc/wakame-vdc/hva.conf
  ;;
esac

# libraries
mkdir -p /opt/caquino
(cd /opt/caquino; git clone https://github.com/caquino/redis-bash.git)
EOS
