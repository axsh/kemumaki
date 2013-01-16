#!/bin/bash

# confirmation

while getopts "y" GETOPTS; do
  case $GETOPTS in
    y) assumeyes=true;;
  esac
done
[[ $assumeyes = true ]] || {
  while true; do
    read -p "Do you want to init wakame-vdc [Y/n]? " yn
    case $yn in
      [Yy]* ) break;;
      [Nn]* ) exit;;
      * ) echo "Please answer yes or no.";;
    esac
  done
}

# stop services

initctl stop vdc-collector

# update wakame-vdc

yum clean metadata && yum update -y 'wakame-vdc*'

# copy conf
cp -f /opt/axsh/wakame-vdc/dcmgr/config/dcmgr.conf.example /etc/wakame-vdc/dcmgr.conf
cp -f /opt/axsh/wakame-vdc/frontend/dcmgr_gui/config/database.yml.example /etc/wakame-vdc/dcmgr_gui/database.yml
cp -f /opt/axsh/wakame-vdc/frontend/dcmgr_gui/config/dcmgr_gui.yml.example /etc/wakame-vdc/dcmgr_gui/dcmgr_gui.yml
cp -f /opt/axsh/wakame-vdc/frontend/dcmgr_gui/config/instance_spec.yml.example /etc/wakame-vdc/dcmgr_gui/instance_spec.yml
cp -f /opt/axsh/wakame-vdc/frontend/dcmgr_gui/config/load_balancer_spec.yml.example /etc/wakame-vdc/dcmgr_gui/load_balancer_spec.yml
cp -f /opt/axsh/wakame-vdc/dcmgr/config/convert_specs/load_balancer.yml.example /etc/wakame-vdc/convert_specs/load_balancer.yml
cp -f /opt/axsh/wakame-vdc/frontend/admin/config/admin.yml.example /etc/wakame-vdc/admin/admin.yml
[[ -f /etc/wakame-vdc/admin/admin.yml.demo ]] && /bin/cp -f /etc/wakame-vdc/admin/admin.yml.demo /etc/wakame-vdc/admin/admin.yml
echo "$(eval "echo \"$(cat /opt/axsh/wakame-vdc/tests/vdc.sh.d/proxy.conf.tmpl)\"")" > /etc/wakame-vdc/proxy.conf

### prepare to start vdc-*

sed -i "s,^#RUN=.*,RUN=yes," /etc/default/vdc-*
sed -i "s/^#\(AMQP_ADDR\)=.*/\1=amqp-server/" /etc/default/vdc-*

### change parameter to run lb instance

sed -i -e "s,management_network.*,management_network 'nw-demo1'," /etc/wakame-vdc/dcmgr.conf
sed -i -e "s,example.com,amqp-server," /etc/wakame-vdc/dcmgr.conf

### initialize database

for dbname in wakame_dcmgr wakame_dcmgr_gui; do
  yes | mysqladmin -uroot drop ${dbname} || :
  mysqladmin -uroot create ${dbname}
done

for dirpath in /opt/axsh/wakame-vdc/dcmgr /opt/axsh/wakame-vdc/frontend/dcmgr_gui; do
  cd ${dirpath}
  /opt/axsh/wakame-vdc/ruby/bin/bundle exec rake db:init --trace
done

### add core data

export HOME=/root

find /var/lib/wakame-vdc/demo/vdc-manage.d/ -type f | sort | xargs cat | egrep -v '^#|^$' | /opt/axsh/wakame-vdc/dcmgr/bin/vdc-manage
find /var/lib/wakame-vdc/demo/gui-manage.d/ -type f | sort | xargs cat | egrep -v '^#|^$' |  /opt/axsh/wakame-vdc/frontend/dcmgr_gui/bin/gui-manage


# start services

initctl start vdc-collector
