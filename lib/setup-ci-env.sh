#!/bin/bash

set -e
#set -x

. ./../config/rpmbuild.conf

function setup_chroot_dir() {
  [ -d ${rpmbuild_tmp_dir}/chroot/base ] || mkdir -p ${rpmbuild_tmp_dir}/chroot/base/
  cd ${rpmbuild_tmp_dir}/chroot/base

  distro_name="centos"
  distro_relver="6"
  distro_subver="3"
  distro_ver="${distro_relver}"

  distro="${distro_name}-${distro_ver}"
  distro_detail="${distro_name}-${distro_ver}.${distro_subver}"

  for arch in ${archs}; do
    [ -f ${distro_detail}_${arch}.tar.gz ] || curl -R -O http://dlc.wakame.axsh.jp.s3.amazonaws.com/demo/rootfs-tree/${distro_detail}_${arch}.tar.gz
    [ -d ${distro_detail}_${arch}        ] || tar zxpf ${distro_detail}_${arch}.tar.gz
    [ -d ${distro}_${arch}               ] || mv ${distro_detail}_${arch} ${distro}_${arch}
  done
}

case $1 in
setup_chroot_dir)
  $1
  ;;
esac
