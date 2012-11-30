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
curl -o /etc/yum.repos.d/wakame-vdc.repo -R https://raw.github.com/axsh/wakame-vdc/master/rpmbuild/wakame-vdc.repo
curl -o /etc/yum.repos.d/openvz.repo     -R https://raw.github.com/axsh/wakame-vdc/master/rpmbuild/openvz.repo
yum install -y http://ftp.riken.jp/Linux/fedora/epel/6/x86_64/epel-release-6-7.noarch.rpm

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

#cd /tmp
#
#echo "git clone."
#[[ -d gist-1108422 ]] || git clone git://gist.github.com/1108422.git gist-1108422
#cd gist-1108422
#pwd
#
#echo "add work user."
#./add-work-user.sh
#
#echo "change normal user password"
#eval $(./detect-linux-distribution.sh)
#devel_user=$(echo ${DISTRIB_ID} | tr A-Z a-z)
#devel_home=$(getent passwd ${devel_user} 2>/dev/null | awk -F: '{print $6}')
#
#echo ${devel_user}:${devel_user} | chpasswd
#egrep -q ^umask ${devel_home}/.bashrc || {
#  echo umask 022 >> ${devel_home}/.bashrc
#}
#
#cd /tmp
#rm -rf gist-1108422

## configure hva

/sbin/chkconfig       ntpd on
/sbin/chkconfig       ntpdate on

nodes="
hva
"

for node in ${nodes}
do
  sed -i -e "s/^#\(RUN=yes\)/\1/" -e "s/^#\(NODE_ID\).*/\1=demo1/" -e "s/^#\(AMQP_ADDR\)=.*/\1=amqp-server/" /etc/default/vdc-${node}
done

cp -f /opt/axsh/wakame-vdc/dcmgr/config/hva.conf.example /etc/wakame-vdc/hva.conf

# add ifcfg-br0 ifcfg-eth0
/opt/axsh/wakame-vdc/rpmbuild/helpers/setup-bridge-if.sh --brname=
# add vzkernel entry
/opt/axsh/wakame-vdc/rpmbuild/helpers/edit-grub4vz.sh add
# edit boot order to use vzkernel as default.
/opt/axsh/wakame-vdc/rpmbuild/helpers/edit-grub4vz.sh enable

# notification
(cd /opt/axsh; git clone https://github.com/caquino/redis-bash.git)
echo "/opt/axsh/redis-bash/redis-bash-cli -h redis-server publish \$(hostname) ready" >> /etc/rc.local

# ssh login without password
cat /root/.ssh/id_rsa.pub > /root/.ssh/authorized_keys 
chmod 600 ~/.ssh/authorized_keys

EOS
