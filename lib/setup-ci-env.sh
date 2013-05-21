#!/bin/bash

set -e
#set -x

. ./../config/rpmbuild.conf

function setup_chroot_dir() {
  distro_name="centos"
  distro_relver="6"
  distro_subver="3"
  distro_ver="${distro_relver}"

  distro="${distro_name}-${distro_ver}"
  distro_detail="${distro_name}-${distro_ver}.${distro_subver}"

  for distro_arch in ${archs}; do
    base_dir=${rpmbuild_tmp_dir}/chroot/base
    [ -d ${base_dir} ] || mkdir -p ${base_dir}
    cd ${base_dir}

    [ -f ${distro_detail}_${distro_arch}.tar.gz ] || curl -fkL -O http://dlc.wakame.axsh.jp.s3.amazonaws.com/demo/rootfs-tree/${distro_detail}_${distro_arch}.tar.gz
    [ -d ${distro_detail}_${distro_arch}        ] || tar zxpf ${distro_detail}_${distro_arch}.tar.gz
    [ -d ${distro}_${distro_arch}               ] || mv ${distro_detail}_${distro_arch} ${distro}_${distro_arch}
  done
}

case $1 in
setup_chroot_dir)
  (cd .. &&  git submodule update --init)
  $1
  ;;
esac
