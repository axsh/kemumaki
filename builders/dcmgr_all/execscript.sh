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

curl -o /etc/yum.repos.d/wakame-vdc.repo -R https://raw.github.com/axsh/wakame-vdc/master/rpmbuild/wakame-vdc.repo
yum install -y http://dlc.wakame.axsh.jp.s3-website-us-east-1.amazonaws.com/epel-release

yum install -y wakame-vdc-dcmgr-vmapp-config
yum install -y wakame-vdc-admin-vmapp-config

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

cp -f /opt/axsh/wakame-vdc/frontend/admin/config/admin.yml.example /etc/wakame-vdc/admin.yml


service mysqld start

trap "service mysqld stop" ERR 

export VDC_ROOT=/var/lib/wakame-vdc/
export PATH="/opt/axsh/wakame-vdc/ruby/bin:$PATH"
function init_db() {
  for dbname in wakame_dcmgr wakame_dcmgr_gui; do
    yes | mysqladmin -uroot drop ${dbname} || :
    mysqladmin -uroot create ${dbname}
  done

  cd /opt/axsh/wakame-vdc/dcmgr
  echo "executing 'rake db:init' => dcmgr ..."
  time bundle exec rake --trace db:init

  cd /opt/axsh/wakame-vdc/frontend/dcmgr_gui
  echo "executing 'rake db:init' => frontend/dcmgr_gui ..."
  time bundle exec rake --trace db:init

  #echo ... rake oauth:create_consumer[${account_id}]
  ##local oauth_keys=$(rake oauth:create_consumer[${account_id}] | egrep -v '^\(in')
  #eval ${oauth_keys}

  # Install demo data.
  #(. $data_path/demodata.sh)
}
init_db

# TODO
# configure bridge
# configure vdc-proxy

service mysqld stop
EOS
