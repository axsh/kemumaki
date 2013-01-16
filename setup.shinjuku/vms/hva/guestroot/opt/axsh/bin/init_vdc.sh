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

initctl stop vdc-hva-worker ID=openvz64
initctl stop vdc-hva

# update wakame-vdc

yum clean metadata && yum update -y 'wakame-vdc*'

# clear vz images

rm -f /vz/template/cache/*

# prepare to start vdc-*

sed -i "s,^#RUN=.*,RUN=yes," /etc/default/vdc-*
sed -i "s/^#\(AMQP_ADDR\)=.*/\1=amqp-server/" /etc/default/vdc-*

# start services

initctl start vdc-hva
initctl start vdc-hva-worker ID=openvz64
