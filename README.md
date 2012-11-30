Kemumaki
========

Kemumaki is a smoke testing framework for Wakame-VDC.

Quick Start
-----------

    $ # install vmbuilder
    $ sudo mkdir -p /opt/hansode
    $ cd /opt/hansode
    $ sudo git clone git://github.com/hansode/vmbuilder.git
    $
    $ # install redis-bash
    $ sudo mkdir -p /opt/caquino
    $ cd /opt/caquino
    $ sudo git://github.com/caquino/redis-bash.git
    $
    $ # configure environment variables
    $ cp .kemumakirc.example .kemumakirc
    $
    $ # configure global settings
    $ cp config/kemumaki.conf.example config/kemumaki.conf
    $ vi config/kemumaki.conf
    $
    $ # configure vm settings
    $ cp config/vms/dcmgr.vm.example config/vms/dcmgr.vm
    $ vi config/vms/dcmgr.vm
    $ cp config/vms/hva.vm.example config/vms/hva.vm
    $ vi config/vms/hva.vm
    $ 
    $ # run all
    $ sudo bin/kemumaki.sh

