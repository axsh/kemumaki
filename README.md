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
    $ # configure global settings
    $ cp config/kemumaki.conf.example config/kemumaki.conf
    $ vi config/kemumaki.conf
    $
    $ # configure vm settings
    $ cp config/vms/dcmgr.conf.example config/vms/dcmgr.conf
    $ vi config/vms/dcmgr.conf
    $ cp config/vms/hva.conf.example config/vms/hva.conf
    $ vi config/vms/hva.conf
    $ 
    $ # run all
    $ sudo bin/kemumaki

