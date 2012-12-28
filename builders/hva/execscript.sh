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

# notification
(cd /opt/axsh; git clone https://github.com/caquino/redis-bash.git)
echo "/opt/axsh/redis-bash/redis-bash-cli -h redis-server publish \$(hostname) ready" >> /etc/rc.local

EOS
