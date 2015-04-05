Kemumaki
========

Kemumaki is a rpmbuild tool for Wakame-vdc

Features
--------

1. build an environment using chroot from scratch
2. build rpm packages
3. create a local yum repository

Getting Started
---------------

```
$ git submodule update --init --recursive
$ sudo bin/kemumaki rpmbuild
```

Specify the version number
--------------------------

Define `distro_ver` in `config/distro_ver.conf`.


```
$ echo distro_ver=6.5 > config/distro_ver.conf
```

Links
-----

+ [wakame-vdc/rpmbuild](https://github.com/axsh/wakame-vdc/tree/master/rpmbuild)
+ [vmbuilder](https://github.com/axsh/vmbuilder)

Contributing
------------

1. Fork it ( https://github.com/[my-github-username]/kemumaki/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
